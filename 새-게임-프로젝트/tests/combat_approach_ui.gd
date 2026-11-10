extends "res://tests/combat_magazine_loop_ui.gd"

func approach_layout() -> void:
	layout()
	check(preview.get_global_rect().encloses(preview.node("Help").get_global_rect()), "Help fits")
	check(not preview.node("Help").get_global_rect().intersects(preview.node("Reset").get_global_rect()), "Header actions separate")
	for id in ["PreviewLabel", "StatusNote"]:
		check(not preview.node(id).get_global_rect().intersects(preview.node("Help").get_global_rect()), "Header labels have reserved space")
	for i in range(preview.model.s.enemies.size()):
		if int(preview.model.s.enemies[i].hp) <= 0: continue
		var plaque: Rect2 = preview.board.enemy_plaque(i)
		var global_top: float = preview.board.get_global_rect().position.y + plaque.position.y
		check(global_top >= preview.node("IntentHint").get_global_rect().end.y, "Close enemy HUD does not collide with guidance")

func run() -> void:
	out = OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/combat_approach_20261031/"): quit(2); return
	Input.emulate_mouse_from_touch = true
	preview = load("res://redesign/samples/combat_approach.tscn").instantiate()
	preview.resume_saved = false
	root.add_child(preview); await settle()
	for size in [Vector2i(1008,630), Vector2i(1280,576), Vector2i(1280,800)]:
		root.size = size; root.content_scale_size = Vector2i(1280,800)
		preview.case_index = 0; preview.approach_on = true; preview.mount(false); await settle()
		var suffix := "%dx%d" % [size.x,size.y]
		approach_layout(); await capture("pressure_ready_" + suffix)
		var order: Array = preview.model.s.magazine.duplicate()
		await tap("Other")
		check(not preview.approach_on and preview.model.s.magazine == order and int(preview.model.s.enemies[0].distance) == 22, "Same magazine can compare old distance")
		await capture("previous_ready_" + suffix)
		await tap("Other")
		check(preview.approach_on and int(preview.model.s.enemies[0].distance) == 11, "Pressure restored once without compounding")
		await tap("Fire"); await tap("Fire")
		check(preview.node("Fire").text.contains("접촉") and not preview.node("Cool").disabled, "Natural firing reaches meaningful overheat/contact choice")
		check(not preview.action_preview("cool").lethal, "Cooling remains a surviving alternative")
		approach_layout(); await capture("decision_" + suffix)
		await tap("Cool")
		check(preview.model.s.phase == "ready" and preview.model.s.magazine.size() == 2, "Cooling keeps the two finishing rounds")
		await capture("near_contact_" + suffix)
		await tap("Fire")
		check(preview.model.s.phase in ["won", "reward"], "Cooling decision wins the same fight")
		await capture("victory_" + suffix)
		await tap("Reset"); await tap("Fire"); await tap("Fire"); await tap("Fire")
		check(preview.model.s.phase == "lost" and preview.model.s.get("loss_reason", "") != "projectile", "Ignoring overheat warning loses to body contact")
		await capture("overheat_defeat_" + suffix)
	# Save at a genuine decision reached by firing, then reopen the exact state.
	preview.case_index = 0; preview.mount(false); await tap("Fire"); await tap("Fire")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(preview.model.s))
	preview.queue_free(); await settle()
	preview = load("res://redesign/samples/combat_approach.tscn").instantiate()
	root.add_child(preview); await settle()
	check(preview.resumed and preview.approach_on and JSON.parse_string(JSON.stringify(preview.model.s)) == saved, "Decision resumes with original movement and RNG")
	await capture("resume_decision_1280x800")
	# Every public scenario completes through the same visible actions.
	for case_number in range(1,5):
		await tap("Pressure")
		check(preview.case_index == case_number, "Public next-battle navigation")
		approach_layout(); await capture("case_%d_ready_1280x800" % case_number)
		for step in range(40):
			if preview.model.s.phase not in ["plan", "ready"]: break
			if preview.model.can_emergency_resupply() or preview.model.s.magazine.is_empty(): await tap("Reload")
			elif float(preview.last_prediction.get("heat", {}).get("forced_probability",0.0)) > 0 and int(preview.model.s.heat) > 0: await tap("Cool")
			else: await tap("Fire")
		check(preview.model.s.phase in ["won","reward"], "Scenario reaches victory using real buttons")
		check(not preview.node("Pressure").disabled and preview.node("Fire").disabled, "Can select next scenario after victory")
	await tap("Pressure"); check(preview.case_index == 0, "Scenario selection wraps")
	await tap("Help"); check(preview.overlay_open and preview.node("DetailBody").text.contains("과열"), "Rules accessible")
	await capture("help_1280x800"); await tap("CloseDetail")
	await tap("Bag"); check(preview.overlay_open, "Reserve detail accessible"); await tap("CloseDetail")
	await tap("Parts"); check(preview.overlay_open, "Parts detail accessible"); await tap("CloseDetail")
	# Baseline comparison choice also persists; malformed envelope is rejected safely.
	await tap("Other"); check(not preview.approach_on, "Baseline selected")
	check(preview.restore_comparison() and not preview.approach_on, "Baseline choice survives save/restore")
	var raw := FileAccess.get_file_as_string(preview.COMPARISON_SAVE)
	var bad: Dictionary = JSON.parse_string(raw); bad.approach = true
	FileAccess.open(preview.COMPARISON_SAVE, FileAccess.WRITE).store_string(JSON.stringify(bad))
	check(not preview.restore_comparison(), "Save envelope cannot disagree with combat rules")
	FileAccess.open(preview.COMPARISON_SAVE, FileAccess.WRITE).store_string("{broken")
	check(not preview.restore_comparison(), "Corrupt save is rejected")
	preview.approach_on = true; preview.mount(false)
	check(not FileAccess.file_exists("user://campaign.json") and not FileAccess.file_exists("user://combat_magazine_trial_v1.json"), "Neither campaign nor prior comparison save is overwritten")
	preview.queue_free(); await settle()
	FileAccess.open(out.path_join("ui.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures}, "  "))
	print("APPROACH UI COMPLETE checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
