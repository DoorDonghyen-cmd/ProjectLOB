extends "res://tests/playtest_revision_combat_ui_runner.gd"
const Payoff = preload("res://redesign/combat_payoff.gd")

func begin_touch(key: String) -> void:
	var button=screen.find_child(key,true,false)
	check(button is Button and not button.disabled,"touch enabled "+key)
	if not button is Button or button.disabled:return
	var point: Vector2 = root.get_final_transform()*(button.get_screen_transform()*(button.size*0.5)-Vector2(DisplayServer.window_get_position()))
	for down in [true,false]:
		var event:=InputEventScreenTouch.new();event.index=0;event.position=point;event.pressed=down
		Input.parse_input_event(event);await process_frame

func prepare(build: String) -> void:
	var recipe: Dictionary=RECIPES[build]
	await setup_hand(recipe.order)
	screen.model.s.gun="burst";screen.campaign.s.gun="burst"
	screen.model.s.equipped_parts=recipe.parts.duplicate()
	screen.campaign.s.equipped_parts=recipe.parts.duplicate();screen.campaign.s.parts=recipe.parts.duplicate()
	screen.model.s.engine.levels[recipe.parts[0]]=8;screen.model.s.heat=recipe.heat
	screen.model.s.enemies=[Data._enemy(["wall",140,5,1,30]),Data._enemy(["runner",30,0,2,34])]
	screen.model.s.encounter_total=2;screen.model.s.deployed=2;screen.model.assign_opening_lanes()
	screen.redraw();await settle()
	for id in screen.Content.loading_order(recipe.order):await tap("load_"+str(id))
	await tap("confirm")

func shoot(label: String, mode: String = "normal", skip: bool = false) -> void:
	var expected: Dictionary=screen.combat_forecast.duplicate(true)
	await capture(label+"_ready")
	await begin_touch("fire")
	var seen := false
	var trail := false
	var started:=Time.get_ticks_msec()
	while screen.busy and Time.get_ticks_msec()-started<20000:
		var view=screen.battle_view
		if not view.build_signature.is_empty() and int(view.build_signature.rank)>=5 and not view.bullet.is_empty() and view.bullet_progress>0.45 and not trail:
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join(label+"_trail.png"))==OK,"flight captured "+label)
			trail=true
		if view.float_target>=0 and not view.build_signature.is_empty() and int(view.build_signature.rank)>=5 and not seen:
			check(not view.salvo_receipt.is_empty(),"actual hit has build receipt "+label)
			for item in view.damage_popup_layout():check(Rect2(Vector2.ZERO,view.size).encloses(item.bounds),"hit numbers remain in field")
			await RenderingServer.frame_post_draw
			check(root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join(label+"_impact.png"))==OK,"impact captured "+label)
			seen=true
			if skip:await begin_touch("skip_animation")
		await process_frame
	check(not screen.busy,"animation completes "+label)
	if mode=="normal":check(seen and trail,"shot and hit signatures observed "+label)
	check(screen.model.s.enemies==expected.enemies,"forecast equals actual result "+label)
	check(screen.last_presentation.get("shown_enemies",[])==screen.model.s.enemies,"animation matches result "+label)
	var receipt:=Payoff.last_receipt(screen.model.s)
	check(screen.battle_view.salvo_receipt==receipt and not receipt.is_empty(),"receipt survives redraw "+label)
	check(screen.preview_label.visible and screen.preview_label.text.contains(str(receipt.get("summary","missing"))),"persistent text summary "+label)
	check(is_equal_approx(Engine.time_scale,1.0),"no simulation time change")
	await capture(label+"_result")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/playtest_revision_20261026/"):quit(2);return
	Input.emulate_mouse_from_touch=true;Input.emulate_touch_from_mouse=true
	screen=load("res://redesign/main.tscn").instantiate();screen.save_enabled=false;screen.presentation_speed=0.65
	root.add_child(screen);await settle()
	for resolution in [Vector2i(1008,630),Vector2i(1280,800),Vector2i(1440,630)]:
		root.size=resolution;await settle()
		for build in RECIPES:
			await prepare(build)
			await shoot(build+"_"+str(resolution.x))
			check(not screen.main_scroll.get_h_scroll_bar().visible,"no horizontal overflow")
	for mode in ["fast","instant"]:
		screen.preferences.data.motion=mode
		await prepare("siege");await shoot("siege_"+mode,mode)
	screen.preferences.data.motion="normal"
	await prepare("volley");await shoot("volley_skip","normal",true)
	root.size=Vector2i(1008,630)
	for revision in [0,2]:
		screen._debug_city("reward");screen.model.s.combat_revision=revision
		screen.redraw();await settle()
		for id in screen.Model.Engines.IDS:
			var rule: String=screen.Model.Engines.growth_rule(screen.model.s,id)
			check(screen.find_children("*","Label",true,false).any(func(node):return node.text==rule),"core reward copy matches calculation")
		await capture("core_rules_"+str(revision))
	for level in [1,2]:
		screen._debug_city("reward")
		screen.campaign.s.clears=3;screen.campaign.s.opening_reward_step=2
		screen.model.s.engine.levels={"volley_drive":level};screen.model.s.engine.gains=["volley_drive"]
		screen.redraw();await settle()
		var growth=screen.find_child("EngineGrowth",true,false)
		check(growth!=null and growth.text.contains("축적" if level==1 else "→"),"growth UI distinguishes accumulated and effective level")
		if growth!=null:check(growth.get_viewport_rect().encloses(growth.get_global_rect()),"growth copy fits small screen")
		await capture("growth_"+str(level))
	FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("payoff_ui.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("PLAYTEST REVISION PAYOFF UI COMPLETE checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
