extends "res://tests/ammo_cycle_ui_runner.gd"
const Engines = preload("res://redesign/damage_engines.gd")

func close_dialogs() -> void:
	for child in screen.get_children():
		if child is AcceptDialog or child.has_meta("lob_modal"):
			child.hide()
			child.queue_free()
	await settle()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/damage_engines/ui"):
		quit(1)
		return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.02
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1008,630),Vector2i(1280,900),Vector2i(1440,630)]:
		root.size = resolution
		for id in Engines.IDS:
			await setup_hand(["basic","charge","precise","pierce","cool","charge_hot"])
			screen.model.s.outfit = "carrier"
			screen.campaign.s.outfit = "carrier"
			screen.campaign.s.parts = [id]
			screen.campaign.s.equipped_parts = [id]
			screen.model.s.equipped_parts = [id]
			screen.model.s.engine.levels[id] = 4
			if id == "thermal_drive": screen.model.s.heat = Ammo.hot_threshold(screen.model.s)
			screen.hand_layout_key = ""
			screen.redraw()
			await settle()
			cards_fit()
			bounds("combat_part_"+id)
			check(screen.find_child("ammo_synergy",true,false)==null,"no extra synergy guide button")
			await tap("load_basic")
			await tap("load_charge")
			check(screen.model.s.plan == ["charge","basic"],"LIFO support before attack")
			bounds("confirm")
			await capture(id+"_planned_%d" % resolution.x)
			await tap("combat_part_"+id)
			await capture(id+"_detail_%d" % resolution.x)
			await close_dialogs()
			await tap("confirm")
			await tap("fire")
			check(int(screen.model.s.enemies[0].hp)<84,"growth increases actual damage " + id)
			check(screen.battle_view.enemies==screen.model.s.enemies,"presentation matches final state")
			screen._debug_city("reward")
			screen.campaign.s.clears = 1
			screen.campaign.s.build_version = 1
			screen.campaign.s.parts = []
			screen.campaign.s.equipped_parts = []
			screen.model.s.equipped_parts = []
			screen.model.s.engine = Engines.fresh()
			screen.redraw()
			await settle()
			check(screen.campaign.part_rewards()==Engines.IDS,"three growth choices")
			for core in Engines.IDS: bounds("city_reward_"+core)
			if id == "volley_drive": await capture("first_core_%d" % resolution.x)
			await tap("city_core_detail_"+id)
			await capture(id+"_reward_detail_%d" % resolution.x)
			await close_dialogs()
			await tap("city_reward_"+id)
			check(screen.campaign.s.parts.has(id) and screen.campaign.s.equipped_parts.has(id),"reward equips " + id)
		# Reward debrief exposes earned growth, separate from next choice.
		screen._debug_city("reward")
		screen.model.s.engine = Engines.fresh()
		screen.model.s.engine.levels.volley_drive = 1
		screen.model.s.engine.settled = true
		screen.model.s.engine.gains = ["volley_drive"]
		screen.redraw()
		await settle()
		bounds("EngineGrowth")
		await capture("growth_%d" % resolution.x)
	await setup_hand(["precise"])
	screen.model.s.equipped_parts = ["volley_drive","duplex"]
	screen.model.s.enemies = [Data._enemy(["runner",1,0,1,24]),Data._enemy(["wall",90,0,1,29])]
	screen.model.load_round("precise")
	screen.redraw()
	await settle()
	var impact: Dictionary = screen.model.preview()
	screen.battle_view._set_damage_popups(impact)
	check(impact.secondary.size()==2 and screen.battle_view.damage_popups.size()==2,"repeated impacts share one readout per target")
	check(screen.battle_view.damage_popups[1].amount==impact.relay_damage,"merged readout conserves actual secondary damage")
	await tap("confirm")
	await tap("fire")
	check(screen.battle_view.enemies==screen.model.s.enemies,"actual relay animation final state matches simulation")
	check(not screen.save_enabled,"UI saves disabled")
	screen.queue_free()
	await process_frame
	print("DAMAGE ENGINES UI COMPLETE checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
