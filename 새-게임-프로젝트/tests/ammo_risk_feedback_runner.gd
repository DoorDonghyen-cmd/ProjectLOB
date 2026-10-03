extends "res://tests/ammo_risk_ui_runner.gd"
const Model = preload("res://redesign/model.gd")
const Data = preload("res://redesign/samples/risk_sample_data.gd")
var captured: Array[String] = []

func begin_tap(key: String) -> void:
	var button := screen.find_child(key, true, false) as Button
	check(button != null and not button.disabled, "start input " + key)
	if button == null or button.disabled: return
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func frame_capture(id: String) -> void:
	if captured.has(id): return
	captured.append(id)
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join(id + ".png")) == OK, "action frame " + id)

func watch_action(key: String, prefix: String) -> void:
	await begin_tap(key)
	var view = screen.battle_view
	var start := Time.get_ticks_msec()
	while screen.busy and Time.get_ticks_msec() - start < 15000:
		if not captured.has(prefix + "_layout"):
			captured.append(prefix + "_layout")
			check(Rect2(Vector2.ZERO, screen.size).encloses(screen.find_child("RiskHeader", true, false).get_global_rect()), "busy header fits with skip " + prefix)
		if view.charge_phase > 0.2: await frame_capture(prefix + "_charge")
		if view.boost_value > 0 and view.flash > 0.15: await frame_capture(prefix + "_muzzle")
		if view.impact_power > 0 and view.pulse < 0.5 and not captured.has(prefix + "_impact"):
			var font := load("res://redesign/ui_font.tres") as Font
			var font_size: int = view._damage_font_size()
			var origin: Vector2 = view._damage_position(view.enemy_position(view.float_target))
			var damage_rect := Rect2(origin - Vector2(0, font.get_ascent(font_size)), Vector2(160, font.get_height(font_size)))
			for i in view._alive_indices(): check(not damage_rect.intersects(view.enemy_plaque(i)), "impact number clear of enemy plaque " + prefix)
			check(Rect2(Vector2.ZERO, view.size).encloses(damage_rect), "impact number inside field " + prefix)
			await frame_capture(prefix + "_impact")
		if view.reload_tick > 0 and view.reload_progress > 0.2 and view.reload_progress < 0.8:
			await frame_capture(prefix + ("_cooling" if view.cooling else "_reload"))
		await process_frame
	check(not screen.busy, "action completes " + prefix)
	check(is_equal_approx(Engine.time_scale, 1.0), "visual hold never changes global time")
	await settle()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/ammo_risk/"):
		quit(1)
		return
	screen = load("res://redesign/samples/ammo_risk.tscn").instantiate()
	root.add_child(screen)
	await settle()
	screen.presentation_speed = 1.0
	await tap("confirm")
	await watch_action("fire", "feedback_hot")
	check(captured.has("feedback_hot_charge") and captured.has("feedback_hot_muzzle") and captured.has("feedback_hot_impact"), "charge and amplified shot are rendered at real speed")
	var events: Array = screen.last_presentation.events
	check(events.filter(func(e): return e.kind == "powered_impact" and int(e.boost) == 4).size() == 2, "exactly the two boosted bullets receive +4 impact")
	check(events.filter(func(e): return e.kind == "heat_added").size() == 1, "one heat onset per actual hot round")
	check(screen.battle_view.heat_debt == 1 and screen.battle_view.get_node("HeatReadout").visible, "heat persists after the transient effects finish")
	check(screen.battle_view.impact_power == 0 and screen.battle_view.shot_power == 0, "impact and recoil settle after action")
	for resolution in [Vector2i(1280, 900), Vector2i(1008, 630), Vector2i(1440, 630)]:
		root.size = resolution
		screen.redraw()
		await settle()
		var readout := screen.battle_view.get_node("HeatReadout") as Label
		check(screen.battle_view.get_global_rect().encloses(readout.get_global_rect()), "heat readout inside battlefield " + str(resolution))
		var plaque: Rect2 = screen.battle_view.enemy_plaque(2)
		check(not readout.get_global_rect().intersects(Rect2(plaque.position + screen.battle_view.global_position, plaque.size)), "heat readout clear of enemy info " + str(resolution))
		await capture("feedback_heat_%dx%d" % [resolution.x, resolution.y])
	root.size = Vector2i(1280, 900)
	screen.redraw()
	await settle()
	var prediction: Dictionary = screen.risk_prediction.reload.duplicate(true)
	await watch_action("reload", "feedback_hot")
	events = screen.last_presentation.events
	var ticks: Array = events.filter(func(e): return e.kind == "turn_complete")
	check(ticks.size() == 2 and ticks[0].shown_enemies[2].distance == 16 and ticks[1].shown_enemies[2].distance == 15, "reload shows real 17 to 16 to 15 approach")
	check(events.filter(func(e): return e.kind == "reload_turn").size() == 1 and events.filter(func(e): return e.kind == "cooling_turn").size() == 1, "base and heat turns have distinct feedback")
	check(screen.model.s.enemies == prediction.enemies and screen.last_presentation.shown_enemies == prediction.enemies, "feedback and forecast retain identical resolved enemies")
	check(screen.battle_view.heat_debt == 0 and not screen.battle_view.get_node("HeatReadout").visible, "completed reload clears heat visuals")
	await capture("feedback_cooled")
	await tap("risk_case_1")
	await tap("confirm")
	await watch_action("fire", "feedback_normal")
	check(not captured.has("feedback_normal_charge"), "normal boost has no overheat charge")
	check(screen.last_presentation.events.filter(func(e): return e.kind == "powered_impact" and int(e.boost) == 2).size() == 1, "shielded first boosted bullet does not fake a damaging impact")
	check(screen.last_presentation.events.filter(func(e): return e.kind == "plain_impact" and bool(e.get("blocked", false))).size() == 2, "blocked hits show shield response")
	await watch_action("reload", "feedback_normal")
	check(screen.last_presentation.events.filter(func(e): return e.kind == "cooling_turn").is_empty(), "normal reload has no fake cooling phase")
	await tap("risk_hot")
	await tap("confirm")
	await watch_action("fire", "feedback_shield_hot")
	check(screen.find_child("reload", true, false).text.contains("위험"), "heated lethal reload retains action warning")
	await watch_action("reload", "feedback_lethal")
	check(screen.model.s.phase == "lost", "actual heat contact still ends combat")
	await tap("risk_case_0")
	await tap("risk_motion")
	await tap("confirm")
	await watch_action("fire", "feedback_reduced")
	check(screen.reduced_feedback and screen.battle_view.reduced_feedback, "reduced effects setting survives action redraw")
	check(screen.battle_view.heat_debt == 1, "reduced effects preserve heat information")
	await capture("feedback_reduced_heat")
	await tap("risk_reset")
	await tap("risk_motion")
	await tap("confirm")
	await begin_tap("fire")
	check(screen.busy, "normal presentation is active for skip test")
	var skip_start := Time.get_ticks_msec()
	await tap("skip_animation")
	check(Time.get_ticks_msec() - skip_start < 1800, "skip cancels presentation delay without stalling input")
	check(screen.model.s.reload_heat == 1 and screen.model.s.enemies[2].hp == 13, "skip does not alter combat results")
	root.size = Vector2i(1008, 630)
	await settle()
	await tap("risk_reset")
	await tap("confirm")
	await watch_action("fire", "feedback_mobile")
	await watch_action("reload", "feedback_mobile")
	await _check_event_replay()
	print("AMMO RISK FEEDBACK COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check_event_replay() -> void:
	# Real-model results with burn, stance, charge/pull, interrupted reload and reserves.
	# This verifies the presenter does not invent movement or reorder future damage.
	for case_index in range(6):
		var model = Model.new()
		Data.seed_model(model, 0)
		model.s.phase = "ready"
		model.s.magazine = []
		model.s.reload_heat = 2
		model.s.enemies = [
			{"kind": "caster", "name": "지원", "hp": 20, "max_hp": 20, "def": 0, "speed": 1, "distance": 18, "burn": 0, "lane": 0, "charge": 1, "charge_max": 3, "charge_pull": 2},
			{"kind": "stance", "name": "교대", "hp": 20, "max_hp": 20, "def": 4, "speed": 1, "distance": 18, "burn": 2, "lane": 1, "stance": true, "stance_closed": true, "stance_def": 4},
		]
		if case_index == 1: model.s.enemies[1].distance = 2
		if case_index in [2, 3]:
			model.s.enemies = [model.s.enemies[1]]
			model.s.enemies[0].hp = 1
		if case_index == 3:
			model.s.reinforcements = [{"kind": "runner", "name": "후속", "hp": 8, "max_hp": 8, "def": 0, "speed": 2, "distance": 18, "burn": 0, "lane": 0}]
		if case_index == 4:
			model.s.enemies[0].charge = 2
			model.s.enemies[1].distance = 1
		if case_index == 5:
			var caster: Dictionary = model.s.enemies[0].duplicate(true)
			caster.lane = 2
			model.s.enemies.append(caster)
		var before: Dictionary = model.s.duplicate(true)
		check(model.reload_magazine(), "replay fixture reload " + str(case_index))
		var after: Dictionary = model.s.duplicate(true)
		var immutable := JSON.stringify(after)
		var detail: Dictionary = after.history.back().detail
		var view = load("res://redesign/samples/risk_battle_view.tscn").instantiate()
		root.add_child(view)
		view.speed_scale = 0.02
		await view.play_action(before, after, [], detail.advance_events, true, detail.get("deployments", []))
		check(JSON.stringify(after) == immutable, "presenter never mutates resolved state " + str(case_index))
		check(view.enemies == after.enemies, "display reaches exact model state " + str(case_index))
		var actual_events: Array = view.visual_events.filter(func(e): return e.kind in ["burn", "charge", "pull", "move", "stance"])
		check(actual_events == detail.advance_events, "event order matches real model " + str(case_index))
		check(view.visual_events.filter(func(e): return e.kind == "turn_complete").size() == int(after.turns) - int(before.turns), "no extra turns after terminal state " + str(case_index))
		check(view.heat_debt == 0 and view.reload_tick == 0 and view.march_phase == 0, "reload feedback settles " + str(case_index))
		view.queue_free()
		await process_frame
