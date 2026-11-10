extends "res://tests/challenge_ui_runner.gd"
var perf_rows: Array = []

func load_record(gun: String, late: bool) -> void:
	var filename := "combat_%s_731042_r%d_n%d.json" % [gun,5 if late else 1,41002 if late else 101]
	var path := ProjectSettings.globalize_path("res://../qa_runtime/central_live/balance/final_731042/").path_join(filename)
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	screen.campaign = Campaign.new()
	screen.campaign.s = record.campaign
	screen.campaign.profile = record.profile
	check(screen.campaign.model.restore_state(record.combat),"real earned UI state restores")
	screen.model = screen.campaign.model
	screen.page = "run"
	screen.debug_session = true
	screen.hand_layout_key = ""
	screen.redraw()
	await settle()

func timing(gun: String, late: bool) -> void:
	await load_record(gun,late)
	var times: Array = []
	for i in 7:
		var start := Time.get_ticks_usec()
		screen.redraw()
		times.append(float(Time.get_ticks_usec()-start)/1000.0)
		await settle()
	times.sort()
	var label := gun+("_late" if late else "_early")
	var row := {"label":label,"redraw_median_ms":times[3],"redraw_max_ms":times.back(),"history_events":screen.model.s.history.size()}
	perf_rows.append(row)
	print(JSON.stringify(row))
	for i in 3:
		var loaded := false
		for button in screen.find_children("load_*","Button",true,false):
			if not button.disabled:
				var start := Time.get_ticks_usec()
				button.pressed.emit()
				row["load_%d_cpu_ms"%i]=float(Time.get_ticks_usec()-start)/1000.0
				loaded = true
				break
		await settle()
		if not loaded: break
	check(not screen.model.s.plan.is_empty(),"production load button accepts input "+label)
	check(not screen.combat_forecast.is_empty(),"visible forecast populated "+label)
	check(not screen.main_scroll.get_h_scroll_bar().visible,"no horizontal clipping "+label)
	await capture(label+"_loaded")
	await tap("confirm");await tap("fire")
	check(screen.last_presentation.shown_enemies==screen.model.s.enemies,"rendered result matches real resolver "+label)
	await capture(label+"_fired")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/playtest_revision_20261026/"):quit(2);return
	screen=load("res://redesign/main.tscn").instantiate()
	screen.save_enabled=false
	screen.presentation_speed=0.04
	root.add_child(screen);await settle()
	if OS.get_environment("QA_REVISION_TAG")=="probes":
		await load_record("burst",true)
		for operation in ["view","layout","theme","forecast","synergy","reload","sync","header","steps"]:
			var start := Time.get_ticks_usec()
			for i in 7:
				match operation:
					"view":screen._new_battle_view().free()
					"layout":screen.CombatWorkbench.instantiate().free()
					"theme":screen.ui_theme.duplicate()
					"forecast":screen.Forecast.analyze(screen.model.s,true,true)
					"synergy":screen.AmmoSynergy.hand_hints(screen.model.s)
					"reload":screen.Forecast.reload_now(screen.model.s,true)
					"sync":screen.battle_view.sync(screen.model.s,screen.combat_forecast)
					"header":screen._combat_header(true)
					"steps":screen._combat_steps(screen.body.find_child("CombatWorkbench",true,false))
			print("PROBE ",operation," ",float(Time.get_ticks_usec()-start)/7000.0," ms")
		print("PLAYTEST REVISION UI COMPLETE checks=%d failures=%d"%[checks,failures]);quit();return
	for gun in ["burst","scatter"]:
		for late in [false,true]:await timing(gun,late)
	FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("ui_performance.json"),FileAccess.WRITE).store_string(JSON.stringify({"rows":perf_rows,"checks":checks,"failures":failures},"  "))
	print("PLAYTEST REVISION UI COMPLETE checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
