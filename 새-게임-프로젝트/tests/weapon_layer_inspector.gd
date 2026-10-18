extends SceneTree

class LayerActor extends "res://redesign/weapon_actor.gd":
	var layer := 0
	func _draw() -> void:
		if layer == 3:
			super._draw()
			return
		var frame := pose(gun_id, pose_id)
		var body: Texture2D = BODIES[family(gun_id)]
		var offset: Vector2 = FOOT - frame.foot
		var cell: Vector2 = frame.cell * CELL
		if layer == 0:
			draw_texture_rect_region(body, Rect2(offset, CELL), Rect2(cell, CELL))
		elif layer == 1:
			draw_set_transform_matrix(weapon_transform(gun_id, pose_id))
			draw_texture(WEAPONS[gun_id].image, Vector2.ZERO)
		elif layer == 2:
			for hand: Rect2 in foreground_hands(gun_id, pose_id):
				draw_texture_rect_region(body, Rect2(offset + hand.position, hand.size), Rect2(cell + hand.position, hand.size))

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1200, 1050)
	root.content_scale_size = root.size
	var board := Control.new()
	root.add_child(board)
	var bg := ColorRect.new()
	bg.color = Color("34444b")
	bg.size = Vector2(1200,1050)
	board.add_child(bg)
	var row := 0
	for gun in ["single", "amplifier", "burst", "scatter", "heavy"]:
		for column in range(4):
			var viewport = load("res://redesign/weapon_actor.tscn").instantiate()
			board.add_child(viewport)
			var actor = viewport.get_node("Actor")
			actor.set_script(LayerActor)
			actor.layer = column
			actor.configure(gun, "idle")
			actor.queue_redraw()
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			var picture := TextureRect.new()
			picture.texture = viewport.get_texture()
			picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			picture.position = Vector2(column*300,row*210)
			picture.size = Vector2(288,192)
			board.add_child(picture)
			var label := Label.new()
			label.text = gun + " / " + ["body", "weapon", "hands", "combined"][column]
			label.position = picture.position + Vector2(10,190)
			board.add_child(label)
		row += 1
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join("weapon_layers.png"))
	print("WEAPON LAYER INSPECTION COMPLETE")
	quit()
