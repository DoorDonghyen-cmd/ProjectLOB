extends SceneTree
const FONT=preload("res://redesign/combat_pixel_font.tres")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var output:=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/rivet_art_20261106/"):quit(2);return
	root.size=Vector2i(960,360);root.content_scale_size=root.size
	var canvas:=Control.new();root.add_child(canvas)
	var bg:=ColorRect.new();bg.size=root.size;bg.color=Color("34444b");canvas.add_child(bg)
	for i in range(2):
		var name:="work_legacy_aim.png" if i==0 else "work_curated_aim.png"
		var source:=output.get_base_dir().path_join("poses").path_join(name)
		var display:=TextureRect.new();display.texture=ImageTexture.create_from_image(Image.load_from_file(source));display.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		display.position=Vector2(i*480,0);display.size=Vector2(480,320);canvas.add_child(display)
		var label:=Label.new();label.text="기존 리벳" if i==0 else "양손 리벳 · 본편 적용"
		label.position=Vector2(i*480+140,328);label.add_theme_font_override("font",FONT);label.add_theme_font_size_override("font_size",20);canvas.add_child(label)
	for n in range(5):await process_frame
	await RenderingServer.frame_post_draw
	var error:=root.get_texture().get_image().save_png(output.path_join("rivet_before_after.png"))
	print("RIVET ART COMPARE COMPLETE failures=",0 if error==OK else 1);quit(0 if error==OK else 1)
