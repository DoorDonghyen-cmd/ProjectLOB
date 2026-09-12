extends SceneTree
var screen: Control
var passed := 0
var failed := 0

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; printerr("FAIL: " + label)

func settle() -> void:
	for i in range(5): await process_frame
	while screen.busy: await process_frame
	await RenderingServer.frame_post_draw

func touch_at(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle()

func tap_button(button: Button) -> void:
	check(button != null and not button.disabled, "touch target available")
	if button == null or button.disabled: return
	var point := root.get_final_transform() * (button.get_screen_transform() * (button.size * 0.5) - Vector2(DisplayServer.window_get_position()))
	await touch_at(point)

func tap(key: String) -> void:
	await tap_button(screen.find_child(key, true, false) as Button)

func close_dialogs() -> void:
	for child in screen.get_children():
		if child is AcceptDialog: await tap_button(child.get_ok_button())

func _run() -> void:
	root.size = Vector2i(1920, 864)
	screen = load("res://redesign/main.tscn").instantiate()
	screen.presentation_speed = 0.05
	root.add_child(screen)
	await settle()
	check(Input.emulate_mouse_from_touch, "touch-to-mouse input enabled by project default")
	check(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile") == "gl_compatibility", "Android explicitly uses compatibility rendering")
	check(ProjectSettings.get_setting("display/window/handheld/orientation") == 4, "sensor landscape configured")
	screen.seed_input.text = "731042"
	await tap("start_single")
	check(screen.page == "run", "touch starts a game")
	if screen.page != "run": quit(1); return
	await tap("details")
	check(screen.find_child("CombatDetails", true, false) != null, "all stats accessible without hover")
	await close_dialogs()
	await tap("load_basic")
	await tap("load_basic")
	check(screen.model.s.plan == ["basic", "basic"], "two taps load exactly two rounds")
	await tap("undo")
	check(screen.model.s.plan.size() == 1, "touch undo")
	await tap("load_basic")
	await tap("confirm")
	await tap("fire")
	check(screen.model.s.shots == 1, "one touch fires only one round")
	var saved: Dictionary = screen.model.s.duplicate(true)
	await tap("menu")
	await tap("resume")
	# JSON restores numbers as floats in nested history; compare serialized values.
	check(JSON.parse_string(JSON.stringify(screen.model.s)) == JSON.parse_string(JSON.stringify(saved)), "touch resume restores saved combat")
	await tap("fire")
	check(screen.model.s.phase == "reward", "touch combat reaches reward")
	await tap("reward_slow")
	check(screen.model.s.floor == 1, "touch reward advances campaign")
	await tap("menu")
	await tap("dev")
	await tap("debug_multi_target")
	check(screen.debug_session, "touch enters isolated practice")
	var target: int = screen.model.target_index()
	var point: Vector2 = root.get_final_transform() * (screen.battle_view.get_screen_transform() * screen.battle_view.enemy_position(1) - Vector2(DisplayServer.window_get_position()))
	await touch_at(point)
	var detail := screen.find_child("EnemyDetails", true, false)
	check(detail != null and detail.get_meta("enemy_index") == 1, "touch enemy B opens its details")
	check(screen.model.target_index() == target, "touch inspection preserves automatic target")
	await close_dialogs()
	root.get_texture().get_image().save_png("user://touch_landscape.png")
	await tap("confirm")
	await tap("fire")
	check(screen.model.s.shots == 4 and screen.model.s.turns == 1, "touch burst fires all rounds once")
	var file := FileAccess.open("user://touch_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failed,"scope":"PC InputEventScreenTouch simulation at 1920x864; not an Android device run"}, "\t"))
	print("REDESIGN TOUCH: %d passed / %d failed" % [passed, failed])
	quit(1 if failed else 0)
