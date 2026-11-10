extends "res://tests/ammo_upgrade_balance.gd"
## Replay a genuinely earned pre-boss choice; never fabricate a victory or a build.
func _run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/ammo_upgrade_single_20261106/"): quit(2); return
	solver = preload("res://tests/fire_control_solver.gd").new()
	route_policy = "safe"; acquisition_policy = "refit"; rule_version = 3
	run_gun = "amplifier"; run_seed = 17; outfit_id = "carrier"; build_kind = "direct"; preferred_core = "siege_drive"
	var c = Campaign.new()
	var path := "res://../docs/qa/reports/ammo_upgrade_single_2026-11-06/states/spike_final_workshop.json"
	check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(path))),"earned final workshop restores")
	check(UpgradePlan.inspect(c,"charge").valid,"actual choice includes a legal charge upgrade")
	var before: Array = c.model.s.deck.duplicate()
	check(c.resolve("skip") and c.leave(),"public keep choice leaves original pair intact")
	check(c.model.s.deck == before,"decline preserves both originals")
	roundtrip(c)
	var won: bool = await play_run(c)
	check(won and c.s.phase == "won","keeping originals completes the remaining earned route")
	check(c.save() == OK,"completed alternate route saves")
	var restored = Campaign.new()
	check(restored.restore() and restored.s.phase == "won","alternate ending resumes")
	write_report()
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"won":won,"phase":c.s.phase},"\t"))
	print("AMMO UPGRADE RECOVERY COMPLETE checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
