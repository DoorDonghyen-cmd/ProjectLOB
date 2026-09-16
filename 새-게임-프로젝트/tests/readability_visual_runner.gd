extends SceneTree
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
	var button := screen.find_child(key, true, false) as Button
	check(button != null and not button.disabled, key + " usable")
	if button and not button.disabled: await touch(button)

func capture(label: String) -> void:
	await settle()
	var image := root.get_texture().get_image()
	check(image != null and not image.is_empty(), "rendered capture " + label)
	if image != null and not image.is_empty(): check(image.save_png("user://readability_" + label + ".png") == OK, "capture saved " + label)
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
	var first_enemy: Dictionary = screen.model.s.enemies[0]
	check(screen.model.s.course and first_enemy.def == 0 and not first_enemy.has("eva") and not first_enemy.has("slow") and not first_enemy.has("crack"), "course starts with simplified enemy state")
	var card := screen.find_child("load_charge", true, false) as Button
	var card_info = card.find_child("CardInfo", true, false)
	check(card_info != null and card_info.stat_items().size() == 1 and card_info.stat_items()[0].kind == "damage", "intro card shows only damage icon")
	check(card_info.attribute_data().kind == "physical" and card_info.effect_data().kind == "boost", "intro card separates attribute and boost effect")
	check(not screen.ammo_inspector.text.contains("명중") and not screen.ammo_inspector.text.contains("회피") and not screen.ammo_inspector.text.contains("균열"), "intro copy contains no removed axes")
	await capture("elemental_intro")
	await tap("load_charge")
	await tap("load_basic")
	await tap("load_basic")
	check(screen.calculation_label.text.contains("증폭 2") and screen.calculation_label.text.contains("= 7"), "actual amplified damage evidence shown")
	await capture("elemental_amplify")
	await tap("inspect_slots")
	var before: Array = screen.model.s.plan.duplicate()
	await touch(screen.magazine_view, Vector2(screen.magazine_view.size.x / 8, 70))
	check(screen.model.s.plan == before and screen.selected_slot == 0, "inspection selects without removing")
	await tap("inspect_slots")
	await touch(screen.magazine_view, Vector2(screen.magazine_view.size.x / 8, 70))
	check(screen.model.s.plan == ["basic", "basic"], "normal slot touch removes selected round")
	await tap("undo")
	await tap("undo")
	for id in ["charge", "basic", "basic"]: await tap("load_" + id)
	await tap("confirm")
	await tap("fire")
	var saved: Dictionary = screen.model.s.duplicate(true)
	await tap("menu")
	await tap("resume")
	check(JSON.parse_string(JSON.stringify(screen.model.s)) == JSON.parse_string(JSON.stringify(saved)), "resume preserves v3 course state")
	await tap("fire")
	await tap("fire")
	check(screen.model.s.phase == "reward", "first simplified lesson completed through UI")
	var reward_card = screen.find_child("RewardCardInfo", true, false)
	check(reward_card != null and reward_card.stat_items().size() == 1, "reward reuses staged ammo icons")
	await capture("elemental_reward")
	await tap("reward_skip")
	check(screen.model.s.floor == 1 and screen.model.s.hand.has("pierce"), "armor lesson provides iron-piercing round")
	card = screen.find_child("load_pierce", true, false) as Button
	card_info = card.find_child("CardInfo", true, false)
	check(card_info.stat_items().size() == 2 and card_info.stat_items()[1].kind == "penetration", "armor lesson adds only penetration axis")
	await capture("elemental_armor")

	# Explicit late-game layout fixture; no campaign claim.
	screen.debug_session = true
	screen.model.start("burst", 731042)
	screen.model.s.floor = 6
	screen.model.s.part = "supply"
	screen.model.begin_encounter()
	screen.model.s.deck = ["bore", "charge", "precise", "arc", "pierce", "push"]
	screen.model.s.hand = ["bore", "charge", "precise", "arc", "pierce"]
	screen.model.s.draw = ["push"]
	screen.model.s.discard = []
	screen.redraw()
	await settle()
	for id in ["bore", "charge", "precise", "arc", "pierce"]: await tap("load_" + id)
	screen._inspect_slot(3)
	check(screen.calculation_label.text.contains("전이") and screen.calculation_label.text.contains("고정"), "electric secondary damage explained separately")
	card = screen.find_child("load_precise", true, false) as Button
	card_info = card.find_child("CardInfo", true, false)
	var precise_stats: Array = card_info.stat_items() if card_info else []
	check(precise_stats.size() == 2 and precise_stats[0].value == "2×2" and precise_stats[1].kind == "penetration", "late cards retain exactly two base stat icons")
	check(card_info.attribute_data().kind == "physical", "attribute badge remains independent of effect")
	await capture("elemental_full_1280")
	root.size = Vector2i(1920, 864)
	await capture("elemental_full_phone")
	await tap("confirm")
	await tap("fire")
	check(screen.last_presentation.shown_enemies == screen.model.s.enemies, "presentation ends at actual elemental state")

	# Developer shortcuts expose all rounds and burn timing while preserving the actual save.
	await tap("menu")
	screen.course_toggle.button_pressed = false
	await tap("start_single")
	check(not screen.model.s.course and screen.model.s.deck.size() == 10, "ordinary run selected explicitly")
	var normal_save := FileAccess.get_file_as_string(screen.SAVE)
	await tap("menu")
	await tap("dev")
	await tap("debug_icon_cards")
	var icon_cards := screen.find_children("CardInfo", "Control", true, false)
	check(icon_cards.size() == 7, "attribute gallery exposes all seven ammo cards")
	var attributes := {}
	for info in icon_cards: attributes[info.attribute_data().kind] = true
	check(attributes.keys().size() == 3 and attributes.has("physical") and attributes.has("fire") and attributes.has("electric"), "gallery exposes exactly three attributes")
	await capture("elemental_icon_cards")
	check(FileAccess.get_file_as_string(screen.SAVE) == normal_save, "attribute gallery preserves actual save")
	await tap("menu")
	await tap("dev")
	await tap("debug_burn_tick")
	check(screen.debug_session and screen.model.s.phase == "ready" and screen.model.s.magazine == ["bore"], "burn shortcut opens interactive ready state")
	await capture("elemental_burn_before")
	await tap("fire")
	check(screen.last_presentation.events.any(func(event): return event.kind == "burn"), "burn tick receives dedicated presentation event")
	check(screen.model.s.enemies[0].burn == 2 and screen.model.s.enemies[0].distance == 4, "burn resolves before survivor movement")
	await capture("elemental_burn_after")
	check(FileAccess.get_file_as_string(screen.SAVE) == normal_save, "burn shortcut preserves actual save")

	var file := FileAccess.open("user://readability_visual.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failed": failed, "scope": "PC rendered synthetic touch, simplified first lesson, elemental cards, burn timing and late layout; no APK"}, "\t"))
	print("READABILITY VISUAL: %d checks / %d failed" % [checks.size(), failed])
	quit(1 if failed else 0)
