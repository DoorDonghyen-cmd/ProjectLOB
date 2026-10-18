extends RefCounted
## Conditional forecast: fire this magazine until an enemy or heat limit stops it.
## Mandatory overheat reload is included; optional manual reload is separate.
## Execute real commands on an isolated copy, including single-shot movement.
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const Ranged = preload("res://redesign/ranged.gd")
static var cache_lock := Mutex.new()
static var cached_key := ""
static var cached_result: Dictionary = {}

static func analyze(state: Dictionary, next_action_only: bool = false, include_reload: bool = false, cancelled: Callable = Callable()) -> Dictionary:
	if state.gun == "scatter" and state.phase in ["plan", "ready"]: return random_analyze(state, include_reload, cancelled)
	var copy = Model.new()
	copy.s = state.duplicate(true)
	var shots: Array = []
	var advance_events: Array = []
	var deployments: Array = []
	var initial_turns: int = copy.s.turns
	var heat_peak := int(state.get("heat", 0))
	var overheat := false
	var forced_cost := 0
	if copy.s.phase == "plan": copy.confirm()
	for action in range(1 if next_action_only else copy.capacity()):
		if not copy.fire(): break
		var detail: Dictionary = copy.s.history.back().detail
		heat_peak = maxi(heat_peak, int(detail.get("heat_peak", 0)))
		overheat = overheat or bool(detail.get("overheated", false))
		forced_cost += int(detail.get("forced_reload", {}).get("cost", 0))
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
	result.heat = _heat_ranges(state, [{"p": 1.0, "peak": heat_peak, "end": int(copy.s.get("heat", 0)), "overheated": overheat, "forced_cost": forced_cost, "fired": shots.size(), "turns": int(copy.s.turns) - initial_turns}])
	result.projectiles = copy.s.get("projectiles", []).duplicate(true)
	if include_reload: result.reload = reload_now(copy.s)
	return result

static func random_analyze(state: Dictionary, include_reload: bool = false, cancelled: Callable = Callable()) -> Dictionary:
	var stack: Array = state.plan if state.phase == "plan" else state.magazine
	var source_model = Model.new()
	source_model.s = state
	var recent: Array = source_model._recent_part_sources() if state.phase == "ready" else []
	var rounds: Array = source_model._recent_part_rounds() if state.phase == "ready" else []
	var previous_round: String = str(rounds.back()) if not rounds.is_empty() else ""
	var key := JSON.stringify([state.get("ammo_cycle", 0), state.gun, Content.equipped_parts(state), state.get("capacity_bonus", 0), state.get("prepared", []), state.floor, state.phase, state.enemies, state.get("reinforcements", []), state.buff, state.push_left, stack, recent, previous_round, state.get("heat", 0), state.get("legacy_reload_penalty", 0), state.get("projectiles", []), state.get("projectile_serial", 0), state.get("previous_kill", false), state.get("engine",{}), include_reload])
	cache_lock.lock()
	if key == cached_key:
		var cached := cached_result.duplicate(true)
		cache_lock.unlock()
		return cached
	cache_lock.unlock()
	var prepared = Model.new()
	prepared.s = state.duplicate(true)
	if prepared.s.phase == "plan": prepared.confirm()
	prepared.s.history = []
	var initial: Dictionary = prepared.s
	var heat_limit := Content.heat_limit(state)
	var branches: Array = [{"state": initial, "p": 1.0, "peak": int(state.get("heat", 0))}]
	var shots: Array = []
	for id in stack:
		var source := Content.source_id(str(id))
		var context := {"first": recent.is_empty(), "last": shots.size() == stack.size() - 1, "triad": recent.size() >= 2 and recent[-1] != recent[-2] and source != recent[-1] and source != recent[-2]}
		context.previous_round = previous_round
		context.fired_count = recent.size()
		context.sequence_count = Content.prior_kind_count(recent, str(id))
		context.profile = Model.shot_profile(str(id), state)
		context.forecast_minimal = true
		var merged: Dictionary = {}
		var shot := {"id": id, "random": true, "target": -1, "damage": 0, "damage_min": 1000000, "damage_max": 0, "expected_damage": 0.0, "hp": -1, "hits": Content.hit_count(str(id), state), "targets": [], "secondary": [], "used_probability": 0.0, "overheat_probability": 0.0, "heat_min": 1000000, "heat_max": 0, "part_probabilities": {"reclaimer": 0.0, "ember_core": 0.0}}
		var target_stats: Dictionary = {}
		shot.effect_probability = 0.0
		shot.prepared_rounds = []
		for branch in branches:
			if cancelled.is_valid() and cancelled.call(): return {}
			var targets_model = Model.new()
			targets_model.s = branch.state
			var alive: Array = targets_model.scatter_targets(str(id))
			if alive.is_empty() or int(branch.state.get("heat", 0)) >= heat_limit:
				var stopped_key := _shot_branch_key(branch.state)
				stopped_key.append(int(branch.peak))
				if merged.has(stopped_key): merged[stopped_key].p += branch.p
				else: merged[stopped_key] = branch
				continue
			for target in alive:
				var copy = Model.new()
				copy.s = _fork_shot_state(branch.state)
				copy.s.magazine.pop_front()
				var applied_boost := preload("res://redesign/attack_boosts.gd").resolve(copy.s.buff, int(copy.s.get("heat",0)), Content.hot_threshold(copy.s))
				if Content.is_attack(str(id)) and (int(applied_boost.dmg) > 0 or int(applied_boost.factor) > 1): shot.boosted = true
				var actual: Dictionary = copy._shot(str(id), int(target), context)
				copy._discard_fired_round(str(id))
				var probability: float = float(branch.p) / alive.size()
				shot.damage_min = mini(int(shot.damage_min), int(actual.damage))
				shot.damage_max = maxi(int(shot.damage_max), int(actual.damage))
				shot.expected_damage += int(actual.damage) * probability
				shot.used_probability += probability
				shot.heat_min = mini(int(shot.heat_min), int(actual.heat_after))
				shot.heat_max = maxi(int(shot.heat_max), int(actual.heat_after))
				for pair in [["ordinary_chain", "ordinary_bonus"], ["compression_sink", "relay_saved"]]:
					if int(actual.get(pair[1], 0)) > 0: shot.part_probabilities[pair[0]] = float(shot.part_probabilities.get(pair[0], 0)) + probability
				if not str(actual.get("engine_id","")).is_empty() and int(actual.damage)+int(actual.get("relay_damage",0))>0: shot.part_probabilities[actual.engine_id] = float(shot.part_probabilities.get(actual.engine_id,0))+probability
				if actual.overheated: shot.overheat_probability += probability
				if int(actual.get("kill_cooled", 0)) > 0: shot.part_probabilities.reclaimer += probability
				if bool(actual.get("part_hot", false)): shot.part_probabilities.ember_core += probability
				if int(actual.get("chain_cooled", 0)) > 0: shot.part_probabilities["chain_sink"] = float(shot.part_probabilities.get("chain_sink", 0)) + probability
				if actual.get("prepared_rounds", []).size() > Content.multiplier(state): shot.part_probabilities["indexer"] = float(shot.part_probabilities.get("indexer", 0)) + probability
				if int(actual.get("interrupted", 0)) > 0 or int(actual.get("transferred", 0)) > 0 or int(actual.get("sequence_bonus", 0)) > 0 or not actual.get("prepared_rounds", []).is_empty(): shot.effect_probability += probability
				if not actual.get("prepared_rounds", []).is_empty(): shot.prepared_rounds = actual.prepared_rounds.duplicate()
				if not target_stats.has(target): target_stats[target] = {"target": target, "probability": 0.0, "damage_min": int(actual.damage), "damage_max": int(actual.damage)}
				target_stats[target].probability += probability
				target_stats[target].damage_min = mini(int(target_stats[target].damage_min), int(actual.damage))
				target_stats[target].damage_max = maxi(int(target_stats[target].damage_max), int(actual.damage))
				var peak := maxi(int(branch.peak), int(actual.heat_after))
				var branch_key := _shot_branch_key(copy.s)
				branch_key.append(peak)
				if merged.has(branch_key): merged[branch_key].p += probability
				else: merged[branch_key] = {"state": copy.s, "p": probability, "peak": peak}
		if float(shot.used_probability) < 0.999999: shot.damage_min = 0
		if int(shot.damage_min) == 1000000: shot.damage_min = 0
		shot.damage = shot.damage_min
		shot.targets = target_stats.values()
		shot.intercept_probability = 0.0
		for candidate in shot.targets:
			if Ranged.is_projectile(int(candidate.target)): shot.intercept_probability += float(candidate.probability)
		if int(shot.heat_min) == 1000000: shot.heat_min = 0
		shots.append(shot)
		previous_round = str(id)
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
	var heat_branches: Array = []
	for branch in branches:
		if cancelled.is_valid() and cancelled.call(): return {}
		var copy = Model.new()
		copy.s = branch.state.duplicate(true)
		copy.forecast_only = true
		var turns_before := int(copy.s.turns)
		var fired: int = stack.size() - copy.s.magazine.size()
		var hot := int(copy.s.get("heat", 0)) >= heat_limit
		var detail: Dictionary = copy.finish_fire() if not stack.is_empty() else {}
		var forced: Dictionary = detail.get("forced_reload", {})
		var deployed: int = detail.get("deployments", []).size() + forced.get("deployments", []).size()
		heat_branches.append({"p": branch.p, "peak": int(branch.peak), "end": int(copy.s.get("heat", 0)), "overheated": hot, "forced_cost": int(forced.get("cost", 0)), "fired": fired, "turns": int(copy.s.turns) - turns_before})
		deployment_min = mini(deployment_min, deployed)
		deployment_max = maxi(deployment_max, deployed)
		expected_deployments += deployed * float(branch.p)
		if not copy.has_remaining_enemies() and copy.s.phase != "lost": win_probability += float(branch.p)
		if copy.s.phase == "lost": lost_probability += float(branch.p)
		hazard_branches.append({"result": copy.s, "p": branch.p})
		if include_reload:
			if not copy.has_remaining_enemies() and copy.s.phase != "lost":
				copy.s.phase = "won" if int(copy.s.floor) == Content.ENCOUNTERS.size() - 1 else "reward"
			if copy.s.phase in ["won", "reward", "lost"]: copy.s.heat = 0
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
	result.heat = _heat_ranges(state, heat_branches)
	result.turns = result.heat.turns_max
	result.projectiles = _projectile_ranges(hazard_branches)
	if include_reload: result.reload = _reload_ranges(reload_branches)
	cache_lock.lock()
	cached_key = key
	cached_result = result.duplicate(true)
	cache_lock.unlock()
	return result

# During the bullet phase only these collections can mutate. Static deck, draw,
# history and reserves are shared read-only; turn resolution takes a full copy.
static func _fork_shot_state(state: Dictionary) -> Dictionary:
	var copy := state.duplicate(false)
	copy.enemies = []
	for enemy in state.enemies: copy.enemies.append(enemy.duplicate(false))
	copy.projectiles = []
	for projectile in state.get("projectiles", []): copy.projectiles.append(projectile.duplicate(false))
	copy.buff = state.buff.duplicate(false)
	copy.magazine = state.magazine.duplicate(false)
	copy.discard = state.discard.duplicate(false)
	copy.field_compression = state.get("field_compression", {}).duplicate(false)
	copy.prepared = state.get("prepared", []).duplicate(false)
	copy.engine = state.get("engine",Model.Engines.fresh()).duplicate(true)
	return copy

# Within one bullet step, gun, parts, target order, reserves, deck and the
# remaining magazine suffix are identical. Only these values can change in
# Model._shot. Fresh immutable numeric keys avoid serializing enemy names and
# entire inventories thousands of times; time advancement happens AFTER merging.
static func _shot_branch_key(state: Dictionary) -> Array:
	var key: Array = [state.magazine.size(), int(state.push_left), int(state.get("heat", 0)), int(state.get("legacy_reload_penalty", 0)), bool(state.get("previous_kill", false)), int(state.buff.get("dmg", 0)), int(state.buff.get("dmg_left", 0)), bool(state.buff.get("persistent", false)), JSON.stringify(state.buff)]
	key.append(state.get("prepared", []).duplicate())
	key.append(JSON.stringify(state.get("engine",{})))
	for enemy in state.enemies:
		key.append_array([int(enemy.hp), int(enemy.def), int(enemy.distance), int(enemy.get("burn", 0)), int(enemy.get("focus_hits", 0)), int(enemy.get("barrier", 0)), int(enemy.get("stance_def", 0)), int(enemy.get("jammed", 0)), bool(enemy.get("disrupted", false))])
	for projectile in state.get("projectiles", []):
		key.append_array([int(projectile.uid), int(projectile.hp), int(projectile.distance), int(projectile.get("burn", 0))])
	return key

## The same real reload command drives both costs and post-reload positions.
## Calling it on a duplicate also includes burn, stance, charge and deployment.
static func reload_now(state: Dictionary, allow_plan: bool = false) -> Dictionary:
	var copy = Model.new()
	copy.forecast_only = true
	copy.s = state.duplicate(true)
	var cost: int = copy.reload_cost()
	var base: int = copy.base_reload_cost()
	var heat := cost - base
	var before := int(copy.s.turns)
	var required: bool = copy.reload_magazine() if copy.s.phase == "ready" or allow_plan else false
	return {"temperature_after": int(copy.s.get("heat", 0)), "required": required, "cost": cost if required else 0, "base": base, "heat": heat if required else 0, "phase": copy.s.phase, "turns": int(copy.s.turns) - before, "enemies": copy.s.enemies.duplicate(true), "projectiles": copy.s.get("projectiles", []).duplicate(true), "loss_reason": copy.s.get("loss_reason", ""), "launches": int(copy.s.get("projectile_serial", 0)) - int(state.get("projectile_serial", 0))}

static func reload_consequence(result: Dictionary) -> String:
	# Read the real simulated outcome: burning shooters, jams and existing shots
	# must not produce a warning based only on a countdown comparison.
	if not result.get("required", false): return ""
	if result.get("phase", "") == "lost": return "피격 위험" if result.get("loss_reason", "") == "projectile" else "접촉 위험"
	if result.get("phase", "") in ["won", "reward"]: return ""
	if int(result.get("launches", 0)) > 0: return "적 발사"
	for shot in result.get("projectiles", []):
		if int(shot.hp) > 0 and Ranged.arrival(shot) <= 1: return "압력탄 임박"
	return ""

static func _reload_ranges(branches: Array) -> Dictionary:
	var result := {"random": true, "required_probability": 0.0, "lost_probability": 0.0, "win_probability": 0.0, "cost_min": 1000000, "cost_max": 0, "heat_min": 1000000, "heat_max": 0, "temperature_min": 1000000, "temperature_max": 0, "enemies": []}
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
		result.temperature_min = mini(result.temperature_min, int(outcome.temperature_after))
		result.temperature_max = maxi(result.temperature_max, int(outcome.temperature_after))
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

static func _heat_ranges(state: Dictionary, rows: Array) -> Dictionary:
	var result := {"current": int(state.get("heat", 0)), "limit": Content.heat_limit(state), "overheat_probability": 0.0, "forced_probability": 0.0}
	for key in ["peak", "end", "fired", "turns", "forced_cost"]:
		result[key + "_min"] = 1000000
		result[key + "_max"] = 0
	for row in rows:
		for key in ["peak", "end", "fired", "turns", "forced_cost"]:
			result[key + "_min"] = mini(int(result[key + "_min"]), int(row[key]))
			result[key + "_max"] = maxi(int(result[key + "_max"]), int(row[key]))
		if row.overheated: result.overheat_probability += float(row.p)
		if int(row.forced_cost) > 0: result.forced_probability += float(row.p)
	return result

static func tag(index: int, enemies: Array = []) -> String:
	if Ranged.is_projectile(index): return "요격"
	return str(enemies[index].get("name", "대상")) if index >= 0 and index < enemies.size() else "대상"

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
	if shot.get("random", false):
		if str(shot.id) in ["prepare", "disrupt", "spread", "sequence"]:
			return "%s %d%%" % [{"prepare": "예약", "disrupt": "차단", "spread": "화상 이동", "sequence": "탄종 연계"}[str(shot.id)], floori(minf(1.0, float(shot.get("effect_probability", 0)) + 0.0000001) * 100)]
		return "후열 무작위" if str(shot.id) == "bypass" else "무작위 표적"
	if not shot.get("prepared_rounds", []).is_empty(): return "다음 패 예약 %d장" % shot.prepared_rounds.size()
	if int(shot.get("interrupted", 0)) > 0: return "준비 정지 %d턴" % shot.interrupted
	if int(shot.get("transferred", 0)) > 0: return "화상 %d 이동" % shot.transferred
	if int(shot.get("sequence_bonus", 0)) > 0: return "탄종 연계 +%d" % shot.sequence_bonus
	if str(shot.id) in ["prepare", "disrupt", "spread", "sequence"]: return "조건 없음 · 추가 효과 0"
	if int(shot.get("vented", 0)) > 0: return "열 %d → 피해 +%d" % [shot.vented, shot.vent_bonus]
	if int(shot.get("thermal_bonus", 0)) > 0: return "고열 피해 +%d" % shot.thermal_bonus
	if int(shot.get("cooled", 0)) > 0: return "냉각 −%d" % shot.cooled
	if int(shot.get("armor_removed", 0)) > 0: return "장갑 −%d" % shot.armor_removed
	if int(shot.get("detonation", 0)) > 0: return "화상 기폭 %d" % shot.detonation
	if int(shot.get("chase_bonus", 0)) > 0: return "처치 연계 +%d" % shot.chase_bonus
	if int(shot.get("blocked_hits", 0)) > 0:
		return "배리어 −%d%s" % [int(shot.blocked_hits), " · HP −%d" % int(shot.damage) if int(shot.damage) > 0 else ""]
	if int(shot.get("focus_damage", 0)) > 0: return "집중 +%d" % shot.focus_damage
	var boosted := int(shot.get("math", {}).get("boost", 0)) > 0 or int(shot.get("math", {}).get("factor", 1)) > 1
	var secondary: Array = shot.get("secondary", [])
	if not secondary.is_empty():
		var impacts: PackedStringArray = []
		for other in secondary:
			var effect_name: String = {"spread":"확산","relay":"잔타","overflow":"돌파","burn_transfer":"화상","heat_wave":"열압"}.get(str(other.get("kind","arc")),"전이")
			impacts.append("%s %s −%d" % [tag(other.target, forecast.get("enemies", [])), effect_name, other.damage])
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
		if shot.get("boost_hot",false): return "고열 공격 +%d" % int(shot.get("boost_granted",0))
		if int(shot.get("boost_heat",0)) > 0: return "공격 ×%d · 추가 열 +%d" % [int(shot.boost_factor_granted),int(shot.boost_heat)]
		return "다음 공격 %d발 %s" % [int(shot.get("boost_rounds", 2)), ("×%d" % int(shot.boost_factor_granted)) if int(shot.get("boost_factor_granted", 1)) > 1 else ("+%d" % int(shot.get("boost_granted", 2)))]
	return ""

static func is_combo_link(forecast: Dictionary, shot_index: int) -> bool:
	if shot_index <= 0 or shot_index >= forecast.get("shots", []).size(): return false
	if forecast.shots[shot_index].get("random", false): return forecast.shots[shot_index].get("boosted", false)
	var shot: Dictionary = forecast.shots[shot_index]
	var previous: Dictionary = forecast.shots[shot_index - 1]
	return int(shot.get("math", {}).get("boost", 0)) > 0 or int(shot.get("math", {}).get("factor", 1)) > 1 or int(shot.get("detonation", 0)) > 0 or int(shot.get("chase_bonus", 0)) > 0 or (int(previous.get("armor_removed", 0)) > 0 and int(previous.target) == int(shot.target))

static func summary(forecast: Dictionary) -> String:
	if forecast.is_empty(): return "탄환을 눌러 장전하세요"
	if forecast.get("random", false):
		var ranges: PackedStringArray = []
		for i in range(forecast.enemies.size()):
			var e: Dictionary = forecast.enemies[i]
			ranges.append("%s HP%d~%d" % [tag(i, forecast.enemies), e.hp_min, e.hp_max])
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
			parts.append("%s 처치" % tag(i, forecast.enemies))
		else:
			parts.append("%s %sHP %d" % [tag(i, forecast.enemies), "◆%d · " % int(enemy.get("barrier", 0)) if int(enemy.get("barrier", 0)) > 0 else "", enemy.hp])
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
	var dealt := 0
	for shot in forecast.get("shots",[]):
		dealt += int(shot.damage)
		for other in shot.get("secondary",[]): dealt += int(other.get("damage",0))
	var result_text := "피해 %d · 처치 %d · 전열 %d" % [dealt, kills, survivors]
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
