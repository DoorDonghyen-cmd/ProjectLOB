extends RefCounted
## Conditional forecast: keep firing this magazine, with no reload in between.
## Execute real commands on an isolated copy, including single-shot movement.
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const Ranged = preload("res://redesign/ranged.gd")
static var cached_key := ""
static var cached_result: Dictionary = {}

static func analyze(state: Dictionary, next_action_only: bool = false, include_reload: bool = false) -> Dictionary:
	if state.gun == "scatter" and state.phase in ["plan", "ready"]: return random_analyze(state, include_reload)
	var copy = Model.new()
	copy.s = state.duplicate(true)
	var shots: Array = []
	var advance_events: Array = []
	var deployments: Array = []
	var initial_turns: int = copy.s.turns
	if copy.s.phase == "plan": copy.confirm()
	for action in range(1 if next_action_only else copy.capacity()):
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
	var result := {"shots": shots, "advance_events": advance_events, "deployments": deployments, "phase": copy.s.phase, "remaining": copy.s.magazine.duplicate(), "turns": int(copy.s.turns) - initial_turns, "enemies": copy.s.enemies.duplicate(true), "reserve": copy.s.get("reinforcements", []).duplicate(true), "wave": int(copy.s.get("wave", 1))}
	result.projectiles = copy.s.get("projectiles", []).duplicate(true)
	if include_reload: result.reload = reload_now(copy.s)
	return result

static func random_analyze(state: Dictionary, include_reload: bool = false) -> Dictionary:
	var stack: Array = state.plan if state.phase == "plan" else state.magazine
	var source_model = Model.new()
	source_model.s = state
	var recent: Array = source_model._recent_part_sources() if state.phase == "ready" else []
	var key := JSON.stringify([state.gun, Content.equipped_parts(state), state.floor, state.phase, state.enemies, state.get("reinforcements", []), state.buff, state.push_left, stack, recent, state.get("reload_heat", 0), state.get("projectiles", []), state.get("projectile_serial", 0), include_reload])
	if key == cached_key: return cached_result.duplicate(true)
	var initial: Dictionary = state.duplicate()
	initial.history = []
	initial = initial.duplicate(true)
	initial.magazine = stack.duplicate()
	var branches: Array = [{"state": initial, "p": 1.0}]
	var shots: Array = []
	for id in stack:
		var source := Content.source_id(str(id))
		var context := {"first": recent.is_empty(), "last": shots.size() == stack.size() - 1, "triad": recent.size() >= 2 and recent[-1] != recent[-2] and source != recent[-1] and source != recent[-2]}
		var merged: Dictionary = {}
		var shot := {"id": id, "random": true, "target": -1, "damage": 0, "damage_min": 1000000, "damage_max": 0, "expected_damage": 0.0, "hp": -1, "hits": Content.hit_count(str(id), state), "targets": [], "secondary": [], "used_probability": 0.0}
		var target_stats: Dictionary = {}
		for branch in branches:
			var targets_model = Model.new()
			targets_model.s = branch.state
			var alive: Array = targets_model.scatter_targets()
			if alive.is_empty():
				var stopped_key := JSON.stringify([branch.state.enemies, branch.state.get("reinforcements", []), branch.state.buff, branch.state.push_left, branch.state.magazine, branch.state.get("reload_heat", 0), branch.state.get("projectiles", []), branch.state.get("projectile_serial", 0)])
				if merged.has(stopped_key): merged[stopped_key].p += branch.p
				else: merged[stopped_key] = branch
				continue
			for target in alive:
				var copy = Model.new()
				copy.s = branch.state.duplicate(true)
				copy.s.magazine.pop_front()
				if int(copy.s.buff.get("dmg", 0)) > 0: shot.boosted = true
				var actual: Dictionary = copy._shot(str(id), int(target), context)
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
				var branch_key := JSON.stringify([copy.s.enemies, copy.s.get("reinforcements", []), copy.s.buff, copy.s.push_left, copy.s.magazine, copy.s.get("reload_heat", 0), copy.s.get("projectiles", []), copy.s.get("projectile_serial", 0)])
				if merged.has(branch_key): merged[branch_key].p += probability
				else: merged[branch_key] = {"state": copy.s, "p": probability}
		if float(shot.used_probability) < 0.999999: shot.damage_min = 0
		if int(shot.damage_min) == 1000000: shot.damage_min = 0
		shot.damage = shot.damage_min
		shot.targets = target_stats.values()
		shot.intercept_probability = 0.0
		for candidate in shot.targets:
			if Ranged.is_projectile(int(candidate.target)): shot.intercept_probability += float(candidate.probability)
		shots.append(shot)
		recent.append(source)
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
	var reload_branches: Array = []
	var hazard_branches: Array = []
	for branch in branches:
		var copy = Model.new()
		copy.s = branch.state
		if not stack.is_empty():
			copy.s.phase = "ready"
			copy.s.turns += 1
		if not stack.is_empty() and copy.target_index() >= 0: copy._advance(1)
		var deployed := 0
		if copy.s.phase != "lost" and copy.reserve_count() > 0:
			deployed = copy._deploy_reinforcements(copy.alive_count() == 0).size()
		deployment_min = mini(deployment_min, deployed)
		deployment_max = maxi(deployment_max, deployed)
		expected_deployments += deployed * float(branch.p)
		if not copy.has_remaining_enemies() and copy.s.phase != "lost": win_probability += float(branch.p)
		if copy.s.phase == "lost": lost_probability += float(branch.p)
		hazard_branches.append({"result": copy.s, "p": branch.p})
		if include_reload:
			if not copy.has_remaining_enemies() and copy.s.phase != "lost":
				copy.s.phase = "won" if int(copy.s.floor) == Content.ENCOUNTERS.size() - 1 else "reward"
			if copy.s.phase in ["won", "reward", "lost"]: copy.s.reload_heat = 0
			reload_branches.append({"result": reload_now(copy.s), "p": branch.p})
		for i in range(enemies.size()):
			var e: Dictionary = copy.s.enemies[i]
			enemies[i].hp_min = mini(int(enemies[i].hp_min), int(e.hp))
			enemies[i].hp_max = maxi(int(enemies[i].hp_max), int(e.hp))
			enemies[i].distance_min = mini(int(enemies[i].distance_min), int(e.distance))
			enemies[i].distance_max = maxi(int(enemies[i].distance_max), int(e.distance))
			if int(e.hp) <= 0: enemies[i].kill_probability += float(branch.p)
	if deployment_min == 99999: deployment_min = 0
	var result := {"random": true, "shots": shots, "advance_events": [], "deployments": [], "deployment_min": deployment_min, "deployment_max": deployment_max, "expected_deployments": expected_deployments, "phase": "uncertain", "remaining": [], "turns": 1 if not stack.is_empty() else 0, "enemies": enemies, "reserve": state.get("reinforcements", []).duplicate(true), "win_probability": win_probability, "lost_probability": lost_probability, "branches": branches.size()}
	result.projectiles = _projectile_ranges(hazard_branches)
	if include_reload: result.reload = _reload_ranges(reload_branches)
	cached_key = key
	cached_result = result.duplicate(true)
	return result

## The same real reload command drives both costs and post-reload positions.
## Calling it on a duplicate also includes burn, stance, charge and deployment.
static func reload_now(state: Dictionary) -> Dictionary:
	var copy = Model.new()
	copy.s = state.duplicate(true)
	var cost: int = copy.reload_cost()
	var base: int = copy.base_reload_cost()
	var heat := int(copy.s.get("reload_heat", 0))
	var before := int(copy.s.turns)
	var required: bool = copy.reload_magazine()
	return {"required": required, "cost": cost if required else 0, "base": base, "heat": heat if required else 0, "phase": copy.s.phase, "turns": int(copy.s.turns) - before, "enemies": copy.s.enemies.duplicate(true), "projectiles": copy.s.get("projectiles", []).duplicate(true), "loss_reason": copy.s.get("loss_reason", "")}

static func _reload_ranges(branches: Array) -> Dictionary:
	var result := {"random": true, "required_probability": 0.0, "lost_probability": 0.0, "win_probability": 0.0, "cost_min": 1000000, "cost_max": 0, "heat_min": 1000000, "heat_max": 0, "enemies": []}
	var enemies: Dictionary = {}
	for branch in branches:
		var outcome: Dictionary = branch.result
		var probability := float(branch.p)
		if outcome.required:
			result.required_probability += probability
			result.cost_min = mini(result.cost_min, int(outcome.cost))
			result.cost_max = maxi(result.cost_max, int(outcome.cost))
			result.heat_min = mini(result.heat_min, int(outcome.heat))
			result.heat_max = maxi(result.heat_max, int(outcome.heat))
		if outcome.phase == "lost": result.lost_probability += probability
		if outcome.phase in ["won", "reward"]: result.win_probability += probability
		for i in range(outcome.enemies.size()):
			var enemy: Dictionary = outcome.enemies[i]
			if not enemies.has(i):
				enemies[i] = {"target": i, "hp_min": int(enemy.hp), "hp_max": int(enemy.hp), "distance_min": int(enemy.distance), "distance_max": int(enemy.distance), "alive_probability": 0.0}
			var entry: Dictionary = enemies[i]
			entry.hp_min = mini(entry.hp_min, int(enemy.hp))
			entry.hp_max = maxi(entry.hp_max, int(enemy.hp))
			entry.distance_min = mini(entry.distance_min, int(enemy.distance))
			entry.distance_max = maxi(entry.distance_max, int(enemy.distance))
			if int(enemy.hp) > 0: entry.alive_probability += probability
	if result.cost_min == 1000000: result.cost_min = 0
	if result.heat_min == 1000000: result.heat_min = 0
	result.enemies = enemies.values()
	result.projectiles = _projectile_ranges(branches)
	return result

static func _projectile_ranges(branches: Array) -> Array:
	var found: Dictionary = {}
	for branch in branches:
		for projectile in branch.result.get("projectiles", []):
			var uid := int(projectile.uid)
			if not found.has(uid): found[uid] = {"uid": uid, "target": Ranged.target_id(projectile), "hp_min": 1, "hp_max": 0, "distance_min": 1000000, "distance_max": 0, "alive_probability": 0.0}
	for uid in found:
		var row: Dictionary = found[uid]
		for branch in branches:
			var matches: Array = branch.result.get("projectiles", []).filter(func(p): return int(p.uid) == int(uid))
			if matches.is_empty():
				row.hp_min = 0
				continue
			var projectile: Dictionary = matches[0]
			row.hp_min = mini(row.hp_min, int(projectile.hp))
			row.hp_max = maxi(row.hp_max, int(projectile.hp))
			row.distance_min = mini(row.distance_min, int(projectile.distance))
			row.distance_max = maxi(row.distance_max, int(projectile.distance))
			if int(projectile.hp) > 0: row.alive_probability += float(branch.p)
	return found.values()

static func tag(index: int) -> String:
	if Ranged.is_projectile(index): return "요격"
	return String.chr(65 + index)

static func outcome(shot: Dictionary) -> String:
	if shot.get("intercept", false): return "요격"
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
	if float(shot.get("intercept_probability", 0)) >= 0.999999: return "확정 요격"
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
	for projectile in forecast.get("projectiles", []):
		if int(projectile.get("hp", 0)) > 0: nearest = mini(nearest, int(projectile.distance))
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
	var incoming := Ranged.active(forecast)
	if not incoming.is_empty():
		result_text += " · 압력탄 %d턴" % Ranged.arrival(incoming[0])
		nearest = mini(nearest, int(incoming[0].distance))
	if not forecast.get("deployments", []).is_empty():
		result_text += " · 증원 +%d" % forecast.deployments.size()
	if str(forecast.get("phase", "")) == "lost":
		result_text += " · 충돌"
	elif nearest < 99999:
		result_text += " · 최근접 %dm" % nearest
	else:
		result_text += " · 전투 종료"
	return result_text
