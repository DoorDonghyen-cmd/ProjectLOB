class_name QACoreFunAssessor
extends RefCounted
## 전략적 코어 재미를 평균 점수가 아닌 독립 게이트와 반증 증거로 판정한다.

const MetricsScript := preload("res://scripts/qa/qa_experience_metrics.gd")

const VERDICT_CONFIRMED := "CORE_FUN_CONFIRMED"
const VERDICT_THIN := "PROMISING_BUT_THIN"
const VERDICT_NOT_DEMONSTRATED := "NOT_DEMONSTRATED"
const VERDICT_STRUCTURAL_PROBLEM := "STRUCTURAL_PROBLEM"


static func assess(probe: Dictionary, reports: Array) -> Dictionary:
	var scenario_count := int(probe.get("scenario_count", 0))
	var order_sensitive := int(probe.get("order_sensitive_scenarios", 0))
	var planned_better := int(probe.get("planned_better_scenarios", 0))
	var mixed_better := int(probe.get("mixed_better_than_basic_scenarios", 0))
	var setup_axes: Array = probe.get("distinct_setup_axes", [])
	var tactical_profile_ids: Dictionary = {}
	var tactical_loads := 0
	var ammo_loads := 0
	var completed_encounters := 0
	var contextual_reasons := 0
	var victories := 0
	var tested_seeds: Dictionary = {}
	for report in reports:
		tested_seeds[int(report.get("gameplay_seed", 0))] = true
		var metrics := MetricsScript.aggregate(report)
		var profile_tactical := int(metrics.get("tactical_ammo", {}).get("used", []).size())
		if profile_tactical > 0:
			tactical_profile_ids[str(report.get("profile", "unknown"))] = true
		completed_encounters += int(report.get("session_summary", {}).get("completed_encounters", 0))
		for action in report.get("actions", []):
			if str(action.get("action", "")) == "choose_reward" and bool(action.get("accepted", false)):
				victories += 1
			if str(action.get("category", "")) != "ammo" or not bool(action.get("accepted", false)):
				continue
			ammo_loads += 1
			if action.get("tags", []).has("tactical_ammo"):
				tactical_loads += 1
			var reason := str(action.get("reason", ""))
			# 기본탄 슬롯을 채운 설명이 아니라 실제 전술탄을 선택한 맥락만 센다.
			if action.get("tags", []).has("tactical_ammo") and (reason.contains("DEF") \
					or reason.contains("EVA") or reason.contains("거리") or reason.contains("결산")):
				contextual_reasons += 1

	var gates := [
		_gate("sequence_leverage", "같은 탄환도 순서가 결과를 바꾸는가",
			order_sensitive >= 3 and planned_better >= 3,
			"%d/%d 상황에서 순서에 따라 결과 변화, 계획 순서 우세 %d회" % [order_sensitive, scenario_count, planned_better]),
		_gate("context_specific_solutions", "적 자물쇠에 따라 필요한 조합이 바뀌는가",
			setup_axes.size() >= 3,
			"서로 다른 해법 축 %d개: %s" % [setup_axes.size(), ", ".join(PackedStringArray(setup_axes))]),
		_gate("mixed_load_value", "상황 맞춤 혼합 장전이 기본탄 반복보다 나은가",
			mixed_better >= 2,
			"%d/%d 상황에서 계획 혼합 장전이 기본탄 비교보다 우세" % [mixed_better, scenario_count]),
		_gate("actual_decision_pressure", "실제 캠페인에서 조합을 선택할 필요가 발생했는가",
			tactical_profile_ids.size() >= 2 and contextual_reasons >= 2,
			"전술탄 사용 성향 %d/4, 상황 근거 장전 %d회, 총 전투 %d회" % [tactical_profile_ids.size(), contextual_reasons, completed_encounters]),
		_gate("sample_coverage", "서로 다른 진행에서도 같은 재미 구조가 반복되는가",
			tested_seeds.size() >= 3 and completed_encounters >= 12,
			"검증 시드 %d개, 총 전투 %d회, 승리 %d회, 패배·종료 %d회" % [
				tested_seeds.size(), completed_encounters, victories, maxi(completed_encounters - victories, 0)]),
	]
	var mechanical_passes := _passed_count(gates.slice(0, 3))
	var actual_pressure := bool(gates[3].passed)
	var coverage := bool(gates[4].passed)
	var verdict := VERDICT_NOT_DEMONSTRATED
	if mechanical_passes <= 1:
		verdict = VERDICT_STRUCTURAL_PROBLEM
	elif mechanical_passes == 3 and actual_pressure and coverage:
		verdict = VERDICT_CONFIRMED
	elif mechanical_passes >= 2:
		verdict = VERDICT_THIN

	return {
		"schema_version": 1,
		"verdict": verdict,
		"headline": _headline(verdict),
		"summary": _summary(verdict, mechanical_passes, actual_pressure),
		"confidence": "medium" if completed_encounters >= 8 else "low",
		"gates": gates,
		"evidence": {
			"scenario_count": scenario_count,
			"order_sensitive_scenarios": order_sensitive,
			"planned_better_scenarios": planned_better,
			"mixed_better_than_basic_scenarios": mixed_better,
			"tactical_profiles": tactical_profile_ids.size(),
			"tactical_loads": tactical_loads,
			"ammo_loads": ammo_loads,
			"contextual_reasons": contextual_reasons,
			"completed_encounters": completed_encounters,
			"victories": victories,
			"losses_or_run_ends": maxi(completed_encounters - victories, 0),
			"tested_seeds": tested_seeds.keys(),
		},
		"human_confirmation": [
			"장전 고민이 즐거운지와 정답 발견 후 다시 시도하고 싶은지",
			"발사·타격·결산 연출이 계획 성공의 쾌감을 충분히 전달하는지",
			"장시간 플레이에서 장전 입력과 계산이 피로보다 만족을 주는지",
		],
		"next_actions": _next_actions(verdict, actual_pressure),
	}


static func _gate(id: String, question: String, passed: bool, evidence: String) -> Dictionary:
	return {"id": id, "question": question, "passed": passed, "evidence": evidence}


static func _passed_count(gates: Array) -> int:
	var count := 0
	for gate in gates:
		if bool(gate.passed): count += 1
	return count


static func _headline(verdict: String) -> String:
	match verdict:
		VERDICT_CONFIRMED: return "탄환 순서 설계가 실제 선택과 결과 차이를 만들고 있음"
		VERDICT_THIN: return "순서 퍼즐은 작동하지만 실제 플레이에서 요구되는 빈도와 깊이가 부족함"
		VERDICT_STRUCTURAL_PROBLEM: return "탄환 순서를 바꿔도 의미 있는 결과 차이가 충분하지 않음"
	return "현재 플레이 증거로는 탄환 조합의 핵심 재미를 확인하지 못함"


static func _summary(verdict: String, mechanical_passes: int, actual_pressure: bool) -> String:
	if verdict == VERDICT_CONFIRMED:
		return "기계적 순서 가치와 실제 상황 대응 장전이 함께 관찰됐다. 인간 체감 항목을 통과하면 코어 재미 근거가 강하다."
	if verdict == VERDICT_THIN:
		return "결정론적 순서 효과는 %d/3 게이트를 통과했지만 실제 캠페인 압박은 %s. 잠재력과 현재 체감 빈도를 구분해야 한다." % [mechanical_passes, "확인됨" if actual_pressure else "미확인"]
	if verdict == VERDICT_STRUCTURAL_PROBLEM:
		return "같은 탄환의 순서 대조에서 계획 우위가 부족해 LIFO가 핵심 의사결정으로 기능하지 못한다."
	return "실제 장전 이유와 결과 대조 증거가 부족하다. 선택률만으로 재미를 판정하지 않는다."


static func _next_actions(verdict: String, actual_pressure: bool) -> Array[String]:
	if verdict == VERDICT_CONFIRMED:
		return ["사람 플레이에서 재계획 욕구와 결산 쾌감 확인", "서로 다른 시드에서 동일 결론 재검증"]
	if verdict == VERDICT_THIN and not actual_pressure:
		return ["초반 전투에서 기본탄 반복만으로 풀리지 않는 읽기 쉬운 자물쇠 배치", "상황 대응형 프로필로 여러 시드 재실행"]
	if verdict == VERDICT_THIN:
		return ["최소 3개 시드·12전투 이상에서 같은 순서 가치가 반복되는지 확인", "사람 플레이에서 재계획 욕구와 결산 쾌감 확인"]
	if verdict == VERDICT_STRUCTURAL_PROBLEM:
		return ["조합탄의 순서 전후 결과 차이를 먼저 확대", "같은 멀티셋 역순 대조 회귀 고정"]
	return ["장전 선택 이유와 예상 피해를 보고서에 기록", "동일 전투의 순서 반사실 대조 추가"]
