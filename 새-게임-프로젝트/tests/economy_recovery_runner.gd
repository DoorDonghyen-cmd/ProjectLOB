extends "res://tests/economy_campaign_runner.gd"

func command(c, item: Dictionary) -> bool:
	if item.action not in ["exchange","field_compress"]:return super.command(c,item)
	var accepted: bool = c.model.exchange(str(item.id)) if item.action == "exchange" else c.model.field_compress(str(item.id))
	c.sync_combat()
	if not check(accepted,"actual preparation command " + JSON.stringify(item)) or not roundtrip(c):return false
	commands.append(item.duplicate(true))
	return true

func checked_previous_path(c) -> Array:
	var sequence: Array = cached_paths.get("%s/%d/%d/refit" % [run_gun,run_seed,int(c.s.node)],[])
	var trial = solver.clone(c.model)
	var accepted: Array = []
	for step in sequence:
		var ok := false
		match str(step.action):
			"load":ok = trial.load_round(str(step.id))
			"confirm":ok = trial.confirm()
			"fire":ok = trial.fire()
			"reload":ok = trial.reload_magazine()
			"emergency":ok = trial.emergency_resupply()
			"exchange":ok = trial.exchange(str(step.id))
			"field_compress":ok = trial.field_compress(str(step.id))
		if not ok:return []
		accepted.append(step.duplicate(true))
		if trial.s.phase in ["reward","won"]:return accepted
		if trial.s.phase == "lost":return []
	return []

func _run() -> void:
	var user_path := ProjectSettings.globalize_path("user://").replace("\\","/")
	if not user_path.contains("/qa_runtime/economy_20261029/") and not user_path.contains("/qa_runtime/late_growth_20261030/"):quit(2);return
	output = OS.get_environment("QA_OUTPUT_DIR")
	var source := OS.get_environment("QA_ECONOMY_SOURCE")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source))
	var diagnosis: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_PATH_SOURCE")))
	var mode := OS.get_environment("QA_PREPARATION")
	var solution: Dictionary = {}
	for row in diagnosis.rows:
		if row.mode == mode and row.solved:solution = row;break
	if not check(not solution.is_empty(),"validated continuation available"):quit(1);return
	var c = Campaign.new()
	check(c.restore_state(payload),"actual earned checkpoint restores")
	run_gun = c.s.gun;run_seed = int(c.s.seed);outfit = c.s.outfit;heat_rule = 1
	route_policy = "elite";acquisition_policy = "refit"
	preferred_core = {"single":"siege_drive","burst":"volley_drive","scatter":"volley_drive","heavy":"thermal_drive","amplifier":"siege_drive"}[run_gun]
	commands = []
	if mode not in ["current_wide","preparation_options"]:
		var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source.get_base_dir().path_join("balance.json")))
		var prefix: Array = []
		for endpoint in original.endpoints:
			if endpoint.gun == run_gun and int(endpoint.seed) == run_seed and endpoint.outfit == outfit:prefix = endpoint.commands;break
		if not check(not prefix.is_empty() and prefix.back().action == "enter" and int(prefix.back().id) == int(payload.campaign.node),"original legal map preparation located"):quit(1);return
		c = Campaign.new();c.start(run_gun,run_seed,0,"balanced",3,outfit)
		for item in prefix.slice(0,-1):
			if not command(c,item.duplicate(true)):quit(1);return
		check(c.s.phase == "map","loadout changes occur on actual map before entry")
		check(command(c,{"action":"equip","id":"none"}),"unequip legally")
		for id in solution.parts:check(command(c,{"action":"equip","id":id}),"equip owned alternative legally")
		check(command(c,prefix.back().duplicate(true)),"enter original encounter after preparation")
		for key in ["hand","draw","deck","enemies","rng_state","target_rng_state"]:
			check(JSON.parse_string(JSON.stringify(c.model.s[key])) == JSON.parse_string(JSON.stringify(payload.combat[key])),"preparation preserves earned starting " + key)
	solver = preload("res://tests/economy_adaptive_solver.gd").new();solver.candidate_limit = 700
	load_previous_paths()
	cached_paths["%s/%d/%d/refit" % [run_gun,run_seed,int(c.s.node)]] = solution.path
	initial_state = c.model.s.duplicate(true)
	encounter_metrics = {"forced_reloads":0,"forced_turns":0,"normal_reloads":0,"emergency_packs":0,"emergency_turns":0,"heat_peak":0,"sustained_heat":0,"fired":0,"discarded_unfired":0,"traces":[]}
	var won: bool = await play_run(c)
	endpoints.append({"gun":run_gun,"seed":run_seed,"outfit":outfit,"heat_rule":heat_rule,"won":won,"region":int(c.s.region)+1,"phase":c.s.phase,"source":source,"preparation":mode,"continuation":true,"commands":commands.duplicate(true)})
	write_report()
	print("ECONOMY RECOVERY COMPLETE checks=%d failures=%d unresolved=%d won=%s" % [checks,failures.size(),unresolved.size(),won])
	quit(0 if failures.is_empty() else 1)
