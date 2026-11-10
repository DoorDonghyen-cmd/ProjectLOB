extends SceneTree
const FONT=preload("res://redesign/combat_pixel_font.tres")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var output:=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/impact_parts_20261106/"):quit(2);return
	var folder:=output.get_base_dir().path_join("ui")
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("frames.json")))
	root.size=Vector2i(1280,740);root.content_scale_size=root.size
	var canvas:=Control.new();root.add_child(canvas)
	var bg:=ColorRect.new();bg.color=Color("17252c");bg.size=root.size;canvas.add_child(bg)
	var cases:=[["plain","일반 적중"],["add","가산 강화"],["opening","첫 발 ×2"],["third","세 번째 발 ×3"],["stacked","배율 중첩"],["thermal","열압 ×1.50"]]
	for i in range(cases.size()):
		var matches:Array=data.frames.filter(func(row):return row.case==str(cases[i][0])+"_1280x800")
		var selected:Dictionary=matches[0]
		for row in matches:
			if row.phase==1:selected=row;break
		var frame:=ImageTexture.create_from_image(Image.load_from_file(folder.path_join(selected.image)))
		var regex:=RegEx.new();regex.compile("-?[0-9]+(?:\\.[0-9]+)?")
		var coords:=regex.search_all(str(selected.entries[0].bounds))
		var center:=Vector2(coords[0].get_string().to_float()+80,coords[1].get_string().to_float()+coords[3].get_string().to_float()*0.5)
		var atlas:=AtlasTexture.new();atlas.atlas=frame;atlas.region=Rect2((center-Vector2(120,105)).round(),Vector2(240,170))
		var origin:=Vector2(i%3*426,i/3*370)
		var label:=Label.new();label.text=cases[i][1];label.position=origin+Vector2(16,12);label.add_theme_font_override("font",FONT);label.add_theme_font_size_override("font_size",24)
		label.add_theme_color_override("font_color",Color(str(selected.entries[0].color)));canvas.add_child(label)
		var picture:=TextureRect.new();picture.texture=atlas;picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
		picture.position=origin+Vector2(14,54);picture.size=Vector2(396,280);canvas.add_child(picture)
	for n in range(6):await process_frame
	await RenderingServer.frame_post_draw
	var error:=root.get_texture().get_image().save_png(output.path_join("impact_comparison.png"))
	print("IMPACT PARTS GALLERY COMPLETE failures=",0 if error==OK else 1);quit(0 if error==OK else 1)
