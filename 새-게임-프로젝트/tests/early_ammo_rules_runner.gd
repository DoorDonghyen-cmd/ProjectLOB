extends "res://tests/heat_rules_runner.gd"
const Card = preload("res://redesign/ammo_card_view.gd")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/early_ammo/"): quit(1); return
	for gun in Ammo.GUNS:
		var m = fixture(["charge", "precise", "basic"], [["wall", 100, 0, 1, 99]], gun)
		var results := fire(m, ["charge", "precise", "basic"])
		check(results[0].boost_rounds == 1, "normal grants one round " + gun)
		check(results[0].damage == 0, "unassisted amplifier is a preparation round " + gun)
		var readout: Dictionary = preload("res://redesign/damage_readout.gd").entry(results[0])
		check(readout.number == "증폭" and readout.label == "다음 1발 +%d" % Ammo.effect_value("charge",m.s), "resolved float states actual duration " + gun)
		if gun == "amplifier":
			check(m.s.buff.dmg_left == 1 and m.s.buff.dmg == 6, "single weapon doubles strength, not duration")
			check(m.fire(), "single amplified followup")
			results.append_array(m.s.history.back().detail.results)
			check(m.fire(), "single final basic")
			results.append_array(m.s.history.back().detail.results)
		check(results[1].math.boost == Ammo.effect_value("charge", m.s), "next round is amplified " + gun)
		check(results[1].hits == 2, "both hits within next round " + gun)
		check(results[2].math.boost == 0, "second round is not amplified " + gun)
		var card = Card.new()
		card.ammo_id = "charge"
		card.state = m.s
		check(card.effect_text() == "다음 1발 +%d" % Ammo.effect_value("charge",m.s), "card agrees with model " + gun)
		card.free()
	var no_followup = fixture(["charge"], [["wall",100,0,1,99]])
	var empty_result := fire(no_followup,["charge"])
	check(empty_result[0].damage == 0 and no_followup.s.heat == 3, "standalone preparation pays heat without free damage")
	check(no_followup.reload_magazine() and not no_followup.s.buff.has("dmg"), "normal unused preparation is lost on reload")
	for id in ["charge_hot", "charge_c", "charge_f"]:
		check(Ammo.boost_rounds(id) == 2, "advanced duration retained " + id)
	var m = fixture(["charge", "precise", "basic"], [["wall",100,0,1,99]])
	m.s.equipped_parts = ["sequencer"]
	var results := fire(m, ["charge", "precise", "basic"])
	check(results[1].math.boost == 4 and results[2].math.boost == 0, "sequencer improves value without extra targets")
	for id in ["charge_c", "charge_f"]:
		m = fixture([id,"basic","precise"], [["wall",100,0,1,99]])
		if id == "charge_f":
			m = fixture(["charge","charge","basic","precise"], [["wall",100,0,1,99]])
			check(m.field_compress("charge"), "create temporary round through real compression")
		fire(m, [] if id == "charge_f" else [id])
		check(m.s.buff.dmg_left == 2 and m.s.buff.persistent, "compressed boost persists " + id)
		check(m.reload_magazine(), "compressed reload")
		check(m.s.buff.dmg_left == 2, "compressed two rounds survive reload " + id)
		var restored = Model.new()
		check(restored.restore_state(JSON.parse_string(JSON.stringify(m.s))), "compressed carry save " + id)
	# Already resolved pre-change boosts must not lose a remaining charge on load.
	m = fixture(["basic","basic"], [["wall",100,0,1,99]])
	m.s.buff = {"dmg":2,"dmg_left":2}
	var restored = Model.new()
	check(restored.restore_state(JSON.parse_string(JSON.stringify(m.s))), "legacy active boost restores")
	results = fire(restored, ["basic","basic"])
	check(results[0].math.boost == 2 and results[1].math.boost == 2, "legacy resolved charges are preserved")
	# Choice should change a kill, not only a total against an infinite health target.
	m = fixture(["charge","precise","basic"], [["runner",10,0,1,30],["runner",20,0,1,34]])
	results = fire(m, ["charge","precise","basic"])
	check(results[1].hp == 0, "correct adjacent amplification crosses ten HP kill line")
	var wrong = fixture(["charge","precise","basic"], [["runner",10,0,1,30],["runner",20,0,1,34]])
	results = fire(wrong, ["charge","basic","precise"])
	check(results[1].hp > 0 and results[2].target == 0, "spending boost on basic delays kill and next target")
	for armor in [0,3]:
		m = fixture(["basic","pierce"], [["wall",100,armor,1,99]])
		results = fire(m,["basic","pierce"])
		check(results[1].damage == 3, "pierce keeps armor role")
		check(results[0].damage == (3 if armor == 0 else 1), "low heat basic competes without armor")
	print("EARLY AMMO RULES COMPLETE checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
