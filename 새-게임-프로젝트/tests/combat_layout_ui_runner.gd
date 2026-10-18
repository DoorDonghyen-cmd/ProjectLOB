extends "res://tests/eavesback_ui_runner.gd"

func measure(label: String) -> void:
	fit()
	var stage: Control = screen.battle_view
	var grid := screen.find_child("AmmoGrid", true, false) as Control
	var panel := screen.find_child("CandidatesPanel", true, false) as Control
	check(stage.size.y >= 240, "stage retains readable minimum " + label)
	var reference := 240.0 if screen.size.y < 960 else 350.0
	var approved_scale := 0.65 * minf(0.18, maxf(0.09, (reference - 100.0) / 1050.0))
	check(is_equal_approx(stage.character_scale(), approved_scale), "approved hero size " + label)
	for button in grid.get_children():
		if not button.visible: continue
		check(panel.get_global_rect().encloses(button.get_global_rect()), "card remains inside hand")
		check(button.size.x >= 120 and button.size.y >= 130, "card touch target remains generous")
		var card := button.get_node("CardInfo")
		var title: String = Ammo.AMMO[card.ammo_id].name
		check(card.FONT.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x <= card.header_title_width(), "title clears heat cost " + title)
		check(card.FONT.get_string_size(card.footer_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x <= card.size.x - 20, "card effect fits " + title)
	print("LAYOUT %s viewport=%s stage=%.0f hand=%.0f cards=%.0f" % [label, str(root.size), stage.size.y, panel.size.y, grid.size.y])

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/eavesback/layout"):
		quit(1)
		return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.02
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1280, 900), Vector2i(1008, 630), Vector2i(1440, 630), Vector2i(1280, 1024)]:
		root.size = resolution
		screen._debug_eavesback(true)
		await settle()
		measure("idle")
		check(screen.battle_view.size.y >= 276, "ordinary stage gains at least 15 percent")
		await capture("layout_%dx%d" % [resolution.x, resolution.y])
		for gun in Ammo.GUNS:
			screen._debug_eavesback(true)
			screen.model.s.gun = gun
			screen.redraw()
			await settle()
			await tap("load_pierce")
			await tap("load_bore")
			check(screen.model.s.plan == ["bore", "pierce"], "last loaded fires first")
			measure("planned " + gun)
			await tap("confirm")
			measure("ready " + gun)
			if gun == "single": await capture("ready_%dx%d" % [resolution.x, resolution.y])
			await tap("fire")
			check(screen.battle_view.enemies == screen.model.s.enemies, "shot still matches model")
			await tap("reload")
			measure("reload " + gun)
		# Compression availability, anchored/two-slot cards, paging and reserve wraps.
		screen._debug_eavesback(true)
		screen.model.s.hand = ["pierce_c", "precise_c", "charge", "charge", "vent", "disrupt", "prepare", "bypass"]
		screen.model.s.draw = ["bore", "arc", "cool", "shatter", "chase", "detonate", "sequence", "spread"]
		screen.model.s.field_compression_left = 1
		screen.hand_layout_key = ""
		screen.redraw()
		await settle()
		measure("compression and reserve")
		var pair := screen.find_child("load_charge", true, false)
		check(pair.get_node("CardInfo").compression_ready, "compression cue retained")
		await capture("compression_%dx%d" % [resolution.x, resolution.y])
		await tap("load_pierce_c")
		check(Ammo.slots_used(screen.model.s.plan) == 2, "two-slot card loads through touch")
		await tap("undo")
		measure("recall")
		if screen.find_child("hand_next", true, false) != null:
			await tap("hand_next")
			measure("hand page")
	# All ammo variants must fit the new header, including the longer heat-spend range.
	root.size = Vector2i(1008, 630)
	var catalog: Array = Ammo.AMMO.keys()
	for offset in range(0, catalog.size(), 6):
		screen._debug_eavesback(true)
		screen.model.s.parts = ["overbore"]
		screen.model.s.hand = catalog.slice(offset, offset + 6)
		screen.hand_layout_key = ""
		screen.redraw()
		await settle()
		measure("all ammo variants %d" % offset)
		await capture("catalog_%d" % offset)
	check(not screen.save_enabled, "isolated QA never saves player campaign")
	screen.queue_free()
	await process_frame
	print("COMBAT LAYOUT UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
