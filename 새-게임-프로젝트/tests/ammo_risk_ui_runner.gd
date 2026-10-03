extends SceneTree
var screen: Control
var failures := 0
var checks := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)

func settle() -> void:
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw

func capture(id: String) -> void:
	await settle()
	check(root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join(id + ".png")) == OK, "capture " + id)

func tap(key: String) -> void:
	var button := screen.find_child(key, true, false) as Button
	check(button != null and not button.disabled, "input " + key)
	if button == null or button.disabled: return
	var point := button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	for i in range(2400):
		if not screen.busy: break
		await process_frame
	check(not screen.busy, "animation completes " + key)
	await settle()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/ammo_risk/"):
		quit(1)
		return
	var scene = load("res://redesign/samples/ammo_risk.tscn")
	if scene == null:
		quit(1)
		return
	screen = scene.instantiate()
	root.add_child(screen)
	await settle()
	screen.presentation_speed = 0.03
	check(not screen.save_enabled and screen.debug_session, "isolated sample cannot save campaign")
	check(screen.model.s.plan == ["charge_hot", "precise", "precise", "pierce"], "hot initial composition")
	for resolution in [Vector2i(1280, 900), Vector2i(1280, 800), Vector2i(1008, 630), Vector2i(1440, 630)]:
		root.size = resolution
		screen.redraw()
		await settle()
		check(not screen.main_scroll.get_v_scroll_bar().visible, "no vertical overflow " + str(resolution))
		check(not screen.main_scroll.get_h_scroll_bar().visible, "no horizontal overflow " + str(resolution))
		for key in ["RiskHeader", "BattleView", "AmmoGrid", "QueuePanel", "RiskStatus", "confirm"]:
			var node := screen.find_child(key, true, false) as Control
			check(node != null and Rect2(Vector2.ZERO, screen.size).encloses(node.get_global_rect()), "screen bounds " + key + str(resolution))
		var status := screen.find_child("RiskStatus", true, false)
		for path in ["Shot/Value", "Reload/Value", "Distance/Value"]:
			var label := status.get_node(path) as Label
			check(label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x <= label.size.x + 1, "risk value fits " + path + str(resolution))
		check(screen.find_child("AmmoGrid", true, false).get_child_count() == 6, "six cards including both boost variants")
		await capture("risk_hot_%dx%d" % [resolution.x, resolution.y])
	root.size = Vector2i(1280, 800)
	screen.redraw()
	await settle()
	check(screen.risk_prediction.reload.cost == 2 and screen.risk_prediction.reload.enemies[2].distance == 15, "pre-shot heat and reload position visible")
	await tap("confirm")
	check(screen.model.s.reload_heat == 0, "confirmation does not generate heat")
	await tap("fire")
	check(screen.model.s.phase == "ready" and screen.model.s.reload_heat == 1, "real hot shot survives urgent encounter")
	check(screen.find_child("reload", true, false).text.contains("2턴"), "reload button reflects actual heat debt")
	await capture("risk_hot_after_fire")
	var projected: Dictionary = screen.risk_prediction.reload.duplicate(true)
	await tap("reload")
	check(screen.model.s.enemies == projected.enemies and screen.model.s.reload_heat == 0, "actual reload matches displayed positions")
	await capture("risk_hot_after_reload")
	for key in ["load_charge", "load_arc", "load_bore", "load_push"]: await tap(key)
	await tap("confirm")
	await tap("fire")
	check(screen.model.s.phase == "reward" and screen.find_child("RiskResult", true, false) != null, "urgent case can be completed through owned card inputs")
	await capture("risk_urgent_victory")
	await tap("risk_next")
	check(not screen.hot_opening and screen.scenario_index == 1, "second case starts stable comparison")
	await capture("risk_shield_normal")
	await tap("confirm")
	await tap("fire")
	await tap("reload")
	check(screen.model.s.phase == "plan" and screen.model.s.enemies[0].distance == 2, "normal composition leaves another action")
	await tap("load_basic")
	await tap("load_basic")
	await tap("load_basic")
	await tap("confirm")
	await tap("fire")
	check(screen.model.s.enemies[0].hp == 0 and screen.model.s.phase == "ready", "surviving normal line can kill approaching shield")
	await tap("reload")
	for key in ["load_charge_hot", "load_arc", "load_bore", "load_push"]: await tap(key)
	await tap("confirm")
	await tap("fire")
	check(screen.model.s.phase == "reward" and screen.model.s.reload_heat == 0, "shield case can finish with a late high-output combination")
	await capture("risk_shield_victory")
	await tap("risk_case_1")
	await tap("risk_hot")
	check(screen.risk_prediction.reload.phase == "lost", "danger visible before committing")
	await capture("risk_shield_hot_warning")
	await tap("confirm")
	await tap("fire")
	await tap("reload")
	check(screen.model.s.phase == "lost", "hot reload produces warned contact")
	check(screen.find_child("RiskResult", true, false) != null, "sample failure stays in comparison flow")
	await capture("risk_shield_hot_result")
	await tap("risk_compare")
	check(screen.model.s.phase == "plan" and not screen.hot_opening and screen.model.s.turns == 0, "result comparison restarts opposite output")
	await tap("risk_case_0")
	await tap("risk_normal")
	await tap("confirm")
	await tap("fire")
	check(screen.model.s.phase == "lost", "normal urgent line demonstrates missed kill threshold")
	await tap("risk_retry")
	check(screen.model.s.phase == "plan" and screen.model.s.reload_heat == 0, "retry cleanly resets heat and enemies")
	print("AMMO RISK UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
