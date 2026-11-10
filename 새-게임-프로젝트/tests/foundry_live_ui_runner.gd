extends "res://tests/challenge_ui_runner.gd"
const Workers = preload("res://redesign/foundry_workers.gd")

func visible_workers(label: String) -> void:
	await settle()
	var view=screen.battle_view
	check(view.get_script().resource_path.ends_with("foundry_battle_view.gd"),"production foundry view")
	var frame:=Rect2(Vector2.ZERO,view.size)
	for i in view._alive_indices():
		check(Workers.active(view.enemies[i]),"current machine identity")
		check(view.machine_sprites.has(i) and view.machine_sprites[i].visible,"authored sprite visible")
		check(frame.encloses(view.concept_rect(i)),"sprite fits "+label+"/"+str(i))
		check(frame.encloses(view.enemy_plaque(i)),"HUD fits "+label)
		check(not view.concept_rect(i).intersects(view.enemy_plaque(i)),"body clear of own HUD "+label)
		for j in view._alive_indices():
			if i!=j:check(not view.enemy_plaque(i).intersects(view.enemy_plaque(j)),"HUD columns distinct "+label)
	if Workers.winding(view.enemies[0]):
		check(frame.encloses(view.intent_rect(0)),"intent fits "+label)
		check(view.challenge_intent(0).contains("정지" if view.enemies[0].recovering else "축압"),"accurate state intent")
	print("FRAME ",label," board=",view.size," actor=",view.concept_rect(0)," hud=",view.enemy_plaque(0))
	await capture(label)

func watch_reload(label: String, skip: bool=false) -> void:
	await settle()


	screen.presentation_speed=1.0
	await begin_touch("reload")
	var view=screen.battle_view
	var seen_charge:=false
	var seen_step:=false
	var seen_recoil:=false
	var started:=Time.get_ticks_msec()
	while screen.busy and Time.get_ticks_msec()-started<15000:
		var name:=""
		if view.anticipating>=0 and not seen_charge:
			seen_charge=true;name=label+"_anticipation"
		if not view.surge_targets.is_empty() and not seen_step:
			seen_step=true;name=label+"_step"
		if view.firing_machine>=0 and not seen_recoil:
			seen_recoil=true;name=label+"_recoil"
		if not name.is_empty():
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join(name+".png"))==OK,"motion capture "+name)
			if skip:await begin_touch("skip_animation")
		await process_frame
	check(not screen.busy,"motion completes")
	check(screen.last_presentation.shown_enemies==screen.model.s.enemies,"final visual matches actual model")
	check(view.anticipating==-1 and view.surge_targets.is_empty() and view.firing_machine==-1,"motion flags clear")
	if label.contains("surge"):check(seen_charge and (seen_step or skip),"charge followed by step")
	if label.contains("pressure"):check(seen_recoil,"projectile launch uses recoil")
	screen.presentation_speed=0.06
	await settle()

func lethal_presentation() -> void:
	# Deliberately tiny encounter checks compositing, not combat difficulty.
	screen._debug_foundry("single","boss")
	screen.model.s.enemies=[screen.model.s.enemies[0]]
	screen.model.s.reinforcements=[]
	screen.model.s.encounter_total=1;screen.model.s.deployed=1
	screen.model.s.enemies[0].hp=1;screen.model.s.enemies[0].def=0
	screen.redraw();await settle()
	await tap("load_"+str(screen.model.s.hand[0]));await tap("confirm")
	screen.presentation_speed=0.7
	await begin_touch("fire")
	var view=screen.battle_view
	var captured:=false
	var zoomed:=false
	var started:=Time.get_ticks_msec()
	while screen.busy and Time.get_ticks_msec()-started<15000:
		if view.finish_active:zoomed=true
		if not captured and not view.damage_popups.is_empty():
			check(is_instance_valid(view.readout_layer) and view.readout_layer.z_index==1,"damage renders above authored sprites")
			for item in view.damage_popup_layout():check(Rect2(Vector2.ZERO,view.size).encloses(item.bounds),"lethal number fits")
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join("boss_finish.png"))
			captured=true
		await process_frame
	check(captured and zoomed and not screen.busy,"boss impact and finish complete")
	check(screen.campaign.s.phase=="reward","real boss reward follows finish")
	screen.presentation_speed=0.06;await settle()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/foundry_live/"):quit(1);return
	screen=load("res://redesign/main.tscn").instantiate()
	screen.save_enabled=false;screen.presentation_speed=0.06
	root.add_child(screen);await settle()
	screen._developer();await settle()
	for key in ["debug_foundry_elite","debug_foundry_boss"]:
		check(screen.find_child(key,true,false)!=null,"direct preview button "+key)
	screen.find_child("debug_foundry_boss",true,false).pressed.emit();await settle()
	check(screen.debug_session and screen.campaign.s.roster_version==8,"isolated current preview")
	for resolution in [Vector2i(1008,630),Vector2i(1280,800),Vector2i(1440,630)]:
		root.size=resolution;await settle()
		screen._debug_foundry("single");await settle()
		check(screen.campaign.enter(int(screen.campaign.choices()[0].id)),"current normal encounter via map")
		screen.redraw();await visible_workers("normal_%d"%resolution.x)
		for kind in ["elite","boss"]:
			screen._debug_foundry("single",kind);await visible_workers("%s_idle_%d"%[kind,resolution.x])
			await begin_touch("enemy_info_0");await settle()
			check(screen.find_child("EnemyDetails",true,false)!=null,"touch details opens")
			screen._close_workspace();await settle()
			await replay_reload();await replay_reload()
			check(screen.battle_view.machine_frame(0)==1,"charged pose persists between actions")
			await visible_workers("%s_charged_%d"%[kind,resolution.x])
			await replay_reload();await visible_workers("%s_recovery_%d"%[kind,resolution.x])
			var distance: int=screen.model.s.enemies[0].distance
			await replay_reload()
			check(screen.model.s.enemies[0].distance==distance,"recovery actually holds position")
	root.size=Vector2i(1280,800);await settle()
	screen._debug_foundry("single","boss");await settle()
	await replay_reload();await watch_reload("pressure")
	await watch_reload("boss_surge")
	screen._debug_foundry("single","elite");await settle()
	await replay_reload();await replay_reload();await watch_reload("elite_surge",true)
	await lethal_presentation()
	screen.preferences.data.motion="instant"
	screen._debug_foundry("burst","boss");await settle();await replay_reload()
	check(screen.model.s.enemies[0].windup==2 and screen.battle_view.machine_frame(0)==1,"reduced motion preserves telegraph")
	await replay_reload()
	check(screen.model.s.enemies[0].windup==0 and not screen.model.s.enemies[0].recovering,"two-turn reload resolves surge then rest")
	screen._debug_foundry("single","boss",false);await settle()
	check(not Workers.active(screen.model.s.enemies[0]) and screen.campaign.s.roster_version==6,"legacy saved formations preserved")
	check(not screen.save_enabled,"isolated save remains disabled")
	print("FOUNDRY LIVE UI COMPLETE checks=%d failures=%d"%[checks,failures])
	screen.queue_free();await process_frame
	quit(0 if failures==0 else 1)
