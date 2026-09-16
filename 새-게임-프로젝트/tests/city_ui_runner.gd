extends SceneTree
## Replay successful full-city real commands through the visible Godot controls.
const Campaign = preload("res://redesign/campaign.gd")
const Ammo = preload("res://redesign/content.gd")
var screen: Control
var checks := 0
var failures: Array = []
var clicks := 0
var captures: Array = []
var output := ""

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)
	return condition

func settle() -> void:
	for i in range(4): await process_frame
	while is_instance_valid(screen) and screen.busy: await process_frame
	await RenderingServer.frame_post_draw

func fresh() -> void:
	if is_instance_valid(screen): screen.free()
	screen = load("res://redesign/main.tscn").instantiate()
	screen.presentation_speed = 0.01
	root.add_child(screen)
	await settle()

func click(key: String, touch: bool = false) -> bool:
	var control := screen.find_child(key, true, false) as Button
	if not check(control != null and not control.disabled and control.is_visible_in_tree(), "usable button " + key): return false
	if control.get_parent().is_ancestor_of(screen.body) or screen.body.is_ancestor_of(control):
		(screen.get_child(0) as ScrollContainer).ensure_control_visible(control)
		await settle()
	if touch:
		var point: Vector2 = root.get_final_transform() * (control.get_screen_transform() * (control.size * 0.5) - Vector2(DisplayServer.window_get_position()))
		for pressed in [true, false]:
			var event := InputEventScreenTouch.new()
			event.index = 0
			event.position = point
			event.pressed = pressed
			Input.parse_input_event(event)
			await process_frame
	else: control.pressed.emit()
	clicks += 1
	await settle()
	return check(screen.save_error.is_empty(), "save after " + key)

func normalized(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value)))

func capture(label: String) -> void:
	await settle()
	var path := output.path_join(label + ".png")
	check(root.get_texture().get_image().save_png(path) == OK, "capture " + label)
	captures.append(path)
	check(screen.body.size.x <= screen.size.x, "no horizontal overflow " + label)

func key(command: Dictionary) -> String:
	match str(command.action):
		"enter": return "city_enter_" + str(int(command.id))
		"reward": return "city_reward_" + str(command.id)
		"gate": return "city_gate_" + str(command.id)
		"buy": return "city_buy_" + str(int(command.id))
		"reroll": return "city_reroll"
		"resolve":
			if screen.campaign.s.phase == "supply": return "city_refine_" + str(command.ammo)
			if command.id == "sell": return "city_sell_" + str(command.ammo)
			return "city_event_" + str(command.id)
		"leave": return "city_leave"
		"load": return "load_" + str(command.id)
		"confirm": return "confirm"
		"fire": return "fire"
		"reload": return "reload"
	return ""

func replay(expected: Dictionary) -> void:
	# Overwrite only this test's isolated city file; production/legacy saves remain.
	var clean := FileAccess.open(Campaign.SAVE, FileAccess.WRITE)
	clean.store_string("{}")
	clean.close()
	await fresh()
	screen.seed_input.text = str(int(expected.seed))
	screen.course_toggle.button_pressed = false
	if not await click("start_" + str(expected.gun)): return
	check(screen.campaign != null and screen.campaign.s.phase == "map", "normal start opens city map")
	await capture("city_start_" + str(expected.gun))
	var captured: Array = []
	var resumed := false
	for command in expected.commands:
		var phase: String = screen.campaign.s.phase
		if not captured.has(phase) and phase != "combat":
			captured.append(phase)
			await capture("city_" + str(expected.gun) + "_" + phase)
		if not await click(key(command)): return
		if not check(screen.campaign.s.phase == command.phase and int(screen.campaign.s.node) == int(command.node) and int(screen.campaign.s.credits) == int(command.credits) and int(screen.model.s.turns) == int(command.turns), "UI command agrees " + key(command)): return
		if not resumed and int(screen.campaign.s.region) >= 2 and screen.campaign.s.phase == "combat":
			var before := normalized({"campaign": screen.campaign.s, "combat": screen.model.s, "profile": screen.campaign.profile})
			await fresh()
			if not await click("resume"): return
			check(normalized({"campaign": screen.campaign.s, "combat": screen.model.s, "profile": screen.campaign.profile}) == before, "full city disk resume exact")
			resumed = true
		if screen.campaign.s.phase == "combat" and screen.model.capacity() == 6 and command.action == "confirm" and not captured.has("six"):
			captured.append("six")
			await capture("city_six_slot_" + str(expected.gun))
		if screen.campaign.s.phase == "map" and int(screen.campaign.s.region) == 4 and int(screen.campaign.s.floor) == 0:
			await capture("city_summit_map_" + str(expected.gun))
	check(screen.campaign.s.phase == "won", "actual UI reaches final core")
	check(normalized(screen.campaign.s) == normalized(expected.campaign), "full city history agrees")
	check(normalized(screen.model.s) == normalized(expected.combat), "full combat history agrees")
	check(normalized(screen.campaign.profile) == normalized(expected.profile), "full profile awards agree")
	await capture("city_complete_" + str(expected.gun))
	if await click("city_archive"):
		await capture("city_archive_" + str(expected.gun))
		await click("city_unlock_thermal")
		check(screen.campaign.profile.unlocks.has("thermal"), "UI unlocks next-run loadout")
		for child in screen.get_children():
			if child is AcceptDialog: child.queue_free()
		await settle()
	if await click("retry"):
		check(screen.campaign.s.phase == "map" and screen.campaign.absolute_floor() == 0 and screen.model.s.turns == 0, "retry resets whole city")
		check(int(screen.campaign.s.seed) == int(expected.seed), "retry keeps route seed")
		check(screen.campaign.profile.unlocks.has("thermal"), "retry retains profile unlock")
	print("CITY UI RUN " + str(expected.gun) + " complete")

func developer() -> void:
	await fresh()
	var saved: String = FileAccess.get_file_as_string(Campaign.SAVE)
	for scenario in ["map", "shop", "supply", "event", "gate", "ending", "reward"]:
		if screen.page != "menu": await click("menu")
		if not await click("dev"): return
		if not await click("debug_city_" + scenario): return
		check(screen.debug_session, "city developer mode protects save")
		await capture("city_debug_" + scenario)
		if scenario == "map":
			await click("map_node_101", true)
			check(screen.campaign.s.phase == "combat", "touch map destination enters actual combat")
		elif scenario == "shop":
			await click("city_buy_1", true)
			check(screen.campaign.s.parts.size() == 1, "touch shop buys a part")
			await click("city_reroll")
			var candidate := screen.find_child("city_buy_1", true, false) as Button
			check(candidate == null or candidate.disabled, "UI part purchase locked after reroll")
			var funds: int = screen.campaign.s.credits
			await click("city_shop_refine")
			await click("city_refine_pick_push")
			check(screen.model.s.deck.size() == 9 and screen.campaign.s.credits == funds - 12, "UI paid refinement updates deck and wallet")
			check((screen.find_child("city_shop_refine", true, false) as Button).disabled, "UI paid refinement once per visit")
		elif scenario == "supply":
			await click("city_refine_push")
			check(screen.model.s.deck.size() == 9, "service refines actual deck")
		elif scenario == "event": await click("city_service_skip")
		elif scenario == "reward":
			await click("city_reward_refine")
			await click("city_refine_pick_push")
			check(screen.model.s.deck.size() == 9 and screen.campaign.s.credits == 75 and screen.campaign.s.phase == "map", "UI refinement consumes reward and no credit")
		elif scenario == "gate":
			await click("city_gate_slot")
			check(screen.campaign.s.region == 1 and screen.campaign.s.slots == 1, "gate enters next region with expansion")
		check(FileAccess.get_file_as_string(Campaign.SAVE) == saved, "developer never writes real city save")
	await click("menu")
	root.size = Vector2i(1008, 630)
	await settle()

	for scenario in ["map", "shop", "event"]:
		await click("dev")
		await click("debug_city_" + scenario)
		await capture("city_phone_" + scenario)
		check(screen.body.size.x <= screen.size.x, "small landscape fits logical viewport width")
		for key_name in ["menu", "CityMap", "city_leave", "city_buy_1"]:
			var control := screen.find_child(key_name, true, false) as Control
			if control:
				var logical: Rect2 = control.get_global_rect()
				var transform: Transform2D = root.get_final_transform()
				var pixels := Rect2(transform * logical.position, transform.basis_xform(logical.size))
				check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(pixels), "small landscape physical bounds " + key_name)
		await click("menu")
	root.size = Vector2i(1280, 800)
	await settle()

func six_slot_layout(expected: Dictionary) -> void:
	var campaign = Campaign.new()
	campaign.start(str(expected.gun), int(expected.seed))
	var final_capacity := int(Ammo.GUNS[expected.gun].capacity) + 2
	var found := false
	for command in expected.commands:
		var accepted := false
		match str(command.action):
			"enter": accepted = campaign.enter(int(command.id))
			"reward": accepted = campaign.reward(str(command.id))
			"gate": accepted = campaign.gate(str(command.id))
			"buy": accepted = campaign.buy(int(command.id))
			"reroll": accepted = campaign.reroll()
			"resolve": accepted = campaign.resolve(str(command.id), str(command.get("ammo", "")))
			"leave": accepted = campaign.leave()
			"load": accepted = campaign.model.load_round(str(command.id))
			"confirm": accepted = campaign.model.confirm()
			"fire": accepted = campaign.model.fire()
			"reload": accepted = campaign.model.reload_magazine()
		campaign.sync_combat()
		if not check(accepted, "actual path to six-slot layout"): return
		campaign.save("user://layout_probe.json")
		if campaign.s.phase == "combat" and campaign.model.capacity() == final_capacity and command.action == "confirm":
			found = true
			break
	if not check(found, "genuine final-capacity state available"): return
	await fresh()
	screen.save_enabled = false
	screen.debug_session = true
	screen.campaign = campaign
	screen.model = campaign.model
	screen.page = "run"
	screen.redraw()
	await settle()
	await capture("city_six_slot_final_" + str(expected.gun))
	var magazine = screen.magazine_view
	var font: Font = load("res://assets/fonts/NeoDunggeunmoPro-Regular.ttf")
	var width: float = magazine.size.x / float(final_capacity) - 8
	for i in range(magazine.forecast.shots.size()):
		var lines: PackedStringArray = magazine.compact_lines(magazine.forecast, i)
		var shot: Dictionary = magazine.forecast.shots[i]
		if shot.get("random", false):
			check(lines[0] == "무작위" and lines[1] == "%d~%d" % [shot.damage_min, shot.damage_max], "compact random slot retains public damage range")
		else: check(lines[1] == ("처치" if int(shot.hp) == 0 else "HP%d" % int(shot.hp)), "compact line retains exact remaining HP")
		for line in range(3): check(font.get_string_size(lines[line], HORIZONTAL_ALIGNMENT_LEFT, -1, 15 if line == 0 else 14).x <= width, "compact result stays inside its slot")
	for key_name in ["fire", "reload"]:
		var control := screen.find_child(key_name, true, false) as Control
		check(control != null and screen.get_global_rect().encloses(control.get_global_rect()), "six-slot action within viewport")
	root.size = Vector2i(1008, 630)
	await capture("city_six_slot_phone_" + str(expected.gun))
	root.size = Vector2i(1280, 800)
	await settle()
func _run() -> void:
	root.size = Vector2i(1280, 800)
	output = OS.get_environment("QA_OUTPUT_DIR")
	var user_path := ProjectSettings.globalize_path("user://").replace("\\", "/")
	if not check(user_path.contains("/qa_runtime/city/ui/") or user_path.contains("/qa_runtime/city/ui_"), "isolated UI profile"): quit(1); return
	var path := ProjectSettings.globalize_path("res://").path_join("../qa_runtime/city/campaign/city_campaign_report.json")
	if not OS.get_environment("QA_CITY_SOURCE").is_empty(): path = OS.get_environment("QA_CITY_SOURCE")
	elif not FileAccess.file_exists(path): path = ProjectSettings.globalize_path("res://").path_join("../docs/qa/reports/full_city_campaign_2026-09-16_assets/city_campaign_report.json")
	var source = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not check(source is Dictionary and source.get("failures", []).is_empty(), "validated external source"): quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	for expected in source.runs:
		if expected.route == "safe" and int(expected.seed) == 731042 and int(expected.difficulty) == 0:
			if OS.get_environment("QA_CITY_LAYOUT_ONLY") == "1": await six_slot_layout(expected)
			else: await replay(expected)
	if OS.get_environment("QA_CITY_LAYOUT_ONLY") != "1": await developer()
	var report := FileAccess.open(output.path_join("city_ui_report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "clicks": clicks, "captures": captures}, "\t"))
	report.close()
	print("CITY UI COMPLETE checks=" + str(checks) + " failures=" + str(failures.size()) + " buttons=" + str(clicks))
	if is_instance_valid(screen): screen.free()
	quit(0 if failures.is_empty() else 1)
