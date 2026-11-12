extends SceneTree

const Actor = preload("res://redesign/weapon_actor.gd")
const Stage = preload("res://redesign/weapon_actor.tscn")
const FONT = preload("res://redesign/combat_pixel_font.tres")
const POSES := ["idle", "aim", "recoil", "reload_open", "reload_seat", "cooling"]
const CAPTIONS := ["대기", "조준", "사격 반동", "재장전 열기", "재장전 닫기", "냉각"]
const GUNS := ["amplifier", "single"]

func _initialize() -> void:
	run.call_deferred()

func label(parent: Control, title: String, point: Vector2) -> void:
	var item := Label.new()
	item.text = title
	item.position = point
	item.add_theme_font_override("font", FONT)
	item.add_theme_font_size_override("font_size", 18)
	parent.add_child(item)

func run() -> void:
	var output := OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\", "/").contains("/qa_runtime/spike_motion_20261106/"): quit(2); return
	root.size = Vector2i(1320, 380)
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1.0
	var failures := 0
	for outfit in Actor.GRID_OUTFITS:
		var sheet := Control.new()
		root.add_child(sheet)
		var background := ColorRect.new()
		background.color = Color("29363a")
		background.size = root.size
		sheet.add_child(background)
		for column in range(POSES.size()):
			label(sheet, CAPTIONS[column], Vector2(column * 220 + 12, 8))
			for row in range(GUNS.size()):
				var stage := Stage.instantiate() as SubViewport
				sheet.add_child(stage)
				var actor = stage.get_node("Actor")
				actor.set_outfit(outfit)
				actor.configure(GUNS[row], POSES[column], 1.0 if POSES[column] == "recoil" else 0.0)
				stage.render_target_update_mode = SubViewport.UPDATE_ALWAYS
				var cell: Rect2 = actor.outfit_grid_region()
				var expected_row := Actor.GRID_OUTFITS.find(outfit) * 2 + row
				if not cell.has_area() or int(cell.position.y / Actor.GRID_CELL.y) != expected_row:
					failures += 1
					print("FAIL: registered outfit ", outfit, " ", GUNS[row], " ", POSES[column])
				var display := TextureRect.new()
				display.texture = stage.get_texture()
				display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				display.position = Vector2(column * 220, 26 + row * 174)
				display.size = Vector2(216, 144)
				sheet.add_child(display)
		label(sheet, "스파이크 · %s" % outfit, Vector2(12, 170))
		label(sheet, "리벳 · %s" % outfit, Vector2(12, 344))
		for frame in range(4): await process_frame
		await RenderingServer.frame_post_draw
		if root.get_texture().get_image().save_png(output.path_join("outfit_%s.png" % outfit)) != OK: failures += 1
		sheet.free()
		await process_frame
	print("SPIKE MOTION OUTFITS COMPLETE samples=%d failures=%d" % [Actor.GRID_OUTFITS.size() * GUNS.size() * POSES.size(), failures])
	quit(0 if failures == 0 else 1)
