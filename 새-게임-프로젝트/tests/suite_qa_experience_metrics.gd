extends RefCounted

const ManifestScript := preload("res://scripts/qa/qa_session_manifest.gd")
const ReportScript := preload("res://scripts/qa/qa_experience_report.gd")
const MetricsScript := preload("res://scripts/qa/qa_experience_metrics.gd")
const ComparatorScript := preload("res://scripts/qa/qa_profile_comparator.gd")
const REPORT_OUTPUT := "user://__qa_profile_reports"


static func run(t) -> void:
	t.section("QA experience metrics")
	var reports := _four_reports()
	for report in reports:
		t.check(ReportScript.is_valid(report), "%s 블랙박스 원본 리포트 계약" % report.profile)
		t.eq(ReportScript.save(report, "%s/%s.json" % [REPORT_OUTPUT, report.profile]), OK,
			"%s 프로필 JSON 원본 저장" % report.profile)

	var contaminated: Dictionary = reports[0].duplicate(true)
	contaminated["oracle_state"] = {"hidden_magazine": ["secret"]}
	t.check(not ReportScript.is_valid(contaminated), "경험 테스터 리포트의 oracle_state 오염 거절")

	var state_bundle := {
		"step": 99,
		"player_view": {"screen": "combat", "enemies": [{"distance": 5, "is_dead": false}]},
		"oracle_state": {"magazine_fire_order": ["hidden"]},
	}
	var recorded := ReportScript.create(_manifest("recorded"), "beginner", _start_condition())
	t.eq(ReportScript.record_action(
		recorded, state_bundle, {"action": "fire", "target_slot": 0}, {"accepted": true},
		"앞의 적에게 피해", "가장 가까운 위험 우선", [], "combat", "target_0"), OK,
		"공개 상태와 선택 이유 기록")
	t.check(not recorded.actions[0].has("oracle_state"), "상태 bundle에서 공개 player_view만 기록")
	t.eq(int(recorded.actions[0].player_view.enemies[0].distance), 5, "공개 최소 거리 증거 보존")

	var aggressive_metrics := MetricsScript.aggregate(reports[1])
	t.check(bool(aggressive_metrics.valid), "공격형 행동 지표 집계")
	t.check(not aggressive_metrics.has("score") and not aggressive_metrics.has("total_score"),
		"단일 종합 점수를 생성하지 않음")
	t.eq(int(aggressive_metrics.pressure.minimum_distance), 3, "player_view 기반 최소 거리 집계")
	t.eq(int(aggressive_metrics.overkill.total_damage), 4, "과잉 피해 증거 합계")
	t.check(aggressive_metrics.tactical_ammo.unused.has("marker"), "보유했지만 쓰지 않은 전술탄 검출")
	var issue_report: Dictionary = reports[0].duplicate(true)
	t.eq(ReportScript.add_issue_candidate(issue_report, "shop_render_conflict", "possible_functional_anomaly",
		"제목과 설명이 충돌함", "카드 제목과 설명의 효과 일치", "서로 다른 효과 표시", [7, 8],
		["상점 진입", "주파수 재요청", "중앙 카드 비교"], "possible_functional_anomaly", "moderate",
		"user://qa/shop/checkpoint_0008.json"), OK, "블랙박스 버그 의심 후보 기록")
	t.check(ReportScript.is_valid(issue_report), "버그 의심과 재미 관찰을 한 경험 리포트에 분리 보존")

	var comparison := ComparatorScript.compare(reports)
	t.check(bool(comparison.comparable), "동일 시작 조건의 네 프로필 비교 성립")
	t.eq(comparison.metrics_by_profile.size(), 4, "네 프로필 개별 지표 보존")
	t.check(_has_dominance(comparison.dominant_choices, "reward", "credits", "bullet"),
		"지배 선택이 밀어낸 대안·선택 차이 증거 생성")
	t.eq(_classification(comparison.conclusions, "reward_text_unclear"), "strong_signal",
		"세 프로필 반복 관찰을 강한 신호로 승격")
	t.eq(_classification(comparison.conclusions, "input_fatigue"), "human_confirmation",
		"촉감·피로도는 자동 확정하지 않고 인간 확인 유지")
	t.eq(comparison.pairwise_choice_overlap.size(), 6, "4프로필 쌍별 선택 중복률 6개 생성")

	var clones: Array = []
	for profile in ReportScript.PROFILES:
		var clone: Dictionary = reports[0].duplicate(true)
		clone["profile"] = profile
		clone["session_id"] = "clone-%s" % profile
		clones.append(clone)
	var rejected := ComparatorScript.compare(clones)
	t.check(not bool(rejected.comparable), "프로필명만 다른 동일 행동열 거절")
	t.check(_contains_text(rejected.errors, "동일 행동열"), "동일 행동열 거절 이유 명시")

	var mismatched: Array = reports.duplicate(true)
	mismatched[3] = reports[3].duplicate(true)
	mismatched[3]["gameplay_seed"] = 999
	var mismatch_result := ComparatorScript.compare(mismatched)
	t.check(not bool(mismatch_result.comparable), "다른 gameplay seed 보고서 비교 거절")


static func _four_reports() -> Array:
	var beginner := _base_report("beginner")
	_add(beginner, 0, "choose_route", "stairs", "route", 8)
	_add(beginner, 1, "choose_reward", "credits", "reward", 8)
	_add(beginner, 2, "buy", "rhythm_chamber", "part", 7)
	_add(beginner, 3, "load", "marker", "ammo", 6, ["tactical_ammo"])
	_add(beginner, 4, "reload", "reload", "combat", 6)
	ReportScript.add_observation(beginner, "reward_text_unclear", "understanding",
		"보상 문구로 실제 효과를 예측하기 어려움", [1])
	ReportScript.add_observation(beginner, "input_fatigue", "pacing",
		"반복 입력 피로는 촉감 확인이 필요함", [4], "human_confirmation")

	var aggressive := _base_report("aggressive")
	_add(aggressive, 0, "choose_route", "stairs", "route", 7)
	_add(aggressive, 1, "choose_reward", "bullet", "reward", 6)
	_add(aggressive, 2, "buy", "damage_part", "part", 5)
	_add(aggressive, 3, "load", "finale", "ammo", 4, ["tactical_ammo"])
	_add(aggressive, 4, "fire", "target_0", "combat", 3, [], 4)
	_add(aggressive, 5, "reload", "reload", "combat", 3)
	ReportScript.add_observation(aggressive, "reward_text_unclear", "understanding",
		"화력 보상과 탄환 보상의 즉시 이득 차이가 안 읽힘", [1])

	var conservative := _base_report("conservative")
	_add(conservative, 0, "choose_route", "air_duct", "route", 9)
	_add(conservative, 1, "choose_reward", "credits", "reward", 9)
	_add(conservative, 2, "buy", "guard_part", "part", 8)
	_add(conservative, 3, "load", "borer", "ammo", 7, ["tactical_ammo"])
	_add(conservative, 4, "reload", "reload", "combat", 7)
	ReportScript.add_observation(conservative, "reward_text_unclear", "understanding",
		"안정성 관점에서 보상 대안의 비용을 비교하기 어려움", [1])

	var experimental := _base_report("experimental")
	_add(experimental, 0, "choose_route", "event", "route", 8)
	_add(experimental, 1, "choose_reward", "credits", "reward", 8)
	_add(experimental, 2, "buy", "novel_part", "part", 6)
	_add(experimental, 3, "load", "chain", "ammo", 5, ["tactical_ammo"])
	_add(experimental, 4, "choose_route", "air_duct", "route", 4)
	return [beginner, aggressive, conservative, experimental]


static func _base_report(profile: String) -> Dictionary:
	return ReportScript.create(_manifest(profile), profile, _start_condition())


static func _manifest(profile: String) -> Dictionary:
	return ManifestScript.create(
		"qa-profile-%s" % profile, "qa-commit", "experience", "campaign_two_sections", false, 424242)


static func _start_condition() -> Dictionary:
	return {
		"save_fixture": "clean",
		"gun_id": "revolver",
		"section": "section_a",
		"tactical_ammo_ids": ["marker", "borer", "chain", "finale"],
	}


static func _add(
	report: Dictionary,
	step: int,
	action: String,
	choice_id: String,
	category: String,
	distance: int,
	tags: Array = [],
	overkill: int = 0
) -> void:
	report.actions.append({
		"step": step,
		"screen": "combat" if category in ["ammo", "combat"] else category,
		"action": action,
		"choice_id": choice_id,
		"category": category,
		"expected": "프로필 원칙에 맞는 결과",
		"reason": "플레이어 공개 정보에서 선택",
		"alternatives": [{"choice_id": "alternative", "reason_not_chosen": "우선순위가 낮음"}],
		"accepted": true,
		"player_view": {
			"screen": "combat" if category in ["ammo", "combat"] else category,
			"enemies": [{"distance": distance, "is_dead": false}],
		},
		"result": {"accepted": true},
		"tags": tags.duplicate(),
		"outcome": {"overkill_damage": overkill} if overkill > 0 else {},
	})


static func _has_dominance(entries: Array, category: String, choice_id: String, alternative: String) -> bool:
	for entry in entries:
		if str(entry.category) != category or str(entry.choice_id) != choice_id:
			continue
		for candidate in entry.alternatives:
			if str(candidate.choice_id) == alternative and int(candidate.lead) == 2:
				return str(entry.classification) == "strong_signal"
	return false


static func _classification(entries: Array, signal_key: String) -> String:
	for entry in entries:
		if str(entry.signal_key) == signal_key:
			return str(entry.classification)
	return ""


static func _contains_text(values: Array, fragment: String) -> bool:
	for value in values:
		if str(value).contains(fragment):
			return true
	return false
