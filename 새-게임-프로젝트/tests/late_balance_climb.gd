extends "res://tests/playtest_rework_climb.gd"
var rule_version:=1
var metrics: Dictionary={}
func command(c,item: Dictionary)->bool:
	var combat: bool=c.s.phase=="combat"
	var prior_turns: int=c.model.s.turns
	var node: String=str(c.s.node)
	var key: String="%s/%d/%s"%[run_gun,run_seed,node]
	var accepted: bool=super.command(c,item)
	if accepted and combat and item.action in ["fire","cool","reload","emergency","eject"]:
		if not metrics.has(key):metrics[key]={"turns":0,"forced_turns":0,"fire":0,"reload":0,"cool":0,"emergency":0,"eject":0,"burn_damage":0,"remaining":0}
		var row: Dictionary=metrics[key]
		row[item.action]+=1;row.turns+=int(before_save.turns)-prior_turns
		row.remaining=c.model.Reserve.remaining(before_save)
		var detail: Dictionary=before_save.history.back().detail
		row.forced_turns+=int(detail.get("forced_cooling",{}).get("elapsed",0))
		for event in detail.get("advance_events",[])+detail.get("forced_cooling",{}).get("advance_events",[]):
			if event.kind=="burn":row.burn_damage+=int(event.damage)
	return accepted
func write_report()->void:
	for battle in battles:
		var key: String="%s/%d/%d"%[battle.gun,int(battle.seed),int(battle.node)]
		battle.metrics=metrics.get(key,{})
	super.write_report()
func _run()->void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/late_balance_20261103/"):quit(2);return
	solver=preload("res://tests/fire_control_solver.gd").new()
	route_policy="safe";acquisition_policy="refit"
	rule_version=int(OS.get_environment("QA_ROLE_VERSION"))
	if rule_version not in [1,2]:quit(2);return
	role_build=OS.get_environment("QA_ROLE_BUILD")=="fire"
	var selected:=OS.get_environment("QA_GUNS")
	if selected.is_empty():selected="heavy"
	for seed_text in OS.get_environment("QA_SEEDS").split(","):
		for gun in selected.split(","):
			run_gun=gun;run_seed=int(seed_text);commands=[]
			preferred_core={"single":"siege_drive","burst":"volley_drive","scatter":"volley_drive","heavy":"thermal_drive","amplifier":"siege_drive"}[gun]
			var c=Campaign.new();c.start(gun,run_seed,0,"balanced",4,"carrier",true)
			c.s.combat_roles_version=rule_version;c.model.s.combat_roles_version=rule_version
			roundtrip(c)
			var won: bool=await play_run(c)
			endpoints.append({"gun":gun,"seed":run_seed,"role_version":rule_version,"role_build":role_build,"won":won,"region":int(c.s.region)+1,"phase":c.s.phase,"deck":c.model.s.deck,"parts":c.s.equipped_parts,"gate_mods":c.model.s.gate_mods,"commands":commands.duplicate(true)})
			check(won,"earned late-balance climb "+gun+"/"+seed_text);write_report()
	print("LATE BALANCE COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
