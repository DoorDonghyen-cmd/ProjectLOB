extends SceneTree
const FONT=preload("res://redesign/combat_pixel_font.tres")
func _initialize() -> void:run.call_deferred()
func label(parent: Control, text: String, point: Vector2, color: Color) -> void:
	var item:=Label.new();item.text=text;item.position=point
	item.add_theme_font_override("font",FONT);item.add_theme_font_size_override("font_size",20)
	item.add_theme_color_override("font_color",color);parent.add_child(item)
func run() -> void:
	var output:=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/firing_fx_20261106/"):quit(2);return
	var folder:=output.get_base_dir().path_join("ui")
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("frames.json")))
	root.size=Vector2i(1280,664);root.content_scale_size=root.size
	var canvas:=Control.new();root.add_child(canvas)
	var bg:=ColorRect.new();bg.color=Color("172329");bg.size=root.size;canvas.add_child(bg)
	label(canvas,"총기별 실제 발사 화면 · 동일 크기 확대",Vector2(18,8),Color("e6e8d4"))
	var cases:=[
		["single_plain_1280x800","리벳 · 짧은 섬광"],
		["burst_plain_1280x800","래칫 · 좁은 섬광"],
		["scatter_plain_1280x800","스플린터 · 넓은 섬광"],
		["heavy_plain_1280x800","리액터 · 두꺼운 섬광"],
		["amplifier_plain_1280x800","스파이크 · 바늘 섬광"],
		["single_opening_1280x800","첫 발 ×2 · 적중과 같은 색"]]
	for i in range(cases.size()):
		var rows:Array=data.frames.filter(func(row):return row.case==str(cases[i][0]) and row.phase=="flash")
		if rows.is_empty():quit(1);return
		var selected:Dictionary=rows[0]
		var texture:=ImageTexture.create_from_image(Image.load_from_file(folder.path_join(selected.image)))
		var regex:=RegEx.new();regex.compile("-?[0-9]+(?:\\.[0-9]+)?")
		var coords:=regex.search_all(str(selected.global_muzzle))
		var muzzle:=Vector2(coords[0].get_string().to_float(),coords[1].get_string().to_float())
		var atlas:=AtlasTexture.new();atlas.atlas=texture;atlas.region=Rect2(muzzle-Vector2(100,65),Vector2(196,132))
		var origin:=Vector2(i%3*426,42+i/3*308)
		label(canvas,cases[i][1],origin+Vector2(14,4),Color("cbb0ee") if i==5 else Color("e6e8d4"))
		var picture:=TextureRect.new();picture.texture=atlas;picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		picture.position=origin+Vector2(14,36);picture.size=Vector2(392,264);canvas.add_child(picture)
	for n in range(6):await process_frame
	await RenderingServer.frame_post_draw
	var error:=root.get_texture().get_image().save_png(output.path_join("firing_comparison.png"))
	print("FIRING FX GALLERY COMPLETE failures=",0 if error==OK else 1);quit(0 if error==OK else 1)
