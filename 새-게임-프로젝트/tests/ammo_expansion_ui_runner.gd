extends "res://tests/ammo_risk_ui_runner.gd"
const Campaign = preload("res://redesign/campaign.gd")
const Data = preload("res://redesign/campaign_content.gd")
const Ammo = preload("res://redesign/content.gd")
const Card = preload("res://redesign/ammo_card_view.gd")

func fit() -> void:
	check(not screen.main_scroll.get_h_scroll_bar().visible and not screen.main_scroll.get_v_scroll_bar().visible, "combat without overflow " + str(root.size))
	for key in ["BattleView", "AmmoGrid", "QueuePanel", "confirm" if screen.model.s.phase == "plan" else "fire"]:
		var node := screen.find_child(key, true, false) as Control
		check(node != null and Rect2(Vector2.ZERO, screen.size).encloses(node.get_global_rect()), "screen bounds " + key)

func combat(ids: Array, gun: String = "single", ranged: bool = false) -> void:
	screen.campaign = Campaign.new()
	screen.campaign.start(gun, 731042)
	screen.campaign.enter(101)
	screen.model = screen.campaign.model
	screen.model.s.deck = ids.duplicate()
	while screen.model.s.deck.size() < 10: screen.model.s.deck.append("pierce")
	screen.model.begin_encounter()
	screen.model.s.hand = ids.duplicate()
	screen.model.s.draw = screen.model.s.deck.duplicate()
	for id in ids: screen.model.s.draw.erase(id)
	screen.model.s.enemies = [Data._enemy(["wall", 25, 4, 1, 22]), Data._enemy(["spitter", 9, 0, 0, 25]) if ranged else Data._enemy(["absorber", 18, 0, 1, 26])]
	screen.model.assign_opening_lanes()
	screen.model.s.encounter_total = 2
	screen.model.s.deployed = 2
	screen.page = "run"
	screen.hand_layout_key = ""
	screen.redraw()
	await settle()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/ammo_expansion/"):
		quit(1)
		return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.02
	root.add_child(screen)
	await settle()
	# Real campaign map selection and entry before focused, reproducible combat fixtures.
	screen.campaign = Campaign.new()
	screen.campaign.start("single", 731042)
	screen.model = screen.campaign.model
	screen.page = "run"
	screen.redraw()
	await settle()
	await tap("story_skip")
	await tap("map_node_101")
	await tap("city_enter_101")
	check(screen.campaign.s.phase == "combat", "public map entry opens campaign combat")
	check(screen.battle_view.has_signal("projectile_inspected"), "campaign uses integrated pressure renderer")
	await capture("campaign_entry")
	for resolution in [Vector2i(1280, 900), Vector2i(1008, 630), Vector2i(1440, 630)]:
		root.size = resolution
		await settle()
		await combat(["shatter", "precise", "bore", "detonate", "chase"])
		fit()
		await tap("load_shatter")
		await tap("load_precise")
		check(screen.full_forecast.shots[0].armor_removed == 3 and screen.full_forecast.shots[1].damage == 6, "public sequence forecasts armor opening")
		await capture("armor_combo_%d" % resolution.x)
		await tap("confirm")
		await tap("fire")
		check(screen.last_presentation.shown_enemies == screen.model.s.enemies, "presented stripped armor matches model")
		await combat(["charge_hot", "cool", "precise", "bypass", "chase"], "single", true)
		await tap("load_charge_hot")
		await tap("load_precise")
		var cost := screen.find_child("ConfirmCost", true, false) as Label
		check(int(screen.full_forecast.heat.end_max) == 9 and cost.text.contains("1턴"), "high output accumulates heat below the limit without extra reload cost")
		await tap("load_cool")
		cost = screen.find_child("ConfirmCost", true, false) as Label
		check(int(screen.full_forecast.heat.end_max) == 6 and cost.text.contains("1턴"), "cooling lowers projected temperature while keeping normal reload cost")
		fit()
		await capture("heat_choice_%d" % resolution.x)
		await tap("confirm")
		await tap("fire")
		check(screen.model.s.heat == 6 and screen.battle_view.heat_debt == 6, "cooling visual matches current heat")
		await tap("reload")
		check(screen.model.s.projectiles.size() == 1 and screen.battle_view.projectiles == screen.model.s.projectiles, "campaign displays actual launched projectile")
		await capture("campaign_pressure_%d" % resolution.x)
	root.size = Vector2i(1008, 630)
	await settle()
	await combat(["charge_hot", "precise", "bypass", "chase", "cool"], "single", true)
	await tap("load_charge_hot")
	await tap("load_precise")
	await tap("confirm")
	check(int(screen.full_forecast.heat.peak_max) == 9 and screen.find_child("HeatGauge", true, false).visible, "projected heat stays visible after confirm without hover")
	fit()
	await capture("hot_ready_mobile")
	await tap("fire")
	check(screen.model.s.heat == 9 and screen.battle_view.heat_debt == 9, "uncooled heat remains visible")
	await capture("hot_after_fire_mobile")
	root.size = Vector2i(1280, 900)
	await settle()
	await combat(["bore", "detonate", "chase", "bypass", "cool"], "heavy")
	await tap("load_bore")
	await tap("load_detonate")
	check(screen.full_forecast.shots[1].detonation == 6, "weapon-adjusted fire conversion forecast")
	await capture("fire_conversion")
	await tap("confirm")
	await tap("fire")
	check(screen.last_presentation.shown_enemies == screen.model.s.enemies, "detonation consumes displayed burn")
	await combat(["shatter", "precise", "chase", "bypass", "cool"], "scatter")
	await tap("load_bypass")
	await tap("load_chase")
	check(screen.full_forecast.random and screen.full_forecast.shots[0].targets.size() == 1, "scatter excludes front target")
	await capture("scatter_backline")
	# Shop rotates through actual stock, then buys a newly introduced role via public button.
	screen._debug_city("shop")
	screen.campaign.s.region = 1
	screen.campaign.s.floor = 4
	screen.campaign.s.node = 10401
	screen.campaign.s.credits = 500
	screen.campaign._stock_shop(screen.campaign.node())
	screen.redraw()
	await settle()
	for revision in range(12):
		if str(screen.campaign.s.offers[0].id) in ["shatter", "detonate", "chase", "bypass", "cool", "charge_hot"]: break
		await tap("city_reroll")
	var offered := str(screen.campaign.s.offers[0].id)
	check(offered in ["shatter", "detonate", "chase", "bypass", "cool", "charge_hot"], "expanded ammo reaches visible shop")
	await tap("city_offer_compare_0")
	await capture("new_ammo_shop")
	var count: int = screen.model.s.deck.count(offered)
	await tap("city_compare_buy_0")
	check(screen.model.s.deck.count(offered) == count + 1, "public purchase adds actual card")
	await capture("new_ammo_purchased")
	screen.campaign.s.phase = "reward"
	screen.model.s.phase = "reward"
	screen.campaign.s.node = 10501
	screen.campaign.s.floor = 5
	screen.redraw()
	await settle()
	var options: Array = screen.campaign.reward_options()
	await capture("discovery_reward")
	await tap("city_reward_" + str(options[1]))
	check(screen.campaign.s.phase == "map" and screen.model.s.deck.has(options[1]), "discovery reward uses same options as model")
	print("AMMO EXPANSION UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
