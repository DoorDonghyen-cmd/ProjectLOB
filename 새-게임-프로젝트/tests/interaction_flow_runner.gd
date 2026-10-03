extends SceneTree
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const Forecast = preload("res://redesign/forecast.gd")
var screen: Control
var checks := 0
var failures := 0
var output := ""

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + label)

func settle() -> void:
	for i in range(6): await process_frame
	while screen.busy: await process_frame
	await RenderingServer.frame_post_draw

func point(control: Control, local: Vector2) -> Vector2:
	return root.get_final_transform() * (control.get_screen_transform() * local - Vector2(DisplayServer.window_get_position()))

func press(control: Control, local: Vector2) -> void:
	var position := point(control, local)
	for held in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = position
		event.pressed = held
		Input.parse_input_event(event)
		await process_frame
	await settle()

func tap(key: String) -> void:
	var control := screen.find_child(key, true, false) as Control
	check(control != null and control.is_visible_in_tree(), "visible touch " + key)
	if control == null: return
	if control is Button:
		check(not control.disabled, "enabled touch " + key)
		if control.disabled: return
	await press(control, control.size * 0.5)

func slot(index: int) -> void:
	var rail: Control = screen.magazine_view
	var entry: Dictionary = rail.layout()[index]
	await press(rail, Vector2((float(entry.start) + 0.5) * rail.size.x / rail.capacity, rail.size.y * 0.5))

func drag_slot(from: int, to: int) -> void:
	var rail: Control = screen.magazine_view
	var a := point(rail, Vector2((from + 0.5) * rail.size.x / rail.capacity, rail.size.y * 0.5))
	var b := point(rail, Vector2((to + 0.5) * rail.size.x / rail.capacity, rail.size.y * 0.5))
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.position = a
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	var previous := a
	for i in range(1, 13):
		var motion := InputEventScreenDrag.new()
		motion.index = 0
		motion.position = a.lerp(b, float(i) / 12.0)
		motion.relative = motion.position - previous
		previous = motion.position
		Input.parse_input_event(motion)
		await process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.position = b
	up.pressed = false
	Input.parse_input_event(up)
	await settle()

func capture(label: String) -> void:
	await settle()
	check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "capture " + label)
	check(not screen.main_scroll.get_v_scroll_bar().visible, "no page overflow " + label)

func close_dialogs() -> void:
	for child in screen.get_children():
		if child is AcceptDialog: child.hide(); child.queue_free()
	await settle()

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/weapons/ui/"):
		quit(2)
		return
	output = OS.get_environment("QA_OUTPUT_DIR")
	root.size = Vector2i(1008, 630)
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.01
	root.add_child(screen)
	await settle()
	for gun in Content.GUNS:
		screen._debug_weapon(gun)
		await settle()
		var before := JSON.stringify(screen.model.s)
		var next: Dictionary = Forecast.analyze(screen.model.s, true)
		check(JSON.stringify(screen.model.s) == before, "forecast does not mutate state or RNG " + gun)
		var actual = Model.new()
		actual.s = screen.model.s.duplicate(true)
		actual.confirm()
		actual.fire()
		if gun != "scatter":
			check(next.enemies == actual.s.enemies and next.remaining == actual.s.magazine, "next forecast matches one real fire " + gun)
			check(next.turns == 1, "next forecast is exactly one turn " + gun)
		else:
			check(next.random and next.turns == 1, "scatter retains honest one-action probability")
	screen._debug_weapon("amplifier")
	await settle()
	check(screen.full_forecast.turns > screen.next_forecast.turns, "single-shot fixture exposes different horizons")
	check(screen.combat_forecast == screen.next_forecast, "default battlefield uses next action")
	await tap("forecast_scope")
	check(screen.combat_forecast == screen.full_forecast, "explicit complete magazine view")
	await capture("amplifier_full")
	await tap("forecast_scope")
	await tap("confirm")
	check((screen.find_child("fire", true, false) as Button).text.contains("1발"), "trigger count matches first survivor stop")
	await slot(1)
	await tap("inspect_slots")
	check(screen.find_child("SlotDetails", true, false) != null, "ready slot detail is visible without a mode toggle")
	await close_dialogs()
	await capture("amplifier_next")
	var expected: Dictionary = screen.next_forecast.duplicate(true)
	await tap("fire")
	check(screen.model.s.enemies == expected.enemies and screen.model.s.magazine == expected.remaining, "visible one-tap outcome matches displayed preview")
	await capture("amplifier_fired")
	# A kill can legally continue within the same single-shot trigger.
	var chain = Model.new()
	chain.start("amplifier", 617)
	chain.s.hand = ["pierce", "precise"]
	chain.s.enemies[0].hp = 1
	chain.load_round("pierce")
	chain.load_round("precise")
	var kill_preview: Dictionary = Forecast.analyze(chain.s, true)
	chain.confirm()
	chain.fire()
	check(kill_preview.enemies == chain.s.enemies and kill_preview.shots.size() == chain.s.history.back().detail.results.size(), "kill continuation shares one-action forecast")
	# Stable duplicate slots and order editing through real touch.
	screen._debug_weapon("single")
	while not screen.model.s.plan.is_empty(): screen.model.undo()
	screen.model.s.hand = ["charge", "charge", "precise", "pierce", "push"]
	screen.model.s.field_compression_left = 1
	screen.hand_layout_key = ""
	screen.redraw()
	await settle()
	var original: Rect2 = (screen.find_child("load_pierce", true, false) as Control).get_global_rect()
	await tap("load_charge_2")
	check((screen.find_child("load_charge_2", true, false) as Button).disabled and not (screen.find_child("load_charge", true, false) as Button).disabled, "only tapped duplicate becomes held")
	check(original.is_equal_approx((screen.find_child("load_pierce", true, false) as Control).get_global_rect()), "other hand cards do not move after load")
	await tap("load_precise")
	await tap("load_pierce")
	var turns: int = screen.model.s.turns
	await slot(0)
	check(screen.model.s.plan == ["charge", "precise", "pierce"], "slot tap selects without removing")
	await tap("slot_next")
	check(screen.model.s.plan == ["precise", "charge", "pierce"], "tap order edit")
	await drag_slot(0, 2)
	check(screen.model.s.plan == ["charge", "pierce", "precise"], "touch drag reorders the firing rail")
	check(screen.model.s.turns == turns, "editing spends no turns")
	await capture("combat_edit")
	await tap("undo")
	check(screen.model.s.plan == ["charge", "pierce"], "end recall removes the rightmost round after a reorder")
	await tap("remove_selected")
	check(screen.model.s.plan.size() == 1, "explicit selected removal")
	while not screen.model.s.plan.is_empty(): await tap("undo")
	await tap("compress_pair_charge")
	check(not screen.model.s.field_compression.is_empty(), "button compression uses a real pair")
	check(original.is_equal_approx((screen.find_child("load_pierce", true, false) as Control).get_global_rect()), "compression keeps other card positions")
	await tap("remove_selected")
	check(screen.model.s.hand.count("charge") == 2 and screen.model.s.field_compression_left == 1, "compression cancellation restores both cards and charge")
	check(original.is_equal_approx((screen.find_child("load_pierce", true, false) as Control).get_global_rect()), "cancel keeps the hand stable")
	# Anchor constraints and saved plan validity use the actual model.
	var anchored = Model.new()
	anchored.start("single", 617)
	anchored.s.plan = ["basic", "basic"]
	anchored.s.plan_load_order = ["basic", "basic"]
	check(anchored.move_planned(0, 1), "ordinary order move accepted")
	check(Model.new().restore_state(anchored.s), "edited state restores through save validator")
	for id in Content.AMMO:
		if Content.anchor(id) == "first":
			anchored.s.plan = [id, "basic"]
			check(not anchored.move_planned(0, 1), "front anchor cannot move behind another bullet")
		elif Content.anchor(id) == "last":
			anchored.s.plan = ["basic", id]
			check(not anchored.move_planned(1, 0), "rear anchor cannot move ahead of another bullet")
	screen._debug_city("shop")
	await settle()
	check(screen.find_children("city_buy_?", "Button", true, false).is_empty(), "no duplicate per-product buy buttons")
	await tap("city_part_info_1")
	var credits: int = screen.campaign.s.credits
	var price: int = screen.campaign.s.offers[1].price
	await tap("city_compare_buy_1")
	check(screen.campaign.s.credits == credits - price, "one comparison purchase charges once")
	check(not screen.campaign.buy(1), "sold item rejects repeated purchase")
	await capture("shop")
	screen._debug_city("deck")
	await settle()
	await tap("city_part_select_overbore")
	var effects := screen.find_child("PartEffectChanges", true, false) as Label
	check(effects != null and effects.text.contains("잃음  교전마다 현장 압축 +1회") and effects.text.contains("해제  탄창 −2칸") and effects.text.contains("얻음  피해·관통 +2"), "comparison exposes gain, lost rule, and released penalty")
	await capture("parts_compare")
	await tap("city_deck_equip_overbore")
	check(screen.campaign.is_equipped("overbore") and not screen.campaign.is_equipped("field_press") and screen.campaign.s.parts.has("field_press"), "atomic replacement preserves removed part")
	screen._close_workspace()
	screen._to_menu()
	await settle()
	await tap("new_run_setup")
	check(not (screen.find_child("PreparationOptions", true, false) as Control).visible, "advanced settings collapsed by default")
	await capture("preparation")
	await tap("preparation_options")
	check((screen.find_child("Seed", true, false) as Control).is_visible_in_tree(), "seed remains accessible")
	await tap("preparation_options")
	await tap("starting_detail_charge")
	check(screen.find_child("StartingRoundDetails", true, false) != null, "starting ammunition has explicit touch detail")
	await close_dialogs()
	print("INTERACTION FLOW COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
