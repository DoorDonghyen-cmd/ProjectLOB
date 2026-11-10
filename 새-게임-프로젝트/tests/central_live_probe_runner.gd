extends "res://tests/central_live_balance_runner.gd"
func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/central_live/"):quit(1);return
	output=OS.get_environment("QA_OUTPUT_DIR")
	solver=preload("res://tests/central_combat_solver.gd").new();solver.candidate_limit=1800
	var variants:Array=[
		{"source":"matrix_17/combat_burst_17_r5_n41002.json","hp":80,"replace_artillery":true},
		{"source":"matrix_17/combat_burst_17_r5_n41002.json","hp":80,"remove_artillery":true}]
	for variant in variants:
		var source:String=variant.source
		var payload=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../qa_runtime/central_live/balance/")+source))
		var c=Campaign.new()
		if not check(c.restore_state(payload),"failure fixture restores"):continue
		c.model.s.enemies[0].hp=variant.hp;c.model.s.enemies[0].max_hp=variant.hp
		if variant.has("armor"):
			c.model.s.enemies[0].def=variant.armor;c.model.s.enemies[0].guard_armor=variant.armor
		if variant.get("remove_shield",false):
			c.model.s.reinforcements.remove_at(2);c.model.s.encounter_total-=1
		if variant.has("distance"):
			for enemy in c.model.s.enemies+c.model.s.reinforcements:enemy.distance+=int(variant.distance)
		if variant.get("replace_artillery",false):
			var guard=preload("res://redesign/central_guard.gd")
			c.model.s.enemies[3]=Data._enemy(guard.unit(guard.HEAVY,18,39));c.model.s.enemies[3].lane=3
		if variant.get("remove_artillery",false):
			c.model.s.enemies.remove_at(3);c.model.s.encounter_total-=1;c.model.s.deployed-=1
		var initial=c.model.s.duplicate(true)
		var path:Array=solver.solve(c.model,12,30)
		print("PROBE ",variant," path=",path.size())
		for step in path:
			if not command(c,step):break
		battles.append({"variant":variant,"solved":not path.is_empty() and c.s.phase=="reward","initial":initial,"final":before_save,"path":path,"best":solver.best_state,"best_path":solver.best_path})
		write_report();await process_frame
	print("CENTRAL LIVE PROBE COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
