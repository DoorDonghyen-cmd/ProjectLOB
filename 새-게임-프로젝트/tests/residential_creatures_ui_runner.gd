extends "res://tests/eavesback_ui_runner.gd"

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/eavesback/family"):
		quit(1)
		return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.03
	root.add_child(screen)
	await settle()
	await tap("dev")
	await tap("debug_residential_creatures")
	check(screen.debug_session and screen.campaign.get_meta("creature_family_preview", false), "family public entry")
	for resolution in [Vector2i(1280, 900), Vector2i(1008, 630), Vector2i(1440, 630)]:
		root.size = resolution
		screen._debug_eavesback(true)
		await settle()
		fit()
		check(screen.battle_view.get_script().resource_path.ends_with("residential_creatures_view.gd"), "family scene active")
		for i in range(3):
			var rect: Rect2 = screen.battle_view.concept_rect(i)
			check(Rect2(Vector2.ZERO, screen.battle_view.size).encloses(rect), "concept inside battlefield")
			check(rect.position.y >= screen.battle_view.enemy_plaque(i).end.y, "concept clears plaque")
			check(is_equal_approx(rect.end.y, screen.battle_view.enemy_feet(i).y), "concept grounded")
			check(screen.battle_view._enemy_at(rect.get_center()) == i, "concept selectable")
			if i < 2: check(not rect.intersects(screen.battle_view.concept_rect(i + 1)), "distinct silhouettes do not overlap")
		check(screen.model.s.enemies[2].weakness == "electric", "rainpouch keeps electric weakness")
		await capture("family_%d" % resolution.x)
		await tap("load_pierce")
		await tap("confirm")
		await tap("fire")
		check(int(screen.model.s.enemies[0].hp) < 12, "runner hit")
		check(int(screen.model.s.enemies[0].distance) == 12, "runner advances by existing speed")
		check(screen.battle_view.enemies == screen.model.s.enemies, "hit and movement match model")
		await capture("hit_%d" % resolution.x)
		await tap("reload")
		check(screen.battle_view.projectiles == screen.model.s.projectiles, "existing toad projectile preserved")
		await capture("reload_%d" % resolution.x)
		# Controlled A/B: only electric weakness differs, same gun/ammo/target state.
		screen._debug_eavesback(true)
		screen.model.s.enemies = [Data._enemy(["evader", 40, 0, 0, 24])]
		screen.model.s.enemies[0].name = "빗주머니 · 시안"
		screen.model.s.encounter_total = 1
		screen.model.s.deployed = 1
		screen.model.assign_opening_lanes()
		var control = preload("res://redesign/model.gd").new()
		control.s = screen.model.s.duplicate(true)
		control.s.enemies[0].erase("weakness")
		check(control.load_round("arc") and control.confirm() and control.fire(), "control electric shot")
		screen.redraw()
		await settle()
		await tap("load_arc")
		await tap("confirm")
		await capture("electric_preview_%d" % resolution.x)
		await tap("fire")
		check(int(control.s.enemies[0].hp) - int(screen.model.s.enemies[0].hp) == 2, "visible organism keeps existing electric bonus")
		check(screen.battle_view.enemies == screen.model.s.enemies, "electric result matches model")
		await capture("electric_hit_%d" % resolution.x)
	# Original approved single-creature preview and normal production remain separate.
	screen._debug_eavesback()
	await settle()
	check(screen.battle_view.get_script().resource_path.ends_with("/eavesback_view.gd"), "original concept preview preserved")
	check(not screen.campaign.s.has("creature_family_preview"), "family flag is not save state")
	screen._debug_city("map")
	screen.campaign.enter(int(screen.campaign.choices()[0].id))
	screen.model = screen.campaign.model
	screen.redraw()
	await settle()
	check(screen.battle_view.get_script().resource_path.ends_with("/residential_battle_view.gd"), "new residential run uses production art after preview")
	await capture("normal_after_family")
	screen.queue_free()
	await process_frame
	print("CREATURE FAMILY UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
