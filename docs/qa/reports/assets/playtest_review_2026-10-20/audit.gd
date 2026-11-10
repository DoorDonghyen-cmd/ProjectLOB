extends "res://tests/heat_rules_runner.gd"

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/playtest_review_20261020/"):
		quit(1)
		return
	var rows: Array = []
	for gun in Ammo.GUNS:
		for offset in [-1, 0]:
			var model = fixture(["thermal"], [["wall", 200, 0, 1, 60]], gun)
			model.s.heat = Ammo.hot_threshold(model.s) + offset
			var shots := fire(model, ["thermal"])
			check(shots.size() == 1, "single thermal card resolved")
			check(shots[0].thermal_bonus == (Ammo.effect_value("thermal", model.s) if offset == 0 else 0), "pre-shot heat boundary " + gun)
			rows.append({"gun":gun, "threshold":Ammo.hot_threshold(model.s), "heat_before":shots[0].heat_before, "bonus":shots[0].thermal_bonus, "damage":shots[0].damage})
	var model = fixture(["basic_p1", "basic_p2"])
	var original_hand: Array = model.s.hand.duplicate()
	var original_draw: Array = model.s.draw.duplicate()
	for iteration in range(20):
		check(model.load_round("basic_p1") and model.remove_planned(0), "repeat recall " + str(iteration))
	check(model.s.hand == original_hand and model.s.draw == original_draw and model.s.turns == 0 and model.s.heat == 0, "recall has no resource cost")
	model.s.hand = []
	model.s.draw = []
	model.s.discard = ["basic_p1", "thermal"]
	model._refill(2)
	check(model.s.hand.has("thermal") and model.s.hand.has("basic_p1") and model.s.discard.is_empty(), "spent rounds are immediately recyclable at empty draw")
	var thresholds: Array = []
	for scenario in [{"equipped_parts":["thermal_drive"],"deck":["basic_p1"]}, {"equipped_parts":[],"deck":["charge_heat"]}, {"equipped_parts":[],"deck":["thermal_c"]}, {"equipped_parts":[],"deck":["thermal"]}]:
		scenario.gun = "single"
		var gauge = preload("res://redesign/heat_gauge.gd").new()
		gauge.sync(scenario,{})
		check(gauge.threshold == Ammo.hot_threshold(scenario), "heat-dependent build exposes activation boundary")
		thresholds.append({"parts":scenario.equipped_parts,"deck":scenario.deck,"displayed_threshold":gauge.threshold})
		gauge.free()
	var neutral = preload("res://redesign/heat_gauge.gd").new()
	neutral.sync({"gun":"single", "deck":["basic_p1"]},{})
	check(neutral.threshold == 0, "plain basic build has no unrelated activation marker")
	neutral.free()
	var report := {"checks":checks,"failures":failures,"thermal_boundary":rows,"recall_repetitions":20,"same_battle_reshuffle":true,"heat_marker_observations":thresholds}
	FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("audit.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("PLAYTEST AUDIT COMPLETE checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
