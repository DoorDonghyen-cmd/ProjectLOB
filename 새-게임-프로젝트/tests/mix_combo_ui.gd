extends "res://tests/tag_float_ui.gd"
## 교차 사격 on screen (2026-11-11, mix_combo.gd): a real 래칫 fight (earned region-3 state)
## with a mixed magazine; fire until a damage number carries 교차+N and capture it.
const Mix = preload("res://redesign/mix_combo.gd")

func catch_cross(label: String) -> Dictionary:
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
				if str(entry.get("label", "")).begins_with("교차"):
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(output.path_join(label + ".png"))
					return entry
			if not host.busy and Time.get_ticks_msec() - started > 400: break
		await settle()
	return {}

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	output = OS.get_environment("QA_OUTPUT_DIR"); Input.emulate_mouse_from_touch = true
	if FileAccess.file_exists(Campaign.SAVE): DirAccess.remove_absolute(Campaign.SAVE)
	for extent in [Vector2i(1280, 800), Vector2i(1008, 454)]:
		root.size = extent
		var suffix := "%dx%d" % [extent.x, extent.y]
		var fight = earned("combat_burst_17_r3_n20502.json", [])
		fight.model.s.mix_combo_version = Mix.VERSION
		# A mixed magazine (the earned deck has 연타탄; add other attack rounds in front).
		fight.model.s.magazine = ["precise_p2", "pierce_p2", "precise_p2", "bore"] + fight.model.s.magazine.slice(0, 2)
		fight.model.s.history.append({"action": "load", "floor": fight.model.s.floor, "turn": fight.model.s.turns, "detail": {}})
		await mount(fight)
		var entry := await catch_cross("cross_float_" + suffix)
		print("CROSS FLOAT ", suffix, " ", entry.get("label", ""), " | ", entry.get("ledger", ""))
		check(str(entry.get("label", "")).begins_with("교차+"), "hit float shows 교차+N " + suffix)
	print("MIX COMBO UI checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
