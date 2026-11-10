extends "res://tests/pipe_map_ui.gd"
## Reuses map input/geometry checks against the current earned v4 campaign.
var captured_trail := false
var checks_current: Array=[]

func apply_recorded(c, step: Dictionary) -> bool:
	var accepted:=false
	match str(step.action):
		"fire":
			if int(step.get("rounds",0))>0:c.model.s.fire_heat_trial.rounds=int(step.rounds)
			accepted=c.model.fire()
		"reload":accepted=c.model.reload_magazine()
		"cool":accepted=c.model.cool_magazine()
		"enter":accepted=c.enter(int(step.id))
		"reward":accepted=c.reward(str(step.id),str(step.get("replace","")))
		"resolve":accepted=c.resolve(str(step.id),str(step.get("ammo","")),str(step.get("replace","")))
		"leave":accepted=c.leave()
		"buy":accepted=c.buy(int(step.id),str(step.get("replace","")))
		"equip":accepted=c.equip(str(step.id))
		"gate":accepted=c.gate(str(step.id),str(step.get("ammo","")))
		"gate_depart":accepted=c.depart_gate()
	if not check(accepted,"current earned command "+str(step.action)):return false
	c.sync_combat()
	if not check(c.save("user://material_route.json")==OK,"current replay normalizes through real save"):return false
	if step.has("phase"):check(c.s.phase==step.phase,"current recorded phase "+str(step.action))
	if step.has("credits"):check(int(c.s.credits)==int(step.credits),"current recorded money "+str(step.action))
	return true

func review_current(c) -> void:
	if captured_trail or int(c.s.region)!=0 or c.s.visited.size()<3:return
	captured_trail=true
	for extent in [Vector2i(1280,800),Vector2i(2340,1080)]:
		var copy=clone_map(c)
		await mount_map(copy,extent)
		var view=host.find_child("PipeMapScreen",true,false)
		var before:Dictionary=canonical({"campaign":copy.s,"combat":copy.model.s,"profile":copy.profile})
		var choice:int=int(copy.choices()[0].id)
		await tap_ui("map_node_"+str(choice))
		geometry("earned_trail_%dx%d"%[extent.x,extent.y])
		check(view.node("RunCredits").text=="%d Cr"%int(copy.s.credits),"separate actual wallet")
		check(not str(view.node("RunStatusBar").text).contains("Cr"),"wallet shown once")
		var graph=view.node("CityMap")
		check(graph.paths.any(func(p):return p.state=="trail"),"earned visited trail displayed")
		check(graph.paths.any(func(p):return p.state=="pick"),"selected outgoing route displayed")
		check(not graph.is_processing(),"instant motion keeps map flow idle")
		await tap_ui("MapKey")
		check(host.find_child("MapKeyContent",true,false)!=null,"authored legend opens")
		root.get_texture().get_image().save_png(output.path_join("legend_%dx%d.png"%[extent.x,extent.y]))
		await tap_ui("workspace_close")
		check(view.selected_id==choice,"legend preserves destination")
		await tap_ui("city_map_details")
		root.get_texture().get_image().save_png(output.path_join("details_%dx%d.png"%[extent.x,extent.y]))
		await tap_ui("workspace_close")
		check(canonical({"campaign":copy.s,"combat":copy.model.s,"profile":copy.profile})==before,"material/legend/details preserve full state and RNG")
		checks_current.append({"extent":[extent.x,extent.y],"visited":graph.visited,"choice":choice})
		# Also exercise normal/fast/instant without changing the map or save.
		graph.feedback_scale=1.0;graph.set_process(true)
		await settle_ui()
		check(graph.is_processing(),"normal motion keeps existing bounded flow")
		graph.feedback_scale=0.0;graph.set_process(false)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/maps/pipe_material_"):
		quit(2);return
	output=OS.get_environment("QA_OUTPUT_DIR");Input.emulate_mouse_from_touch=true
	if OS.get_environment("QA_MAP_LEGACY_ONLY")=="1":
		for version in [1,2,3]:
			var legacy=Campaign.new();legacy.start("single",17,0,"balanced",version);legacy.advance_departure(true)
			check(legacy.save()==OK,"legacy save v"+str(version))
			var restored=Campaign.new()
			check(restored.restore(),"legacy restore v"+str(version))
			check(canonical(restored.current_nodes())==canonical(legacy.current_nodes()),"legacy exact graph retained v"+str(version))
			await mount_map(restored,Vector2i(844,390))
			geometry("legacy_v"+str(version))
			var id:int=int(restored.choices()[-1].id)
			await tap_ui("map_node_"+str(id));await tap_ui("city_enter_"+str(id))
			check(int(restored.s.node)==id,"legacy legal move v"+str(version))
		if is_instance_valid(host):host.free();await settle_ui()
		FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"screens":visual_checks},"  "))
		print("MAP MATERIAL LEGACY COMPLETE checks=%d failures=%d"%[checks,failures.size()])
		quit(0 if failures.is_empty() else 1);return
	var folder:=ProjectSettings.globalize_path("res://../qa_runtime/boss_skills_20261106/heavy_elite")
	var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("balance.json")))
	var endpoint:Dictionary=report.endpoints[0]
	var c=Campaign.new()
	if not check(c.restore(folder.path_join("combat_heavy_17_r1_n101.json")),"current earned opening restores"):quit(1);return
	for index in range(endpoint.commands.size()):
		var step:Dictionary=endpoint.commands[index]
		if index==0 and step.action=="enter":continue
		if c.s.phase=="map":
			await review_earned_map(c)
			await review_shortcut(c)
			await review_gate_art(c)
			await review_current(c)
		if not apply_recorded(c,step):break
		if index%40==0:print("MAP MATERIAL ROUTE ",index,"/",endpoint.commands.size()," region=",c.s.region)
		if failures.size()>8:break
	check(c.s.phase=="won" and seen_regions.size()==5,"current earned route reaches all five gates")
	check(captured_trail,"actual trail and selected route reviewed")
	check(shortcut_checked,"current legal shortcut exercised")
	check(captured_gates.size()==2,"current first and final gate inputs exercised")
	var expected:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("Roaming/Godot/app_userdata/Last on Board - Core Redesign/city_probe.json")))
	check(canonical(c.s)==canonical(expected.campaign),"current campaign state exact original earned endpoint")
	check(canonical(c.model.s)==canonical(expected.combat),"current combat/history/RNG exact original earned endpoint")
	check(canonical(c.profile)==canonical(expected.profile),"current profile exact original earned endpoint")
	if is_instance_valid(host):host.free();await settle_ui()
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"regions":seen_regions.keys(),"screens":visual_checks,"current_cases":checks_current},"  "))
	print("MAP MATERIAL UI COMPLETE checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
