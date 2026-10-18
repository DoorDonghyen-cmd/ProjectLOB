extends "res://tests/ammo_cycle_ui_runner.gd"
var impact_values: Array = []
var heat_events := 0

func observe_heat(event: Dictionary) -> void:
	if str(event.get("kind", "")) not in ["heat_added", "heat_removed", "kill_cooling", "reload_complete"]: return
	heat_events += 1
	check(screen.find_child("HeatGauge",true,false).current == int(event.heat), "heat event immediately reaches gauge: " + str(event.kind))

func observe_impact(result: Dictionary) -> void:
	var gauge = screen.find_child("HeatGauge",true,false)
	impact_values.append({"actual":result.heat_after,"display":gauge.current})
	check(gauge.current == int(result.heat_after),"impact heat reaches visible gauge")
	check(not gauge.reading_text().contains("예상"), "live impact shows actual heat rather than old prediction")

func check_reading(expected: String) -> void:
	var gauge = screen.find_child("HeatGauge",true,false)
	check(gauge.reading_text() == expected, "primary heat reading: " + expected)
	check(gauge.FONT.get_string_size(gauge.reading_text(), HORIZONTAL_ALIGNMENT_LEFT, -1, gauge.reading_font_size()).x <= gauge.size.x - gauge.READING_LEFT - 4, "primary heat reading fits beside thermometer")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/heat_live/ui"):
		quit(1); return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.2
	root.add_child(screen)
	root.size = Vector2i(1280,900)
	await settle()
	for resolution in [Vector2i(1008,630), Vector2i(1280,900), Vector2i(1440,630)]:
		root.size = resolution
		await setup_hand(["basic","charge","pierce","cool","push"])
		check_reading("발열 0 / 12")
		await tap("load_basic")
		check_reading("발열 0 → 예상 1 / 12")
		await tap("load_pierce")
		check_reading("발열 0 → 예상 4 / 12")
		check(screen.model.s.heat == 0, "loading only previews heat")
		await capture("planned_heat_%d" % resolution.x)
		await tap("remove_selected")
		check_reading("발열 0 → 예상 1 / 12")
		await tap("remove_selected")
		check_reading("발열 0 / 12")
		# Cold-first never exceeds the initial 5; pierce-first raises the peak to 8.
		screen.model.s.heat = 5
		screen.redraw()
		await settle()
		await tap("load_pierce")
		await tap("load_cool")
		check_reading("발열 5 → 예상 5 / 12")
		await tap("slot_next")
		check_reading("발열 5 → 예상 8 / 12")
		await tap("confirm")
		check_reading("발열 5 → 예상 8 / 12")
		await capture("reordered_heat_%d" % resolution.x)
	root.size = Vector2i(1280,900)
	for gun in Ammo.GUNS:
		impact_values.clear()
		await setup_hand(["basic","charge","pierce","cool","push"])
		screen.model.s.gun = gun
		screen.campaign.s.gun = gun
		screen.redraw()
		await settle()
		await tap("load_basic")
		await tap("load_pierce")
		await tap("confirm")
		screen.battle_view.shot_impacted.connect(observe_impact)
		screen.battle_view.feedback_changed.connect(observe_heat)
		await tap("fire")
		var gauge = screen.find_child("HeatGauge",true,false)
		print("HEAT TRACE gun=%s model=%d gauge=%d impacts=%s" % [gun,screen.model.s.heat,gauge.current,impact_values])
		check(int(screen.model.s.heat)>0,"normal shot retains heat "+gun)
		check(gauge.current==int(screen.model.s.heat),"post-fire gauge matches model "+gun)
		await capture("after_"+gun)
	await setup_hand(["basic","charge","pierce","cool","push"])
	screen.model.s.heat = 9
	screen.redraw()
	await settle()
	await tap("load_pierce")
	await tap("load_cool")
	await tap("confirm")
	screen.battle_view.feedback_changed.connect(observe_heat)
	screen.battle_view.shot_impacted.connect(observe_impact)
	await tap("fire")
	check(screen.find_child("HeatGauge",true,false).current == screen.model.s.heat, "cooling round settles to actual heat")
	for motion in ["normal", "instant"]:
		root.size = Vector2i(1008,630)
		screen.preferences.data.motion = motion
		await setup_hand(["basic","charge","pierce","cool","push"])
		screen.model.s.heat = 11
		screen.redraw()
		await settle()
		await tap("load_pierce")
		check(screen.find_child("HeatGauge",true,false).current == 11, "loading preserves actual heat")
		check(screen.find_child("HeatGauge",true,false).prediction.peak_max == 14, "loading forecasts increased heat before cooling")
		await tap("confirm")
		screen.battle_view.feedback_changed.connect(observe_heat)
		screen.battle_view.shot_impacted.connect(observe_impact)
		await tap("fire")
		var cooled_gauge = screen.find_child("HeatGauge",true,false)
		check(cooled_gauge.current == 0 and screen.model.s.heat == 0, "forced reload ends at actual zero")
		check(cooled_gauge.cooling_receipt == "과열 14 → 0 · 강제 냉각", "forced cooling remains explained after redraw " + motion)
		await capture("forced_"+motion)
		await tap("reload")
		check(screen.find_child("HeatGauge",true,false).cooling_receipt.is_empty(), "next action clears stale forced cooling receipt")
	var saved_path := OS.get_environment("QA_OUTPUT_DIR").path_join("reported_save.json")
	if FileAccess.file_exists(saved_path):
		screen.campaign = Campaign.new()
		check(screen.campaign.restore(saved_path), "isolated copy of reported save restores")
		screen.model = screen.campaign.model
		screen.page = "run"
		screen.redraw()
		await settle()
		impact_values.clear()
		screen.battle_view.shot_impacted.connect(observe_impact)
		screen.battle_view.feedback_changed.connect(observe_heat)
		await capture("saved_before")
		await tap("fire")
		print("SAVED HEAT TRACE model=%d impacts=%s" % [screen.model.s.heat,impact_values])
		await capture("saved_after")
	check(heat_events > 0, "live heat events observed")
	print("HEAT LIVE UI COMPLETE checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
