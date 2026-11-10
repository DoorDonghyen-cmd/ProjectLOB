extends "res://tests/economy_workshop_runner.gd"

func command(c, item: Dictionary) -> bool:
	var step := item.duplicate(true)
	if step.action=="gate" and OS.get_environment("QA_GROWTH_POLICY")=="growth" and c.gate_options().has("growth"):
		step={"action":"gate","id":"growth"}
	return super.command(c,step)

func load_previous_paths() -> void:
	super.load_previous_paths()
	var base := ProjectSettings.globalize_path("res://../qa_runtime/economy_20261029/")
	for tag in ["b1_heavy_carrier","b1_single_burst_carrier","b1_scatter_spike_carrier","b1_scout","b1_expedition","workshop_compress"]:
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base.path_join(tag+"/balance.json")))
		if tag=="workshop_compress" and OS.get_environment("QA_WORKSHOP")!="compress":continue
		for battle in report.battles:
			if battle.solved and battle.outfit==OS.get_environment("QA_OUTFITS"):
				cached_paths["%s/%d/%d/refit" % [battle.gun,int(battle.seed),int(battle.node)]]=battle.path

func write_report() -> void:
	if not battles.is_empty() and not battles.back().has("growth_limit"):
		battles.back().growth_limit=preload("res://redesign/core_growth.gd").limit(initial_state)
	for row in endpoints:row.growth_policy=OS.get_environment("QA_GROWTH_POLICY")
	super.write_report()
