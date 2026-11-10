extends "res://tests/navigation_ui_runner.gd"
## Compare on-demand actor textures with a continuously rendered reference.
## This catches stale inner weapons and stale outer bodies after any pose change.
func compare_actor(preview: Control, label: String) -> void:
	await settle()
	var viewport: SubViewport = preview.actor_viewport
	var weapon_viewport: SubViewport = preview.actor.weapon_layer_viewport
	# The scene property retains UPDATE_ONCE; the renderer owns its transition
	# to disabled after drawing. Query that effective state in QA only.
	check(RenderingServer.viewport_get_update_mode(viewport.get_viewport_rid()) == RenderingServer.VIEWPORT_UPDATE_DISABLED, "outer viewport rests " + label)
	check(RenderingServer.viewport_get_update_mode(weapon_viewport.get_viewport_rid()) == RenderingServer.VIEWPORT_UPDATE_DISABLED, "inner viewport rests " + label)
	var cached := viewport.get_texture().get_image().get_data()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	weapon_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await settle()
	check(cached == viewport.get_texture().get_image().get_data(), "pixels match continuously rendered reference " + label)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	weapon_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await settle()

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/playtest_revision_20261026/render_ui/"):
		quit(2); return
	output = OS.get_environment("QA_OUTPUT_DIR")
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	await settle()
	screen._open_preparation(false)
	await settle()
	var preview = screen.find_child("OutfitPortrait", true, false)
	for outfit in Content.OUTFITS:
		screen.find_child("outfit_select_" + outfit, true, false).pressed.emit()
		for gun in Content.GUNS:
			screen.find_child("weapon_select_" + gun, true, false).pressed.emit()
			for pose in ["idle", "aim", "recoil", "reload_open", "reload_seat", "cooling"]:
				preview.actor.configure(gun, pose, 0.7 if pose == "recoil" else 0.0, 0.7 if pose == "reload_seat" else -1.0, 0.6 if pose == "cooling" else 0.0)
				await compare_actor(preview, outfit + "/" + gun + "/" + pose)
	for resolution in [Vector2i(1280,800), Vector2i(1008,630), Vector2i(1440,630)]:
		root.size = resolution
		root.content_scale_size = resolution
		await settle()
		preview = screen.find_child("OutfitPortrait", true, false)
		for outfit in Content.OUTFITS:
			screen.find_child("outfit_select_" + outfit, true, false).pressed.emit()
			screen.find_child("weapon_select_single", true, false).pressed.emit()
			await settle()
			preview = screen.find_child("OutfitPortrait", true, false)
			var rect: Rect2 = preview.display_rect()
			var foot: Vector2 = preview.global_position + rect.position + (preview.WeaponActor.FOOT - preview.SOURCE_RECT.position) * (rect.size.x / preview.SOURCE_RECT.size.x)
			check(screen.find_child("Stage", true, false).get_global_rect().has_point(foot), "feet within equipment stage")
			check(not screen.main_scroll.get_h_scroll_bar().visible and not screen.main_scroll.get_v_scroll_bar().visible, "equipment fits " + str(resolution))
			await capture("ground_%s_%d" % [outfit, resolution.x])
	print("PLAYTEST REVISION RENDER UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
