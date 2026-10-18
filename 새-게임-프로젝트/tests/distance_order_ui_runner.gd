extends "res://tests/ammo_expansion_ui_runner.gd"

var observed_frames := 0
var inverted_frames := 0

func observe_movement() -> void:
	if not is_instance_valid(screen) or not screen.busy or screen.battle_view == null: return
	var view = screen.battle_view
	observed_frames += 1
	for a in view._alive_indices():
		for b in view._alive_indices():
			if float(view.enemies[a].distance) < float(view.enemies[b].distance) and view.enemy_feet(a).x >= view.enemy_feet(b).x:
				inverted_frames += 1

func fixture(distances: Array) -> void:
	screen.model.s.enemies = []
	var kinds := ["runner", "wall", "spitter", "stance"]
	for i in range(distances.size()):
		screen.model.s.enemies.append(Data._enemy([kinds[i % 4], 30, 0, 1, distances[i]]))
	screen.model.assign_opening_lanes()
	screen.model.s.projectiles = []
	screen.model.s.reinforcements = []
	screen.model.s.encounter_total = distances.size()
	screen.model.s.deployed = distances.size()
	screen.redraw()
	await settle()

func verify_order(label: String) -> void:
	var view = screen.battle_view
	var entities: Array = view._alive_indices()
	for projectile in view.projectiles:
		if int(projectile.hp) > 0: entities.append(view.Ranged.target_id(projectile))
	var leftmost := -1
	var left_x := INF
	for a in entities:
		var at: Vector2 = view.enemy_position(a)
		check(at.x >= 180 and at.x < view.size.x - 20, label + " within field")
		if at.x < left_x:
			left_x = at.x
			leftmost = a
		for b in entities:
			if float(view._visual_entity(a).distance) < float(view._visual_entity(b).distance):
				check(at.x < view.enemy_position(b).x, label + " nearer threat draws nearer")
		if not view.Ranged.is_projectile(a):
			check(view.enemy_feet(a).y == view.player_feet().y, label + " stable ground")
			check(view._enemy_at(at) == a, label + " actor inspection")
			for b in view._alive_indices():
				if a == b: continue
				check(not view.enemy_plaque(a).intersects(view.enemy_plaque(b)), label + " readable plaques")
				if float(view.enemies[a].distance) < float(view.enemies[b].distance):
					check(view.enemy_plaque(a).position.x < view.enemy_plaque(b).position.x, label + " plaque order")
	check(leftmost == screen.model.target_index(), label + " leftmost matches real target")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/distance_order/"):
		quit(1)
		return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.03
	root.add_child(screen)
	await settle()
	await combat(["push", "pierce", "disrupt", "cool"], "single", true)
	await fixture([13, 24, 28, 9])
	var view = screen.battle_view
	print("REPRO width=%s 13m_x=%s 9m_x=%s target=%s" % [view.size.x, view.enemy_feet(0).x, view.enemy_feet(3).x, screen.model.target_index()])
	if OS.get_environment("QA_DISTANCE_STAGE") == "before":
		check(view.enemy_feet(0).x < view.enemy_feet(3).x, "original inversion reproduced")
		await capture("before_13m_9m")
	else:
		process_frame.connect(observe_movement)
		for resolution in [Vector2i(1280, 900), Vector2i(1008, 630), Vector2i(1440, 630)]:
			root.size = resolution
			for distances in [[13, 24, 28, 9], [9, 13, 9, 13], [1, 1, 1, 1], [32, 32, 32, 32], [45, 33, 40, 34]]:
				await fixture(distances)
				verify_order(str(resolution) + str(distances))
				fit()
				if distances == [13, 24, 28, 9]: await capture("after_13m_9m_%d" % resolution.x)
				if resolution.x == 1008 and distances == [32, 32, 32, 32]: await capture("after_equal_distance_1008")
			# Reversed persistent lanes, distance ties and a projectile from the rear lane.
			await fixture([13, 24, 28, 9])
			for i in range(4): screen.model.s.enemies[i].lane = 3 - i
			for distance in [6, 9, 11, 13, 25, 32]:
				screen.model.s.projectiles = [{"uid": 1, "source": 2, "kind": "pressure", "name": "압력탄", "hp": 1, "max_hp": 1, "def": 0, "speed": 6, "distance": distance, "burn": 0}]
				screen.redraw()
				await settle()
				verify_order("projectile %s %s" % [resolution, distance])
				if resolution.x == 1008 and distance == 9: await capture("after_projectile_front_1008")
			await capture("after_projectile_%d" % resolution.x)
		# Public firing advances enemies and pushes one past a different enemy.
		screen.presentation_speed = 0.25
		await fixture([12, 13, 22, 28])
		await tap("load_push")
		await tap("confirm")
		await tap("fire")
		check(screen.last_presentation.shown_enemies == screen.model.s.enemies, "push presentation agrees with model")
		check(screen.model.target_index() == 1, "actual push changes nearest enemy")
		verify_order("after actual push and movement")
		await capture("after_push")
		await combat(["pierce", "cool", "disrupt"], "single", true)
		await fixture([13, 24, 28, 9])
		screen.model.s.enemies[0].speed = 7
		screen.redraw()
		await settle()
		await tap("load_basic")
		await tap("confirm")
		await tap("fire")
		check(screen.model.target_index() == 0, "faster enemy overtakes previous nearest")
		verify_order("after different approach speeds")
		# Actual kill and deployment keep the closest surviving threat on the left.
		await combat(["pierce", "cool", "disrupt"], "single", true)
		await fixture([13, 24, 28, 9])
		screen.model.s.enemies[1].hp = 0
		screen.model.s.enemies[3].hp = 1
		screen.model.s.reinforcements = [Data._enemy(["wall", 20, 2, 1, 18])]
		screen.model.s.encounter_total = 5
		screen.redraw()
		await settle()
		await tap("load_pierce")
		await tap("confirm")
		await tap("fire")
		check(screen.model.s.enemies[3].hp == 0, "actual nearest enemy killed")
		check(screen.model.s.deployed == 5, "actual reinforcement deployed")
		check(screen.last_presentation.shown_enemies == screen.model.s.enemies, "deployment presentation agrees with model")
		verify_order("after kill and deployment")
		await capture("after_deployment")
		check(observed_frames > 0 and inverted_frames == 0, "no reversed distance order during action frames")
		print("ANIMATION observed_frames=%d inverted_frames=%d" % [observed_frames, inverted_frames])
	screen.queue_free()
	await process_frame
	print("DISTANCE ORDER UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
