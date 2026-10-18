extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var output := OS.get_environment("QA_OUTPUT_DIR")
	if output.is_empty():
		quit(1)
		return
	root.size = Vector2i(1000, 630)
	root.content_scale_size = root.size
	for outfit in ["work", "hoist"]:
		for pose in ["aim", "reload_open", "cooling"]:
			var board := Control.new()
			root.add_child(board)
			var background := ColorRect.new()
			background.color = Color("34444b")
			background.size = Vector2(root.size)
			board.add_child(background)
			for column in range(2):
				var viewport = load("res://redesign/weapon_actor.tscn").instantiate()
				var actor = viewport.get_node("Actor")
				actor.coarse_burst = column == 1
				actor.set_outfit(outfit)
				actor.configure("burst", pose, 0.0, 0.4, 0.0)
				board.add_child(viewport)
				viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
				var heading := Label.new()
				heading.text = ("BEFORE" if column == 0 else "COARSE GRID") + " / " + outfit + " / " + pose
				heading.position = Vector2(column * 500 + 24, 15)
				board.add_child(heading)
				for row in range(2):
					var picture := TextureRect.new()
					picture.texture = viewport.get_texture()
					picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
					picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					var factor := 0.62 if row == 0 else 0.22
					picture.size = Vector2(viewport.size) * factor
					picture.position = Vector2(column * 500 + 32, 65 if row == 0 else 470)
					board.add_child(picture)
				var caption := Label.new()
				caption.text = "Below: combat-size reference"
				caption.position = Vector2(column * 500 + 24, 425)
				board.add_child(caption)
			for frame in range(6): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join(outfit + "_" + pose + ".png"))
			board.queue_free()
			await process_frame
	print("WEAPON DENSITY PREVIEW COMPLETE")
	quit()
