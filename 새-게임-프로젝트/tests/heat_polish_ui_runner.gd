extends "res://tests/ammo_expansion_ui_runner.gd"
const Insight = preload("res://redesign/run_insight.gd")

func visible_report() -> void:
	var view := screen.find_child("HeatReport", true, false) as Control
	check(view != null and view.is_visible_in_tree(), "public thermal report shown")
	if view == null: return
	check(Rect2(Vector2.ZERO, screen.size).encloses(view.get_global_rect()), "thermal report inside viewport")
	check(view.get_child_count() == 3, "three compact report columns")
	for column in view.get_children():
		check(view.get_global_rect().encloses(column.get_global_rect()), "report column inside row")
		for label in column.get_children():
			check(column.get_global_rect().encloses(label.get_global_rect()), "report label inside column")

func close_dialogs() -> void:
	for child in screen.get_children():
		if child is AcceptDialog or child.has_meta("lob_modal"):
			child.hide()
			child.queue_free()
	await settle()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/heat_polish/"):
		quit(1)
		return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.02
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1280, 900), Vector2i(1008, 630), Vector2i(1440, 630)]:
		root.size = resolution
		await settle()
		await combat(["charge_hot", "thermal", "vent", "cool"])
		screen.campaign.s.parts = ["ember_core", "reclaimer"]
		screen.campaign.s.equipped_parts = ["ember_core", "reclaimer"]
		screen.model.s.equipped_parts = ["ember_core", "reclaimer"]
		screen.model.s.enemies = [Data._enemy(["wall", 12, 0, 1, 22]), Data._enemy(["runner", 7, 0, 2, 26])]
		screen.model.assign_opening_lanes()
		screen.redraw()
		await settle()
		for id in Ammo.loading_order(["charge_hot", "thermal", "vent"]): await tap("load_" + id)
		await tap("confirm")
		await tap("fire")
		check(screen.campaign.s.phase == "reward", "legal combo reaches real reward")
		var report := Insight.combat_report(screen.campaign.encounter_report_state())
		check(report.heat_peak == 7 and report.cooled == 8 and report.forced_reloads == 0, "reward reflects actual kill cooling and vent")
		visible_report()
		for label in screen.find_children("BuildHighlight_*", "Label", true, false):
			check(label.get_line_count() == 1 and label.size.y < 40, "part highlights flow as readable lines")
		check(not screen.main_scroll.get_h_scroll_bar().visible, "reward no horizontal overflow")
		await capture("heat_reward_%d" % resolution.x)
		await tap("encounter_record")
		check(is_instance_valid(screen.workspace_overlay) and screen.workspace_overlay.find_child("HeatReport", true, false) != null, "record workspace opens through public button")
		await capture("heat_record_%d" % resolution.x)
		await tap("workspace_close")
		check(screen.get_viewport().gui_get_focus_owner() == screen.find_child("encounter_record", true, false), "record close restores reward button focus")
		await combat(["charge_hot", "precise", "pierce", "cool"])
		screen.model.s.enemies = [Data._enemy(["wall", 40, 4, 2, 6])]
		screen.model.s.encounter_total = 1
		screen.model.s.deployed = 1
		screen.model.assign_opening_lanes()
		screen.redraw()
		await settle()
		for id in Ammo.loading_order(["charge_hot", "precise", "pierce", "cool"]): await tap("load_" + id)
		await tap("confirm")
		await tap("fire")
		check(screen.campaign.s.phase == "lost", "actual forced reload reaches ending")
		check(Insight.loss_advice(screen.model.s).contains("과열 후 강제 재장전"), "loss cause distinguishes heat")
		visible_report()
		await capture("heat_loss_%d" % resolution.x)
		# Inspect owned thermal components in the actual build workspace.
		screen._debug_city("shop")
		screen.campaign.s.parts = ["radiator", "ember_core", "reclaimer"]
		screen.campaign.s.equipped_parts = ["radiator", "ember_core", "reclaimer"]
		screen.model.s.equipped_parts = ["radiator", "ember_core", "reclaimer"]
		screen.redraw()
		await settle()
		await tap("city_deck")
		await tap("equipped_part_detail_0")
		await capture("heat_loadout_%d" % resolution.x)
		await tap("part_rules")
		var dialogs := screen.get_children().filter(func(child): return child is AcceptDialog and child.visible)
		var details: Control = dialogs[0].find_child("PartDetails", true, false) if not dialogs.is_empty() else null
		check(details != null, "part rules reachable from equipped inspector")
		var labels := details.find_children("*", "Label", true, false)
		check(labels.any(func(label): return label.text.contains("고열 보너스가 시작되는 열도 높아짐")), "cooling tradeoff visible in actual rules")
		check(labels.any(func(label): return label.text.contains("열 한계 12→15")), "already equipped radiator contribution correct")
		if details != null:
			var scroll := details.get_parent() as ScrollContainer
			check(not scroll.get_v_scroll_bar().visible and not scroll.get_h_scroll_bar().visible, "part rules and tradeoff visible without scrolling")
		await capture("heat_part_rules_%d" % resolution.x)
		await close_dialogs()
		await tap("workspace_close")
	screen.queue_free()
	await process_frame
	print("HEAT POLISH UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
