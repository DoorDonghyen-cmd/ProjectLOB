extends "res://tests/ammo_cycle_ui_runner.gd"

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/support_combo/"): quit(1); return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.05
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1008,630), Vector2i(1280,900), Vector2i(1440,630)]:
		root.size = resolution
		await setup_hand(["charge","charge_hot","cool","precise","shatter"])
		cards_fit()
		check(Ammo.primary_stat("charge",screen.model.s).value == "+3" and Ammo.primary_stat("charge_hot",screen.model.s).value == "×2", "cards compare effects instead of zero damage")
		await capture("support_cards_%d" % resolution.x)
		var initial_height: float = screen.find_child("QueuePanel",true,false).size.y
		for id in ["precise","cool","charge_hot","charge"]: await tap("load_" + id)
		cards_fit()
		check(is_equal_approx(initial_height,screen.find_child("QueuePanel",true,false).size.y), "stacking never increases layout height")
		await capture("compound_plan_%d" % resolution.x)
		await tap("confirm")
		await tap("fire")
		var results: Array = screen.model.s.history.back().detail.results
		check(results.size() == 4 and results[3].damage == 24, "actual touch executes compound damage")
		check(results[0].damage == 0 and results[1].damage == 0 and results[2].damage == 0, "support effects do not shoot for damage")
		await capture("compound_fired_%d" % resolution.x)
		if screen.model.s.phase == "ready": await tap("reload")
		check(screen.model.s.buff.is_empty(), "reload clears ordinary setup")
		await setup_hand(["charge_heat","charge_hot","charge","cool","basic"])
		cards_fit()
		check(Ammo.primary_stat("charge_heat",screen.model.s).label == "고열 공격", "conditional main stat names the condition")
		await capture("boost_choices_%d" % resolution.x)
		for id in ["basic","cool","charge_heat"]: await tap("load_" + id)
		await capture("heat_setup_plan_%d" % resolution.x)
		check(screen.model.s.heat == 0, "conditional preview leaves temperature intact")
		await tap("confirm")
		await tap("fire")
		check(screen.model.s.history.back().detail.results.back().boost_hot_failed, "touch path exposes cold setup failure")
		await setup_hand(["charge_heat","charge_hot","charge","cool","basic"])
		screen.model.s.heat = 5
		screen.redraw()
		await settle()
		for id in ["cool","basic","charge_heat"]: await tap("load_" + id)
		await capture("hot_setup_plan_%d" % resolution.x)
		await tap("confirm")
		await tap("fire")
		check(screen.model.s.history.back().detail.results[1].damage == 9, "touch path rewards retained heat")
		await setup_hand(["charge","charge","basic","cool","pierce"])
		for id in ["basic","charge","charge_2"]: await tap("load_" + id)
		var replaced: Dictionary = preload("res://redesign/forecast.gd").analyze(screen.model.s)
		check(replaced.shots[1].boost_replaced, "duplicate setup is visibly reported as replacement")
		await capture("replacement_plan_%d" % resolution.x)
		await setup_hand(["shatter","prepare","disrupt","spread","cool"])
		cards_fit()
		await capture("utility_cards_%d" % resolution.x)
		# All-support hands can be cycled; no hidden damage is needed to advance.
		await tap("reload")
		check(screen.model.s.turns == 1 and screen.model.s.hand.has("pierce"), "support-only draw has paid escape")
	print("SUPPORT COMBO UI COMPLETE checks=%d failures=%d" % [checks,failures])
	screen.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
