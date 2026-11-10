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
	var folder:=output.get_base_dir().path_join("projectile")
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("frames.json")))
	root.size=Vector2i(1280,540);root.content_scale_size=root.size
	var canvas:=Control.new();root.add_child(canvas)
	var bg:=ColorRect.new();bg.color=Color("172329");bg.size=root.size;canvas.add_child(bg)
	label(canvas,"날아가는 탄두 · 실제 전투 캡처 3배 확대",Vector2(18,8),Color("e6e8d4"))
	var cases:=[
		["single_basic_p2_1280x800","기본탄 · 구리 탄두"],
		["single_pierce_p2_1280x800","관통탄 · 긴 강철 탄두"],
		["single_precise_p2_1280x800","연타탄 · 띠가 있는 탄두"],
		["single_push_1280x800","충격탄 · 둔한 탄두"],
		["single_bore_1280x800","소이탄 · 소이 코어"],
		["single_basic_p2_empowered_1280x800","배율 강화 · 연보라 띠"]]
	for i in range(cases.size()):
		var rows:Array=data.frames.filter(func(row):return row.case==str(cases[i][0]) and row.phase=="trail")
		if rows.is_empty():quit(1);return
		var selected:Dictionary=rows[0]
		var texture:=ImageTexture.create_from_image(Image.load_from_file(folder.path_join(selected.image)))
		var regex:=RegEx.new();regex.compile("-?[0-9]+(?:\\.[0-9]+)?")
		var coords:=regex.search_all(str(selected.projectile.global_head))
		var head:=Vector2(coords[0].get_string().to_float(),coords[1].get_string().to_float())
		var atlas:=AtlasTexture.new();atlas.atlas=texture;atlas.region=Rect2(head-Vector2(76,32),Vector2(128,64))
		var origin:=Vector2(i%3*426,42+i/3*246)
		label(canvas,cases[i][1],origin+Vector2(14,4),Color("cbb0ee") if i==5 else Color("e6e8d4"))
		var picture:=TextureRect.new();picture.texture=atlas;picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		picture.position=origin+Vector2(14,36);picture.size=Vector2(384,192);canvas.add_child(picture)
	for n in range(6):await process_frame
	await RenderingServer.frame_post_draw
	var error:=root.get_texture().get_image().save_png(output.path_join("projectile_comparison.png"))
	print("FIRING FX PROJECTILE GALLERY COMPLETE failures=",0 if error==OK else 1);quit(0 if error==OK else 1)
