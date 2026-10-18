extends "res://tests/place_revision_runner.gd"
const Solver = preload("res://tests/city_combat_solver.gd")

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/place_revision/"): quit(2); return
	var c
	for seed_value in range(1,50):
		c = at_room(seed_value, "event", "siphon")
		if c == null: continue
		if int(c.s.floor) == 3 and Campaign.Encounters.outcome("siphon", "open", seed_value, int(c.s.node)).type == "combat": break
	check(c != null, "reachable early encounter")
	check(c.resolve("encounter", "open") and c.resolve("fight"), "clue to ambush")
	var solver := Solver.new()
	solver.candidate_limit = 600
	var path := solver.solve(c.model, 12, 14)
	check(not path.is_empty(), "reachable victory with owned opening deck")
	var paid: int = c.s.credits
	for step in path:
		var accepted := false
		match str(step.action):
			"load": accepted = c.model.load_round(str(step.id))
			"confirm": accepted = c.model.confirm()
			"fire": accepted = c.model.fire()
			"reload": accepted = c.model.reload_magazine()
		check(accepted, "actual combat command " + str(step.action))
		c.sync_combat()
		c = roundtrip(c)
	check(c.s.phase == "reward" and c.s.credits == paid + 18, "actual victory pays scene loot")
	check(c.model.s.shots > 0, "shots actually fired")
	check(c.reward("credits") and c.s.phase == "map", "normal reward after extra loot")
	roundtrip(c)
	print("PLACE COMBAT COMPLETE checks=%d failures=%d commands=%d seed=%s" % [checks, failures, path.size(), c.s.seed])
	quit(0 if failures == 0 else 1)
