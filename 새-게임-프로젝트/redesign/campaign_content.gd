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
		"supply": return "탄환 1장 보급 또는 덱 1장 정제"
		"bypass": return "전투 없이 이동 · 기록 1개 발견"
		"event":
			return {"siphon": "전력 잔류 · 크레딧과 접근 거리 교환", "archive": "기록 신호 · 자료 또는 탄환 회수", "salvage": "부품 신호 · 탄환을 크레딧으로 교환"}[node.event]
	return ""

static func encounter(node: Dictionary, seed_value: int, gun: String, difficulty: int, pressure: int) -> Array:
	var region := int(node.region)
	var local_floor := int(node.floor)
	var random := rng(seed_value, int(node.id))
	var boss: bool = node.kind == "boss"
	var rows: Array = []
	if region == 0 and local_floor == 1:
		rows = [["runner", 12, 0, 2, 22]]
	elif boss:
		# More time, but a larger ordered-combo demand; the upper gates have escorts.
		rows = [["wall", 23 + region * 3, 2 + mini(region, 1), 1, 24 + region * 2]]
		if region >= 1: rows.append(["runner", 6 + region, 0, 2, 25 + region * 2])
		if region >= 3: rows.append(["evader", 5 + region, 1, 2, 29 + region * 2])
	else:
		var count := 1 if region == 0 and local_floor < 5 else (3 if region >= 3 and local_floor >= 5 else 2)
		for i in range(count):
			var kind: String = ["runner", "wall", "evader"][(random.randi_range(0, 2) + i) % 3]
			var armor := mini(region + 1, 3) if kind == "wall" else (1 if region >= 2 else 0)
			var hp := (11 if kind == "wall" else 7) + region * 2 + random.randi_range(0, 2)
			var speed := 1 if kind == "wall" else 2
			if region >= 3 and kind == "runner" and local_floor >= 5: speed = 3
			rows.append([kind, hp, armor, speed, 20 + region * 2 + i * 3 + (3 if speed == 3 else 0)])
	var enemies: Array = []
	for i in range(rows.size()):
		var row: Array = rows[i]
		var distance := int(row[4]) - pressure - mini(4, difficulty / 2)
		enemies.append({"kind": row[0], "name": str(node.name) if boss and i == 0 else str(Ammo.ENEMY_NAMES[row[0]]), "hp": row[1], "max_hp": row[1], "def": row[2], "speed": row[3], "distance": maxi(6, distance), "burn": 0})
	return enemies

static func rewards(node: Dictionary, seed_value: int) -> Array:
	return shuffle(["charge", "precise", "pierce", "bore", "push", "arc"], rng(seed_value, int(node.id) + 700)).slice(0, 2)

static func offers(node: Dictionary, seed_value: int, revision: int, gun: String, owned: Array) -> Array:
	var random := rng(seed_value, int(node.id) + 1900 + revision * 37)
	var ammo_id: String = shuffle(["charge", "precise", "pierce", "bore", "push", "arc"], random)[0]
	var parts: Array = ["lens", "coil"]
	if Ammo.accepts_part(gun, "loader"): parts.append("loader")
	for id in owned: parts.erase(id)
	parts = shuffle(parts, random)
	var result: Array = [{"id": ammo_id, "type": "ammo", "price": 12, "sold": false}]
	for id in parts.slice(0, 2): result.append({"id": id, "type": "part", "price": 30, "sold": false})
	return result
