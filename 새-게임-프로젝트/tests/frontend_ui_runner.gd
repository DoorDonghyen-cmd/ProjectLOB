extends SceneTree
## Focused visual and interaction check for title -> loadout preparation.

var screen: Control
var checks := 0
var failures: Array[String] = []
var output := ""

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)

func settle() -> void:
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw

func click(key: String) -> void:
	var control := screen.find_child(key, true, false) as Button
	check(control != null, "button exists: " + key)
	if control == null:
		return
	check(control.is_visible_in_tree() and not control.disabled, "button usable: " + key)
	if not control.is_visible_in_tree() or control.disabled:
		return
	control.pressed.emit()
	await settle()

func capture(label: String) -> void:
	await settle()
	var path := output.path_join(label + ".png")
	check(root.get_texture().get_image().save_png(path) == OK, "capture: " + label)
	check(screen.body.size.x <= screen.size.x + 1.0, "no horizontal overflow: " + label)

func _run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 800)
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	await settle()
	check(screen.find_child("TitleHero", true, false) != null, "title has authored hero")
	check(screen.find_child("new_run_setup", true, false) != null, "title exposes primary new-run action")
	check(screen.find_child("WeaponSelection", true, false) == null, "title does not expose setup form")
	await capture("frontend_title")

	await click("new_run_setup")
	check(screen.page == "loadout", "new run opens preparation screen")
	check(screen.find_child("WeaponSelection", true, false) != null, "preparation exposes weapon rail")
	check(screen.find_child("SelectedWeaponPanel", true, false) != null, "preparation exposes selected weapon showcase")
	check(screen.find_child("start_single", true, false) != null, "preparation has one final launch action")
	await capture("frontend_loadout_default")

	await click("weapon_select_amplifier")
	check(screen.selected_weapon_id == "amplifier", "weapon card changes the selected identity")
	check(screen.find_child("start_amplifier", true, false) != null, "launch action follows selected weapon")
	var launch := screen.find_child("start_amplifier", true, false) as Control
	(screen.main_scroll as ScrollContainer).ensure_control_visible(launch)
	await capture("frontend_loadout_confirm")

	root.size = Vector2i(1008, 630)
	screen.redraw()
	await settle()
	check((screen.find_child("WeaponSelection", true, false) as GridContainer).columns == 5, "logical landscape keeps all five weapons visible")
	await capture("frontend_loadout_phone")

	await click("loadout_back")
	await click("training_setup")
	check(screen.page == "loadout" and screen.preparation_training, "training uses the same preparation room")
	check(screen.find_child("start_amplifier", true, false) != null, "training keeps the chosen weapon")
	await capture("frontend_training")
	await click("start_amplifier")
	check(screen.page == "run" and screen.campaign == null and screen.model.s.gun == "amplifier", "training launch enters the selected weapon run")

	print("FRONTEND UI CHECKS %d FAILURES %d" % [checks, failures.size()])
	quit(1 if not failures.is_empty() else 0)
