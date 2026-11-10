extends "res://tests/combat_approach_probe.gd"
const Approach = preload("res://redesign/combat_approach_trial.gd")
const Solver = preload("res://tests/combat_approach_solver.gd")
var checks := 0
var failures: Array = []
var audit: Array = []
var decisions: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)

func candidate(role: String, order_seed: int, pressure_on := true):
	var model = Model.new()
	check(model.restore_state(source(role)), "Earned source restores " + role)
	model.s.magazine_trial_version = 1
	model.s.history = []
	var original: Dictionary = model.s.duplicate(true)
	if pressure_on:
		check(Approach.apply_opening(model.s, role), "Opening profile applies once")
		var applied := JSON.stringify(model.s)
		check(not Approach.apply_opening(model.s, role) and JSON.stringify(model.s) == applied, "Repeated application is rejected without mutation")
		for zone in ["enemies", "reinforcements"]:
			check(model.s[zone].size() == original[zone].size(), "No extra enemies")
			for i in range(model.s[zone].size()):
				var e: Dictionary = model.s[zone][i].duplicate(true); var before: Dictionary = original[zone][i].duplicate(true)
				e.erase("speed"); e.erase("distance"); before.erase("speed"); before.erase("distance")
				check(e == before, "HP, armor, attacks, and enemy identity unchanged")
	if order_seed > 0:
		var rng := RandomNumberGenerator.new(); rng.seed = order_seed; model.s.rng_state = str(rng.state)
		model.s.draw = model.s.hand + model.s.draw; model.s.hand = []; model._shuffle(model.s.draw)
	check(model.trial_load_magazine(), "Whole owned magazine loads")
	check(model.capacity() == 6, "Selected fixture has six usable slots")
	return model

func roundtrip(model) -> void:
	var restored = Model.new()
	check(restored.restore_state(JSON.parse_string(model.serialized_state())), "Approach state restores")
	check(JSON.parse_string(JSON.stringify(model.s)) == JSON.parse_string(JSON.stringify(restored.s)), "Restore does not reapply distance or speed")
	var owned: Array = model.s.hand + model.s.draw + model.s.discard + model.s.magazine
	var expected: Array = model.s.deck.duplicate()
	for i in range(Model.Reserve.generated_count(model.s)): expected.append(Model.Reserve.EMERGENCY_ROUND)
	owned.sort(); expected.sort(); check(owned == expected, "Ammo conserved under pressure")

func tracked(model, role: String, order_seed: int, pressure_on: bool) -> Dictionary:
	var start: int = model.s.turns
	var min_margin := margin(model)
	var path: Array = []
	var close := 0
	for step in range(40):
		if model.s.phase not in ["plan", "ready"]: break
		var m := margin(model); min_margin = mini(m, min_margin)
		if m <= 2: close += 1
		var before := JSON.stringify(model.s)
		var outcomes: Dictionary = {}
		for action in Solver.actions(model):
			var copy = Model.new(); copy.s = Model.simulation_state(model.s)
			check(Solver.command(copy, action), "Alternative uses a legal command")
			outcomes[action] = {"phase":copy.s.phase, "reason":copy.s.get("loss_reason", ""), "turns":int(copy.s.turns)-int(model.s.turns)}
		check(JSON.stringify(model.s) == before, "Alternative previews preserve live state/RNG")
		var selected := policy(model, true)
		var prediction: Dictionary = Forecast.analyze(model.s, true) if selected == "fire" else {}
		if outcomes.values().any(func(v): return v.phase == "lost") and outcomes.values().any(func(v): return v.phase != "lost"):
			decisions.append({"role":role, "seed":order_seed, "pressure":pressure_on, "step":step, "margin":m, "path":path.duplicate(), "alternatives":outcomes})
		check(Solver.command(model, selected), "Heat-aware policy advances")
		path.append(selected)
		check(model.s.phase == outcomes[selected].phase, "Advertised consequence matches actual action")
		if not prediction.is_empty():
			check(model.s.enemies == prediction.enemies and model.s.projectiles == prediction.projectiles and model.s.phase == prediction.phase and model.s.magazine == prediction.remaining, "Shot forecast includes faster approach and forced cooling")
		roundtrip(model)
	return {"role":role, "order_seed":order_seed, "pressure":pressure_on, "phase":model.s.phase, "turns":int(model.s.turns)-start, "used":model.s.discard.size(), "min_contact_actions":min_margin, "close_decisions":close, "path":path, "loss_reason":model.s.get("loss_reason", "")}

func run() -> void:
	var out := OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/combat_approach_20261031/"): quit(2); return
	# All five roles, original order plus a six-order controlled matrix.
	for role in Approach.ROLES:
		for order_seed in [0, 17, 1042, 731042, 900001, 1200411]:
			for pressure_on in [false, true]:
				var model = candidate(role, order_seed, pressure_on)
				var row := tracked(model, role, order_seed, pressure_on)
				check(row.phase in ["reward", "won"], "Core comparison has a winning cooling policy")
				rows.append(row)
	# Wider order variations test brittle opening combinations, beyond the chosen example.
	for role in ["breach", "boss"]:
		for order_seed in range(1, 41):
			var model = candidate(role, order_seed, true)
			var initial: Dictionary = model.s.duplicate(true)
			var row := simulate(model, true)
			row.merge({"role":role, "order_seed":order_seed})
			if row.phase not in ["reward", "won"]:
				var rescue := Solver.solve(initial)
				row.rescue_path = rescue
				if not rescue.is_empty():
					var replay = Model.new(); replay.s = initial
					for action in rescue: check(Solver.command(replay, action), "Rescue replays legally")
					check(replay.s.phase in ["reward", "won"], "Rescue actually wins")
				else: row.unresolved = true
			audit.append(row)
	var bad: Dictionary = candidate("breach", 0).s.duplicate(true)
	for version in [-1, 2, 0.5, "1", true]:
		bad.approach_trial_version = version
		check(not Model.new().restore_state(bad), "Reject invalid approach version")
	bad.approach_trial_version = 1; bad.approach_trial_role = "boss"
	check(not Model.new().restore_state(bad), "Reject profile/encounter mismatch")
	bad.approach_trial_role = "breach"; bad.magazine_trial_version = 0
	check(not Model.new().restore_state(bad), "Approach requires magazine trial")
	FileAccess.open(out.path_join("rules.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks":checks, "failures":failures, "rows":rows, "audit":audit, "decisions":decisions, "scope":"Existing earned fixtures with changed opening movement only; shuffled-order audit is not a player win rate or a new earned campaign."}, "  "))
	print("APPROACH RULES COMPLETE checks=%d failures=%d audit=%d" % [checks, failures.size(), audit.size()])
	quit(0 if failures.is_empty() else 1)
