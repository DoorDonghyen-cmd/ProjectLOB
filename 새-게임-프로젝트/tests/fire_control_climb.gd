extends "res://tests/campaign_magazine_rules.gd"
func choose_ammo(c,options: Array)->String:
	if OS.get_environment("QA_BUILD")!="focus":return super.choose_ammo(c,options)
	var priorities: Array={"volley_drive":["precise","charge","shatter","chase","pierce","arc","cool"],"thermal_drive":["bore","charge_heat","vent","detonate","push","cool"],"siege_drive":["pierce","charge","charge_hot","bypass","cool"]}.get(preferred_core,[])
	for family in priorities:
		var limit:=4 if family in ["precise","bore","pierce"] else 2 if family=="charge" else 1
		if c.model.s.deck.filter(func(id):return Ammo.source_id(str(id))==family).size()>=limit:continue
		for id in options:
			if Ammo.source_id(str(id))==family:return str(id)
	return super.choose_ammo(c,options)
func command(c,item: Dictionary)->bool:
	if item.action=="enter" and OS.get_environment("QA_ROUTE")=="avoid_elite":
		var choices: Array=c.choices()
		var requested: Array=choices.filter(func(n):return int(n.id)==int(item.id))
		if not requested.is_empty() and requested[0].get("elite",false):
			for option in choices:
				if not option.get("elite",false):item=item.duplicate(true);item.id=option.id;break
	if item.action=="fire":c.model.s.fire_heat_trial.rounds=int(item.get("rounds",0))
	return super.command(c,item)
func _run()->void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/fire_control_20261102/"):quit(2);return
	output=OS.get_environment("QA_OUTPUT_DIR")
	solver=preload("res://tests/fire_control_solver.gd").new()
	route_policy="safe";acquisition_policy="refit"
	if OS.get_environment("QA_ROUTE")=="elite":route_policy="elite"
	for gun in OS.get_environment("QA_GUNS").split(","):
		run_gun=gun;run_seed=int(OS.get_environment("QA_SEED"));commands=[]
		preferred_core={"single":"siege_drive","burst":"volley_drive","scatter":"volley_drive","heavy":"thermal_drive","amplifier":"siege_drive"}[gun]
		var c=Campaign.new();c.start(gun,run_seed,0,"balanced",3,"carrier",true)
		check(c.s.fire_control_version==1 and c.model.FireHeatTrial.range_enabled(c.model.s),"new campaign enables selected production rules")
		roundtrip(c)
		var won: bool=await play_run(c)
		endpoints.append({"gun":gun,"seed":run_seed,"won":won,"region":int(c.s.region)+1,"phase":c.s.phase,"deck":c.model.s.deck,"parts":c.s.equipped_parts,"commands":commands.duplicate(true)})
		check(won,"new fire-control full climb "+gun);write_report()
	print("FIRE CONTROL COMPLETE checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
