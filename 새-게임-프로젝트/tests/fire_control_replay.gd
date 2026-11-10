extends "res://tests/fire_control_climb.gd"
func _run()->void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/fire_control_20261102/"):quit(2);return
	for label in ["climb_vent_four","climb_scatter_route","climb_scatter17_vent"]:
		var path: String=ProjectSettings.globalize_path("res://../qa_runtime/fire_control_20261102/")+str(label)+"/balance.json"
		var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		for endpoint in report.endpoints:
			if not check(endpoint.won,"source is a completed earned route"):continue
			var c=Campaign.new();c.start(endpoint.gun,int(endpoint.seed),0,"balanced",3,"carrier",true)
			commands=[]
			for step in endpoint.commands:
				var expected_turns: int=int(step.get("turns",-1))
				if not command(c,step.duplicate(true)):break
				if expected_turns>=0:check(c.model.s.turns==expected_turns,"current model preserves recorded action timing")
			check(c.s.phase=="won" and c.profile.wins==1,"current source replays whole earned climb and one award")
			endpoints.append({"gun":endpoint.gun,"seed":endpoint.seed,"source":label,"won":c.s.phase=="won","turns":c.model.s.turns})
			print("REPLAY ",endpoint.gun," ",endpoint.seed," ",c.s.phase)
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"runs":endpoints},"  "))
	print("FIRE CONTROL COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
