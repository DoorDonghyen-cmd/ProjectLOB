extends "res://tests/combat_hierarchy_ui_runner.gd"

var recording := false
var busy_capture := false
var case_name := ""
var seen := {}
var pictures := {}
var layout_errors := {}
var popup_frames := 0
var layout_before := {}

func observe() -> void:
	if not recording or not is_instance_valid(screen.battle_view): return
	var view = screen.battle_view
	if view.cooling and view.reload_tick > 0: seen["forced_cooling"] = true
	if view.armor_chips:
		seen["armor_break"] = true
		if case_name != "armor": layout_errors["false armor break "+case_name] = true
	if view.cooling_puff > 0 or view.thermal_release > 0:
		seen["cooling"] = true
		if case_name == "cold_cool": layout_errors["false cooling at zero heat"] = true
		var cooling_key := "cooling_%d" % root.size.x
		if not pictures.has(cooling_key) and not busy_capture and view.cooling_puff > 0.2 and view.cooling_puff < 0.65:
			busy_capture = true
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join(cooling_key+".png"))
			pictures[cooling_key] = true
			busy_capture = false
	for key in layout_before:
		if screen.find_child(key,true,false).get_global_rect() != layout_before[key]: layout_errors["layout "+key] = true
	for control in screen.find_children("UIImpulse","Control",true,false):
		if control.amount > 0: seen["ui_response"] = true
	if screen.magazine_view.shot_response > 0: seen["rail_response"] = true
	var popup_layout: Array = view.damage_popup_layout()
	if popup_layout.is_empty(): return
	popup_frames += 1
	var occupied: Array = []
	for popup in popup_layout:
		var rect: Rect2 = popup.bounds
		var entry: Dictionary = popup.entry
		seen[str(entry.kind)] = true
		if entry.strong: seen["boost"] = true
		if entry.kill: seen["kill"] = true
		if entry.number == "막힘": seen["blocked"] = true
		if entry.label.contains("2연타"): seen["double"] = true
		if not Rect2(Vector2.ZERO,view.size).encloses(rect): layout_errors["outside "+case_name+str(root.size)+str(rect)] = true
		for index in view._alive_indices():
			if rect.intersects(view.enemy_plaque(index)): layout_errors["HUD "+case_name+str(root.size)] = true
			if rect.intersects(view.distance_label_rect(index)): layout_errors["distance "+case_name+str(root.size)] = true
		for prior in occupied:
			if rect.intersects(prior): layout_errors["other popup "+case_name+str(root.size)] = true
		occupied.append(rect)
		if view.FONT.get_string_size(entry.label,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x > rect.size.x: layout_errors["tag width "+entry.label] = true
	var key := "%s_%d" % [case_name,root.size.x]
	if popup_layout.any(func(item): return item.entry.kind == "burn") and case_name == "burn": key = "burn_tick_%d" % root.size.x
	if case_name == "combo" and not popup_layout.any(func(item): return item.entry.strong): return
	if pictures.has(key) or busy_capture or view.pulse < 0.15 or view.pulse > 0.55: return
	busy_capture = true
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join(key+".png"))
	pictures[key] = true
	busy_capture = false

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/combat_feedback/ui"):
		quit(1); return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	await settle()
	screen.preferences.data.motion = "normal"
	screen.presentation_speed = 1.0
	process_frame.connect(observe)
	for resolution in [Vector2i(1008,630),Vector2i(1280,900),Vector2i(1440,630)]:
		root.size = resolution
		for fixture in [["plain",["basic"]],["combo",["precise","charge"]],["chain",["arc"]],["burn",["bore"]],["blocked",["basic"]],["kill",["basic"]],["chain_kill",["arc"]],["armor",["shatter"]],["pierce",["pierce"]],["cool",["cool"]],["cold_cool",["cool"]],["overheat",["charge_hot"]]]:
			case_name = fixture[0]
			await setup_hand(fixture[1])
			screen.model.s.gun = "burst"
			screen.campaign.s.gun = "burst"
			screen.model.s.enemies = [Data._enemy(["runner",40,0,1,14]),Data._enemy(["runner",40,0,1,19]),Data._enemy(["runner",40,0,1,24])]
			screen.model.s.encounter_total = 3
			screen.model.s.deployed = 3
			if case_name == "blocked": screen.model.s.enemies[0].barrier = 1
			if case_name == "kill": screen.model.s.enemies[0].hp = 1
			if case_name in ["armor", "pierce"]: screen.model.s.enemies[0].def = 4
			if case_name == "cool": screen.model.s.heat = 6
			if case_name == "overheat": screen.model.s.heat = 13
			if case_name == "chain_kill":
				screen.model.s.enemies[0].hp = 1
				screen.model.s.enemies[1].hp = 1
			screen.model.assign_opening_lanes()
			await refresh()
			for id in fixture[1]: await tap("load_"+id)
			await tap("confirm")
			var oracle = load("res://redesign/model.gd").new()
			oracle.s = screen.model.s.duplicate(true)
			check(oracle.fire(),"fixture fires")
			layout_before = layout_snapshot()
			recording = true
			await tap("fire")
			recording = false
			check(screen.model.s == oracle.s,"feedback leaves resolved damage and RNG unchanged "+case_name)
			check(screen.battle_view.damage_popups.is_empty(),"no stale number after action")
			check(not screen.battle_view.armor_chips,"no stale armor fragments")
			check(screen.battle_view.thermal_release == 0,"reload steam ends")
			fit()
	# Action keys use native pressed surfaces since the compact-hand redesign.
	for key in ["shot","boost","double","arc","burn","blocked","kill","rail_response","armor_break","cooling","forced_cooling"]: check(seen.has(key),"actual event readout "+key)
	check(popup_frames > 10,"real intermediate frames observed")
	for error in layout_errors: check(false,error)
	check(layout_errors.is_empty(),"popup and fixed UI bounds at every observed frame")
	# Reduced-motion rail response ends immediately.
	screen.preferences.data.motion = "instant"
	await setup_hand(["basic"])
	screen.magazine_view.show_impact()
	check(screen.magazine_view.shot_response == 0,"instant rail avoids pulse")
	await setup_hand(["cool"])
	screen.model.s.heat = 6
	await refresh()
	await tap("load_cool")
	await tap("confirm")
	var instant_oracle = load("res://redesign/model.gd").new()
	instant_oracle.s = screen.model.s.duplicate(true)
	check(instant_oracle.fire(),"instant cooling fixture fires")
	await tap("fire")
	check(screen.model.s == instant_oracle.s,"instant feedback preserves resolved state")
	check(screen.battle_view.cooling_puff == 0 and screen.battle_view.thermal_release == 0,"instant cooling leaves no particles")
	screen.queue_free()
	await process_frame
	print("COMBAT FEEDBACK UI COMPLETE checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
