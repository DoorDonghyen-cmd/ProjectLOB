extends "res://tests/actor_motion_ui_runner.gd"

func art_capture(label: String) -> void:
	await settle()
	check(not screen.main_scroll.get_h_scroll_bar().visible, "no horizontal overflow " + label)
	await capture(label)

func region_view(region: int) -> void:
	match region:
		0: screen._debug_challenge("elite")
		1: screen._debug_foundry_background(1)
		2: screen._debug_garden_background(1,"boss")
		3: screen._debug_noble_background(1)
		4: screen._debug_central_background(2)
	await settle()
	screen.model.s.gun = ["single","burst","scatter","heavy","amplifier"][region]
	screen.model.s.weapon_version=1
	screen.redraw()
	await settle()
	screen.battle_view.reduced_feedback=true

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/art_cohesion/"): quit(1); return
	screen=load("res://redesign/main.tscn").instantiate()
	screen.save_enabled=false
	screen.presentation_speed=0.04
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1280,900),Vector2i(1008,630),Vector2i(1440,630)]:
		root.size=resolution
		await settle()
		for region in range(5):
			await region_view(region)
			var view=screen.battle_view
			var original:=hash(screen.model.s)
			for enabled in [false,true]:
				view.cohesive_actor_art=enabled
				view.queue_redraw()
				await art_capture("region%d_%s_%d"%[region+1,"after" if enabled else "before",resolution.x])
			check(hash(screen.model.s)==original,"art never changes combat or RNG")
			fit()
			screen._open_preparation(false);await settle()
			var equipment=screen.find_child("EquipmentScreen",true,false)
			equipment._select_weapon(["single","burst","scatter","heavy","amplifier"][region])
			await art_capture("equipment_%s_%d"%[["single","burst","scatter","heavy","amplifier"][region],resolution.x])
		for kind in ["map","shop","workshop","supply","event"]:
			screen._debug_city(kind);await settle()
			await art_capture("place_%s_%d"%[kind,resolution.x])
		screen._to_menu();await art_capture("title_%d"%resolution.x)
	# Capture an actual new-version Reactor heat warning, then execute its model.
	root.size=Vector2i(1280,900)
	await combat(["basic","basic","basic"],"heavy",true)
	screen.model.s.weapon_version=1;screen.model.s.heat=13
	await set_enemies([["runner",200,0,1,80]])
	for token in ["load_basic","load_basic_2","load_basic_3"]: await tap(token)
	check(screen._heat_consequence(screen.next_forecast).contains("강행 1발"),"Reactor warning describes extra shot")
	check(screen._heat_consequence(screen.next_forecast).contains("4턴"),"Reactor warning uses actual forced cost")
	await art_capture("reactor_heat_plan")
	await tap("confirm");await tap("fire")
	check(screen.model.s.history.back().detail.forced_reload.cost==4,"UI fires Reactor with actual four-turn cost")
	check(screen.last_presentation.shown_enemies==screen.model.s.enemies,"Reactor animation matches resolved targets")
	check(screen.last_presentation.events.any(func(e):return e.kind=="reactor_overdrive"),"extra shot visibly identified")
	await art_capture("reactor_heat_after")
	print("ART COHESION UI COMPLETE checks=",checks," failures=",failures)
	quit(1 if failures else 0)
