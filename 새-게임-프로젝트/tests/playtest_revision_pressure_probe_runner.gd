extends "res://tests/foundry_campaign_runner.gd"
func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/playtest_revision_20261026/"):quit(2);return
	output=OS.get_environment("QA_OUTPUT_DIR")
	var base:=ProjectSettings.globalize_path("res://../qa_runtime/central_live/balance/")
	var payload=JSON.parse_string(FileAccess.get_file_as_string(base+"pressure_fit_heavy/combat_heavy_731042_r5_n41002.json"))
	var prior=JSON.parse_string(FileAccess.get_file_as_string(base+"revised_builds_fit_heavy/balance.json"))
	var c=Campaign.new();check(c.restore_state(payload),"actual new earned final state restores")
	var path:Array=prior.battles[-1].path
	var trace:Array=[]
	for step in path:
		if c.model.s.phase in ["won","reward","lost"]:break
		if not command(c,step):break
		if step.action in ["fire","reload"]:
			trace.append({"action":step,"phase":c.model.s.phase,"heat":c.model.s.heat,"turn":c.model.s.turns,"targets":c.model.s.enemies.map(func(e):return {"hp":e.hp,"def":e.def,"distance":e.distance,"barrier":e.get("barrier",0)}),"remaining":(c.model.s.hand+c.model.s.draw+c.model.s.magazine).size()})
	FileAccess.open(output.path_join("probe.json"),FileAccess.WRITE).store_string(JSON.stringify({"phase":c.model.s.phase,"campaign_phase":c.s.phase,"trace":trace,"commands":commands},"  "))
	print("PRIOR FIT FINAL PATH phase=",c.model.s.phase," turn=",c.model.s.turns," remaining=",(c.model.s.hand+c.model.s.draw+c.model.s.magazine).size()," hp=",c.model.s.enemies.map(func(e):return e.hp))
	print("PLAYTEST REVISION PRESSURE PROBE COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
