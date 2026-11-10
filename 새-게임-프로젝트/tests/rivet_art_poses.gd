extends SceneTree
const Content=preload("res://redesign/content.gd")
const Actor=preload("res://redesign/weapon_actor.gd")
const Carbine=preload("res://redesign/samples/rivet_carbine_actor.gd")
const Legacy=preload("res://art_source/rivet_twohand_20261106/legacy_weapon_actor.gd")
const FONT=preload("res://redesign/combat_pixel_font.tres")
var checks:=0
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;print("FAIL: "+label)
func run() -> void:
	var output:=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/rivet_art_20261106/"):quit(2);return
	root.size=Vector2i(1280,960);root.content_scale_size=root.size
	var evidence:Array=[]
	for outfit in Content.OUTFITS:
		var board:=Control.new();root.add_child(board)
		var bg:=ColorRect.new();bg.color=Color("34444b");bg.size=root.size;board.add_child(bg)
		var row:=0
		for mode in ["legacy","raw","quiet","coarse","curated"]:
			var col:=0
			for action in ["idle","aim","recoil","reload_open","reload_seat","cooling"]:
				var viewport=load("res://redesign/weapon_actor.tscn").instantiate()
				var old=viewport.get_node("Actor");var replacement=Legacy.new() if mode=="legacy" else Carbine.new();replacement.name="Actor";replacement.material=old.material;replacement.texture_filter=old.texture_filter
				viewport.remove_child(old);old.free();viewport.add_child(replacement)
				if mode!="legacy":replacement.set_style(mode)
				board.add_child(viewport);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
				var actor=viewport.get_node("Actor");actor.set_outfit(outfit);actor.configure("single",action,1.0 if action=="recoil" else 0.0,0.4 if action=="reload_open" else 0.95,0.8 if action=="cooling" else 0.0)
				var picture:=TextureRect.new();picture.texture=viewport.get_texture();picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
				picture.position=Vector2(col*213,row*190);picture.size=Vector2(213,142);board.add_child(picture)
				var label:=Label.new();label.text="%s · %s"%[mode,action];label.position=picture.position+Vector2(8,153);label.add_theme_font_override("font",FONT);label.add_theme_font_size_override("font_size",13);board.add_child(label)
				var frame:Dictionary=Legacy.frame_for(outfit,"single",action) if mode=="legacy" else Actor.frame_for(outfit,"burst",action)
				var grip:Vector2=actor.registered_transform()*(Legacy.WEAPONS.single.grip if mode=="legacy" else Carbine.PROFILE.grip)
				check(grip.distance_to(Actor.FOOT+(frame.grip-frame.foot)*frame.scale)<0.01,"rear grip "+outfit+mode+action)
				check(Rect2(Vector2.ZERO,actor.body_texture().get_size()).encloses(frame.source),"body source "+outfit+mode+action)
				var projected:Vector2=actor.registered_muzzle(Vector2(122,500),0.12)
				check(projected.is_finite() and Rect2(0,0,1280,800).has_point(projected),"muzzle "+outfit+mode+action)
				if mode!="legacy" and frame.has("support"):
					var hand:Vector2=Actor.FOOT+(frame.support-frame.foot)*frame.scale
					var local:Vector2=actor.registered_transform().affine_inverse()*hand
					evidence.append({"outfit":outfit,"mode":mode,"action":action,"support_in_source":str(local)})
				for n in range(4):await process_frame
				await RenderingServer.frame_post_draw
				var occupied:Rect2i=viewport.get_texture().get_image().get_used_rect()
				check(occupied.position.x>0 and occupied.end.x<768 and occupied.end.y<=512 and occupied.size.y>300,"actor unclipped "+outfit+mode+action)
				if mode in ["legacy","raw","curated"] and action=="aim":viewport.get_texture().get_image().save_png(output.path_join(outfit+"_"+mode+"_aim.png"))
				if mode=="curated":
					var production=load("res://redesign/weapon_actor.tscn").instantiate();board.add_child(production)
					production.render_target_update_mode=SubViewport.UPDATE_ALWAYS
					var actual=production.get_node("Actor");actual.set_outfit(outfit);actual.configure("single",action,actor.recoil_amount,0.4 if action=="reload_open" else 0.95,actor.heat_amount)
					for n in range(4):await process_frame
					await RenderingServer.frame_post_draw
					check(production.get_texture().get_image().get_data()==viewport.get_texture().get_image().get_data(),"production is pixel-identical to selected art "+outfit+action)
					production.free()
				col+=1
			row+=1
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("poses_"+outfit+".png"))
		board.free();await process_frame
	FileAccess.open(output.path_join("contacts.json"),FileAccess.WRITE).store_string(JSON.stringify(evidence,"  "))
	print("RIVET ART POSES COMPLETE checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
