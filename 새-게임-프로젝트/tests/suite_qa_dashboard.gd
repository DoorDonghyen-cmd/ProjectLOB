extends RefCounted

const ExporterScript := preload("res://scripts/qa/qa_dashboard_exporter.gd")
const OUTPUT := "user://__qa_dashboard"


static func run(t) -> void:
	t.section("QA HTML dashboard export")
	var summary := {
		"confirmed_bugs": [],
		"experience_signals": [{
			"finding_key": "empty_chamber_guidance",
			"classification": "hypothesis",
			"findings": [{
				"role": "experience_qa",
				"category": "ui",
				"severity": "low",
				"observation": "빈 약실 다음 행동 안내가 부족함",
			}],
		}],
		"passes": [{
			"finding_key": "campaign_flow",
			"findings": [{
				"role": "functional_qa",
				"category": "flow",
				"severity": "none",
				"observation": "2구역 진행 완료",
			}],
		}],
		"infrastructure": [{
			"finding_key": "headless_capture",
			"findings": [{
				"role": "functional_qa",
				"category": "capture",
				"severity": "low",
				"observation": "headless PNG 미지원",
			}],
		}],
		"blocked": [],
		"conflicts": [],
		"source_reports": [{
			"role": "functional_qa",
			"completed_at": "2026-08-23T20:00:00Z",
			"findings": [{"classification": "PASS"}, {"classification": "INFRA"}],
		}, {
			"role": "experience_qa",
			"completed_at": "2026-08-23T20:01:00Z",
			"findings": [{"classification": "SIGNAL"}],
		}],
	}
	var run := ExporterScript.create_run({
		"session_id": "qa-dashboard-test",
		"created_at": "2026-08-23T20:02:00Z",
		"status": "BLOCKED",
		"mode": "release_gate",
		"scope": "campaign_2_sections",
		"commit": "abcdef1",
		"dirty_worktree": true,
		"gameplay_seed": 424242,
	}, summary, {"passed": 3562, "failed": 0, "warnings": 3}, {
		"shots": 16, "hits": 15, "effective_hits": 14, "damage": 44,
	}, [{"label": "통합 리포트", "href": "../reports/qa.md", "kind": "report"}])
	t.check(ExporterScript.is_valid(run), "대시보드 실행 이력 계약")
	t.eq(str(run.status), "BLOCKED", "릴리스 보류 상태 보존")
	t.eq(int(run.counts.pass), 1, "PASS 항목 집계")
	t.eq(int(run.counts.signal), 1, "SIGNAL 항목 집계")
	t.eq(int(run.counts.infra), 1, "INFRA 항목 집계")
	t.eq(run.roles.size(), 2, "역할별 원본 집계")
	t.eq(run.findings.size(), 3, "분류별 finding 평탄화")
	t.eq(ExporterScript.save_run(run, OUTPUT + "/runs/phase_f.json"), OK, "실행 이력 JSON 저장")

	var pass_run: Dictionary = run.duplicate(true)
	pass_run.run_id = "qa-dashboard-pass"
	pass_run.created_at = "2026-08-22T20:02:00Z"
	pass_run.status = "PASS"
	t.eq(ExporterScript.save_run(pass_run, OUTPUT + "/runs/phase_e.json"), OK, "이전 실행 이력 저장")
	var runs := ExporterScript.load_runs(OUTPUT + "/runs")
	t.eq(runs.size(), 2, "대시보드 이력 폴더 로드")
	t.eq(str(runs[0].run_id), "qa-dashboard-test", "최신 실행 우선 정렬")
	t.eq(ExporterScript.save_data_script(runs, OUTPUT + "/dashboard_data.js"), OK,
		"file 프로토콜용 데이터 스크립트 저장")
	var data_file := FileAccess.open(OUTPUT + "/dashboard_data.js", FileAccess.READ)
	t.check(data_file != null, "대시보드 데이터 스크립트 생성")
	if data_file != null:
		var content := data_file.get_as_text()
		t.check(content.begins_with("window.QA_DASHBOARD_DATA = "), "전역 데이터 계약 접두사")
		t.check(content.contains("qa-dashboard-test"), "최신 실행 데이터 포함")

	var invalid: Dictionary = run.duplicate(true)
	invalid.status = "UNKNOWN"
	t.check(not ExporterScript.is_valid(invalid), "알 수 없는 최종 판정 거절")
	var failed := ExporterScript.create_run({
		"session_id": "qa-dashboard-fail", "scope": "smoke", "commit": "abcdef1",
	}, summary, {"passed": 10, "failed": 1, "warnings": 0})
	t.eq(str(failed.status), "FAIL", "회귀 실패가 있으면 HTML 최종 판정 FAIL")
	var review := ExporterScript.create_run({
		"session_id": "qa-dashboard-review", "scope": "actual_play", "commit": "abcdef1",
	}, summary, {"passed": 10, "failed": 0, "warnings": 0})
	t.eq(str(review.status), "REVIEW", "재미·UX 신호가 있으면 승인 대신 개선 논의 상태")
