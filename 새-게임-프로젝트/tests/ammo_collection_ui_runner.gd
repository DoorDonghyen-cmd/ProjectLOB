extends "res://tests/ammo_cycle_ui_runner.gd"
const Compare = preload("res://redesign/ammo_comparison.gd")
const Art = preload("res://redesign/ammo_art.gd")

func finger(point: Vector2, down: bool) -> void:
	var event:=InputEventScreenTouch.new()
	event.index=0
	event.window_id=root.get_window_id()
	event.position=root.get_final_transform()*point
	event.pressed=down
	Input.parse_input_event(event)
	await process_frame

func swipe(point: Vector2, movement: Vector2) -> void:
	await finger(point,true)
	for i in range(1,13):
		var event:=InputEventScreenDrag.new()
		event.index=0
		event.window_id=root.get_window_id()
		event.position=root.get_final_transform()*(point+movement*i/12.0)
		event.relative=root.get_final_transform().basis_xform(movement/12.0)
		event.screen_relative=event.relative
		Input.parse_input_event(event)
		await create_timer(0.018).timeout
	await finger(point+movement,false)
	await create_timer(0.4).timeout
	await settle()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/ammo_collection/"): quit(1);return
	Input.emulate_mouse_from_touch=true
	Input.emulate_touch_from_mouse=true
	screen=load("res://redesign/main.tscn").instantiate()
	screen.save_enabled=false;screen.presentation_speed=0.02
	root.add_child(screen);await settle()
	for resolution in [Vector2i(1008,630),Vector2i(1280,800),Vector2i(1440,630)]:
		root.size=resolution
		screen._debug_city("reward");await settle()
		await tap("city_reward_volley_drive")
		var offered: Array=screen.campaign.reward_options()
		await capture("reward_%d"%resolution.x)
		await tap("city_reward_"+offered[0])
		for source in screen.campaign.replaceable_basics():
			var button: Button=screen.find_child("ammo_replace_"+source,true,false)
			if button==null: continue
			var labels: Control=button.get_node("Margin/Row/Info")
			check(labels.get_node("Change").text==Compare.changes(source,offered[0],screen.model.s),"replacement compares actual attack/support values")
			check(labels.get_node("Cost").text==Compare.costs(source,offered[0],screen.model.s),"replacement shows heat and footprint")
		await capture("acquisition_%d"%resolution.x)
		await tap("DialogClose")
		screen._debug_city("shop")
		screen.model.s.deck=["basic_p1","basic_p2","basic_p2","pierce_p2","pierce_p2","charge","charge","cool","cool","arc"]
		screen.campaign.s.credits=100
		screen.campaign.s.offers=[{"id":"charge_hot","type":"ammo","price":18,"sold":false},{"id":"bore","type":"ammo","price":12,"sold":false},{"id":"shatter","type":"ammo","price":12,"sold":false}]
		screen.redraw();await settle()
		await tap("city_offer_compare_0")
		bounds("city_compare_buy_0")
		await capture("shop_%d"%resolution.x)
		await tap("city_shop_tune");await tap("city_tune_select_0")
		check(screen.find_child("city_tune_cool",true,false).disabled,"minimum heat cannot be cooled further")
		check(screen.find_child("TuneDelta_cool",true,false).text.contains("최소"),"unavailable tune explains why")
		await tap("city_tune_back");await tap("city_tune_select_1")
		var delta: Label=screen.find_child("TuneDelta_power",true,false)
		check(delta.text.contains(Compare.changes("basic_p2","basic_p2_power",screen.model.s)),"tuning preview uses equipped weapon values")
		await capture("tuning_%d"%resolution.x)
		await tap("city_tune_power")
		check(screen.model.s.deck.count("basic_p2_power")==1 and screen.campaign.s.credits==88,"tuning still changes and charges exactly once")
		await tap("city_shop_press")
		await capture("compression_%d"%resolution.x)
		await tap("city_compress_charge")
		check(screen.model.s.deck.has("charge_c") and screen.campaign.s.credits==70,"support compression changes actual deck and wallet")
		await setup_hand(["basic_p2","pierce_p2","precise_p2","charge","cool"])
		screen.model.s.deck=Ammo.TACTICAL_AMMO.slice(0,14)
		screen.model.begin_encounter();screen.redraw();await settle()
		await tap("ammo_bag")
		var bag: Control=screen.find_child("AmmoBagView",true,false)
		var scroll: ScrollContainer=bag.get_node("BagScroll")
		var before: Dictionary=screen.model.s.duplicate(true)
		var tab_rect: Rect2=bag.get_node("Tabs").get_global_rect()
		var detail_rect: Rect2=bag.get_node("Inspection").get_global_rect()
		var selected: String=bag.inspected_id
		print("BAG RANGE ",scroll.get_v_scroll_bar().max_value," page ",scroll.get_v_scroll_bar().page," logical ",screen.size)
		await swipe(scroll.get_global_rect().get_center(),Vector2(0,-160))
		print("BAG SCROLLED ",scroll.scroll_vertical)
		check(scroll.scroll_vertical>0,"finger scrolls the bag inventory")
		check(bag.get_node("Tabs").get_global_rect()==tab_rect and bag.get_node("Inspection").get_global_rect()==detail_rect,"tabs and selected detail stay fixed")
		check(bag.inspected_id==selected and screen.model.s==before,"swipe does not select, acquire or spend")
		await capture("bag_scrolled_%d"%resolution.x)
		await tap("bag_details")
		check(is_instance_valid(screen.workspace_overlay),"card detail leaves bag open underneath")
		await tap("DialogClose")
		check(screen.model.s==before,"card detail is read only")
		await tap("workspace_close")
		await setup_hand(["bore","push","shatter","detonate","chase","bypass","thermal","vent","charge_heat","charge_hot"],true)
		fit();await capture("combat_family_%d"%resolution.x)
	# All discoverable families have matching art, including the former late-game outliers.
	for id in Ammo.TACTICAL_AMMO+ ["basic"]:
		if id in ["prepare","disrupt"]: continue
		check(Art.Regions.has(id) or Art.SpecialRegions.has(id),"art coverage "+id)
	root.size=Vector2i(1008,630)
	screen.preferences.data.text_scale=1.1
	screen.redraw();await settle()
	await tap("ammo_bag")
	for key in ["bag_tab_all","bag_tab_loaded","bag_tab_draw","bag_tab_discard"]:
		await tap(key);bounds("workspace_close");bounds("BagCardDetails")
	await capture("bag_large_text")
	await tap("workspace_close")
	check(not screen.save_enabled,"player save remains disabled")
	screen.queue_free();await process_frame
	print("AMMO COLLECTION UI COMPLETE checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
