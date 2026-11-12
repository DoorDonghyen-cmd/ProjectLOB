extends "res://tests/supply_live_ui.gd"
## Ammo/part overhaul on screen (2026-11-10): the gate with 구동 강화 / 탄종 숙련 / 보조 숙련
## options, and the shop's 구동 정비 button (the hidden compressor slot), both in v2 runs built
## from earned 2026-11-06 states.
const GrowthV2 = preload("res://redesign/growth_structure.gd")

func find(id: String) -> Control:
	for name in ["GateScreen", "WorkspaceOverlay"]:
		var scene: Node = host.find_child(name, true, false)
		if scene != null and id != name:
			var inside: Node = scene.find_child(id, true, false)
			if inside != null: return inside as Control
	return host.find_child(id, true, false) as Control

func earned(file: String):
	var c = Campaign.new()
	check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_BUILD_DIR").path_join(file)))), "earned state restores " + file)
	c.model.s.growth_structure_version = GrowthV2.VERSION
	return c

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	output = OS.get_environment("QA_OUTPUT_DIR"); Input.emulate_mouse_from_touch = true
	if FileAccess.file_exists(Campaign.SAVE): DirAccess.remove_absolute(Campaign.SAVE)
	for extent in [Vector2i(1280, 800), Vector2i(844, 390)]:
		root.size = extent
		var suffix := "%dx%d" % [extent.x, extent.y]
		# Gate: new options are real buttons on screen.
		var gate = earned("gate_burst_17_r2.json")
		gate.model.s.engine.levels = {"volley_drive": 6}
		await mount(gate)
		for id in ["drive", "mastery", "mastery_support"]:
			var option := find("Option_" + id)
			# The option row scrolls sideways on short screens (up to 8 options in v2).
			var scroller: Node = option.get_parent() if option != null else null
			while scroller != null and not scroller is ScrollContainer: scroller = scroller.get_parent()
			if scroller != null: scroller.ensure_control_visible(option); await settle()
			check(option != null and option.is_visible_in_tree() and root.get_visible_rect().grow(1).encloses(option.get_global_rect()), "gate shows %s on screen %s" % [id, suffix])
		await tap("Option_drive")
		await capture("gate_drive_" + suffix)
		await tap("Apply")
		check(int(gate.model.s.engine.levels.volley_drive) == 10 and int(saved().model.s.engine.levels.volley_drive) == 10, "구동 강화 from the gate screen: 6 → 10, saved")
		# Shop: the compressor slot becomes 구동 정비.
		var shop = earned("shop_burst_17_r5_n40401.json")
		shop.model.s.engine.levels = {"volley_drive": 8}
		shop.s.credits = 80
		await mount(shop)
		var wide: bool = extent.x >= 1000
		var tune := find("Charge") as Button
		if wide:
			check(tune != null and tune.is_visible_in_tree() and tune.text.contains("구동 정비") and tune.text.contains("36Cr") and not tune.disabled, "shop shows 구동 정비 Lv8→10 · 36Cr " + suffix)
			await capture("shop_drive_" + suffix)
			await tap("Charge")
		else:
			# Short screens: the six-key row would overflow, so 구동 정비 sits in the shop menu.
			check(tune == null or not tune.is_visible_in_tree(), "short screen keeps the action row to five keys")
			await tap("Tools")
			var item := find("shop_drive_tune") as Button
			check(item != null and item.text.contains("36Cr") and not item.disabled, "shop menu offers 구동 정비 Lv8→10 · 36Cr " + suffix)
			await capture("shop_drive_" + suffix)
			await tap("shop_drive_tune")
		check(int(shop.model.s.engine.levels.volley_drive) == 10 and int(shop.s.credits) == 44 and int(saved().model.s.engine.levels.volley_drive) == 10, "구동 정비 spends 36Cr, +2 levels, saved " + suffix)
		if wide: check(find("Charge").text.contains("Lv10→12") and find("Charge").text.contains("42Cr") and not find("Charge").disabled, "next step priced (44Cr left, 42Cr needed)")
		else: check(find("WorkspaceOverlay") == null, "the menu closes after tuning")
		print("OVERHAUL UI checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
