extends "res://tests/reserve_rules_runner.gd"
const Solver = preload("res://tests/city_combat_solver.gd")
func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/reserve/"):quit(1);return
	# Captured from the first full-run comparison before the earned-round guarantee.
	var fixture_state: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/reserve_earned_round.json"))
	var solver=Solver.new()
	solver.candidate_limit=1500
	var evidence: Array=[]
	for option in ["original","first_earned","old_cycle"]:
		var m=Model.new()
		check(m.restore_state(fixture_state),"audit valid")
		if option=="old_cycle":m.s.reserve_version=0
		if option=="first_earned":
			var index:=0
			while index<m.s.draw.size() and Ammo.source_id(m.s.draw[index])=="basic":index+=1
			if index<m.s.draw.size():
				var incoming=m.s.draw.pop_at(index)
				m.s.draw.push_front(m.s.hand.pop_back())
				m.s.hand.push_front(incoming)
		var path: Array=solver.solve(m,12,14)
		evidence.append({"case":option,"solved":not path.is_empty(),"steps":path.size()})
		print("CHOICE ",evidence.back())
	var file=FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("audit.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"  "));file.close()
	print("RESERVE CHOICE COMPLETE checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
