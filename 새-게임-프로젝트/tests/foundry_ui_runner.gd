extends "res://tests/challenge_ui_runner.gd"
const Foundry = preload("res://redesign/foundry_roster.gd")

func visible_foundry(label: String) -> void:
	await settle()
	var view=screen.battle_view
	check(Foundry.named(view.enemies[0]),"foundry rank shown")
	check(view.challenge_intent(0).contains("장갑"),"actual armor intent present")
	var frame:=Rect2(Vector2.ZERO,view.size)
	check(frame.encloses(view.intent_rect(0)),"foundry intent stays inside battle")
	for i in view._alive_indices():
		check(frame.encloses(view.enemy_plaque(i)),"foundry HUD inside battle")
		for j in view._alive_indices():
			if i!=j:check(not view.enemy_plaque(i).intersects(view.enemy_plaque(j)),"foundry HUD does not overlap")
	await capture(label)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/foundry/"):quit(1);return
	screen=load("res://redesign/main.tscn").instantiate()
	screen.save_enabled=false;screen.presentation_speed=0.08
	root.add_child(screen);await settle()
	# Test the actual development-menu callbacks, then the production map.
	screen._developer();await settle()
	for gun in ["single","burst","scatter","heavy","amplifier"]:
		check(screen.find_child("debug_foundry_"+gun,true,false)!=null,"menu exposes earned build "+gun)
	screen.find_child("debug_foundry_single",true,false).pressed.emit()
	await settle()
	check(screen.debug_session and screen.campaign.s.region==1,"menu callback opens second region")
	for gun in ["single","burst","scatter","heavy","amplifier"]:
		screen._debug_foundry(gun,"",false);await settle()
		check(screen.debug_session and screen.campaign.s.region==1 and screen.campaign.s.phase=="map","isolated second-region entry")
		check(screen.model.s.reserve_version==1 and screen.campaign.s.roster_version==6,"current finite reserve and roster")
		check(screen.campaign.model.s.deck.size()>=23,"preview uses earned deck")
		var protected_path: String=screen.campaign.SAVE
		var existed:=FileAccess.file_exists(protected_path)
		var contents:=FileAccess.get_file_as_string(protected_path) if existed else ""
		screen.save_enabled=true;screen._persist();screen.save_enabled=false
		check(FileAccess.file_exists(protected_path)==existed,"preview creates no normal save")
		if existed:check(FileAccess.get_file_as_string(protected_path)==contents,"preview leaves saved campaign unchanged")
	await capture("foundry_map")
	for resolution in [Vector2i(1008,630),Vector2i(1280,800),Vector2i(1440,630)]:
		root.size=resolution;await settle()
		for kind in ["elite","boss"]:
			screen._debug_foundry("single",kind,false)
			await visible_foundry("%s_closed_%d"%[kind,resolution.x])
			await replay_reload()
			check(screen.model.s.enemies[0].def==0,"one enemy tick opens plate")
			await visible_foundry("%s_open_%d"%[kind,resolution.x])
			await begin_touch("enemy_info_0");await settle()
			check(screen.find_child("EnemyDetails",true,false)!=null,"foundry details accessible")
			screen._close_workspace();await settle()
			if kind=="boss":
				await replay_reload();await replay_reload()
				check(screen.last_presentation.events.any(func(e):return e.kind=="foundry_link"),"boss extra approach has visible link feedback")
				check(screen.last_presentation.shown_enemies==screen.model.s.enemies,"boss pattern matches final model")
				await visible_foundry("boss_command_%d"%resolution.x)
	screen._debug_foundry("burst","boss",false);await settle()
	await replay_reload()
	check(screen.model.s.enemies[0].def==6 and screen.battle_view.challenge_intent(0).contains("1턴"),"two-turn reload communicates imminent command")
	print("FOUNDRY UI COMPLETE checks=%d failures=%d"%[checks,failures])
	screen.queue_free();await process_frame
	quit(0 if failures==0 else 1)
