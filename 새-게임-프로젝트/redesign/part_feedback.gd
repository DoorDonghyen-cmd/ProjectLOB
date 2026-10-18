extends RefCounted
## Presentation observations only. No commands, RNG, or counterfactual HP totals.
const Content = preload("res://redesign/content.gd")
const PASSIVE := ["loader", "supply", "reserve", "field_press", "radiator", "cooling_breech"]

static func shot_effects(state: Dictionary, shot: Dictionary, conditional: Array, burn_before: int) -> Array:
	var effects: Array = []
	var id := str(shot.id)
	var spec: Dictionary = Content.AMMO[id]
	var unblocked := int(shot.hits) > int(shot.blocked_hits)
	if unblocked:
		for effect in conditional: effects.append(effect.duplicate())
	for part in Content.equipped_parts(state):
		var label := ""
		match part:
			"overbore":
				if unblocked and Content.is_heavy_attack(id): label = "중량 피해 +3"
			"lens":
				if unblocked and int(spec.pen) > 0 and int(shot.math.armor_before) > int(shot.pen) - 2: label = "관통 +2"
			"breaker":
				if int(shot.barrier_removed) > int(shot.blocked_hits): label = "보호 파쇄"
			"duplex":
				var direct_hits := int(shot.hits)
				for impact in shot.get("secondary",[]):
					if impact.get("kind","") == "relay": direct_hits += 1
				if Content.source_id(id) == "precise" and direct_hits > int(spec.get("hits", 2)): label = "타격 +1"
			"sequencer":
				if spec.effect == "boost" and int(spec.get("boost_factor", 1)) == 1: label = "증폭 +1"
			"coil", "inferno":
				var bonus := 1 if part == "coil" else 2
				# A capped or killed target must not claim extra burn duration.
				var without := mini(6, burn_before + int(spec.value) + (2 if part == "coil" and Content.has_part(state, "inferno") else 0) + (1 if part == "inferno" and Content.has_part(state, "coil") else 0))
				if spec.effect == "burn" and int(shot.burn_added) > 0 and int(shot.burn) > without:
					label = "화상 +%d" % mini(bonus, int(shot.burn) - without)
			"capacitor", "arc_splitter":
				# Applied enhancement, not additive credit for enemy HP removed.
				if spec.effect == "arc" and not shot.secondary.is_empty(): label = "전이 강화"
			"rammer", "momentum":
				if int(shot.push) > 0: label = "밀기 %dm" % int(shot.push)
		if not label.is_empty(): effects.append({"id": part, "label": label})
	return effects

static func slots(prediction: Dictionary, part: String) -> Array:
	var found: Array = []
	# Aggregated random previews do not promise a particular hidden target/trigger.
	if prediction.get("random", false): return found
	var shots: Array = prediction.get("shots", [])
	for i in range(shots.size()):
		for effect in shots[i].get("part_effects", []):
			if str(effect.id) == part:
				found.append(i + 1)
				break
	return found

static func readiness(prediction: Dictionary, part: String) -> String:
	if PASSIVE.has(part): return "장착 중 · " + str(Content.PARTS[part].upside)
	if prediction.get("pending", false): return "발동 예측 계산 중"
	if prediction.get("random", false):
		if part in ["reclaimer", "ember_core", "chain_sink", "indexer", "ordinary_chain", "compression_sink", "volley_drive", "thermal_drive", "siege_drive"]:
			var chances: PackedStringArray = []
			for i in range(prediction.get("shots", []).size()):
				var chance := float(prediction.shots[i].get("part_probabilities", {}).get(part, 0))
				if chance > 0: chances.append("%d번 %d%%" % [i + 1, roundi(chance * 100)])
			return "발동 예상 · " + " / ".join(chances) if not chances.is_empty() else "이번 발사에서 발동 없음"
		return "무작위 표적 · 실제 발사 후 발동 확인"
	var positions := slots(prediction, part)
	if positions.is_empty(): return "이번 발사에서 발동 없음"
	var labels: PackedStringArray = []
	for position in positions: labels.append(str(position))
	return "이번 발사 · " + "/".join(labels) + "번째 탄에서 발동 예상"

static func encounter_state(state: Dictionary) -> Dictionary:
	var result := state.duplicate(false)
	var history: Array = state.get("history", [])
	var start := 0
	for i in range(history.size() - 1, -1, -1):
		if str(history[i].get("action", "")) == "encounter":
			start = i
			break
	result.history = history.slice(start)
	return result

static func highlights(state: Dictionary) -> Array:
	var counts: Dictionary = {}
	var focus := 0
	var boosted := 0
	for event in encounter_state(state).get("history", []):
		if str(event.get("action", "")) != "fire": continue
		for shot in event.get("detail", {}).get("results", []):
			for effect in shot.get("part_effects", []):
				var id := str(effect.id)
				counts[id] = int(counts.get(id, 0)) + 1
			focus += int(shot.get("focus_damage", 0))
			if int(shot.get("math", {}).get("boost", 0)) > 0 and int(shot.get("hits", 0)) > int(shot.get("blocked_hits", 0)): boosted += 1
	var ids: Array = counts.keys()
	ids.sort_custom(func(a, b):
		var conditional := ["triad", "igniter", "opening", "afterburner", "executioner", "reclaimer", "ember_core"]
		if conditional.has(a) != conditional.has(b): return conditional.has(a)
		if int(counts[a]) != int(counts[b]): return int(counts[a]) > int(counts[b])
		return str(a) < str(b)
	)
	var result: Array = []
	for id in ids.slice(0, 2): result.append({"id": id, "text": "%s · %d발 발동" % [Content.PARTS[id].name, counts[id]]})
	if result.size() < 2 and focus > 0: result.append({"id": "", "text": "집중 추가 피해 %d" % focus})
	if result.size() < 2 and boosted > 0: result.append({"id": "", "text": "증폭 연계 %d발" % boosted})
	return result
