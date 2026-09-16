extends SceneTree
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const Campaign = preload("res://redesign/campaign.gd")
const Forecast = preload("res://redesign/forecast.gd")
var screen: Control
var checks := 0
var failures: Array = []
var captures: Array = []
var output := ""

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("FAIL: " + label)
	return condition

func _initialize() -> void:
	_run.call_deferred()

func settle() -> void:
	for i in range(4): await process_frame
	while screen.busy: await process_frame
	await RenderingServer.frame_post_draw

func click(key: String) -> bool:
	var button := screen.find_child(key, true, false) as Button
	if not check(button != null and not button.disabled and button.is_visible_in_tree(), "usable control " + key): return false
	var ancestor: Node = button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(button)
			await settle()
			break
		ancestor = ancestor.get_parent()
	var point: Vector2 = root.get_final_transform() * (button.get_screen_transform() * (button.size * 0.5) - Vector2(DisplayServer.window_get_position()))
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle()
	return true

func capture(label: String) -> void:
	await settle()
	var path := output.path_join(label + ".png")
	check(root.get_texture().get_image().save_png(path) == OK, "capture " + label)
	captures.append(path)
	check(screen.body.size.x <= screen.size.x, "no horizontal overflow " + label)

func close_dialogs() -> void:
	for child in screen.get_children():
		if child is AcceptDialog: child.hide(); child.queue_free()
	await settle()

func viewport_controls(keys: Array) -> void:
	for key in keys:
		var control := screen.find_child(key, true, false) as Control
		if not check(control != null, "control exists " + key): continue
		var ancestor: Node = control.get_parent()
		while ancestor != null:
			if ancestor is ScrollContainer:
				ancestor.ensure_control_visible(control)
				await settle()
				break
			ancestor = ancestor.get_parent()
		var logical: Rect2 = control.get_global_rect()
		var transform: Transform2D = root.get_final_transform()
		var pixels := Rect2(transform * logical.position, transform.basis_xform(logical.size))
		check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(pixels), "visible viewport control " + key)

func _run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	if not check(ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/weapons/ui/"), "isolated UI save"): quit(1); return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 800)
	screen = load("res://redesign/main.tscn").instantiate()
	screen.presentation_speed = 0.01
	root.add_child(screen)
	await settle()
	# Save sentinel, then exercise developer sessions without writing either save.
	for path in [Campaign.SAVE, screen.SAVE]:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string("weapon QA sentinel")
		file.close()
	screen.redraw()
	await settle()
	await capture("weapon_selection")
	var buttons: Array = ["start_single", "start_burst", "start_scatter", "start_heavy", "start_amplifier", "dev"]
	# Invalid-save notices add height; all starts should still be reachable.
	await viewport_controls(buttons)
	for gun in Content.GUNS:
		if not await click("weapon_info_" + gun): break
		check(screen.find_child("WeaponDetails", true, false) != null, "weapon rules and starting deck dialog")
		await capture("weapon_details_" + gun)
		await close_dialogs()
	root.size = Vector2i(1008, 630)
	await capture("weapon_selection_phone")
	await viewport_controls(buttons)
	root.size = Vector2i(1280, 800)
	await settle()
	for gun in Content.GUNS:
		if screen.page != "menu": await click("menu")
		if not await click("dev"): break
		if not await click("debug_weapon_" + gun): break
		check(screen.debug_session and screen.model.s.gun == gun, "weapon shortcut uses actual gun and preserves save")
		check(Model.new().restore_state(screen.model.s), "valid owned zones in developer fixture")
		await capture("weapon_combat_" + gun)
		var prediction := Forecast.analyze(screen.model.s)
		if not await click("confirm"): break
		var actual = Model.new()
		actual.s = screen.model.s.duplicate(true)
		actual.fire()
		if not await click("fire"): break
		check(screen.model.s.enemies == actual.s.enemies and screen.model.s.shots == actual.s.shots and screen.model.s.turns == actual.s.turns, "visible fire resolves exact model state")
		check(screen.last_presentation.shown_enemies == screen.last_presentation.after.enemies, "weapon animation ends at actual enemy state")
		check(screen.find_child("WeaponIdentity", true, false) != null, "combat shows gun identity")
		if gun == "scatter":
			check(prediction.random and prediction.shots[0].target == -1 and screen.battle_view.first_shot.is_empty(), "random preview never draws a predetermined primary target")
			check(screen.last_presentation.events.filter(func(event): return event.kind == "secondary" and event.get("effect", "") == "spread").is_empty(), "random weapon produces no distance spread")
		await capture("weapon_fired_" + gun)
		root.size = Vector2i(1008, 630)
		await capture("weapon_combat_phone_" + gun)
		await viewport_controls(["menu", "fire", "reload"] if screen.model.s.phase == "ready" else ["menu"])
		root.size = Vector2i(1280, 800)
		await settle()
		for path in [Campaign.SAVE, screen.SAVE]: check(FileAccess.get_file_as_string(path) == "weapon QA sentinel", "developer save sentinel intact")
	await click("menu")
	await click("dev")
	await click("debug_weapon_selection")
	check(screen.page == "menu" and screen.find_child("start_amplifier", true, false) != null, "weapon selection debug shortcut")
	# Narrow maximum magazines use the real owned developer fixture.
	await click("dev")
	await click("debug_weapon_scatter")
	screen.model.s.capacity_bonus = 2
	screen.model.s.supply = 7
	for i in range(4): check(screen.model.load_round("basic"), "seven slot UI fixture loads")
	for slots in [7, 8]:
		if slots == 8:
			screen.model.s.part = "supply"
			screen.model.s.supply = 8
			check(screen.model.load_round("basic"), "legacy eighth slot UI fixture loads")
		check(Model.new().restore_state(screen.model.s), "maximum UI fixture ownership valid")
		screen.redraw()
		root.size = Vector2i(1008, 630)
		await capture("weapon_scatter_" + str(slots) + "_slots_phone")
		var font: Font = load("res://assets/fonts/NeoDunggeunmoPro-Regular.ttf")
		var slot_width: float = screen.magazine_view.size.x / float(slots) - 8
		for i in range(screen.magazine_view.forecast.shots.size()):
			var lines: PackedStringArray = screen.magazine_view.compact_lines(screen.magazine_view.forecast, i)
			for line in range(3): check(font.get_string_size(lines[line], HORIZONTAL_ALIGNMENT_LEFT, -1, 15 if line == 0 else 14).x <= slot_width, "random compact text inside maximum slot")
		await viewport_controls(["menu", "confirm"])
	root.size = Vector2i(1280, 800)
	await click("menu")
	# Normal starts preserve selection, deck ownership and resume.
	for gun in Content.GUNS:
		screen.seed_input.text = "731042"
		if not await click("start_" + gun): break
		check(screen.campaign.s.phase == "map" and screen.campaign.s.gun == gun and screen.model.s.deck == Content.start_deck(gun), "normal weapon starts full city with own deck")
		await click("menu")
		await click("resume")
		check(screen.campaign.s.gun == gun, "resume retains weapon")
		await click("menu")
	var file := FileAccess.open(output.path_join("weapon_ui_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "captures": captures}, "\t"))
	file.close()
	print("WEAPON UI COMPLETE checks=" + str(checks) + " failures=" + str(failures.size()))
	screen.free()
	quit(0 if failures.is_empty() else 1)
