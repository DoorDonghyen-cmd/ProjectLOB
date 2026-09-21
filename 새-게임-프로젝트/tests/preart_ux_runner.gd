extends SceneTree
## Focused regression for the player-facing pre-art UX layer.

const Campaign = preload("res://redesign/campaign.gd")
const Preferences = preload("res://redesign/preferences.gd")
var screen: Control
var checks := 0
var failures: Array = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)

func settle() -> void:
	for i in range(5): await process_frame

func fresh() -> void:
	if is_instance_valid(screen): screen.free()
	screen = load("res://redesign/main.tscn").instantiate()
	root.add_child(screen)
	await settle()

func press(key: String) -> void:
	var button := screen.find_child(key, true, false) as Button
	check(button != null and not button.disabled and button.is_visible_in_tree(), "usable " + key)
	if button != null and not button.disabled:
		button.pressed.emit()
		await settle()

func close_dialogs() -> void:
	for child in screen.get_children():
		if child is AcceptDialog:
			child.hide()
			child.queue_free()
	await settle()

func _run() -> void:
	var output := OS.get_environment("QA_OUTPUT_DIR")
	var user_path := ProjectSettings.globalize_path("user://").replace("\\", "/")
	check(user_path.contains("qa_runtime"), "isolated user profile")
	DirAccess.make_dir_recursive_absolute(output)

	var settings_path := output.path_join("preferences_probe.json")
	var preferences := Preferences.new()
	check(not preferences.load_preferences(settings_path), "missing preferences use defaults")
	check(preferences.data.text_scale == 1.0 and preferences.data.motion == "normal" and preferences.data.hints, "default accessibility values")
	preferences.data.text_scale = 1.1
	preferences.data.motion = "instant"
	preferences.data.hints = false
	check(preferences.save_preferences(settings_path) == OK, "preferences save atomically")
	var restored := Preferences.new()
	check(restored.load_preferences(settings_path), "preferences reload")
	check(restored.data.text_scale == 1.1 and restored.motion_scale() == 0.05 and not restored.data.hints, "preferences round trip")

	await fresh()
	for key in ["first_guide", "guide", "settings", "start_single", "resume"]:
		check(screen.find_child(key, true, false) != null, "menu exposes " + key)
	await press("guide")
	check(screen.find_child("FirstGuide", true, false) != null, "first guide opens")
	check(screen.preferences.data.guide_seen, "opening guide records completion")
	await close_dialogs()
	await press("settings")
	check(screen.find_child("SettingsDialog", true, false) != null, "settings opens")
	var scale := screen.find_child("TextScaleSetting", true, false) as OptionButton
	var motion := screen.find_child("MotionSetting", true, false) as OptionButton
	var hints := screen.find_child("ContextHintsSetting", true, false) as CheckButton
	check(scale != null and motion != null and hints != null, "all accessibility controls visible")
	scale.select(2)
	scale.item_selected.emit(2)
	motion.select(2)
	motion.item_selected.emit(2)
	hints.button_pressed = false
	hints.toggled.emit(false)
	await settle()
	check(screen.preferences.data.text_scale == 1.1 and is_equal_approx(screen.presentation_speed, 0.05) and not screen.preferences.data.hints, "settings apply immediately")
	await close_dialogs()
	await fresh()
	check(screen.preferences.data.text_scale == 1.1 and screen.preferences.data.motion == "instant" and not screen.preferences.data.hints, "screen restores accessibility settings")

	# Keep an unfinished run, then verify that choosing another weapon cannot silently replace it.
	var active := Campaign.new()
	active.start("single", 731042)
	check(active.save() == OK, "active city fixture saved")
	await fresh()
	await press("start_burst")
	var confirm := screen.find_child("NewRunConfirmation", true, false) as ConfirmationDialog
	check(confirm != null and screen.page == "menu", "new run replacement requires confirmation")
	if confirm != null:
		confirm.canceled.emit()
		await settle()
	check(screen.page == "menu", "cancel keeps current run")
	await press("start_burst")
	confirm = screen.find_child("NewRunConfirmation", true, false) as ConfirmationDialog
	if confirm != null:
		confirm.confirmed.emit()
		await settle()
	check(screen.page == "run" and screen.campaign != null and screen.campaign.s.gun == "burst", "confirm starts selected weapon")
	check(screen.find_child("RunStatusBar", true, false) != null, "city state bar visible")

	# Android/system Back behavior closes a modal first, then returns to the title without deleting the run.
	await press("settings")
	var cancel := InputEventAction.new()
	cancel.action = "ui_cancel"
	cancel.pressed = true
	screen._unhandled_input(cancel)
	await settle()
	check(screen.find_child("SettingsDialog", true, false) == null, "back closes top dialog")
	screen._unhandled_input(cancel)
	await settle()
	check(screen.page == "menu", "back from run returns to menu")
	var saved := Campaign.new()
	check(saved.restore() and not saved.s.settled and saved.s.gun == "burst", "back preserves active run")

	var report := FileAccess.open(output.path_join("preart_ux_report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	report.close()
	print("PREART UX COMPLETE checks=%d failures=%d" % [checks, failures.size()])
	if is_instance_valid(screen): screen.free()
	quit(0 if failures.is_empty() else 1)
