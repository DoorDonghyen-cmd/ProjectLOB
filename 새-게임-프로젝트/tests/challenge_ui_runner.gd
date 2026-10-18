extends "res://tests/build_payoff_ui_runner.gd"
const Challenges = preload("res://redesign/residential_challenges.gd")
const CombatModel = preload("res://redesign/model.gd")

func visible_challenge(label: String) -> void:
	await settle()
	var view = screen.battle_view
	check(view.get_script().resource_path.ends_with("residential_battle_view.gd"),"production challenge view")
	check(Challenges.named(view.enemies[0]),"actual challenge actor")
	var frame := Rect2(Vector2.ZERO,view.size)
	var actor: Rect2 = view.concept_rect(0)
	check(frame.encloses(actor),"whole challenge sprite inside board " + label)
	for index in view._alive_indices():
		check(frame.encloses(view.enemy_plaque(index)),"enemy HUD fits " + label)
		for other in view._alive_indices():
			if other != index: check(not view.enemy_plaque(index).intersects(view.enemy_plaque(other)),"distinct enemy HUD columns " + label)
		check(not actor.intersects(view.enemy_plaque(index)),"challenge body clear of HUD " + label)
		check(not actor.intersects(view.distance_label_rect(index)),"challenge clear of distance " + label)
	check(view.creature_sprites.has(0) and view.creature_sprites[0].visible,"new alpha cutout shown")
	check(view.creature_sprites[0].texture.resource_path.contains("elite_boss_20261018"),"new atlas not ordinary placeholder")
	check(view.creature_sprites[0].material.shader.resource_path.ends_with("monster_alpha_cutout.gdshader"),"generated diffuse fringe rejected")
	print("FRAME ",label," board=",view.size," actor=",actor," hud=",view.enemy_plaque(0))
	await capture(label)

func replay_reload() -> void:
	var oracle = CombatModel.new()
	check(oracle.restore_state(screen.model.s),"UI fixture is valid owned state")
	check(oracle.reload_magazine(),"oracle real reload")
	await tap("reload")
	await settle()
	check(screen.model.s.enemies == oracle.s.enemies and screen.model.s.projectiles == oracle.s.projectiles,"UI reload actual model")
	check(screen.last_presentation.shown_enemies == screen.model.s.enemies,"visual state matches model after reload")

func finish_check() -> void:
	screen._debug_challenge("boss")
	screen.model.s.enemies = [screen.model.s.enemies[0]]
	screen.model.s.reinforcements = []
	screen.model.s.encounter_total = 1;screen.model.s.deployed = 1
	screen.model.s.enemies[0].hp = 1
	screen.model.s.enemies[0].guard_armor = 0;screen.model.s.enemies[0].def = 0
	screen.redraw();await settle()
	await tap("load_precise_p3");await tap("confirm")
	screen.presentation_speed = 1.0
	await begin_touch("fire")
	var view = screen.battle_view
	var seen := false
	var approach := false
	var captured := false
	var started := Time.get_ticks_msec()
	while screen.busy and Time.get_ticks_msec()-started < 15000:
		if view.finish_active:
			seen = true
			if not view.bullet.is_empty(): approach = true
			check(view.finish_camera().get_scale().x <= 1.251,"large boss zoom ceiling")
			if view.finish_progress > 0.3 and not captured:
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join("boss_finish_%d.png" % root.size.x))
				captured = true
		await process_frame
	check(seen and approach and captured and not screen.busy,"boss lethal pre-impact zoom completes")
	check(screen.campaign.s.phase == "reward","boss flows to real gate reward")
	screen.presentation_speed = 0.08

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/elite_boss/"): quit(1);return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false;screen.presentation_speed = 0.08
	root.add_child(screen);await settle()
	for resolution in [Vector2i(1008,630),Vector2i(1280,800),Vector2i(1440,630)]:
		root.size = resolution;await settle()
		for kind in ["elite","boss"]:
			screen._debug_challenge(kind)
			await visible_challenge("%s_idle_%d" % [kind,resolution.x])
			await begin_touch("enemy_info_0");await settle()
			check(screen.find_child("EnemyDetails",true,false) != null,"touch opens named threat details")
			screen._close_workspace();await settle()
			await replay_reload();await replay_reload()
			await visible_challenge("%s_open_%d" % [kind,resolution.x])
			await replay_reload()
			if kind == "boss":
				await replay_reload()
				check(screen.model.s.projectiles.size() == 1,"boss launches through UI reload")
				await capture("boss_projectile_%d" % resolution.x)
			else:
				check(screen.last_presentation.events.any(func(event): return event.kind == "resonance"),"elite has distinct release presentation")
		await finish_check()
	# Extra status effects must not push the large body into its overhead HUD.
	root.size = Vector2i(1008,630)
	screen._debug_challenge("boss")
	screen.model.s.enemies[0].burn = 3
	screen.model.s.enemies[0].jammed = 2
	screen.model.s.enemies[0].disrupted = true
	screen.redraw();await visible_challenge("boss_status_stack_1008")
	print("CHALLENGE UI COMPLETE checks=%d failures=%d" % [checks,failures])
	screen.queue_free();await process_frame
	quit(0 if failures == 0 else 1)
