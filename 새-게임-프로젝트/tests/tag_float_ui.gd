extends "res://tests/build_engine_ui.gd"
## Tag hit floats on screen (2026-11-11, user: "태그 식별이 어렵고 효과가 있는지 잘 모르겠어").
## A real 리벳 fight (earned region-3 state) with 단타 parts and a copy: fire until a damage
## number carries the tag label, capture that frame, and check the boosted card numbers.
const Tags = preload("res://redesign/tag_build.gd")
const TAG_SET := ["third_striker", "tag_single_add", "tag_single_mult", "tag_copy"]

func catch_tag(label: String) -> Dictionary:
	var hud = host.campaign_hud
	for attempt in range(10):
		if not is_instance_valid(hud) or not host.campaign.s.phase == "combat": return {}
		var fire: Control = hud.node("Fire")
		if fire == null or fire.disabled or not fire.is_visible_in_tree():
			var reload: Control = hud.node("Reload")
			if reload != null and not reload.disabled: await press(reload)
			await settle()
			var waited := Time.get_ticks_msec()
			while host.busy and Time.get_ticks_msec() - waited < 20000: await process_frame
			continue
		await press(fire)
		var started := Time.get_ticks_msec()
		while Time.get_ticks_msec() - started < 20000:
			await process_frame
			if not is_instance_valid(hud) or not is_instance_valid(hud.board): break
			for entry in hud.board.damage_popups:
				if str(entry.get("label", "")).begins_with("단타"):
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(output.path_join(label + ".png"))
					# Fired (emptied) slots drop their chips during the animation too.
					for i in range(hud.slot_count):
						var chips: Control = hud.node("Face%d" % i).get_node_or_null("Tags")
						if not hud.node("Name%d" % i).visible: check(chips == null or not chips.visible, "no chips on an emptied slot %d %s" % [i, label])
					return entry
			if not host.busy and Time.get_ticks_msec() - started > 400: break
		await settle()
	return {}

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	output = OS.get_environment("QA_OUTPUT_DIR"); Input.emulate_mouse_from_touch = true
	if FileAccess.file_exists(Campaign.SAVE): DirAccess.remove_absolute(Campaign.SAVE)
	for extent in [Vector2i(1280, 800), Vector2i(844, 390)]:
		root.size = extent
		var suffix := "%dx%d" % [extent.x, extent.y]
		var fight = earned("combat_single_17_r3_n20101.json", TAG_SET)
		fight.model.s.tag_build_version = Tags.VERSION
		fight.s.equipped_parts = TAG_SET.duplicate()
		fight._sync_equipped_parts()
		await mount(fight)
		var hud = host.campaign_hud
		check(is_instance_valid(hud), "combat HUD mounted " + suffix)
		await capture("tag_cards_" + suffix)
		var green := 0
		for i in range(fight.model.s.magazine.size()):
			if hud.node("Value%d" % i).get_theme_color("font_color") == Tags.BOOSTED: green += 1
		var single_cards: int = fight.model.s.magazine.filter(func(id): return Tags.has_tag(fight.model.s, str(id), "단타") and preload("res://redesign/content.gd").is_attack(str(id))).size()
		print("CARDS %s green %d of %d 단타 attack cards" % [suffix, green, single_cards])
		check(green == single_cards and green > 0, "every 단타 attack card shows a green boosted number " + suffix)
		var entry := await catch_tag("tag_float_" + suffix)
		print("FLOAT ", suffix, " ", entry.get("label", ""), " | ", entry.get("ledger", ""))
		check(str(entry.get("label", "")).begins_with("단타+2×2.25") or str(entry.get("label", "")).begins_with("단타+2×1.5"), "hit float names 단타 with its + and × " + suffix)
		check(entry.get("label_color", Color.BLACK) == Tags.COLORS["단타"], "tag label in the tag colour " + suffix)
	print("TAG FLOAT UI checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
