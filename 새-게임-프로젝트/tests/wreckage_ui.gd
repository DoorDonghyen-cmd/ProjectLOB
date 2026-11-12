extends "res://tests/campaign_magazine_ui.gd"

const Trial = preload("res://redesign/samples/wreckage_trial_data.gd")

func exercise(extent: Vector2i) -> void:
	root.size = extent
	var campaign := Trial.make()
	if not check(campaign != null, "enter foundry trial"): return
	await mount(campaign)
	host.save_enabled = false
	var hud = host.campaign_hud
	var board = hud.board
	var tag := str(extent.x)
	check(board.get_script().resource_path.ends_with("/foundry_view.gd"), "uses live foundry campaign HUD")
	await capture("standing_" + tag)
	hud.select_budget(1, false)
	await tap("Fire")
	check(board.enemies[0].wreckage == 2 and hud.combo_label.text.contains("잔해") and board.target == 0, "real shot leaves visible wreckage and forecasts its next hit")
	var wreck_rect: Rect2 = board._wreckage_rect(0)
	check(is_equal_approx(wreck_rect.end.y, board.enemy_feet(0).y) and wreck_rect.has_point(board._wreckage_point(0)), "sprite and bullet impact share the registered wreck position")
	var rear_hp := int(board.enemies[1].hp)
	await capture("wreckage_" + tag)
	hud.select_budget(1, false)
	await tap("Fire")
	check(board.enemies[0].wreckage == 1 and board.enemies[1].hp == rear_hp, "normal round chips cover")
	await capture("chipped_" + tag)
	hud.select_budget(1, false)
	await tap("Fire")
	check(board.enemies[0].wreckage == 0 and board.enemies[1].hp == rear_hp, "piercing round removes cover")
	await capture("cleared_" + tag)
	hud.select_budget(1, false)
	await tap("Fire")
	check(campaign.model.s.enemies[1].hp < rear_hp, "next cartridge reaches exposed target")
	if is_instance_valid(hud):
		check(not hud.combo_label.text.contains("잔해"), "no stale cover in the next prediction")
		hud_bounds()

func run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\", "/").contains("/qa_runtime/wreckage_trial/"): quit(2); return
	Input.emulate_mouse_from_touch = true
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1
	await exercise(Vector2i(1280, 800))
	await exercise(Vector2i(1008, 454))
	if is_instance_valid(host): host.free()
	print("WRECKAGE UI COMPLETE checks=%d failures=%d" % [checks, failures.size()]); quit(0 if failures.is_empty() else 1)
