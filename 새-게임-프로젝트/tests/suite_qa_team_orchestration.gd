extends RefCounted

const ManifestScript := preload("res://scripts/qa/qa_session_manifest.gd")
const PacketScript := preload("res://scripts/qa/qa_role_packet.gd")
const ReportScript := preload("res://scripts/qa/qa_team_report.gd")
const OrchestratorScript := preload("res://scripts/qa/qa_team_orchestrator.gd")

const OUTPUT := "user://__qa_team_orchestration"


static func run(t) -> void:
	t.section("QA team orchestration")
	var manifest := ManifestScript.create(
		"qa-team-phase-f", "qa-commit", "release_gate", "phase_f_front_to_back", true, 424242)
	var artifacts := {
		"functional_qa": ["user://qa_runtime/phase_f_normal/replay_result.json"],
		"experience_qa": [
			"res://docs/qa/fixtures/phase_f_sample_a.json",
			"res://docs/qa/fixtures/phase_f_sample_b.json",
		],
		"combat_simulator": ["res://baseline/lifo_depth_v5.json"],
	}
	var instructions := {
		"functional_qa": ["재현 단계와 원본 artifact로만 기능 결함 판정"],
		"experience_qa": ["player_view와 보이는 텍스트만 사용"],
		"combat_simulator": ["결정론 수식과 실제 CombatManager 결과만 대조"],
	}
	var prepared := OrchestratorScript.prepare(manifest, OUTPUT, artifacts, instructions)
	t.check(bool(prepared.prepared), "세 역할 독립 입력 패킷 생성")
	t.eq(prepared.packets.size(), 3, "기능·경험·시뮬레이터 패킷 3개")
	t.check(FileAccess.file_exists(OUTPUT + "/packets/experience_qa.json"), "경험 QA 패킷 원본 저장")
	t.check(not prepared.packets.experience_qa.has("prior_conclusions"), "경험 QA에 사전 결론 미제공")

	var leaked: Dictionary = prepared.packets.experience_qa.duplicate(true)
	leaked.artifact_paths.append("res://scripts/core/combat_manager.gd")
	t.check(not PacketScript.is_valid(leaked), "경험 QA 패킷의 소스·오라클 누출 차단")
	var biased: Dictionary = prepared.packets.functional_qa.duplicate(true)
	biased["expected_findings"] = ["sample_b는 버그"]
	t.check(not PacketScript.is_valid(biased), "사전 기대 결론이 든 역할 패킷 거절")

	var functional := ReportScript.create(prepared.packets.functional_qa)
	ReportScript.add_finding(functional, "campaign_flow", "flow", "PASS", "none",
		"2구역 46행동과 13노드가 진행 중단 없이 완료됨",
		["phase_f_normal/replay_result.json"])
	ReportScript.add_finding(functional, "sample_a_shop", "ui", "PASS", "none",
		"리롤 후 세 카드의 제목과 설명이 함께 교체됨",
		["phase_f_sample_a.json step 7-8"])
	ReportScript.add_finding(functional, "sample_b_shop_state", "ui", "FAIL", "moderate",
		"리롤 후 중앙 카드의 설명과 카드 수가 새 상태와 일치하지 않음",
		["phase_f_sample_b.json step 7-8"], {
			"expected": "리롤 후 3카드의 제목·설명이 현재 제안과 일치",
			"actual": "퀵로드 제목에 리듬 챔버 설명이 남고 중앙 카드가 2개 표시됨",
			"reproduction_steps": ["샘플 B step 7 확인", "reroll_shop 실행", "step 8 중앙 카드와 개수 확인"],
			"artifact_path": "res://docs/qa/fixtures/phase_f_sample_b.json",
			"origin": "seeded_fixture",
			"registration_eligible": false,
			"reproduction": {"attempts": 1, "reproduced": 1, "deterministic": true, "seeds": [424242]},
			"defect_fingerprint": "seeded_shop_center_stale",
		})
	ReportScript.add_finding(functional, "runtime_reproduced_issue", "flow", "FAIL", "high",
		"실제 제품 흐름의 같은 시작 상태에서 진행 차단이 2회 반복됨",
		["runtime attempt 1", "runtime attempt 2"], {
			"expected": "합법 행동 뒤 다음 화면으로 진행",
			"actual": "같은 화면에 머물고 진행 가능한 행동이 사라짐",
			"reproduction_steps": ["깨끗한 QA 세이브 시작", "같은 시드로 합법 행동 제출", "진행 정지 확인"],
			"artifact_path": "user://qa_runtime/runtime_reproduced_issue.json",
			"origin": "product_runtime",
			"registration_eligible": true,
			"reproduction": {"attempts": 2, "reproduced": 2, "deterministic": true, "seeds": [424242]},
			"defect_fingerprint": "flow|phase_f|legal_action_no_progress",
		})
	ReportScript.complete(functional)

	var experience := ReportScript.create(prepared.packets.experience_qa)
	ReportScript.add_finding(experience, "sample_a_shop", "ui", "PASS", "none",
		"제목과 설명이 함께 바뀌어 선택지를 다시 읽을 수 있음",
		["phase_f_sample_a.json step 7-8"])
	ReportScript.add_finding(experience, "sample_b_shop_state", "ui", "SIGNAL", "moderate",
		"퀵로드 제목과 연속 운용 설명이 어긋나고 중앙 카드가 중복해 선택 예측이 불가능함",
		["phase_f_sample_b.json step 8"])
	ReportScript.add_finding(experience, "input_fatigue", "pacing", "SIGNAL", "low",
		"반복 입력 피로는 자동 판정할 수 없음",
		["phase_f_public checkpoints"], {"requires_human_confirmation": true})
	ReportScript.complete(experience)

	var simulator := ReportScript.create(prepared.packets.combat_simulator)
	ReportScript.add_finding(simulator, "combat_math", "combat", "PASS", "none",
		"명중 임계값·이진 관통·LIFO 정산이 계약과 일치함",
		["suite_damage.gd", "suite_qa_bridge.gd"])
	ReportScript.complete(simulator)

	for report in [functional, experience, simulator]:
		t.check(ReportScript.is_valid(report), "%s 독립 원본 보고 계약" % report.role)
		var save_error := ReportScript.save(report, "%s/reports/%s.json" % [OUTPUT, report.role])
		t.eq(save_error, OK, "%s 원본 보고 후공유 대기 폴더 저장" % report.role)

	var invalid_experience := experience.duplicate(true)
	invalid_experience.findings[1]["classification"] = "FAIL"
	t.check(not ReportScript.is_valid(invalid_experience), "경험 QA의 기능 버그 확정 차단")
	var shared_early := simulator.duplicate(true)
	shared_early["shared_results_received"] = true
	t.check(not ReportScript.is_valid(shared_early), "원본 완료 전 역할 결론 공유 거절")

	var summary := OrchestratorScript.integrate_from_directory(OUTPUT)
	t.check(bool(summary.ready), "세 원본 보고 완료 후 QA 리드 통합")
	t.eq(summary.source_reports.size(), 3, "요약 전 세 원본 보고 보존")
	t.eq(summary.confirmed_bugs.size(), 1, "제품 런타임에서 2회 재현된 결함만 확정")
	t.eq(str(summary.confirmed_bugs[0].finding_key), "runtime_reproduced_issue", "재현 완전한 제품 결함 확정")
	t.eq(summary.seeded_detections.size(), 1, "의도적 fixture 결함은 검출 통계로 분리")
	t.eq(str(summary.seeded_detections[0].finding_key), "sample_b_shop_state", "seeded fixture를 제품 버그로 등록하지 않음")
	t.check(_contains_key(summary.passes, "sample_a_shop"), "정상 샘플을 버그로 오인하지 않음")
	t.check(_contains_key(summary.experience_signals, "input_fatigue"),
		"근거 부족·인간 확인 관찰을 확정 버그에서 분리")
	t.check(FileAccess.file_exists(OUTPUT + "/integrated_summary.json"), "QA 리드 통합 JSON 저장")
	t.check(bool(summary.dashboard.exported), "통합 완료 시 HTML 대시보드 데이터 자동 내보내기")
	t.check(FileAccess.file_exists(OUTPUT + "/dashboard_run.json"), "대시보드 실행 이력 JSON 저장")
	t.check(FileAccess.file_exists(OUTPUT + "/dashboard_data.js"), "file 프로토콜용 대시보드 데이터 저장")


static func _contains_key(entries: Array, finding_key: String) -> bool:
	for entry in entries:
		if str(entry.finding_key) == finding_key:
			return true
	return false
