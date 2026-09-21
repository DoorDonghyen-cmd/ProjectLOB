extends RefCounted
## Conditional forecast: keep firing this magazine, with no reload in between.
## Execute real commands on an isolated copy, including single-shot movement.
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
static var cached_key := ""
static var cached_result: Dictionary = {}

static func analyze(state: Dictionary) -> Dictionary:
	if state.gun == "scatter" and state.phase in ["plan", "ready"]: return random_analyze(state)
	var copy = Model.new()
	copy.s = state.duplicate(true)
	var shots: Array = []
	var advance_events: Array = []
	var deployments: Array = []
	var initial_turns: int = copy.s.turns
	if copy.s.phase == "plan": copy.confirm()
	for action in range(copy.capacity()):
		if not copy.fire(): break
		for result in copy.s.history.back().detail.results:
			var shot: Dictionary = result.duplicate(true)
			shot.action = action
			shots.append(shot)
		for event_value in copy.s.history.back().detail.get("advance_events", []):
			var event: Dictionary = event_value.duplicate(true)
			event.action = action
			advance_events.append(event)
		for deployment_value in copy.s.history.back().detail.get("deployments", []):
			var deployment: Dictionary = deployment_value.duplicate(true)
			deployment.action = action
			deployments.append(deployment)
	return {"shots": shots, "advance_events": advance_events, "deployments": deployments, "phase": copy.s.phase, "remaining": copy.s.magazine.duplicate(), "turns": int(copy.s.turns) - initial_turns, "enemies": copy.s.enemies.duplicate(true), "reserve": copy.s.get("reinforcements", []).duplicate(true), "wave": int(copy.s.get("wave", 1))}

static func random_analyze(state: Dictionary) -> Dictionary:
	var stack: Array = state.plan if state.phase == "plan" else state.magazine
	var key := JSON.stringify([state.gun, state.part, state.floor, state.phase, state.enemies, state.get("reinforcements", []), state.buff, state.push_left, stack])
	if key == cached_key: return cached_result.duplicate(true)
	var initial: Dictionary = state.duplicate()
	initial.history = []
	initial = initial.duplicate(true)
	initial.magazine = stack.duplicate()
	var branches: Array = [{"state": initial, "p": 1.0}]
	var shots: Array = []
	for id in stack:
		var merged: Dictionary = {}
		var spec: Dictionary = Content.AMMO[id]
		var shot := {"id": id, "random": true, "target": -1, "damage": 0, "damage_min": 1000000, "damage_max": 0, "expected_damage": 0.0, "hp": -1, "hits": int(spec.get("hits", 2 if spec.effect == "double" else 1)), "targets": [], "secondary": [], "used_probability": 0.0}
		var target_stats: Dictionary = {}
		for branch in branches:
			var alive: Array = []
			for i in range(branch.state.enemies.size()):
				if int(branch.state.enemies[i].hp) > 0: alive.append(i)
			if alive.is_empty():
				var stopped_key := JSON.stringify([branch.state.enemies, branch.state.get("reinforcements", []), branch.state.buff, branch.state.push_left, branch.state.magazine])
				if merged.has(stopped_key): merged[stopped_key].p += branch.p
				else: merged[stopped_key] = branch
				continue
			for target in alive:
				var copy = Model.new()
				copy.s = branch.state.duplicate(true)
				copy.s.magazine.pop_front()
				if int(copy.s.buff.get("dmg", 0)) > 0: shot.boosted = true
				var actual: Dictionary = copy._shot(str(id), int(target))
				copy._discard_fired_round(str(id))
				var probability: float = float(branch.p) / alive.size()
				shot.damage_min = mini(int(shot.damage_min), int(actual.damage))
				shot.damage_max = maxi(int(shot.damage_max), int(actual.damage))
				shot.expected_damage += int(actual.damage) * probability
				shot.used_probability += probability
				if not target_stats.has(target): target_stats[target] = {"target": target, "probability": 0.0, "damage_min": int(actual.damage), "damage_max": int(actual.damage)}
				target_stats[target].probability += probability
				target_stats[target].damage_min = mini(int(target_stats[target].damage_min), int(actual.damage))
				target_stats[target].damage_max = maxi(int(target_stats[target].damage_max), int(actual.damage))
				var branch_key := JSON.stringify([copy.s.enemies, copy.s.get("reinforcements", []), copy.s.buff, copy.s.push_left, copy.s.magazine])
				if merged.has(branch_key): merged[branch_key].p += probability
				else: merged[branch_key] = {"state": copy.s, "p": probability}
		if float(shot.used_probability) < 0.999999: shot.damage_min = 0
		if int(shot.damage_min) == 1000000: shot.damage_min = 0
		shot.damage = shot.damage_min
		shot.targets = target_stats.values()
		shots.append(shot)
		branches = merged.values()
	var enemies: Array = state.enemies.duplicate(true)
	for e in enemies:
		e.hp_min = int(e.hp)
		e.hp_max = 0
		e.distance_min = int(e.distance) + Content.push_budget(state)
		e.distance_max = 0
		e.kill_probability = 0.0
	var win_probability := 0.0
	var lost_probability := 0.0
	var deployment_min := 99999
	var deployment_max := 0
	var expected_deployments := 0.0
	for branch in branches:
		var copy = Model.new()
		copy.s = branch.state
		if not stack.is_empty() and copy.target_index() >= 0: copy._advance(1)
		var deployed := 0
		if copy.s.phase != "lost" and copy.reserve_count() > 0:
			deployed = copy._deploy_reinforcements(copy.target_index() < 0).size()
		deployment_min = mini(deployment_min, deployed)
		deployment_max = maxi(deployment_max, deployed)
		expected_deployments += deployed * float(branch.p)
		if not copy.has_remaining_enemies() and copy.s.phase != "lost": win_probability += float(branch.p)
		if copy.s.phase == "lost": lost_probability += float(branch.p)
		for i in range(enemies.size()):
			var e: Dictionary = copy.s.enemies[i]
			enemies[i].hp_min = mini(int(enemies[i].hp_min), int(e.hp))
			enemies[i].hp_max = maxi(int(enemies[i].hp_max), int(e.hp))
			enemies[i].distance_min = mini(int(enemies[i].distance_min), int(e.distance))
			enemies[i].distance_max = maxi(int(enemies[i].distance_max), int(e.distance))
			if int(e.hp) <= 0: enemies[i].kill_probability += float(branch.p)
	if deployment_min == 99999: deployment_min = 0
	var result := {"random": true, "shots": shots, "advance_events": [], "deployments": [], "deployment_min": deployment_min, "deployment_max": deployment_max, "expected_deployments": expected_deployments, "phase": "uncertain", "remaining": [], "turns": 1 if not stack.is_empty() else 0, "enemies": enemies, "reserve": state.get("reinforcements", []).duplicate(true), "win_probability": win_probability, "lost_probability": lost_probability, "branches": branches.size()}
	cached_key = key
	cached_result = result.duplicate(true)
	return result

static func tag(index: int) -> String:
	return String.chr(65 + index)

static func outcome(shot: Dictionary) -> String:
	if shot.get("random", false): return "%d~%d" % [shot.damage_min, shot.damage_max]
	if not shot.hit: return "빗나감"
	if int(shot.get("blocked_hits", 0)) > 0 and int(shot.damage) == 0: return "배리어 −%d" % int(shot.blocked_hits)
	if int(shot.damage) == 0: return "도탄"
	if int(shot.hp) == 0: return "처치"
	return "−%d · HP %d" % [shot.damage, shot.hp]

static func burn_ticks_for_shot(forecast: Dictionary, shot_index: int) -> int:
	if shot_index < 0 or shot_index >= forecast.get("shots", []).size(): return 0
	var shot: Dictionary = forecast.shots[shot_index]
	if int(shot.get("burn_added", 0)) <= 0: return 0
	var ticks := 0
	for event in forecast.get("advance_events", []):
		if str(event.get("kind", "")) == "burn" and int(event.get("target", -1)) == int(shot.target) and int(event.get("action", -1)) >= int(shot.action):
			ticks += 1
	return ticks

static func note(forecast: Dictionary, shot_index: int) -> String:
	if shot_index < 0 or shot_index >= forecast.get("shots", []).size(): return ""
	var shot: Dictionary = forecast.shots[shot_index]
	if shot.get("random", false): return "무작위 표적"
	if int(shot.get("blocked_hits", 0)) > 0:
		return "배리어 −%d%s" % [int(shot.blocked_hits), " · HP −%d" % int(shot.damage) if int(shot.damage) > 0 else ""]
	if int(shot.get("focus_damage", 0)) > 0: return "집중 +%d" % shot.focus_damage
	var boosted := int(shot.get("math", {}).get("boost", 0)) > 0
	var secondary: Array = shot.get("secondary", [])
	if not secondary.is_empty():
		var impacts: PackedStringArray = []
		for other in secondary:
			impacts.append("%s %s −%d" % [tag(other.target), "확산" if other.get("kind", "arc") == "spread" else "전이", other.damage])
		return ("증폭 · " if boosted else "") + " / ".join(impacts)
	if int(shot.get("math", {}).get("overflow", 0)) > 0:
		return ("증폭 · 2타 · " if boosted and int(shot.hits) > 1 else ("증폭 · " if boosted else "")) + "초과 관통 +%d" % shot.math.overflow
	if int(shot.get("burn_added", 0)) > 0:
		var ticks := burn_ticks_for_shot(forecast, shot_index)
		return "화상 %d회 예상" % ticks if ticks > 0 else "화상 +%d" % shot.burn_added
	if int(shot.get("push", 0)) > 0:
		return "거리 +%dm" % shot.push
	if boosted and int(shot.get("hits", 1)) > 1:
		return "증폭 · %d타" % int(shot.hits)
	if boosted:
		return "증폭 적용"
	if int(shot.get("hits", 1)) > 1:
		return "%d회 타격" % int(shot.hits)
	if Content.AMMO.has(str(shot.get("id", ""))) and str(Content.AMMO[str(shot.id)].effect) == "boost":
		return "다음 2발 +%d" % int(shot.get("boost_granted", 2))
	return ""

static func is_combo_link(forecast: Dictionary, shot_index: int) -> bool:
	if shot_index <= 0 or shot_index >= forecast.get("shots", []).size(): return false
	if forecast.shots[shot_index].get("random", false): return forecast.shots[shot_index].get("boosted", false)
	return int(forecast.shots[shot_index].get("math", {}).get("boost", 0)) > 0

static func summary(forecast: Dictionary) -> String:
	if forecast.is_empty(): return "탄환을 눌러 장전하세요"
	if forecast.get("random", false):
		var ranges: PackedStringArray = []
		for i in range(forecast.enemies.size()):
			var e: Dictionary = forecast.enemies[i]
			ranges.append("%s HP%d~%d" % [tag(i), e.hp_min, e.hp_max])
		ranges.append("전멸 %d%%" % floori(minf(1.0, float(forecast.win_probability) + 0.0000001) * 100))
		if float(forecast.lost_probability) > 0: ranges.append("접촉 %d%%" % ceili(float(forecast.lost_probability) * 100 - 0.0000001))
		return " · ".join(ranges)
	var parts: PackedStringArray = []
	var nearest := 99999
	for i in range(forecast.get("enemies", []).size()):
		var enemy: Dictionary = forecast.enemies[i]
		if int(enemy.hp) <= 0:
			parts.append("%s 처치" % tag(i))
		else:
			parts.append("%s %sHP %d" % [tag(i), "◆%d · " % int(enemy.get("barrier", 0)) if int(enemy.get("barrier", 0)) > 0 else "", enemy.hp])
			nearest = mini(nearest, int(enemy.distance))
	if str(forecast.get("phase", "")) == "lost":
		parts.append("접촉 위험")
	elif nearest < 99999:
		parts.append("안전 %dm" % nearest)
	else:
		parts.append("전투 종료")
	return " · ".join(parts)

static func compact_summary(forecast: Dictionary) -> String:
	if forecast.is_empty(): return "탄환을 넣으면 결과가 표시됩니다"
	if forecast.get("random", false):
		var random_text := "전멸 %d%%" % floori(minf(1.0, float(forecast.get("win_probability", 0.0)) + 0.0000001) * 100)
		if int(forecast.get("deployment_max", 0)) > 0:
			random_text += " · 증원 +%d~%d" % [int(forecast.get("deployment_min", 0)), int(forecast.get("deployment_max", 0))]
		if float(forecast.get("lost_probability", 0.0)) > 0.0:
			random_text += " · 충돌 %d%%" % ceili(float(forecast.lost_probability) * 100.0 - 0.0000001)
		return random_text
	var kills := 0
	var survivors := 0
	var nearest := 99999
	for enemy in forecast.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0:
			kills += 1
		else:
			survivors += 1
			nearest = mini(nearest, int(enemy.get("distance", 0)))
	var result_text := "처치 %d · 전열 %d" % [kills, survivors]
	if not forecast.get("deployments", []).is_empty():
		result_text += " · 증원 +%d" % forecast.deployments.size()
	if str(forecast.get("phase", "")) == "lost":
		result_text += " · 충돌"
	elif nearest < 99999:
		result_text += " · 최근접 %dm" % nearest
	else:
		result_text += " · 전투 종료"
	return result_text