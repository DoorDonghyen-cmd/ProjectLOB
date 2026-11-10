extends "res://tests/boss_skills_probe.gd"
func run() -> void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/boss_skills_20261106/"): quit(2); return
	var rows: Array=[]
	for tag in ["single","burst","scatter","heavy_elite","amplifier","heavy_scout"]:
		var folder: String=ProjectSettings.globalize_path("res://../qa_runtime/boss_skills_20261106/"+tag)
		var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("balance.json")))
		var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("Roaming/Godot/app_userdata/Last on Board - Core Redesign/city_probe.json")))
		for entry in report.battles:
			if not entry.boss or entry.region!=1: continue
			var file := "combat_%s_%d_r1_n%d.json" % [entry.gun,int(entry.seed),int(entry.node)]
			var c=Campaign.new(); check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(file)))),"earned first-boss replay restores")
			var begin: int=c.model.s.history.size()
			for command in entry.path: check(execute(c.model,command),"committed first-boss command stays legal")
			check(c.model.s.phase in ["reward","won"],"committed first-boss route still completes")
			var original: Array=[]
			for index in range(begin,saved.combat.history.size()):
				if int(saved.combat.history[index].get("node",-1))==int(entry.node): original.append(saved.combat.history[index])
			var actual: Array=c.model.s.history.slice(begin)
			var same: bool=canonical(actual)==canonical(original)
			check(same,"final disruption handler preserves all recorded receipts in earned route "+tag)
			rows.append({"run":tag,"same_receipts":same,"receipt_count":actual.size()})
	FileAccess.open(output.path_join("replay.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows},"  "))
	print("BOSS SKILLS COMPLETE checks=%d failures=%d" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
