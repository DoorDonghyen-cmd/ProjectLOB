extends SceneTree
const Content=preload("res://redesign/content.gd")
const FONT=preload("res://redesign/combat_pixel_font.tres")
var checks:=0
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: "+label)
func run() -> void:
	var output:=OS.get_environment("QA_OUTPUT_DIR")
	if output.is_empty(): quit(1);return
	root.size=Vector2i(1300,1400);root.content_scale_size=root.size
	var board:=Control.new();root.add_child(board)
	var bg:=ColorRect.new();bg.color=Color("17262b");bg.size=root.size;board.add_child(bg)
	var entries:Array=[]
	var row:=0
	for outfit in Content.OUTFITS:
		var col:=0
		for gun in Content.GUNS:
			var viewport=load("res://redesign/weapon_actor.tscn").instantiate()
			board.add_child(viewport)
			viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
			var actor=viewport.get_node("Actor")
			actor.set_outfit(outfit)
			var display:=TextureRect.new();display.texture=viewport.get_texture()
			display.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
			display.position=Vector2(col*260,40+row*192);display.size=Vector2(256,170.67)
			board.add_child(display)
			var caption:=Label.new();caption.text=Content.GUNS[gun].name+" · "+Content.OUTFITS[outfit].name
			caption.add_theme_font_override("font",FONT);caption.add_theme_font_size_override("font_size",15)
			caption.position=display.position+Vector2(12,170);board.add_child(caption)
			entries.append({"actor":actor,"viewport":viewport,"gun":gun,"outfit":outfit})
			col+=1
		row+=1
	for pose in ["idle","aim","recoil","reload_open","reload_seat","cooling"]:
		for entry in entries: entry.actor.configure(entry.gun,pose,0.65 if pose=="recoil" else 0,0.4 if pose=="reload_open" else 0.95,0.8 if pose=="cooling" else 0)
		for frame in range(5): await process_frame
		await RenderingServer.frame_post_draw
		for entry in entries:
			var occupied:Rect2i=entry.viewport.get_texture().get_image().get_used_rect()
			check(occupied.size.y>200 and occupied.position.x>0 and occupied.end.x<768 and occupied.end.y<=512,"complete actor "+entry.gun+"/"+entry.outfit+"/"+pose)
		root.get_texture().get_image().save_png(output.path_join("outfit_matrix_"+pose+".png"))
	print("ACTOR CATALOG COMPLETE checks=",checks," failures=",failures)
	board.queue_free();await process_frame
	var preview=load("res://redesign/weapon_concept_preview.tscn").instantiate();root.add_child(preview)
	root.size=Vector2i(1280,820)
	for frame in range(8):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("weapon_catalog.png"))
	quit(1 if failures else 0)
