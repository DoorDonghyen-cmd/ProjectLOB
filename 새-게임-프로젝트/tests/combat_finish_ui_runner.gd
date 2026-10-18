extends "res://tests/combat_hierarchy_ui_runner.gd"

var observing := false
var capturing := false
var captured := {}
var seen := {}
var observed_layout := {}
var layout_errors := 0

func observe() -> void:
	if not observing or capturing or not is_instance_valid(screen.battle_view): return
	var view = screen.battle_view
	for name in observed_layout:
		var rect: Rect2 = screen.find_child(name,true,false).get_global_rect()
		var original: Rect2 = observed_layout[name]
		if absf(rect.position.y-original.position.y) > 1 or absf(rect.size.y-original.size.y) > 1: layout_errors += 1
	var key := ""
	if view.flash > 0.25: key = "muzzle"
	if view.impact_power > 0: key = "powered_hit"
	if view.overheat_lock > 0: key = "overheat"
	if view.thermal_release > 0:
		key = "cooling"
		if not screen.find_child("OverheatWarning",true,false).visible: seen["cooling_ui"] = true
	if view.float_target >= 0 and view.float_target < view.enemies.size() and int(view.enemies[view.float_target].hp) <= 0:
		seen["defeat"] = true
	seen[key] = true
	if key.is_empty(): return
	var file := "%s_%d" % [key, root.size.x]
	if captured.has(file): return
	capturing = true
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join(file + ".png")) == OK, "actual feedback capture " + file)
	captured[file] = true
	capturing = false

func prepare_demo() -> void:
	screen._debug_combat_finish()
	await settle()
	for id in screen.model.s.deck: check(Ammo.AMMO.has(id), "valid demo ammo")
	fit()
	await capture("rest_%d" % root.size.x)
	var baseline := layout_snapshot()
	await tap("load_basic")
	await tap("load_precise")
	await tap("load_charge_hot")
	stable_layout(baseline, "art remains in fixed footprint")
	await capture("loaded_%d" % root.size.x)
	await tap("confirm")
	await capture("ready_%d" % root.size.x)
	check(screen.full_forecast.heat.forced_probability == 1.0, "demo naturally overheats")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/combat_finish/ui"):
		quit(1)
		return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 1.0
	root.add_child(screen)
	await settle()
	screen.preferences.data.motion = "normal"
	screen.presentation_speed = 1.0
	process_frame.connect(observe)
	for resolution in [Vector2i(1008,630), Vector2i(1280,900), Vector2i(1440,630)]:
		root.size = resolution
		await prepare_demo()
		var oracle = load("res://redesign/model.gd").new()
		oracle.s = screen.model.s.duplicate(true)
		check(oracle.fire(), "oracle action")
		seen.clear()
		observed_layout = layout_snapshot()
		layout_errors = 0
		observing = true
		await tap("fire")
		observing = false
		check(screen.model.s == oracle.s, "presentation preserves model and RNG")
		check(screen.last_presentation.shown_enemies == screen.model.s.enemies, "actors finish at model positions")
		for key in ["muzzle", "powered_hit", "overheat", "cooling", "cooling_ui", "defeat"]:
			check(seen.has(key), "actual demo feedback " + key)
		check(layout_errors == 0, "animation retains layout on every observed frame")
		check(not screen.busy and screen.battle_view.overheat_lock == 0 and screen.battle_view.thermal_release == 0, "effects return to rest")
		check(screen.find_child("HeatGauge", true, false).current == screen.model.s.heat, "heat finishes at actual value")
		fit()
		await capture("settled_%d" % resolution.x)
	# Motion-off must retain the same simulation and readable static heat states.
	screen.preferences.data.motion = "instant"
	screen.presentation_speed = 0.02
	await prepare_demo()
	check(screen.battle_view.reduced_feedback and screen.find_child("HeatGauge",true,false).reduced_motion, "motion preference reaches both layers")
	var oracle = load("res://redesign/model.gd").new()
	oracle.s = screen.model.s.duplicate(true)
	oracle.fire()
	await tap("fire")
	check(screen.model.s == oracle.s, "instant mode preserves same combat")
	var gauge = screen.find_child("HeatGauge",true,false)
	gauge.show_value(4)
	check(gauge.response == 0 and not gauge.is_processing(), "instant gauge has no lingering animation")
	# Artwork must remain readable on six-card pages and all weapon capacities.
	for resolution in [Vector2i(1008,630),Vector2i(1440,630)]:
		root.size = resolution
		for gun in Ammo.GUNS:
			await setup_hand(["basic","charge","pierce","cool","vent","sequence","precise","arc","prepare","thermal"],true)
			screen.model.s.gun = gun
			screen.campaign.s.gun = gun
			await refresh()
			cards_fit()
			check(screen.find_child("confirm",true,false).get_theme_stylebox("normal") is StyleBoxTexture,"primary uses shared pixel skin")
			var reload_button := screen.find_child("reload",true,false) as Button
			check(reload_button.get_theme_stylebox("normal") is StyleBoxTexture,"reload uses same pixel construction")
			check(absf(reload_button.size.x-screen.find_child("confirm",true,false).size.x) <= 1,"fire and reload share action column width")
			for card in screen.find_children("CardInfo","Control",true,false):
				check(card.combat_skin,"live ammunition uses battle skin")
			await tap("hand_next")
			cards_fit()
		await capture("full_bag_%d" % resolution.x)
	check(not screen.save_enabled and screen.debug_session, "practice uses isolated save")
	screen.queue_free()
	await process_frame
	print("COMBAT FINISH UI COMPLETE checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
