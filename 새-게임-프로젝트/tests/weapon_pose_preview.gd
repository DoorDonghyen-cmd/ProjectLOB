extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1200, 720)
	var output := OS.get_environment("QA_OUTPUT_DIR")
	if output.is_empty():
		quit(1)
		return
	for gun in ["single", "amplifier", "burst", "scatter", "heavy"]:
		var board := Control.new()
		root.add_child(board)
		var background := ColorRect.new()
		background.color = Color("34444b")
		background.size = Vector2(1200,720)
		board.add_child(background)
		var index := 0
		for pose in ["idle", "aim", "recoil", "reload_open", "reload_seat", "cooling"]:
			var viewport = load("res://redesign/weapon_actor.tscn").instantiate()
			board.add_child(viewport)
			viewport.get_node("Actor").configure(gun, pose)
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			var image := TextureRect.new()
			image.texture = viewport.get_texture()
			image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.position = Vector2(index % 3 * 400, index / 3 * 360)
			image.size = Vector2(480,320)
			board.add_child(image)
			var label := Label.new()
			label.text = gun + " / " + pose
			label.position = image.position + Vector2(20, 326)
			board.add_child(label)
			index += 1
		for frame in range(4): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("poses_" + gun + ".png"))
		board.queue_free()
		await process_frame
	quit()
