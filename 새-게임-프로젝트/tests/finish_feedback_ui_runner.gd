extends "res://tests/build_payoff_ui_runner.gd"
const Readout = preload("res://redesign/damage_readout.gd")
var errors: Dictionary={}
var measured: Dictionary={}
var snapshots: Dictionary={}

func fixture(kind: String) -> void:
	var ids: Array=["basic_p2"]
	if kind=="heavy": ids=["basic_p5","charge_hot","charge"]
	if kind=="multi": ids=["basic_p3","charge"]
	await setup_hand(ids)
	if kind!="production": screen.campaign=null
	screen.model.s.gun="burst"
	screen.model.s.enemies=[Data._enemy(["runner",40,0,1,18])]
	screen.model.s.reinforcements=[]
	if kind in ["kill","finish","reserve","burn"]: screen.model.s.enemies[0].hp=1
	if kind=="kill": screen.model.s.enemies.append(Data._enemy(["wall",40,0,1,25]))
	if kind=="reserve": screen.model.s.reinforcements=[Data._enemy(["runner",10,0,1,30])]
	if kind=="burn": screen.model.s.enemies[0].burn=1
	if kind=="production":
		var node:={"id":101,"region":0,"floor":1,"kind":"combat","name":"QA","elite":false}
		var pack:=Data.encounter_pack(node,731042,"burst",0,0,4)
		screen.model.s.enemies=pack.active.duplicate(true)
		for i in range(screen.model.s.enemies.size()): screen.model.s.enemies[i].hp=1 if i==0 else 0
		screen.campaign.s.gun="burst"
	if kind=="multi":
		screen.model.s.equipped_parts=["siege_drive"]
		screen.model.s.engine.levels.siege_drive=2
		screen.model.s.enemies=[]
		for distance in [18,22,26]: screen.model.s.enemies.append(Data._enemy(["runner",2,0,1,distance]))
	screen.model.s.encounter_total=screen.model.s.enemies.size()+screen.model.s.reinforcements.size()
	screen.model.s.deployed=screen.model.s.enemies.size()
	screen.model.assign_opening_lanes()
	screen.hand_layout_key="";screen.redraw();await settle()
	if kind!="burn":
		for id in ids: await tap("load_"+id)
		await tap("confirm")

func exercise(kind: String, expected_finish: bool, skip: bool=false) -> void:
	await fixture(kind)
	print("FINISH CASE ",kind," ",root.size," ",screen.preferences.data.motion," skip=",skip)
	check(screen.battle_view.visual_clock_scale()==1.0,"fresh battle has no slow clock")
	if kind=="production": check(screen.battle_view.get_script().resource_path=="res://redesign/residential_battle_view.gd","production residential adapter")
	var oracle=load("res://redesign/model.gd").new()
	oracle.s=screen.model.s.duplicate(true)
	check(oracle.reload_magazine() if kind=="burn" else oracle.fire(),"fixture resolves "+kind)
	var view=screen.battle_view
	var start:=Time.get_ticks_msec()
	await begin_touch("reload" if kind=="burn" else "fire")
	var saw_finish:=false
	var slow_frames:=0
	var finish_start:=0
	var finish_ms:=0
	var max_font:=0
	var approach_frames:=0
	var impact_zoom:=1.0
	var did_skip:=false
	var previous_clock: float=view.actor_clock
	while screen.busy and Time.get_ticks_msec()-start<15000:
		if not is_equal_approx(Engine.time_scale,1.0): errors["global time changed"]=true
		var popups: Array=view.damage_popup_layout()
		for popup in popups:
			var rect:Rect2=popup.bounds
			if not Rect2(Vector2.ZERO,view.size).encloses(rect): errors["outside "+kind+str(root.size)]=true
			for target in view._alive_indices():
				if rect.intersects(view.enemy_plaque(target)) or rect.intersects(view.distance_label_rect(target)): errors["HUD overlap "+kind]=true
			for other in popups:
				if other.entry.target!=popup.entry.target and rect.intersects(other.bounds): errors["number overlap "+kind]=true
			if popup.entry.amount>0: max_font=maxi(max_font,popup.font_size)
		if view.finish_active:
			if not view.bullet.is_empty():
				approach_frames+=1
				if not popups.is_empty(): errors["premature damage text "+kind]=true
				if view._alive_indices().is_empty(): errors["premature death "+kind]=true
			elif not popups.is_empty():
				impact_zoom=maxf(impact_zoom,view.finish_camera().get_scale().x)
			if view.finish_progress>view.FINISH_RELEASE+0.02 and view.pulse<0.99: errors["zoom out before death completes "+kind]=true
			if finish_start==0: finish_start=Time.get_ticks_msec()
			saw_finish=true
			finish_ms=Time.get_ticks_msec()-finish_start
			if view.finish_progress<0.5 and view.actor_clock>=previous_clock and view.get_process_delta_time()>0:
				if (view.actor_clock-previous_clock)/view.get_process_delta_time()<0.5: slow_frames+=1
			if skip and not did_skip:
				await begin_touch("skip_animation")
				did_skip=true
				if not screen.busy: break
		var key:="%s_%d"%[kind,root.size.x]
		var shot_visible: bool=popups.any(func(p): return int(p.entry.amount)>0)
		var moment: bool=view.finish_active and view.finish_progress>0.18 and view.finish_progress<0.45 if expected_finish else view.pulse>0.15 and view.pulse<0.45
		if shot_visible and moment and not snapshots.has(key) and not skip and not view.reduced_feedback:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join(key+".png"))
			snapshots[key]=true
		if kind=="finish" and root.size.x==1008 and view.finish_active:
			for threshold in [0.1,0.3,0.6,0.85]:
				var stage:="finish_stage_%02d"%int(threshold*100)
				if view.finish_progress>=threshold and not snapshots.has(stage):
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join(stage+".png"))
					snapshots[stage]=true
		previous_clock=view.actor_clock
		await process_frame
	check(not screen.busy,"action ends "+kind)
	check(screen.model.s==oracle.s,"resolved state and RNG unchanged "+kind)
	check(saw_finish==expected_finish,"terminal-only finish "+kind)
	var count: int=screen.last_presentation.events.filter(func(event): return event.kind=="finisher").size()
	check(count==(1 if expected_finish else 0),"one finish per completed encounter "+kind)
	check(not is_instance_valid(screen.battle_view) or (not screen.battle_view.finish_active and screen.battle_view.visual_clock_scale()==1.0),"local clock restored or finished view removed "+kind)
	if expected_finish and not skip:
		if kind!="burn":
			check(approach_frames>2,"slow approach starts before lethal impact "+kind)
			check(impact_zoom>1.01,"damage shown after camera has approached "+kind)
			var events: Array=screen.last_presentation.events
			var approach_index: int=events.find(events.filter(func(event): return event.kind=="finish_approach")[0]) if events.any(func(event): return event.kind=="finish_approach") else -1
			check(approach_index>=0 and events.slice(approach_index+1).any(func(event): return event.kind=="impact"),"approach precedes actual impact event "+kind)
		check(slow_frames>2,"actor clock visibly slows "+kind)
		check(finish_ms>=2000*screen.presentation_speed and finish_ms<3000*screen.presentation_speed,"finish lasts 2–3 seconds at normal speed "+kind)
		print("FINISH TIMING ",kind," ",root.size," ",screen.preferences.data.motion," ",finish_ms,"ms")
	if skip: check(did_skip and finish_ms<350,"skip remains responsive")
	measured["%s_%d"%[kind,root.size.x]]=max_font
	await settle()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/finish_feedback/"): quit(1);return
	screen=load("res://redesign/main.tscn").instantiate()
	screen.save_enabled=false;screen.presentation_speed=1.0
	root.add_child(screen);await settle()
	screen.preferences.data.motion="normal"
	for resolution in [Vector2i(1008,630),Vector2i(1280,800),Vector2i(1440,630)]:
		root.size=resolution;await settle()
		for kind in ["plain","heavy","kill","finish","reserve","multi","burn"]:
			await exercise(kind,kind in ["finish","multi","burn"])
		check(measured["kill_%d"%resolution.x]>measured["plain_%d"%resolution.x]*1.35,"lethal number is substantially larger")
		check(measured["heavy_%d"%resolution.x]>measured["plain_%d"%resolution.x],"heavy damage larger than normal")
	await exercise("finish",true,true)
	screen.preferences.data.motion="fast";screen.presentation_speed=0.55
	await exercise("finish",true)
	screen.preferences.data.motion="instant";screen.presentation_speed=0.05
	await exercise("finish",false)
	var intercepted:=Readout.entry({"target":10000,"damage":3,"hp":0,"intercept":true})
	check(not intercepted.kill and intercepted.number=="요격","projectile interception is not a kill")
	screen.preferences.data.motion="normal";screen.presentation_speed=1.0
	root.size=Vector2i(1008,630);await settle()
	await exercise("production",true)
	check(screen.campaign.s.phase=="reward","finish flows into actual campaign reward")
	for error in errors: check(false,error)
	check(errors.is_empty(),"bounds and time intact across all observed frames")
	print("NUMBER SIZES ",JSON.stringify(measured))
	print("FINISH FEEDBACK UI COMPLETE checks=%d failures=%d"%[checks,failures])
	screen.queue_free();await process_frame
	quit(0 if failures==0 else 1)
