extends "res://tests/challenge_ui_runner.gd"
const Hunters=preload("res://redesign/garden_hunters.gd")

func visible_hunters(label: String) -> void:
	await settle()
	var view=screen.battle_view
	check(view.get_script().resource_path.ends_with("garden_battle_view.gd"),"production garden view")
	var frame:=Rect2(Vector2.ZERO,view.size)
	for i in view._alive_indices():
		check(frame.encloses(view.concept_rect(i)),"sprite fits "+label+"/"+str(i))
		check(frame.encloses(view.enemy_plaque(i)),"HUD fits "+label)
		check(not view.concept_rect(i).intersects(view.enemy_plaque(i)),"body clear of own HUD "+label)
		for j in view._alive_indices():
			if i!=j:check(not view.enemy_plaque(i).intersects(view.enemy_plaque(j)),"HUD columns distinct "+label)
		if Hunters.active(view.enemies[i]):
			check(view.hunter_sprites.has(i) and view.hunter_sprites[i].visible,"authored pose visible")
			check(frame.encloses(view.intent_rect(i)),"intent fits "+label)
			check(view.challenge_intent(i).contains("숨고르기" if view.enemies[i].recovering else "도약"),"accurate intent")
	print("FRAME ",label," actor=",view.concept_rect(0)," hud=",view.enemy_plaque(0))
	await capture(label)

func watch_leap(label: String,skip: bool=false) -> void:
	screen.presentation_speed=1.0
	await begin_touch("reload")
	var view=screen.battle_view
	var preparation:=false
	var launch:=false
	var started:=Time.get_ticks_msec()
	while screen.busy and Time.get_ticks_msec()-started<15000:
		var name:=""
		if view.anticipating>=0 and not preparation:preparation=true;name=label+"_anticipation"
		if not view.leaping.is_empty() and not launch:launch=true;name=label+"_leap"
		if not name.is_empty():
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join(name+".png"))==OK,"motion capture")
			if skip:await begin_touch("skip_animation")
		await process_frame
	check(preparation and (launch or skip),"prepare then launch")
	check(not screen.busy and view.anticipating==-1 and view.leaping.is_empty(),"animation completes and clears")
	check(screen.last_presentation.shown_enemies==screen.model.s.enemies,"visual state matches actual result")
	screen.presentation_speed=0.06;await settle()

func finish_check() -> void:
	# One HP is exclusively a presentation fixture; not used for difficulty evidence.
	screen._debug_garden_background(2,"boss")
	screen.model.s.enemies=[screen.model.s.enemies[0]];screen.model.s.reinforcements=[]
	screen.model.s.encounter_total=1;screen.model.s.deployed=1;screen.model.s.enemies[0].hp=1
	screen.redraw();await settle()
	var damaging: Array=screen.model.s.hand.filter(func(id):return preload("res://redesign/content.gd").damage(str(id),screen.model.s)>0)
	check(not damaging.is_empty(),"fixture has a damaging round")
	await tap("load_"+str(damaging[0]));await tap("confirm")
	screen.presentation_speed=0.7;await begin_touch("fire")
	var view=screen.battle_view
	var captured:=false
	var zoomed:=false
	var started:=Time.get_ticks_msec()
	while screen.busy and Time.get_ticks_msec()-started<15000:
		if view.finish_active:zoomed=true
		if not captured and not view.damage_popups.is_empty():
			check(is_instance_valid(view.readout_layer) and view.readout_layer.z_index==1,"damage above sprites")
			for item in view.damage_popup_layout():check(Rect2(Vector2.ZERO,view.size).encloses(item.bounds),"finish number fits")
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join("boss_finish.png"));captured=true
		await process_frame
	check(captured and zoomed and not screen.busy,"boss impact and finish complete")
	check(screen.campaign.s.phase=="reward","boss reward follows finish")
	screen.presentation_speed=0.06;await settle()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/garden_live/"):quit(1);return
	screen=load("res://redesign/main.tscn").instantiate();screen.save_enabled=false;screen.presentation_speed=0.06
	root.add_child(screen);await settle()
	screen._developer();await settle()
	for key in ["debug_garden_elite","debug_garden_boss"]:check(screen.find_child(key,true,false)!=null,"preview button "+key)
	screen.find_child("debug_garden_boss",true,false).pressed.emit();await settle()
	check(screen.debug_session and screen.campaign.s.roster_version==9,"isolated current preview")
	for resolution in [Vector2i(1008,630),Vector2i(1280,800),Vector2i(1440,630)]:
		root.size=resolution;await settle()
		for kind in ["elite","boss"]:
			screen._debug_garden_background(2,kind);await visible_hunters("%s_idle_%d"%[kind,resolution.x])
			await begin_touch("enemy_info_0");await settle()
			check(screen.find_child("EnemyDetails",true,false)!=null,"touch details opens")
			screen._close_workspace();await settle()
			await replay_reload();check(screen.battle_view.hunter_frame(0)==1,"preparation pose stays until action")
			await visible_hunters("%s_prepared_%d"%[kind,resolution.x])
			await replay_reload();await visible_hunters("%s_recovery_%d"%[kind,resolution.x])
			var distance: int=screen.model.s.enemies[0].distance
			await replay_reload();check(screen.model.s.enemies[0].distance==distance,"recovery holds position")
	root.size=Vector2i(1280,800);await settle()
	for kind in ["elite","boss"]:
		screen._debug_garden_background(2,kind);await settle();await replay_reload();await watch_leap(kind,kind=="elite")
	await finish_check()
	screen.preferences.data.motion="instant"
	screen._debug_garden_background(2,"boss");await settle();await replay_reload();await replay_reload()
	check(screen.model.s.enemies[0].recovering and screen.battle_view.hunter_frame(0)==0,"reduced motion retains accurate recovery")
	check(not screen.save_enabled,"user save disabled throughout QA")
	print("GARDEN LIVE UI COMPLETE checks=%d failures=%d"%[checks,failures])
	screen.queue_free();await process_frame;quit(0 if failures==0 else 1)
