extends "res://tests/challenge_ui_runner.gd"
const Guard=preload("res://redesign/central_guard.gd")
var captures:Array=[]

func inspect_frame(label:String) -> void:
	await settle()
	var view=screen.battle_view
	var bounds:=Rect2(Vector2.ZERO,view.size)
	check(view.get_script().resource_path.ends_with("central_battle_view.gd"),"live central renderer")
	check(not screen.main_scroll.get_v_scroll_bar().visible and not screen.main_scroll.get_h_scroll_bar().visible,"screen fits "+label)
	for i in view._alive_indices():
		check(view.guard_sprites.has(i) and view.guard_sprites[i].visible,"authored actor "+label)
		check(bounds.encloses(view.concept_rect(i)),"whole source visible "+label+"/"+str(i))
		check(bounds.encloses(view.enemy_plaque(i)),"HP within board "+label)
		check(absf(view.enemy_plaque(i).get_center().x-view.enemy_feet(i).x)<2,"HP aligned with body")
		check(not view.concept_rect(i).intersects(view.enemy_plaque(i)),"own HP clear of body "+label)
		for j in view._alive_indices():
			if i!=j:
				check(not view.enemy_plaque(i).intersects(view.enemy_plaque(j)),"separate HP columns")
				check(not view.concept_rect(i).intersects(view.concept_rect(j)),"separate silhouettes")
		if Guard.leader(view.enemies[i]):check(bounds.encloses(view.intent_rect(i)),"visible command preview")
	await capture(label);captures.append(label+".png")

func watch_command(order:String,skip:bool=false) -> void:
	screen._debug_central_background(2,"boss");await settle()
	# Presentation fixture, with actual earned deck. It does not prove a winning route.
	for enemy in screen.model.s.enemies:enemy.distance=50+int(enemy.lane)*5
	screen.model.s.enemies[0].command_left=1
	screen.model.s.enemies[0].command_order=order
	for enemy in screen.model.s.enemies:enemy.barrier=0
	screen.redraw();await inspect_frame("boss_"+order+"_warning")
	screen.presentation_speed=1.0;await begin_touch("reload")
	var view=screen.battle_view
	var seen:=false
	var started:=Time.get_ticks_msec()
	while screen.busy and Time.get_ticks_msec()-started<20000:
		if view.issuing>=0 and not seen:
			seen=true
			await RenderingServer.frame_post_draw
			var filename="boss_"+order+"_release.png"
			root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join(filename));captures.append(filename)
			if skip:await begin_touch("skip_animation")
		await process_frame
	check(seen and not screen.busy and view.issuing==-1,"command animation completes or skips")
	check(screen.last_presentation.shown_enemies==screen.model.s.enemies,"command animation matches resolver")
	check(screen.model.s.enemies[0].command_order!=order,"next instruction updates")
	screen.presentation_speed=0.06;await inspect_frame("boss_"+order+"_after")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/central_live/"):quit(1);return
	screen=load("res://redesign/main.tscn").instantiate();screen.save_enabled=false;screen.presentation_speed=0.06
	root.add_child(screen);await settle()
	screen._developer();await settle()
	for key in ["debug_central_normal","debug_central_elite","debug_central_boss"]:check(screen.find_child(key,true,false)!=null,"developer entry "+key)
	screen.find_child("debug_central_boss",true,false).pressed.emit();await settle()
	check(screen.debug_session and screen.campaign.s.roster_version==11,"isolated current preview")
	for resolution in [Vector2i(1008,630),Vector2i(1280,900),Vector2i(1440,630)]:
		root.size=resolution;await settle()
		for kind in ["normal","elite","boss"]:
			screen._debug_central_background(1 if kind=="normal" else 2,"" if kind=="normal" else kind)
			await inspect_frame("%s_%d"%[kind,resolution.x])
			await begin_touch("enemy_info_0");await settle()
			check(screen.find_child("EnemyDetails",true,false)!=null,"touch details")
			screen._close_workspace();await settle()
			var attacks=screen.model.s.hand.filter(func(id):return Data.Ammo.damage(str(id),screen.model.s)>0)
			check(not attacks.is_empty(),"earned attack available")
			await tap("load_"+str(attacks[0]));await tap("confirm");await tap("fire")
			check(screen.last_presentation.shown_enemies==screen.model.s.enemies,"real fire agrees with model")
	# A production-generated ordinary ranged formation, independent of the boss
	# composition. Keep the earned deck; this is a visual/interaction fixture.
	for resolution in [Vector2i(1008,630),Vector2i(1280,900),Vector2i(1440,630)]:
		root.size=resolution;screen._debug_central_background(1);await settle()
		for seed_value in range(1,30):
			var pack=Data.encounter_pack(screen.campaign.node(),seed_value,"single",0,0,11)
			if not pack.active.any(func(enemy):return enemy.species==Guard.ARTILLERY):continue
			screen.model.s.enemies=pack.active;screen.model.s.reinforcements=pack.reserve
			screen.model.s.encounter_total=pack.total;screen.model.s.deployed=4
			break
		check(screen.model.s.enemies.any(func(enemy):return enemy.species==Guard.ARTILLERY),"ordinary artillery fixture exists")
		screen.redraw();await inspect_frame("artillery_%d"%resolution.x)
		await replay_reload();await replay_reload()
		check(screen.model.Ranged.active(screen.model.s).size()==1,"authored artillery launches one interceptable projectile")
	root.size=Vector2i(1280,900);await settle()
	screen._debug_central_background(2,"boss");await settle()
	screen.battle_view.payoff_tier=1;screen.battle_view.salvo_damage=42;screen.battle_view.salvo_kills=[1,2]
	screen.battle_view.queue_redraw();await capture("boss_payoff");captures.append("boss_payoff.png")
	await watch_command("advance");await watch_command("shield",true)
	screen.preferences.data.motion="instant"
	screen._debug_central_background(2,"elite");await settle()
	screen.model.s.enemies[0].command_left=1
	screen.redraw();await settle();await replay_reload()
	check(screen.model.s.enemies[0].command_order=="shield" and screen.battle_view.issuing==-1,"instant mode retains instruction state")
	# Final blow and finish camera use the current full-game route's earned deck.
	screen.preferences.data.motion="normal"
	screen._debug_central_background(2,"boss");await settle()
	screen.model.s.enemies=[screen.model.s.enemies[0]];screen.model.s.reinforcements=[]
	screen.model.s.enemies[0].hp=1;screen.model.s.enemies[0].barrier=0
	screen.model.s.encounter_total=1;screen.model.s.deployed=1
	screen.redraw();await settle()
	var attacks=screen.model.s.hand.filter(func(id):return Data.Ammo.damage(str(id),screen.model.s)>0)
	await tap("load_"+str(attacks[0]));await tap("confirm");await tap("fire")
	check(screen.campaign.s.phase=="reward","final enemy death opens final reward")
	await capture("final_reward");captures.append("final_reward.png")
	check(screen.campaign.reward("skip"),"full bag may legally skip final reward")
	screen.redraw();await settle();await capture("ending");captures.append("ending.png")
	check(screen.campaign.s.phase=="won" and screen.campaign.profile.wins==1,"ending connected exactly once")
	check(not screen.save_enabled,"developer session never writes user save")
	var file=FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("visual_qa.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"human_preference":"not_verified","galaxy":"not_verified"},"  "));file.close()
	print("CENTRAL LIVE UI COMPLETE checks=%d failures=%d"%[checks,failures])
	screen.queue_free();await process_frame;quit(0 if failures==0 else 1)
