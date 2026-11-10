extends SceneTree
const FONT=preload("res://redesign/combat_pixel_font.tres")
func _initialize() -> void:run.call_deferred()
func label(parent: Control, text: String, position: Vector2, color: Color) -> void:
	var item:=Label.new();item.text=text;item.position=position
	item.add_theme_font_override("font",FONT);item.add_theme_font_size_override("font_size",20)
	item.add_theme_color_override("font_color",color);parent.add_child(item)
func coordinates(text: String) -> Vector2:
	var regex:=RegEx.new();regex.compile("-?[0-9]+(?:\\.[0-9]+)?")
	var results:=regex.search_all(text)
	return Vector2(results[0].get_string().to_float(),results[1].get_string().to_float())
func run() -> void:
	var output:=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/surface_fx_20261106/"):quit(2);return
	var folder:=output.get_base_dir().path_join("ui")
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("frames.json")))
	root.size=Vector2i(1280,764);root.content_scale_size=root.size
	var canvas:=Control.new();root.add_child(canvas)
	var bg:=ColorRect.new();bg.color=Color("172329");bg.size=root.size;canvas.add_child(bg)
	label(canvas,"장갑 · 차폐 · 전이 · 불꽃 / 실제 화면 2배 확대",Vector2(18,8),Color("e6e8d4"))
	var cases:=[
		["metal","장갑에 적중","shot",0],
		["chips","장갑 파편","shot",3],
		["shield","차폐에 막힘","shot",2],
		["arc","전류 전이","shot",1],
		["transfer","화상 이동 · 적에서 적으로","shot",2],
		["fire","바닥 불길 · 남은 영역","burn",2]]
	for i in range(cases.size()):
		var rows:Array=data.frames.filter(func(row):return row.case==str(cases[i][0])+"_1280x800" and row.profile.kind==cases[i][2])
		if rows.is_empty():quit(1);return
		var selected:Dictionary=rows[0]
		for row in rows:
			if row.phase==cases[i][3]:selected=row;break
		var file:String=selected.image if i!=5 else "settled_fire_1280x800.png"
		var texture:=ImageTexture.create_from_image(Image.load_from_file(folder.path_join(file)))
		var point:=coordinates(selected.point);var foot:=coordinates(selected.foot)
		var center:=Vector2(point.x,foot.y-66)
		if i in [3,4] and not selected.links.is_empty():center.x=(point.x+coordinates(selected.links[0].destination).x)*0.5
		var atlas:=AtlasTexture.new();atlas.atlas=texture;atlas.region=Rect2((center-Vector2(100,74)).round(),Vector2(200,148))
		var origin:=Vector2(i%3*426,42+i/3*350)
		label(canvas,cases[i][1],origin+Vector2(14,4),Color("ddaa7c") if i>=4 else Color("c0cdca"))
		var picture:=TextureRect.new();picture.texture=atlas;picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		picture.position=origin+Vector2(14,36);picture.size=Vector2(400,296);canvas.add_child(picture)
	for n in range(6):await process_frame
	await RenderingServer.frame_post_draw
	var error:=root.get_texture().get_image().save_png(output.path_join("surface_comparison.png"))
	print("SURFACE FX GALLERY COMPLETE failures=",0 if error==OK else 1);quit(0 if error==OK else 1)
