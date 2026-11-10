extends SceneTree
const FONT=preload("res://redesign/combat_pixel_font.tres")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var output:=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/spike_motion_20261106/"): quit(2); return
	root.size=Vector2i(960,360); root.content_scale_size=root.size
	var canvas:=Control.new();root.add_child(canvas)
	var background:=ColorRect.new();background.color=Color("34434a");background.size=root.size;canvas.add_child(background)
	for index in range(2):
		var directory:=output.get_base_dir().path_join("before" if index==0 else "after")
		var picture:=Image.load_from_file(directory.path_join("actor_carrier_recoil_3.png"))
		if picture==null: quit(2);return
		var display:=TextureRect.new();display.texture=ImageTexture.create_from_image(picture)
		display.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		display.position=Vector2(index*480,0);display.size=Vector2(480,320);canvas.add_child(display)
		var label:=Label.new();label.text="수정 전 · 사격 반동" if index==0 else "수정 후 · 조준 팔 유지"
		label.add_theme_font_override("font",FONT);label.add_theme_font_size_override("font_size",20)
		label.position=Vector2(index*480+125,328);canvas.add_child(label)
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var error:=root.get_texture().get_image().save_png(output.path_join("spike_before_after.png"))
	print("SPIKE MOTION COMPARE COMPLETE failures=",0 if error==OK else 1)
	quit(0 if error==OK else 1)
