extends SceneTree
## 네 블랙박스 프로필 원본을 읽어 재미/UX/밸런스 신호와 반복 기능 결함을 분리 통합한다.

const ManifestScript := preload("res://scripts/qa/qa_session_manifest.gd")
const ExperienceReportScript := preload("res://scripts/qa/qa_experience_report.gd")
const ComparatorScript := preload("res://scripts/qa/qa_profile_comparator.gd")
const MetricsScript := preload("res://scripts/qa/qa_experience_metrics.gd")
const TeamReportScript := preload("res://scripts/qa/qa_team_report.gd")
const OrchestratorScript := preload("res://scripts/qa/qa_team_orchestrator.gd")
const DashboardScript := preload("res://scripts/qa/qa_dashboard_exporter.gd")
const CoreFunAssessorScript := preload("res://scripts/qa/qa_core_fun_assessor.gd")


func _initialize() -> void:
	var report_directory := _env("QA_REPORT_DIR", "user://qa_runtime/autonomous/reports")
	var output_directory := _env("QA_TEAM_OUTPUT_DIR", "user://qa_runtime/autonomous/team")
	var session_id := _env("QA_SESSION_ID", "qa-autonomous-final")
	var commit_hash := _env("QA_COMMIT", "working-tree")
	var seed := int(_env("QA_GAMEPLAY_SEED", "424242"))
	var reports := _load_profile_reports(report_directory)
	if reports.size() != ExperienceReportScript.PROFILES.size():
		quit(2)
		return
	var comparison := ComparatorScript.compare(reports)
	if not bool(comparison.get("comparable", false)):
		printerr("QA 프로필 비교 불가: %s" % JSON.stringify(comparison.get("errors", [])))
		quit(2)
		return
	ComparatorScript.save(comparison, "%s/profile_comparison.json" % output_directory.trim_suffix("/"))
	var core_probe := _load_json(_env("QA_CORE_FUN_PATH", ""))
	if core_probe.is_empty():
		printerr("QA core fun probe missing or invalid")
		quit(2)
		return
	var core_fun := CoreFunAssessorScript.assess(core_probe, reports)
	_save_json(core_fun, "%s/core_fun_assessment.json" % output_directory.trim_suffix("/"))

	var manifest := ManifestScript.create(
		session_id, commit_hash, "experience", "autonomous_actual_play", true, seed)
	var artifacts := {
		"functional_qa": _profile_paths(report_directory),
		"experience_qa": _profile_paths(report_directory),
		"combat_simulator": [_env("QA_REGRESSION_LOG", "regression.log")],
	}
	var instructions := {
		"functional_qa": ["같은 공개 이상이 두 프로필 이상에서 반복될 때만 제품 결함 확정"],
		"experience_qa": ["종합 재미 점수 금지, 선택 증거와 인간 확인 항목 분리"],
		"combat_simulator": ["회귀 종료 코드와 실제 전투 완료 수만 판정"],
	}
	var prepared := OrchestratorScript.prepare(manifest, output_directory, artifacts, instructions)
	if not bool(prepared.get("prepared", false)):
		printerr("QA 역할 패킷 생성 실패: %s" % JSON.stringify(prepared.get("errors", [])))
		quit(3)
		return

	var functional := _functional_report(prepared.packets.functional_qa, reports)
	var experience := _experience_report(prepared.packets.experience_qa, reports, comparison, core_fun)
	var simulator := _simulator_report(prepared.packets.combat_simulator, reports)
	for report in [functional, experience, simulator]:
		if not TeamReportScript.is_valid(report):
			printerr("QA 역할 보고 계약 오류 %s: %s" % [report.role, JSON.stringify(TeamReportScript.validation_errors(report))])
			quit(3)
			return
		var error := TeamReportScript.save(report, "%s/reports/%s.json" % [output_directory, report.role])
		if error != OK:
			printerr("QA 역할 보고 저장 실패: %d" % error)
			quit(3)
			return

	var summary := OrchestratorScript.integrate_from_directory(output_directory)
	if not bool(summary.get("ready", false)):
		printerr("QA 통합 실패: %s" % JSON.stringify(summary.get("errors", [])))
		quit(3)
		return
	var regression := {
		"passed": int(_env("QA_REGRESSION_PASSED", "0")),
		"failed": int(_env("QA_REGRESSION_FAILED", "0")),
		"warnings": int(_env("QA_REGRESSION_WARNINGS", "0")),
	}
	var dashboard_run := DashboardScript.create_run({
		"session_id": session_id,
		"commit": commit_hash,
		"dirty_worktree": _env("QA_DIRTY_WORKTREE", "true").to_lower() == "true",
		"scenario_id": "autonomous_actual_play",
		"gameplay_seed": seed,
		"mode": "fun_and_bug_playtest",
		"scope": "총 %d전투 / 4프로필" % _total_encounters(reports),
		"core_fun": core_fun,
	}, summary, regression, _combat_metrics(reports), [
		{"label": "프로필 비교 원본", "path": "profile_comparison.json"},
		{"label": "통합 QA 원본", "path": "integrated_summary.json"},
		{"label": "핵심 재미 판정", "path": "core_fun_assessment.json"},
		{"label": "동일 탄환 순서 대조", "path": "core_fun_probe.json"},
	])
	var run_error := DashboardScript.save_run(dashboard_run, "%s/dashboard_run.json" % output_directory)
	var data_error := DashboardScript.save_data_script([dashboard_run], "%s/dashboard_data.js" % output_directory)
	if run_error != OK or data_error != OK:
		printerr("QA 대시보드 산출 실패: %d/%d" % [run_error, data_error])
		quit(3)
		return
	print("[QA FINALIZE] status=%s confirmed=%d candidates=%d signals=%d output=%s" % [
		dashboard_run.status, summary.confirmed_bugs.size(), summary.candidate_bugs.size(),
		summary.experience_signals.size(), ProjectSettings.globalize_path(output_directory)])
	quit(1 if dashboard_run.status == "FAIL" else 0)


func _functional_report(packet: Dictionary, reports: Array) -> Dictionary:
	var report := TeamReportScript.create(packet)
	var grouped := _group_candidates(reports)
	for issue_key in grouped:
		var entries: Array = grouped[issue_key]
		var profiles := _candidate_profiles(entries)
		var first: Dictionary = entries[0].candidate
		var repeated := profiles.size() >= 2
		if repeated and str(first.get("issue_type", "")) == "possible_functional_anomaly":
			TeamReportScript.add_finding(report, issue_key, "runtime", "FAIL", str(first.get("severity", "moderate")),
				str(first.get("observation", "공개 결과 불일치")), _candidate_evidence(entries), {
					"issue_type": "functional_bug",
					"expected": str(first.get("expected", "")),
					"actual": str(first.get("actual", "")),
					"reproduction_steps": first.get("reproduction_steps", []).duplicate(true),
					"artifact_path": str(first.get("artifact_path", "")),
					"origin": "product_runtime",
					"registration_eligible": true,
					"reproduction": {"attempts": profiles.size(), "reproduced": profiles.size(), "deterministic": true, "seeds": [int(packet.gameplay_seed)]},
					"defect_fingerprint": "runtime|autonomous_actual_play|%s" % issue_key,
				})
		else:
			TeamReportScript.add_finding(report, issue_key, "runtime", "BLOCKED", str(first.get("severity", "moderate")),
				"기능 이상 가능성이 있으나 독립 반복 재현이 부족함: %s" % str(first.get("observation", "")),
				_candidate_evidence(entries), {"issue_type": "functional_bug", "confidence": "observation"})
	if grouped.is_empty():
		TeamReportScript.add_finding(report, "runtime_public_contracts", "flow", "PASS", "none",
			"네 프로필의 합법 행동이 거절 없이 실제 플레이 경로를 완료함",
			_profile_paths(_env("QA_REPORT_DIR", "")), {"issue_type": "pass", "confidence": "confirmed"})
	TeamReportScript.complete(report)
	return report


func _experience_report(packet: Dictionary, reports: Array, comparison: Dictionary, core_fun: Dictionary) -> Dictionary:
	var report := TeamReportScript.create(packet)
	for conclusion in comparison.get("conclusions", []):
		if str(conclusion.get("signal_key", "")) == "physical_feel_requires_human":
			continue
		var classification := str(conclusion.get("classification", "hypothesis"))
		var details := {
			"issue_type": _issue_type_for_axis(str(conclusion.get("axis", "choice"))),
			"confidence": "human_confirmation" if classification == "human_confirmation" else \
				("strong_signal" if classification == "strong_signal" else "observation"),
			"requires_human_confirmation": classification == "human_confirmation",
		}
		TeamReportScript.add_finding(report, str(conclusion.get("signal_key", "experience_signal")),
			str(conclusion.get("axis", "experience")), "SIGNAL", "low",
			_cold_observation(conclusion), [JSON.stringify(conclusion.get("evidence", []))], details)
	for dominance in comparison.get("dominant_choices", []):
		TeamReportScript.add_finding(report,
			"dominant_%s_%s" % [str(dominance.get("category", "choice")), str(dominance.get("choice_id", "unknown"))],
			"balance", "SIGNAL", "moderate",
			"프로필 간 선택이 %s에 %.1f%% 집중됨; 재미 성공이 아니라 지배 전략 후보임" % [
				str(dominance.get("choice_id", "")), float(dominance.get("share", 0.0)) * 100.0],
			[JSON.stringify(dominance)], {"issue_type": "balance_risk", "confidence": str(dominance.get("classification", "hypothesis")).replace("hypothesis", "observation")})
	for profile_report in reports:
		for candidate in profile_report.get("issue_candidates", []):
			TeamReportScript.add_finding(report, "experience_%s_%s" % [profile_report.profile, candidate.issue_key],
				"ui", "SIGNAL", str(candidate.get("severity", "moderate")),
				str(candidate.get("observation", "")), [str(candidate.get("artifact_path", ""))],
				{"issue_type": "ux_issue", "confidence": "observation"})
	for gate in core_fun.get("gates", []):
		var passed := bool(gate.get("passed", false))
		TeamReportScript.add_finding(report, "core_fun_%s" % str(gate.get("id", "gate")),
			"core_fun", "PASS" if passed else "SIGNAL", "none" if passed else "moderate",
			"%s — %s" % [str(gate.get("question", "")), str(gate.get("evidence", ""))],
			[_env("QA_CORE_FUN_PATH", "core_fun_probe.json")], {
				"issue_type": "pass" if passed else "fun_issue",
				"confidence": "confirmed" if passed else "strong_signal",
			})
	var core_confirmed := str(core_fun.get("verdict", "")) == CoreFunAssessorScript.VERDICT_CONFIRMED
	TeamReportScript.add_finding(report, "core_fun_verdict", "core_fun",
		"PASS" if core_confirmed else "SIGNAL", "none" if core_confirmed else "moderate",
		"%s — %s" % [str(core_fun.get("headline", "")), str(core_fun.get("summary", ""))],
		["%s/core_fun_assessment.json" % _env("QA_TEAM_OUTPUT_DIR", "")], {
			"issue_type": "pass" if core_confirmed else "fun_issue",
			"confidence": "strong_signal" if str(core_fun.get("confidence", "low")) == "medium" else "observation",
		})
	if report.findings.is_empty():
		TeamReportScript.add_finding(report, "experience_evidence_collected", "experience", "PASS", "none",
			"네 프로필의 선택 이유·대안·실제 결과가 기록됨", _profile_paths(_env("QA_REPORT_DIR", "")))
	TeamReportScript.complete(report)
	return report


func _simulator_report(packet: Dictionary, reports: Array) -> Dictionary:
	var report := TeamReportScript.create(packet)
	var failed := int(_env("QA_REGRESSION_FAILED", "0"))
	if failed > 0:
		TeamReportScript.add_finding(report, "automatic_regression", "combat", "FAIL", "high",
			"자동 회귀에서 %d개 검사가 실패함" % failed, [_env("QA_REGRESSION_LOG", "regression.log")], {
				"expected": "자동 회귀 실패 0", "actual": "실패 %d" % failed,
				"reproduction_steps": ["전용 QA APPDATA 설정", "run_all.gd 실행", "회귀 요약 확인"],
				"artifact_path": _env("QA_REGRESSION_LOG", "regression.log"),
				"origin": "product_runtime", "registration_eligible": false,
				"reproduction": {"attempts": 1, "reproduced": 1, "deterministic": false, "seeds": []},
				"defect_fingerprint": "regression|run_all|failure",
			})
	else:
		TeamReportScript.add_finding(report, "automatic_regression", "combat", "PASS", "none",
			"자동 회귀와 실제 프로필 전투가 실패 없이 완료됨",
			[_env("QA_REGRESSION_LOG", "regression.log"), "encounters=%d" % _total_encounters(reports)])
	TeamReportScript.complete(report)
	return report


func _load_profile_reports(directory: String) -> Array:
	var reports: Array = []
	for profile in ExperienceReportScript.PROFILES:
		var path := "%s/%s.json" % [directory.trim_suffix("/"), profile]
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			printerr("QA profile missing: %s" % ProjectSettings.globalize_path(path))
			return []
		var parsed = JSON.parse_string(file.get_as_text())
		if not parsed is Dictionary or not ExperienceReportScript.is_valid(parsed):
			printerr("QA profile invalid: %s" % path)
			return []
		reports.append(parsed)
	return reports


func _group_candidates(reports: Array) -> Dictionary:
	var grouped: Dictionary = {}
	for report in reports:
		for candidate in report.get("issue_candidates", []):
			var key := str(candidate.get("issue_key", "unknown"))
			if not grouped.has(key): grouped[key] = []
			grouped[key].append({"profile": str(report.profile), "candidate": candidate})
	return grouped


func _candidate_profiles(entries: Array) -> Array:
	var profiles: Dictionary = {}
	for entry in entries: profiles[str(entry.profile)] = true
	return profiles.keys()


func _candidate_evidence(entries: Array) -> Array:
	var evidence: Array = []
	for entry in entries:
		evidence.append("%s: %s" % [str(entry.profile), str(entry.candidate.get("artifact_path", ""))])
	return evidence


func _profile_paths(directory: String) -> Array:
	var paths: Array = []
	for profile in ExperienceReportScript.PROFILES:
		paths.append("%s/%s.json" % [directory.trim_suffix("/"), profile])
	return paths


func _combat_metrics(reports: Array) -> Dictionary:
	var shots := 0
	var reloads := 0
	var minimum_distance = null
	for report in reports:
		var metrics := MetricsScript.aggregate(report)
		for action in report.actions:
			if str(action.action) == "fire": shots += 1
		reloads += int(metrics.action_counts.reload)
		var distance = metrics.pressure.minimum_distance
		if distance != null: minimum_distance = int(distance) if minimum_distance == null else mini(int(minimum_distance), int(distance))
	return {"shots": shots, "reloads": reloads, "min_distance": minimum_distance, "completed_encounters": _total_encounters(reports)}


func _total_encounters(reports: Array) -> int:
	var total := 0
	for report in reports:
		total += int(report.get("session_summary", {}).get("completed_encounters", 0))
	return total


func _issue_type_for_axis(axis: String) -> String:
	if axis in ["understanding", "feedback"]: return "ux_issue"
	if axis == "diversity": return "balance_risk"
	return "fun_issue"


func _cold_observation(conclusion: Dictionary) -> String:
	var profiles: Array = conclusion.get("profiles", [])
	return "%d개 프로필에서 %s 신호가 관찰됨; 종합 재미 판정이 아닌 행동 증거임" % [
		profiles.size(), str(conclusion.get("signal_key", "experience"))]


func _env(key: String, fallback: String) -> String:
	var value := OS.get_environment(key)
	return fallback if value.is_empty() else value


func _load_json(path: String) -> Dictionary:
	if path.is_empty(): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _save_json(value: Dictionary, path: String) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	if error != OK and error != ERR_ALREADY_EXISTS: return error
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value, "\t") + "\n")
	return OK
