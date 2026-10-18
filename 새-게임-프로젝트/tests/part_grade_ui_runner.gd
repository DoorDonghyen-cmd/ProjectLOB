extends "res://tests/parts_revision_ui_runner.gd"

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/part_grade/ui"):
		quit(1)
		return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1008, 630), Vector2i(1280, 900), Vector2i(1440, 630)]:
		root.size = resolution
		screen._debug_city("deck")
		screen.campaign.s.parts = ["lens", "ordinary_chain", "overbore", "coil", "reserve", "cooling_breech"]
		screen.campaign.s.equipped_parts = ["lens", "ordinary_chain", "overbore", "coil", "reserve"]
		screen.model.s.equipped_parts = screen.campaign.s.equipped_parts.duplicate()
		screen.city_ui.deck()
		await settle()
		await tap("equipped_part_detail_2")
		bounds("part_rules")
		await capture("grades_equipment_%d" % resolution.x)
		await tap("part_rules")
		var dialog = screen.find_children("PartDetails", "", true, false).filter(func(item): return item.has_meta("dialog"))[0]
		check(dialog != null, "touch opens grade explanation")
		check(Rect2(Vector2.ZERO, screen.size).encloses(dialog.get_global_rect()), "grade details fit viewport")
		await capture("grades_details_%d" % resolution.x)
		(dialog.get_meta("dialog") as Control).get_ok_button().name = "grade_details_close"
		await tap("grade_details_close")
		screen._debug_city("shop")
		screen.campaign.s.parts = []
		screen.campaign.s.equipped_parts = []
		screen.campaign.s.offers = [{"id": "pierce", "type": "ammo", "price": 12, "sold": false}, {"id": "lens", "type": "part", "price": 30, "sold": false}, {"id": "overbore", "type": "part", "price": 30, "sold": false}]
		screen.redraw()
		await settle()
		await tap("city_part_info_2")
		bounds("city_compare_buy_2")
		check(not screen.main_scroll.get_v_scroll_bar().visible, "grade does not expand shop height")
		await capture("grades_shop_%d" % resolution.x)
	check(not screen.save_enabled, "personal save untouched")
	screen.queue_free()
	await process_frame
	print("PART GRADE UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
