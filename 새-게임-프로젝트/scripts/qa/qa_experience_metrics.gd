class_name QAExperienceMetrics
extends RefCounted

const ReportScript := preload("res://scripts/qa/qa_experience_report.gd")


static func aggregate(report: Dictionary) -> Dictionary:
	var errors := ReportScript.validation_errors(report)
	if not errors.is_empty():
		return {"valid": false, "errors": errors}

	var total := 0
	var accepted := 0
	var invalid := 0
	var reloads := 0
	var decision_count := 0
	var choices: Dictionary = {}
	var category_choices: Dictionary = {}
	var minimum_distance = null
	var distance_samples := 0
	var overkill_total := 0
	var overkill_samples := 0
	var used_tactical: Dictionary = {}
	var observed_tactical: Dictionary = {}
	var part_choices: Array[String] = []
	var route_choices: Array[String] = []

	for record in report.actions:
		total += 1
		var is_accepted := bool(record.get("accepted", false))
		if is_accepted:
			accepted += 1
		else:
			invalid += 1
		if str(record.get("action", "")) == "reload":
			reloads += 1

		var choice_id := str(record.get("choice_id", ""))
		var category := str(record.get("category", ""))
		if is_accepted and not choice_id.is_empty() and category not in ["flow", "combat"]:
			if not category_choices.has(category):
				category_choices[category] = {}
			category_choices[category][choice_id] = \
				int(category_choices[category].get(choice_id, 0)) + 1
			# 한 탄창의 기본탄 슬롯 수는 전략 선택 횟수가 아니다. 장전 탄별 집계는
			# by_category.ammo에 보존하되 전체 선택 집중도에서는 제외한다.
			if category != "ammo":
				decision_count += 1
				choices[choice_id] = int(choices.get(choice_id, 0)) + 1
			if category == "part":
				part_choices.append(choice_id)
			elif category == "route":
				route_choices.append(choice_id)

		var tags: Array = record.get("tags", [])
		if is_accepted and tags.has("tactical_ammo") and not choice_id.is_empty():
			used_tactical[choice_id] = true
		var view: Dictionary = record.get("player_view", {})
		for ammo_entry in view.get("available_ammo", []):
			if ammo_entry is Dictionary and not bool(ammo_entry.get("bullet", {}).get("is_basic", false)):
				observed_tactical[str(ammo_entry.get("id", ""))] = true
		for enemy in view.get("enemies", []):
			if enemy is Dictionary and not bool(enemy.get("is_dead", false)):
				var distance := int(enemy.get("distance", 0))
				minimum_distance = distance if minimum_distance == null else mini(int(minimum_distance), distance)
				distance_samples += 1
		var outcome: Dictionary = record.get("outcome", {})
		if outcome.has("overkill_damage"):
			overkill_total += maxi(int(outcome.get("overkill_damage", 0)), 0)
			overkill_samples += 1

	var top_choice := ""
	var top_count := 0
	for choice_id in choices:
		if int(choices[choice_id]) > top_count:
			top_choice = str(choice_id)
			top_count = int(choices[choice_id])
	var concentration := float(top_count) / float(decision_count) if decision_count > 0 else 0.0

	var available_tactical: Array = observed_tactical.keys()
	# 합성 단위 테스트처럼 player_view에 탄약 카탈로그가 없는 과거 보고서만 시작 조건을 폴백한다.
	if available_tactical.is_empty():
		available_tactical = report.start_condition.get("tactical_ammo_ids", []).duplicate(true)
	var unused_tactical: Array[String] = []
	for ammo_id in available_tactical:
		if not used_tactical.has(str(ammo_id)):
			unused_tactical.append(str(ammo_id))

	var result := {
		"valid": true,
		"profile": str(report.profile),
		"action_counts": {
			"total": total,
			"accepted": accepted,
			"invalid": invalid,
			"reload": reloads,
			"invalid_ratio": _ratio(invalid, total),
			"reload_ratio": _ratio(reloads, total),
		},
		"selection": {
			"decision_count": decision_count,
			"top_choice": top_choice,
			"top_choice_count": top_count,
			"concentration": concentration,
			"counts": choices,
			"by_category": category_choices,
		},
		"pressure": {
			"minimum_distance": minimum_distance,
			"distance_samples": distance_samples,
		},
		"overkill": {
			"total_damage": overkill_total,
			"samples": overkill_samples,
		},
		"tactical_ammo": {
			"available": available_tactical.duplicate(true),
			"used": used_tactical.keys(),
			"unused": unused_tactical,
		},
		"parts": _duplicate_metric(part_choices),
		"routes": _duplicate_metric(route_choices),
	}
	result["judgments"] = _judgments(result)
	return result


static func _judgments(metrics: Dictionary) -> Array[Dictionary]:
	var judgments: Array[Dictionary] = []
	if int(metrics.selection.decision_count) >= 4 and float(metrics.selection.concentration) >= 0.6:
		judgments.append(_signal("choice_concentration", "choice", {
			"choice": metrics.selection.top_choice,
			"selected": metrics.selection.top_choice_count,
			"decisions": metrics.selection.decision_count,
			"share": metrics.selection.concentration,
		}))
	if float(metrics.action_counts.invalid_ratio) >= 0.1:
		judgments.append(_signal("invalid_action_repetition", "pacing", metrics.action_counts))
	if float(metrics.action_counts.reload_ratio) >= 0.3:
		judgments.append(_signal("reload_repetition", "pacing", metrics.action_counts))
	# 짧은 런에서 모든 전술탄을 쓰지 않는 것은 정상이다. 사용 가능했는데 한 발도
	# 선택하지 않은 경우만 '미사용' 신호로 올린다.
	if not metrics.tactical_ammo.available.is_empty() and metrics.tactical_ammo.used.is_empty():
		judgments.append(_signal("tactical_ammo_unused", "diversity", metrics.tactical_ammo))
	if int(metrics.parts.count) >= 2 and float(metrics.parts.repeat_ratio) >= 0.5:
		judgments.append(_signal("part_repetition", "diversity", metrics.parts))
	if int(metrics.routes.count) >= 2 and float(metrics.routes.repeat_ratio) >= 0.5:
		judgments.append(_signal("route_repetition", "diversity", metrics.routes))
	if int(metrics.overkill.samples) > 0 and int(metrics.overkill.total_damage) > 0:
		judgments.append(_signal("overkill_pressure", "choice", metrics.overkill))
	return judgments


static func _signal(signal_key: String, axis: String, evidence: Dictionary) -> Dictionary:
	return {
		"signal_key": signal_key,
		"axis": axis,
		"classification": "hypothesis",
		"evidence": evidence.duplicate(true),
	}


static func _duplicate_metric(values: Array[String]) -> Dictionary:
	var unique: Dictionary = {}
	for value in values:
		unique[value] = true
	var repeats := maxi(values.size() - unique.size(), 0)
	return {
		"count": values.size(),
		"unique_count": unique.size(),
		"repeat_count": repeats,
		"repeat_ratio": _ratio(repeats, values.size()),
		"choices": values.duplicate(),
	}


static func _ratio(numerator: int, denominator: int) -> float:
	return float(numerator) / float(denominator) if denominator > 0 else 0.0
