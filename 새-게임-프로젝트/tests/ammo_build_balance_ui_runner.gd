extends "res://tests/ammo_cycle_ui_runner.gd"
const Discovery=preload("res://redesign/ammo_discovery.gd")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/ammo_build_balance/"): quit(1);return
	screen=load("res://redesign/main.tscn").instantiate()
	screen.save_enabled=false;screen.presentation_speed=0.02
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1008,630),Vector2i(1280,900),Vector2i(1440,630)]:
		root.size=resolution
		screen._debug_city("reward")
		screen.campaign.s.clears=2
		screen.campaign.s.floor=5;screen.campaign.s.node=501
		screen.campaign.s.parts=["coil"];screen.campaign.s.equipped_parts=["coil"]
		screen.model.s.equipped_parts=["coil"]
		var options: Array=screen.campaign.reward_options()
		check(Discovery.LINKS.coil.has(options[0]),"fire module contributes a reward without a growth core")
		check(not options.any(func(id):return Discovery.PAUSED_AMMO.has(Ammo.source_id(id))),"reward screen has active families")
		screen.redraw()
		await settle()
		for id in options: bounds("city_reward_"+id)
		await capture("reward_%d" % resolution.x)
		var before: int=screen.model.s.deck.count(options[0])
		await tap("city_reward_"+options[0])
		check(screen.model.s.deck.count(options[0])==before+1 and screen.campaign.s.phase=="map","real reward tap adds one owned card and returns to map")
		screen._debug_city("shop")
		check(screen.campaign.s.discovery_version==Discovery.VERSION,"public shop uses new acquisition policy")
		check(not screen.campaign.s.offers.any(func(o):return Discovery.PAUSED_AMMO.has(Ammo.source_id(o.id)) or Discovery.PAUSED_PARTS.has(o.id)),"actual stock excludes paused content")
		await settle()
		# Shop is intentionally scrollable on short screens. Test the reachable action.
		screen.main_scroll.ensure_control_visible(screen.find_child("city_compare_buy_0",true,false))
		await settle()
		bounds("city_compare_buy_0")
		await capture("shop_%d" % resolution.x)
		var offer: Dictionary=screen.campaign.s.offers[0].duplicate()
		before=screen.model.s.deck.count(offer.id)
		var credits: int=screen.campaign.s.credits
		await tap("city_compare_buy_0")
		check(screen.model.s.deck.count(offer.id)==before+1 and screen.campaign.s.credits==credits-offer.price,"real shop tap buys exactly one offered card")
	check(not screen.save_enabled,"UI never writes user campaign")
	screen.queue_free()
	await process_frame
	print("AMMO BUILD BALANCE UI COMPLETE checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
