extends "res://tests/challenge_ui_runner.gd"
const Slum = preload("res://redesign/slum_roster.gd")
const HumanArt = preload("res://redesign/slum_art.gd")

func show_region(region: int, depth: int, kind: String = "normal") -> void:
	screen.campaign=Campaign.new()
	screen.campaign.start("single",731042,0,"balanced",3,"carrier")
	screen.campaign.s.region=region
	screen.campaign.s.departure_step=3
	var candidates: Array=screen.campaign.current_nodes().filter(func(n):return n.kind=="boss" if kind=="boss" else bool(n.get("elite",false)) if kind=="elite" else int(n.floor)==depth and n.kind=="combat" and not n.get("elite",false))
	var node: Dictionary=candidates[0] if not candidates.is_empty() else {"id":region*10000+depth*100+1,"region":region,"floor":depth,"name":"QA","kind":"combat","elite":false}
	screen.campaign.s.node=node.id;screen.campaign.s.floor=node.floor
	screen.campaign._begin_combat(node)
	screen.model=screen.campaign.model
	screen.page="run";screen.debug_session=true;screen.hand_layout_key=""
	screen.redraw()
	await settle()

func check_field(label: String) -> void:
	var view=screen.battle_view
	var frame:=Rect2(Vector2.ZERO,view.size)
	for i in view._alive_indices():
		check(frame.encloses(view.enemy_plaque(i)),"HUD within field "+label)
		for j in view._alive_indices():
			if i!=j:check(not view.enemy_plaque(i).intersects(view.enemy_plaque(j)),"separate HUD columns "+label)
		if Slum.human(view.enemies[i]):
			check(view.human_sprites.has(i) and view.human_sprites[i].visible,"human art rendered")
			check(view.human_sprites[i].texture==HumanArt.TEXTURES[str(view.enemies[i].species)],"correct human species art")
			check(frame.encloses(view.concept_rect(i)),"full registered actor in field "+label)
			check(not view.concept_rect(i).intersects(view.enemy_plaque(i)),"weapon pose clear of overhead status "+label)
	await capture(label)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/slum/"):quit(1);return
	screen=load("res://redesign/main.tscn").instantiate()
	screen.save_enabled=false;screen.presentation_speed=0.08
	root.add_child(screen);await settle()
	for resolution in [Vector2i(1008,630),Vector2i(1280,800),Vector2i(1440,630)]:
		root.size=resolution;await settle()
		screen._open_preparation(false);await settle()
		var equipment=screen.find_child("EquipmentScreen",true,false)
		for outfit in Ammo.OUTFITS:
			equipment._select_outfit(outfit);await settle()
			var preview=screen.find_child("OutfitPortrait",true,false)
			check(preview.actor.outfit_id==outfit and preview.actor.gun_id==screen.selected_weapon_id,"selection shares combat costume and gun")
			check(Rect2(Vector2.ZERO,preview.size).encloses(preview.display_rect()),"combat preview fits selection area")
			bounds("OutfitPortrait")
			if resolution.x==1280 or outfit=="work":await capture("outfit_%s_%d"%[outfit,resolution.x])
		for depth in [1,2,3,6]:
			await show_region(0,depth)
			check(screen.battle_view.get_script().resource_path.ends_with("slum_battle_view.gd"),"production humans selected")
			await check_field("slum_depth_%d_%d"%[depth,resolution.x])
		screen._debug_challenge("elite");await settle()
		check(screen.model.s.enemies[0].species==Slum.LEADER,"new challenge preview uses human leader")
		check(screen.battle_view.challenge_intent(0).contains("지휘"),"human action uses command wording")
		await check_field("leader_idle_%d"%resolution.x)
		await begin_touch("enemy_info_0");await settle()
		check(screen.find_child("EnemyDetails",true,false)!=null,"human details available by touch")
		screen._close_workspace();await settle()
		await replay_reload();await replay_reload()
		check(screen.battle_view.human_frame(0)==1,"command imminent pose follows model clock")
		await check_field("leader_ready_%d"%resolution.x)
		await replay_reload()
		check(screen.last_presentation.events.any(func(e):return e.kind=="command_link"),"actual command has source-to-ally cue")
		await check_field("leader_after_command_%d"%resolution.x)
		screen._debug_challenge("boss");await settle()
		check(screen.model.s.enemies[0].species==Challenges.BOSS and screen.model.s.enemies[0].def==5,"gate unchanged")
		await check_field("gate_with_raiders_%d"%resolution.x)
		await show_region(2,3)
		check(screen.battle_view.get_script().resource_path.ends_with("residential_battle_view.gd"),"garden uses biological actors")
		check(screen.model.s.enemies.all(func(e):return e.has("species") and not Slum.human(e)),"garden species")
		await check_field("garden_%d"%resolution.x)
		await show_region(2,8,"elite")
		await check_field("garden_elite_%d"%resolution.x)
		await show_region(2,9,"boss")
		await check_field("garden_gate_%d"%resolution.x)
	# Capture all keyed human poses at consistent field scale, including atlas seams.
	await show_region(0,6)
	screen.model.s.enemies=[]
	for kind in ["runner","wall","evader","spitter"]:
		var enemy:=Data._enemy([kind,9,1 if kind=="wall" else 0,1,18+screen.model.s.enemies.size()*4])
		Slum.identify(enemy);screen.model.s.enemies.append(enemy)
	screen.model.s.reinforcements=[];screen.model.s.encounter_total=4;screen.model.s.deployed=4
	screen.model.assign_opening_lanes();screen.redraw();await settle()
	var view=screen.battle_view
	await check_field("human_family_idle")
	view.moving_indices=[0,1,2];view.march_phase=PI/2
	view.enemies[3].ranged_left=1
	view.queue_redraw();await RenderingServer.frame_post_draw
	await capture("human_family_step")
	view.attacking_indices=[0,1,2];view.firing_human=3
	view.queue_redraw();await RenderingServer.frame_post_draw
	await capture("human_family_attack")
	view.attacking_indices=[];view.moving_indices=[];view.firing_human=-1
	# A raised command pose with extra statuses keeps its fixed overhead area clear.
	screen._debug_challenge("elite");await settle()
	screen.model.s.enemies[0].charge=2
	screen.model.s.enemies[0].burn=3;screen.model.s.enemies[0].jammed=2
	screen.redraw();await settle()
	await check_field("leader_status_stack")
	# Actual lethal shot presentation must clear the new polygon actor and match model.
	screen._debug_challenge("elite");await settle()
	screen.model.s.enemies[0].hp=1;screen.model.s.enemies[0].def=0
	screen.redraw();await settle()
	await tap("load_precise_p3");await tap("confirm");await tap("fire");await settle()
	check(screen.model.s.enemies[0].hp==0,"human target dies by real shot")
	check(screen.last_presentation.shown_enemies==screen.model.s.enemies,"human death presentation agrees with model")
	check(not screen.battle_view.human_sprites.has(0) or not screen.battle_view.human_sprites[0].visible,"dead human hidden")
	print("SLUM UI COMPLETE checks=%d failures=%d"%[checks,failures])
	screen.queue_free();await process_frame
	quit(0 if failures==0 else 1)
