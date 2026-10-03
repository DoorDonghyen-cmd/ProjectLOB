extends "res://tests/ammo_risk_ui_runner.gd"
const Ranged = preload("res://redesign/ranged.gd")
const Data = preload("res://redesign/samples/ranged_sample_data.gd")
const Solver = preload("res://tests/city_combat_solver.gd")
const Forecast = preload("res://redesign/forecast.gd")
var replay_paths: Array = []

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/ranged/"):
		quit(1)
		return
	screen = load("res://redesign/samples/ranged_sample.tscn").instantiate()
	root.add_child(screen)
	await settle()
	screen.presentation_speed = 0.03
	check(not screen.save_enabled and screen.debug_session, "ranged sample cannot write campaign")
	for resolution in [Vector2i(1280, 900), Vector2i(1280, 800), Vector2i(1008, 630), Vector2i(1440, 630)]:
		root.size = resolution
		screen.redraw()
		await settle()
		for case_index in range(2):
			await tap("risk_case_%d" % case_index)
			check(not screen.main_scroll.get_v_scroll_bar().visible and not screen.main_scroll.get_h_scroll_bar().visible, "no overflow " + str(resolution))
			for key in ["RiskHeader", "BattleView", "AmmoGrid", "QueuePanel", "RiskStatus", "confirm"]:
				var node := screen.find_child(key, true, false) as Control
				check(node != null and Rect2(Vector2.ZERO, screen.size).encloses(node.get_global_rect()), "inside screen " + key + str(resolution))
			var status := screen.find_child("RiskStatus", true, false)
			for path in ["Shot/Value", "Reload/Value", "Distance/Value"]:
				var label := status.get_node(path) as Label
				check(label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x <= label.size.x + 1, "risk text fits " + path)
			if case_index == 1:
				check(screen.risk_prediction.shots[0].intercept, "queue forecasts first interception")
				_check_projectile_label()
			await capture("ranged_case%d_%dx%d" % [case_index, resolution.x, resolution.y])
			if case_index == 1 and resolution == Vector2i(1008, 630): await _inspect_projectile()
	root.size = Vector2i(1280, 900)
	screen.redraw()
	await settle()
	await tap("risk_case_0")
	await tap("confirm")
	await tap("fire")
	check(screen.model.s.enemies[1].ranged_left == 1 and screen.model.s.projectiles.is_empty(), "first shot advances visible preparation")
	check(screen.model.s.enemies.size() == 3 and screen.model.s.enemies[2].distance == 18, "reinforcement appears without birth movement")
	await capture("ranged_prepare")
	await tap("reload")
	check(screen.model.s.projectiles.size() == 1 and screen.model.s.projectiles[0].distance == 24, "actual reload launches pressure shot without movement")
	check(screen.battle_view.projectiles == screen.model.s.projectiles, "display shows launched projectile")
	await capture("ranged_launch")
	await _finish_with_public_inputs("telegraph")
	await tap("risk_next")
	await tap("risk_hot")
	await tap("confirm")
	await tap("fire")
	check(screen.last_presentation.events.filter(func(e): return e.kind == "impact" and Ranged.is_projectile(int(e.target))).size() == 1, "real UI intercepts once")
	check(screen.model.s.reload_heat == 1 and Ranged.active(screen.model.s).is_empty(), "hot intercept grants boost and accumulates heat")
	await capture("ranged_intercepted")
	await tap("reload")
	check(screen.model.s.projectiles[0].uid == 2 and screen.model.s.projectiles[0].distance == 24, "extra heat tick permits next launch")
	await capture("ranged_hot_reload")
	await _finish_with_public_inputs("incoming")
	# Readability stress fixture: four formation slots plus one separate projectile.
	await tap("risk_case_1")
	screen.model.s.enemies.append(Data.enemy("runner", 6, 0, 2, 24, 2))
	screen.model.s.enemies.append(Data.enemy("wall", 12, 3, 1, 28, 3))
	screen.model.s.encounter_total = 4
	screen.model.s.deployed = 4
	root.size = Vector2i(1008, 630)
	screen.redraw()
	await settle()
	_check_projectile_label()
	for i in range(4):
		for j in range(i): check(not screen.battle_view.enemy_plaque(i).intersects(screen.battle_view.enemy_plaque(j)), "four enemy plaques stay separate")
	await capture("ranged_four_enemies")
	# Actual known reload hazard, exercised through the public reload button.
	await tap("risk_case_1")
	while not screen.model.s.plan.is_empty(): await tap("undo")
	screen.model.s.enemies[0].distance = 8
	screen.model.s.enemies[0].hp = 90
	screen.model.s.enemies[0].max_hp = 90
	screen.model.s.projectiles[0].distance = 18
	screen.redraw()
	await settle()
	await tap("load_charge_hot")
	await tap("confirm")
	await tap("fire")
	check(screen.risk_prediction.reload.loss_reason == "projectile", "danger visible before committing reload")
	check(screen.find_child("reload", true, false).text.contains("피격"), "reload button names projectile danger")
	await capture("ranged_reload_warning")
	await tap("reload")
	check(screen.model.s.phase == "lost" and screen.find_child("RiskResult", true, false).get_node("Title").text.contains("압력탄"), "projectile impact has its own result reason")
	await capture("ranged_projectile_loss")
	await tap("risk_retry")
	check(screen.model.s.turns == 0 and screen.model.s.reload_heat == 0, "retry resets clocks and heat")
	# The fired projectile stays visible and playable after its source dies.
	await tap("risk_case_1")
	screen.model.s.enemies[0].hp = 0
	screen.model.s.enemies[1].hp = 1
	screen.model.s.enemies[1].burn = 1
	while not screen.model.s.plan.is_empty(): await tap("undo")
	screen.model.s.phase = "ready"
	screen.redraw()
	await settle()
	await tap("reload")
	check(screen.model.alive_count() == 0 and Ranged.active(screen.model.s).size() == 1, "dead source does not falsely open victory")
	check(screen.battle_view.projectiles[0].distance == 6, "orphan projectile still displayed at actual distance")
	await capture("ranged_projectile_only")
	await tap("load_basic")
	await tap("confirm")
	await tap("fire")
	check(screen.model.s.phase == "reward", "public input intercepts last orphan projectile")
	# Capture launch and interception during actual normal-speed presentation.
	root.size = Vector2i(1280, 900)
	await settle()
	await tap("risk_case_0")
	await tap("confirm")
	await tap("fire")
	screen.presentation_speed = 1.0
	await _watch_action("reload", "ranged_launch_action", "launch")
	await tap("risk_case_1")
	await tap("confirm")
	await _watch_action("fire", "ranged_intercept_action", "intercept")
	var file := FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("ranged_ui_paths.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(replay_paths, "\t"))
	print("RANGED UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check_projectile_label() -> void:
	var view = screen.battle_view
	for projectile in Ranged.active(screen.model.s):
		var rect: Rect2 = view.projectile_label_rect(projectile)
		check(Rect2(Vector2.ZERO, view.size).encloses(rect), "projectile deadline stays inside field")
		for i in view._alive_indices(): check(not rect.intersects(view.enemy_plaque(i)), "projectile deadline does not cover enemy info")
		var font := load("res://redesign/ui_font.tres") as Font
		check(font.get_string_size(view.projectile_caption(projectile), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x <= rect.size.x - 8, "projectile deadline text fits")
		check(view.projectile_caption(projectile).begins_with("요격") == Ranged.is_projectile(screen.model.target_index()), "interception label matches actual next target")

func _finish_with_public_inputs(label: String) -> void:
	var solver = Solver.new()
	var path: Array = solver.solve(screen.model, 5, 8)
	check(not path.is_empty(), "reachable continuation " + label)
	replay_paths.append({"case": label, "path": path, "explored": solver.explored})
	for command in path:
		if command.action == "load":
			var base := "load_" + str(command.id)
			var available := ""
			for copy_number in range(1, 6):
				var key := base if copy_number == 1 else base + "_%d" % copy_number
				var button := screen.find_child(key, true, false) as Button
				if button != null and not button.disabled:
					available = key
					break
			check(not available.is_empty(), "available round " + str(command.id))
			if not available.is_empty(): await tap(available)
		else: await tap(str(command.action))
	check(screen.model.s.phase in ["reward", "won"] and Ranged.active(screen.model.s).is_empty(), "real UI completes enemies and hazards " + label)
	await capture("ranged_victory_" + label)

func _inspect_projectile() -> void:
	var before := JSON.stringify(screen.model.s)
	var view = screen.battle_view
	var point: Vector2 = view.global_position + view.projectile_label_rect(screen.model.s.projectiles[0]).get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await settle()
	var details := screen.find_child("ProjectileDetails", true, false)
	check(details != null, "projectile can be inspected through field label")
	if details == null: return
	var dialog := details.get_meta("dialog") as AcceptDialog
	check(Rect2(Vector2.ZERO, root.size).encloses(Rect2(dialog.position, dialog.size)), "projectile detail fits mobile viewport")
	await capture("ranged_projectile_details")
	var close_point := Vector2(dialog.position) + dialog.get_ok_button().get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = close_point
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await settle()
	check(not is_instance_valid(dialog) or not dialog.visible, "projectile detail closes through OK button")
	check(JSON.stringify(screen.model.s) == before, "inspection does not advance or change target")

func _watch_action(key: String, artifact: String, stage: String) -> void:
	var button := screen.find_child(key, true, false) as Button
	check(button != null and not button.disabled, "normal-speed input " + key)
	if button == null or button.disabled: return
	var point := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	var captured := false
	var completed_tick_checked := false
	var start := Time.get_ticks_msec()
	while screen.busy and Time.get_ticks_msec() - start < 15000:
		var view = screen.battle_view
		var ready: bool = view.caption.begins_with("압력탄 발사") if stage == "launch" else (view.float_text == "요격" and view.pulse < 0.7)
		if ready and not captured:
			captured = true
			if stage == "launch": check(screen.find_child("RiskStatus", true, false).get_node("Distance/Value").text.contains("압력탄"), "launch immediately replaces preparation with flying deadline")
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join(artifact + ".png")) == OK, "normal-speed frame " + stage)
		if stage == "launch" and view.feedback_stage == "turn_complete" and not completed_tick_checked:
			completed_tick_checked = true
			check(screen.find_child("RiskStatus", true, false).get_node("Distance/Value").text.contains("압력탄"), "turn completion keeps current projectile deadline")
		await process_frame
	check(captured and not screen.busy, "normal-speed action visibly completes " + stage)
	if stage == "launch": check(completed_tick_checked, "normal-speed launch presents its completed tick")
	await settle()
