extends "res://tests/campaign_magazine_ui.gd"
const Actor = preload("res://redesign/weapon_actor.gd")
const Content = preload("res://redesign/content.gd")
var recording := false
var current_outfit := ""
var current_stage := "fire"
var feedback := "full"
var seen: Dictionary = {}
var frames: Array = []

func post_draw() -> void:
	if not recording or not is_instance_valid(host) or not is_instance_valid(host.campaign_hud): return
	var board=host.campaign_hud.board
	if not is_instance_valid(board.weapon_viewport): return
	var actor=board.weapon_viewport.get_node("Actor")
	var bucket := int(roundf(actor.recoil_amount*4.0))
	var key := "%s_%s_%s_%s_%d" % [current_outfit,feedback,current_stage,actor.pose_id,bucket]
	if seen.has(key): return
	seen[key]=true
	check(actor.outfit_grid_region().has_area(),"live G body grid "+key)
	frames.append({"outfit":current_outfit,"feedback":feedback,"stage":current_stage,"pose":actor.pose_id,"kick":actor.recoil_amount,"action":board.hero_action,"body":actor.body_texture().resource_path,"muzzle":str(board.player_muzzle()),"frame":str(actor.frame_for(actor.outfit_id,actor.gun_id,actor.pose_id))})
	if actor.pose_id == "recoil":
		var aim: Dictionary = Actor.frame_for(current_outfit,"amplifier","aim")
		var expected: Vector2 = Actor.FOOT + (aim.grip-aim.foot)*aim.scale
		check((actor.registered_transform()*Actor.WEAPONS.amplifier.grip).distance_to(expected)<0.01,"actual fire holds wrist "+key)
	root.get_texture().get_image().save_png(output.path_join("live_"+key+".png"))
	board.weapon_viewport.get_texture().get_image().save_png(output.path_join("actor_"+key+".png"))

func run() -> void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/spike_motion_20261106/"):quit(2);return
	Input.emulate_mouse_from_touch=true;root.size=Vector2i(1280,800);root.content_scale_size=Vector2i.ZERO;root.content_scale_factor=1
	RenderingServer.frame_post_draw.connect(post_draw)
	for outfit in Content.OUTFITS:
		var c=Campaign.new();c.start("amplifier",17,0,"balanced",4,outfit,true)
		check(c.enter(101),"actual first encounter starts "+outfit)
		await mount(c);host.save_enabled=false;host.campaign_hud.board.speed_scale=1.0;host.campaign_hud.board.reduced_feedback=false
		current_outfit=outfit;feedback="full";current_stage="fire";recording=true
		await tap("Fire");recording=false
		check(frames.any(func(f):return f.outfit==outfit and f.pose=="recoil"),"actual public firing renders recoil "+outfit)
		await capture("settled_"+outfit)
		for action in ["Reload","Cool"]:
			current_stage=action.to_lower();recording=true
			await tap(action);recording=false
		check(frames.any(func(f):return f.outfit==outfit and f.pose=="reload_open"),"actual reload keeps opening pose "+outfit)
		check(frames.any(func(f):return f.outfit==outfit and f.pose=="cooling"),"actual cooling keeps cooling pose "+outfit)
		# Reuse a real mid-encounter save; reduced feedback must remain a legal
		# fire path and cannot silently fall back to another costume.
		var restored=Campaign.new()
		var save_path:=output.path_join("mid_"+outfit+".json")
		check(c.save(save_path)==OK,"mid-encounter state saves "+outfit)
		check(restored.restore(save_path),"mid-encounter state restores "+outfit)
		await mount(restored);host.save_enabled=false
		host.campaign_hud.board.speed_scale=1.0;host.campaign_hud.board.reduced_feedback=true
		feedback="reduced";current_stage="fire";recording=true
		await tap("Fire");recording=false
		check(not frames.any(func(f):return f.outfit==outfit and f.feedback=="reduced" and f.pose=="recoil"),"reduced feedback avoids recoil body " + outfit)
	RenderingServer.frame_post_draw.disconnect(post_draw)
	if is_instance_valid(host):host.free()
	FileAccess.open(output.path_join("live.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"frames":frames},"  "))
	print("SPIKE MOTION LIVE COMPLETE checks=%d failures=%d frames=%d" % [checks,failures.size(),frames.size()]);quit(0 if failures.is_empty() else 1)
