extends RefCounted
const Content = preload("res://redesign/content.gd")
const TITLES := ["긴급 제압", "보호막 전열"]
const HINTS := ["가까운 두 적을 이번 사격에 정리할 수 있을까?", "보호막에 소모되는 화력과 재장전 시간을 비교하세요"]

static func seed_model(model: RefCounted, index: int) -> void:
	model.start("single", 104040 + index)
	model.s.floor = 4
	model.s.deck = ["charge", "charge_hot", "precise", "precise", "pierce", "push", "bore", "arc"]
	model.s.hand = model.s.deck.slice(0, 5)
	model.s.draw = model.s.deck.slice(5)
	model.s.discard = []
	model.s.plan = []
	model.s.plan_load_order = []
	model.s.magazine = []
	model.s.reinforcements = []
	model.s.field_compression_left = 0
	if index == 0:
		model.s.enemies = [
			_enemy("runner", 16, 0, 2, 2, 0),
			_enemy("runner", 16, 0, 2, 2, 1),
			_enemy("wall", 18, 3, 1, 18, 2),
		]
	else:
		var shield := _enemy("absorber", 16, 0, 2, 6, 0)
		shield.barrier = 4
		shield.barrier_max = 4
		model.s.enemies = [shield, _enemy("wall", 12, 2, 1, 18, 1)]
	model.s.encounter_total = model.s.enemies.size()
	model.s.deployed = model.s.enemies.size()
	model.s.wave = 1
	model.s.message = HINTS[index]

static func initial_plan(hot: bool) -> Array:
	return ["charge_hot" if hot else "charge", "precise", "precise", "pierce"]

static func _enemy(kind: String, hp: int, armor: int, speed: int, distance: int, lane: int) -> Dictionary:
	return {"kind": kind, "name": Content.ENEMY_NAMES[kind], "hp": hp, "max_hp": hp, "def": armor, "speed": speed, "distance": distance, "burn": 0, "lane": lane}
