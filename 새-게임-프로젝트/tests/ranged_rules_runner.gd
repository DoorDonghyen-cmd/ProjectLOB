extends SceneTree
const Model = preload("res://redesign/model.gd")
const Forecast = preload("res://redesign/forecast.gd")
const Content = preload("res://redesign/content.gd")
const Ranged = preload("res://redesign/ranged.gd")
const Data = preload("res://redesign/samples/ranged_sample_data.gd")
const Insight = preload("res://redesign/run_insight.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)

func fixture(gun: String = "single") -> RefCounted:
	var model = Model.new()
	Data.seed_model(model, 1, gun)
	return model

func load_fire(model: RefCounted, ids: Array) -> void:
	for id in ids: check(model.load_round(str(id)), "owned load " + str(id))
	check(model.confirm(), "confirm real command")
	check(model.fire(), "fire real command")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/ranged/"):
		quit(1)
		return
	var model = Model.new()
	Data.seed_model(model, 0)
	model.s.reinforcements = []
	var events: Array = model._advance(1, true)
	check(model.s.enemies[1].ranged_left == 1 and Ranged.active(model.s).is_empty(), "first tick telegraphs without firing")
	events = model._advance(1, true)
	check(Ranged.active(model.s).size() == 1 and model.s.projectiles[0].distance == 24, "second tick launches at source distance")
	check(events.filter(func(e): return e.kind == "projectile_move").is_empty(), "no birth-tick movement")
	model._advance(1, true)
	check(model.s.projectiles[0].distance == 18 and model.s.enemies[1].distance == 24, "projectile advances six, shooter stationary")
	check(model.s.enemies[1].ranged_phase == "waiting", "one active shot blocks charging")
	# Editing and preview cannot advance the projectile or consume RNG.
	var untouched := JSON.stringify(model.s)
	Forecast.analyze(model.s, true, true)
	check(JSON.stringify(model.s) == untouched, "empty prediction is pure")
	check(model.load_round("charge") and model.undo(), "free edit remains legal")
	check(model.s.projectiles[0].distance == 18, "editing does not advance pressure")

	model = fixture()
	model.s.enemies[0].hp = 0
	model.s.projectiles = []
	model.s.enemies[1].hp = 3
	model.s.enemies[1].ranged_phase = "prepare"
	model.s.enemies[1].ranged_left = 1
	load_fire(model, ["basic"])
	check(model.s.phase == "reward" and Ranged.active(model.s).is_empty(), "kill telegraph cancels launch")
	model = fixture()
	model.s.enemies[0].hp = 0
	model.s.enemies[1].hp = 1
	model.s.enemies[1].burn = 1
	model._advance(1, true)
	check(model.s.enemies[1].hp == 0 and model.s.phase == "plan" and model.s.projectiles[0].distance == 6, "burned shooter leaves its airborne shot")
	load_fire(model, ["basic"])
	check(model.s.phase == "reward", "intercept last remaining hazard completes encounter")
	check(Insight.combat_report(model.s).kills == 0, "hazard is not an enemy kill")

	for gun in Content.GUNS:
		model = fixture(str(gun))
		var before_count: int = model.alive_count()
		load_fire(model, ["charge_hot", "pierce", "precise"])
		var shots: Array = model.s.history.back().detail.results
		check(shots[0].get("intercept", false) and shots[0].hits == 1, "first hot bullet intercepts " + str(gun))
		check(shots[1].math.boost == 4 * Content.multiplier(model.s), "interception grants normal boost " + str(gun))
		check(model.s.reload_heat == 1 and model.alive_count() <= before_count, "real cost and formation accounting " + str(gun))
		check(model.s.enemies[1].ranged_phase == "prepare" and model.s.enemies[1].ranged_left == 2, "one recovery tick after intercept " + str(gun))
		if gun == "amplifier": check(shots.size() == 2 and model.s.magazine.size() == 1, "amplifier chains through interception then stops on survivor")
		if gun == "burst": check(int(model.s.enemies[0].get("focus_hits", 0)) == 0, "projectile hit is not transferred to focus target")
	model = fixture()
	load_fire(model, ["precise"])
	check(model.s.history.back().detail.results[0].hits == 1 and model.s.enemies[0].hp == 20, "extra hits do not spill through the 1HP projectile")

	model = fixture()
	load_fire(model, ["arc"])
	var shot: Dictionary = model.s.history.back().detail.results[0]
	check(shot.intercept and shot.secondary.size() == 1 and shot.secondary[0].target == 0 and model.s.enemies[0].hp == 18, "arc intercept still chains to nearest enemy")
	model = fixture()
	model.s.enemies[0].distance = 6
	load_fire(model, ["arc"])
	shot = model.s.history.back().detail.results[0]
	check(shot.target == 0 and shot.secondary[0].get("intercept", false), "arc can intercept behind a closer enemy")
	check(model.s.enemies[1].hp == 18, "arc does not magically hit rear shooter")
	model = fixture()
	model.s.enemies[0].distance = 12
	check(Ranged.is_projectile(model.target_index()), "equal distance prioritizes projectile")
	model.s.reinforcements = [Data.enemy("runner", 6, 0, 2, 24, -1)]
	model.s.encounter_total = 3
	var hazard_id: int = model.target_index()
	model._deploy_reinforcements()
	check(model.alive_count() == 3 and model.target_entity(hazard_id).uid == 1, "stable hazard ID survives enemy deployment without occupying a slot")

	for hot in [false, true]:
		model = fixture()
		model.s.projectiles[0].distance = 18
		model.s.enemies[0].distance = 8
		model.s.enemies[0].hp = 90
		model.s.enemies[0].max_hp = 90
		check(model.load_round("charge_hot" if hot else "charge"), "risk fixture load")
		untouched = JSON.stringify(model.s)
		var prediction := Forecast.analyze(model.s, true, true)
		check(JSON.stringify(model.s) == untouched, "shot/reload forecast does not mutate state")
		check(model.confirm() and model.fire(), "risk fixture fire")
		check(model.s.projectiles == prediction.projectiles, "shot projectile forecast equals command")
		check(model.reload_magazine(), "risk fixture reload")
		check(model.s.projectiles == prediction.reload.projectiles and model.s.phase == prediction.reload.phase, "projectile reload forecast equals command")
		check((model.s.phase == "lost") == hot, "extra cooling causes only the warned impact")
		if hot: check(model.s.loss_reason == "projectile", "loss distinguishes pressure impact")
	model = fixture()
	model.s.phase = "ready"
	model.s.projectiles[0].distance = 6
	model.s.reload_heat = 2
	var turns: int = model.s.turns
	check(model.reload_magazine() and int(model.s.turns) - turns == 1, "lethal partial reload stops at the actual first tick")
	check(model.s.history.back().detail.advance_events.filter(func(e): return int(e.turn) > 0).is_empty(), "no invented events after death")

	_check_random()
	_check_constraints()
	_check_restore()
	print("RANGED RULES COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check_random() -> void:
	var model = fixture("scatter")
	for id in ["charge_hot", "pierce", "precise", "arc"]: model.load_round(id)
	var before := JSON.stringify(model.s)
	var prediction := Forecast.analyze(model.s, true, true)
	check(JSON.stringify(model.s) == before, "random preview leaves target RNG untouched")
	check(prediction.shots[0].intercept_probability > 0.99999 and prediction.shots[0].targets.size() == 1, "scatter forecasts guaranteed nearest interception")
	check(prediction.shots[1].targets.size() == 2, "scatter returns to random enemy targets")
	for seed_value in range(48):
		var copy = Model.new()
		copy.s = model.s.duplicate(true)
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		copy.s.target_rng_state = str(rng.state)
		check(copy.confirm() and copy.fire(), "scatter real seed " + str(seed_value))
		check(copy.s.history.back().detail.results[0].get("intercept", false), "scatter cannot miss mandatory interception")
		for i in range(copy.s.enemies.size()):
			check(copy.s.enemies[i].hp >= prediction.enemies[i].hp_min and copy.s.enemies[i].hp <= prediction.enemies[i].hp_max, "enemy result inside probability range")
		if copy.s.phase == "ready":
			check(copy.reload_magazine(), "random reload legal")
			for projectile in Ranged.active(copy.s):
				var rows: Array = prediction.reload.projectiles.filter(func(p): return int(p.uid) == int(projectile.uid))
				check(rows.size() == 1 and int(projectile.distance) >= int(rows[0].distance_min) and int(projectile.distance) <= int(rows[0].distance_max), "new projectile inside reload probability range")
	model.s.enemies[0].distance = 6
	var changed := Forecast.analyze(model.s, true, true)
	check(changed.shots[0].intercept_probability == 0, "closer enemy restores ordinary scatter selection")
	model.s.projectiles[0].distance = 3
	changed = Forecast.analyze(model.s, true, true)
	check(changed.shots[0].intercept_probability > 0.99999, "projectile distance participates in preview cache")

func _check_constraints() -> void:
	var model = fixture()
	model.s.deck.append_array(["arc_c", "charge_c"])
	model.s.hand.append_array(["arc_c", "charge_c"])
	model.s.equipped_parts = ["opening", "afterburner"]
	model.s.part = "none"
	for id in ["charge_c", "basic", "arc_c"]: check(model.load_round(id), "load constrained round " + id)
	check(model.s.plan == ["arc_c", "basic", "charge_c"], "first and last anchors retain order around interception")
	var prediction := Forecast.analyze(model.s, true, true)
	check(model.confirm() and model.fire(), "fire compressed interception with order parts")
	var shots: Array = model.s.history.back().detail.results
	check(shots[0].intercept and shots[0].math.part_bonus == 2 and shots[0].secondary.size() == 2, "opening compressed arc intercepts and chains twice")
	check(shots.back().math.part_bonus == 3 and model.s.buff.get("dmg", 0) == 4 and model.s.buff.get("persistent", false), "tail part and delayed compressed boost retain their roles")
	check(model.reload_cost() == 2 and model.s.reload_heat == 0, "tail part lengthens reload without inventing compression heat")
	check(model.s.enemies == prediction.enemies and model.s.projectiles == prediction.projectiles, "compressed and part forecast matches actual interception")
	check(model.reload_magazine() and model.s.projectiles == prediction.reload.projectiles, "part reload can launch the next real projectile")
	model = fixture()
	model.s.equipped_parts = ["afterburner"]
	model.s.part = "none"
	model.s.enemies[0].distance = 8
	model.s.enemies[0].hp = 90
	model.s.enemies[0].max_hp = 90
	model.s.projectiles[0].distance = 24
	check(model.load_round("charge_hot"), "load hot round with tail part")
	prediction = Forecast.analyze(model.s, true, true)
	check(model.confirm() and model.fire() and model.reload_cost() == 3, "part and heat costs add to three ticks")
	check(model.reload_magazine() and model.s.loss_reason == "projectile" and model.s.projectiles == prediction.reload.projectiles, "three-tick part/heat reload reaches predicted pressure impact")
	model = fixture()
	model.s.enemies[0].hp = 0
	model.s.projectiles = []
	model.s.enemies[1].ranged_phase = "prepare"
	model.s.enemies[1].ranged_left = 1
	model.s.hand.append("push")
	model.s.draw.erase("push")
	load_fire(model, ["push"])
	check(model.s.enemies[1].distance > 24 and model.s.projectiles[0].distance == model.s.enemies[1].distance, "pushed shooter launches from its actual distance without cancellation")
	model = fixture()
	var old_id: int = model.target_index()
	load_fire(model, ["basic"])
	check(model.reload_magazine(), "reload advances the recovered shooter's preparation")
	load_fire(model, ["basic"])
	check(model.s.projectiles[0].uid == 2 and model.target_entity(old_id).is_empty(), "next launch cannot alias the intercepted target ID")

func _check_restore() -> void:
	var model = fixture()
	var restored = Model.new()
	var serialized: Dictionary = JSON.parse_string(JSON.stringify(model.s))
	check(restored.restore_state(serialized), "JSON roundtrip with live projectile")
	check(restored.s.projectiles.size() == 1 and int(restored.s.projectiles[0].uid) == 1 and int(restored.s.projectiles[0].source) == 1 and int(restored.s.projectiles[0].distance) == 12, "restore preserves source, stable ID and distance across JSON number types")
	var snapshot := JSON.stringify(restored.s)
	for entry in [["uid", true], ["uid", 2], ["source", 99], ["hp", 2], ["speed", 0], ["distance", -1], ["distance", 1.5], ["burn", 2]]:
		var invalid: Dictionary = serialized.duplicate(true)
		invalid.projectiles[0][entry[0]] = entry[1]
		check(not restored.restore_state(invalid) and JSON.stringify(restored.s) == snapshot, "reject malformed hazard atomically " + str(entry))
	var invalid: Dictionary = serialized.duplicate(true)
	invalid.projectiles.append(invalid.projectiles[0].duplicate())
	check(not restored.restore_state(invalid), "one active projectile cap validated")
	invalid = serialized.duplicate(true)
	invalid.enemies[1].ranged_left = 2
	check(not restored.restore_state(invalid), "reject mismatched waiting clock")
	var old = Model.new()
	old.start("single", 77)
	old.s.erase("projectiles")
	old.s.erase("projectile_serial")
	old.s.erase("loss_reason")
	check(restored.restore_state(old.s) and restored.s.projectiles.is_empty(), "old v8 save defaults to empty hazards")
	model = fixture()
	load_fire(model, ["charge"])
	check(model.save_run("user://ranged_roundtrip.json") == OK and restored.restore_run("user://ranged_roundtrip.json"), "actual isolated save/restore after interception")
