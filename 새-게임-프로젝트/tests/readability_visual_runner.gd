extends SceneTree
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
var screen: Control
var checks: Array = []
var failed := 0

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks.append({"passed": ok, "label": label})
	if not ok: failed += 1; printerr("FAIL: " + label)

func settle() -> void:
	for i in range(4): await process_frame
	while screen.busy: await process_frame
	await RenderingServer.frame_post_draw

func touch(control: Control, local := Vector2(-1, -1)) -> void:
	check(control != null, "touch target exists")
	if control == null: return
	var point: Vector2 = root.get_final_transform() * (control.get_screen_transform() * (control.size * 0.5 if local.x < 0 else local) - Vector2(DisplayServer.window_get_position()))
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle()

func tap(key: String) -> void:
	var b := screen.find_child(key, true, false) as Button
	check(b != null and not b.disabled, key + " usable")
	if b and not b.disabled: await touch(b)

func capture(label: String) -> void:
	await settle()
	root.get_texture().get_image().save_png("user://readability_" + label + ".png")
	for key in ["confirm", "fire", "reload", "inspect_slots"]:
		var control := screen.find_child(key, true, false) as Control
		if control: check(screen.get_global_rect().encloses(control.get_global_rect()), key + " inside screen " + label)
	check(screen.body.size.x <= screen.size.x, "no horizontal overflow " + label)

func _run() -> void:
	root.size = Vector2i(1280, 800)
	screen = load("res://redesign/main.tscn").instantiate()
	screen.presentation_speed = 0.02
	root.add_child(screen)
	await settle()
	screen.course_toggle.button_pressed = true
	screen.seed_input.text = "731042"
	await tap("start_single")
	check(screen.model.s.course and screen.model.s.enemies[0].def == 0 and screen.model.s.enemies[0].eva == 0, "course start has no hidden defenses")
	var card := screen.find_child("load_charge", true, false) as Button
	check(card.text.contains("위력") and not card.text.contains("관통") and not card.text.contains("명중"), "intro card shows only active axis")
	check(not screen.ammo_inspector.text.contains("균열") and not screen.ammo_inspector.text.contains("연속"), "intro detail avoids future mechanics")
	await capture("intro")
	await tap("load_charge")
	await tap("load_basic")
	await tap("load_basic")
	check(screen.calculation_label.text.contains("강화 2") and screen.calculation_label.text.contains("7"), "actual boost evidence shown for added basic")
	await capture("boost")
	await tap("inspect_slots")
	var before: Array = screen.model.s.plan.duplicate()
	await touch(screen.magazine_view, Vector2(screen.magazine_view.size.x / 8, 70))
	check(screen.model.s.plan == before and screen.selected_slot == 0, "inspection selects without removing")
	await capture("inspect_mode")
	await tap("inspect_slots")
	await touch(screen.magazine_view, Vector2(screen.magazine_view.size.x / 8, 70))
	check(screen.model.s.plan == ["basic", "basic"], "normal slot touch removes only selected round")
	await tap("undo")
	await tap("undo")
	for id in ["charge", "basic", "basic"]: await tap("load_" + id)
	await tap("confirm")
	await tap("fire")
	var saved: Dictionary = screen.model.s.duplicate(true)
	await tap("menu")
	await tap("resume")
	# Match the disk JSON representation: JSON numbers load as floats.
	check(JSON.parse_string(JSON.stringify(screen.model.s)) == JSON.parse_string(JSON.stringify(saved)), "resume preserves course and full run")
	await tap("fire")
	await tap("fire")
	check(screen.model.s.phase == "reward", "first lesson completed through actual UI")
	await tap("reward_skip")
	check(screen.model.s.floor == 1 and screen.model.s.hand.has("bore") and screen.model.s.hand.has("pierce"), "next lesson provides both new rounds")
	await capture("armor")
	for id in ["bore", "pierce"]: await tap("load_" + id)
	check(screen.calculation_label.text.contains("균열2") and screen.calculation_label.text.contains("관통2"), "crack and penetration linked to target armor")
	await capture("shatter")
	# Explicit display fixture, not a campaign or difficulty claim.
	screen.debug_session = true
	screen.model.start("burst", 731042)
	screen.model.s.floor = 6
	screen.model.s.part = "supply"
	screen.model.begin_encounter()
	screen.model.s.hand = ["bore", "charge", "precise", "arc", "pierce"]
	screen.model.s.draw = ["bore", "mark", "push", "slow", "finish"]
	screen.redraw()
	await settle()
	for id in ["bore", "charge", "precise", "arc", "pierce"]: await tap("load_" + id)
	screen._inspect_slot(3)
	await capture("full_1280")
	check(screen.calculation_label.text.contains("도약") and screen.calculation_label.text.contains("고정"), "secondary target damage explained separately")
	card = screen.find_child("load_precise", true, false) as Button
	check(card.text.contains("2×2") and card.text.contains("관통") and card.text.contains("명중"), "all base stats plus hit count readable without hover")
	root.size = Vector2i(1920, 864)
	await capture("full_phone")
	await tap("confirm")
	await tap("fire")
	check(screen.last_presentation.shown_enemies == screen.model.s.enemies, "presentation ends at actual state")
	await tap("menu")
	screen.course_toggle.button_pressed = false
	await tap("start_single")
	check(not screen.model.s.course and screen.model.s.deck.size() == 10, "ordinary run selected explicitly")
	var normal_save := FileAccess.get_file_as_string(screen.SAVE)
	await tap("menu")
	await tap("dev")
	await tap("debug_lesson_3")
	check(screen.debug_session and screen.model.s.course and screen.model.s.floor == 3 and screen.model.s.hand.has("mark"), "accuracy lesson shortcut has usable new round")
	await capture("accuracy_lesson")
	check(FileAccess.get_file_as_string(screen.SAVE) == normal_save, "lesson shortcut preserves actual save")
	var file := FileAccess.open("user://readability_visual.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed, "scope": "PC rendered synthetic touch, real first two lessons and explicit late-game layout fixture; no APK"}, "\t"))
	print("READABILITY VISUAL: %d checks / %d failed" % [checks.size(), failed])
	quit(1 if failed else 0)
