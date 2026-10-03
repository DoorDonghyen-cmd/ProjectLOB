extends SceneTree
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const Forecast = preload("res://redesign/forecast.gd")
const Feedback = preload("res://redesign/part_feedback.gd")
const Insight = preload("res://redesign/run_insight.gd")
var screen: Control
var checks := 0
var failures := 0
var output := ""
var impact_captured := false
var comparisons: Array = []
var ready_parts_position := Vector2.ZERO

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + label)

func enemy(hp: int = 100, armor: int = 0, lane: int = 0) -> Dictionary:
	return {"kind": "wall", "name": "중장갑체", "hp": hp, "max_hp": hp, "def": armor, "speed": 1, "distance": 24 + lane * 3, "burn": 0, "lane": lane}

func fixture(gun: String, parts: Array, rounds: Array, enemies: Array = []):
	var model = Model.new()
	model.start(gun, 731042)
	model.s.equipped_parts = parts.duplicate()
	model.s.deck = ["charge", "precise", "pierce", "bore", "arc", "push"]
	model.s.hand = []
	for id in rounds:
		if id == "basic": continue
		if model.s.hand.count(id) >= model.s.deck.count(id): model.s.deck.append(id)
		model.s.hand.append(id)
	model.s.draw = model.s.deck.duplicate()
	for id in model.s.hand: model.s.draw.erase(id)
	model.s.discard = []
	model.s.enemies = enemies.duplicate(true) if not enemies.is_empty() else [enemy()]
	model.s.push_left = Content.push_budget(model.s)
	model.s.supply = model.supply_capacity()
	for id in rounds: check(model.load_round(id), "legal fixture load " + id)
	check(Content.valid_part_set(gun, parts), "legal part set " + str(parts))
	return model

func fire(model) -> Array:
	if model.s.phase == "plan": check(model.confirm(), "confirm actual model")
	check(model.fire(), "fire actual model")
	return model.s.history.back().detail.results

func has_effect(shot: Dictionary, id: String) -> bool:
	for effect in shot.get("part_effects", []):
		if effect.id == id: return true
	return false

func settle() -> void:
	for i in range(8): await process_frame
	while screen.busy: await process_frame
	await RenderingServer.frame_post_draw

func tap(key: String, finish: bool = true) -> void:
	var button := screen.find_child(key, true, false) as Button
	check(button != null and button.is_visible_in_tree() and not button.disabled, "public button " + key)
	if button == null or button.disabled: return
	var position := root.get_final_transform() * (button.get_screen_transform() * (button.size * 0.5) - Vector2(DisplayServer.window_get_position()))
	for held in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = position
		event.pressed = held
		Input.parse_input_event(event)
		await process_frame
	if finish: await settle()

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(output.path_join(label + ".png")) == OK, "capture " + label)

func bounds(label: String) -> void:
	check(not screen.main_scroll.get_v_scroll_bar().visible and not screen.main_scroll.get_h_scroll_bar().visible, "no combat scroll " + label)
	for key in ["CombatParts", "BattleView", "QueuePanel", "AmmoGrid", "menu"]:
		var control := screen.find_child(key, true, false) as Control
		check(control != null and Rect2(Vector2.ZERO, screen.size).encloses(control.get_global_rect()), "bounds " + key + " " + label)
	var strip := screen.find_child("CombatParts", true, false) as Control
	var build := screen.find_child("details", true, false) as Control
	check(strip.get_global_rect().end.x <= build.get_global_rect().position.x, "parts and menu do not overlap " + label)

func record_impact(result: Dictionary) -> void:
	if str(result.id) != "precise": return
	check((screen.find_child("CombatParts", true, false) as Control).global_position.is_equal_approx(ready_parts_position), "part locations stay fixed when skip appears")
	check(screen.combat_parts.triad.activated and screen.combat_parts.duplex.activated and screen.combat_parts.igniter.activated, "actual third shot lights its three applied parts")
	check(screen.magazine_view.impact_active and screen.magazine_view.fired_count == 3, "actual bullet slot lights at impact")
	check(int(screen.battle_view.enemies[int(result.target)].focus_hits) == int(result.focus_after), "visible focus equals resolved impact")
	await capture("impact_phone")
	impact_captured = true

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/weapons/ui/"):
		quit(2)
		return
	output = OS.get_environment("QA_OUTPUT_DIR")
	# Conditions are observed from resolved commands, including blocked and capped effects.
	var model = fixture("burst", ["opening", "afterburner", "triad", "duplex", "igniter"], ["charge", "bore", "precise", "pierce"])
	var unchanged := JSON.stringify(model.s)
	var predicted := Forecast.analyze(model.s, true)
	check(JSON.stringify(model.s) == unchanged, "feedback forecast preserves live state and both RNGs")
	check(Feedback.slots(predicted, "opening") == [1] and Feedback.slots(predicted, "afterburner") == [4] and Feedback.slots(predicted, "triad") == [3, 4], "order parts expose the actual next-action slots")
	var shots := fire(model)
	for i in range(shots.size()): check(shots[i].part_effects == predicted.shots[i].part_effects, "predicted effects match actual " + str(i))
	check(Model.new().restore_state(model.s), "new observational fields survive validated restore")
	var saved := Model.new()
	check(saved.restore_state(model.s), "restore observed encounter")
	check(Feedback.highlights(saved.s) == Feedback.highlights(model.s), "debrief survives restore")
	var protected := enemy()
	protected.barrier = 2
	protected.barrier_max = 2
	shots = fire(fixture("single", ["opening"], ["basic"], [protected]))
	check(shots[0].part_effects.is_empty() and shots[0].damage == 0, "fully blocked shot claims no damage part activation")
	shots = fire(fixture("single", ["breaker"], ["basic"], [protected]))
	check(has_effect(shots[0], "breaker") and shots[0].barrier_removed == 2, "barrier removal still lights breaker")
	var capped := enemy()
	capped.burn = 6
	shots = fire(fixture("heavy", ["coil", "inferno"], ["bore"], [capped]))
	check(not has_effect(shots[0], "coil") and not has_effect(shots[0], "inferno"), "capped burn does not invent added duration")
	shots = fire(fixture("heavy", ["coil", "inferno"], ["bore"]))
	check(has_effect(shots[0], "coil") and has_effect(shots[0], "inferno"), "effective duration modifiers are observed")
	shots = fire(fixture("single", ["coil", "duplex"], ["bore", "precise"], [enemy(1), enemy(1, 0, 1)]))
	check(not has_effect(shots[0], "coil") and not has_effect(shots[1], "duplex"), "dead targets do not claim burn or unfired extra hits")
	for item in [["lens", "pierce"], ["capacitor", "arc"], ["rammer", "push"], ["sequencer", "charge"], ["overbore", "basic"], ["arc_splitter", "arc"], ["momentum", "push"], ["executioner", "basic"]]:
		var targets := [enemy(5 if item[0] == "executioner" else 100, 5 if item[0] == "lens" else 0), enemy(100, 0, 1), enemy(100, 0, 2)]
		shots = fire(fixture("heavy", [item[0]], [item[1]], targets))
		check(has_effect(shots[0], item[0]), "applied part observation " + item[0])
	model = fixture("single", [], ["charge", "precise"])
	fire(model)
	var legacy: Dictionary = model.s.duplicate(true)
	for event in legacy.history:
		for shot in event.get("detail", {}).get("results", []): shot.erase("part_effects")
	check(not Feedback.highlights(legacy).is_empty(), "old histories keep combo highlights without fabricated parts")
	var rules_snapshot = preload("res://tests/combat_rules_snapshot.gd")
	check(rules_snapshot.state(model.s) == rules_snapshot.state(legacy), "old golden snapshot differs only by optional presentation data")
	legacy.history.back().detail.results[0].damage += 1
	check(rules_snapshot.state(model.s) != rules_snapshot.state(legacy), "golden comparison still rejects any damage mismatch")
	model.begin_encounter()
	check(Feedback.highlights(model.s).is_empty(), "previous encounter activations do not leak into next debrief")
	# Same scene and same rounds, varying only order or one part.
	for setup in [["boost_first", ["charge", "precise", "pierce"], []], ["boost_late", ["precise", "pierce", "charge"], []], ["burn_first", ["bore", "precise", "pierce"], ["igniter"]], ["burn_late", ["precise", "pierce", "bore"], ["igniter"]], ["with_duplex", ["charge", "precise", "pierce"], ["duplex"]]]:
		model = fixture("burst", setup[2], setup[1], [enemy(100, 1)])
		fire(model)
		comparisons.append({"case": setup[0], "rounds": setup[1], "parts": setup[2], "report": Insight.combat_report(model.s)})
	check(comparisons[0].report.direct > comparisons[1].report.direct, "same rounds gain damage from boost order")
	check(comparisons[2].report.direct > comparisons[3].report.direct, "igniter rewards burn before follow-up shots")
	check(comparisons[4].report.direct > comparisons[0].report.direct, "duplex changes actual build output")
	# Random forecast must include order conditions and invalidate after equipment changes.
	model = fixture("scatter", [], ["charge", "precise", "pierce"])
	var plain := Forecast.analyze(model.s)
	model.s.equipped_parts = ["opening", "afterburner", "triad", "duplex"]
	predicted = Forecast.analyze(model.s)
	shots = fire(model)
	check(predicted.enemies[0].hp_min == model.s.enemies[0].hp and predicted.enemies[0].hp_max == model.s.enemies[0].hp, "one-target scatter includes every order part exactly")
	check(predicted.enemies[0].hp_max != plain.enemies[0].hp_max, "random forecast cache includes equipped parts")
	check(predicted.shots[1].hits == shots[1].hits, "random forecast reflects duplex hit count")
	check(Feedback.slots(predicted, "triad").is_empty() and Feedback.readiness(predicted, "triad").contains("무작위"), "random triggers are not promised as guaranteed")
	for seed_value in range(24):
		model = fixture("scatter", ["opening", "afterburner", "triad"], ["bore", "precise", "arc"], [enemy(18, 1), enemy(25, 2, 1), enemy(35, 0, 2)])
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		model.s.target_rng_state = str(rng.state)
		predicted = Forecast.analyze(model.s)
		fire(model)
		for i in range(3): check(int(model.s.enemies[i].hp) >= int(predicted.enemies[i].hp_min) and int(model.s.enemies[i].hp) <= int(predicted.enemies[i].hp_max), "multi-target actual inside honest range " + str(seed_value))
	# Rendered input and timing checks. Test fixtures do not claim human play evidence.
	root.size = Vector2i(1008, 630)
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	await settle()
	screen.campaign = null
	screen.page = "run"
	screen.model = fixture("burst", ["opening", "afterburner", "triad", "duplex", "igniter"], ["charge", "bore", "precise", "pierce"], [enemy(70), enemy(40, 2, 1)])
	for resolution in [Vector2i(1008, 630), Vector2i(1280, 800), Vector2i(1440, 630)]:
		root.size = resolution
		for scale in [1.0, 1.1]:
			screen.preferences.data.text_scale = scale
			screen.redraw()
			await settle()
			bounds(str(resolution) + " " + str(scale))
	root.size = Vector2i(1008, 630)
	screen.preferences.data.text_scale = 1.0
	screen.redraw()
	await settle()
	await capture("parts_ready_phone")
	await tap("combat_part_triad")
	check(screen.find_child("CombatPartDetails", true, false) != null, "touch opens condition and penalty")
	await capture("part_condition_phone")
	for child in screen.get_children():
		if child is AcceptDialog: child.hide(); child.queue_free()
	await settle()
	await tap("confirm")
	ready_parts_position = (screen.find_child("CombatParts", true, false) as Control).global_position
	screen.presentation_speed = 1.0
	screen.battle_view.shot_impacted.connect(record_impact)
	await tap("fire")
	check(impact_captured, "actual animation impact captured")
	var displayed: Array = screen.last_presentation.events.filter(func(e): return str(e.kind) == "part")
	var expected_count := 0
	for shot in screen.model.s.history.back().detail.results: expected_count += shot.part_effects.size()
	check(displayed.size() == expected_count, "every applied part is presented once with target and bullet")
	await capture("focus_after_phone")
	# A short completed fight verifies the real reward route and detail record button.
	screen.model = fixture("single", ["opening", "afterburner"], ["charge", "precise"], [enemy(10)])
	screen.redraw()
	await settle()
	await tap("confirm")
	screen.presentation_speed = 0.01
	await tap("fire")
	check(screen.model.s.phase == "reward", "completed combat reaches reward")
	check(screen.find_child("BuildHighlight_opening", true, false) != null, "reward exposes current encounter part")
	await capture("debrief_phone")
	await tap("encounter_record")
	check(screen.get_children().any(func(child): return child is AcceptDialog), "full record remains accessible by touch")
	for child in screen.get_children():
		if child is AcceptDialog: child.hide(); child.queue_free()
	await settle()
	# Real campaign header includes currencies; exercise all five slots and its reward route.
	screen.campaign = preload("res://redesign/campaign.gd").new()
	screen.campaign.start("burst", 731042)
	check(screen.campaign.enter(101), "enter campaign combat")
	screen.model = fixture("burst", ["opening", "afterburner", "triad", "duplex", "igniter"], ["charge", "bore", "precise", "pierce"], [enemy(55)])
	screen.campaign.model = screen.model
	screen.campaign.s.equipped_parts = screen.model.s.equipped_parts.duplicate()
	screen.campaign.s.parts = screen.model.s.equipped_parts.duplicate()
	screen.preferences.data.text_scale = 1.1
	screen.redraw()
	await settle()
	bounds("campaign five parts large text")
	await capture("campaign_parts_phone")
	await tap("confirm")
	screen.presentation_speed = 1.0
	await tap("fire", false)
	await tap("skip_animation")
	check(not screen.busy and screen.campaign.s.phase == "reward", "skip finishes feedback and campaign reward transition")
	var highlights := screen.find_children("BuildHighlight_*", "Label", true, false)
	check(highlights.size() == 2, "campaign reward shows at most two relevant build observations")
	var record_button := screen.find_child("encounter_record", true, false) as Button
	var text_width := record_button.get_theme_font("font").get_string_size(record_button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, record_button.get_theme_font_size("font_size")).x
	check(text_width + record_button.get_theme_stylebox("normal").get_minimum_size().x <= record_button.size.x and record_button.size.y <= 64, "record button has room for one readable line")
	await capture("campaign_debrief_phone")
	await tap("encounter_record")
	check(screen.get_children().any(func(child): return child is AcceptDialog), "campaign record reachable by touch")
	var artifact := {"seed": 731042, "comparisons": comparisons, "checks": checks, "failures": failures}
	var file := FileAccess.open(output.path_join("build_feedback_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(artifact, "\t"))
	print("BUILD FEEDBACK COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
