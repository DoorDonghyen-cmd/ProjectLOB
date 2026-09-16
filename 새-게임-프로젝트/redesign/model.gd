extends RefCounted
## One serializable state; commands validate before mutation. Preview executes the
## same shot resolver on a copy and never changes live state or RNG.
const Content = preload("res://redesign/content.gd")
const VERSION := 3
var s: Dictionary = {}

func start(gun_id: String, run_seed: int, course: bool = false) -> void:
	assert(Content.GUNS.has(gun_id))
	s = {"version": VERSION, "course": course, "seed": str(run_seed), "gun": gun_id, "part": "none", "floor": 0, "deck": Content.COURSE_GRANTS[0].duplicate() if course else Content.START_DECK.duplicate(), "turns": 0, "shots": 0, "reloads": 0, "history": [], "reward_taken": false}
	begin_encounter()

func begin_encounter() -> void:
	s.phase = "plan"
	s.enemies = Content.enemies_for(int(s.floor), int(s.seed), s.get("course", false), str(s.gun))
	s.hand = []
	s.draw = s.deck.duplicate()
	s.discard = []
	s.magazine = []
	s.plan = []
	s.buff = {}
	s.push_left = 2
	s.exchange_left = 1
	s.supply = supply_capacity()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(s.seed) + int(s.floor) * 104729
	s.rng_state = str(rng.state)
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
	return int(Content.GUNS[s.gun].capacity) + (1 if s.part == "supply" else 0)

func reload_cost() -> int:
	return maxi(1, int(Content.GUNS[s.gun].reload) - (1 if s.part == "loader" else 0))

func supply_capacity() -> int:
	return capacity()

func available(id: String) -> int:
	return (int(s.supply) if id == "basic" else s.hand.count(id)) - s.plan.count(id)

func load_round(id: String) -> bool:
	if s.phase != "plan" or not Content.AMMO.has(id) or s.plan.size() >= capacity() or available(id) <= 0:
		return false
	s.plan.append(id)
	s.message = "%s 추가 · 왼쪽부터 차례대로 발사합니다." % Content.AMMO[id].name
	return true

func undo() -> bool:
	if s.phase != "plan" or s.plan.is_empty():
		return false
	s.plan.pop_back()
	return true

func confirm() -> bool:
	if s.phase != "plan" or s.plan.is_empty() or s.plan.size() > capacity():
		return false
	for id in s.plan:
		if not Content.AMMO.has(id) or available(id) < 0:
			return false
	for id in s.plan:
		if id == "basic":
			s.supply -= 1
		else:
			s.hand.erase(id)
	s.magazine = s.plan.duplicate()
	_record("load", {"load_order": s.plan.duplicate(), "hand_left": s.hand.duplicate()})
	s.plan.clear()
	s.phase = "ready"
	s.message = "장전 확정. 발사하거나 %d턴을 써서 다시 장전할 수 있습니다." % reload_cost()
	return true

func fire() -> bool:
	if s.phase != "ready" or s.magazine.is_empty():
		return false
	var results: Array = []
	var count: int = s.magazine.size() if s.gun == "burst" else 1
	for i in range(count):
		if target_index() < 0:
			break
		var id: String = s.magazine.pop_front()
		var result := _shot(id)
		results.append(result)
		s.shots += 1
		if id != "basic":
			s.discard.append(id)
	s.turns += 1
	var advance_events: Array = []
	if target_index() < 0:
		s.phase = "won" if int(s.floor) == Content.ENCOUNTERS.size() - 1 else "reward"
		s.reward_taken = false
	else:
		advance_events = _advance(1)
	var lines: PackedStringArray = []
	for result in results:
		lines.append(result.text)
	s.message = "\n".join(lines)
	if s.phase == "lost":
		s.message += "\n적이 0m에 도달했습니다. 같은 시드로 다시 설계할 수 있습니다."
	_record("fire", {"results": results, "advance_events": advance_events, "phase": s.phase})
	return true

func reload_magazine() -> bool:
	if s.phase != "ready":
		return false
	for id in s.magazine:
		if id != "basic":
			s.discard.append(id)
	s.magazine.clear()
	s.buff = {}
	s.reloads += 1
	var cost := reload_cost()
	var advance_events := _advance(cost, true)
	# Count each actual elapsed turn, including a lethal partial reload.
	if s.phase in ["reward", "won"]:
		s.message = "화상이 전진 전에 마지막 적을 처치했습니다."
	elif s.phase != "lost":
		s.phase = "plan"
		s.supply = supply_capacity()
		s.push_left = 2
		s.exchange_left = 1
		_refill()
		s.message = "재장전 완료 · %d턴 경과 · 남은 패 유지, 빈 자리 보충" % cost
	else:
		s.message = "재장전 도중 적이 0m에 도달했습니다."
	_record("reload", {"cost": cost, "advance_events": advance_events, "phase": s.phase})
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
				e.hp = maxi(0, hp_before - 1)
				e.burn = maxi(0, int(e.burn) - 1)
				events.append({"turn": i, "target": enemy_index, "kind": "burn", "damage": hp_before - int(e.hp), "hp": e.hp, "burn": e.burn})
		if target_index() < 0:
			s.phase = "won" if int(s.floor) == Content.ENCOUNTERS.size() - 1 else "reward"
			s.reward_taken = false
			break
		for enemy_index in range(s.enemies.size()):
			var e: Dictionary = s.enemies[enemy_index]
			if int(e.hp) <= 0: continue
			var distance_before := int(e.distance)
			e.distance = maxi(0, distance_before - int(e.speed))
			events.append({"turn": i, "target": enemy_index, "kind": "move", "from": distance_before, "to": e.distance})
			if int(e.distance) == 0:
				s.phase = "lost"
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

func _shot(id: String) -> Dictionary:
	var index := target_index()
	if index < 0: return {}
	var e: Dictionary = s.enemies[index]
	var spec: Dictionary = Content.AMMO[id]
	var dmg_buff := int(s.buff.get("dmg", 0))
	var pen := Content.penetration(id, s)
	var raw := int(spec.dmg) + int(Content.GUNS[s.gun].bonus) + dmg_buff
	var combo: Array = []
	if dmg_buff > 0: combo.append("증폭")
	var armor := maxi(0, int(e.def) - pen)
	var per_hit := maxi(1, raw - armor)
	var hits := 2 if spec.effect == "double" else 1
	var hp_before := int(e.hp)
	var math := {"base": int(spec.dmg) + int(Content.GUNS[s.gun].bonus), "boost": dmg_buff, "raw": raw, "armor": armor, "per_hit": per_hit, "hits": hits, "hp_before": hp_before, "armor_before": int(e.def)}
	var damage := mini(hp_before, per_hit * hits)
	e.hp -= damage
	if s.buff.has("dmg"):
		s.buff.dmg_left -= 1
		if s.buff.dmg_left <= 0:
			s.buff.erase("dmg")
			s.buff.erase("dmg_left")
	if spec.effect == "boost":
		s.buff.dmg = spec.value
		s.buff.dmg_left = 2
		combo.append("다음 2발 증폭")
	var burn_added := 0
	if spec.effect == "burn" and int(e.hp) > 0:
		burn_added = Content.burn_amount(id, s)
		e.burn = mini(6, int(e.get("burn", 0)) + burn_added)
		combo.append("화상 %d" % e.burn)
	var pushed := 0
	if int(e.hp) > 0:
		if spec.effect == "push":
			pushed = mini(int(spec.value), int(s.push_left))
			e.distance += pushed
			s.push_left -= pushed
	var secondary: Array = []
	if spec.effect == "arc":
		var other := -1
		for i in range(s.enemies.size()):
			if i != index and s.enemies[i].hp > 0 and (other < 0 or s.enemies[i].distance < s.enemies[other].distance): other = i
		if other >= 0:
			var amount := mini(int(s.enemies[other].hp), int(spec.value))
			s.enemies[other].hp -= amount
			secondary.append({"target": other, "damage": amount, "hp": s.enemies[other].hp})
			combo.append("전이 %d" % amount)
	var description := "%s → %s: %d피해" % [spec.name, e.name, damage]
	if not combo.is_empty(): description += " · " + " / ".join(combo)
	if e.hp == 0: description += " · 처치"
	return {"id": id, "target": index, "hit": true, "damage": damage, "hits": hits, "pen": pen, "hp": e.hp, "burn": int(e.get("burn", 0)), "burn_added": burn_added, "push": pushed, "secondary": secondary, "math": math, "combo": combo, "text": description}

func preview() -> Dictionary:
	var stack: Array = s.plan if s.phase == "plan" else s.magazine
	if stack.is_empty() or target_index() < 0:
		return {}
	var copy = get_script().new()
	copy.s = s.duplicate(true)
	return copy._shot(str(stack.front()))

func movement_preview(turn_count: int) -> Array:
	var result: Array = []
	for e in s.enemies:
		var hp := int(e.hp)
		var burn := int(e.get("burn", 0))
		var distance := int(e.distance)
		for i in range(turn_count):
			if hp <= 0: break
			if burn > 0:
				hp -= 1
				burn -= 1
			if hp > 0: distance = maxi(0, distance - int(e.speed))
		result.append(distance)
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
	return 2 if s.get("course", false) else 6

func deck_limit() -> int:
	var reserved := 0
	if s.get("course", false):
		for stage in range(int(s.floor) + 1, 7): reserved += Content.COURSE_GRANTS[stage].size()
	return 14 - reserved

func reward_options() -> Array:
	var options := Content.rewards_for(int(s.floor), int(s.seed), str(s.gun), s.get("course", false))
	options.erase(str(s.part))
	return options

func remove_planned(index: int) -> bool:
	if s.phase != "plan" or index < 0 or index >= s.plan.size(): return false
	s.plan.remove_at(index)
	return true

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
	if int(parsed.get("version", -1)) == 2:
		parsed = _migrate_v2(parsed)
	elif int(parsed.get("version", -1)) != VERSION:
		return false
	if not parsed.has("course"): parsed.course = false
	if not parsed.course is bool: return false
	for key in ["seed", "gun", "part", "floor", "deck", "turns", "shots", "reloads", "history", "reward_taken", "phase", "enemies", "hand", "draw", "discard", "magazine", "plan", "buff", "push_left", "supply", "rng_state", "message", "exchange_left"]:
		if not parsed.has(key):
			return false
	if not Content.GUNS.has(parsed.gun) or not Content.PARTS.has(parsed.part) or not _whole(parsed.floor, 0, 6) or not parsed.phase in ["plan", "ready", "reward", "won", "lost"]:
		return false
	# JSON numbers cannot preserve every signed 64-bit seed. New saves use text;
	# old ordinary numeric seeds remain readable, unsafe numeric seeds are rejected.
	if parsed.seed is String:
		if not parsed.seed.is_valid_int() or str(int(parsed.seed)) != parsed.seed:
			return false
	elif not _whole(parsed.seed, -9007199254740991, 9007199254740991):
		return false
	parsed.seed = str(int(parsed.seed))
	if not parsed.rng_state is String or not parsed.rng_state.is_valid_int():
		return false
	for key in ["turns", "shots", "reloads"]:
		if not _whole(parsed[key], 0, 1000000): return false
	if not parsed.history is Array or not parsed.message is String or not parsed.reward_taken is bool or not parsed.buff is Dictionary:
		return false
	for key in parsed.buff:
		if not key in ["dmg", "dmg_left"] or not _whole(parsed.buff[key], 0, 10): return false
	var limit: int = int(Content.GUNS[parsed.gun].capacity) + (1 if parsed.part == "supply" else 0)
	var supply_limit := limit
	if not _whole(parsed.exchange_left, 0, 1): return false
	if parsed.buff.has("dmg") != parsed.buff.has("dmg_left"): return false
	if parsed.buff.has("dmg") and not _whole(parsed.buff.dmg_left, 1, 2): return false
	if not _whole(parsed.supply, 0, supply_limit) or not _whole(parsed.push_left, 0, 2): return false
	for key in ["deck", "hand", "draw", "discard", "magazine", "plan"]:
		if not parsed[key] is Array:
			return false
		for id in parsed[key]:
			if not Content.AMMO.has(id) or (key in ["deck", "hand", "draw", "discard"] and id == "basic"):
				return false
	if parsed.deck.size() < (2 if parsed.course else 6) or parsed.deck.size() > 14 or parsed.hand.size() > 5 or parsed.magazine.size() > limit or parsed.plan.size() > limit:
		return false
	if (parsed.phase == "plan" and not parsed.magazine.is_empty()) or (parsed.phase != "plan" and not parsed.plan.is_empty()): return false
	for id in parsed.plan:
		var count: int = int(parsed.supply) if id == "basic" else parsed.hand.count(id)
		if parsed.plan.count(id) > count: return false
	var owned: Array = parsed.hand + parsed.draw + parsed.discard
	for id in parsed.magazine:
		if id != "basic": owned.append(id)
	owned.sort()
	var expected: Array = parsed.deck.duplicate()
	expected.sort()
	if owned != expected: return false
	if not parsed.enemies is Array or parsed.enemies.is_empty() or parsed.enemies.size() > 3: return false
	for enemy in parsed.enemies:
		if not enemy is Dictionary: return false
		for key in ["kind", "name", "hp", "max_hp", "def", "speed", "distance", "burn"]:
			if not enemy.has(key): return false
		if not Content.ENEMY_NAMES.has(enemy.kind) or not enemy.name is String: return false
		for key in ["hp", "max_hp", "def", "speed", "distance", "burn"]:
			if not _whole(enemy[key], 0, 1000000): return false
		if enemy.hp > enemy.max_hp or not _whole(enemy.burn, 0, 6): return false
	s = parsed
	return true

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
	migrated.version = VERSION
	return migrated

func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float): return false
	return is_finite(float(value)) and float(value) == floorf(float(value)) and value >= minimum and value <= maximum
