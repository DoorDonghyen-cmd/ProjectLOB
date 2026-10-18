extends "res://tests/ammo_expansion_ui_runner.gd"

func tap(key: String) -> void:
	var button := screen.find_child(key, true, false) as Button
	check(button != null and button.is_visible_in_tree() and not button.disabled, "usable " + key)
	if button == null or button.disabled: return
	var ancestor := button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(button)
			break
		ancestor = ancestor.get_parent()
	await settle()
	var point := root.get_final_transform() * (button.get_screen_transform() * (button.size * 0.5) - Vector2(DisplayServer.window_get_position()))
	for held in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = held
		Input.parse_input_event(event)
		await process_frame
	for i in range(2400):
		if not screen.busy: break
		await process_frame
	check(not screen.busy, "animation completes " + key)
	await settle()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/eavesback/"):
		quit(1)
		return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.03
	root.add_child(screen)
	await settle()
	await tap("dev")
	var entry := screen.find_child("debug_eavesback", true, false) as Control
	var parent := entry.get_parent() if entry != null else null
	while parent != null:
		if parent is ScrollContainer:
			parent.ensure_control_visible(entry)
			break
		parent = parent.get_parent()
	await settle()
	await tap("debug_eavesback")
	check(screen.debug_session and screen.campaign.get_meta("eavesback_preview", false), "public concept entry is a debug campaign")
	for resolution in [Vector2i(1280, 900), Vector2i(1008, 630), Vector2i(1440, 630)]:
		root.size = resolution
		screen._debug_eavesback()
		await settle()
		fit()
		check(screen.battle_view.has_method("concept_rect"), "concept view selected")
		var rect: Rect2 = screen.battle_view.concept_rect(0)
		check(Rect2(Vector2.ZERO, screen.battle_view.size).encloses(rect), "concept is in battlefield")
		check(rect.position.y >= screen.battle_view.enemy_plaque(0).end.y, "shell clears plaque")
		check(is_equal_approx(rect.end.y, screen.battle_view.enemy_feet(0).y), "feet grounded")
		check(screen.battle_view._enemy_at(rect.get_center()) == 0, "concept can be inspected")
		await capture("idle_%d" % resolution.x)
		await tap("load_pierce")
		await tap("confirm")
		await tap("fire")
		check(int(screen.model.s.enemies[0].hp) < 24, "piercing shot damages armoured concept")
		check(screen.battle_view.enemies == screen.model.s.enemies, "presentation matches actual result")
		await capture("hit_%d" % resolution.x)
		await tap("reload")
		check(screen.battle_view.has_method("concept_rect"), "concept persists across redraw")
		check(screen.battle_view.projectiles == screen.model.s.projectiles, "ranged integration preserved")
		await capture("reload_%d" % resolution.x)
		screen._debug_eavesback()
		screen.model.s.enemies = [Data._enemy(["wall", 24, 3, 1, 14]), Data._enemy(["runner", 12, 0, 2, 19]), Data._enemy(["spitter", 12, 0, 0, 24]), Data._enemy(["wall", 24, 3, 1, 29])]
		screen.model.s.encounter_total = 4
		screen.model.s.deployed = 4
		screen.model.assign_opening_lanes()
		screen.redraw()
		await settle()
		fit()
		for i in [0, 3]:
			var bounds: Rect2 = screen.battle_view.concept_rect(i)
			check(bounds.position.y >= screen.battle_view.enemy_plaque(i).end.y, "four actors clear labels")
			check(screen.battle_view._enemy_at(bounds.get_center()) == i, "four actor selection")
		await capture("four_%d" % resolution.x)
	# Meta is local to the development campaign, never changes shared Pixel cache.
	check(not screen.campaign.s.has("eavesback_preview") and not screen.model.s.has("eavesback_preview"), "preview flag stays outside save state")
	screen._debug_city("map")
	screen.campaign.enter(int(screen.campaign.choices()[0].id))
	screen.model = screen.campaign.model
	screen.redraw()
	await settle()
	check(screen.battle_view.get_script().resource_path.ends_with("/residential_battle_view.gd"), "new residential run uses production art after preview")
	await capture("normal_after_preview")
	screen.queue_free()
	await process_frame
	print("EAVESBACK UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
