extends "res://tests/fire_control_ui.gd"
func run()->void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/fire_control_20261102/"):quit(2);return
	Input.emulate_mouse_from_touch=true
	var expected_file:=output.path_join("expected.json")
	if OS.get_environment("QA_RESUME_PHASE")=="write":
		var c=Campaign.new();c.start("heavy",731042,0,"balanced",3,"carrier",true);c.enter(101)
		await mount(c);await drag_one();await tap("Fire");await tap("Reload")
		await tap("Select1");await tap("EjectToggle")
		FileAccess.open(expected_file,FileAccess.WRITE).store_string(JSON.stringify({"campaign":c.s,"combat":c.model.s,"profile":c.profile}))
	else:
		host=load("res://redesign/main.tscn").instantiate();root.add_child(host);await settle();await tap("resume")
		var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(expected_file))
		check(canonical({"campaign":host.campaign.s,"combat":host.model.s,"profile":host.campaign.profile})==expected,"new process resumes exact live rules, prefix, retained heat, RNG and ejection")
		hud_bounds();check(host.campaign_hud.current_budget()==1,"new process shows selected one-shot prefix")
		await capture("resumed")
	host.free();await settle()
	print("FIRE CONTROL COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
