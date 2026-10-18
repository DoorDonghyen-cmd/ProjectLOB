extends "res://tests/actor_motion_ui_runner.gd"

func actor_frame(viewport: SubViewport) -> Image:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func check_surface_heat() -> void:
	var viewport = load("res://redesign/weapon_actor.tscn").instantiate()
	root.add_child(viewport)
	var actor = viewport.get_node("Actor")
	for gun in actor.WEAPONS:
		for action in ["idle", "aim", "recoil", "reload_open", "reload_seat", "cooling"]:
			actor.configure(gun, action, 0.4, 0.4, 0.0)
			var cold := (await actor_frame(viewport)).get_data()
			actor.configure(gun, action, 0.4, 0.4, 1.0)
			var hot := (await actor_frame(viewport)).get_data()
			var same_alpha := true
			for index in range(3, cold.size(), 4):
				if cold[index] != hot[index]:
					same_alpha = false
					break
			check(same_alpha, "heat cannot add pixels outside existing silhouette " + gun + "/" + action)
			check(hash(cold) != hash(hot), "heat changes metal surface " + gun + "/" + action)
			actor.configure(gun, action, 0.4, 0.4, 0.0)
			check(hash(cold) == hash((await actor_frame(viewport)).get_data()), "cooling restores original pixels " + gun + "/" + action)
	viewport.queue_free()
	await process_frame

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/muzzle_followup/"):
		quit(1); return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	root.size = Vector2i(1280, 900)
	await settle()
	await check_surface_heat()
	await combat(["basic", "cool"], "single", true)
	await set_enemies([["runner", 60, 0, 1, 20]])
	var view = screen.battle_view
	view.reduced_feedback = true
	view.hero_action = "idle"
	var cold_background: PackedByteArray
	for heat in [0, 1, 12]:
		view.heat_debt = heat
		view.queue_redraw()
		await settle()
		await RenderingServer.frame_post_draw
		var frame := root.get_texture().get_image()
		# User-reported bar was 18x3 directly below the muzzle. Its lowest
		# row must remain background at both low and maximum residual heat.
		var below := Rect2i(view.global_position + view.player_muzzle() + Vector2(-14, 3), Vector2(14, 1))
		var background := frame.get_region(below).get_data()
		if heat == 0: cold_background = background
		else: check(background == cold_background, "no floating bar below muzzle at heat " + str(heat))
		frame.save_png(OS.get_environment("QA_OUTPUT_DIR").path_join("heat_%d.png" % heat))
		# Inspect the same player area, without resampling the pixels.
		var area := Rect2i(view.global_position + Vector2(35, view.player_feet().y - 135), Vector2(200, 160))
		frame.get_region(area).save_png(OS.get_environment("QA_OUTPUT_DIR").path_join("player_heat_%d.png" % heat))
		if heat == 1:
			# Prove this image assertion detects the former rendering defect.
			var legacy_overlay := Node2D.new()
			view.add_child(legacy_overlay)
			legacy_overlay.draw.connect(func(): legacy_overlay.draw_rect(Rect2(view.player_muzzle() + Vector2(-16, 1), Vector2(18, 3)), view.HOT))
			legacy_overlay.queue_redraw()
			await settle()
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().get_region(below).get_data() != cold_background, "regression sample detects the old floating rectangle")
			legacy_overlay.queue_free()
			await process_frame
	print("WEAPON HEAT UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures > 0 else 0)
