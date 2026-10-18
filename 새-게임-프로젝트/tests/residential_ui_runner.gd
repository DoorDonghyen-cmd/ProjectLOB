extends "res://tests/eavesback_ui_runner.gd"

func show_depth(depth: int) -> void:
	screen.campaign = Campaign.new()
	screen.campaign.start("single", 731042)
	screen.campaign.enter(int(screen.campaign.choices()[0].id))
	screen.model = screen.campaign.model
	var node: Dictionary = Data.nodes(0, 731042, 2).filter(func(n): return int(n.floor) == depth and n.kind in ["combat", "boss"])[0]
	var pack := Data.encounter_pack(node, 731042, "single", 0, 0, 2)
	screen.model.s.enemies = pack.active.duplicate(true)
	screen.model.s.reinforcements = pack.reserve.duplicate(true)
	screen.model.s.encounter_total = pack.total
	screen.model.s.deployed = pack.active.size()
	screen.model.assign_opening_lanes()
	screen.debug_session = false
	screen.page = "run"
	screen.hand_layout_key = ""
	screen.redraw()
	await settle()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/residential/"):
		quit(1)
		return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.05
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1280, 900), Vector2i(1008, 630), Vector2i(1440, 630)]:
		root.size = resolution
		for depth in [1, 2, 3, 4, 6, 8]:
			await show_depth(depth)
			fit()
			check(not screen.debug_session and screen.battle_view.get_script().resource_path.ends_with("/residential_battle_view.gd"), "production view outside developer mode")
			for i in range(screen.model.s.enemies.size()):
				var rect: Rect2 = screen.battle_view.toad_rect(i) if screen.model.s.enemies[i].kind == "spitter" else screen.battle_view.concept_rect(i)
				check(Rect2(Vector2.ZERO, screen.battle_view.size).encloses(rect), "actor within battlefield")
				check(absf(rect.end.y - screen.battle_view.enemy_feet(i).y) <= 1, "species planted on floor")
				check(rect.position.y >= screen.battle_view.enemy_plaque(i).end.y, "HP and traits above actor")
				for j in range(i):
					if screen.model.s.enemies[i].distance > screen.model.s.enemies[j].distance:
						check(screen.battle_view.enemy_feet(i).x > screen.battle_view.enemy_feet(j).x, "distance order remains monotonic")
			await capture("depth_%d_%d" % [depth, resolution.x])
		await show_depth(3)
		await tap("load_basic")
		await tap("confirm")
		await tap("fire")
		check(screen.battle_view.enemies == screen.model.s.enemies, "movement and hit finish at model state")
		var reload_button := screen.find_child("reload", true, false) as Button
		check(reload_button.text.contains("적 발사"), "reload warns actual launch")
		check(reload_button.get_theme_color("font_color") == preload("res://redesign/combat_pixel_skin.gd").HEAT, "warning survives final pixel skin")
		fit()
		await capture("launch_warning_%d" % resolution.x)
		await tap("reload")
		check(not screen.model.s.projectiles.is_empty() and screen.battle_view.projectiles == screen.model.s.projectiles, "toad launches from real turn timer")
		await capture("projectile_%d" % resolution.x)
		await tap("reload")
		await tap("reload")
		reload_button = screen.find_child("reload", true, false) as Button
		check(reload_button.text.contains("압력탄 임박"), "planning reload warns approaching projectile")
		fit()
		await capture("imminent_%d" % resolution.x)
		await tap("reload")
		reload_button = screen.find_child("reload", true, false) as Button
		check(reload_button.text.contains("피격 위험") and reload_button.get_meta("reload_lethal", false), "lethal projectile gets danger skin")
		fit()
		await capture("lethal_%d" % resolution.x)
		# Actual details use the biological species name and rule, no placeholder.
		await show_depth(4)
		screen._enemy_details(2)
		await settle()
		var texts := ""
		for label in screen.find_children("*", "Label", true, false): texts += label.text
		check(texts.contains("빗주머니") and texts.contains("집수기관"), "species details match visible creature")
		screen._close_workspace()
		await settle()
	# Contact motion uses actual losing reload events for both new species.
	for role in ["runner", "evader"]:
		await show_depth(3)
		screen.model.s.enemies = [Data._enemy([role, 20, 0, 2, 1])]
		Data.Residential.identify(screen.model.s.enemies[0])
		screen.model.s.reinforcements = []
		screen.model.s.encounter_total = 1
		screen.model.s.deployed = 1
		screen.model.assign_opening_lanes()
		var before: Dictionary = screen.model.s.duplicate(true)
		check(screen.model.reload_magazine(), "paid reload can expose contact " + role)
		var after: Dictionary = screen.model.s.duplicate(true)
		check(after.phase == "lost", "actual contact loss " + role)
		var view = screen.battle_view
		await view.play_action(before, after, [], screen.model.last_reload_detail.advance_events, true)
		check(view.visual_events.any(func(e): return e.kind == "monster_contact"), "species contact reaction " + role)
		check(view.attacking_indices.is_empty() and view.enemies == after.enemies and screen.model.s == after, "contact animation resets without changing combat")
		view.reduced_feedback = true
		await view.play_action(before, after, [], screen.model.last_reload_detail.advance_events, true)
		check(view.enemies == after.enemies and screen.model.s == after, "instant animation preserves contact result")
	# Existing runs and upper regions retain their original production view.
	for legacy in [true, false]:
		await show_depth(1)
		if legacy: screen.campaign.s.roster_version = 1
		else:
			screen.campaign.s.region = 1
			screen.campaign.s.node = Data.nodes(1, 731042, 2)[0].id
		screen.redraw()
		await settle()
		check(screen.battle_view.get_script().resource_path.ends_with("/ranged_battle_view.gd"), "legacy or later region uses existing actors")
	print("RESIDENTIAL UI COMPLETE checks=%d failures=%d" % [checks, failures])
	screen.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
