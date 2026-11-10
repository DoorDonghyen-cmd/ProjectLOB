extends "res://tests/foundry_live_ui_runner.gd"
const Ascent = preload("res://redesign/ascent_background.gd")

func ground_check(label: String) -> void:
	var view = screen.battle_view
	var source: Rect2 = view.background_source_rect()
	check(view.background_profile.ready and view.background_profile.region == 1, "foundry authored background " + label)
	check(Rect2(Vector2.ZERO, view.tower_texture.get_size()).encloses(source), "whole crop inside texture " + label)
	var ground: float = (float(view.source_floor_y) - source.position.y) * view.size.y / source.size.y
	check(absf(ground - view.player_feet().y) < 0.01, "background floor meets hero " + label)
	for i in view._alive_indices():
		check(absf(ground - view.enemy_feet(i).y) < 0.01, "background floor meets enemy " + label)
	check(not screen.main_scroll.get_v_scroll_bar().visible and not screen.main_scroll.get_h_scroll_bar().visible, "screen has no overflow " + label)

func background_states() -> void:
	for map_version in [1, 2, 3]:
		var per_height := {}
		var stages := {}
		var length := int(Data.info(1, map_version).floors)
		for node in Data.nodes(1, 731042, map_version):
			var profile := Ascent.profile(1, int(node.floor), length)
			if per_height.has(node.floor): check(per_height[node.floor] == profile, "all same-height branches share art")
			per_height[node.floor] = profile
			stages[profile.stage] = true
			check(profile.ready and profile.path.contains("foundry_ascent_20261023"), "current and old maps use foundry art")
		check(stages.size() == 3, "all map versions use three stages")
	for i in range(9): check(Ascent.profile(1, i + 1, 9).stage == i / 3, "current nine heights in thirds")
	screen._debug_foundry("single", "", false)
	check(screen.campaign.enter(int(screen.campaign.choices()[0].id)), "legacy real route entry")
	screen.redraw()
	await settle()
	var before := hash(screen.model.s)
	var restored := Campaign.new()
	check(screen.campaign.save("user://foundry_background_restore.json") == OK, "isolated old foundry save")
	check(restored.restore("user://foundry_background_restore.json"), "old foundry run can restore")
	screen.redraw(); await settle()
	check(hash(screen.model.s) == before and screen.campaign.s.roster_version == 6, "legacy combat and RNG unchanged by new background")
	check(Ascent.profile(1, restored.s.floor, restored.region_info().floors) == screen.battle_view.background_profile, "save reload needs no new background fields")
	ground_check("legacy")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/foundry_background/"): quit(1); return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.06
	root.add_child(screen); await settle()
	await background_states()
	for resolution in [Vector2i(1280, 800), Vector2i(1008, 630), Vector2i(1440, 630)]:
		root.size = resolution; await settle()
		for stage in range(3):
			screen._debug_foundry_background(stage); await settle()
			check(screen.battle_view.background_profile.stage == stage, "preview maps to correct height")
			var before := hash(screen.model.s)
			var feet: Vector2 = screen.battle_view.player_feet()
			var enemies: Array = []
			for i in screen.battle_view._alive_indices(): enemies.append(screen.battle_view.enemy_feet(i))
			# Replacing the backdrop only must not shift actors, advance enemies or consume RNG.
			for other in range(3):
				screen.battle_view.set_route_background(1, 1 + other * 3, 9)
				await settle()
				check(hash(screen.model.s) == before and screen.battle_view.player_feet() == feet, "background replacement preserves state and hero")
				for i in range(enemies.size()): check(screen.battle_view.enemy_feet(i) == enemies[i], "background replacement preserves enemy position")
			screen.redraw(); await settle()
			ground_check("stage%d_%d" % [stage, resolution.x])
			await visible_workers("stage%d_%d" % [stage, resolution.x])
			await tap("load_" + str(screen.model.s.hand[0])); await tap("confirm"); await tap("fire")
			check(screen.battle_view.background_profile.stage == stage, "firing retains background")
			await replay_reload()
			check(screen.battle_view.background_profile.stage == stage, "reload retains background")
			ground_check("after actions")
		# Verify the elite's charged pose at its actual encounter height too.
		screen._debug_foundry("single", "elite"); await settle()
		await replay_reload(); await replay_reload()
		ground_check("elite")
		await visible_workers("elite_%d" % resolution.x)
	# Touch each actual developer entry, including a scrolled menu at mobile width.
	root.size = Vector2i(1008, 630); await settle()
	for stage in range(3):
		screen._developer(); await settle()
		var key := "debug_foundry_background_%d" % stage
		var button := screen.find_child(key, true, false) as Control
		check(button != null, "preview entry exists")
		var parent := button.get_parent()
		while parent != null:
			if parent is ScrollContainer: parent.ensure_control_visible(button)
			parent = parent.get_parent()
		await settle(); await begin_touch(key); await settle()
		check(screen.debug_session and screen.campaign.s.phase == "combat" and screen.battle_view.background_profile.stage == stage, "touch opens isolated correct stage")
	root.size = Vector2i(1280, 800); await settle()
	await lethal_presentation()
	check(not screen.save_enabled, "normal saves remain disabled")
	print("FOUNDRY BACKGROUND UI COMPLETE checks=%d failures=%d" % [checks, failures])
	screen.queue_free(); await process_frame
	quit(0 if failures == 0 else 1)
