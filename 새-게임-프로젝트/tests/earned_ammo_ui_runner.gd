extends "res://tests/ammo_cycle_ui_runner.gd"

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/earned_ammo/"): quit(1);return
	screen=load("res://redesign/main.tscn").instantiate()
	screen.save_enabled=false;screen.presentation_speed=0.02
	root.add_child(screen);await settle()
	for resolution in [Vector2i(1008,630),Vector2i(1280,900),Vector2i(1440,630)]:
		root.size=resolution
		screen._open_preparation(false);await settle()
		var equipment=screen.find_child("EquipmentScreen",true,false)
		check(equipment._start_deck().all(func(id):return Ammo.source_id(id)=="basic"),"equipment previews basic-only deck")
		await tap("starting_deck");await capture("starter_%d"%resolution.x);await tap("DialogClose")
		screen._debug_city("reward");await settle()
		bounds("city_reward_volley_drive");await capture("core_%d"%resolution.x)
		await tap("city_reward_volley_drive")
		check(screen.campaign.first_ammo_reward(),"core selection advances to special selection")
		var choices: Array=screen.campaign.reward_options()
		for id in choices: bounds("city_reward_"+id)
		await capture("first_special_%d"%resolution.x)
		await tap("city_reward_"+choices[0]);await settle()
		bounds("ammo_replace_basic_p1");bounds("ammo_acquire_add")
		await capture("exchange_%d"%resolution.x)
		await tap("DialogClose")
		check(screen.campaign.first_ammo_reward() and screen.model.s.deck.size()==10,"cancel does not acquire or consume reward")
		await tap("city_reward_"+choices[0]);await tap("ammo_replace_basic_p1")
		check(screen.campaign.s.phase=="map" and screen.model.s.deck.size()==10 and screen.model.s.deck.count(choices[0])==1,"real touch replaces one basic")
		screen._debug_city("reward");await settle();await tap("city_reward_siege_drive")
		choices=screen.campaign.reward_options()
		await tap("city_reward_"+choices[0]);await tap("ammo_acquire_add")
		check(screen.model.s.deck.size()==11 and screen.campaign.s.phase=="map","append remains explicit alternative")
		screen._debug_city("shop")
		screen.campaign.s.credits=100
		screen.campaign.s.offers[0]={"id":"precise_p2","type":"ammo","price":12,"sold":false}
		screen.model.s.deck.append_array(["basic_p2","basic_p2","basic_p2","basic_p2"])
		screen.redraw();await settle()
		await tap("city_compare_buy_0")
		check(screen.find_child("ammo_acquire_add",true,false).disabled,"full-deck append disabled")
		bounds("ammo_replace_basic_p1");await capture("shop_exchange_%d"%resolution.x)
		await tap("DialogClose")
		check(screen.campaign.s.credits==100 and not screen.campaign.s.offers[0].sold,"cancel purchase leaves wallet untouched")
		await tap("city_compare_buy_0");await tap("ammo_replace_basic_p1")
		check(screen.campaign.s.credits==88 and screen.model.s.deck.size()==14 and screen.campaign.s.offers[0].sold,"paid replacement works at deck cap")
		screen._debug_city("supply");await settle()
		var id: String=screen.campaign.reward_options()[0]
		var source: String=screen.campaign.replaceable_basics().filter(func(item):return item!=id)[0]
		await tap("city_supply_"+id);await tap("ammo_replace_"+source)
		check(screen.campaign.s.resolved and screen.model.s.deck.size()==10 and screen.model.s.deck.has(id),"supply replacement uses same input flow")
	check(not screen.save_enabled,"UI never writes player save")
	screen._debug_city("shop")
	screen.campaign.s.credits=100
	screen.campaign.s.offers[0]={"id":"precise_p2","type":"ammo","price":12,"sold":false}
	screen.model.s.deck[0]="basic_p2_power";screen.model.s.deck[1]="basic_p3_cool"
	screen.redraw();await settle();await tap("city_compare_buy_0")
	var power: Button=screen.find_child("ammo_replace_basic_p2_power",true,false)
	var cool: Button=screen.find_child("ammo_replace_basic_p3_cool",true,false)
	check(power!=null and cool!=null and power.get_node("Margin/Row/Info/Title").text!=cool.get_node("Margin/Row/Info/Title").text,"equal-stat tuned cards remain distinguishable")
	await tap("ammo_replace_basic_p2_power")
	check(not screen.model.s.deck.has("basic_p2_power") and screen.model.s.deck.has("basic_p3_cool"),"replacement removes only selected modified copy")
	screen.queue_free();await process_frame
	print("EARNED AMMO UI COMPLETE checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
