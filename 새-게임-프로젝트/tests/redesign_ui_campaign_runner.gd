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
	# This runner requires a QA-only application profile, checked before this call.
	screen.save_enabled = true
	root.add_child(screen)
	await settle()

func _run() -> void:
	root.size = Vector2i(1280, 800)
	source_path = OS.get_environment("QA_CAMPAIGN_SOURCE")
	if not check(not source_path.is_empty(), "explicit campaign source"):
		finish()
		return
	var user_path := ProjectSettings.globalize_path("user://").replace("\\", "/")
	if not check(user_path.contains("/qa_runtime/redesign/campaign_ui/"), "isolated campaign_ui profile: " + user_path):
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
	var reward_ids: Dictionary = {}
	for entry in expected.history:
		if entry.action == "reward":
			reward_ids[int(entry.floor)] = str(entry.detail.choice)
	for floor_index in range(expected.paths.size()):
		if not check(int(screen.model.s.floor) == floor_index and screen.model.s.phase == "plan", "floor %d entry" % (floor_index + 1)):
			return false
		var step_index := 0
		for step in expected.paths[floor_index]:
			if step.reload and not await click("reload"):
				return false
			for id in step.load:
				if not await click("load_" + str(id)):
					return false
			if not await click("confirm"):
				return false
			if floor_index == 3 and step_index == 0:
				await capture(active_gun + "_04_ready_actual")
				var before: Dictionary = screen.model.s.duplicate(true)
				if not await click("menu"):
					return false
				# Recreate the UI/model to ensure resume reads disk instead of retaining state.
				await fresh_screen()
				if not await click("resume"):
					return false
				if not check(normalized(screen.model.s) == normalized(before), "disk resume restores complete mid-run state"):
					return false
			for shot in range(int(step.fires)):
				if not await click("fire"):
					return false
			step_index += 1
		if floor_index < 6:
			if not check(screen.model.s.phase == "reward", "actual reward after floor %d" % (floor_index + 1)):
				return false
			if not await click("reward_" + str(reward_ids[floor_index])):
				return false
	if not check(screen.model.s.phase == "won", "actual final victory"):
		return false
	check(int(screen.model.s.turns) == int(expected.turns), "turn count matches source")
	check(int(screen.model.s.shots) == int(expected.shots), "shot count matches source")
	check(normalized(screen.model.s.history) == normalized(expected.history), "complete UI action history matches source")
	for enemy in screen.model.s.enemies:
		check(int(enemy.hp) == 0, "final enemy defeated: " + str(enemy.name))
	await capture(active_gun + "_07_won_actual")
	var result := {"gun": active_gun, "seed": screen.model.s.seed,
		"won": screen.model.s.phase == "won", "turns": screen.model.s.turns,
		"shots": screen.model.s.shots, "reloads": screen.model.s.reloads,
		"history": screen.model.s.history.duplicate(true)}
	reports.append(result)
	if not await click("retry"):
		return false
	check(screen.model.s.phase == "plan" and int(screen.model.s.floor) == 0 and int(screen.model.s.turns) == 0, "retry resets run")
	check(screen.model.s.gun == active_gun and int(screen.model.s.seed) == 731042, "retry retains gun and seed")
	if not await click("menu"):
		return false
	return check(screen.page == "menu", "menu after retry")

func normalized(value: Variant) -> Variant:
	# JSON loads numbers as floats. Compare serialized values without an int/float
	# type-only mismatch while preserving every field and the precise seed string.
	return JSON.parse_string(JSON.stringify(value))

func finish() -> void:
	var file := FileAccess.open("user://redesign_ui_campaign_report.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"method": "recorded real-command path replay through rendered Button.pressed; no forced wins or state edits; not human win rate",
			"source": source_path, "checks": checks, "failures": failures,
			"actions": actions, "reports": reports, "captures": captures}, "\t"))
	print("REDESIGN UI CAMPAIGN: %d checks / %d failed / %d campaigns / %d UI buttons" % [checks.size(), failures, reports.size(), actions.size()])
	quit(1 if failures > 0 else 0)
