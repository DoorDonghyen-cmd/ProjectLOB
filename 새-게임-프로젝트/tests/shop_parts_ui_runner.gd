extends "res://tests/ammo_grade_ui_runner.gd"

func shop_fixture() -> void:
	screen._debug_city("shop")
	screen.campaign.s.parts=["volley_drive","radiator","lens","loader","supply","field_press","thermal_drive","compression_sink"]
	screen.campaign.s.equipped_parts=["volley_drive","radiator","lens","loader","supply"]
	screen.model.s.equipped_parts=screen.campaign.s.equipped_parts.duplicate()
	screen.campaign.s.offers=[{"id":"charge","type":"ammo","price":12,"sold":false},{"id":"field_press","type":"part","price":30,"sold":false},{"id":"thermal_drive","type":"part","price":40,"sold":false}]
	screen.campaign.s.parts.erase("field_press")
	screen.campaign.s.parts.erase("thermal_drive")
	screen.campaign.s.shop_part_bought=false
	screen.campaign.s.credits=100
	screen.city_ui.shop_selection=1
	screen.redraw()
	await settle()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/shop_parts/"): quit(1);return
	screen=load("res://redesign/main.tscn").instantiate()
	screen.save_enabled=false
	screen.presentation_speed=0.02
	root.add_child(screen)
	await settle()
	var baseline := OS.get_cmdline_user_args().has("--baseline")
	if not baseline:
		var preview: Control=load("res://redesign/shop_workbench.tscn").instantiate()
		check(preview.get_node("%ShopOfferGrid").get_child_count()==3,"authored shop offers visible before runtime binding")
		preview.free()
	for resolution in [Vector2i(1008,630),Vector2i(1280,900),Vector2i(1440,630)]:
		root.size=resolution
		await shop_fixture()
		if not baseline:
			bounds("city_compare_buy_1")
			check(screen.main_scroll.scroll_vertical==0 and not screen.main_scroll.get_v_scroll_bar().visible,"purchase visible on initial viewport without scrolling")
		await capture("shop_%d"%resolution.x)
		await tap("city_part_info_2")
		await capture("shop_core_%d"%resolution.x)
		await tap("city_compare_buy_2")
		check(screen.campaign.s.parts.has("thermal_drive") and not screen.campaign.is_equipped("thermal_drive"),"full loadout purchase goes into storage")
		check(screen.campaign.s.credits==60,"price charged exactly once")
		await tap("city_shop_build")
		await tap("city_part_select_thermal_drive")
		await capture("parts_%d"%resolution.x)
		if baseline: continue
		bounds("city_deck_equip_thermal_drive")
		var deck_before: Array=screen.model.s.deck.duplicate()
		var money_before: int=screen.campaign.s.credits
		await tap("city_deck_equip_thermal_drive")
		check(screen.campaign.is_equipped("thermal_drive") and not screen.campaign.is_equipped("volley_drive"),"core replacement uses legal outgoing core")
		check(screen.campaign.equipped_parts().size()==5 and screen.model.s.deck==deck_before and screen.campaign.s.credits==money_before,"replacement preserves inventory limits deck and credits")
		await tap("city_deck_equip_thermal_drive")
		check(not screen.campaign.is_equipped("thermal_drive"),"unequip returns to storage")
		await tap("city_part_select_thermal_drive")
		await tap("city_deck_equip_thermal_drive")
		check(screen.campaign.is_equipped("thermal_drive"),"empty slot can equip again")
		await capture("equipped_%d"%resolution.x)
		await tap("workspace_close")
		await tap("city_part_info_2")
		check(screen.find_child("city_compare_buy_2",true,false).disabled,"sold offer cannot be bought twice")
		await capture("sold_%d"%resolution.x)
	if not baseline:
		await shop_fixture()
		screen.campaign.s.credits=3
		screen.redraw();await settle()
		var buy: Button=screen.find_child("city_compare_buy_1",true,false)
		check(buy.disabled and buy.text.contains("27Cr 부족"),"insufficient money shows exact shortage")
		await shop_fixture()
		screen.model.s.deck.resize(14);screen.model.s.deck.fill("basic_p2")
		screen.city_ui.shop_selection=0
		screen.redraw();await settle()
		await tap("city_compare_buy_0");await tap("ammo_replace_basic_p2")
		check(screen.model.s.deck.size()==14 and screen.campaign.s.credits==88,"full deck replacement preserves size and charges once")
		check(screen.find_child("ShopHint",true,false).text.contains("기본탄과 교체"),"purchase feedback matches replacement instead of append")
		await shop_fixture()
		screen.campaign.s.parts=[];screen.campaign.s.equipped_parts=[];screen.model.s.equipped_parts=[]
		screen.city_ui.selected_part_id="none"
		screen.redraw();await settle();await tap("city_shop_build")
		check(not screen.find_child("city_deck_equip_none",true,false).visible,"empty loadout cannot equip placeholder")
		await capture("empty_parts")
		await tap("workspace_close")
		await shop_fixture()
		screen.campaign.s.phase="combat"
		screen.city_ui.deck();await settle();await tap("equipped_part_detail_0")
		check(not screen.find_child("city_deck_equip_volley_drive",true,false).visible,"combat inspector remains read-only")
		await capture("readonly_parts")
	check(not screen.save_enabled,"player save remains untouched")
	screen.queue_free();await process_frame
	print("SHOP PARTS UI COMPLETE checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
