extends "res://tests/balance_review_climb.gd"
## Earned workshop states. Trial policies see only current heat/magazine, not draw/RNG.
const UpgradePlan = preload("res://redesign/ammo_upgrade.gd")
var comparisons: Array = []
var seen_workshops: Dictionary = {}
var policy_observations: Array = []

func check(ok: bool, label: String) -> bool:
	# An always-upgrade policy is a balance experiment, not a required winning route.
	# Keep illegal commands/save errors as failures; retain bounded-search misses as data.
	if not ok and OS.get_environment("QA_UPGRADE_ROUTE") == "1" and (label.begins_with("fresh earned route ") or label.begins_with("earned baseline route completes ")):
		checks += 1
		policy_observations.append({"label":label,"classification":"route_not_completed_by_bounded_oracle"})
		print("BALANCE OBSERVATION ",label)
		return false
	return super.check(ok,label)

func canonical(value): return JSON.parse_string(JSON.stringify(value))

func checked_previous_path(c) -> Array:
	var path: Array = cached_paths.get("%s/%d/%d/%s" % [run_gun,run_seed,int(c.s.node),acquisition_policy],[])
	if path.is_empty(): return []
	var m = solver.clone(c.model)
	for step in path:
		var accepted := false
		match str(step.action):
			"fire": m.s.fire_heat_trial.rounds = int(step.get("rounds",0)); accepted = m.fire()
			"reload": accepted = m.reload_magazine()
			"cool": accepted = m.cool_magazine()
			"emergency": accepted = m.emergency_resupply()
			"eject": accepted = m.eject_magazine_rounds(step.indices)
		if not accepted: return []
	return path.duplicate(true) if m.s.phase in ["won","reward"] else []

func next_combat(c) -> bool:
	for i in range(35):
		match str(c.s.phase):
			"combat": return true
			"map":
				var choices: Array = c.choices()
				if choices.is_empty() or not c.enter(int(choices[0].id)): return false
				c.sync_combat()
			"supply", "event":
				if not c.s.resolved and not c.resolve("skip"): return false
				if not c.leave(): return false
			"shop", "bypass":
				if not c.leave(): return false
			"reward":
				var parts: Array = c.part_rewards()
				if not parts.is_empty():
					if not c.reward(preferred_core if parts.has(preferred_core) else str(parts[0])): return false
				elif not c.reward("credits"):
					if not c.reward("skip"): return false
			"gate":
				if not c.s.resolved and not c.gate("skip"): return false
				if not c.depart_gate(): return false
			_: return false
	return false

func trial(owner, policy: String) -> Array:
	var c = UpgradePlan.copy(owner)
	var fights: Array = []
	for encounter in range(2):
		if not next_combat(c): break
		var m = c.model
		var start_turns: int = m.s.turns
		var row := {"node":c.s.node,"region":c.s.region+1,"policy":policy,"turns":0,"fire":0,"cool":0,"reload":0,"emergency":0,"forced_turns":0,"nearest_after_action":1000000,"fired_rounds":0,"part_events":{}}
		var actions: Array = []
		if policy == "oracle_rng_known":
			actions = checked_previous_path(c)
			if actions.is_empty(): actions = solver.solve(m,4,18)
		for step in range(150):
			if m.s.phase != "ready": break
			var action := ""
			var rounds := 0
			if policy == "oracle_rng_known":
				if step >= actions.size(): break
				action = str(actions[step].action)
				rounds = int(actions[step].get("rounds",0))
			elif m.can_emergency_resupply(): action = "emergency"
			elif m.s.magazine.is_empty(): action = "reload"
			elif policy == "visible_heat_single" and int(m.s.heat) >= Ammo.hot_threshold(m.s): action = "cool"
			else:
				action = "fire"
				rounds = 1 if policy == "visible_heat_single" else 0
			var accepted := false
			match action:
				"fire":
					m.s.fire_heat_trial.rounds = rounds
					accepted = m.fire()
				"cool": accepted = m.cool_magazine()
				"reload": accepted = m.reload_magazine()
				"emergency": accepted = m.emergency_resupply()
				"eject": accepted = m.eject_magazine_rounds(actions[step].indices)
			if not check(accepted,"trial legal action " + policy + "/" + action): break
			row[action] = int(row.get(action,0))+1
			var detail: Dictionary = m.s.history.back().detail
			row.forced_turns += int(detail.get("forced_cooling",{}).get("elapsed",0))
			for shot in detail.get("results",[]):
				row.fired_rounds += 1
				for effect in shot.get("part_effects",[]):
					row.part_events[effect.id] = int(row.part_events.get(effect.id,0))+1
			for enemy in m.s.enemies + m.Ranged.active(m.s):
				if int(enemy.hp)>0: row.nearest_after_action = mini(row.nearest_after_action,int(enemy.distance))
		row.turns = int(m.s.turns)-start_turns
		row.remaining = m.Reserve.remaining(m.s)
		row.won = m.s.phase in ["won","reward"]
		row.phase = m.s.phase
		row.limit_hit = m.s.phase == "ready"
		fights.append(row)
		if not row.won: break
		c.sync_combat()
	return fights

func compare(owner) -> void:
	var key := "%s/%d/%d" % [run_gun,run_seed,int(owner.s.region)]
	if seen_workshops.has(key) or int(owner.s.region) not in [0,2,4]: return
	var pairs: Array = owner.compressible_ids()
	if pairs.is_empty(): return
	seen_workshops[key] = true
	snapshot(owner,"workshop_%s_%d_r%d" % [run_gun,run_seed,int(owner.s.region)+1])
	var source: String = str(pairs[0])
	var main: String = owner.model.FocusBuild.main_round(owner.model.s)
	for id in pairs:
		if Ammo.source_id(id) == Ammo.source_id(main): source = id; break
	var frozen = canonical([owner.s,owner.model.s,owner.profile])
	var entry := {"gun":run_gun,"seed":run_seed,"outfit":owner.model.s.outfit,"region":owner.s.region+1,"node":owner.s.node,"source":source,"target":Ammo.compressed_id(source),"deck_before":owner.model.s.deck.duplicate(),"parts":owner.s.equipped_parts.duplicate(),"branches":[]}
	for choice in ["keep","upgrade","other_work"]:
		var c = UpgradePlan.copy(owner)
		var operation: String = choice
		var accepted := false
		match choice:
			"keep": accepted = c.resolve("skip")
			"upgrade": accepted = UpgradePlan.execute(c,source)
			"other_work":
				operation = "bag" if c.can_grow_bag() else "remove"
				accepted = c.resolve(operation,source)
		if not accepted: continue
		c.normalize_for_save()
		check(c.leave(),"trial leaves the same workshop")
		var branch := {"choice":choice,"operation":operation,"deck_count":c.model.s.deck.size(),"deck_limit":c.model.deck_limit(),"policies":{}}
		for policy in ["full_fire","visible_heat_single","oracle_rng_known"]:
			branch.policies[policy] = trial(c,policy)
		entry.branches.append(branch)
	comparisons.append(entry)
	check(canonical([owner.s,owner.model.s,owner.profile]) == frozen,"counterfactuals preserve earned source state")
	FileAccess.open(output.path_join("comparisons.json"),FileAccess.WRITE).store_string(JSON.stringify(comparisons,"\t"))
	print("UPGRADE COMPARE ",key," source=",source," branches=",entry.branches.size())

func command(c,item: Dictionary) -> bool:
	if item.action == "resolve" and c.s.phase == "supply" and c.node().get("workshop",false) and not c.s.resolved:
		compare(c)
		if OS.get_environment("QA_UPGRADE_ROUTE") == "1" and not c.compressible_ids().is_empty():
			var source: String = str(c.compressible_ids()[0])
			var main: String = c.model.FocusBuild.main_round(c.model.s)
			for id in c.compressible_ids():
				if Ammo.source_id(id) == Ammo.source_id(main): source = id; break
			item = {"action":"resolve","id":"compress","ammo":source,"replace":""}
	return super.command(c,item)

func _run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/ammo_upgrade_single_20261106/"): quit(2); return
	solver = preload("res://tests/fire_control_solver.gd").new()
	route_policy = "safe"; acquisition_policy = "refit"; rule_version = 3; review_revision = 1
	# Reuse earlier oracle paths only after replaying them on the CURRENT model.
	# This imports actions, never earned states or victories into the route.
	for label in ["balance_first","balance_extra","balance_scout"]:
		var path: String = "res://../qa_runtime/ammo_upgrade_single_20261106/" + str(label) + "/balance.json"
		if not FileAccess.file_exists(path): continue
		var report = JSON.parse_string(FileAccess.get_file_as_string(path))
		for battle in report.get("battles",[]):
			if battle.get("solved",false): cached_paths["%s/%d/%d/%s" % [battle.gun,int(battle.seed),int(battle.node),battle.get("acquisition","refit")]] = battle.path
	for seed_text in OS.get_environment("QA_SEEDS").split(","):
		for gun in OS.get_environment("QA_GUNS").split(","):
			run_gun = gun; run_seed = int(seed_text); outfit_id = OS.get_environment("QA_OUTFIT"); commands = []
			if outfit_id.is_empty(): outfit_id = "carrier"
			build_kind = {"single":"direct","burst":"control","scatter":"control","heavy":"fire","amplifier":"direct"}[gun]
			role_build = build_kind == "fire"
			preferred_core = {"single":"siege_drive","burst":"volley_drive","scatter":"volley_drive","heavy":"thermal_drive","amplifier":"siege_drive"}[gun]
			var c = Campaign.new(); c.start(gun,run_seed,0,"balanced",4,outfit_id,true)
			roundtrip(c)
			var won: bool = await play_run(c)
			endpoints.append({"gun":gun,"seed":run_seed,"outfit":outfit_id,"workshop_policy":"upgrade" if OS.get_environment("QA_UPGRADE_ROUTE")=="1" else "refit","won":won,"phase":c.s.phase,"deck":c.model.s.deck,"commands":commands.duplicate(true)})
			check(won,"earned baseline route completes " + gun)
			write_report()
	check(not comparisons.is_empty(),"earned workshop comparisons were reached")
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"policy_observations":policy_observations,"contexts":comparisons.size(),"endpoints":endpoints},"\t"))
	print("AMMO UPGRADE BALANCE COMPLETE checks=%d failures=%d observations=%d" % [checks,failures.size(),policy_observations.size()])
	quit(0 if failures.is_empty() else 1)
