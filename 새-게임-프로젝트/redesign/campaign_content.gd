extends RefCounted
## The production city's names/altitudes remain the single source of truth.
const City = preload("res://scripts/core/map_generator.gd")
const Ammo = preload("res://redesign/content.gd")
const REGIONS := ["section_a", "section_b", "section_c", "section_d", "section_e"]
const LOADOUTS := {
	"balanced": {"name": "무기 기본 보급", "deck": Ammo.START_DECK},
	"amplify": {"name": "증폭·연발", "deck": ["charge", "charge", "charge", "precise", "precise", "precise", "pierce", "pierce", "bore", "push"]},
	"thermal": {"name": "화상·거리", "deck": ["bore", "bore", "bore", "push", "push", "charge", "precise", "precise", "pierce", "arc"]},
	"voltage": {"name": "전격·관통", "deck": ["arc", "arc", "arc", "pierce", "pierce", "charge", "charge", "precise", "precise", "push"]},
}

static func info(region: int) -> Dictionary:
	return City.section_info(REGIONS[region])

static func rng(seed_value: int, salt: int) -> RandomNumberGenerator:
	var random := RandomNumberGenerator.new()
	random.seed = seed_value + salt * 104729
	return random

static func shuffle(values: Array, random: RandomNumberGenerator) -> Array:
	var result := values.duplicate()
	for i in range(result.size() - 1, 0, -1):
		var j := random.randi_range(0, i)
		var temp = result[i]
		result[i] = result[j]
		result[j] = temp
	return result

static func names(region: int) -> Dictionary:
	match region:
		0: return City._names_a()
		1: return City._names_b()
		2: return City._names_c()
		3: return City._names_d()
	return City._names_e()

static func nodes(region: int, seed_value: int) -> Array:
	var result: Array = []
	var table := names(region)
	var floors := int(info(region).floors)
	for floor_number in range(1, floors + 1):
		var kinds: Array = ["combat", "combat"]
		if floor_number == floors: kinds = ["boss"]
		elif floor_number == 2: kinds = ["combat", "event"]
		elif floor_number == 3: kinds = ["supply", "combat"]
		elif floor_number == 4: kinds = ["shop"]
		elif floor_number == 5: kinds = ["combat", "bypass"]
		elif floor_number == 6: kinds = ["combat", "event"]
		for lane in range(kinds.size()):
			var id := region * 10000 + floor_number * 100 + lane + 1
			var old_id := floor_number * 100 + lane + 1
			var kind: String = kinds[lane]
			var label := str(table.get(old_id, ["비공개 구획", ""])[0]).split(" (")[0]
			if kind == "event": label = "비공개 구획"
			var route := "stairs" if lane == 0 else "duct"
			if kind == "shop": route = "stairs" if (seed_value + region) % 2 == 0 else "duct"
			var random := rng(seed_value, id)
			var event_kind: String = ["siphon", "archive", "salvage"][random.randi_range(0, 2)] if kind == "event" else ""
			result.append({"id": id, "region": region, "floor": floor_number, "lane": lane, "kind": kind, "name": label, "route": route, "event": event_kind})
	return result

static func kind_name(kind: String) -> String:
	return {"combat": "전투", "boss": "관문", "shop": "무기고", "supply": "보급", "bypass": "우회", "event": "신호"}.get(kind, kind)

static func hint(node: Dictionary) -> String:
	match str(node.kind):
		"combat": return "적 편성 공개 · 탄환 또는 크레딧 보상"
		"boss": return "계층 관문 · 처치하면 다음 계층으로"
		"shop": return "탄환·파츠 구매 · 보유 파츠 교체"
		"supply": return "공개된 탄환 중 1장 보급"
		"bypass": return "전투 없이 이동 · 기록 1개 발견"
		"event":
			return {"siphon": "전력 잔류 · 크레딧과 접근 거리 교환", "archive": "기록 신호 · 자료 또는 탄환 회수", "salvage": "부품 신호 · 탄환을 크레딧으로 교환"}[node.event]
	return ""

static func _enemy(row: Array, boss_name: String = "") -> Dictionary:
	var kind := str(row[0])
	var enemy := {"kind": kind, "name": boss_name if not boss_name.is_empty() else str(Ammo.ENEMY_NAMES[kind]), "hp": int(row[1]), "max_hp": int(row[1]), "def": int(row[2]), "speed": int(row[3]), "distance": int(row[4]), "burn": 0}
	if kind == "caster":
		enemy.charge = 0
		enemy.charge_max = 3
		enemy.charge_pull = 2
	elif kind == "absorber":
		enemy.barrier = 2
		enemy.barrier_max = 2
	elif kind == "stance":
		enemy.stance = true
		enemy.stance_def = maxi(4, int(row[2]))
		enemy.stance_closed = true
		enemy.def = int(enemy.stance_def)
	elif kind == "evader":
		enemy.weakness = "electric"
	if row.size() > 5:
		var overrides: Dictionary = row[5]
		for key in overrides: enemy[key] = overrides[key]
		if enemy.has("barrier") and not enemy.has("barrier_max"): enemy.barrier_max = enemy.barrier
		if enemy.has("stance") and bool(enemy.stance):
			enemy.stance_def = int(enemy.get("stance_def", maxi(4, int(enemy.def))))
			enemy.stance_closed = bool(enemy.get("stance_closed", true))
			enemy.def = int(enemy.stance_def) if bool(enemy.stance_closed) else 0
	return enemy

static func encounter_pack(node: Dictionary, seed_value: int, gun: String, difficulty: int, pressure: int) -> Dictionary:
	var region := int(node.region)
	var local_floor := int(node.floor)
	var random := rng(seed_value, int(node.id))
	var boss: bool = node.kind == "boss"
	var rows: Array = []
	if region == 0 and local_floor == 1:
		# The first city fight teaches targeting with two fragile bodies. The
		# seven-encounter training course remains the one-enemy tutorial.
		rows = [["runner", 4, 0, 2, 20], ["evader", 4, 0, 2, 24]]
	elif boss:
		# Every gate is an anchor surrounded by a disposable formation. The boss
		# is always in the opening four; later escorts wait in the public queue.
		match region:
			0: rows = [["wall", 14, 2, 1, 23]]
			1: rows = [["caster", 14, 1, 1, 24, {"charge_max": 3, "charge_pull": 2}]]
			2: rows = [["absorber", 16, 1, 1, 25, {"barrier": 3, "barrier_max": 3}]]
			3: rows = [["stance", 18, 4, 2, 26]]
			_: rows = [["stance", 22, 4, 1, 27, {"barrier": 3, "barrier_max": 3, "charge": 0, "charge_max": 3, "charge_pull": 2}]]
		var escort_pool: Array = ["runner", "evader", "wall"]
		if region >= 1: escort_pool.append("caster")
		if region >= 2: escort_pool.append("absorber")
		if region >= 3: escort_pool.append("stance")
		var total := mini(8, 5 + region)
		for i in range(total - 1):
			var kind := str(escort_pool[(i + region) % escort_pool.size()])
			var hp := int({"runner": 4, "evader": 4, "caster": 5, "absorber": 6, "wall": 7, "stance": 7}[kind])
			var armor := 4 if kind == "stance" else (3 if kind == "wall" and region >= 2 else (2 if kind == "wall" else (1 if kind == "absorber" else 0)))
			var speed := 1 if kind in ["wall", "caster", "absorber"] else 2
			rows.append([kind, hp, armor, speed, mini(34, 19 + region * 2 + i * 3)])
	else:
		var count := (2 if local_floor <= 2 else (5 if local_floor >= 5 else 4)) if region == 0 else mini(8, 4 + region)
		var pool: Array = ["runner", "wall", "evader"]
		if region >= 1: pool.append("caster")
		if region >= 2: pool.append("absorber")
		if region >= 3: pool.append("stance")
		var offset := random.randi_range(0, pool.size() - 1)
		for i in range(count):
			var kind := str(pool[(offset + i) % pool.size()])
			var armor := 4 if kind == "stance" else (3 if kind == "wall" and region >= 2 else (2 if kind == "wall" else (1 if kind == "absorber" else 0)))
			var base_hp: int = int({"runner": 4, "evader": 4, "caster": 5, "absorber": 6, "wall": 7, "stance": 7}[kind])
			var hp := base_hp + random.randi_range(0, 1)
			var speed := 1 if kind in ["wall", "caster", "absorber"] else 2
			if region >= 3 and kind == "runner" and local_floor >= 5: speed = 3
			rows.append([kind, hp, armor, speed, mini(34, 18 + region * 2 + i * 3 + (2 if speed == 3 else 0))])
	var enemies: Array = []
	for i in range(rows.size()):
		var row: Array = rows[i]
		var enemy := _enemy(row, str(node.name) if boss and i == 0 else "")
		enemy.distance = maxi(6, int(enemy.distance) - pressure - mini(4, difficulty / 2))
		enemies.append(enemy)
	var active_count := mini(4, enemies.size())
	for i in range(enemies.size()):
		enemies[i].lane = i if i < active_count else -1
	return {"active": enemies.slice(0, active_count), "reserve": enemies.slice(active_count), "total": enemies.size()}

static func encounter(node: Dictionary, seed_value: int, gun: String, difficulty: int, pressure: int) -> Array:
	return encounter_pack(node, seed_value, gun, difficulty, pressure).active

static func rewards(node: Dictionary, seed_value: int) -> Array:
	return shuffle(["charge", "precise", "pierce", "bore", "push", "arc"], rng(seed_value, int(node.id) + 700)).slice(0, 2)

static func eligible_parts(gun: String) -> Array:
	var result: Array = []
	for id in Ammo.PARTS:
		if id == "none": continue
		if Ammo.accepts_part(gun, id): result.append(id)
	return result

static func offers(node: Dictionary, seed_value: int, revision: int, gun: String, owned: Array, seen: Array = []) -> Array:
	var random := rng(seed_value, int(node.id) + 1900 + revision * 37)
	var ammo_id: String = shuffle(["charge", "precise", "pierce", "bore", "push", "arc"], random)[0]
	var parts: Array = eligible_parts(gun)
	for id in owned: parts.erase(id)
	var unseen: Array = []
	var repeated: Array = []
	for id in parts:
		if seen.has(id): repeated.append(id)
		else: unseen.append(id)
	unseen = shuffle(unseen, random)
	repeated = shuffle(repeated, random)
	var selected: Array = unseen.slice(0, 2)
	for id in repeated:
		if selected.size() >= 2: break
		selected.append(id)
	var result: Array = [{"id": ammo_id, "type": "ammo", "price": 12, "sold": false}]
	for id in selected: result.append({"id": id, "type": "part", "price": 30, "sold": false, "new": not seen.has(id)})
	return result
