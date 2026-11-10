extends SceneTree
const Campaign=preload("res://redesign/campaign.gd")
const Content=preload("res://redesign/content.gd")
var host
var checks:=0
var failures: Array=[]
var records: Array=[]
var output: String
func _initialize()->void:run.call_deferred()
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok: failures.append(label);print("FAIL: "+label)
func settle()->void:
	for i in range(10):await process_frame
func capture(label: String)->void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
func scale_state()->Array:
	return [root.content_scale_mode,root.content_scale_factor,root.content_scale_size,root.get_visible_rect().size]
func mount(outfit: String,gun: String)->void:
	if is_instance_valid(host):host.free()
	host=load("res://redesign/main.tscn").instantiate();host.save_enabled=false
	root.add_child(host)
	var c=Campaign.new();c.start(gun,731042,0,"balanced",3,outfit,true);c.advance_departure(true);c.enter(101)
	host.campaign=c;host.model=c.model;host.page="run";host.redraw()
	await settle()
func run()->void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/playtest_20261102/"):quit(2);return
	output=OS.get_environment("QA_OUTPUT_DIR")
	Input.emulate_mouse_from_touch=true
	root.size=Vector2i(2016,908)
	await settle()
	var original:=scale_state()
	for cycle in range(3):
		await mount("carrier","single")
		var during:=scale_state()
		host._to_menu();await settle()
		var after:=scale_state()
		print("SCALE ",original," -> ",during," -> ",after)
		records.append({"cycle":cycle,"before":str(original),"during":str(during),"after":str(after)})
		check(after==original,"window scale restored cycle "+str(cycle))
	# Track the actual selected outfit on every frame of public reload playback.
	host.free();host=null
	root.size=Vector2i(1280,800);root.content_scale_factor=1.0
	for outfit in Content.OUTFITS:
		for gun in Content.GUNS:
			await mount(outfit,gun)
			var ui=host.campaign_hud
			ui.board.speed_scale=0.35
			var button: Button=ui.node("Reload")
			check(not button.disabled,"reload available "+outfit+gun)
			button.pressed.emit()
			var observed: Dictionary={}
			var started:=Time.get_ticks_msec()
			while ui.busy and Time.get_ticks_msec()-started<8000:
				await process_frame
				var actor=ui.board.weapon_viewport.get_node("Actor")
				check(actor.outfit_id==outfit,"reload retains outfit "+outfit+gun+actor.pose_id)
				var key: String=actor.pose_id+":"+actor.body_texture().resource_path
				if not observed.has(key):
					observed[key]=true
					if gun=="single" and outfit in ["carrier","work","scout"]:await capture(outfit+"_"+actor.pose_id)
			check(not ui.busy,"reload finishes "+outfit+gun)
			records.append({"outfit":outfit,"gun":gun,"poses":observed.keys()})
			print("OUTFIT ",outfit," ",gun," ",observed.keys())
	if is_instance_valid(host):host.free()
	var file:=FileAccess.open(output.path_join("result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"  "));file.close()
	print("PRESENTATION COMPLETE checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
