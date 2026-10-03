extends SceneTree
const Art = preload("res://redesign/world_art.gd")
const Content = preload("res://redesign/content.gd")
var screen: Control
var failures := 0
var checks := 0
var output := ""

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + label)

func settle() -> void:
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw

func capture(id: String) -> void:
	await settle()
	check(root.get_texture().get_image().save_png(output.path_join(id + ".png")) == OK, "capture " + id)

func visible_bounds(key: String) -> void:
	var control := screen.find_child(key, true, false) as Control
	check(control != null and control.is_visible_in_tree() and Rect2(Vector2.ZERO, screen.size).encloses(control.get_global_rect()), "visible bounds " + key)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/weapons/ui/"):
		quit(1)
		return
	output = OS.get_environment("QA_OUTPUT_DIR")
	root.size = Vector2i(1008, 630)
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	await capture("title_phone")
	for id in ["reclaimer", "workshop", "city_overview", "foundry", "maintenance", "administration", "summit"]:
		check(Art.texture(id).resource_path.ends_with(id + ".png"), "authored asset loaded " + id)
	screen._debug_city("shop")
	await settle()
	for key in ["ShopPrice_0", "ShopPrice_1", "ShopPrice_2", "city_compare_buy_0", "city_buy_compressor", "CurrentBuildPanel"]: visible_bounds(key)
	check(not screen.main_scroll.get_v_scroll_bar().visible, "shop decisions fit without vertical scrolling")
	await capture("shop_phone")
	var offer: Dictionary = screen.campaign.s.offers[1]
	var predicted: bool = screen.city_ui._purchase_will_equip(str(offer.id))
	check(predicted, "new part with free slot predicts automatic equip")
	screen.city_ui._show_shop_offer_compare(screen.find_child("ShopWorkbench", true, false), offer, 1)
	await capture("shop_comparison")
	visible_bounds("city_compare_buy_1")
	check((screen.find_child("OfferCompareTitle", true, false) as Label).text.contains("즉시 장착"), "comparison states actual purchase destination")
	screen._campaign_action("buy", 1)
	await settle()
	check(screen.campaign.is_equipped(str(offer.id)) == predicted, "purchase destination matches actual equipped state")
	check(screen.city_ui._offer_destination(str(offer.id)) == "장착 중", "sold part keeps actual equipped status")
	screen._debug_city("deck")
	await capture("five_part_build")
	visible_bounds("EquippedPartGrid")
	check((screen.find_child("EquippedPartGrid", true, false) as GridContainer).columns == 5, "whole five-part build stays together")
	var equipped: Array = screen.campaign.equipped_parts()
	for id in equipped: visible_bounds("PartCard_" + str(id))
	check(not screen.city_ui._purchase_will_equip("overbore"), "second core and full slots cannot predict auto equip")
	screen._close_workspace()
	for region in range(5):
		screen._debug_city("map")
		screen.campaign.s.region = region
		screen.redraw()
		await capture("map_region_%d" % region)
		screen.campaign.enter(region * 10000 + 101)
		screen.redraw()
		await settle()
		check(screen.battle_view.region == region, "combat uses matching region art")
		visible_bounds("BattleView")
		visible_bounds("AmmoGrid")
		await capture("combat_region_%d" % region)
	screen._debug_city("ending")
	screen.campaign.s.equipped_parts = ["capacitor", "rammer", "sequencer", "opening", "field_press"]
	screen.redraw()
	await capture("ending_phone")
	visible_bounds("retry")
	visible_bounds("EquippedPartStrip")
	# Real model output drives presentation; stable firing positions do not shift.
	screen._debug_weapon("single")
	screen.model.s.plan = []
	screen.model.s.plan_load_order = []
	screen.model.s.hand = ["charge", "precise", "pierce", "bore", "arc"]
	screen.model.s.draw = []
	screen.model.s.deck = screen.model.s.hand.duplicate()
	screen.model.s.equipped_parts = ["opening"]
	screen.model.s.enemies[0].hp = 100
	screen.model.s.enemies[0].max_hp = 100
	screen.model.s.enemies[0].def = 0
	screen.model.s.enemies[0].distance = 24
	check(screen.model.load_round("charge") and screen.model.load_round("precise") and screen.model.confirm(), "combo fixture uses legal commands")
	screen.redraw()
	await settle()
	var original: Array = screen.magazine_view.stack.duplicate()
	screen.presentation_speed = 2.0
	screen._fire.call_deferred()
	await screen.battle_view.shot_started
	await settle()
	check(screen.magazine_view.stack == original and screen.magazine_view.fired_count == 1, "firing marks original slot without shifting order")
	check(screen.preview_label.text.contains("피해"), "shot outcome is visible")
	await create_timer(0.42).timeout
	await capture("combo_first_impact")
	check(screen.battle_view.caption.contains("선두 +2"), "actual part trigger is shown at impact")
	while screen.busy: await process_frame
	check(screen.last_presentation.shown_enemies == screen.last_presentation.after.enemies, "animated enemies match resolved model")
	print("PRODUCTION EXPERIENCE COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
