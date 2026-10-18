extends RefCounted
const AttackBoosts = preload("res://redesign/attack_boosts.gd")
## One serializable state; commands validate before mutation. Preview executes the
## same shot resolver on a copy and never changes live state or RNG.
const Content = preload("res://redesign/content.gd")
const Ranged = preload("res://redesign/ranged.gd")
const Engines = preload("res://redesign/damage_engines.gd")
const VERSION := 15
var s: Dictionary = {}
# Exact forecast resolves the same rules without presentation snapshots or draws
# after the final action. This flag is never serialized or used by live commands.
var forecast_only := false
var last_reload_detail: Dictionary = {}

func start(gun_id: String, run_seed: int, course: bool = false, outfit: String = "work") -> void:
	assert(Content.GUNS.has(gun_id) and Content.OUTFITS.has(outfit))
	s = {"version": VERSION, "ammo_cycle": 1, "outfit": outfit, "bag_version": Content.BAG_VERSION, "bag_upgrades": 0, "course": course, "seed": str(run_seed), "gun": gun_id, "part": "none", "equipped_parts": [], "floor": 0, "deck": Content.cycle_start_deck(Content.COURSE_GRANTS[0]) if course else Content.start_deck(gun_id), "turns": 0, "shots": 0, "reloads": 0, "history": [], "reward_taken": false}
	begin_encounter()

func begin_encounter(field_charges: int = 1) -> void:
	Engines.begin(s)
	s.phase = "plan"
	s.enemies = Content.enemies_for(int(s.floor), int(s.seed), s.get("course", false), str(s.gun))
	s.reinforcements = []
	s.projectiles = []
	s.projectile_serial = 0
	s.loss_reason = ""
	assign_opening_lanes()
	s.encounter_total = s.enemies.size()
	s.deployed = s.enemies.size()
	s.wave = 1
	s.hand = []
	s.draw = s.deck.duplicate()
	s.discard = []
	s.magazine = []
	s.plan = []
	s.plan_load_order = []
	s.buff = {}
	s.heat = 0
	s.legacy_reload_penalty = 0
	s.previous_kill = false
	s.prepared = []
	s.push_left = Content.push_budget(s)
	s.exchange_left = Content.exchange_capacity(s)
	s.field_compression_left = 0 if s.get("course", false) else clampi(field_charges, 0, 2) + Content.field_compression_bonus(s)
	s.field_compression = {}
	s.supply = supply_capacity()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(s.seed) + int(s.floor) * 104729
	s.rng_state = str(rng.state)
	s.target_rng_state = _target_state(s)
	_shuffle(s.draw)
	_refill()
	if s.get("course", false):
		# Each newly taught round is in the first hand. Keep ownership and RNG intact.
		for id in Content.COURSE_GRANTS[int(s.floor)]:
			if not s.hand.has(id) and s.draw.has(id):
				var replace_index: int = s.hand.size() - 1
				while Content.COURSE_GRANTS[int(s.floor)].has(s.hand[replace_index]) and s.hand.count(s.hand[replace_index]) == 1:
					replace_index -= 1
				var outgoing = s.hand[replace_index]
				s.hand.remove_at(replace_index)
				s.draw.erase(id)
				s.draw.append(outgoing)
				s.hand.push_front(id)
	s.message = "마지막에 넣은 탄부터 발사 · 발사 순서는 왼쪽부터 · 확정 전 자유롭게 설계"
	_record("encounter", {"index": s.floor})

func capacity() -> int:
	return Content.capacity(s)

func reload_cost() -> int:
	return base_reload_cost() + (1 if int(s.get("heat", 0)) >= Content.heat_limit(s) else 0) + int(s.get("legacy_reload_penalty", 0))

func base_reload_cost() -> int:
	return maxi(1, int(Content.GUNS[s.gun].reload) + Content.reload_modifier(s))

func assign_opening_lanes() -> void:
	var used: Array = []
	for enemy in s.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0: continue
		var lane := int(enemy.get("lane", -1))
		if lane < 0 or lane > 3 or used.has(lane):
			lane = 0
			while used.has(lane) and lane < 4: lane += 1
		enemy.lane = clampi(lane, 0, 3)
		used.append(enemy.lane)
	for enemy in s.get("reinforcements", []): enemy.lane = -1

func supply_capacity() -> int:
	return Content.supply_capacity(s)

func available(id: String) -> int:
	return (int(s.supply) if id == "basic" and not Content.uses_ammo_cards(s) else s.hand.count(id)) - s.plan.count(id)

func can_load(id: String) -> bool:
	return load_block_reason(id).is_empty()

func load_block_reason(id: String) -> String:
	if s.phase != "plan": return "장전 확정 상태"
	if not Content.AMMO.has(id) or Content.is_temporary(id): return "직접 장전 불가"
	if available(id) <= 0: return "보유 없음"
	return Content.insertion_block_reason(s.plan, id, capacity())

func load_round(id: String) -> bool:
	if not can_load(id):
		return false
	var index := Content.insertion_index(s.plan, id)
	s.plan.insert(index, id)
	s.plan_load_order.append(id)
	s.message = "%s를 맨 앞에 장전 · 마지막에 넣은 탄부터 발사합니다." % Content.AMMO[id].name
	return true

func undo() -> bool:
	# Recall the stack top, including after an explicit rail edit.
	return remove_planned(0)

func confirm() -> bool:
	if s.phase != "plan" or s.plan.is_empty() or not Content.valid_stack(s.plan, capacity()):
		return false
	for id in s.plan:
		if not Content.AMMO.has(id) or (Content.is_temporary(id) and str(s.field_compression.get("id", "")) != id) or (not Content.is_temporary(id) and available(id) < 0):
			return false
	for id in s.plan:
		if id == "basic" and not Content.uses_ammo_cards(s):
			s.supply -= 1
		elif not Content.is_temporary(id):
			s.hand.erase(id)
	s.magazine = s.plan.duplicate()
	s.previous_kill = false
	if not s.field_compression.is_empty(): s.field_compression.zone = "magazine"
	_record("load", {"load_order": s.plan.duplicate(), "hand_left": s.hand.duplicate()})
	s.plan.clear()
	s.plan_load_order.clear()
	s.phase = "ready"
	s.message = "장전 확정. 발사하거나 %d턴을 써서 다시 장전할 수 있습니다." % reload_cost()
	return true

func fire() -> bool:
	if s.phase != "ready" or s.magazine.is_empty():
		return false
	var results: Array = []
	var peak_heat := int(s.get("heat", 0))
	# Amplifier is the deliberate single-shot weapon, but a kill keeps the trigger
	# window open. The first survivor ends the execution chain and advances time.
	var count: int = s.magazine.size() if Content.chains(s) or s.gun == "amplifier" else 1
	var recent_rounds: Array = _recent_part_rounds()
	var previous_round: String = str(recent_rounds.back()) if not recent_rounds.is_empty() else ""
	var recent_sources: Array = _recent_part_sources()
	for i in range(count):
		if target_index() < 0:
			break
		var id: String = s.magazine.pop_front()
		var source: String = Content.source_id(id)
		var triad_ready: bool = recent_sources.size() >= 2 and recent_sources[-1] != recent_sources[-2] and source != recent_sources[-1] and source != recent_sources[-2]
		var result := _shot(id, -1, {"first": recent_sources.is_empty(), "last": s.magazine.is_empty(), "last_attack": not s.magazine.any(func(round_id): return Content.is_attack(str(round_id))), "triad": triad_ready, "previous_round": previous_round, "fired_count": recent_sources.size(), "sequence_count": Content.prior_kind_count(recent_sources, id)})
		results.append(result)
		peak_heat = maxi(peak_heat, int(s.get("heat", 0)))
		previous_round = id
		recent_sources.append(source)
		s.shots += 1
		_discard_fired_round(id)
		if int(s.get("heat", 0)) >= Content.heat_limit(s) or (s.gun == "amplifier" and int(result.get("hp", 1)) > 0):
			break
	var detail := finish_fire()
	detail.results = results
	detail.heat_peak = peak_heat
	detail.overheated = not results.is_empty() and bool(results.back().get("overheated", false))
	var lines: PackedStringArray = []
	for result in results: lines.append(result.text)
	if not detail.forced_reload.is_empty(): lines.append("과열 · 사격 중단 · 강제 재장전 %d턴" % int(detail.forced_reload.cost))
	s.message = "\n".join(lines)
	_record("fire", detail)
	return true

# Shared by actual fire and exact scatter branches. Resolves the ONE firing turn,
# then an obligatory reload only if combat survives the overheat shot.
func finish_fire() -> Dictionary:
	var overheated := int(s.get("heat", 0)) >= Content.heat_limit(s)
	s.turns += 1
	var advance_events: Array = []
	if target_index() < 0 and reserve_count() == 0:
		s.phase = "won" if int(s.floor) == Content.ENCOUNTERS.size() - 1 else "reward"
		s.reward_taken = false
	else:
		advance_events = _advance(1)
	var deployments: Array = []
	if s.phase != "lost" and reserve_count() > 0:
		deployments = _deploy_reinforcements(alive_count() == 0)
	if s.phase != "lost" and target_index() < 0 and reserve_count() == 0:
		s.phase = "won" if int(s.floor) == Content.ENCOUNTERS.size() - 1 else "reward"
		s.reward_taken = false
	if s.phase in ["reward", "won", "lost"]:
		s.heat = 0
		s.prepared = []
		s.legacy_reload_penalty = 0
		_release_unfired_field_round()
	Engines.settle(s, Content.equipped_parts(s))
	var firing_enemies: Array = [] if forecast_only else s.enemies.duplicate(true)
	var firing_projectiles: Array = [] if forecast_only else s.get("projectiles", []).duplicate(true)
	var firing_reinforcements: Array = [] if forecast_only else s.get("reinforcements", []).duplicate(true)
	var forced: Dictionary = {}
	if overheated and s.phase == "ready":
		reload_magazine()
		forced = last_reload_detail.duplicate(true)
	return {"advance_events": advance_events, "deployments": deployments, "phase": s.phase, "forced_reload": forced, "firing_enemies": firing_enemies, "firing_projectiles": firing_projectiles, "firing_reinforcements": firing_reinforcements}

func _recent_part_sources() -> Array:
	return _recent_part_rounds().map(func(id): return Content.source_id(str(id)))

func _recent_part_rounds() -> Array:
	var result: Array = []
	for history_index in range(s.history.size() - 1, -1, -1):
		var event: Dictionary = s.history[history_index]
		if str(event.get("action", "")) == "load": break
		if str(event.get("action", "")) != "fire": continue
		var fired: Array = []
		for shot in event.get("detail", {}).get("results", []): fired.append(str(shot.get("id", "")))
		for fired_index in range(fired.size() - 1, -1, -1): result.push_front(fired[fired_index])
	return result

func reload_magazine() -> bool:
	if s.phase != "ready" and not (s.phase == "plan" and Content.uses_ammo_cards(s)):
		return false
	if s.phase == "plan":
		# Planned ordinary rounds still belong to hand. Restore temporary originals once.
		if not s.field_compression.is_empty():
			s.hand.append(s.field_compression.source)
			s.hand.append(s.field_compression.source)
			s.field_compression = {}
		s.plan.clear()
		s.plan_load_order.clear()
	for id in s.magazine.duplicate():
		_discard_fired_round(str(id))
	s.magazine.clear()
	s.previous_kill = false
	s.buff = AttackBoosts.after_reload(s.buff)
	s.reloads += 1
	var cost := reload_cost()
	var heat_paid := cost - base_reload_cost()
	var heat_before := int(s.get("heat", 0))
	var heat_after := Content.heat_after_reload(s)
	var advance_events := _advance(cost, true)
	s.heat = heat_after if s.phase not in ["reward", "won", "lost"] else 0
	s.legacy_reload_penalty = 0
	var deployments: Array = []
	if s.phase != "lost" and reserve_count() > 0 and alive_count() == 0:
		deployments = _deploy_reinforcements(true)
	# Count each actual elapsed turn, including a lethal partial reload.
	if s.phase in ["reward", "won"]:
		s.message = "화상이 전진 전에 마지막 적을 처치했습니다."
	elif s.phase != "lost":
		s.phase = "plan"
		s.supply = supply_capacity()
		s.push_left = Content.push_budget(s)
		s.exchange_left = Content.exchange_capacity(s)
		# Unused rounds cycle into discard; ownership is conserved, including in previews.
		s.discard.append_array(s.hand)
		s.hand.clear()
		if not forecast_only:
			_draw_prepared()
			_refill()
		else: s.prepared = []
		s.message = "재장전 · %d턴 · 열 %d→%d · 새 패 %d장" % [cost, heat_before, s.heat, s.hand.size()]
	else:
		s.message = "재장전 도중 적이 0m에 도달했습니다."
	if s.phase in ["reward", "won", "lost"]: s.prepared = []
	Engines.settle(s, Content.equipped_parts(s))
	last_reload_detail = {"cost": cost, "heat_paid": heat_paid, "heat_before": heat_before, "heat_after": int(s.heat), "advance_events": advance_events, "deployments": deployments, "phase": s.phase}
	if not forecast_only: _record("reload", last_reload_detail)
	return true

func _advance(turn_count: int, count_turns: bool = false) -> Array:
	var events: Array = []
	for i in range(turn_count):
		if count_turns:
			s.turns += 1
		# Every burning enemy resolves before any survivor moves this turn.
		for enemy_index in range(s.enemies.size()):
			var e: Dictionary = s.enemies[enemy_index]
			if int(e.hp) <= 0:
				continue
			if int(e.get("burn", 0)) > 0:
				var hp_before := int(e.hp)
				e.hp = maxi(0, hp_before - Content.burn_damage(s))
				e.burn = maxi(0, int(e.burn) - 1)
				if not forecast_only: events.append({"turn": i, "target": enemy_index, "kind": "burn", "damage": hp_before - int(e.hp), "hp": e.hp, "burn": e.burn})
		if target_index() < 0 and reserve_count() == 0:
			s.phase = "won" if int(s.floor) == Content.ENCOUNTERS.size() - 1 else "reward"
			s.reward_taken = false
			break
		elif target_index() < 0:
			continue
		# Charging units publish their clock. On completion they pull every other
		# survivor before ordinary movement, so the full distance cost is knowable.
		for source_index in range(s.enemies.size()):
			var source: Dictionary = s.enemies[source_index]
			if int(source.hp) <= 0 or int(source.get("charge_max", 0)) <= 0 or int(source.get("jammed", 0)) > 0:
				continue
			source.charge = int(source.get("charge", 0)) + 1
			var released := int(source.charge) >= int(source.charge_max)
			if not forecast_only: events.append({"turn": i, "target": source_index, "kind": "charge", "charge": 0 if released else source.charge, "charge_max": source.charge_max, "released": released})
			if released:
				source.charge = 0
				var pull := int(source.get("charge_pull", 2))
				for enemy_index in range(s.enemies.size()):
					if enemy_index == source_index or int(s.enemies[enemy_index].hp) <= 0: continue
					var ally: Dictionary = s.enemies[enemy_index]
					var before_pull := int(ally.distance)
					ally.distance = maxi(0, before_pull - pull)
					if not forecast_only: events.append({"turn": i, "target": enemy_index, "source": source_index, "kind": "pull", "from": before_pull, "to": ally.distance, "amount": pull})
					if int(ally.distance) == 0: s.phase = "lost"
		if s.phase == "lost":
			break
		for enemy_index in range(s.enemies.size()):
			var e: Dictionary = s.enemies[enemy_index]
			if int(e.hp) <= 0: continue
			var distance_before := int(e.distance)
			e.distance = maxi(0, distance_before - int(e.speed))
			if not forecast_only: events.append({"turn": i, "target": enemy_index, "kind": "move", "from": distance_before, "to": e.distance})
			if int(e.distance) == 0:
				s.phase = "lost"
		# Stance changes after movement and is therefore the public defense for the
		# player's next decision. Multi-turn reloads alternate once per elapsed turn.
		for enemy_index in range(s.enemies.size()):
			var e: Dictionary = s.enemies[enemy_index]
			if int(e.hp) <= 0 or not bool(e.get("stance", false)): continue
			e.stance_closed = not bool(e.get("stance_closed", true))
			e.def = int(e.get("stance_def", 4)) if bool(e.stance_closed) else 0
			if not forecast_only: events.append({"turn": i, "target": enemy_index, "kind": "stance", "def": e.def, "closed": e.stance_closed})
		if s.phase == "lost":
			break
		events.append_array(Ranged.advance(s, i, not forecast_only))
		for enemy in s.enemies:
			if int(enemy.get("jammed", 0)) > 0: enemy.jammed = int(enemy.jammed) - 1
		if s.phase == "lost": break
	return events

func target_index() -> int:
	var selected := -1
	var distance := 2147483647
	for i in range(s.enemies.size()):
		var e: Dictionary = s.enemies[i]
		if int(e.hp) > 0 and int(e.distance) < distance:
			selected = i
			distance = int(e.distance)
	for projectile in Ranged.active(s):
		if int(projectile.distance) <= distance:
			selected = Ranged.target_id(projectile)
			distance = int(projectile.distance)
	return selected

func target_entity(index: int) -> Dictionary:
	return Ranged.entity(s, index)

func active_targets() -> Array:
	var result: Array = []
	for i in range(s.enemies.size()):
		if int(s.enemies[i].hp) > 0: result.append(i)
	for projectile in Ranged.active(s): result.append(Ranged.target_id(projectile))
	return result

func shot_targets(id: String) -> Array:
	var nearest := target_index()
	if nearest < 0: return []
	if Ranged.is_projectile(nearest): return [nearest]
	var targets := active_targets().filter(func(index): return not Ranged.is_projectile(int(index)))
	targets.sort_custom(func(a, b): return int(s.enemies[a].distance) < int(s.enemies[b].distance) if int(s.enemies[a].distance) != int(s.enemies[b].distance) else int(a) < int(b))
	if str(Content.AMMO.get(id, {}).get("effect", "")) == "bypass" and targets.size() > 1:
		targets.pop_front()
	return targets if s.gun == "scatter" else [targets[0]]

func scatter_targets(id: String = "basic") -> Array:
	var nearest := target_index()
	if Ranged.is_projectile(nearest): return [nearest]
	var targets := active_targets().filter(func(index): return not Ranged.is_projectile(int(index)))
	if str(Content.AMMO.get(id, {}).get("effect", "")) == "bypass" and targets.size() > 1: targets.erase(nearest)
	return targets

func alive_count() -> int:
	var count := 0
	for enemy in s.get("enemies", []):
		if int(enemy.get("hp", 0)) > 0: count += 1
	return count

func reserve_count() -> int:
	return s.get("reinforcements", []).size()

func has_remaining_enemies() -> bool:
	return alive_count() > 0 or reserve_count() > 0 or not Ranged.active(s).is_empty()

func _deploy_reinforcements(force: bool = false) -> Array:
	var deployments: Array = []
	if reserve_count() == 0 or (not force and alive_count() > 2):
		return deployments
	var room := maxi(0, 4 - alive_count())
	while room > 0 and not s.reinforcements.is_empty():
		var enemy: Dictionary = s.reinforcements.pop_front()
		var used_lanes: Array = []
		for active_index in range(s.enemies.size()):
			var active: Dictionary = s.enemies[active_index]
			if int(active.get("hp", 0)) > 0: used_lanes.append(int(active.get("lane", active_index % 4)))
		var open_lane := 0
		while used_lanes.has(open_lane) and open_lane < 4: open_lane += 1
		enemy.lane = clampi(open_lane, 0, 3)
		s.enemies.append(enemy)
		deployments.append({"target": s.enemies.size() - 1, "enemy": enemy.duplicate(true)})
		room -= 1
	if not deployments.is_empty():
		s.deployed = int(s.get("deployed", 0)) + deployments.size()
		s.wave = int(s.get("wave", 1)) + 1
	return deployments

func _random_target(id: String = "basic") -> int:
	var alive := scatter_targets(id)
	if alive.is_empty(): return -1
	if Ranged.is_projectile(int(alive[0])): return int(alive[0])
	var rng := RandomNumberGenerator.new()
	rng.state = int(s.target_rng_state)
	var index: int = alive[rng.randi_range(0, alive.size() - 1)]
	s.target_rng_state = str(rng.state)
	return index

func _target_state(state: Dictionary) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state.get("seed", 0)) ^ (int(state.get("floor", 0)) * 7919 + 15485863)
	return str(rng.state)

# These values depend only on the bullet and the current weapon/parts, not on
# a random target. Forecast branches share a read-only profile for this step.
static func shot_profile(id: String, state: Dictionary) -> Dictionary:
	return {"parts": Content.equipped_parts(state), "damage": Content.damage(id, state), "pen": Content.penetration(id, state), "effect": Content.effect_value(id, state), "hits": Content.hit_count(id, state), "burn": Content.burn_amount(id, state), "burn_tick": Content.burn_damage(state), "heat_limit": Content.heat_limit(state), "hot_threshold": Content.hot_threshold(state)}

func _shot(id: String, forced_target: int = -1, part_context: Dictionary = {}) -> Dictionary:
	var index := forced_target
	if index < 0:
		if s.gun == "scatter": index = _random_target(id)
		else:
			var candidates := shot_targets(id)
			index = int(candidates[0]) if not candidates.is_empty() else -1
	var e := target_entity(index)
	if e.is_empty(): return {}
	if int(e.hp) <= 0: return {}
	var spec: Dictionary = Content.AMMO[id]
	var minimal := bool(part_context.get("forecast_minimal", false))
	var profile: Dictionary = part_context.get("profile", {})
	if profile.is_empty(): profile = shot_profile(id, s)
	var active_parts: Array = profile.parts
	var previous_round := str(part_context.get("previous_round", ""))
	var relay_saved := mini(2, Content.heat_cost(id)) if active_parts.has("compression_sink") and Content.compression_link(previous_round, id) else 0
	var heat_added := Content.heat_cost(id) - relay_saved
	var heat_before := int(s.get("heat", 0))
	var attack := Content.is_attack(id)
	var applied := AttackBoosts.resolve(s.buff, heat_before, int(profile.hot_threshold)) if attack else {"dmg":0,"factor":1,"heat":0,"hot_failed":false}
	heat_added += int(applied.heat)
	heat_added += Content.part_heat_bonus(id,s)
	var cooled := mini(heat_before, int(profile.effect)) if spec.effect == "cool" else 0
	var vented := mini(heat_before, int(spec.get("heat_spend", 0))) if spec.effect == "vent" else 0
	var thermal_bonus := int(profile.effect) if spec.effect == "thermal" and heat_before >= int(profile.hot_threshold) else 0
	var vent_bonus := vented * int(profile.effect)
	s.heat = heat_before + heat_added - cooled - vented
	var chase_bonus := int(profile.effect) if spec.effect == "chase" and bool(s.get("previous_kill", false)) else 0
	var sequence_bonus := int(profile.effect) * int(part_context.get("sequence_count", 0)) if spec.effect == "sequence" else 0
	var prepared_rounds: Array = []
	if spec.effect == "prepare":
		if not s.has("prepared"): s.prepared = []
		var candidates: Array = []
		for value in s.magazine:
			var next_id := str(value)
			if (next_id == "basic" and not Content.uses_ammo_cards(s)) or Content.is_temporary(next_id): continue
			candidates.append(next_id)
			if s.prepared.count(next_id) >= candidates.count(next_id): continue
			if s.prepared.size() >= 3 or prepared_rounds.size() >= int(profile.effect): break
			s.prepared.append(next_id)
			prepared_rounds.append(next_id)
	var alive_before := alive_count()
	var dmg_buff := int(applied.dmg)
	var factor := int(applied.factor)
	var pen := int(profile.pen)
	var weakness_bonus := Content.weakness_bonus(id, e)
	var part_bonus := 0
	var part_combo: PackedStringArray = []
	var part_effects: Array = []
	var ordinary_bonus := 2 * int(part_context.get("sequence_count",0)) if active_parts.has("ordinary_chain") and bool(part_context.get("last_attack",false)) and Content.is_attack(id) else 0
	if ordinary_bonus > 0:
		part_bonus += ordinary_bonus
		if not minimal: part_combo.append("교차 급탄 +%d" % ordinary_bonus)
		if not minimal: part_effects.append({"id": "ordinary_chain", "label": "교차 급탄 +%d" % ordinary_bonus})
	var burn_before := int(e.get("burn", 0))
	if active_parts.has("ember_core") and heat_before >= int(profile.hot_threshold):
		var bonus := int(Content.PARTS.ember_core.hot_damage)
		part_bonus += bonus
		if not minimal: part_combo.append("잔열 +%d" % bonus)
		if not minimal: part_effects.append({"id": "ember_core", "label": "고열 피해 +%d" % bonus})
	if active_parts.has("igniter") and int(e.get("burn", 0)) > 0:
		part_bonus += 2
		if not minimal: part_combo.append("점화 +2")
		if not minimal: part_effects.append({"id": "igniter", "label": "피해 +2"})
	if active_parts.has("executioner") and int(e.hp) <= 5:
		part_bonus += 2
		if not minimal: part_combo.append("처형 +2")
		if not minimal: part_effects.append({"id": "executioner", "label": "피해 +2"})
	if active_parts.has("opening") and bool(part_context.get("first", false)):
		part_bonus += 2
		if not minimal: part_combo.append("선두 +2")
		if not minimal: part_effects.append({"id": "opening", "label": "피해 +2"})
	if active_parts.has("afterburner") and bool(part_context.get("last", false)):
		part_bonus += 3
		if not minimal: part_combo.append("후미 +3")
		if not minimal: part_effects.append({"id": "afterburner", "label": "피해 +3"})
	if active_parts.has("triad") and bool(part_context.get("triad", false)):
		part_bonus += 5
		if not minimal: part_combo.append("삼중 +5")
		if not minimal: part_effects.append({"id": "triad", "label": "피해 +5"})
	if not attack:
		weakness_bonus = 0
		part_bonus = 0
		ordinary_bonus = 0
		part_combo.clear()
		part_effects.clear()
	var engine_flat := Engines.flat(s,active_parts) if attack else 0
	var engine_percent := Engines.percent(s,active_parts,int(profile.hits),heat_before>=int(profile.hot_threshold)) if attack else 100
	part_bonus += engine_flat
	var engine_id := "volley_drive" if engine_flat>0 else ("thermal_drive" if active_parts.has("thermal_drive") and engine_percent>100 else ("siege_drive" if engine_percent>100 else ""))
	if not engine_id.is_empty() and not minimal: part_effects.append({"id":engine_id,"label":Engines.value(s,engine_id)})
	var subtotal := int(profile.damage) + dmg_buff + weakness_bonus + part_bonus + chase_bonus + thermal_bonus + vent_bonus + sequence_bonus
	var raw := int(subtotal * factor * engine_percent / 100.0) if attack else 0
	var armor := maxi(0, int(e.def) - pen)
	var per_hit := maxi(1, raw - armor) if raw > 0 else 0
	var requested_hits := int(profile.hits) if attack else 0
	var hp_before := int(e.hp)
	var focus_before := int(e.get("focus_hits", 0))
	var focus_damage := 0
	var focus_triggers := 0
	var hits := 0
	var barrier_before := int(e.get("barrier", 0))
	var blocked_hits := 0
	var barrier_removed := 0
	var combo: Array = []
	if not minimal and (dmg_buff > 0): combo.append("증폭 +%d" % dmg_buff)
	if not minimal and factor > 1: combo.append("배율 ×%d" % factor)
	if not minimal and bool(applied.hot_failed): combo.append("잔열 부족 · 강화 소멸")
	if not minimal and int(applied.heat) > 0: combo.append("배율 대가 · 열 +%d" % int(applied.heat))
	if not minimal and (weakness_bonus > 0): combo.append("약점 +%d" % weakness_bonus)
	if not minimal and (chase_bonus > 0): combo.append("추격 +%d" % chase_bonus)
	if not minimal: combo.append_array(part_combo)
	for hit_index in range(requested_hits):
		if int(e.hp) <= 0: break
		hits += 1
		var blocked := false
		if int(e.get("barrier", 0)) > 0:
			var removed := mini(int(e.barrier), 2 if active_parts.has("breaker") else 1)
			e.barrier = int(e.barrier) - removed
			barrier_removed += removed
			blocked_hits += 1
			blocked = true
		else:
			e.hp = maxi(0, int(e.hp) - per_hit)
		if s.gun == "burst":
			e.focus_hits = int(e.get("focus_hits", 0)) + 1
			if int(e.focus_hits) == 3:
				e.focus_hits = 0
				focus_triggers += 1
				var extra := 0 if blocked else mini(4, int(e.hp))
				e.hp -= extra
				focus_damage += extra
	var detonation := 0
	if spec.effect == "detonate" and not Ranged.is_projectile(index):
		detonation = mini(int(e.hp), burn_before * int(profile.burn_tick) * int(spec.get("detonate_scale", 1)))
		e.hp -= detonation
		e.burn = 0
		if not minimal and (detonation > 0): combo.append("화상 기폭 %d" % detonation)
	var armor_removed := 0
	var armor_before := int(e.def)
	if spec.effect == "shatter" and not Ranged.is_projectile(index):
		var stored_armor := int(e.get("stance_def", e.def)) if bool(e.get("stance", false)) else int(e.def)
		if Ranged.is_gatekeeper(e): stored_armor = int(e.guard_armor)
		armor_removed = mini(stored_armor, int(profile.effect))
		if Ranged.is_gatekeeper(e):
			e.guard_armor = stored_armor - armor_removed
			e.def = int(e.guard_armor) if str(e.ranged_phase) == "guard" else 0
		elif bool(e.get("stance", false)):
			e.stance_def = stored_armor - armor_removed
			e.def = int(e.stance_def) if bool(e.stance_closed) else 0
		else: e.def -= armor_removed
		if not minimal and (armor_removed > 0): combo.append("장갑 −%d" % armor_removed)
	var damage := hp_before - int(e.hp)
	if not minimal and (blocked_hits > 0): combo.append("배리어 −%d" % barrier_removed)
	if not minimal and (focus_triggers > 0): combo.append("집중 추가 피해 %d" % focus_damage)
	if not minimal and (heat_added > 0): combo.append("열 +%d" % heat_added)
	if not minimal and (cooled > 0): combo.append("냉각 −%d" % cooled)
	if attack: s.buff = AttackBoosts.consume(s.buff)
	var boost_replaced := false
	if spec.effect == "boost":
		var boost_channel := "carry" if Content.is_compressed(id) else ("factor" if Content.boost_factor(id,s) > 1 else "flat")
		boost_replaced = AttackBoosts.layers(s.buff).any(func(v): return AttackBoosts.channel(v) == boost_channel)
		s.buff = AttackBoosts.prepare(s.buff, int(profile.effect), Content.boost_factor(id, s), Content.boost_rounds(id), Content.is_compressed(id), bool(spec.get("boost_hot",false)), int(spec.get("boost_heat",0)))
		if not minimal: combo.append("다음 공격 %d발 %s" % [Content.boost_rounds(id), Content.boost_label(id, s)])
	var burn_added := 0
	if spec.effect == "burn" and int(e.hp) > 0:
		burn_added = int(profile.burn)
		e.burn = mini(6, int(e.get("burn", 0)) + burn_added)
		if not minimal: combo.append("화상 %d · 턴당 %d" % [e.burn, int(profile.burn_tick)])
	var pushed := 0
	if int(e.hp) > 0 and spec.effect == "push":
		var local_budget := int(s.push_left) + int(spec.get("push_budget_bonus", 0)) * Content.multiplier(s)
		pushed = mini(int(profile.effect), local_budget)
		e.distance += pushed
		s.push_left = maxi(0, int(s.push_left) - pushed)
	var secondary: Array = []
	var relay_hits := 0
	var relay_damage := 0
	if attack and int(e.hp)<=0:
		var remainder := maxi(0,per_hit-hp_before) if requested_hits==1 and blocked_hits==0 and active_parts.has("siege_drive") else 0
		var remaining_hits := requested_hits-hits if active_parts.has("volley_drive") else 0
		# Target-dependent bonuses are recomputed; the prepared buff is paid only once.
		var base_subtotal := subtotal-weakness_bonus-(2 if active_parts.has("igniter") and burn_before>0 else 0)-(2 if active_parts.has("executioner") and hp_before<=5 else 0)
		var relay := _engine_relay(id,remaining_hits,remainder,base_subtotal,factor,engine_percent,pen,active_parts)
		secondary = relay.events
		relay_hits = int(relay.hits)
		relay_damage = int(relay.damage)
	Engines.observe(s,active_parts,(hits-blocked_hits if damage>0 else 0)+relay_hits,engine_percent>100 and active_parts.has("thermal_drive"),(damage-detonation+relay_damage) if requested_hits==1 else 0)
	# A hot direct hit that reaches the heat limit releases a single pressure wave.
	# Resolve before kill-cooling: a kill-cooling build may earn its way out of reload.
	var shock_damage := 0
	if active_parts.has("thermal_drive") and engine_percent>100 and damage-detonation>0 and int(s.heat)>=int(profile.heat_limit):
		var shock_raw := int(raw/2)
		for other_index in active_targets():
			if int(other_index)==index: continue
			var other := target_entity(int(other_index))
			var blocked := int(other.get("barrier",0))>0
			var dealt := 0 if blocked else mini(int(other.hp),maxi(0,shock_raw-int(other.def)))
			if blocked: other.barrier = int(other.barrier)-1
			other.hp -= dealt
			shock_damage += dealt
			secondary.append({"kind":"heat_wave","target":other_index,"damage":dealt,"hp":other.hp,"raw":shock_raw,"armor":other.def,"barrier":int(other.get("barrier",0)),"blocked_hits":1 if blocked else 0,"intercept":Ranged.is_projectile(int(other_index)) and int(other.hp)<=0})
	var interrupted := 0
	if spec.effect == "disrupt" and int(e.hp) > 0 and not Ranged.is_projectile(index) and not bool(e.get("disrupted", false)):
		if int(e.get("charge_max", 0)) > 0 or (str(e.get("kind", "")) == "spitter" and str(e.get("ranged_phase", "")) == "prepare"):
			interrupted = int(profile.effect)
			e.jammed = interrupted
			e.disrupted = true
	var transferred := 0
	if spec.effect == "spread" and not Ranged.is_projectile(index) and burn_before > 0:
		var others: Array = []
		for i in range(s.enemies.size()):
			if i != index and int(s.enemies[i].hp) > 0: others.append(i)
		others.sort_custom(func(a: int, b: int): return int(s.enemies[a].distance) < int(s.enemies[b].distance) if int(s.enemies[a].distance) != int(s.enemies[b].distance) else a < b)
		if not others.is_empty():
			var other: Dictionary = s.enemies[others[0]]
			transferred = mini(mini(burn_before, int(profile.effect)), 6 - int(other.get("burn", 0)))
			e.burn = int(e.burn) - transferred
			other.burn = int(other.get("burn", 0)) + transferred
			if transferred > 0: secondary.append({"kind": "burn_transfer", "target": others[0], "damage": 0, "hp": other.hp, "burn": other.burn, "transferred": transferred})
	if spec.effect == "arc":
		var others: Array = []
		for i in active_targets():
			if i != index: others.append(i)
		others.sort_custom(func(a: int, b: int):
			if int(target_entity(a).distance) == int(target_entity(b).distance):
				if Ranged.is_projectile(a) != Ranged.is_projectile(b): return Ranged.is_projectile(a)
				return a < b
			return int(target_entity(a).distance) < int(target_entity(b).distance)
		)
		var target_count := mini(others.size(), int(spec.get("arc_targets", 1)) + Content.arc_target_bonus(s))
		for other_index in range(target_count):
			var other: int = int(others[other_index])
			var other_entity := target_entity(other)
			var amount := mini(int(other_entity.hp), int(profile.effect))
			other_entity.hp -= amount
			var impact := {"kind": "arc", "target": other, "damage": amount, "hp": other_entity.hp}
			if Ranged.is_projectile(other): impact.intercept = true
			secondary.append(impact)
		if not minimal and (not secondary.is_empty()): combo.append("전이 %d명" % secondary.size())
	s.previous_kill = alive_count() < alive_before
	var kill_cooled := mini(int(s.heat), int(Content.PARTS.reclaimer.cool_on_kill)) if active_parts.has("reclaimer") and s.previous_kill else 0
	s.heat -= kill_cooled
	var chain_cooled := mini(int(s.heat), int(Content.PARTS.chain_sink.third_cooling)) if active_parts.has("chain_sink") and int(part_context.get("fired_count", -1)) == 2 else 0
	s.heat -= chain_cooled
	if minimal: return {"engine_id":engine_id,"relay_damage":relay_damage,"ordinary_bonus": ordinary_bonus if hits > blocked_hits else 0, "relay_saved": relay_saved, "damage": damage, "heat_after": int(s.heat), "heat_before": heat_before, "overheated": int(s.heat) >= int(profile.heat_limit), "kill_cooled": kill_cooled, "chain_cooled": chain_cooled, "prepared_rounds": prepared_rounds, "interrupted": interrupted, "transferred": transferred, "sequence_bonus": sequence_bonus, "vented": vented, "thermal_bonus": thermal_bonus, "part_hot": active_parts.has("ember_core") and heat_before >= int(profile.hot_threshold) and hits > blocked_hits}
	if relay_saved > 0: combo.append("압축 발열 −%d" % relay_saved)
	if chain_cooled > 0: combo.append("세 번째 발 냉각 −%d" % chain_cooled)
	if interrupted > 0: combo.append("특수 행동 %d턴 차단" % interrupted)
	if transferred > 0: combo.append("화상 %d 이동" % transferred)
	if sequence_bonus > 0: combo.append("탄종 연계 +%d" % sequence_bonus)
	if not prepared_rounds.is_empty():
		var labels: PackedStringArray = []
		for next_id in prepared_rounds: labels.append(Content.AMMO[next_id].name)
		combo.append("다음 패 예약 · " + "/".join(labels))
	if not minimal and (kill_cooled > 0): combo.append("처치 냉각 −%d" % kill_cooled)
	if not minimal and (vented > 0): combo.append("열 %d 소모 · 피해 +%d" % [vented, vent_bonus])
	if not minimal and (thermal_bonus > 0): combo.append("고열 피해 +%d" % thermal_bonus)
	var math := {"base": int(profile.damage), "boost": dmg_buff, "weakness": weakness_bonus, "part_bonus": part_bonus, "thermal": thermal_bonus, "vent": vent_bonus, "subtotal": subtotal, "factor": factor, "raw": raw, "armor": armor, "per_hit": per_hit, "hits": hits, "hp_before": hp_before, "armor_before": int(e.def), "focus": focus_damage, "barrier_before": barrier_before, "blocked_hits": blocked_hits, "barrier_removed": barrier_removed}
	var description := "%s → %s: %d피해" % [spec.name, e.name, damage]
	if not combo.is_empty(): description += " · " + " / ".join(combo)
	if e.hp == 0: description += " · 요격" if Ranged.is_projectile(index) else " · 처치"
	var result := {"id": id, "target": index, "hit": true, "damage": damage, "hits": hits, "pen": pen, "hp": e.hp, "burn": int(e.get("burn", 0)), "burn_added": burn_added, "burn_tick": int(profile.burn_tick), "push": pushed, "secondary": secondary, "math": math, "combo": combo, "text": description, "focus_before": focus_before, "focus_after": int(e.get("focus_hits", 0)), "focus_damage": focus_damage, "focus_triggers": focus_triggers, "barrier_before": barrier_before, "barrier": int(e.get("barrier", 0)), "blocked_hits": blocked_hits, "barrier_removed": barrier_removed, "boost_granted": int(profile.effect) if spec.effect == "boost" else 0}
	result.engine_id = engine_id
	result.engine_percent = engine_percent
	result.relay_damage = relay_damage
	result.relay_hits = relay_hits
	result.shock_damage = shock_damage
	result.math.engine_percent = engine_percent
	result.boost_rounds = Content.boost_rounds(id)
	result.boost_replaced = boost_replaced
	result.boost_hot = bool(spec.get("boost_hot",false))
	result.boost_heat = int(spec.get("boost_heat",0))
	result.boost_heat_paid = int(applied.heat)
	result.boost_hot_failed = bool(applied.hot_failed)
	result.boost_factor_granted = Content.boost_factor(id, s) if spec.effect == "boost" else 1
	result.pending_boost = s.buff.duplicate(true)
	result.part_effects = preload("res://redesign/part_feedback.gd").shot_effects(s, result, part_effects, burn_before)
	if chain_cooled > 0: result.part_effects.append({"id": "chain_sink", "label": "세 번째 발 냉각 −%d" % chain_cooled})
	if active_parts.has("indexer") and prepared_rounds.size() > Content.multiplier(s): result.part_effects.append({"id": "indexer", "label": "예약 +1장"})
	if transferred > int(spec.value) * Content.multiplier(s):
		if active_parts.has("coil"): result.part_effects.append({"id": "coil", "label": "화상 이동 강화"})
		if active_parts.has("inferno"): result.part_effects.append({"id": "inferno", "label": "화상 이동 강화"})
	if kill_cooled > 0: result.part_effects.append({"id": "reclaimer", "label": "처치 냉각 −%d" % kill_cooled})
	if relay_saved > 0: result.part_effects.append({"id": "compression_sink", "label": "압축 발열 −%d" % relay_saved})
	result.relay_saved = relay_saved
	result.ordinary_bonus = ordinary_bonus
	result.heat_added = heat_added
	result.cooled = cooled + vented + kill_cooled + chain_cooled
	result.chain_cooled = chain_cooled
	result.prepared_rounds = prepared_rounds
	result.interrupted = interrupted
	result.transferred = transferred
	result.sequence_bonus = sequence_bonus
	result.math.sequence = sequence_bonus
	result.kill_cooled = kill_cooled
	result.vented = vented
	result.thermal_bonus = thermal_bonus
	result.vent_bonus = vent_bonus
	result.heat_after = int(s.heat)
	result.heat_before = heat_before
	result.overheated = int(s.heat) >= Content.heat_limit(s)
	result.chase_bonus = chase_bonus
	result.detonation = detonation
	result.armor_removed = armor_removed
	result.armor = int(e.def)
	result.stance_def = int(e.get("stance_def", 0))
	if Ranged.is_gatekeeper(e): result.guard_armor = int(e.guard_armor)
	result.math.armor_before = armor_before
	result.math.chase = chase_bonus
	if Ranged.is_projectile(index) and int(e.hp) == 0: result.intercept = true
	return result

# Follow-up direct impacts are bounded by remaining hits/targets. No recursive
# status, boost, heat or proc reactivation. Scatter's initial target stays random;
# continuation always uses the public nearest-target rule.
func _engine_relay(id: String, remaining: int, overflow: int, base: int, factor: int, percent: int, pen: int, parts: Array) -> Dictionary:
	var events: Array = []
	var total := 0
	var connected := 0
	while remaining>0 or overflow>0:
		var next := target_index()
		if next<0: break
		var other := target_entity(next)
		var is_overflow := overflow>0
		var hp := int(other.hp)
		var blocked := int(other.get("barrier",0))>0
		var amount := overflow
		if not is_overflow:
			var added := Content.weakness_bonus(id,other)+(2 if parts.has("igniter") and int(other.get("burn",0))>0 else 0)+(2 if parts.has("executioner") and hp<=5 else 0)
			amount = int((base+added)*factor*percent/100.0)
		amount = maxi(0,amount-maxi(0,int(other.def)-pen)) if is_overflow else (maxi(1,amount-maxi(0,int(other.def)-pen)) if amount>0 else 0)
		var dealt := 0
		if blocked:
			other.barrier = maxi(0,int(other.barrier)-(2 if parts.has("breaker") else 1))
		else:
			dealt = mini(hp,amount)
			other.hp -= dealt
			if dealt>0: connected += 1
		if not is_overflow and s.gun=="burst":
			other.focus_hits = int(other.get("focus_hits",0))+1
			if int(other.focus_hits)>=3:
				other.focus_hits = 0
				var extra := mini(4,int(other.hp)) if not blocked else 0
				other.hp -= extra
				dealt += extra
		total += dealt
		events.append({"kind":"overflow" if is_overflow else "relay","target":next,"damage":dealt,"hp":int(other.hp),"barrier":int(other.get("barrier",0)),"focus_hits":int(other.get("focus_hits",0)),"blocked_hits":1 if blocked else 0,"intercept":Ranged.is_projectile(next) and int(other.hp)<=0})
		if is_overflow: overflow = maxi(0,amount-hp) if not blocked else 0
		else: remaining -= 1
	return {"events":events,"damage":total,"hits":connected}

func preview() -> Dictionary:
	var stack: Array = s.plan if s.phase == "plan" else s.magazine
	if stack.is_empty() or target_index() < 0 or s.gun == "scatter":
		return {}
	var copy = get_script().new()
	copy.s = s.duplicate(true)
	var recent: Array = _recent_part_sources() if s.phase == "ready" else []
	var source: String = Content.source_id(str(stack.front()))
	var triad_ready: bool = recent.size() >= 2 and recent[-1] != recent[-2] and source != recent[-1] and source != recent[-2]
	var rounds := _recent_part_rounds() if s.phase == "ready" else []
	return copy._shot(str(stack.front()), -1, {"previous_round": str(rounds.back()) if not rounds.is_empty() else "", "first": recent.is_empty(), "last": stack.size() == 1, "last_attack": not stack.slice(1).any(func(round_id): return Content.is_attack(str(round_id))), "triad": triad_ready, "fired_count": recent.size(), "sequence_count": Content.prior_kind_count(recent, str(stack.front()))})

func movement_preview(turn_count: int) -> Array:
	var copy = get_script().new()
	copy.s = s.duplicate(true)
	copy._advance(turn_count)
	var result: Array = []
	for e in copy.s.enemies: result.append(int(e.distance))
	return result

func choose_reward(id: String, remove_id: String = "") -> bool:
	if s.phase != "reward" or s.reward_taken:
		return false
	var options: Array = reward_options()
	if id == "skip":
		pass
	elif id == "remove":
		if s.deck.size() <= minimum_deck() or not s.deck.has(remove_id):
			return false
		s.deck.erase(remove_id)
	elif options.has(id) and Content.AMMO.has(id):
		if s.deck.size() >= deck_limit():
			return false
		s.deck.append(id)
	elif options.has(id) and Content.PARTS.has(id):
		var equipped := Content.equipped_parts(s)
		var proposed := equipped.duplicate()
		proposed.append(id)
		if not Content.valid_part_set(str(s.gun), proposed): return false
		s.equipped_parts = proposed
		s.part = id
	else:
		return false
	s.reward_taken = true
	_record("reward", {"choice": id, "removed": remove_id})
	s.floor += 1
	if s.get("course", false): s.deck.append_array(Content.COURSE_GRANTS[int(s.floor)])
	begin_encounter()
	return true

func minimum_deck() -> int:
	return 2 if s.get("course", false) else 8

func deck_limit() -> int:
	var reserved := 0
	if s.get("course", false):
		for stage in range(int(s.floor) + 1, 7): reserved += Content.COURSE_GRANTS[stage].size()
	return 14 - reserved

func reward_options() -> Array:
	var options := Content.rewards_for(int(s.floor), int(s.seed), str(s.gun), s.get("course", false))
	for id in Content.equipped_parts(s): options.erase(str(id))
	return options

func remove_planned(index: int) -> bool:
	if s.phase != "plan" or index < 0 or index >= s.plan.size(): return false
	var id: String = str(s.plan[index])
	if Content.is_temporary(id): return _cancel_field_compression()
	s.plan.remove_at(index)
	var history_index: int = s.plan_load_order.rfind(id)
	if history_index >= 0: s.plan_load_order.remove_at(history_index)
	return true

func can_move_planned(from: int, to: int) -> bool:
	if s.phase != "plan" or from == to or from < 0 or to < 0 or from >= s.plan.size() or to >= s.plan.size(): return false
	var proposed: Array = s.plan.duplicate()
	var id: String = str(proposed.pop_at(from))
	proposed.insert(to, id)
	return Content.valid_stack(proposed, capacity())

func move_planned(from: int, to: int) -> bool:
	if not can_move_planned(from, to): return false
	var id: String = str(s.plan.pop_at(from))
	s.plan.insert(to, id)
	return true

func field_compressible_ids() -> Array:
	var result: Array = []
	if s.phase != "plan" or s.get("course", false) or int(s.get("field_compression_left", 0)) <= 0 or not s.get("field_compression", {}).is_empty():
		return result
	for source in Content.FIELD_COMPRESSIONS:
		if can_field_compress(str(source)): result.append(str(source))
	return result

func can_field_compress(source: String) -> bool:
	if s.phase != "plan" or s.get("course", false) or int(s.get("field_compression_left", 0)) <= 0 or not s.get("field_compression", {}).is_empty(): return false
	if not Content.FIELD_COMPRESSIONS.has(source) or Content.is_compressed(source) or available(source) < 2: return false
	return Content.can_insert(s.plan, Content.field_id(source), capacity())

func field_compress(source: String) -> bool:
	if not can_field_compress(source): return false
	var id := Content.field_id(source)
	s.hand.erase(source)
	s.hand.erase(source)
	var index := Content.insertion_index(s.plan, id)
	s.plan.insert(index, id)
	s.plan_load_order.append(id)
	s.field_compression = {"source": source, "id": id, "zone": "plan"}
	s.field_compression_left -= 1
	s.message = "%s 두 발을 현장 압축 · 확정 전 되돌리면 압축 코어가 복구됩니다." % Content.AMMO[source].name
	return true

func _cancel_field_compression() -> bool:
	if s.phase != "plan" or s.get("field_compression", {}).is_empty() or str(s.field_compression.get("zone", "")) != "plan": return false
	var id := str(s.field_compression.id)
	var source := str(s.field_compression.source)
	var plan_index: int = s.plan.find(id)
	var order_index: int = s.plan_load_order.find(id)
	if plan_index < 0 or order_index < 0: return false
	s.plan.remove_at(plan_index)
	s.plan_load_order.remove_at(order_index)
	s.hand.append(source)
	s.hand.append(source)
	s.field_compression = {}
	s.field_compression_left = mini(2 + Content.field_compression_bonus(s), int(s.field_compression_left) + 1)
	s.message = "현장 압축 취소 · 원본 두 발과 압축 코어를 복구했습니다."
	return true

func _discard_fired_round(id: String) -> void:
	if Content.is_temporary(id) and not s.get("field_compression", {}).is_empty() and str(s.field_compression.get("id", "")) == id:
		var source := str(s.field_compression.source)
		s.discard.append(source)
		s.discard.append(source)
		s.field_compression = {}
	elif id != "basic" or Content.uses_ammo_cards(s):
		s.discard.append(id)

func _release_unfired_field_round() -> void:
	if s.get("field_compression", {}).is_empty() or str(s.field_compression.get("zone", "")) != "magazine": return
	var id := str(s.field_compression.id)
	if s.magazine.has(id):
		s.magazine.erase(id)
		_discard_fired_round(id)

func exchange(id: String) -> bool:
	if s.phase != "plan" or int(s.exchange_left) <= 0 or (id == "basic" and not Content.uses_ammo_cards(s)) or available(id) <= 0: return false
	# The exchanged round joins discard only AFTER replacement: never redraw itself.
	if s.draw.is_empty() and s.discard.is_empty(): return false
	s.hand.erase(id)
	_refill(s.hand.size() + 1)
	s.discard.append(id)
	s.exchange_left -= 1
	s.message = "%s 교환 · 다음 재장전 때 교환 %d회 복구" % [Content.AMMO[id].name, Content.exchange_capacity(s)]
	_record("exchange", {"id": id})
	return true

func _shuffle(items: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.state = int(s.rng_state)
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var value = items[i]
		items[i] = items[j]
		items[j] = value
	s.rng_state = str(rng.state)

func _draw_prepared() -> void:
	# Reservations move owned cards, never add cards or consume draw RNG.
	for id in s.get("prepared", []):
		if s.hand.size() >= Content.hand_capacity(s): break
		for zone in [s.discard, s.draw]:
			if zone.has(id):
				zone.erase(id)
				s.hand.append(id)
				break
	s.prepared = []

func _refill(target_size: int = -1) -> void:
	if target_size < 0: target_size = Content.hand_capacity(s)
	while s.hand.size() < target_size:
		if s.draw.is_empty():
			if s.discard.is_empty():
				break
			s.draw = s.discard.duplicate()
			s.discard.clear()
			_shuffle(s.draw)
		s.hand.append(s.draw.pop_front())

func _record(action: String, detail: Dictionary) -> void:
	s.history.append({"action": action, "floor": s.floor, "turn": s.turns, "detail": detail})
	if s.has("encounter_id"): s.history.back()["node"] = s.encounter_id

func save_run(path: String) -> Error:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(s))
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path)

func restore_run(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return false
	var parsed = parser.data
	if not parsed is Dictionary:
		return false
	return restore_state(parsed)

func restore_state(source: Dictionary) -> bool:
	var parsed: Dictionary = source.duplicate(true)
	if parsed.has("ammo_cycle") and not _whole(parsed.ammo_cycle, 1, 1): return false
	if not Content.valid_bag_state(parsed): return false
	if parsed.has("outfit") and (not parsed.outfit is String or not Content.OUTFITS.has(parsed.outfit)): return false
	if int(parsed.get("version", -1)) == 2:
		parsed = _migrate_v7(_migrate_v6(_migrate_v5(_migrate_v4(_migrate_v3(_migrate_v2(parsed))))))
	elif int(parsed.get("version", -1)) == 3:
		parsed = _migrate_v7(_migrate_v6(_migrate_v5(_migrate_v4(_migrate_v3(parsed)))))
	elif int(parsed.get("version", -1)) == 4:
		parsed = _migrate_v7(_migrate_v6(_migrate_v5(_migrate_v4(parsed))))
	elif int(parsed.get("version", -1)) == 5:
		parsed = _migrate_v7(_migrate_v6(_migrate_v5(parsed)))
	elif int(parsed.get("version", -1)) == 6:
		parsed = _migrate_v7(_migrate_v6(parsed))
	elif int(parsed.get("version", -1)) == 7:
		parsed = _migrate_v7(parsed)
	elif int(parsed.get("version", -1)) not in [8, 9, 10, 11, 12, 13, 14, VERSION]:
		return false
	if int(parsed.version)<15: parsed.engine = Engines.fresh()
	if not Engines.valid(parsed.get("engine")): return false
	if not parsed.has("course"): parsed.course = false
	if not parsed.course is bool: return false
	# Old heat meant extra reload turns, never temperature. Preserve that debt
	# for one reload while migrating to a zero-temperature v9 state.
	if int(parsed.version) == 8:
		if not _whole(parsed.get("reload_heat", 0), 0, 1000000): return false
		parsed.legacy_reload_penalty = int(parsed.get("reload_heat", 0))
		parsed.heat = 0
		parsed.erase("reload_heat")
		parsed.version = VERSION
	if int(parsed.version) in [9, 10, 11, 12, 13, 14]:
		# Saved arrays already describe displayed firing order. Keep that order,
		# including a confirmed/partially fired magazine; new input uses LIFO.
		parsed.version = VERSION
	if not parsed.has("prepared"): parsed.prepared = []
	if not _whole(parsed.get("heat", -1), 0, 1000000): return false
	if not _whole(parsed.get("legacy_reload_penalty", 0), 0, 1000000): return false
	parsed.heat = int(parsed.heat)
	parsed.legacy_reload_penalty = int(parsed.get("legacy_reload_penalty", 0))
	if not parsed.get("previous_kill", false) is bool: return false
	parsed.previous_kill = bool(parsed.get("previous_kill", false))
	if parsed.heat > 0 and parsed.get("phase", "") not in ["plan", "ready"]: return false
	if parsed.legacy_reload_penalty > 0 and parsed.get("phase", "") != "ready": return false
	for key in ["seed", "gun", "part", "equipped_parts", "floor", "deck", "turns", "shots", "reloads", "history", "reward_taken", "phase", "enemies", "reinforcements", "encounter_total", "deployed", "wave", "hand", "draw", "discard", "magazine", "plan", "plan_load_order", "buff", "push_left", "supply", "rng_state", "target_rng_state", "message", "exchange_left", "field_compression_left", "field_compression"]:
		if not parsed.has(key):
			return false
	if not Content.GUNS.has(parsed.gun) or not Content.PARTS.has(parsed.part) or not _whole(parsed.floor, 0, 6) or not parsed.phase in ["plan", "ready", "reward", "won", "lost"]:
		return false
	if parsed.heat >= Content.heat_limit(parsed): return false
	if not parsed.equipped_parts is Array or not Content.valid_part_set(str(parsed.gun), parsed.equipped_parts): return false
	# `part` remains readable for older automation and v7 migration. A current save
	# must still satisfy the five-slot and one-core limits after that legacy value
	# is folded into the equipped list.
	if not Content.valid_part_set(str(parsed.gun), Content.equipped_parts(parsed)): return false
	# JSON numbers cannot preserve every signed 64-bit seed. New saves use text;
	# old ordinary numeric seeds remain readable, unsafe numeric seeds are rejected.
	if parsed.seed is String:
		if not parsed.seed.is_valid_int() or str(int(parsed.seed)) != parsed.seed:
			return false
	elif not _whole(parsed.seed, -9007199254740991, 9007199254740991):
		return false
	parsed.seed = str(int(parsed.seed))
	if not parsed.rng_state is String or not parsed.rng_state.is_valid_int() or not parsed.target_rng_state is String or not parsed.target_rng_state.is_valid_int():
		return false
	for key in ["turns", "shots", "reloads"]:
		if not _whole(parsed[key], 0, 1000000): return false
	if not parsed.history is Array or not parsed.message is String or not parsed.reward_taken is bool or not parsed.buff is Dictionary:
		return false
	if not AttackBoosts.valid(parsed.buff): return false
	if not _whole(parsed.get("capacity_bonus", 0), 0, 2): return false
	var limit: int = Content.capacity(parsed)
	var supply_limit := Content.supply_capacity(parsed)
	if not _whole(parsed.exchange_left, 0, Content.exchange_capacity(parsed)): return false
	var compression_limit := 2 + Content.field_compression_bonus(parsed)
	if not _whole(parsed.field_compression_left, 0, compression_limit) or not parsed.field_compression is Dictionary: return false
	if parsed.buff.has("dmg") != parsed.buff.has("dmg_left"): return false
	if parsed.buff.has("persistent") and not parsed.buff.has("dmg"): return false
	if parsed.buff.has("dmg") and not _whole(parsed.buff.dmg_left, 1, 2): return false
	if not _whole(parsed.supply, 0, supply_limit) or not _whole(parsed.push_left, 0, Content.push_budget(parsed)): return false
	for key in ["deck", "hand", "draw", "discard", "magazine", "plan", "plan_load_order"]:
		if not parsed[key] is Array:
			return false
		for id in parsed[key]:
			if not Content.AMMO.has(id): return false
			if key in ["deck", "hand", "draw", "discard"] and id == "basic" and not Content.uses_ammo_cards(parsed): return false
			if key in ["deck", "hand", "draw", "discard"] and Content.is_temporary(str(id)): return false
	if not parsed.prepared is Array or parsed.prepared.size() > 3: return false
	for id in parsed.prepared:
		if not id is String or not Content.AMMO.has(id) or (id == "basic" and not Content.uses_ammo_cards(parsed)) or Content.is_temporary(id): return false
		if parsed.prepared.count(id) > parsed.deck.count(id): return false
	# Legacy city saves may already contain six or seven cards. They remain
	# readable, while every new removal/compression path enforces the new floor 8.
	if parsed.deck.size() < (2 if parsed.course else 6) or parsed.deck.size() > 14 or parsed.hand.size() > Content.hand_capacity(parsed) or not Content.valid_stack(parsed.magazine, limit) or not Content.valid_stack(parsed.plan, limit):
		return false
	if (parsed.phase == "plan" and not parsed.magazine.is_empty()) or (parsed.phase != "plan" and (not parsed.plan.is_empty() or not parsed.plan_load_order.is_empty())): return false
	var planned_sorted: Array = parsed.plan.duplicate()
	var history_sorted: Array = parsed.plan_load_order.duplicate()
	planned_sorted.sort()
	history_sorted.sort()
	if planned_sorted != history_sorted: return false
	for id in parsed.plan:
		if not Content.is_temporary(str(id)):
			var count: int = int(parsed.supply) if id == "basic" and not Content.uses_ammo_cards(parsed) else parsed.hand.count(id)
			if parsed.plan.count(id) > count: return false
	var transient_ids: Array = []
	for id in parsed.plan + parsed.magazine:
		if Content.is_temporary(str(id)): transient_ids.append(str(id))
	if parsed.field_compression.is_empty():
		if not transient_ids.is_empty(): return false
	else:
		for key in ["source", "id", "zone"]:
			if not parsed.field_compression.has(key) or not parsed.field_compression[key] is String: return false
		var field_source := str(parsed.field_compression.source)
		var field_id := str(parsed.field_compression.id)
		var field_zone := str(parsed.field_compression.zone)
		if not Content.FIELD_COMPRESSIONS.has(field_source) or Content.field_id(field_source) != field_id or transient_ids != [field_id] or int(parsed.field_compression_left) > compression_limit - 1: return false
		if field_zone == "plan":
			if parsed.phase != "plan" or parsed.plan.count(field_id) != 1 or parsed.plan_load_order.count(field_id) != 1: return false
		elif field_zone == "magazine":
			if parsed.phase != "ready" or parsed.magazine.count(field_id) != 1: return false
		else: return false
	if parsed.course and (int(parsed.field_compression_left) != 0 or not parsed.field_compression.is_empty()): return false
	var owned: Array = parsed.hand + parsed.draw + parsed.discard
	for id in parsed.magazine:
		if Content.is_temporary(str(id)):
			owned.append(Content.compression_source(str(id)))
			owned.append(Content.compression_source(str(id)))
		elif id != "basic" or Content.uses_ammo_cards(parsed): owned.append(id)
	for id in parsed.plan:
		if Content.is_temporary(str(id)):
			owned.append(Content.compression_source(str(id)))
			owned.append(Content.compression_source(str(id)))
	owned.sort()
	var expected: Array = parsed.deck.duplicate()
	expected.sort()
	if owned != expected: return false
	if not parsed.enemies is Array or parsed.enemies.is_empty() or parsed.enemies.size() > 8: return false
	if not parsed.reinforcements is Array or parsed.reinforcements.size() > 8 or parsed.enemies.size() + parsed.reinforcements.size() > 8: return false
	if not _whole(parsed.encounter_total, 1, 8) or not _whole(parsed.deployed, 1, 8) or not _whole(parsed.wave, 1, 8): return false
	for enemy in parsed.enemies + parsed.reinforcements:
		if not _valid_enemy(enemy): return false
	if not Ranged.valid_state(parsed): return false
	parsed.projectiles = parsed.get("projectiles", [])
	parsed.projectile_serial = int(parsed.get("projectile_serial", 0))
	parsed.loss_reason = str(parsed.get("loss_reason", ""))
	s = parsed
	return true

func _migrate_v3(old_state: Dictionary) -> Dictionary:
	var old_seed: Variant = old_state.get("seed")
	if old_seed is String:
		if not old_seed.is_valid_int() or str(int(old_seed)) != old_seed: return {}
	elif not _whole(old_seed, -9007199254740991, 9007199254740991): return {}
	if not _whole(old_state.get("floor"), 0, 6): return {}
	var migrated: Dictionary = old_state.duplicate(true)
	migrated.target_rng_state = _target_state(migrated)
	migrated.version = 4
	return migrated

func _migrate_v4(old_state: Dictionary) -> Dictionary:
	var migrated: Dictionary = old_state.duplicate(true)
	migrated.plan_load_order = migrated.get("plan", []).duplicate()
	migrated.version = 5
	return migrated

func _migrate_v5(old_state: Dictionary) -> Dictionary:
	var migrated: Dictionary = old_state.duplicate(true)
	migrated.field_compression_left = 0 if migrated.get("course", false) else 1
	migrated.field_compression = {}
	migrated.version = 6
	return migrated

func _migrate_v6(old_state: Dictionary) -> Dictionary:
	var migrated: Dictionary = old_state.duplicate(true)
	migrated.reinforcements = []
	migrated.encounter_total = migrated.get("enemies", []).size()
	migrated.deployed = migrated.get("enemies", []).size()
	migrated.wave = 1
	migrated.version = 7
	return migrated

func _migrate_v7(old_state: Dictionary) -> Dictionary:
	var migrated: Dictionary = old_state.duplicate(true)
	var legacy := str(migrated.get("part", "none"))
	migrated.equipped_parts = [legacy] if Content.PARTS.has(legacy) and legacy != "none" else []
	migrated.version = 8
	return migrated

func _migrate_v2(old_state: Dictionary) -> Dictionary:
	var migrated: Dictionary = old_state.duplicate(true)
	var replacements := {"mark": "charge", "slow": "push", "finish": "pierce"}
	for key in ["deck", "hand", "draw", "discard", "magazine", "plan"]:
		if migrated.get(key) is Array:
			for i in range(migrated[key].size()):
				var old_id := str(migrated[key][i])
				if replacements.has(old_id): migrated[key][i] = replacements[old_id]
	if migrated.get("buff") is Dictionary:
		migrated.buff.erase("acc")
		migrated.buff.erase("acc_left")
	if migrated.get("enemies") is Array:
		for enemy in migrated.enemies:
			if not enemy is Dictionary: continue
			enemy.erase("eva")
			enemy.erase("slow")
			enemy.erase("crack")
			enemy.burn = 0
			if Content.ENEMY_NAMES.has(enemy.get("kind", "")): enemy.name = Content.ENEMY_NAMES[enemy.kind]
	migrated.version = 3
	return migrated

func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float): return false
	return is_finite(float(value)) and float(value) == floorf(float(value)) and value >= minimum and value <= maximum

func _valid_enemy(enemy: Variant) -> bool:
	if not enemy is Dictionary: return false
	if not _whole(enemy.get("jammed", 0), 0, 2) or not enemy.get("disrupted", false) is bool: return false
	if int(enemy.get("jammed", 0)) > 0 and not bool(enemy.get("disrupted", false)): return false
	for key in ["kind", "name", "hp", "max_hp", "def", "speed", "distance", "burn"]:
		if not enemy.has(key): return false
	if not Content.ENEMY_NAMES.has(enemy.kind) or not enemy.name is String: return false
	for key in ["hp", "max_hp", "def", "speed", "distance", "burn"]:
		if not _whole(enemy[key], 0, 1000000): return false
	if enemy.hp > enemy.max_hp or not _whole(enemy.burn, 0, 6) or not _whole(enemy.get("focus_hits", 0), 0, 2): return false
	if not _whole(enemy.get("barrier", 0), 0, 9) or not _whole(enemy.get("barrier_max", 0), 0, 9) or int(enemy.get("barrier", 0)) > int(enemy.get("barrier_max", 0)): return false
	if not _whole(enemy.get("charge", 0), 0, 9) or not _whole(enemy.get("charge_max", 0), 0, 9) or not _whole(enemy.get("charge_pull", 0), 0, 9): return false
	if int(enemy.get("charge_max", 0)) > 0 and int(enemy.get("charge", 0)) >= int(enemy.get("charge_max", 0)): return false
	if enemy.has("stance") and not enemy.stance is bool: return false
	if bool(enemy.get("stance", false)):
		if not enemy.get("stance_closed", true) is bool or not _whole(enemy.get("stance_def", 4), 0, 9): return false
		if int(enemy.def) != (int(enemy.stance_def) if bool(enemy.get("stance_closed", true)) else 0): return false
	if enemy.has("lane") and not _whole(enemy.lane, -1, 3): return false
	if enemy.has("weakness") and (not enemy.weakness is String or not str(enemy.weakness) in ["", "electric"]): return false
	return true
