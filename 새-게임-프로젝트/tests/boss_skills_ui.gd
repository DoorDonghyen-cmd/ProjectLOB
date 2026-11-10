extends "res://tests/leader_patterns_ui.gd"
const Ranged = preload("res://redesign/ranged.gd")

func select_prefix(count: int) -> void:
	var hud = host.campaign_hud
	hud.node("MagazineHousing").scroll_horizontal = 0; await settle()
	var first: Control = hud.node("Select0"); var last: Control = hud.node("Select%d" % (count-1))
	var origin: Vector2 = first.get_global_transform_with_canvas()*(first.size*0.5)
	var target: Vector2 = last.get_global_transform_with_canvas()*(last.size*0.5)
	var press := InputEventScreenTouch.new(); press.index=0; press.position=origin; press.pressed=true
	root.push_input(press,true); await process_frame
	for position in [origin+Vector2(16,0), target]:
		var drag := InputEventScreenDrag.new(); drag.index=0; drag.position=position; drag.relative=position-origin
		root.push_input(drag,true); await process_frame
	press=InputEventScreenTouch.new(); press.index=0; press.position=target; press.pressed=false
	root.push_input(press,true); await settle()
	check(hud.current_budget()==count,"public prefix gesture selects requested count")

func action(c, name: String, rounds: int = 0) -> void:
	if name=="fire": await select_prefix(rounds if rounds>0 else host.campaign_hud.maximum_budget())
	var expected = Model.new(); expected.s = c.model.s.duplicate(true)
	var accepted := false
	match name:
		"fire": accepted=expected.fire()
		"reload": accepted=expected.reload_magazine()
		"cool": accepted=expected.cool_magazine()
	check(accepted,"same public command is legal in the actual resolver")
	await tap({"fire":"Fire","reload":"Reload","cool":"Cool"}[name])
	if expected.s.phase=="ready":
		check(canonical(c.model.s)==canonical(expected.s),"full live state and RNG match after "+name)
	else: check(c.model.s.phase==expected.s.phase,"live completion matches the actual resolver")

func run() -> void:
	output=OS.get_environment("QA_OUTPUT_DIR"); Input.emulate_mouse_from_touch=true
	if not output.replace("\\","/").contains("/qa_runtime/boss_skills_20261106/"): quit(2); return
	var gate_file: String=ProjectSettings.globalize_path("res://../qa_runtime/boss_skills_20261106/single/combat_single_17_r1_n802.json")
	var mother_file: String=ProjectSettings.globalize_path("res://../qa_runtime/boss_skills_20261106/heavy_elite/combat_heavy_17_r3_n20902.json")
	var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../qa_runtime/boss_skills_20261106/heavy_elite/balance.json")))
	var path: Array=[]
	for entry in route.battles:
		if entry.region==3 and entry.boss: path=entry.path
	for extent in [Vector2i(1280,800),Vector2i(1008,454),Vector2i(2340,1080)]:
		root.size=extent; root.content_scale_factor=1; root.content_scale_size=Vector2i.ZERO
		var c=Campaign.new(); check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(gate_file))),"earned new first-boss snapshot restores")
		await mount(c); hud_bounds()
		await tap("enemy_info_0")
		check(host.campaign_hud.node("DetailBody").text.contains("2연발"),"enemy detail discloses the two-shot sequence")
		await capture("salvo_detail_%dx%d" % [extent.x,extent.y]); await tap("CloseDetail")
		await action(c,"reload"); await capture("salvo_warning_%dx%d" % [extent.x,extent.y])
		await action(c,"reload")
		check(c.model.s.enemies[0].ranged_phase=="burst" and Ranged.active(c.model.s).size()==1,"first launch leaves a public second-shot warning")
		check(host.campaign_hud.board.challenge_intent(0).contains("연속 발사"),"native board shows the second-shot warning")
		await capture("salvo_first_%dx%d" % [extent.x,extent.y])
		await action(c,"reload")
		check(Ranged.active(c.model.s).size()==2 and host.campaign_hud.board.projectiles.filter(func(p):return p.hp>0).size()==2,"both pressure shots remain visible after second launch")
		var board=host.campaign_hud.board; var active: Array=Ranged.active(c.model.s)
		check(not board.projectile_label_rect(active[0]).intersects(board.projectile_label_rect(active[1])),"two projectile labels do not overlap")
		await capture("salvo_two_%dx%d" % [extent.x,extent.y])
		var resumed=Campaign.new(); check(resumed.restore() and canonical(resumed.model.s)==canonical(c.model.s),"both stable projectile IDs and pending cycle resume exactly")
		# The earned magazine starts with a support round and escorts may be closer
		# than the missiles. Resolve the real two-round response, not an assumed
		# one-round intercept; isolated interception is covered by the rules suite.
		await action(c,"fire",2)
		await capture("salvo_response_%dx%d" % [extent.x,extent.y])
		c=Campaign.new(); check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(mother_file))),"earned new mother snapshot restores")
		await mount(c); hud_bounds()
		check(host.campaign_hud.board.challenge_intent(0).contains("증원 3턴"),"native mother warning states the call clock")
		await capture("call_warning_%dx%d" % [extent.x,extent.y])
		var arrived := false
		for command in path:
			await action(c,str(command.action),int(command.get("rounds",0)))
			if c.model.s.enemies.any(func(e):return e.get("brood_reserve",false)):
				arrived=true; break
		check(arrived and c.model.s.enemies[0].summon_done,"actual public winning route triggers the finite reinforcement call")
		check(c.model.alive_count()<=4 and c.model.s.encounter_total==7,"summon keeps finite encounter size and living cap")
		await capture("call_arrived_%dx%d" % [extent.x,extent.y])
		resumed=Campaign.new(); check(resumed.restore() and canonical(resumed.model.s)==canonical(c.model.s),"call progress and deployed/reserved monsters resume exactly")
	if is_instance_valid(host): host.free()
	FileAccess.open(output.path_join("ui.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("BOSS SKILLS COMPLETE checks=%d failures=%d" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
