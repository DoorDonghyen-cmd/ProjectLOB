extends "res://tests/build_roles_climb.gd"
var outfit_id:="carrier"
var economy_version:=1
var ledger: Array=[]
var copy_policy:=false
func command(c,item: Dictionary)->bool:
	if item.action=="gate_depart" and c.can_buy_gate_bag() and c.model.s.deck.size()>=c.model.deck_limit()-2:
		if not command(c,{"action":"gate_bag"}):return false
	if item.action=="gate_depart" and copy_policy:
		var main: String=c.model.FocusBuild.main_round(c.model.s)
		if c.can_buy_gate_copy(main):
			if not command(c,{"action":"gate_copy","id":main}):return false
	var before: Dictionary={"node":c.s.node,"phase":c.s.phase,"action":item.action,"credits":c.s.credits,"deck":c.model.s.deck.size(),"limit":c.model.deck_limit()}
	var accepted: bool
	if item.action in ["gate_bag","gate_copy"]:
		accepted=check(c.buy_gate_bag() if item.action=="gate_bag" else c.buy_gate_copy(str(item.id)),"legal paid gate expansion") and roundtrip(c)
		if accepted:commands.append(item.duplicate(true))
	else:accepted=super.command(c,item)
	if accepted and item.action in ["enter","reward","buy","gate","gate_bag","gate_copy","resolve","leave","gate_depart"]:
		before.merge({"after_credits":c.s.credits,"after_deck":c.model.s.deck.size(),"after_limit":c.model.deck_limit(),"id":item.get("id","")})
		ledger.append(before)
	return accepted
func write_report()->void:
	super.write_report()
	# The inherited raw remaining metric omits emergency rounds; use actual reserves.
	for battle in battles:
		if not battle.has("raw_remaining"):battle.raw_remaining=battle.remaining
		battle.remaining=int(battle.metrics.get("remaining",battle.remaining))
	super.write_report()
	FileAccess.open(output.path_join("economy.json"),FileAccess.WRITE).store_string(JSON.stringify({"outfit":outfit_id,"economy_version":economy_version,"ledger":ledger},"  "))
func _run()->void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/economy_roles_20261103/"):quit(2);return
	solver=preload("res://tests/fire_control_solver.gd").new();route_policy="safe";acquisition_policy="refit";rule_version=3
	run_gun=OS.get_environment("QA_GUN");run_seed=int(OS.get_environment("QA_SEED"));outfit_id=OS.get_environment("QA_OUTFIT")
	if run_gun.is_empty():run_gun="heavy"
	if outfit_id.is_empty():outfit_id="carrier"
	if run_seed==0:run_seed=17
	copy_policy=OS.get_environment("QA_COPY")=="1"
	economy_version=0 if OS.get_environment("QA_ECONOMY")=="0" else 1
	build_kind={"heavy":"fire","burst":"control","single":"direct"}[run_gun];role_build=build_kind=="fire"
	preferred_core={"single":"siege_drive","burst":"volley_drive","heavy":"thermal_drive"}[run_gun]
	var c=Campaign.new();c.start(run_gun,run_seed,0,"balanced",4,outfit_id,true)
	if economy_version==0:
		for key in ["economy_version","intro_part_bought","gate_bag_used","gate_ammo_used"]:c.s.erase(key)
	roundtrip(c)
	var won: bool=await play_run(c)
	endpoints.append({"gun":run_gun,"seed":run_seed,"outfit":outfit_id,"economy_version":economy_version,"copy_policy":copy_policy,"role_version":3,"build":build_kind,"won":won,"region":int(c.s.region)+1,"phase":c.s.phase,"deck":c.model.s.deck,"parts":c.s.equipped_parts,"gate_mods":c.model.s.gate_mods,"credits":c.s.credits,"bag_upgrades":c.s.bag_upgrades,"commands":commands.duplicate(true)})
	check(won,"earned economy climb "+run_gun+"/"+outfit_id+"/"+str(run_seed));write_report()
	print("ECONOMY ROLES COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
