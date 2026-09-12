extends SceneTree
var screen: Control
var failures := 0
var checks := 0
var captures: Array = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)

func settle() -> void:
	for i in range(5): await process_frame
	while is_instance_valid(screen) and screen.busy: await process_frame
	await RenderingServer.frame_post_draw

func click(key: String) -> void:
	var button := screen.find_child(key, true, false) as Button
	check(button != null and not button.disabled, "button enabled: " + key)
	if button != null and not button.disabled:
		button.pressed.emit()
	await settle()

func capture(label: String) -> void:
	await settle()
	var path := "user://" + label + ".png"
	root.get_texture().get_image().save_png(path)
	captures.append(path)
	check(screen.body.size.x <= 1280, "no horizontal overflow " + label)
	if label in ["02_plan", "03_planned", "04_ready", "07_final_fixture"]:
		for key in ["rules", "menu", "confirm", "fire", "reload"]:
			var button := screen.find_child(key, true, false) as Button
			if button != null:
				check(button.get_global_rect().end.y <= 800 and button.size.x >= 80, "action visible without scroll: " + label + " " + key)

func _run() -> void:
	root.size = Vector2i(1280, 800)
	screen = load("res://redesign/main.tscn").instantiate()
	screen.presentation_speed = 0.05
	screen.save_enabled = false
	root.add_child(screen)
	await capture("01_menu")
	screen.seed_input.text = "731042"
	await click("start_single")
	await capture("02_plan")
	var initial: Dictionary = screen.model.s.duplicate(true)
	var basic := screen.find_child("load_basic", true, false) as Button
	basic.grab_focus()
	await settle()
	check(screen.ammo_inspector.text.contains("회수탄") and screen.ammo_inspector.text.contains("피해 4"), "keyboard focus exposes current gun damage")
	check(basic.tooltip_text.contains("관통 1") and basic.tooltip_text.contains("명중 6"), "compact card retains exact gate stats in tooltip")
	await click("details")
	check(screen.find_child("CombatDetails", true, false) != null, "clickable combat information is available without hover")
	await capture("10_details")
	for child in screen.get_children():
		if child is AcceptDialog: child.get_ok_button().pressed.emit()
	await settle()
	check(screen.model.s == initial, "opening and closing details preserves combat state")
	await click("load_basic")
	await click("load_basic")
	await click("undo")
	check(screen.model.s.plan.size() == 1, "undo through UI")
	await click("load_basic")
	await capture("03_planned")
	await click("confirm")
	check(screen.model.s.turns == 0 and screen.model.s.shots == 0, "confirm does not fire")
	await capture("04_ready")
	await click("fire")
	await click("fire")
	check(screen.model.s.phase == "reward", "actual encounter won via UI")
	await capture("05_reward")
	await click("reward_slow")
	check(screen.model.s.floor == 1, "reward advances")
	await capture("06_armor")
	await click("menu")
	await click("dev")
	await click("debug_6plan")
	check(screen.debug_session and screen.model.s.floor == 6, "isolated developer shortcut")
	await capture("07_final_fixture")
	await click("rules")
	await capture("08_rules")
	for child in screen.get_children():
		if child is AcceptDialog:
			check(child.size.y <= 760 and child.get_ok_button().is_visible_in_tree(), "rules dialog and close button fit viewport")
			child.queue_free()
	await settle()
	# Deliberate end-screen fixture verifies the practice retry save boundary.
	screen.model.s.phase = "lost"
	screen.redraw()
	await settle()
	await click("retry")
	check(screen.debug_session, "practice retry remains isolated from normal autosave")
	# Resize through normal canvas stretch; no state fixture needed.
	root.size = Vector2i(960, 600)
	await capture("09_small_window")
	var file := FileAccess.open("user://visual_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "captures": captures, "scope": "actual UI commands through first reward; final encounter is developer display fixture"}, "\t"))
	file.close()
	print("REDESIGN VISUAL: %d passed / %d failed" % [checks - failures, failures])
	quit(1 if failures else 0)
