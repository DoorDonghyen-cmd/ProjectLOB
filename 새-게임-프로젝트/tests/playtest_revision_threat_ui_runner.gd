extends "res://tests/playtest_revision_payoff_ui_runner.gd"

func arrange(distances: Array) -> void:
	await setup_hand(["push", "basic", "cool"])
	screen.model.s.enemies = []
	for i in range(distances.size()): screen.model.s.enemies.append(Data._enemy(["runner", 20, 0, 1, distances[i]]))
	screen.model.s.encounter_total = distances.size(); screen.model.s.deployed = distances.size()
	screen.model.s.reinforcements = []; screen.model.assign_opening_lanes()
	screen.redraw(); await settle()

func inspect_layout(label: String) -> void:
	var view = screen.battle_view
	var bounds := Rect2(Vector2.ZERO, view.size)
	for i in view._alive_indices():
		check(is_equal_approx(view.enemy_feet(i).y, view.player_feet().y), "enemy shares the illustrated walkway " + label)
		check(bounds.encloses(view.enemy_plaque(i)), "HP and warning within battlefield " + label)
		check(view._enemy_at(view.enemy_plaque(i).get_center()) == i, "separated inspect area " + label)
		for j in view._alive_indices():
			if i == j: continue
			check(not view.enemy_plaque(i).intersects(view.enemy_plaque(j)), "separate overhead controls " + label)
			if float(view.enemies[i].distance) < float(view.enemies[j].distance):
				check(view.enemy_feet(i).x < view.enemy_feet(j).x, "distance ordering " + label)
		check(view.FONT.get_string_size(str(view.threat_readouts.get(i, {}).get("text", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x <= view.enemy_plaque(i).size.x - 14, "warning fits " + label)
	check(view.readout_layer.z_index > 4, "overhead draws above frontmost body")
	for group in view.crowded_groups():
		check(bounds.encloses(group.rect), "crowd count inside battlefield " + label)
		check(not group.rect.intersects(view.reinforcement_strip_rect()), "crowd count clear of reserves " + label)
		for i in view._alive_indices(): check(not group.rect.intersects(view.enemy_plaque(i)), "crowd count clear of HP " + label)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/playtest_revision_20261026/"): quit(2); return
	Input.emulate_mouse_from_touch = true
	screen = load("res://redesign/main.tscn").instantiate(); screen.save_enabled = false; screen.presentation_speed = 0.12
	root.add_child(screen); await settle()
	for resolution in [Vector2i(1008,630), Vector2i(1280,800), Vector2i(1440,630)]:
		root.size = resolution; await settle()
		for distances in [[12,13,14,15], [18,18,18,18], [1,2,3,4], [45,33,40,34]]:
			await arrange(distances); inspect_layout(str(resolution) + str(distances))
			var view = screen.battle_view
			if distances == [18,18,18,18]:
				check(view.crowded_groups().size() == 1 and view.crowded_groups()[0].members.size() == 4, "four coincident bodies have an explicit count")
				check(view._enemy_at(view.actor_pick_rect(view.target).get_center()) == view.target, "actual target is drawn and picked in front")
				view.hovered = 2; view.queue_redraw(); await settle()
				check(view.actor_layer(2) > view.actor_layer(view.target), "inspected body can be seen above automatic target")
				await capture("crowd_focus_%d" % resolution.x)
				view.hovered = -1
			var unchanged: Vector2 = view.enemy_feet(1)
			view.enemies[0].distance += 8
			check(view.enemy_feet(1) == unchanged, "other actor push never displaces stationary anchor")
			view.enemies[0].hp = 0
			check(view.enemy_feet(1) == unchanged, "death never displaces survivor")
			view.enemies.append(Data._enemy(["wall",20,2,1,12])); view.enemies[-1].lane = 0
			check(view.enemy_feet(1) == unchanged, "reinforcement never displaces survivor")
			screen.redraw(); await settle()
			if distances[0] == 18 or distances[0] == 1: await capture("crowd_%d_%d" % [resolution.x, distances[0]])
		# Actual current regional packs, including large bosses and status-heavy escorts.
		for region in range(5):
			await setup_hand(["push", "basic", "cool"])
			screen.campaign.s.region = region; screen.campaign.s.roster_version = 11
			var pack := Data.encounter_pack({"id":20601,"region":region,"floor":6,"kind":"boss","elite":false,"name":"QA"},731042,"single",0,0,11,2)
			screen.model.s.enemies = pack.active; screen.model.s.reinforcements = pack.reserve
			screen.model.s.encounter_total = pack.total; screen.model.s.deployed = pack.active.size(); screen.model.assign_opening_lanes()
			screen.redraw(); await settle(); inspect_layout("region " + str(region))
			await capture("region_%d_%d" % [region,resolution.x])
			if resolution.x == 1008:
				for depth in [1,4,7]:
					screen.battle_view.set_route_background(region, depth, 7)
					await settle(); inspect_layout("background %d/%d" % [region,depth])
					await capture("ground_region_%d_depth_%d" % [region,depth])
			if resolution.x == 1008:
				for enemy in screen.model.s.enemies:
					if enemy.has("command_left"): enemy.command_left = 1
					if enemy.has("windup_max"): enemy.windup = int(enemy.windup_max) - 1
					if enemy.has("leap_left"): enemy.leap_left = 1
					if enemy.has("charge_max"): enemy.charge = int(enemy.charge_max) - 1
					if enemy.kind == "spitter": enemy.ranged_phase = "prepare"; enemy.ranged_left = 1
				screen.redraw(); await settle(); inspect_layout("imminent region " + str(region))
				var active_view = screen.battle_view
				if active_view.has_method("challenge_intent"):
					check(not str(active_view.challenge_intent(0)).contains("m"), "boss overhead has no meter readout")
				await capture("region_%d_imminent" % region)
	# Every overlapping enemy remains reachable through actual touch controls.
	root.size = Vector2i(1008,630); await arrange([12,12,12,12])
	for i in range(4):
		await begin_touch("enemy_info_%d" % i); await settle()
		var details = screen.find_child("EnemyDetails", true, false)
		check(details != null and int(details.get_meta("enemy_index", -1)) == i, "touch opens intended overlapping enemy")
		if details != null: check(details.find_children("*","Label",true,false).any(func(node): return node.text.contains("기본 접근")), "exact distance retained in details")
		screen._close_workspace(); await settle()
	# Legal public push/fire/reload: view must end on the resolver state.
	await arrange([12,13,22,28]); await tap("load_push"); await tap("confirm"); await tap("fire")
	check(screen.model.target_index() == 1, "push changes target without pushing unrelated bodies")
	check(screen.last_presentation.shown_enemies == screen.model.s.enemies, "push and movement match actual state")
	await capture("push_result")
	await tap("reload")
	check(screen.last_presentation.shown_enemies == screen.model.s.enemies, "reload movement matches actual state")
	# Existing pressure projectile remains visible and independently inspectable.
	await arrange([20,20,20,20])
	screen.model.s.enemies[3] = Data._enemy(["spitter",20,0,0,20]); screen.model.s.enemies[3].lane = 3
	screen.model.s.enemies[3].ranged_phase = "waiting"; screen.model.s.enemies[3].ranged_left = 0
	screen.model.s.projectile_serial = 1
	screen.model.s.projectiles = [{"uid":1,"source":3,"kind":"pressure","name":"압력탄","hp":1,"max_hp":1,"def":0,"speed":6,"distance":6,"burn":0}]
	screen.redraw(); await settle()
	var view = screen.battle_view
	var projectile: Dictionary = view.projectiles[0]
	check(view.projectile_caption(projectile).contains("다음 적 행동"), "imminent projectile uses explicit enemy-action warning")
	check(view.FONT.get_string_size(view.projectile_caption(projectile), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x <= view.projectile_label_rect(projectile).size.x - 8, "projectile warning fits")
	for i in view._alive_indices(): check(not view.projectile_label_rect(projectile).intersects(view.enemy_plaque(i)), "projectile warning clear of HP")
	await capture("pressure_imminent")
	# Reduced and skipped movement still settle at the actual resolver state.
	for mode in ["fast", "instant"]:
		screen.preferences.data.motion = mode
		await arrange([12,13,22,28]); await tap("load_push"); await tap("confirm"); await tap("fire")
		check(screen.last_presentation.shown_enemies == screen.model.s.enemies, "reduced movement matches resolver " + mode)
	FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("threat_ui.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("PLAYTEST REVISION THREAT UI COMPLETE checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
