extends SceneTree
var screen: Control
var passed := 0
var failed := 0

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; printerr("FAIL: " + label)

func settle() -> void:
	for i in range(4): await process_frame
	while screen.busy: await process_frame
	await RenderingServer.frame_post_draw

func tap_control(control: Control, local: Vector2 = Vector2(-1, -1)) -> void:
	check(control != null, "touch target exists")
	if control == null: return
	var point := root.get_final_transform() * (control.get_screen_transform() * (control.size * 0.5 if local.x < 0 else local) - Vector2(DisplayServer.window_get_position()))
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle()

func tap(key: String) -> void:
	var button := screen.find_child(key, true, false) as Button
	check(button != null and not button.disabled, key + " enabled")
	if button and not button.disabled: await tap_control(button)

func close_dialogs() -> void:
	for child in screen.get_children():
		if child is AcceptDialog: await tap_control(child.get_ok_button())

func capture(name: String) -> void:
	await settle()
	root.get_texture().get_image().save_png("user://chain_" + name + ".png")
	for key in ["confirm", "fire", "reload", "exchange", "undo"]:
		var control := screen.find_child(key, true, false) as Control
		if control:
			check(screen.get_global_rect().encloses(control.get_global_rect()), key + " within screen")

func _run() -> void:
	root.size = Vector2i(1920, 864)
	screen = load("res://redesign/main.tscn").instantiate()
	screen.presentation_speed = 0.03
	root.add_child(screen)
	await settle()
	await tap("new_run_setup")
	screen.seed_input.text = "731042"
	await tap("start_single")
	check(screen.page == "run", "touch starts chain edition")
	await capture("initial")
	await tap("load_basic")
	var second: String = screen.model.s.hand[0]
	await tap("load_" + second)
	check(screen.model.s.plan == ["basic", second], "FIFO input order retained")
	await tap_control(screen.magazine_view, Vector2(screen.magazine_view.size.x / 8.0, 65))
	check(screen.model.s.plan == [second], "tap slot removes selected first round")
	await tap("undo")
	await tap("exchange")
	var replaced: String = screen.model.s.hand[0]
	await tap("exchange_" + replaced)
	check(screen.model.s.exchange_left == 0 and screen.model.s.hand.size() == 5, "touch exchanges one round")
	await tap("load_basic")
	await tap("confirm")
	await tap("fire")
	check(screen.model.s.shots == 1, "single touch one shot")
	var saved: Dictionary = screen.model.s.duplicate(true)
	await tap("menu")
	await tap("resume")
	check(JSON.parse_string(JSON.stringify(screen.model.s)) == JSON.parse_string(JSON.stringify(saved)), "new save resumes without changing state")
	await tap("reload")
	check(screen.model.s.exchange_left == 1, "reload restores exchange")
	# Explicit presentation fixture, not a campaign or balance claim.
	screen.debug_session = true
	screen.model.start("burst", 731042)
	screen.model.s.floor = 6
	screen.model.s.part = "supply"
	screen.model.begin_encounter()
	screen.model.s.hand = ["bore", "charge", "precise", "arc", "pierce"]
	screen.model.s.draw = ["mark", "push", "slow", "finish", "bore"]
	screen.redraw()
	await settle()
	for id in ["bore", "charge", "precise", "arc", "pierce"]: await tap("load_" + id)
	check(screen.magazine_view.capacity == 5 and screen.combat_forecast.shots.size() == 5, "fifth slot forecast visible")
	await capture("five_slots")
	await tap("enemy_info_1")
	check(screen.find_child("EnemyDetails", true, false) != null, "enemy details touch")
	await close_dialogs()
	await tap("confirm")
	var forecast: Dictionary = screen.combat_forecast.duplicate(true)
	await tap("fire")
	check(screen.model.s.enemies == forecast.enemies, "forecast matches actual expanded burst")
	check(screen.last_presentation.shown_enemies == screen.model.s.enemies, "visual enemies end at actual state")
	await capture("after_burst")
	screen.model.s.phase = "reward"
	screen.model.s.floor = 1
	screen.model.s.gun = "single"
	screen.model.s.part = "none"
	screen.redraw()
	await capture("reward")
	await tap("reward_supply")
	check(screen.model.capacity() == 5 and screen.model.s.floor == 2, "reward equips expansion and advances")
	var file := FileAccess.open("user://chain_visual_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": passed, "failed": failed, "scope": "PC synthetic touch at 1920x864, actual UI with explicit five-slot fixture; not Android execution"}, "\t"))
	print("CHAIN VISUAL: %d passed / %d failed" % [passed, failed])
	quit(1 if failed else 0)
