extends SceneTree
const Campaign = preload("res://redesign/campaign.gd")
var screen: Control
var checks := 0
var failures: Array = []
var output := ""

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)

func settle() -> void:
	for i in range(5): await process_frame
	while screen.busy: await process_frame
	await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	await settle()
	var path := output.path_join(label + ".png")
	check(root.get_texture().get_image().save_png(path) == OK, "capture " + label)
	check(screen.body.size.x <= screen.size.x, "no horizontal overflow " + label)

func _run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1008, 630)
	screen = load("res://redesign/main.tscn").instantiate()
	screen.presentation_speed = 0.01
	root.add_child(screen)
	await settle()
	screen._developer()
	await settle()
	var shortcut := screen.find_child("debug_horde_reinforcement", true, false) as Button
	check(shortcut != null and not shortcut.disabled, "horde debug shortcut is available")
	shortcut.emit_signal("pressed")
	await settle()
	check(screen.model.alive_count() == 4 and screen.model.reserve_count() == 4, "four active and four public reserves render")
	check(screen.battle_view.info_buttons.size() == 4 and screen.battle_view.reserve_buttons.size() == 4, "battle targets and reserve icons are inspectable")
	check(screen.battle_view.size.x >= screen.body.size.x - 2.0 and screen.battle_view.size.y >= 210.0, "battlefield uses full width and four readable lanes")
	check(not screen.ammo_inspector.visible, "long ammo prose stays hidden in normal planning")
	check(screen.preview_label.text.contains("증원") and screen.preview_label.text.length() < 48, "forecast is a compact reinforcement summary")
	var reserve_label := screen.find_child("ReinforcementCount", true, false) as Label
	check(reserve_label != null and reserve_label.text.contains("4"), "header exposes reserve count")
	await capture("horde_plan_phone")
	var disclosed_distances: Array = screen.model.s.reinforcements.slice(0, 3).map(func(enemy): return int(enemy.distance))
	screen._confirm()
	await settle()
	await screen._fire()
	await settle()
	check(screen.last_presentation.events.any(func(event): return event.kind == "deployment" and int(event.count) == 3), "deployment receives its own visual event")
	check(screen.model.alive_count() == 4 and screen.model.reserve_count() == 1 and screen.model.s.wave == 2, "front refills and one reserve remains")
	var entered_distances: Array = []
	for index in range(4, 7): entered_distances.append(int(screen.model.s.enemies[index].distance))
	check(entered_distances == disclosed_distances, "new reserve positions match the pre-action disclosure")
	reserve_label = screen.find_child("ReinforcementCount", true, false) as Label
	check(reserve_label != null and reserve_label.text.contains("1"), "header updates after deployment")
	await capture("horde_deployed_phone")
	var reserve_button := screen.find_child("reserve_info_0", true, false) as Button
	check(reserve_button != null, "remaining reserve keeps an inspection target")
	reserve_button.emit_signal("pressed")
	await settle()
	check(screen.find_child("ReinforcementDetails", true, false) != null, "reserve inspection opens concise rules")
	for child in screen.get_children():
		if child is AcceptDialog: child.hide(); child.queue_free()
	await settle()

	var campaign = Campaign.new()
	campaign.start("single", 731042)
	screen.campaign = campaign
	screen.model = campaign.model
	screen.page = "run"
	screen.redraw()
	await settle()
	var combat_node: Dictionary = campaign.current_nodes().filter(func(node): return node.kind in ["combat", "boss"])[0]
	screen.city_ui.inspect_node(int(combat_node.id))
	await settle()
	var formation_count := screen.find_child("FormationCount", true, false) as Label
	check(formation_count != null and formation_count.text.contains("전열") and formation_count.text.contains("증원"), "map inspection previews front and reserve counts")
	await capture("horde_map_preview_phone")

	var report := FileAccess.open(output.path_join("horde_ui_report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	report.close()
	print("HORDE UI COMPLETE checks=%d failures=%d" % [checks, failures.size()])
	screen.free()
	quit(0 if failures.is_empty() else 1)
