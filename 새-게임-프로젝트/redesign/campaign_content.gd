extends RefCounted
## Stable route IDs and floor counts; current tower names live in this adapter.
const City = preload("res://scripts/core/map_generator.gd")
const Ammo = preload("res://redesign/content.gd")
const BuildGuide = preload("res://redesign/build_guide.gd")
const RouteMap = preload("res://redesign/route_map.gd")
const Residential = preload("res://redesign/residential_roster.gd")
const Discovery = preload("res://redesign/ammo_discovery.gd")
const START_CREDITS := 30
const Acquisition = preload("res://redesign/ammo_acquisition.gd")
const ROUTE_REWARD_BONUS := 6
const REGIONS := ["section_a", "section_b", "section_c", "section_d", "section_e"]
const LOADOUTS := {
	"balanced": {"name": "코어·무기 맞춤", "deck": Ammo.START_DECK},
	"amplify": {"name": "연타 보급", "deck": ["charge", "charge", "charge", "precise", "precise", "precise", "pierce", "pierce", "push", "push"]},
	"thermal": {"name": "소이 보급", "deck": ["bore", "bore", "bore", "push", "push", "arc", "pierce", "pierce", "bore", "arc"]},
	"voltage": {"name": "전격 보급", "deck": ["arc", "arc", "arc", "pierce", "pierce", "charge", "charge", "precise", "precise", "arc"]},
}

static func info(region: int, map_version: int = 1) -> Dictionary:
	var data: Dictionary = City.section_info(REGIONS[region]).duplicate(true)
	if map_version >= 2: data.floors = RouteMap.LENGTHS[region]
	data.name = ["승강장·주거 통로", "축열 주조장", "우수 정원", "송전 회랑", "관측대·제어실"][region]
	data.brief = ["우리 동네를 다시 잠그는 명령은 정상에서 내려옵니다.", "열은 충분합니다. 닫힌 분기로는 닿지 않을 뿐입니다.", "열린 격리문 너머에도 사람이 남아 있습니다.", "공급 목록 밖의 불빛을 따라 정상으로 향하세요.", "중앙의 차단 명령을 해제하고 현장 제어권을 여세요."][region]
	return data

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

static func nodes(region: int, seed_value: int, map_version: int = 1) -> Array:
	if map_version >= 2:
		var generated := RouteMap.generate(region, seed_value, map_version)
		for item in generated:
			if item.kind == "shop": item.name = ["승강장 잡화점", "주조장 고물상", "정원 교역소", "회랑 물자상", "관측대 상점"][region] if map_version >= 3 else preload("res://redesign/city_story.gd").SHOPS[region].place
			if item.kind == "boss" and region == 4: item.name = "중앙 제어실 관문"
		return generated
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
			if kind == "shop": label = preload("res://redesign/city_story.gd").SHOPS[region].place
			if kind == "boss" and region == 4: label = "중앙 제어실 관문"
			var route := "stairs" if lane == 0 else "duct"
			if kind == "shop": route = "stairs" if (seed_value + region) % 2 == 0 else "duct"
			var random := rng(seed_value, id)
			var event_kind: String = ["siphon", "archive", "salvage"][random.randi_range(0, 2)] if kind == "event" else ""
			result.append({"id": id, "region": region, "floor": floor_number, "lane": lane, "kind": kind, "name": label, "route": route, "event": event_kind})
	# Materialize the original topology too: drawing, traversal and validation share one source.
	for item in result:
		item.next = []
		var following := result.filter(func(target): return int(target.floor) == int(item.floor) + 1)
		for target in following:
			if int(item.lane) == 1 and int(target.lane) == 0 and following.size() > 1: continue
			item.next.append(target.id)
	return result

static func room_kind(node: Dictionary) -> String:
	if node.get("elite", false): return "elite"
	if node.get("workshop", false): return "workshop"
	return str(node.kind)

static func kind_name(kind: String) -> String:
	return {"combat": "전투", "elite": "정예", "workshop": "공방", "boss": "관문", "shop": "상점", "supply": "탄약고", "bypass": "샛길", "event": "조우"}.get(kind, kind)

static func hint(node: Dictionary) -> String:
	if int(node.get("map_version", 1)) >= 3:
		if node.get("workshop", false): return "무료 작업 1회 · 압축 / 개조 / 제거 / 가방 확장"
		if node.kind == "shop": return "파츠·탄환·전투용 압축 충전 구매"
		if node.kind == "supply": return "보유 탄 보충 또는 새로운 탄환 · 무료 1장"
		if node.kind == "event": return "사람과 설비가 남긴 흔적 · 현장에서 단서를 살펴보세요."
	if node.get("elite", false): return "정예와 호위 · 위험한 전열\n미보유 파츠 최대 2종 중 1개 또는 크레딧"
	if node.get("workshop", false): return "무료 정비 1회 · 탄환 압축 / 1장 제거 / 압축 코어 충전"
	match str(node.kind):
		"combat": return "적 편성 공개 · 탄환 또는 크레딧 보상"
		"boss": return "최종 관문 · 처치 후 정상 설비 복구" if int(node.region) == 4 else "구역 관문 · 처치하면 다음 구역으로"
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
	elif kind == "spitter":
		enemy.speed = 0
		enemy.ranged_phase = "prepare"
		enemy.ranged_left = 2
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

static func encounter_pack(node: Dictionary, seed_value: int, gun: String, difficulty: int, pressure: int, roster_version: int = 1) -> Dictionary:
	var region := int(node.region)
	var local_floor := int(node.floor)
	var random := rng(seed_value, int(node.id))
	var boss: bool = node.kind == "boss"
	var rows: Array = []
	if region == 0 and local_floor == 1:
		# One new idea: combine rounds before introducing armor or weakness.
		rows = [["runner", 8, 0, 2, 18], ["runner", 12, 0, 2, 22]]
	elif region == 0 and local_floor == 2:
		rows = [["wall", 10, 3, 1, 22], ["runner", 6, 0, 2, 26]]
	elif region == 0 and local_floor == 3:
		rows = [["runner", 6, 0, 2, 21], ["evader", 6, 0, 2, 24], ["wall", 9, 2, 1, 27]]
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
	if not boss and (region > 0 or local_floor >= 5):
		var role := posmod(region + local_floor, 3)
		if role == 0:
			rows[0] = ["wall", 10 + mini(region, 2), 4, 1, 22 + region]
		elif role == 1:
			rows[0] = ["absorber", 7 + mini(region, 2), 0, 1, 22 + region]
		else:
			rows[0] = ["wall", 8, 3, 1, 22 + region]
			rows[1] = ["spitter", 7 + mini(region, 2), 0, 0, 25 + region]
	var residential := region == 0 and roster_version >= 2
	if residential: rows = Residential.rows(node, random)
	if roster_version >= 3: rows = preload("res://redesign/assault_roster.gd").rows(node,random,rows)
	if roster_version >= 4: rows = Acquisition.opening_rows(node, rows)
	if roster_version >= 5: rows = preload("res://redesign/residential_challenges.gd").rows(node, rows)
	var enemies: Array = []
	for i in range(rows.size()):
		var row: Array = rows[i]
		var enemy := _enemy(row, str(node.name) if boss and i == 0 else "")
		if residential: Residential.identify(enemy, boss and i == 0)
		if roster_version >= 5: preload("res://redesign/residential_challenges.gd").identify(enemy, row)
		if node.get("elite", false) and i == 0 and not enemy.has("rank"):
			enemy.hp = ceili(float(enemy.hp) * 1.35)
			enemy.max_hp = enemy.hp
			enemy.name = "강화 " + str(enemy.name)
		# Heat needs a meaningful action deadline. Reserves still enter at their
		# published distance and do not move on their arrival turn.
		var approach := int(enemy.distance)
		if not (region == 0 and local_floor == 1): approach = ceili(approach * 0.65)
		enemy.distance = maxi(6, approach - pressure - mini(4, difficulty / 2))
		if node.get("elite", false): enemy.distance = maxi(6, int(enemy.distance) - 1)
		enemies.append(enemy)
	var active_count := mini(4, enemies.size())
	for i in range(enemies.size()):
		enemies[i].lane = i if i < active_count else -1
	return {"active": enemies.slice(0, active_count), "reserve": enemies.slice(active_count), "total": enemies.size()}

static func encounter(node: Dictionary, seed_value: int, gun: String, difficulty: int, pressure: int) -> Array:
	return encounter_pack(node, seed_value, gun, difficulty, pressure).active

# New roles open in stages; duplicates remain valuable for compression.
static func ammo_pool(node: Dictionary, discovery_version: int = 0) -> Array:
	var pool := _legacy_ammo_pool(node)
	return Discovery.ammo(pool, discovery_version) if discovery_version >= 1 else pool

static func _legacy_ammo_pool(node: Dictionary) -> Array:
	var pool: Array = Ammo.TACTICAL_AMMO.duplicate()
	if int(node.get("region", 0)) == 0:
		if int(node.get("floor", 1)) == 2:
			return pool.slice(0, 6) + ["shatter", "disrupt", "bypass"]
		if int(node.get("floor", 1)) < 2:
			return pool.slice(0, 6)
		if int(node.get("floor", 1)) < 5:
			return pool.slice(0, 9) + ["cool", "disrupt", "bypass"]
	return pool

static func rewards(node: Dictionary, seed_value: int, deck: Array = [], equipped: Array = [], discovery_version: int = 0) -> Array:
	var options := shuffle(ammo_pool(node, discovery_version), rng(seed_value, int(node.id) + 700))
	var families: Array = []
	for id in deck:
		var source := Ammo.source_id(str(id))
		if not families.has(source): families.append(source)
	var links := {"bore": ["detonate", "push", "spread", "disrupt"], "charge": ["precise", "charge_hot", "chase", "prepare"], "precise": ["shatter", "charge", "chase", "prepare"], "arc": ["bypass", "chase", "sequence"], "pierce": ["chase", "bypass", "sequence"], "cool": ["charge_hot", "thermal", "sequence"], "thermal": ["charge_heat", "vent"], "charge_heat": ["thermal", "vent", "precise"], "vent": ["charge_hot", "thermal"], "prepare": ["charge", "precise", "sequence"], "disrupt": ["bore", "bypass"], "spread": ["bore", "detonate"], "sequence": ["shatter", "cool", "prepare"]}
	var partners: Array = families.duplicate()
	if deck.has("charge_hot"):
		partners.append_array(["charge", "precise", "cool", "vent", "thermal"])
	for family in families:
		for id in links.get(family, []):
			if not partners.has(id): partners.append(id)
	var fitting := options.filter(func(id): return partners.has(id))
	var core_options := Discovery.fitting(options, equipped, discovery_version) if discovery_version >= 1 else preload("res://redesign/build_affinity.gd").candidates(options,equipped)
	if not core_options.is_empty(): fitting = core_options
	var first: String = fitting[0] if not fitting.is_empty() else options[0]
	if int(node.get("region", -1)) == 0 and int(node.get("floor", 0)) == 1: first = "pierce"
	options.erase(first)
	var discoveries := options.filter(func(id): return not (families if discovery_version >= 2 else deck).has(id))
	var second: String = discoveries[0] if not discoveries.is_empty() else options[0]
	var result: Array = [first, advanced_offer(second, node, rng(seed_value, int(node.id) + 1700))]
	if discovery_version >= 2:
		var profiles := rng(seed_value, int(node.id) + 3700)
		for i in range(result.size()): result[i] = Ammo.Variants.offer(result[i], Ammo.AMMO, profiles, node)
	return result

static func advanced_offer(id: String, node: Dictionary, random: RandomNumberGenerator) -> String:
	# Keep opening build ingredients accessible; occasional later finds supplement compression.
	if int(node.get("region", 0)) >= 1 and Ammo.COMPRESSIONS.has(id) and random.randf() < 0.15:
		return Ammo.compressed_id(id)
	return id

static func opening_pair(state: Dictionary) -> Array:
	var precise: Array = state.deck.filter(func(id): return Ammo.source_id(str(id)) == "precise")
	if (state.gun == "heavy" or not state.deck.has("charge") or precise.is_empty()) and state.deck.has("bore") and state.deck.has("push"): return ["bore", "push"]
	return ["charge", str(precise[0]) if not precise.is_empty() else "precise"]

static func prepare_opening_hand(model) -> void:
	var wanted := opening_pair(model.s)
	for id in wanted:
		if model.s.hand.has(id) or not model.s.draw.has(id): continue
		for index in range(model.s.hand.size() - 1, -1, -1):
			if wanted.has(model.s.hand[index]): continue
			var draw_index: int = model.s.draw.find(id)
			model.s.draw[draw_index] = model.s.hand[index]
			model.s.hand[index] = id
			break

static func lesson(node: Dictionary, state: Dictionary) -> String:
	if int(node.get("region", -1)) != 0: return ""
	match int(node.get("floor", 0)):
		1: return "충격 → 소이 장전 · 소이가 먼저 발사" if opening_pair(state) == ["bore", "push"] else "연타 → 증폭 장전 · 증폭이 먼저 발사"
		2: return "장갑 돌파 · 관통으로 뚫거나 화상·밀치기로 시간을 버세요"
		3: return "원거리 준비 · 먼저 처치하거나 발사된 압력탄을 요격하세요"
		4, 5: return "증원 대기 · 열은 다음 탄창에도 남습니다"
		6: return "전열 뒤에도 증원 · 다음 탄창과 압축 자원을 남겨두세요"
	return ""

static func eligible_parts(gun: String, discovery_version: int = 0) -> Array:
	var result: Array = []
	for id in Ammo.PARTS:
		if id == "none": continue
		if Ammo.accepts_part(gun, id): result.append(id)
	return Discovery.parts(result) if discovery_version >= 1 else result

static func part_grade_weights(node: Dictionary) -> Array:
	if node.get("elite", false): return [20, 50, 30]
	return [55, 35, 10] if int(node.get("region", 0)) == 0 else [45, 40, 15]

static func pick_part(candidates: Array, node: Dictionary, random: RandomNumberGenerator) -> String:
	# Draw a grade before drawing a part, so adding content does not dilute rarity.
	# Missing grades are renormalized after ownership/discovery/role filtering.
	var weights := part_grade_weights(node)
	var pools: Array = [[], [], []]
	for id in candidates: pools[Ammo.part_grade(str(id))].append(id)
	var total := 0
	for grade in range(3):
		if not pools[grade].is_empty(): total += int(weights[grade])
	if total == 0: return "none"
	var ticket := random.randi_range(1, total)
	for grade in range(3):
		if pools[grade].is_empty(): continue
		ticket -= int(weights[grade])
		if ticket <= 0: return str(pools[grade][random.randi_range(0, pools[grade].size() - 1)])
	return str(candidates[0])

static func offers(node: Dictionary, seed_value: int, revision: int, gun: String, owned: Array, seen: Array = [], seen_ammo: Array = [], equipped: Array = [], discovery_version: int = 0) -> Array:
	var random := rng(seed_value, int(node.id) + 1900 + revision * 37)
	var ammo_choices := shuffle(ammo_pool(node, discovery_version), random)
	var seen_families := seen_ammo.map(func(id): return Ammo.source_id(str(id))) if discovery_version >= 2 else seen_ammo
	var unseen_ammo := ammo_choices.filter(func(id): return not seen_families.has(id) and not seen_families.has(Ammo.compressed_id(id)))
	var ammo_id: String = unseen_ammo[0] if not unseen_ammo.is_empty() else ammo_choices[0]
	ammo_id = advanced_offer(ammo_id, node, rng(seed_value, int(node.id) + 2900 + revision * 37))
	if discovery_version >= 2: ammo_id = Ammo.Variants.offer(ammo_id, Ammo.AMMO, rng(seed_value, int(node.id) + 4700 + revision * 37), node)
	var parts: Array = eligible_parts(gun, discovery_version)
	for id in owned: parts.erase(id)
	var unseen: Array = []
	var repeated: Array = []
	for id in parts:
		if seen.has(id): repeated.append(id)
		else: unseen.append(id)
	unseen = shuffle(unseen, random)
	repeated = shuffle(repeated, random)
	var selected: Array = []
	var pool: Array = unseen + repeated
	while not pool.is_empty() and selected.size() < 2:
		# Never repeat a seen part while an unseen candidate remains.
		var candidates: Array = pool.filter(func(id): return not seen.has(id))
		if candidates.is_empty(): candidates = pool.duplicate()
		if revision == 0 and int(node.get("region", 0)) == 0 and not node.get("elite", false):
			var modules := candidates.filter(func(id): return not Ammo.is_core_part(id))
			if not modules.is_empty(): candidates = modules
		if not selected.is_empty():
			var different := candidates.filter(func(id): return BuildGuide.family(id) != BuildGuide.family(str(selected[0])))
			if not different.is_empty(): candidates = different
		else:
			var compatible := Discovery.modules(candidates, equipped) if discovery_version >= 1 else preload("res://redesign/build_affinity.gd").candidates(candidates,equipped,true)
			if not compatible.is_empty(): candidates = compatible
		var picked: String = pick_part(candidates, node, random)
		selected.append(picked)
		pool.erase(picked)
	var result: Array = [{"id": ammo_id, "type": "ammo", "price": 24 if Ammo.grade(ammo_id) == 1 else 12, "sold": false}]
	for id in selected: result.append({"id": id, "type": "part", "price": 30, "sold": false, "new": not seen.has(id)})
	return result
