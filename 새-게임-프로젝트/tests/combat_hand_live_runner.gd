extends "res://tests/ammo_cycle_ui_runner.gd"

func hand(ids: Array, capacity: int) -> void:
	screen._close_workspace()
	await setup_hand(ids,capacity==10)
	screen.model.s.outfit="scout"
	screen.model.s.bag_upgrades=capacity-4
	screen.hand_layout_key=""
	screen.redraw()
	await settle()

func visible_slots() -> Array:
	return screen.find_child("AmmoGrid",true,false).get_children().filter(func(c): return c.visible)

func grid_fit(capacity: int) -> float:
	fit()
	var slots:=visible_slots()
	check(slots.size()==10,"ten stable positions")
	var locked:=0
	var rect: Rect2=slots[0].get_global_rect()
	for slot in slots:
		bounds(str(slot.name))
		check(is_equal_approx(slot.size.y,132),"compact height")
		check(absf(slot.size.x-rect.size.x)<=1,"equal slot width")
		check(is_equal_approx(slot.global_position.y,rect.position.y),"single row")
		if not slot is Button and slot.slot_state=="locked": locked+=1
	check(locked==10-capacity,"only expansion positions locked")
	return rect.size.x

func long_touch(key: String) -> void:
	var button: Control=screen.find_child(key,true,false)
	var point: Vector2=root.get_final_transform()*(button.get_screen_transform()*(button.size*0.5)-Vector2(DisplayServer.window_get_position()))
	var down:=InputEventScreenTouch.new()
	down.index=0;down.position=point;down.pressed=true
	Input.parse_input_event(down)
	await create_timer(0.65).timeout
	var up:=InputEventScreenTouch.new()
	up.index=0;up.position=point;up.pressed=false
	Input.parse_input_event(up)
	await settle()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/combat_hand_live/"): quit(1);return
	var authored: Control=load("res://redesign/combat_workbench.tscn").instantiate()
	authored.set_script(null)
	authored.size=Vector2(1280,780)
	root.add_child(authored)
	await settle()
	var authored_grid: GridContainer=authored.find_child("AmmoGrid",true,false)
	check(authored_grid.columns==10 and authored_grid.get_child_count()==10,"editor composition contains exactly ten representative slots before binding")
	await capture("editor_before_binding")
	authored.free()
	screen=load("res://redesign/main.tscn").instantiate()
	screen.save_enabled=false
	screen.presentation_speed=0.02
	root.add_child(screen)
	await settle()
	var ten: Array=["basic_p1","basic_p1","basic_p3","pierce_p2","precise_p2","charge","cool","arc","basic_p2_power","pierce_p3_cool"]
	for resolution in [Vector2i(1008,630),Vector2i(1280,800),Vector2i(1440,630)]:
		root.size=resolution
		var width:=0.0
		for capacity in [4,6,10]:
			await hand(ten.slice(0,capacity),capacity)
			var current_width:=grid_fit(capacity)
			if width>0: check(is_equal_approx(width,current_width),"bag capacity never stretches cards")
			width=current_width
			await capture("bag%d_%d"%[capacity,resolution.x])
		await tap("load_pierce_p3_cool")
		check(screen.model.s.plan==["pierce_p3_cool"],"tenth visible card accepts touch")
		await tap("remove_selected")
		check(screen.model.s.plan.is_empty(),"tenth card returns without paging")
		await hand(ten.slice(0,6),6)
		var before_height: float=screen.body.size.y
		var before_rect: Rect2=screen.find_child("load_basic_p1_2",true,false).get_global_rect()
		await tap("load_basic_p1_2")
		check(screen.model.s.plan==["basic_p1"],"second duplicate loads once")
		check(screen.find_child("load_basic_p1_2",true,false).disabled and not screen.find_child("load_basic_p1",true,false).disabled,"specific duplicate stays selected")
		check(screen.find_child("load_basic_p1_2",true,false).get_global_rect()==before_rect,"loading preserves card position")
		check(is_equal_approx(screen.body.size.y,before_height),"no vertical growth on loading")
		await long_touch("load_basic_p1_2")
		check(is_instance_valid(screen.workspace_overlay),"loaded disabled card remains inspectable")
		if is_instance_valid(screen.workspace_overlay): await tap("workspace_close")
		await tap("load_charge")
		check(screen.model.s.plan==["charge","basic_p1"],"last insertion fires first")
		check(int(screen.full_forecast.heat.get("peak_max",0))>0,"forecast heat visible while planning")
		await capture("loaded_%d"%resolution.x)
		await tap("remove_selected")
		check(screen.model.s.plan.size()==1,"selected rail card can be returned")
		var state: Dictionary=screen.model.s.duplicate(true)
		await long_touch("load_basic_p3")
		check(is_instance_valid(screen.workspace_overlay),"native long touch opens details")
		check(screen.model.s==state,"inspection does not load or spend time")
		if is_instance_valid(screen.workspace_overlay):
			await capture("detail_%d"%resolution.x)
			await tap("hand_detail_next")
			check(screen.model.s==state,"detail cycling is read only")
			await tap("workspace_close")
		await tap("confirm")
		await tap("fire")
		check(screen.model.s.discard.has("basic_p1"),"fired copy enters discard")
		check(visible_slots().any(func(c): return not c is Button and c.slot_state=="used"),"spent card leaves marked place")
		await capture("spent_%d"%resolution.x)
		await tap("reload")
		check(screen.model.s.hand.size()==6,"six capacity draws six")
		grid_fit(6)
		await hand(["basic_p1","basic_p1","charge","cool","pierce_p2","arc"],6)
		screen.model.s.field_compression_left=1
		screen.redraw();await settle()
		await tap("compress_pair_basic_p1")
		check(screen.model.s.plan.size()==1 and Ammo.is_temporary(screen.model.s.plan[0]),"compression produces actual temporary round")
		check(visible_slots().filter(func(c): return not c is Button and c.slot_state=="compressed").size()==2,"both compressed positions stay reserved")
		await tap("remove_selected")
		check(screen.model.s.hand.count("basic_p1")==2 and screen.model.s.field_compression_left==1,"compression recall restores original pair and charge")
		await tap("exchange")
		await tap("exchange_basic_p1")
		check(screen.model.s.discard.count("basic_p1")==1,"exchange works with individual cards")
		grid_fit(6)
		await hand(["pierce_c","precise_c","charge_c","cool_c","bore_c","arc_c","charge_hot","thermal","vent","sequence"],10)
		grid_fit(10)
		await capture("special_%d"%resolution.x)
	# Current heat, overheat interruption and reload still use the real model.
	root.size=Vector2i(1008,630)
	screen.preferences.data.text_scale=1.1
	await hand(["basic_p1","basic_p2","charge","cool"],4)
	screen.model.s.heat=Ammo.heat_limit(screen.model.s)-1
	screen.redraw();await settle()
	await tap("load_basic_p2")
	check(float(screen.full_forecast.heat.overheat_probability)>0,"overheat warning still tied to forecast")
	grid_fit(4)
	await capture("overheat_large_text")
	await tap("confirm");await tap("fire")
	check(screen.find_child("HeatGauge",true,false).current==screen.model.s.heat,"displayed heat settles to actual model after firing")
	await tap("reload")
	check(screen.find_child("HeatGauge",true,false).current==screen.model.s.heat,"reload cooling settles to actual model")
	check(not screen.save_enabled,"player save remains disabled")
	screen.queue_free();await process_frame
	print("COMBAT HAND LIVE COMPLETE checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
