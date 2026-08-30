extends RefCounted

const ProbeScript := preload("res://scripts/qa/qa_core_fun_probe.gd")
const AssessorScript := preload("res://scripts/qa/qa_core_fun_assessor.gd")
const ManifestScript := preload("res://scripts/qa/qa_session_manifest.gd")
const ReportScript := preload("res://scripts/qa/qa_experience_report.gd")


static func run(t) -> void:
	t.section("QA core fun")
	var probe := ProbeScript.generate_report()
	t.eq(int(probe.scenario_count), 4, "핵심 재미 순서 대조 4상황")
	t.eq(int(probe.order_sensitive_scenarios), 4, "동일 멀티셋 4상황 모두 순서 영향")
	t.eq(int(probe.planned_better_scenarios), 4, "계획 순서가 역순보다 4상황 모두 우세")
	t.eq(int(probe.mixed_better_than_basic_scenarios), 4, "상황 혼합 장전이 기본 반복보다 4상황 모두 우세")
	for scenario in probe.scenarios:
		t.check(bool(scenario.same_multiset), "%s 계획/역순은 같은 탄환 묶음" % str(scenario.scenario_id))

	var adaptive_reports: Array = []
	for cohort in range(3):
		adaptive_reports.append_array(_reports(true, 424242 + cohort))
	var confirmed := AssessorScript.assess(probe, adaptive_reports)
	t.eq(str(confirmed.verdict), AssessorScript.VERDICT_CONFIRMED,
		"기계 대조와 실제 상황 장전이 함께 있으면 핵심 재미 확인")
	t.check(not confirmed.has("score") and not confirmed.has("total_score"),
		"핵심 재미를 평균 점수로 뭉개지 않음")
	t.eq(confirmed.gates.size(), 5, "순서·상황·혼합·실전 압박·표본 독립 게이트")

	var passive_reports := _reports(false)
	var thin := AssessorScript.assess(probe, passive_reports)
	t.eq(str(thin.verdict), AssessorScript.VERDICT_THIN,
		"순서 수학만 작동하고 실제 장전 압박이 없으면 가능성은 있으나 얕음")


static func _reports(adaptive: bool, seed: int = 424242) -> Array:
	var reports: Array = []
	for index in range(ReportScript.PROFILES.size()):
		var profile: String = ReportScript.PROFILES[index]
		var manifest := ManifestScript.create(
			"core-fun-%s-%d" % [profile, seed], "qa-commit", "experience", "core_fun", false, seed)
		var report := ReportScript.create(manifest, profile, {
			"save_fixture": "clean", "gun_id": "revolver", "tactical_ammo_ids": ["marker", "borer"]})
		var tactical := adaptive and index < 2
		var choice := "표식탄" if tactical else "경량탄"
		var tags: Array = ["tactical_ammo", "planned_sequence"] if tactical else ["planned_sequence"]
		report.actions.append({
			"step": 0, "screen": "combat", "action": "load", "choice_id": choice,
			"category": "ammo", "expected": "LIFO 계획에 추가",
			"reason": "대상 EVA 7을 열기 위한 ACC 결산" if tactical else "기본탄 우선",
			"alternatives": [], "accepted": true,
			"player_view": {"screen": "combat", "enemies": [{"distance": 6, "is_dead": false}],
				"available_ammo": [{"id": "표식탄", "bullet": {"is_basic": false}}]},
			"result": {"accepted": true}, "tags": tags, "outcome": {},
		})
		ReportScript.finish(report, "target_reached", 2, [])
		reports.append(report)
	return reports
