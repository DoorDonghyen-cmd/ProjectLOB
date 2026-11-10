extends "res://tests/challenge_ui_runner.gd"
const Ascent = preload("res://redesign/ascent_background.gd")
var preview_script = preload("res://redesign/garden_preview.gd")
var region_index := 2
var suite := "garden"
var asset_directory := "garden_ascent_20261023"
var actor_renderer := "garden_battle_view.gd"
var finish_encounter := ""

func district_checks() -> void:
	pass

func damaging_round() -> String:
	for round_id in screen.model.s.hand:
		if preload("res://redesign/content.gd").damage(str(round_id), screen.model.s) > 0: return str(round_id)
	return ""

func open_stage(stage: int, encounter: String = "") -> void:
	screen.call("_debug_%s_background" % suite, stage, encounter)

func ground_check(label: String) -> void:
	var view = screen.battle_view
	var source: Rect2 = view.background_source_rect()
	check(view.background_profile.ready and view.background_profile.region == region_index, "authored background " + label)
	check(Rect2(Vector2.ZERO, view.tower_texture.get_size()).encloses(source), "whole crop inside texture " + label)
	var ground: float = (float(view.source_floor_y) - source.position.y) * view.size.y / source.size.y
	check(absf(ground - view.player_feet().y) < 0.01, "floor meets hero " + label)
	var frame := Rect2(Vector2.ZERO, view.size)
	for i in view._alive_indices():
		check(absf(ground - view.enemy_feet(i).y) < 0.01, "floor meets enemy " + label)
		check(frame.encloses(view.enemy_plaque(i)), "HP fits " + label)
		check(frame.encloses(view.distance_label_rect(i)), "distance fits " + label)
		for j in view._alive_indices():
			if i != j: check(not view.enemy_plaque(i).intersects(view.enemy_plaque(j)), "distinct HP columns " + label)
	check(not screen.main_scroll.get_v_scroll_bar().visible and not screen.main_scroll.get_h_scroll_bar().visible, "no screen overflow " + label)

func background_states() -> void:
	for version in [1, 2, 3]:
		var per_height := {}
		var stages := {}
		var length := int(Data.info(region_index, version).floors)
		for node in Data.nodes(region_index, 731042, version):
			var profile := Ascent.profile(region_index, int(node.floor), length)
			if per_height.has(node.floor): check(per_height[node.floor] == profile, "same-height branches share art")
			per_height[node.floor] = profile
			stages[profile.stage] = true
			check(profile.ready and profile.path.contains(asset_directory), "all map versions use district art")
		check(stages.size() == 3, "three bands in each map version")
	# Save checks traverse an actual available node; later visual previews jump rooms.
	for roster in [6, 8]:
		screen.campaign = preview_script.campaign(-1, "", roster)
		check(screen.campaign != null and screen.campaign.s.region == region_index, "preview enters requested region")
		if screen.campaign == null: return
		check(screen.campaign.enter(int(screen.campaign.choices()[0].id)), "legal route entry")
		screen.model = screen.campaign.model
		screen.page = "run"; screen.debug_session = true
		screen.redraw(); await settle()
		var before := hash(screen.model.s)
		var restored := Campaign.new()
		check(screen.campaign.save("user://%s_restore.json" % suite) == OK, "isolated district save")
		var restored_ok := restored.restore("user://%s_restore.json" % suite)
		check(restored_ok, "district save restores")
		if restored_ok:
			check(Ascent.profile(region_index, restored.s.floor, restored.region_info().floors) == screen.battle_view.background_profile, "restore selects same art without new fields")
		screen.redraw(); await settle()
		check(hash(screen.model.s) == before and screen.campaign.s.roster_version == roster, "new art preserves old/new combat and RNG")
		ground_check("restored")

func finish_presentation() -> void:
	open_stage(2, finish_encounter); await settle()
	check(not screen.campaign.s.resolved and screen.campaign.s.encounter.is_empty(), "direct preview resets previous room resolution")
	# Rendering-only fixture; never evidence of a legitimately won encounter.
	screen.model.s.enemies = [screen.model.s.enemies[0]]
	screen.model.s.reinforcements = []
	screen.model.s.encounter_total = 1; screen.model.s.deployed = 1
	screen.model.s.enemies[0].hp = 1; screen.model.s.enemies[0].def = 0
	if preload("res://redesign/noble_house.gd").shielded(screen.model.s.enemies[0]):
		preload("res://redesign/noble_house.gd").strip(screen.model.s.enemies[0], 9)
	screen.model.s.enemies[0].barrier = 0
	screen.redraw(); await settle()
	var round_id := damaging_round()
	check(not round_id.is_empty(), "finish uses a damaging owned round")
	await tap("load_" + round_id); await tap("confirm")
	screen.presentation_speed = 0.8
	await begin_touch("fire")
	var view = screen.battle_view
	var seen := false
	var captured := false
	var started := Time.get_ticks_msec()
	while screen.busy and Time.get_ticks_msec() - started < 15000:
		if view.finish_active:
			seen = true
			var frame := Rect2(Vector2.ZERO, view.size)
			check((view.finish_camera() * frame).grow(1).encloses(frame), "zoom covers entire battle view")
		if not captured and not view.damage_popups.is_empty():
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join("%s_finish.png" % suite)) == OK, "capture finish")
			captured = true
		await process_frame
	check(seen and captured and not screen.busy, "lethal zoom and damage complete")
	check(screen.campaign.s.phase == "reward", "finish enters reward screen")
	check(not screen.campaign.s.resolved, "preview reward can be selected")
	screen.presentation_speed = 0.06; await settle()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/%s_background/" % suite): quit(1); return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false; screen.presentation_speed = 0.06
	root.add_child(screen); await settle()
	await background_states()
	for resolution in [Vector2i(1280, 800), Vector2i(1008, 630), Vector2i(1440, 630)]:
		root.size = resolution; await settle()
		for stage in range(3):
			open_stage(stage); await settle()
			check(screen.battle_view.background_profile.stage == stage, "preview uses correct district band")
			check(screen.battle_view.get_script().resource_path.ends_with(actor_renderer), "production actor renderer")
			var before := hash(screen.model.s)
			var feet: Vector2 = screen.battle_view.player_feet()
			var positions: Array = []
			for i in screen.battle_view._alive_indices(): positions.append(screen.battle_view.enemy_feet(i))
			var length := int(screen.campaign.region_info().floors)
			for other in range(3):
				var depth := ceili(float(other * length) / 3.0) + 1
				screen.battle_view.set_route_background(region_index, depth, length); await settle()
				check(screen.battle_view.background_profile.stage == other, "each region length reaches requested band")
				check(hash(screen.model.s) == before and screen.battle_view.player_feet() == feet, "background change keeps state and hero")
				for i in range(positions.size()): check(screen.battle_view.enemy_feet(i) == positions[i], "background change keeps distance positions")
			screen.redraw(); await settle()
			ground_check("stage%d_%d" % [stage, resolution.x])
			await capture("stage%d_%d" % [stage, resolution.x])
			print("ACTION ", suite, " stage=", stage, " width=", resolution.x, " round=", screen.model.s.hand[0])
			await tap("load_" + str(screen.model.s.hand[0]))
			check(not screen.model.s.plan.is_empty(), "tap loaded round stage%d_%d" % [stage, resolution.x])
			if screen.model.s.plan.is_empty(): await capture("failed_load_%d_%d" % [stage, resolution.x])
			await tap("confirm"); await tap("fire")
			check(screen.battle_view.background_profile.stage == stage, "firing retains district stage")
			await replay_reload()
			ground_check("after actions")
		for encounter in ["elite", "boss"]:
			open_stage(2, encounter); await settle()
			ground_check(encounter)
			await capture("%s_%d" % [encounter, resolution.x])
	root.size = Vector2i(1008, 630); await settle()
	for stage in range(3):
		screen._developer(); await settle()
		var key := "debug_%s_background_%d" % [suite, stage]
		var button := screen.find_child(key, true, false) as Control
		check(button != null, "district menu entry exists")
		var parent := button.get_parent()
		while parent != null:
			if parent is ScrollContainer: parent.ensure_control_visible(button)
			parent = parent.get_parent()
		await settle(); await begin_touch(key); await settle()
		check(screen.debug_session and screen.campaign.s.region == region_index and screen.campaign.s.phase == "combat" and screen.battle_view.background_profile.stage == stage, "touch opens isolated district stage")
	root.size = Vector2i(1280, 800); await settle()
	await finish_presentation()
	await district_checks()
	check(not screen.save_enabled, "normal saves remain disabled")
	print("%s BACKGROUND UI COMPLETE checks=%d failures=%d" % [suite.to_upper(), checks, failures])
	screen.queue_free(); await process_frame
	quit(0 if failures == 0 else 1)
