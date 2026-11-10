extends SceneTree
const Content=preload("res://redesign/content.gd")
const Actor=preload("res://redesign/weapon_actor.gd")
const FONT=preload("res://redesign/combat_pixel_font.tres")
var checks:=0
var failures:=0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures+=1;print("FAIL: "+label)
func run() -> void:
	var output:=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").ends_with("/qa_runtime/weapon_live_20261106/poses"):quit(2);return
	root.size=Vector2i(1280,480);root.content_scale_size=root.size
	var evidence: Array=[]
	for outfit in Content.OUTFITS:
		var board:=Control.new();root.add_child(board)
		var bg:=ColorRect.new();bg.color=Color("34444b");bg.size=root.size;board.add_child(bg)
		for row in range(2):
			var gun: String=["deadbolt","rewinder"][row]
			var col:=0
			for action in ["idle","aim","recoil","reload_open","reload_seat","cooling"]:
				var viewport=load("res://redesign/weapon_actor.tscn").instantiate();board.add_child(viewport)
				viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
				var actor=viewport.get_node("Actor")
				actor.set_outfit(outfit);actor.configure(gun,action,1.0 if action=="recoil" else 0.0,0.4 if action=="reload_open" else 0.95,0.8 if action=="cooling" else 0.0)
				var picture:=TextureRect.new();picture.texture=viewport.get_texture();picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
				picture.position=Vector2(col*213,row*240);picture.size=Vector2(213,170);board.add_child(picture)
				var label:=Label.new();label.text=Content.GUNS[gun].name+" · "+action;label.position=picture.position+Vector2(8,180);label.add_theme_font_override("font",FONT);label.add_theme_font_size_override("font_size",13);board.add_child(label)
				var frame: Dictionary=Actor.frame_for(outfit,gun,action)
				check(actor.outfit_grid_region().has_area(),"live G body grid "+outfit+gun+action)
				var profile: Dictionary=Actor.WEAPONS[gun]
				var grip: Vector2=actor.registered_transform()*profile.grip
				check(grip.distance_to(Actor.FOOT+(frame.grip-frame.foot)*frame.scale)<0.01,"rear grip "+outfit+gun+action)
				check(Rect2(Vector2.ZERO,actor.body_texture().get_size()).encloses(frame.source),"correct outfit body source "+outfit+gun+action)
				var muzzle: Vector2=actor.registered_muzzle(Vector2(122,500),0.12)
				check(muzzle.is_finite() and Rect2(0,0,1280,800).has_point(muzzle),"registered muzzle "+outfit+gun+action)
				if frame.has("support"):
					var support: Vector2=Actor.FOOT+(frame.support-frame.foot)*frame.scale
					evidence.append({"outfit":outfit,"gun":gun,"action":action,"support_source":str(actor.registered_transform().affine_inverse()*support)})
				for unused in range(4):await process_frame
				await RenderingServer.frame_post_draw
				var image: Image=viewport.get_texture().get_image();var occupied: Rect2i=image.get_used_rect()
				check(occupied.position.x>0 and occupied.end.x<768 and occupied.end.y<=512 and occupied.size.y>300,"actor unclipped "+outfit+gun+action)
				if outfit=="work":image.save_png(output.path_join(gun+"_"+action+".png"))
				col+=1
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(output.path_join("poses_"+outfit+".png"))==OK,"native pose contact sheet "+outfit)
		board.free();await process_frame
	FileAccess.open(output.path_join("contacts.json"),FileAccess.WRITE).store_string(JSON.stringify(evidence,"  "))
	print("WEAPON LIVE POSES COMPLETE checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
