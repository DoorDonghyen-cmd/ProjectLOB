extends "res://tests/playtest_revision_ui_runner.gd"
const Workers = preload("res://redesign/foundry_workers.gd")
const Guard = preload("res://redesign/central_guard.gd")

func set_rows(rows: Array) -> void:
	screen.model.s.enemies=[]
	for row in rows:screen.model.s.enemies.append(Data._enemy(row))
	screen.model.s.reinforcements=[]
	screen.model.s.encounter_total=rows.size();screen.model.s.deployed=rows.size()
	screen.model.assign_opening_lanes();screen.redraw()
	await settle()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/playtest_revision_20261026/"):quit(2);return
	screen=load("res://redesign/main.tscn").instantiate()
	screen.save_enabled=false;screen.presentation_speed=0.04
	root.add_child(screen);await settle()
	for resolution in [Vector2i(1008,630),Vector2i(1280,800)]:
		root.size=resolution;await settle()
		var label:=str(resolution.x)
		await setup_hand(["basic","precise_p3"])
		screen.model.s.gun="heavy";screen.campaign.s.gun="heavy"
		screen.model.s.equipped_parts=["thermal_drive"];screen.campaign.s.equipped_parts=["thermal_drive"];screen.campaign.s.parts=["thermal_drive"]
		screen.model.s.heat=11
		await set_rows([["wall",120,3,1,40],["runner",80,0,1,45]])
		for id in screen.Content.loading_order(["basic","precise_p3"]):await tap("load_"+str(id))
		check(not screen.main_scroll.get_h_scroll_bar().visible,"new heat UI fits "+label)
		var forecast:Dictionary=screen.combat_forecast.duplicate(true)
		check(forecast.shots[1].overdrive_percent==200,"visible forecast carries overdrive "+label)
		await capture("reactor_"+label+"_loaded")
		screen._inspect_slot(1);screen._slot_details();await settle()
		check(screen.calculation_label.text.contains("×2.00(강행)") and screen.calculation_label.text.contains("×70%"),"visible receipt explains heat and armor "+label)
		await capture("reactor_"+label+"_receipt")
		await tap("workspace_close")
		await tap("confirm");await tap("fire")
		check(forecast.enemies==screen.model.s.enemies,"heat forecast equals actual enemies "+label)
		check(screen.last_presentation.shown_enemies==screen.model.s.enemies,"heat animation ends on actual state "+label)
		await capture("reactor_"+label+"_fired")
		for kind in ["foundry","central"]:
			await setup_hand(["basic","pierce_p3","disrupt"])
			var region:=1 if kind=="foundry" else 4
			screen.campaign.s.region=region;screen.model.s.region=region
			var rows:=Workers.revise([Workers.leader(Workers.BOSS,56,30),Workers.worker("mold_worker",12,36)]) if kind=="foundry" else [Guard.unit(Guard.RULER,80,35,2),Guard.unit(Guard.HEAVY,16,40,2),Guard.unit(Guard.RUSHER,9,30,2)]
			await set_rows(rows)
			check(not screen.main_scroll.get_h_scroll_bar().visible,"boss UI fits "+kind+label)
			await capture(kind+"_"+label+"_intent")
			screen._enemy_details(0);await settle()
			var labels=screen.find_children("*","Label",true,false)
			check(labels.any(func(node):return node.text.contains("2행동마다") if kind=="central" else node.text.contains("2번째")),"boss detail matches new clock "+kind+label)
			await capture(kind+"_"+label+"_detail")
			await tap("workspace_close")
	screen._debug_foundry("single","boss");await settle()
	check(screen.debug_session and screen.model.s.combat_revision==2 and screen.model.s.enemies[0].windup_max==2,"real developer foundry entry uses current rules")
	await capture("developer_foundry")
	screen._debug_central_background(2,"boss");await settle()
	check(screen.debug_session and screen.model.s.combat_revision==2 and screen.model.s.enemies[0].command_left==2,"real developer central entry uses current rules")
	await capture("developer_central")
	root.size=Vector2i(1008,630);screen.selected_weapon_id="heavy"
	screen._open_preparation(false);await settle()
	var identity=screen.find_child("WeaponIdentity",true,false)
	check(identity!=null and identity.text.contains("×2"),"new run equipment explains overdrive damage")
	check(not screen.main_scroll.get_h_scroll_bar().visible,"new equipment caption fits")
	await capture("reactor_equipment_1008")
	print("PLAYTEST REVISION PRESSURE UI COMPLETE checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
