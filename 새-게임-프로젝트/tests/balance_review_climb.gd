extends "res://tests/economy_roles_climb.gd"
## Fresh earned campaigns; compare the same public acquisition policy, not injected builds.
var pressure_metrics: Dictionary = {}
var review_revision := 0

func choose_parts(c) -> bool:
	var desired := preferred_core
	if desired == "inferno" and not c.s.parts.has("inferno"):
		preferred_core = "thermal_drive"
	var accepted: bool = super.choose_parts(c)
	preferred_core = desired
	return accepted

func greedy(state: Dictionary) -> Dictionary:
	var m = Campaign.Model.new()
	m.s = Campaign.Model.simulation_state(state)
	var steps := 0
	while m.s.phase == "ready" and steps < 100:
		var accepted: bool
		if m.can_emergency_resupply(): accepted = m.emergency_resupply()
		elif m.s.magazine.is_empty(): accepted = m.reload_magazine()
		else: accepted = m.fire()
		if not accepted: break
		steps += 1
	return {"won":m.s.phase in ["won", "reward"], "phase":m.s.phase,
		"commands":steps, "turns":int(m.s.turns)-int(state.turns), "remaining":m.Reserve.remaining(m.s)}

func command(c, item: Dictionary) -> bool:
	if item.action == "reward" and c.engine_reward() and preferred_core == "inferno":
		item = item.duplicate(true); item.id = "thermal_drive"
	var combat: bool = c.s.phase == "combat"
	var key := "%s/%d/%s" % [run_gun,run_seed,str(c.s.node)]
	var accepted: bool = super.command(c,item)
	if accepted and item.action == "enter" and c.s.phase == "combat":
		pressure_metrics["%s/%d/%s" % [run_gun,run_seed,str(c.s.node)]] = {
			"greedy":greedy(c.model.s), "event_kinds":{}, "reload_burn":0, "forced_burn":0, "nearest_during_action":1000000}
	if accepted and combat and pressure_metrics.has(key) and item.action in ["fire","cool","reload","emergency"]:
		var row: Dictionary = pressure_metrics[key]
		var wanted: String = "reload" if item.action == "emergency" else str(item.action)
		var detail: Dictionary = {}
		# Automatic magazine loading follows a reload. Read the command's receipt,
		# not that later load receipt, to retain all elapsed enemy actions.
		for index in range(before_save.history.size()-1,-1,-1):
			if before_save.history[index].action == wanted:
				detail = before_save.history[index].detail; break
		for event in detail.get("advance_events",[]):
			var kind: String = event.get("kind", "")
			row.event_kinds[kind] = int(row.event_kinds.get(kind,0))+1
			if kind == "burn" and item.action == "reload": row.reload_burn += int(event.damage)
		for event in detail.get("forced_cooling",{}).get("advance_events",[]):
			if event.get("kind", "") == "burn": row.forced_burn += int(event.damage)
		for event in detail.get("advance_events",[]) + detail.get("forced_cooling",{}).get("advance_events",[]):
			if event.get("kind", "") in ["move","pull","projectile_move"]:
				row.nearest_during_action = mini(int(row.nearest_during_action), int(event.get("to",1000000)))
	return accepted

func write_report() -> void:
	for battle in battles:
		var key := "%s/%d/%d" % [battle.gun,int(battle.seed),int(battle.node)]
		battle.pressure_metrics = pressure_metrics.get(key,{})
	super.write_report()

func _run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/balance_review_20261106/"): quit(2); return
	solver = preload("res://tests/fire_control_solver.gd").new()
	route_policy = "safe"; acquisition_policy = "refit"; rule_version = 3
	run_gun = OS.get_environment("QA_GUN"); run_seed = int(OS.get_environment("QA_SEED"))
	outfit_id = OS.get_environment("QA_OUTFIT"); review_revision = int(OS.get_environment("QA_REVISION"))
	build_kind = {"single":"direct","burst":"control","scatter":"control","heavy":"fire","amplifier":"direct"}[run_gun]
	role_build = build_kind == "fire"
	preferred_core = OS.get_environment("QA_CORE")
	if preferred_core.is_empty(): preferred_core = {"single":"siege_drive","burst":"volley_drive","scatter":"volley_drive","heavy":"thermal_drive","amplifier":"siege_drive"}[run_gun]
	var c = Campaign.new(); c.start(run_gun,run_seed,0,"balanced",4,outfit_id,true)
	# This runner isolates the first balance pass from later enemy revisions.
	c.s.erase("enemy_pattern_version"); c.model.s.erase("enemy_pattern_version")
	c.s.erase("boss_skills_version"); c.model.s.erase("boss_skills_version")
	if review_revision == 0:
		c.s.erase("balance_version"); c.model.s.erase("balance_version")
	roundtrip(c)
	var won: bool = await play_run(c)
	endpoints.append({"gun":run_gun,"seed":run_seed,"outfit":outfit_id,"revision":review_revision,
		"core":preferred_core,"won":won,"phase":c.s.phase,"region":c.s.region,"credits":c.s.credits,
		"deck":c.model.s.deck,"parts":c.s.equipped_parts,"commands":commands.duplicate(true)})
	write_report()
	print("BALANCE REVIEW COMPLETE checks=%d failures=%d won=%s" % [checks,failures.size(),won])
	quit(0 if failures.is_empty() else 1)
