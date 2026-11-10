extends "res://tests/gate_ui_runner.gd"
## RETIRED 2026-11-08 as a run target: checks old gate grid, replaced 2026-11-07. Replaced by: gate_live_ui.
## Current UI suites: docs/qa/ui-test-suites.md

func late_fixture():
	var c=Campaign.new()
	check(c.restore(ProjectSettings.globalize_path("res://../qa_runtime/economy_20261029/b1_single_burst_carrier/gate_single_731042_r2.json")),"earned second gate restores")
	c.s.growth_version=1;c.model.s.growth_version=1
	return c

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/late_growth_20261030/"):quit(2);return
	out=OS.get_environment("QA_OUTPUT_DIR")
	Input.emulate_mouse_from_touch=true;Input.emulate_touch_from_mouse=true
	screen=load("res://redesign/main.tscn").instantiate();screen.save_enabled=true;root.add_child(screen);await settle()
	for size in [Vector2i(1008,630),Vector2i(1280,800),Vector2i(1280,576)]:
		root.size=size;root.content_scale_size=size
		await mount(late_fixture())
		check(screen.find_child("GateUpgradeGrid",true,false).get_child_count()==4,"four available choices")
		check(root.gui_get_focus_owner()==screen.find_child("city_gate_thermal",true,false),"four-choice screen starts with keyboard focus")
		for id in screen.campaign.gate_options():
			var b=screen.find_child("city_gate_"+id,true,false)
			check(b.get_global_rect().position.x>=0 and b.get_global_rect().end.x<=b.get_viewport_rect().size.x,"card fits width "+id)
		var prior: Dictionary=screen.model.s.engine.duplicate(true)
		await tap("city_gate_growth")
		check(screen.model.s.engine==prior and not screen.campaign.gate_ready(),"selection is a preview")
		check(screen.find_child("GateSelectionSummary",true,false).text.contains("성장 완료 시 단타 ×3.50"),"projected gain uses actual core formula")
		for button in screen.find_child("GateUpgradeGrid",true,false).get_children():
			for label in button.find_children("*","Label",true,false):
				check(button.get_global_rect().grow(1).encloses(label.get_global_rect()),"card text stays inside its panel")
		await snap("growth_selected_"+str(size.x)+"x"+str(size.y))
		await tap("city_gate_apply")
		check(screen.model.s.engine==prior and screen.campaign.gate_ready() and Gates.level(screen.model.s,"growth")==1,"confirmation raises only cap")
		await snap("growth_rest_"+str(size.x)+"x"+str(size.y))
		var saved=Campaign.new();check(saved.restore(Campaign.SAVE) and saved.gate_ready() and Gates.level(saved.model.s,"growth")==1,"automatic save retains expansion")
		await mount(saved);await tap("city_gate_depart")
		check(screen.campaign.s.region==2,"new region opens after explicit departure")
	root.size=Vector2i(1008,630);root.content_scale_size=root.size;screen.preferences.data.text_scale=1.2
	await mount(late_fixture());await tap("city_gate_growth");await snap("growth_large_text")
	for button in screen.find_child("GateUpgradeGrid",true,false).get_children():
		for label in button.find_children("*","Label",true,false):
			check(button.get_global_rect().grow(1).encloses(label.get_global_rect()),"large text stays inside its panel")
	await tap("city_gate_apply")
	check(screen.campaign.gate_ready(),"large text selection and confirmation accessible")
	var c=late_fixture();c.s.erase("growth_version");c.model.s.erase("growth_version")
	screen.preferences.data.text_scale=1.0;await mount(c)
	check(screen.find_child("city_gate_growth",true,false)==null,"legacy gate has no new option")
	await snap("growth_legacy")
	FileAccess.open(out.path_join("ui.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("LATE GROWTH UI COMPLETE checks=%d failures=%d" % [checks,failures.size()])
	screen.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
