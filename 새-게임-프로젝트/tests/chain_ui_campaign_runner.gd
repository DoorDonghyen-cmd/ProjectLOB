extends SceneTree
## Replay an externally recorded real-command campaign through rendered UI buttons.
## No state injection, enemy edits, debug shortcuts, or victory fixtures.
var screen: Control
var checks: Array = []
var actions: Array = []
var reports: Array = []
var captures: Array = []
var failures := 0
var source_path := ""
var active_gun := ""

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> bool:
	checks.append({"passed": ok, "check": message, "gun": active_gun})
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
	return ok

func settle() -> void:
	for i in range(3):
		await process_frame
	while is_instance_valid(screen) and screen.busy:
		await process_frame
	await RenderingServer.frame_post_draw

func summary() -> Dictionary:
	return {"page": screen.page, "phase": screen.model.s.get("phase", ""),
		"floor": screen.model.s.get("floor", -1), "turns": screen.model.s.get("turns", 0),
		"shots": screen.model.s.get("shots", 0), "plan": screen.model.s.get("plan", []).duplicate(),
		"magazine": screen.model.s.get("magazine", []).duplicate()}

func click(key: String) -> bool:
	var button := screen.find_child(key, true, false) as Button
	if not check(button != null and not button.disabled and button.is_visible_in_tree(), "enabled visible button: " + key):
		return false
	var entry := {"gun": active_gun, "button": key, "before": summary()}
	button.pressed.emit()
	await settle()
	entry["after"] = summary()
	actions.append(entry)
	return check(screen.save_error.is_empty(), "autosave after " + key)

func capture(label: String) -> void:
	await settle()
	var path := "user://" + label + ".png"
	var image := root.get_texture().get_image()
	check(image != null and not image.is_empty(), "rendered capture " + label)
	if image != null and not image.is_empty():
		check(image.save_png(path) == OK, "capture saved " + label)
		captures.append(ProjectSettings.globalize_path(path))
	check(screen.body.size.x <= 1280, "no horizontal overflow " + label)
	var snapshot := FileAccess.open("user://" + label + ".json", FileAccess.WRITE)
	if snapshot != null:
		snapshot.store_string(JSON.stringify({"state": screen.model.s, "page": screen.page}, "\t"))

func fresh_screen() -> void:
	if is_instance_valid(screen):
		screen.free()
	screen = load("res://redesign/main.tscn").instantiate()
	screen.presentation_speed = 0.05
	# This runner requires a QA-only application profile, checked before this call.
	screen.save_enabled = true
	root.add_child(screen)
	await settle()

func _run() -> void:
	root.size = Vector2i(1280, 800)
	source_path = OS.get_environment("CHAIN_CAMPAIGN_SOURCE")
	if not check(not source_path.is_empty(), "explicit campaign source"):
		finish()
		return
	var user_path := ProjectSettings.globalize_path("user://").replace("\\", "/")
	if not check(user_path.contains("/qa_runtime/chain/ui_campaign/"), "isolated campaign_ui profile: " + user_path):
		finish()
		return
	var source = JSON.parse_string(FileAccess.get_file_as_string(source_path))
	if not check(source is Dictionary and source.get("reports", []) is Array, "source report loaded"):
		finish()
		return
	for gun in ["single", "burst"]:
		active_gun = gun
		var expected: Dictionary = {}
		for report in source.reports:
			if report.gun == gun and int(report.seed) == 731042:
				expected = report
		if not check(not expected.is_empty(), "recorded source for gun"):
			break
		await fresh_screen()
		screen.seed_input.text = "731042"
		if not await click("start_" + gun):
			break
		if not await replay(expected):
			break
	finish()

func replay(expected: Dictionary) -> bool:
	var resumed := false
	for command in expected.commands:
		var key: String = command.action
		match command.action:
			"load": key = "load_" + str(command.id)
			"reward": key = ("remove_" + str(command.remove_id)) if command.id == "remove" else "reward_" + str(command.id)
			"exchange":
				if not await click("exchange"): return false
				key = "exchange_" + str(command.id)
		if not await click(key): return false
		if not check(screen.model.s.phase == command.phase_after and int(screen.model.s.floor) == int(command.floor_after) and int(screen.model.s.turns) == int(command.turn_after), "command replay agrees: " + key): return false
		if command.action == "confirm" and int(screen.model.s.floor) in [0, 3, 6]:
			await capture(active_gun + "_%02d_plan" % (int(screen.model.s.floor) + 1))
		if command.action == "fire" and not resumed:
			var before: Dictionary = screen.model.s.duplicate(true)
			if not await click("menu"): return false
			await fresh_screen()
			if not await click("resume"): return false
			if not check(normalized(screen.model.s) == normalized(before), "disk resume restores complete state"): return false
			resumed = true
	if not check(screen.model.s.phase == "won", "actual final victory"): return false
	check(int(screen.model.s.turns) == int(expected.turns), "turn count agrees")
	check(int(screen.model.s.shots) == int(expected.shots), "shot count agrees")
	if expected.has("history"): check(normalized(screen.model.s.history) == normalized(expected.history), "complete UI history agrees")
	await capture(active_gun + "_07_won_actual")
	reports.append({"gun": active_gun, "won": true, "turns": screen.model.s.turns, "shots": screen.model.s.shots, "reloads": screen.model.s.reloads})
	if not await click("retry"): return false
	check(screen.model.s.phase == "plan" and int(screen.model.s.floor) == 0 and int(screen.model.s.turns) == 0, "retry resets run")
	check(screen.model.s.gun == active_gun and int(screen.model.s.seed) == 731042, "retry retains gun and seed")
	return true

func normalized(value: Variant) -> Variant:
	# JSON loads numbers as floats. Compare serialized values without an int/float
	# type-only mismatch while preserving every field and the precise seed string.
	return JSON.parse_string(JSON.stringify(value))

func finish() -> void:
	var file := FileAccess.open("user://chain_ui_campaign_report.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"method": "recorded real-command path replay through rendered Button.pressed; no forced wins or state edits; not human win rate",
			"source": source_path, "checks": checks, "failures": failures,
			"actions": actions, "reports": reports, "captures": captures}, "\t"))
	print("CHAIN UI CAMPAIGN: %d checks / %d failed / %d campaigns / %d UI buttons" % [checks.size(), failures, reports.size(), actions.size()])
	quit(1 if failures > 0 else 0)
