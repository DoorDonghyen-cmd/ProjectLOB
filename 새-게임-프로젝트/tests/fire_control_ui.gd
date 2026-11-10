extends "res://tests/campaign_magazine_ui.gd"
func point(id: String)->Vector2:
	var item: Control=host.campaign_hud.node(id)
	return item.get_global_transform_with_canvas()*(item.size*0.5)
func touch(pos: Vector2,down: bool)->void:
	var event:=InputEventScreenTouch.new();event.index=0;event.position=pos;event.pressed=down
	root.push_input(event,true);await process_frame
func motion(pos: Vector2,relative: Vector2)->void:
	var event:=InputEventScreenDrag.new();event.index=0;event.position=pos;event.relative=relative
	root.push_input(event,true);await process_frame
func drag_one()->void:
	var from:=point("Select0")
	await touch(from,true);await motion(from+Vector2(16,0),Vector2(16,0));await touch(from+Vector2(16,0),false);await settle()
func run()->void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/fire_control_20261102/"):quit(2);return
	Input.emulate_mouse_from_touch=true
	if FileAccess.file_exists(Campaign.SAVE):DirAccess.remove_absolute(Campaign.SAVE)
	host=load("res://redesign/main.tscn").instantiate();root.add_child(host);await settle()
	host.preparation_seed="731042";host._open_preparation();await settle();await capture("equipment");await tap("start_single")
	check(host.campaign.s.fire_control_version==1,"actual production start opts into rules")
	host._campaign_action("departure_skip");await settle();host._campaign_action("enter",101);await settle()
	for size in [Vector2i(740,360),Vector2i(844,390),Vector2i(1280,800),Vector2i(2016,908)]:
		root.size=size;await settle();hud_bounds();await drag_one()
		check(host.campaign_hud.current_budget()==1,"drag selects one round at each viewport scale")
		await capture("ready_%dx%d"%[size.x,size.y])
	root.size=Vector2i(844,390)
	for gun in ["single","burst","scatter","heavy","amplifier"]:
		var c=Campaign.new();c.start(gun,731042,0,"balanced",3,"carrier",true);c.enter(101);await mount(c)
		host.campaign_hud.hud.feedback.save_setting("motion","fast")
		var before: Dictionary=canonical(c.model.s)
		await drag_one()
		before.fire_heat_trial.rounds=1
		check(canonical(c.model.s)==canonical(before),"drag only changes selected budget in live campaign")
		var oracle=Model.new();oracle.s=c.model.s.duplicate(true);oracle.fire()
		await tap("Fire");check(canonical(c.model.s)==canonical(oracle.s),"live fire equals selected-prefix real model")
		var saved:=Campaign.new();check(saved.restore() and canonical(saved.model.s)==canonical(c.model.s),"action automatically saves exact live campaign")
		if c.model.s.phase!="ready":continue
		var heat: int=c.model.s.heat;var streak: int=Model.Content.Sustained.count(c.model.s)
		await tap("Reload")
		check(c.model.s.heat==heat and Model.Content.Sustained.count(c.model.s)==streak,"live reload keeps heat and sustained counter")
		await tap("Cool")
		check(Model.Content.Sustained.count(c.model.s)==0 and c.model.s.heat<heat,"live cooling remains separate from reload")
		await tap("Select1");await tap("EjectToggle")
		check(c.model.ejection_remaining()==1,"tap-then-eject still removes a middle round")
		await tap("Menu");await tap("BudgetMore");await tap("MenuClose")
		check(host.campaign_hud.current_budget()==2,"menu alternative edits same prefix")
		print("UI ",gun)
	# Old saves retain their original firing and menu behavior.
	var old: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../qa_runtime/campaign_magazine_20261101/v3_single/rules/combat_single_731042_r1_n401.json")))
	var c=Campaign.new();check(c.restore_state(old),"legacy campaign restores for UI");await mount(c)
	check(not host.campaign_hud.node("BudgetRow").visible,"legacy UI hides unsupported prefix input")
	var before: Dictionary=canonical(c.model.s);await drag_one() # It may select ejection, never consume or add rule keys.
	check(canonical(c.model.s)==before and not c.model.s.has("fire_heat_trial"),"legacy drag cannot enable new combat rules")
	host.free();await settle()
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("FIRE CONTROL COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
