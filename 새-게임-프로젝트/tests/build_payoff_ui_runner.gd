extends "res://tests/ammo_cycle_ui_runner.gd"
const Engines = preload("res://redesign/damage_engines.gd")

func begin_touch(key: String) -> void:
	var button := screen.find_child(key,true,false) as Button
	check(button!=null and not button.disabled,"begin usable "+key)
	if button==null or button.disabled: return
	var point := root.get_final_transform()*(button.get_screen_transform()*(button.size*0.5)-Vector2(DisplayServer.window_get_position()))
	for pressed in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index=0;event.position=point;event.pressed=pressed
		Input.parse_input_event(event)
		await process_frame

func build(core: String) -> void:
	await setup_hand(["charge","precise","basic","pierce","cool","thermal"])
	screen.campaign=null
	screen.model.s.outfit="carrier"
	screen.model.s.equipped_parts=[core]+(["duplex"] if core=="volley_drive" else [])
	screen.model.s.engine.levels[core]=2
	screen.model.s.enemies=[]
	for row in [["runner",6,0,1,24],["runner",6,0,1,27],["runner",6,0,1,30],["wall",30,3,1,33]]: screen.model.s.enemies.append(Data._enemy(row))
	screen.model.s.encounter_total=4;screen.model.s.deployed=4
	screen.model.assign_opening_lanes()
	if core=="thermal_drive":screen.model.s.heat=5
	screen.hand_layout_key=""
	screen.redraw()
	await settle()
	await tap("load_basic" if core=="siege_drive" else "load_precise")
	await tap("load_charge")
	await tap("confirm")

func watch(name: String, skip: bool = false) -> void:
	await begin_touch("fire")
	var view = screen.battle_view
	var captured := false
	var started := Time.get_ticks_msec()
	while screen.busy and Time.get_ticks_msec()-started<15000:
		if view.payoff_tier==2 and not captured:
			check(view.salvo_kills.size()>=2,"payoff uses resolved multi kills")
			check(view.salvo_damage>=12,"payoff totals actual damage")
			for item in view.damage_popup_layout():
				check(Rect2(Vector2.ZERO,view.size).encloses(item.bounds),"damage readout inside field")
			var kinds: Array=[]
			for event in view.chain_targets:kinds.append(str(event.kind))
			check(kinds.has("heat_wave" if name.begins_with("thermal") else "overflow" if name.begins_with("siege") else "relay"),"core-specific follow-up event")
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join(name+".png"))==OK,"capture actual payoff")
			captured=true
			if skip: await begin_touch("skip_animation")
		await process_frame
	check(captured and not screen.busy,"payoff captured and action completes")
	check(is_equal_approx(Engine.time_scale,1.0),"no global time manipulation")
	await settle()
	check(screen.last_presentation.shown_enemies==screen.model.s.enemies,"animation and model end equal")
	check(screen.battle_view.damage_popups.is_empty() and screen.battle_view.payoff_tier==0,"temporary feedback clears")

func production_roster(width: int) -> void:
	screen.campaign = Campaign.new()
	screen.campaign.start("single",731042,0,"balanced",2,"carrier")
	check(screen.campaign.enter(int(screen.campaign.choices()[0].id)),"real new campaign enters combat")
	screen.model=screen.campaign.model
	screen.page="run";screen.debug_session=true;screen.hand_layout_key=""
	screen.redraw()
	await settle()
	check(screen.battle_view.get_script().resource_path=="res://redesign/residential_battle_view.gd","new roster uses production residential art")
	check(screen.model.s.enemies.all(func(e):return e.has("species")),"new campaign actors have residential identity")
	await capture("new_campaign_%d" % width)
	# Layout fixture populated through the same production encounter generator.
	var node := {"id":401,"region":0,"floor":4,"kind":"combat","name":"QA","elite":false}
	var pack := Data.encounter_pack(node,731042,"single",0,0,3)
	screen.model.s.enemies=pack.active.duplicate(true)
	screen.model.s.reinforcements=pack.reserve.duplicate(true)
	screen.model.s.encounter_total=pack.total;screen.model.s.deployed=pack.active.size()
	screen.model.assign_opening_lanes()
	screen.redraw()
	await settle()
	check(screen.battle_view.enemies.size()==4 and screen.model.s.reinforcements.size()==4,"expanded population keeps four visible actors")
	cards_fit();bounds("reload")
	await capture("residential_wave_%d" % width)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/build_payoff/"):quit(1);return
	screen=load("res://redesign/main.tscn").instantiate()
	screen.save_enabled=false;screen.presentation_speed=0.8
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1008,630),Vector2i(1280,900),Vector2i(1440,630)]:
		root.size=resolution
		for core in Engines.IDS:
			await build(core)
			cards_fit()
			bounds("fire")
			await capture(core+"_plan_%d" % resolution.x)
			await watch(core+"_impact_%d" % resolution.x)
		await production_roster(resolution.x)
		# First core reward remains accessible.
		screen._debug_city("reward")
		screen.campaign.s.clears=1
		screen.redraw()
		await settle()
		bounds("city_reward_thermal_drive")
		await capture("core_choice_%d" % resolution.x)
		await tap("city_reward_thermal_drive")
		check(screen.campaign.equipped_parts().has("thermal_drive"),"core selection remains accessible")
	await build("thermal_drive")
	await watch("thermal_drive_skipped",true)
	screen.preferences.data.motion="instant"
	await build("volley_drive")
	check(screen.battle_view.reduced_feedback,"instant motion disables decorative movement")
	await tap("fire")
	check(not screen.busy and screen.last_presentation.shown_enemies==screen.model.s.enemies,"reduced feedback preserves outcome")
	check(not screen.save_enabled,"UI saves disabled")
	screen.queue_free()
	await process_frame
	print("BUILD PAYOFF UI COMPLETE checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
