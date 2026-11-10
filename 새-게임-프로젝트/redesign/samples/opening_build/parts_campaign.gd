extends "res://redesign/campaign.gd"

const STARTERS := ["sequencer", "rammer", "chain_sink"]
enum VariantMode { PARTS, SUPPORT, FOLLOW_UP }

var mode: int = VariantMode.PARTS
var opening_round := ""

func reward(choice: String, remove_id: String = "") -> bool:
	var package := mode != VariantMode.PARTS and first_ammo_reward() and reward_options().has(choice)
	if not super.reward(choice, remove_id): return false
	if package: opening_round = choice
	return true

func _load_opening_magazine() -> void:
	if mode != VariantMode.PARTS and _second_normal(1) and not opening_round.is_empty():
		var hand_size: int = model.s.hand.size()
		var pool: Array = model.s.hand + model.s.draw
		_include_round(pool, opening_round)
		_include_round(pool, str(Model.FocusBuild.package(opening_round)[2]))
		model.s.hand = pool.slice(0, hand_size)
		model.s.draw = pool.slice(hand_size)
	super._load_opening_magazine()

func _second_normal(clears: int) -> bool:
	return int(s.region) == 0 and int(s.floor) == 2 and int(s.clears) == clears and node().kind == "combat" and not node().get("elite", false)

func _include_round(pool: Array, id: String) -> void:
	var source := pool.find(id)
	if source < 0 or _loaded(pool).has(id): return
	var slots := Ammo.slot_cost(id)
	var candidates: Array[int] = []
	for i in range(source):
		var current := str(pool[i])
		if Ammo.source_id(current) != "basic" or Ammo.slot_cost(current) != slots: continue
		var test := pool.duplicate()
		test[i] = id
		test[source] = current
		if _loaded(test).has(id): candidates.append(i)
	if candidates.is_empty(): return
	# The owned round moves to a slot derived from the existing shuffled draw.
	var destination: int = candidates[source % candidates.size()]
	pool[source] = pool[destination]
	pool[destination] = id

func _loaded(pool: Array) -> Array:
	return Model.MagazineTrial.take(pool, model.capacity(), Ammo.slot_cost, Ammo.anchor).selected

func part_rewards() -> Array:
	if engine_reward():
		return STARTERS.filter(func(id): return not s.parts.has(id))
	var follow_up := _follow_up()
	if not follow_up.is_empty(): return [follow_up]
	return super.part_rewards()

func reward_options() -> Array:
	var options := super.reward_options()
	return options.slice(0, -1) if not _follow_up().is_empty() and not options.is_empty() else options

func _follow_up() -> String:
	if mode != VariantMode.FOLLOW_UP or s.phase != "reward" or not _second_normal(2): return ""
	var family := Ammo.source_id(opening_round)
	var aligned := {"bore":"coil", "arc":"capacitor", "pierce":"lens"}
	for id in [aligned.get(family, "radiator"), "radiator", "executioner"]:
		if not s.parts.has(id): return id
	return ""
