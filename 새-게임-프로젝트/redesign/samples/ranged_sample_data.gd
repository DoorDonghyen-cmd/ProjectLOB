extends RefCounted
const Content = preload("res://redesign/content.gd")
const Ranged = preload("res://redesign/ranged.gd")
const TITLES := ["공격 예고", "날아오는 압력탄"]

static func enemy(kind: String, hp: int, armor: int, speed: int, distance: int, lane: int) -> Dictionary:
	var result := {"kind": kind, "name": Content.ENEMY_NAMES[kind], "hp": hp, "max_hp": hp, "def": armor, "speed": speed, "distance": distance, "burn": 0, "lane": lane}
	if kind == "spitter":
		result.ranged_phase = "prepare"
		result.ranged_left = 2
	return result

static func projectile(uid: int, source: int, distance: int) -> Dictionary:
	return {"uid": uid, "source": source, "kind": "pressure", "name": "압력탄", "hp": 1, "max_hp": 1, "def": 0, "speed": Ranged.PROJECTILE_SPEED, "distance": distance, "burn": 0}

static func seed_model(model: RefCounted, index: int, gun: String = "single") -> void:
	model.start(gun, 104140 + index)
	model.s.floor = 4
	model.s.deck = ["charge", "charge_hot", "pierce", "precise", "arc", "push", "bore", "precise"]
	model.s.hand = model.s.deck.slice(0, 5)
	model.s.draw = model.s.deck.slice(5)
	model.s.discard = []
	model.s.plan = []
	model.s.plan_load_order = []
	model.s.magazine = []
	model.s.field_compression_left = 0
	model.s.enemies = [enemy("wall", 14 if index == 0 else 20, 2, 1, 12 if index == 0 else 18, 0), enemy("spitter", 24 if index == 0 else 18, 0, 0, 24, 1)]
	model.s.reinforcements = [enemy("runner", 8, 0, 2, 18, -1)] if index == 0 else []
	if index == 1:
		model.s.projectile_serial = 1
		model.s.projectiles = [projectile(1, 1, 12)]
		model.s.enemies[1].ranged_phase = "waiting"
		model.s.enemies[1].ranged_left = 0
	model.s.encounter_total = model.s.enemies.size() + model.s.reinforcements.size()
	model.s.deployed = model.s.enemies.size()
	model.s.wave = 1
	model.s.message = "가장 가까운 압력탄은 다음 발로 요격 · 증폭과 전이는 요격해도 발동"

static func initial_plan(hot: bool, index: int) -> Array:
	return ["charge_hot" if hot else "charge", "pierce", "precise"] if index == 0 else ["charge_hot" if hot else "charge", "pierce", "precise", "arc"]
