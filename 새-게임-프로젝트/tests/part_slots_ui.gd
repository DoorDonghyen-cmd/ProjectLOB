extends "res://tests/tag_build_ui.gd"
## Part types by gun component, stage 1 labels (2026-11-11, part_slots.gd): every part has a
## type; the shop label, part details and combat build window name it. Equip rules unchanged.
const Slots = preload("res://redesign/part_slots.gd")
const Ammo = preload("res://redesign/content.gd")

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	output = OS.get_environment("QA_OUTPUT_DIR"); Input.emulate_mouse_from_touch = true
	if FileAccess.file_exists(Campaign.SAVE): DirAccess.remove_absolute(Campaign.SAVE)
	var counts := {}
	for id in Ammo.PARTS:
		if id == "none": continue
		check(Slots.SLOTS.has(id), "type for " + str(id))
		counts[Slots.slot(id)] = int(counts.get(Slots.slot(id), 0)) + 1
		check(Ammo.part_grade_summary(id, {"growth_structure_version": 1}).contains(Slots.name_of(id)) and not Ammo.part_grade_summary(id).contains("모듈"), "summary names the type " + str(id))
	print("TYPES ", counts)
	check(Ammo.part_grade_summary("lens") == "일반 · 총열" and Ammo.part_grade_summary("executioner").ends_with("조준기"), "examples: 가속 총열 = 총열, 처형 조준기 = 조준기")
	for extent in [Vector2i(1280, 800), Vector2i(1008, 454)]:
		root.size = extent
		var suffix := "%dx%d" % [extent.x, extent.y]
		# Shop: the item label and the part details.
		var shop = earned("shop_burst_17_r5_n40401.json", func(data):
			data.campaign.offers[2] = {"id": "lens", "new": true, "price": 30, "sold": false, "type": "part"})
		await mount(shop)
		host.city_ui.shop_selection = 2; host.redraw(); await settle()
		var kind := find("Kind") as Label
		check(kind != null and kind.text == "파츠 · 총열", "shop label 파츠 · 총열 " + suffix + " (" + (kind.text if kind != null else "none") + ")")
		await capture("shop_type_" + suffix)
		await tap("Details")
		var window := find("PartDetails")
		var subtitle: Label = window.get_meta("dialog").get_node("%Subtitle") if window != null else null
		check(subtitle != null and subtitle.text == "일반 · 총열", "details subtitle 일반 · 총열 " + suffix)
		await capture("details_type_" + suffix)
		# Combat build window.
		var combat = earned("combat_heavy_17_r3_n20101.json", func(data): pass)
		await mount(combat)
		var hud: Control = host.campaign_hud
		if hud != null:
			hud.node("Parts").pressed.emit(); await settle()
			var body: String = hud.node("DetailBody").text
			var equipped: Array = Ammo.equipped_parts(combat.model.s)
			check(not equipped.is_empty() and equipped.all(func(id): return body.contains("[%s] %s" % [Slots.name_of(id), Ammo.PARTS[id].name])), "build window tags each part with its type " + suffix)
			await capture("build_type_" + suffix)
	print("PART SLOTS UI checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
