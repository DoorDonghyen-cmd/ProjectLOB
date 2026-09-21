extends RefCounted
## One serializable state; commands validate before mutation. Preview executes the
## same shot resolver on a copy and never changes live state or RNG.
const Content = preload("res://redesign/content.gd")
const VERSION := 8
var s: Dictionary = {}

func start(gun_id: String, run_seed: int, course: bool = false) -> void:
	assert(Content.GUNS.has(gun_id))
	s = {"version": VERSION, "course": course, "seed": str(run_seed), "gun": gun_id, "part": "none", "equipped_parts": [], "floor": 0, "deck": Content.COURSE_GRANTS[0].duplicate() if course else Content.start_deck(gun_id), "turns": 0, "shots": 0, "reloads": 0, "history": [], "reward_taken": false}
	begin_encounter()

func begin_encounter(field_charges: int = 1) -> void:
	s.phase = "plan"
	s.enemies = Content.enemies_for(int(s.floor), int(s.seed), s.get("course", false), str(s.gun))
	s.reinforcements = []
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
	s.push_left = Content.push_budget(s)
	s.exchange_left = 1
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
	s.message = "탄환을 누른 순서대로 발사 · 칸을 눌러 회수 · 확정 전 자유롭게 설계"
	_record("encounter", {"index": s.floor})

func capacity() -> int:
	return Content.capacity(s)

func reload_cost() -> int:
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
	return (int(s.supply) if id == "basic" else s.hand.count(id)) - s.plan.count(id)

func can_load(id: String) -> bool:
	return s.phase == "plan" and Content.AMMO.has(id) and not Content.is_temporary(id) and available(id) > 0 and Content.can_insert(s.plan, id, capacity())

func load_round(id: String) -> bool:
	if not can_load(id):
		return false
	var index := Content.insertion_index(s.plan, id)
	s.plan.insert(index, id)
	s.plan_load_order.append(id)
	s.message = "%s 추가 · 왼쪽부터 차례대로 발사합니다." % Content.AMMO[id].name
	return true

func undo() -> bool:
	if s.phase != "plan" or s.plan.is_empty() or s.plan_load_order.is_empty():
		return false
	var id: String = str(s.plan_load_order.back())
	if Content.is_temporary(id):
		return _cancel_field_compression()
	s.plan_load_order.pop_back()
	var index: int = s.plan.rfind(id)
	if index < 0: return false
	s.plan.remove_at(index)
	return true

func confirm() -> bool:
	if s.phase != "plan" or s.plan.is_empty() or not Content.valid_stack(s.plan, capacity()):
		return false
	for id in s.plan:
		if not Content.AMMO.has(id) or (Content.is_temporary(id) and str(s.field_compression.get("id", "")) != id) or (not Content.is_temporary(id) and available(id) < 0):
			return false
	for id in s.plan:
		if id == "basic":
			s.supply -= 1
		elif not Content.is_temporary(id):
			s.hand.erase(id)
	s.magazine = s.plan.duplicate()
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
	# Amplifier is the deliberate single-shot weapon, but a kill keeps the trigger
	# window open. The first survivor ends the execution chain and advances time.
	var count: int = s.magazine.size() if Content.chains(s) or s.gun == "amplifier" else 1
	var recent_sources: Array = _recent_part_sources()
	for i in range(count):
		if target_index() < 0:
			break
		var id: String = s.magazine.pop_front()
		var source: String = Content.source_id(id)
		var triad_ready: bool = recent_sources.size() >= 2 and recent_sources[-1] != recent_sources[-2] and source != recent_sources[-1] and source != recent_sources[-2]
		var result := _shot(id, -1, {"first": recent_sources.is_empty(), "last": s.magazine.is_empty(), "triad": triad_ready})
		results.append(result)
		recent_sources.append(source)
		s.shots += 1
		_discard_fired_round(id)
		if s.gun == "amplifier" and int(result.get("hp", 1)) > 0:
			break
	s.turns += 1
	var advance_events: Array = []
	if target_index() < 0 and reserve_count() == 0:
		s.phase = "won" if int(s.floor) == Content.ENCOUNTERS.size() - 1 else "reward"
		s.reward_taken = false
	else:
		advance_events = _advance(1)
	var deployments: Array = []
	if s.phase != "lost" and reserve_count() > 0:
		deployments = _deploy_reinforcements(target_index() < 0)
	if s.phase != "lost" and target_index() < 0 and reserve_count() == 0:
		s.phase = "won" if int(s.floor) == Content.ENCOUNTERS.size() - 1 else "reward"
		s.reward_taken = false
	if s.phase in ["reward", "won", "lost"]:
		_release_unfired_field_round()
	var lines: PackedStringArray = []
	for result in results:
		lines.append(result.text)
	s.message = "\n".join(lines)
	if not deployments.is_empty():
		s.message += "\n증원 %d기 투입 · 대기 %d기" % [deployments.size(), reserve_count()]
	if s.phase == "lost":
		s.message += "\n적이 0m에 도달했습니다. 같은 시드로 다시 설계할 수 있습니다."
	_record("fire", {"results": results, "advance_events": advance_events, "deployments": deployments, "phase": s.phase})
	return true

func _recent_part_sources() -> Array:
	var result: Array = []
	for history_index in range(s.history.size() - 1, -1, -1):
		var event: Dictionary = s.history[history_index]
		if str(event.get("action", "")) == "load": break
		if str(event.get("action", "")) != "fire": continue
		var fired: Array = []
		for shot in event.get("detail", {}).get("results", []): fired.append(Content.source_id(str(shot.get("id", ""))))
		for fired_index in range(fired.size() - 1, -1, -1): result.push_front(fired[fired_index])
	return result

func reload_magazine() -> bool:
	if s.phase != "ready":
		return false
	for id in s.magazine.duplicate():
		_discard_fired_round(str(id))
	s.magazine.clear()
	if bool(s.buff.get("persistent", false)):
		s.buff.erase("persistent")
	else:
		s.buff = {}
	s.reloads += 1
	var cost := reload_cost()
	var advance_events := _advance(cost, true)
	var deployments: Array = []
	if s.phase != "lost" and reserve_count() > 0 and target_index() < 0:
		deployments = _deploy_reinforcements(true)
	# Count each actual elapsed turn, including a lethal partial reload.
	if s.phase in ["reward", "won"]:
		s.message = "화상이 전진 전에 마지막 적을 처치했습니다."
	elif s.phase != "lost":
		s.phase = "plan"
		s.supply = supply_capacity()
		s.push_left = Content.push_budget(s)
		s.exchange_left = 1
		_refill()
		s.message = "재장전 완료 · %d턴 경과 · 남은 패 유지, 빈 자리 보충" % cost
	else:
		s.message = "재장전 도중 적이 0m에 도달했습니다."
	_record("reload", {"cost": cost, "advance_events": advance_events, "deployments": deployments, "phase": s.phase})
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
				events.append({"turn": i, "target": enemy_index, "kind": "burn", "damage": hp_before - int(e.hp), "hp": e.hp, "burn": e.burn})
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
			if int(source.hp) <= 0 or int(source.get("charge_max", 0)) <= 0:
				continue
			source.charge = int(source.get("charge", 0)) + 1
			var released := int(source.charge) >= int(source.charge_max)
			events.append({"turn": i, "target": source_index, "kind": "charge", "charge": 0 if released else source.charge, "charge_max": source.charge_max, "released": released})
			if released:
				source.charge = 0
				var pull := int(source.get("charge_pull", 2))
				for enemy_index in range(s.enemies.size()):
					if enemy_index == source_index or int(s.enemies[enemy_index].hp) <= 0: continue
					var ally: Dictionary = s.enemies[enemy_index]
					var before_pull := int(ally.distance)
					ally.distance = maxi(0, before_pull - pull)
					events.append({"turn": i, "target": enemy_index, "source": source_index, "kind": "pull", "from": before_pull, "to": ally.distance, "amount": pull})
					if int(ally.distance) == 0: s.phase = "lost"
		if s.phase == "lost":
			break
		for enemy_index in range(s.enemies.size()):
			var e: Dictionary = s.enemies[enemy_index]
			if int(e.hp) <= 0: continue
			var distance_before := int(e.distance)
			e.distance = maxi(0, distance_before - int(e.speed))
			events.append({"turn": i, "target": enemy_index, "kind": "move", "from": distance_before, "to": e.distance})
			if int(e.distance) == 0:
				s.phase = "lost"
		# Stance changes after movement and is therefore the public defense for the
		# player's next decision. Multi-turn reloads alternate once per elapsed turn.
		for enemy_index in range(s.enemies.size()):
			var e: Dictionary = s.enemies[enemy_index]
			if int(e.hp) <= 0 or not bool(e.get("stance", false)): continue
			e.stance_closed = not bool(e.get("stance_closed", true))
			e.def = int(e.get("stance_def", 4)) if bool(e.stance_closed) else 0
			events.append({"turn": i, "target": enemy_index, "kind": "stance", "def": e.def, "closed": e.stance_closed})
		if s.phase == "lost":
			break
	return events

func target_index() -> int:
	var selected := -1
	var distance := 99999
	for i in range(s.enemies.size()):
		var e: Dictionary = s.enemies[i]
		if int(e.hp) > 0 and int(e.distance) < distance:
			selected = i
			distance = int(e.distance)
	return selected

func alive_count() -> int:
	var count := 0
	for enemy in s.get("enemies", []):
		if int(enemy.get("hp", 0)) > 0: count += 1
	return count

func reserve_count() -> int:
	return s.get("reinforcements", []).size()

func has_remaining_enemies() -> bool:
	return alive_count() > 0 or reserve_count() > 0

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

func _random_target() -> int:
	var alive: Array = []
	for i in range(s.enemies.size()):
		if int(s.enemies[i].hp) > 0: alive.append(i)
	if alive.is_empty(): return -1
	var rng := RandomNumberGenerator.new()
	rng.state = int(s.target_rng_state)
	var index: int = alive[rng.randi_range(0, alive.size() - 1)]
	s.target_rng_state = str(rng.state)
	return index

func _target_state(state: Dictionary) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state.get("seed", 0)) ^ (int(state.get("floor", 0)) * 7919 + 15485863)
	return str(rng.state)

func _shot(id: String, forced_target: int = -1, part_context: Dictionary = {}) -> Dictionary:
	var index := forced_target if forced_target >= 0 else (_random_target() if s.gun == "scatter" else target_index())
	if index < 0 or index >= s.enemies.size(): return {}
	var e: Dictionary = s.enemies[index]
	if int(e.hp) <= 0: return {}
	var spec: Dictionary = Content.AMMO[id]
	var dmg_buff := int(s.buff.get("dmg", 0))
	var pen := Content.penetration(id, s)
	var weakness_bonus := Content.weakness_bonus(id, e)
	var part_bonus := 0
	var part_combo: PackedStringArray = []
	if Content.has_part(s, "igniter") and int(e.get("burn", 0)) > 0:
		part_bonus += 2
		part_combo.append("점화 +2")
	if Content.has_part(s, "executioner") and int(e.hp) <= 5:
		part_bonus += 2
		part_combo.append("처형 +2")
	if Content.has_part(s, "opening") and bool(part_context.get("first", false)):
		part_bonus += 2
		part_combo.append("선두 +2")
	if Content.has_part(s, "afterburner") and bool(part_context.get("last", false)):
		part_bonus += 3
		part_combo.append("후미 +3")
	if Content.has_part(s, "triad") and bool(part_context.get("triad", false)):
		part_bonus += 5
		part_combo.append("삼중 +5")
	var raw := Content.damage(id, s) + dmg_buff + weakness_bonus + part_bonus
	var armor := maxi(0, int(e.def) - pen)
	var per_hit := maxi(1, raw - armor)
	var requested_hits := Content.hit_count(id, s)
	var hp_before := int(e.hp)
	var focus_before := int(e.get("focus_hits", 0))
	var focus_damage := 0
	var focus_triggers := 0
	var hits := 0
	var barrier_before := int(e.get("barrier", 0))
	var blocked_hits := 0
	var barrier_removed := 0
	var combo: Array = []
	if dmg_buff > 0: combo.append("증폭")
	if weakness_bonus > 0: combo.append("약점 +%d" % weakness_bonus)
	combo.append_array(part_combo)
	for hit_index in range(requested_hits):
		if int(e.hp) <= 0: break
		hits += 1
		var blocked := false
		if int(e.get("barrier", 0)) > 0:
			var removed := mini(int(e.barrier), 2 if Content.has_part(s, "breaker") else 1)
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
	var damage := hp_before - int(e.hp)
	var math := {"base": Content.damage(id, s), "boost": dmg_buff, "weakness": weakness_bonus, "part_bonus": part_bonus, "raw": raw, "armor": armor, "per_hit": per_hit, "hits": hits, "hp_before": hp_before, "armor_before": int(e.def), "focus": focus_damage, "barrier_before": barrier_before, "blocked_hits": blocked_hits, "barrier_removed": barrier_removed}
	if blocked_hits > 0: combo.append("배리어 −%d" % barrier_removed)
	if focus_triggers > 0: combo.append("집중 추가 피해 %d" % focus_damage)
	if s.buff.has("dmg"):
		s.buff.dmg_left -= 1
		if s.buff.dmg_left <= 0:
			s.buff.erase("dmg")
			s.buff.erase("dmg_left")
			s.buff.erase("persistent")
	if spec.effect == "boost":
		s.buff.dmg = Content.effect_value(id, s)
		s.buff.dmg_left = 2
		if Content.is_compressed(id): s.buff.persistent = true
		combo.append("다음 2발 +%d" % s.buff.dmg)
	var burn_added := 0
	if spec.effect == "burn" and int(e.hp) > 0:
		burn_added = Content.burn_amount(id, s)
		e.burn = mini(6, int(e.get("burn", 0)) + burn_added)
		combo.append("화상 %d · 턴당 %d" % [e.burn, Content.burn_damage(s)])
	var pushed := 0
	if int(e.hp) > 0 and spec.effect == "push":
		var local_budget := int(s.push_left) + int(spec.get("push_budget_bonus", 0)) * Content.multiplier(s)
		pushed = mini(Content.effect_value(id, s), local_budget)
		e.distance += pushed
		s.push_left = maxi(0, int(s.push_left) - pushed)
	var secondary: Array = []
	if spec.effect == "arc":
		var others: Array = []
		for i in range(s.enemies.size()):
			if i != index and s.enemies[i].hp > 0: others.append(i)
		others.sort_custom(func(a: int, b: int):
			if int(s.enemies[a].distance) == int(s.enemies[b].distance): return a < b
			return int(s.enemies[a].distance) < int(s.enemies[b].distance)
		)
		var target_count := mini(others.size(), int(spec.get("arc_targets", 1)) + Content.arc_target_bonus(s))
		for other_index in range(target_count):
			var other: int = int(others[other_index])
			var amount := mini(int(s.enemies[other].hp), Content.effect_value(id, s))
			s.enemies[other].hp -= amount
			secondary.append({"kind": "arc", "target": other, "damage": amount, "hp": s.enemies[other].hp})
		if not secondary.is_empty(): combo.append("전이 %d명" % secondary.size())
	var description := "%s → %s: %d피해" % [spec.name, e.name, damage]
	if not combo.is_empty(): description += " · " + " / ".join(combo)
	if e.hp == 0: description += " · 처치"
	return {"id": id, "target": index, "hit": true, "damage": damage, "hits": hits, "pen": pen, "hp": e.hp, "burn": int(e.get("burn", 0)), "burn_added": burn_added, "burn_tick": Content.burn_damage(s), "push": pushed, "secondary": secondary, "math": math, "combo": combo, "text": description, "focus_before": focus_before, "focus_after": int(e.get("focus_hits", 0)), "focus_damage": focus_damage, "focus_triggers": focus_triggers, "barrier_before": barrier_before, "barrier": int(e.get("barrier", 0)), "blocked_hits": blocked_hits, "barrier_removed": barrier_removed, "boost_granted": Content.effect_value(id, s) if spec.effect == "boost" else 0}

func preview() -> Dictionary:
	var stack: Array = s.plan if s.phase == "plan" else s.magazine
	if stack.is_empty() or target_index() < 0 or s.gun == "scatter":
		return {}
	var copy = get_script().new()
	copy.s = s.duplicate(true)
	var recent: Array = _recent_part_sources() if s.phase == "ready" else []
	var source: String = Content.source_id(str(stack.front()))
	var triad_ready: bool = recent.size() >= 2 and recent[-1] != recent[-2] and source != recent[-1] and source != recent[-2]
	return copy._shot(str(stack.front()), -1, {"first": recent.is_empty(), "last": stack.size() == 1, "triad": triad_ready})

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
	elif id != "basic":
		s.discard.append(id)

func _release_unfired_field_round() -> void:
	if s.get("field_compression", {}).is_empty() or str(s.field_compression.get("zone", "")) != "magazine": return
	var id := str(s.field_compression.id)
	if s.magazine.has(id):
		s.magazine.erase(id)
		_discard_fired_round(id)

func exchange(id: String) -> bool:
	if s.phase != "plan" or int(s.exchange_left) <= 0 or id == "basic" or available(id) <= 0: return false
	# The exchanged round joins discard only AFTER replacement: never redraw itself.
	if s.draw.is_empty() and s.discard.is_empty(): return false
	s.hand.erase(id)
	_refill()
	s.discard.append(id)
	s.exchange_left -= 1
	s.message = "%s 교환 · 다음 재장전 때 교환 1회 복구" % Content.AMMO[id].name
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

func _refill() -> void:
	while s.hand.size() < 5:
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
	elif int(parsed.get("version", -1)) != VERSION:
		return false
	if not parsed.has("course"): parsed.course = false
	if not parsed.course is bool: return false
	for key in ["seed", "gun", "part", "equipped_parts", "floor", "deck", "turns", "shots", "reloads", "history", "reward_taken", "phase", "enemies", "reinforcements", "encounter_total", "deployed", "wave", "hand", "draw", "discard", "magazine", "plan", "plan_load_order", "buff", "push_left", "supply", "rng_state", "target_rng_state", "message", "exchange_left", "field_compression_left", "field_compression"]:
		if not parsed.has(key):
			return false
	if not Content.GUNS.has(parsed.gun) or not Content.PARTS.has(parsed.part) or not _whole(parsed.floor, 0, 6) or not parsed.phase in ["plan", "ready", "reward", "won", "lost"]:
		return false
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
	for key in parsed.buff:
		if key == "persistent":
			if not parsed.buff[key] is bool: return false
		elif not key in ["dmg", "dmg_left"] or not _whole(parsed.buff[key], 0, 10): return false
	if not _whole(parsed.get("capacity_bonus", 0), 0, 2): return false
	var limit: int = Content.capacity(parsed)
	var supply_limit := Content.supply_capacity(parsed)
	if not _whole(parsed.exchange_left, 0, 1): return false
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
			if key in ["deck", "hand", "draw", "discard"] and id == "basic": return false
			if key in ["deck", "hand", "draw", "discard"] and Content.is_temporary(str(id)): return false
	# Legacy city saves may already contain six or seven cards. They remain
	# readable, while every new removal/compression path enforces the new floor 8.
	if parsed.deck.size() < (2 if parsed.course else 6) or parsed.deck.size() > 14 or parsed.hand.size() > 5 or not Content.valid_stack(parsed.magazine, limit) or not Content.valid_stack(parsed.plan, limit):
		return false
	if (parsed.phase == "plan" and not parsed.magazine.is_empty()) or (parsed.phase != "plan" and (not parsed.plan.is_empty() or not parsed.plan_load_order.is_empty())): return false
	var planned_sorted: Array = parsed.plan.duplicate()
	var history_sorted: Array = parsed.plan_load_order.duplicate()
	planned_sorted.sort()
	history_sorted.sort()
	if planned_sorted != history_sorted: return false
	for id in parsed.plan:
		if not Content.is_temporary(str(id)):
			var count: int = int(parsed.supply) if id == "basic" else parsed.hand.count(id)
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
			owned.append(Content.source_id(str(id)))
			owned.append(Content.source_id(str(id)))
		elif id != "basic": owned.append(id)
	for id in parsed.plan:
		if Content.is_temporary(str(id)):
			owned.append(Content.source_id(str(id)))
			owned.append(Content.source_id(str(id)))
	owned.sort()
	var expected: Array = parsed.deck.duplicate()
	expected.sort()
	if owned != expected: return false
	if not parsed.enemies is Array or parsed.enemies.is_empty() or parsed.enemies.size() > 8: return false
	if not parsed.reinforcements is Array or parsed.reinforcements.size() > 8 or parsed.enemies.size() + parsed.reinforcements.size() > 8: return false
	if not _whole(parsed.encounter_total, 1, 8) or not _whole(parsed.deployed, 1, 8) or not _whole(parsed.wave, 1, 8): return false
	for enemy in parsed.enemies + parsed.reinforcements:
		if not _valid_enemy(enemy): return false
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
	migrated.version = VERSION
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
		if not enemy.get("stance_closed", true) is bool or not _whole(enemy.get("stance_def", 4), 1, 9): return false
		if int(enemy.def) != (int(enemy.stance_def) if bool(enemy.get("stance_closed", true)) else 0): return false
	if enemy.has("lane") and not _whole(enemy.lane, -1, 3): return false
	if enemy.has("weakness") and (not enemy.weakness is String or not str(enemy.weakness) in ["", "electric"]): return false
	return true
