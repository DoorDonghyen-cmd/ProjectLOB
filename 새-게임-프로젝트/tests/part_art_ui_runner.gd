extends "res://tests/parts_revision_ui_runner.gd"
const Art = preload("res://redesign/part_icon_art.gd")

func catalog(old: bool) -> void:
	var surface := Control.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(surface)
	var background := ColorRect.new()
	background.color = Color("101d25")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.add_child(background)
	var label := Label.new()
	label.text = "파츠 28종 · 이전" if old else "파츠 28종 · 금속 본체와 연결부 리터치"
	label.position = Vector2(18, 16)
	label.add_theme_font_override("font", PartCard.FONT)
	label.add_theme_font_size_override("font_size", 26)
	surface.add_child(label)
	var old_script = load(ProjectSettings.globalize_path("res://").path_join("../docs/qa/reports/part_art_2026-10-09_assets/part_card_before.gd")) if old else null
	for i in range(Art.IDS.size()):
		var card = old_script.new() if old else PartCard.new()
		card.setup(Art.IDS[i], {"gun": "single"})
		card.portrait = true
		card.slot_number = i + 1
		surface.add_child(card)
		card.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		card.position = Vector2(12 + (i % 7) * 181, 65 + (i / 7) * 193)
		card.size = Vector2(174, 182)
		check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(card.get_global_rect()), "catalog card fits " + Art.IDS[i])
	await capture("catalog_before" if old else "catalog_after")
	surface.queue_free()
	await settle()

func raw_grid() -> void:
	var surface := Control.new()
	root.add_child(surface)
	var background := ColorRect.new()
	background.color = Color("101d25")
	background.size = Vector2(root.size)
	surface.add_child(background)
	for factor in [0.6, 1.0]:
		for i in range(Art.IDS.size()):
			var icon := Control.new()
			icon.position = Vector2((i % 7) * 170 + 20, (i / 7) * 90 + (20 if factor == 0.6 else 430))
			icon.size = Vector2(150, 75)
			surface.add_child(icon)
			var id: String = Art.IDS[i]
			icon.draw.connect(func(): Art.draw(icon, id, Vector2(75, 37), PartCard.COLORS[id], factor))
	await capture("sizes")
	var frame := root.get_texture().get_image()
	var bg := frame.get_pixel(0, 0)
	var hashes: Array = []
	for i in range(Art.IDS.size()):
		var origin := Vector2i((i % 7) * 170 + 20, (i / 7) * 90 + 430)
		var crop := frame.get_region(Rect2i(origin + Vector2i(43, 13), Vector2i(64, 48)))
		var hash_value := crop.get_data().hex_encode().sha256_text()
		check(not hashes.has(hash_value), "distinct rendered part image " + Art.IDS[i])
		hashes.append(hash_value)
		var solid := 0
		var within_bounds := true
		var integer_pixels := true
		for y in range(75):
			for x in range(150):
				var color := frame.get_pixelv(origin + Vector2i(x, y))
				if color != bg:
					solid += 1
					within_bounds = within_bounds and Rect2i(43, 13, 64, 48).has_point(Vector2i(x, y))
		check(within_bounds, "art stays in declared footprint " + Art.IDS[i])
		check(solid > 500, "visible material area " + Art.IDS[i])
		for y in range(0, 48, 2):
			for x in range(0, 64, 2):
				var color := crop.get_pixel(x, y)
				integer_pixels = integer_pixels and color == crop.get_pixel(x + 1, y) and color == crop.get_pixel(x, y + 1) and color == crop.get_pixel(x + 1, y + 1)
		check(integer_pixels, "integer pixels without blur " + Art.IDS[i])
	surface.queue_free()
	await settle()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/part_art/ui"):
		quit(1)
		return
	root.size = Vector2i(1280, 900)
	for id in Ammo.PARTS:
		if id != "none": check(Art.IDS.has(id), "every part has dedicated art " + id)
	await catalog(true)
	await catalog(false)
	await raw_grid()
	print("PART ART UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
