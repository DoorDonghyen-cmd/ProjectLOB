extends "res://tests/ammo_cycle_ui_runner.gd"

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/early_ammo/"): quit(1); return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.02
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1008,630), Vector2i(1280,900), Vector2i(1440,630)]:
		root.size = resolution
		await setup_hand(["charge","precise","pierce","basic","charge_hot"])
		cards_fit()
		await tap("load_basic")
		await tap("load_precise")
		await tap("load_charge")
		await capture("combo_%d" % resolution.x)
		await tap("confirm")
		await tap("fire")
		var results: Array = screen.model.s.history.back().detail.results
		check(results[0].boost_rounds == 1, "UI executes one-round boost")
		check(results[1].math.boost == 3 and results[2].math.boost == 0, "UI selected recipient only")
		await capture("fired_%d" % resolution.x)
		await setup_hand(["charge_c","precise","pierce","basic","charge_hot"])
		cards_fit()
		await capture("advanced_%d" % resolution.x)
	print("EARLY AMMO UI COMPLETE checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
