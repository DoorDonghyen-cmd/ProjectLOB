extends "res://tests/supply_live_ui.gd"
## Build engine trial on screen (2026-11-08): the calculation line under the damage number
## in a real 래칫 fight (earned region-3 state, trial parts), and the new parts in the build
## workshop (icon, details with the 기록 progress).
const BuildEngine = preload("res://redesign/build_engine.gd")
const CommonWindow = preload("res://redesign/common/window.gd")
const TRIAL := ["volley_drive", "third_striker", "duplex", "resonator", "tally"]

func find(id: String) -> Control:
	for child in host.get_children():
		if child.get_script() == CommonWindow and not child.is_queued_for_deletion():
			var inside: Node = child.find_child(id, true, false)
			if inside != null: return inside as Control
	var overlay: Node = host.find_child("WorkspaceOverlay", true, false)
	if overlay != null and id != "WorkspaceOverlay":
		var in_overlay: Node = overlay.find_child(id, true, false)
		if in_overlay != null: return in_overlay as Control
	return host.find_child(id, true, false) as Control

func earned(file: String, parts: Array):
	var c = Campaign.new()
	check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_BUILD_DIR").path_join(file)))), "earned state restores " + file)
	for id in parts:
		if not c.s.parts.has(id): c.s.parts.append(id)
	c.model.s.build_engine_version = BuildEngine.VERSION
	c.model.s.part_growth = {"tally": 9}
	return c

func press(control: Control) -> void:
	var point: Vector2 = control.get_global_transform_with_canvas() * (control.size * 0.5)
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0; event.position = point; event.pressed = pressed
		root.push_input(event, true)
		await process_frame

## Fire until a damage number with a calculation line is on screen; capture that frame.
func catch_ledger(label: String) -> String:
	var hud = host.campaign_hud
	for attempt in range(8):
		if not is_instance_valid(hud) or not host.campaign.s.phase == "combat": return ""
		var fire: Control = hud.node("Fire")
		if fire == null or fire.disabled or not fire.is_visible_in_tree():
			var reload: Control = hud.node("Reload")
			if reload != null and not reload.disabled: await press(reload)
			await settle()
			var started := Time.get_ticks_msec()
			while host.busy and Time.get_ticks_msec() - started < 20000: await process_frame
			continue
		await press(fire)
		var started := Time.get_ticks_msec()
		while Time.get_ticks_msec() - started < 20000:
			await process_frame
			if not is_instance_valid(hud) or not is_instance_valid(hud.board): break
			for entry in hud.board.damage_popups:
				if not str(entry.get("ledger", "")).is_empty():
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(output.path_join(label + ".png"))
					return str(entry.ledger)
			if not host.busy and Time.get_ticks_msec() - started > 400: break
		await settle()
	return ""

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	output = OS.get_environment("QA_OUTPUT_DIR"); Input.emulate_mouse_from_touch = true
	if FileAccess.file_exists(Campaign.SAVE): DirAccess.remove_absolute(Campaign.SAVE)
	for extent in [Vector2i(1280, 800), Vector2i(844, 390)]:
		root.size = extent
		var suffix := "%dx%d" % [extent.x, extent.y]
		var fight = earned("combat_burst_17_r3_n20502.json", TRIAL)
		fight.s.equipped_parts = TRIAL.duplicate()
		fight._sync_equipped_parts()
		await mount(fight)
		check(is_instance_valid(host.campaign_hud), "combat HUD mounted " + suffix)
		var ledger := await catch_ledger("ledger_" + suffix)
		print("LEDGER ", suffix, " ", ledger)
		check(not ledger.is_empty() and (ledger.contains("×") or ledger.contains("+")), "a shot shows its calculation line " + suffix)
	# Build workshop: icons and the 기록 progress in the part details.
	root.size = Vector2i(1280, 800)
	var map = earned("entry_burst_17_r5.json", ["resonator", "tally"])
	await mount(map)
	await tap("city_deck")
	check(find("Stored_resonator") != null and find("Stored_tally") != null, "new parts listed in storage")
	await tap("Stored_resonator")
	await capture("workshop_resonator_1280x800")
	await tap("Stored_tally")
	await tap("PartRules")
	var details := find("PartDetails")
	var text := ""
	if details != null:
		for label in details.find_children("*", "Label", true, false): text += (label as Label).text + "\n"
	check(text.contains("기록: 처치 9회") and text.contains("+3"), "tally details show the record")
	await capture("tally_details_1280x800")
	print("BUILD ENGINE UI checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
