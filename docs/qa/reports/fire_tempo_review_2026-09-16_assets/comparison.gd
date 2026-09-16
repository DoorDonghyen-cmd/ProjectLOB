extends SceneTree
const Model = preload("res://redesign/model.gd")
var results: Array = []
var failures: Array = []

func _initialize() -> void:
	run.call_deferred()

func compare(label: String, gun: String, rounds: Array, hp: int, distance: int, bonus: int = 0, part: String = "none", reload_after: bool = false) -> Dictionary:
	var model = Model.new()
	model.start(gun, 731042)
	model.s.capacity_bonus = bonus
	model.s.part = part
	model.s.supply = model.capacity()
	model.s.deck = ["charge", "precise", "bore", "pierce", "push", "arc"]
	model.s.hand = ["charge", "precise", "bore", "pierce", "push"]
	model.s.draw = ["arc"]
	model.s.discard = []
	model.s.history = []
	model.s.enemies = [{"kind": "wall", "name": "Fixture", "hp": hp, "max_hp": hp, "def": 0, "speed": 2, "distance": distance, "burn": 0}]
	for id in rounds:
		if not model.load_round(id): failures.append(label + "/load/" + str(id))
	if not model.confirm(): failures.append(label + "/confirm")
	while model.fire():
		pass
	if reload_after and model.s.phase == "ready":
		if not model.reload_magazine(): failures.append(label + "/reload")
	var moves := 0
	var meters := 0
	for event in model.s.history:
		for advance in event.detail.get("advance_events", []):
			if advance.kind == "move":
				moves += 1
				meters += int(advance.from) - int(advance.to)
	var result := {"case": label, "gun": gun, "capacity": model.capacity(), "part": part, "rounds": rounds, "initial_hp": hp, "initial_distance": distance, "damage": hp - int(model.s.enemies[0].hp), "shots": model.s.shots, "turns": model.s.turns, "enemy_moves": moves, "enemy_meters": meters, "remaining_hp": model.s.enemies[0].hp, "phase": model.s.phase}
	results.append(result)
	return result

func run() -> void:
	for gun in ["single", "burst", "scatter", "heavy"]:
		compare("same_three_combo_survives", gun, ["charge", "precise", "basic"], 100, 24)
		compare("same_three_combo_clears", gun, ["charge", "precise", "basic"], 15, 24)
		compare("same_three_combo_contact", gun, ["charge", "precise", "basic"], 15, 4)
		compare("same_three_combo_with_reload", gun, ["charge", "precise", "basic"], 100, 100, 0, "none", true)
	for bonus in [0, 2]:
		var rounds: Array = []
		for i in range(4 + bonus): rounds.append("basic")
		for gun in ["single", "burst"]:
			compare("full_basic_fire", gun, rounds, 100, 100, bonus)
			compare("full_basic_cycle", gun, rounds, 100, 100, bonus, "none", true)
		compare("full_basic_cycle_loader", "burst", rounds, 100, 100, bonus, "loader", true)
	for gun in ["single", "burst"]:
		compare("burn_before_two_basic", gun, ["bore", "basic", "basic"], 100, 100)
	var file := FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("comparison.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures": failures, "results": results}, "\t"))
	file.close()
	for result in results: print(JSON.stringify(result))
	print("COMPARISON_COMPLETE cases=" + str(results.size()) + " failures=" + str(failures.size()))
	quit(0 if failures.is_empty() else 1)
