extends "res://tests/build_feedback_runner.gd"
const Campaign = preload("res://redesign/campaign.gd")
const Data = preload("res://redesign/campaign_content.gd")

func fit(keys: Array) -> void:
	for key in keys:
		var node := screen.find_child(key, true, false) as Control
		check(node != null and node.is_visible_in_tree() and Rect2(Vector2.ZERO, screen.size).encloses(node.get_global_rect()), "visible bounds " + key)
	check(not screen.main_scroll.get_h_scroll_bar().visible, "no horizontal scrolling")

func begin(gun: String = "burst") -> void:
	screen.campaign = Campaign.new()
	screen.campaign.start(gun, 731042)
	screen.model = screen.campaign.model
	screen.page = "run"
	screen.redraw()
	await settle()

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/weapons/ui/"):
		quit(2)
		return
	output = OS.get_environment("QA_OUTPUT_DIR")
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.01
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1008, 630), Vector2i(1280, 800), Vector2i(1440, 630)]:
		root.size = resolution
		screen.preferences.data.text_scale = 1.1
		await begin()
		await tap("map_node_102")
		var route := screen.find_child("MapRouteDetail", true, false) as Label
		check(route.text.contains("−2m") and route.text.contains("+6Cr") and route.text.contains("전열 2"), "route preview exposes exact risk, reward and formation")
		fit(["MapRouteSheet", "city_enter_102"])
		await capture("route_" + str(resolution.x))
		await tap("city_enter_102")
		check(screen.model.s.hand.has("charge") and screen.model.s.hand.has("precise"), "actual first encounter has example pair")
		var hint := screen.find_child("EncounterLesson", true, false) as Label
		check(hint != null and hint.text.contains("증폭 → 연발"), "first action teaches an order comparison")
		fit(["EncounterLesson", "load_charge", "load_precise", "confirm"])
		await capture("first_fight_" + str(resolution.x))
		await tap("load_charge")
		await tap("load_precise")
		await tap("confirm")
		await tap("fire")
		check(screen.last_presentation.shown_enemies == screen.model.s.enemies, "guided combat presents actual model results")
	root.size = Vector2i(1008, 630)
	await begin("heavy")
	await tap("map_node_101")
	await tap("city_enter_101")
	check((screen.find_child("EncounterLesson", true, false) as Label).text.contains("소이 → 충격"), "heavy opening teaches its own plan")
	await capture("heavy_opening")
	screen.preferences.data.hints = false
	screen.redraw()
	await settle()
	check(screen.find_child("EncounterLesson", true, false) == null, "experienced player can hide lessons")
	screen.preferences.data.hints = true
	screen._debug_city("shop")
	screen.campaign.s.credits = 30
	screen.redraw()
	await settle()
	await tap("city_part_info_1")
	var compare := screen.find_child("OfferCompareBody", true, false) as Label
	check(compare != null and compare.text.contains("▲"), "shop explains benefit")
	var buy := screen.find_child("city_compare_buy_1", true, false) as Button
	check(buy.text.contains("잔액 0") and not buy.disabled, "first part purchase shows remaining money")
	fit(["city_compare_buy_1", "city_reroll", "city_leave"])
	await capture("first_part_shop")
	await tap("city_compare_buy_1")
	check(screen.campaign.s.credits == 0 and screen.campaign.equipped_parts().size() == 1, "purchase spends once and equips real part")
	await tap("city_part_info_2")
	check((screen.find_child("city_compare_buy_2", true, false) as Button).text.contains("30Cr 부족"), "insufficient funds explains required amount")
	screen.campaign.s.credits = 20
	screen.redraw()
	await settle()
	await tap("city_reroll")
	check(screen.campaign.s.credits == 17 and (screen.find_child("city_reroll", true, false) as Button).text.contains("5Cr"), "first refresh charges 3 and shows next 5")
	await tap("city_reroll")
	check(screen.campaign.s.credits == 12 and (screen.find_child("city_reroll", true, false) as Button).text.contains("7Cr"), "second refresh charges 5 and shows next 7")
	await capture("shop_after_refresh")
	screen._debug_city("deck")
	screen.campaign.s.parts.append("reserve")
	screen.city_ui.deck()
	await settle()
	await tap("city_part_select_reserve")
	await tap("part_rules")
	check(screen.find_child("PartDetails", true, false) != null, "part workbench explains changed reserve rule")
	await capture("reserve_rule")
	FileAccess.open(output.path_join("progression_ui.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	print("PROGRESSION UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
