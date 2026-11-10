extends "res://tests/challenge_ui_runner.gd"
const House=preload("res://redesign/noble_house.gd")

func visible_house(label: String) -> void:
	await settle()
	var view=screen.battle_view
	check(not screen.main_scroll.get_v_scroll_bar().visible and not screen.main_scroll.get_h_scroll_bar().visible,"screen stays within viewport "+label)
	check(view.get_script().resource_path.ends_with("noble_battle_view.gd"),"production noble view")
	var bounds:=Rect2(Vector2.ZERO,view.size)
	for i in view._alive_indices():
		check(view.house_sprites.has(i) and view.house_sprites[i].visible,"actual authored actor "+label)
		check(bounds.encloses(view.concept_rect(i)),"sprite fits "+label+"/"+str(i))
		check(bounds.encloses(view.enemy_plaque(i)),"HUD fits "+label)
		check(absf(view.enemy_plaque(i).get_center().x-view.enemy_feet(i).x)<2.0,"HP remains centered above its actor "+label)
		check(not view.concept_rect(i).intersects(view.enemy_plaque(i)),"own HP clear of body "+label)
		for j in view._alive_indices():
			if i!=j:check(not view.enemy_plaque(i).intersects(view.enemy_plaque(j)),"HUD columns separate "+label)
		if House.shielded(view.enemies[i]):
			check(bounds.encloses(view.intent_rect(i)),"intent in board "+label)
			check(view.house_frame(i)==(1 if view.enemies[i].barrier==0 else 0),"pose agrees with shield "+label)
	print("FRAME ",label," actor=",view.concept_rect(0)," hud=",view.enemy_plaque(0))
	await capture(label)

func single_leader(kind: String="boss") -> void:
	screen._debug_noble_background(2,kind)
	# Presentation fixture only: remove escorts to observe the leader without RNG.
	screen.model.s.enemies=[screen.model.s.enemies[0]];screen.model.s.reinforcements=[]
	screen.model.s.enemies[0].distance=40
	screen.model.s.encounter_total=1;screen.model.s.deployed=1
	screen.redraw();await settle()

func watch_break() -> void:
	await single_leader()
	screen.model.s.enemies[0].barrier=1
	screen.redraw();await settle()
	var ammo=screen.model.s.hand.filter(func(id):return Data.Ammo.damage(str(id),screen.model.s)>0)
	check(not ammo.is_empty(),"earned hand contains a direct attack")
	await tap("load_"+str(ammo[0]));await tap("confirm")
	screen.presentation_speed=1.0;await begin_touch("fire")
	var view=screen.battle_view
	var seen:=false
	var started:=Time.get_ticks_msec()
	while screen.busy and Time.get_ticks_msec()-started<15000:
		if view.break_target>=0 and not seen:
			seen=true
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join("boss_shield_break.png"))
		await process_frame
	check(seen and not screen.busy,"real impact shows shield breaking")
	check(screen.last_presentation.shown_enemies==screen.model.s.enemies,"visual result equals resolver")
	screen.presentation_speed=0.06;await visible_house("boss_after_break")

func watch_rearm(kind: String, skip: bool=false) -> void:
	await single_leader(kind)
	House.strip(screen.model.s.enemies[0],9);screen.model.s.enemies[0].exposure_left=1
	screen.redraw();await settle()
	await visible_house(kind+"_warning")
	screen.presentation_speed=1.0;await begin_touch("reload")
	var view=screen.battle_view
	var seen:=false
	var started:=Time.get_ticks_msec()
	while screen.busy and Time.get_ticks_msec()-started<15000:
		if not view.rearming.is_empty() and not seen:
			seen=true
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join(kind+"_rearm.png"))
			if skip: await begin_touch("skip_animation")
		await process_frame
	check(seen and not screen.busy and view.rearming.is_empty(),"rearm pose completes/skip clears")
	check(screen.last_presentation.shown_enemies==screen.model.s.enemies,"multi-turn presentation equals resolver")
	screen.presentation_speed=0.06

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/noble_live/"):quit(1);return
	screen=load("res://redesign/main.tscn").instantiate();screen.save_enabled=false;screen.presentation_speed=0.06
	root.add_child(screen);await settle()
	screen._developer();await settle()
	for key in ["debug_noble_normal","debug_noble_elite","debug_noble_boss"]:check(screen.find_child(key,true,false)!=null,"developer preview "+key)
	screen.find_child("debug_noble_boss",true,false).pressed.emit();await settle()
	check(screen.debug_session and screen.campaign.s.roster_version==10,"isolated current roster preview")
	for resolution in [Vector2i(1008,630),Vector2i(1280,900),Vector2i(1440,630)]:
		root.size=resolution;await settle()
		for kind in ["normal","elite","boss"]:
			screen._debug_noble_background(1 if kind=="normal" else 2,"" if kind=="normal" else kind)
			await visible_house("%s_closed_%d"%[kind,resolution.x])
			await begin_touch("enemy_info_0");await settle()
			check(screen.find_child("EnemyDetails",true,false)!=null,"touch opens details")
			screen._close_workspace();await settle()
			for enemy in screen.model.s.enemies:
				if House.shielded(enemy):House.strip(enemy,9)
			screen.redraw();await visible_house("%s_exposed_%d"%[kind,resolution.x])
	root.size=Vector2i(1280,900);await settle()
	await watch_break();await watch_rearm("boss");await watch_rearm("elite",true)
	screen.preferences.data.motion="instant"
	await single_leader();House.strip(screen.model.s.enemies[0],9);screen.model.s.enemies[0].exposure_left=1
	screen.redraw();await settle();await replay_reload()
	check(screen.model.s.enemies[0].barrier==4 and screen.battle_view.house_frame(0)==0,"reduced motion retains current shield")
	# No user save is written, including the developer transition.
	check(not screen.save_enabled,"isolated user save remains disabled")
	print("NOBLE LIVE UI COMPLETE checks=%d failures=%d"%[checks,failures])
	screen.queue_free();await process_frame;quit(0 if failures==0 else 1)
