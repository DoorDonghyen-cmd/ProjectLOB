extends "res://tests/campaign_magazine_ui.gd"
const Preview=preload("res://redesign/samples/rivet_carbine_preview.gd")
const Content=preload("res://redesign/content.gd")
var recording:=false
var mode:=""
var current_outfit:=""
var seen:Dictionary={}
var frames:Array=[]
func post_draw() -> void:
	if not recording or not is_instance_valid(host) or not is_instance_valid(host.campaign_hud):return
	var board=host.campaign_hud.board;var actor=board.weapon_viewport.get_node("Actor")
	var key:="%s_%s_%s_%d_%d"%[current_outfit,mode,actor.pose_id,roundi(actor.recoil_amount*4),roundi(actor.reload_amount*2)]
	if seen.has(key):return
	seen[key]=true
	frames.append({"key":key,"pose":actor.pose_id,"muzzle":str(board.player_muzzle()),"body":actor.body_texture().get_size()})
	root.get_texture().get_image().save_png(output.path_join(key+".png"))
func run() -> void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/rivet_art_20261106/"):quit(2);return
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i.ZERO;root.content_scale_factor=1
	RenderingServer.frame_post_draw.connect(post_draw)
	for outfit in Content.OUTFITS:
		var reference:Dictionary={}
		var reference_save:Dictionary={}
		for variant in ["legacy","raw","curated","production"]:
			var c=Campaign.new();c.start("single",17,0,"balanced",4,outfit,true);check(c.enter(101),"actual first combat "+outfit+variant)
			await mount(c);host.save_enabled=false
			mode=variant;current_outfit=outfit
			var before:Dictionary=canonical(c.model.s)
			Preview.apply_style(host.campaign_hud.board,mode);await settle()
			check(canonical(c.model.s)==before,"art swap leaves complete model unchanged "+outfit+mode)
			host.campaign_hud.board.speed_scale=1.0;host.campaign_hud.board.reduced_feedback=false
			recording=true
			for action in ["Fire","Reload","Cool"]:await tap(action)
			recording=false
			var result:Dictionary=canonical(c.model.s)
			if variant=="legacy":reference=result
			else:check(result==reference,"same real actions give exact legacy model state "+outfit+mode)
			var save_path:=output.path_join("save_"+outfit+"_"+mode+".json")
			check(c.save(save_path)==OK,"actual isolated save "+outfit+mode)
			var saved:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(save_path))
			if variant=="legacy":reference_save=saved
			else:check(saved==reference_save,"exact legacy campaign combat and profile save "+outfit+mode)
			if variant=="production":
				var restored=Campaign.new();check(restored.restore(save_path),"production save restores "+outfit)
				check(canonical({"campaign":restored.s,"combat":JSON.parse_string(restored.model.serialized_state()),"profile":restored.profile})==saved,"restored campaign combat and profile are exact "+outfit)
			await capture("settled_"+outfit+"_"+mode)
		# Compare whole-scene pixel processing with the same settled state.
		if outfit=="work":
			for variant in ["quiet","coarse"]:
				Preview.apply_style(host.campaign_hud.board,variant);await settle();await capture("whole_scene_"+variant)
	RenderingServer.frame_post_draw.disconnect(post_draw)
	if is_instance_valid(host):host.free()
	var preview=load("res://redesign/samples/rivet_carbine_preview.tscn").instantiate();root.add_child(preview);await settle()
	host=preview.host
	for pair in [[KEY_F1,"legacy"],[KEY_F2,"raw"],[KEY_F3,"quiet"],[KEY_F4,"coarse"],[KEY_F5,"curated"]]:
		var before:Dictionary=canonical(host.model.s)
		for pressed in [true,false]:
			var key:=InputEventKey.new();key.keycode=pair[0];key.pressed=pressed;root.push_input(key,true);await process_frame
		await settle()
		check(preview.style_mode==pair[1],"public preview key "+str(pair[1]))
		check(canonical(host.model.s)==before,"preview key leaves model unchanged "+str(pair[1]))
	var old_outfit:String=host.model.s.outfit
	for pressed in [true,false]:
		var key:=InputEventKey.new();key.keycode=KEY_F6;key.pressed=pressed;root.push_input(key,true);await process_frame
	await settle()
	check(host.model.s.outfit!=old_outfit and host.model.s.gun=="single","F6 starts next outfit with Rivet rules")
	for size in [Vector2i(1280,800),Vector2i(1008,454)]:
		root.size=size;await settle();hud_bounds();await capture("preview_%dx%d"%[size.x,size.y])
	check(not host.save_enabled,"interactive preview cannot write ordinary campaign saves")
	preview.free()
	FileAccess.open(output.path_join("frames.json"),FileAccess.WRITE).store_string(JSON.stringify(frames,"  "))
	print("RIVET ART UI COMPLETE checks=%d failures=%d frames=%d"%[checks,failures.size(),frames.size()]);quit(0 if failures.is_empty() else 1)
