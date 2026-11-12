extends "res://tests/campaign_magazine_ui.gd"

const Trial = preload("res://redesign/samples/elite_shield_trial_data.gd")
const House = Trial.House

func exercise(variant: String, extent: Vector2i) -> void:
	root.size = extent
	var campaign := Trial.make(variant)
	if not check(campaign != null, "enter elite shield trial " + variant): return
	await mount(campaign)
	host.save_enabled = false
	var hud = host.campaign_hud
	var board = hud.board
	var strict := variant == House.PIERCE_ONLY
	var tag := "%s_%d" % [variant, extent.x]
	check(board.get_script().resource_path.ends_with("/noble_view.gd"), "uses native noble battle HUD")
	check(hud.node("Title").text.contains("철갑 전용" if strict else "철갑 약점"), "variant is identified")
	await capture("start_" + tag)
	hud.select_budget(1, false)
	await tap("Fire")
	check(int(board.enemies[0].barrier) == (3 if strict else 2), "first ordinary shot respects the variant")
	check(hud.combo_label.text.contains("노출 대기" if strict else "차폐 −1칸"), "forecast shows next round's shield effect")
	await capture("guard_" + tag)
	if strict:
		check(int(board.enemies[0].shield_open_left) == 1 and House.intent(board.enemies[0], false).contains("1행동"), "on-screen countdown reaches one")
		await tap("Cool")
	else:
		hud.select_budget(1, false)
		await tap("Fire")
		hud.select_budget(1, false)
		await tap("Fire")
	check(int(board.enemies[0].barrier) == 0 and House.intent(board.enemies[0], false).contains("노출"), "real transition is visibly open")
	await capture("open_" + tag)
	hud_bounds()

func exercise_campaign(extent: Vector2i) -> void:
	root.size = extent
	var campaign := Trial.enter_elite()
	if not check(campaign != null, "enter full campaign elite battle"): return
	await mount(campaign)
	host.save_enabled = false
	var hud = host.campaign_hud
	var board = hud.board
	check(hud.node("Title").text == "%s · %s" % [campaign.region_info().name, campaign.node().name], "normal room title is visible")
	check(board.enemies[0].shield_open_left == 2, "real battle begins with two guard actions")
	hud.select_budget(1, false)
	await tap("Fire")
	check(board.enemies[0].shield_open_left == 1, "real HUD replays the guard countdown")
	var plaque: Rect2 = board.enemy_plaque(0)
	var header: Rect2 = board.intent_rect(0)
	check(header.end.y <= plaque.position.y and absf(header.get_center().x - plaque.get_center().x) < plaque.size.x * 0.5, "countdown stays above the elite HP card in the full formation")
	await capture("campaign_guard_%d" % extent.x)
	await tap("Cool")
	check(board.enemies[0].barrier == 0 and board.enemies[0].exposure_left == 3, "real HUD replays the timed opening")
	await capture("campaign_open_%d" % extent.x)
	hud_bounds()

func run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\", "/").contains("/qa_runtime/elite_shield_trial/"): quit(2); return
	Input.emulate_mouse_from_touch = true
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_factor = 1
	for extent in [Vector2i(1280, 800), Vector2i(1008, 454)]:
		await exercise(House.PIERCE_WEAK, extent)
		await exercise(House.PIERCE_ONLY, extent)
		await exercise_campaign(extent)
	if is_instance_valid(host): host.free()
	print("ELITE SHIELD UI COMPLETE checks=%d failures=%d" % [checks, failures.size()]); quit(0 if failures.is_empty() else 1)
