extends "res://tests/combat_ui_stage1_ui.gd"

func wait_action() -> void:
	for frame in range(1800):
		if not preview.busy: break
		await process_frame
	check(not preview.busy, "Action animation finishes")
	await settle()

func tap(id: String) -> void:
	await super.tap(id)
	await wait_action()

func layout() -> void:
	geometry()
	for id in ["IntentTitle", "IntentHint"]:
		check(preview.node(id).get_global_rect().end.y <= preview.board.get_global_rect().position.y, "Threat guidance cannot overlap approaching enemy HUD")
	var buttons := ["HeatLabel", "Bag", "Parts", "Cool", "Reload", "Fire"]
	for i in range(buttons.size()):
		var item: Control = preview.node(buttons[i])
		check(preview.get_global_rect().encloses(item.get_global_rect()), "Action fits " + buttons[i])
		if i > 0: check(not item.get_global_rect().intersects(preview.node(buttons[i-1]).get_global_rect()), "Actions do not overlap")
		if item is Button:
			check(item.size.y * float(root.size.y) / 800.0 >= 44.0, "Action touch target")
			var font := item.get_theme_font("font")
			var width := font.get_string_size(item.text, HORIZONTAL_ALIGNMENT_LEFT, -1, item.get_theme_font_size("font_size")).x
			check(width + 32 <= item.size.x, "Action label fits " + buttons[i])
	for i in range(6):
		check(preview.get_global_rect().encloses(preview.node("Round%d" % i).get_global_rect()), "All six slots fit")
	check(preview.node("Prediction").get_global_rect().position.y >= preview.board.get_global_rect().position.y, "Prediction stays in battlefield composition")

func run() -> void:
	out = OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/combat_magazine_loop_20261031/"): quit(2); return
	Input.emulate_mouse_from_touch = true
	preview = load("res://redesign/samples/combat_magazine_loop.tscn").instantiate()
	preview.resume_saved = false
	root.add_child(preview); await settle()
	for size in [Vector2i(1008, 630), Vector2i(1280, 576), Vector2i(1280, 800)]:
		root.size = size; root.content_scale_size = Vector2i(1280, 800); await settle()
		preview.mount(false); await settle(); layout()
		var suffix := "%dx%d" % [size.x, size.y]
		check(preview.model.s.magazine.size() == 6 and preview.model.s.phase == "ready", "Whole magazine ready on entry")
		check(preview.node("Cool").disabled, "Zero heat has no free wait button")
		await capture("ready_" + suffix)
		await tap("Pressure"); check(preview.pressure, "Switch to earned boss")
		var ordered: Array = preview.model.s.magazine.duplicate()
		await tap("Fire")
		check(preview.model.s.magazine == ordered.slice(2), "Touch fires exactly first two rounds")
		check(preview.board.visual_events.any(func(e): return str(e.kind) == "shot"), "Actual shot animation executes")
		check(not preview.node("Reset").disabled and not preview.node("Other").disabled, "Controls unlock after animation")
		await capture("partial_" + suffix)
		var kept: Array = preview.model.s.magazine.duplicate()
		await tap("Cool")
		check(preview.model.s.magazine == kept and preview.model.s.heat == 0, "Touch cools without losing remaining rounds")
		await tap("Reload")
		check(preview.model.s.magazine.size() == 6 and preview.model.s.phase == "ready", "Touch changes entire magazine and keeps playing")
		layout(); await capture("swapped_" + suffix)
		await tap("Bag"); check(preview.overlay_open, "Reserve details available")
		var unchanged := JSON.stringify(preview.model.s)
		preview.fire(); check(JSON.stringify(preview.model.s) == unchanged, "Modal blocks combat input")
		await tap("CloseDetail")
		await tap("Other"); check(preview.node("DetailBody").text.contains("-6"), "Rules match actual cooling")
		await capture("rules_" + suffix)
		await tap("CloseDetail")
		check(preview.save_ok, "Comparison autosave succeeds")
	# Save a partly fired magazine, close the scene, then resume through the public entry.
	preview.mount(true); await tap("Fire")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(preview.model.s))
	preview.queue_free(); await settle()
	preview = load("res://redesign/samples/combat_magazine_loop.tscn").instantiate()
	root.add_child(preview); await settle()
	check(preview.resumed and JSON.parse_string(JSON.stringify(preview.model.s)) == saved, "Reopening resumes isolated partial magazine")
	await capture("resumed_1280x800")
	# Force overheat through legal uninterrupted firing; keep every unfired round.
	preview.mount(true)
	for step in range(3):
		await tap("Fire")
		var detail: Dictionary = preview.model.s.history.back().detail
		if not detail.get("forced_cooling", {}).is_empty():
			check(preview.node("CapacityNote").text.contains("과열"), "Forced cooling result explained")
			check(preview.board.salvo_receipt.is_empty(), "No duplicate result over enemy headers")
			await capture("forced_cooling_1280x800")
			break
	# Finish a natural loop through the same public buttons.
	preview.mount(true)
	for step in range(40):
		if preview.model.s.phase not in ["plan", "ready"]: break
		if preview.model.can_emergency_resupply() or preview.model.s.magazine.is_empty(): await tap("Reload")
		elif float(preview.last_prediction.get("heat", {}).get("forced_probability", 0.0)) > 0.0 and preview.model.s.heat > 0: await tap("Cool")
		else: await tap("Fire")
	check(preview.model.s.phase in ["reward", "won"], "Playable boss loop reaches victory")
	check(preview.node("Fire").disabled and preview.node("Cool").disabled and preview.node("Reload").disabled, "No actions after victory")
	await capture("victory_1280x800")
	# Projectile and body contact are different threats and must be labelled separately.
	preview.mount(true)
	for step in range(30):
		if preview.node("Reload").text.contains("피격"): break
		await tap("Reload")
	check(preview.node("Reload").text.contains("피격") and preview.node("IntentTitle").text.contains("압력탄"), "Projectile warning does not claim body contact")
	await capture("projectile_warning_1280x800")
	await tap("Reload")
	check(preview.model.s.get("loss_reason", "") == "projectile" and preview.node("IntentTitle").text.contains("압력탄"), "Projectile defeat text matches actual reason")
	# Approach test uses legal paid swaps, not teleporting enemies for the screenshot.
	preview.mount(false)
	for step in range(30):
		if preview.node("Reload").text.contains("접촉"): break
		await tap("Reload")
	check(preview.node("Reload").text.contains("접촉"), "Approaching contact is warned before commitment")
	await capture("contact_warning_1280x800")
	await tap("Reload")
	check(preview.model.s.phase == "lost" and preview.model.s.get("loss_reason", "") != "projectile", "Warned swap causes contact defeat")
	await capture("defeat_1280x800")
	await tap("Reset"); check(not preview.pressure and preview.model.s.phase == "ready", "Restart keeps selected battle")
	check(not FileAccess.file_exists("user://campaign.json"), "Main campaign save never created")
	preview.queue_free(); await settle()
	FileAccess.open(out.path_join("ui.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures}, "  "))
	print("MAGAZINE LOOP UI COMPLETE checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
