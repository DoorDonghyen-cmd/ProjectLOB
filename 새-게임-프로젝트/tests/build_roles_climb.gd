extends "res://tests/late_balance_climb.gd"
var build_kind:="fire"
func choose_ammo(c,options: Array)->String:
	if c.first_ammo_reward():
		var main: String={"fire":"bore","control":"precise_p2","direct":"pierce_p2"}[build_kind]
		if options.has(main):return main
	if not c.first_ammo_reward():
		for id in (["disrupt","detonate"] if build_kind=="fire" else ["disrupt"]):
			if options.has(id) and not c.model.s.deck.any(func(held):return Ammo.source_id(held)==id):return id
	return super.choose_ammo(c,options)
func choose_parts(c)->bool:
	var preferred: Array={
		"fire":[preferred_core,"coil","igniter","rammer","compression_sink","chain_sink","radiator"],
		"control":[preferred_core,"rammer","third_striker","duplex","capacitor","sequencer","chain_sink"],
		"direct":[preferred_core,"third_striker","opening","capacitor","afterburner","lens","sequencer"]}[build_kind]
	var chosen: Array=[]
	for id in preferred+c.s.parts:
		if not chosen.has(id) and c.s.parts.has(id) and Ammo.valid_part_set(run_gun,chosen+[id]):chosen.append(id)
		if chosen.size()==5:break
	if chosen==c.s.equipped_parts:return true
	if not c.s.equipped_parts.is_empty() and not command(c,{"action":"equip","id":"none"}):return false
	for id in chosen:
		if not command(c,{"action":"equip","id":id}):return false
	return true
func command(c,item: Dictionary)->bool:
	if c.s.phase=="shop" and item.action=="buy":snapshot(c,"shop_%s_%d_r%d_n%d"%[run_gun,run_seed,int(c.s.region)+1,c.s.node])
	return super.command(c,item)
func _run()->void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/build_roles_20261103/"):quit(2);return
	solver=preload("res://tests/fire_control_solver.gd").new()
	route_policy="safe";acquisition_policy="refit";rule_version=3
	var selected:=OS.get_environment("QA_GUNS")
	if selected.is_empty():selected="heavy,burst,single"
	var seeds:=OS.get_environment("QA_SEEDS")
	if seeds.is_empty():seeds="17"
	for seed_text in seeds.split(","):
		for gun in selected.split(","):
			run_gun=gun;run_seed=int(seed_text);commands=[]
			build_kind={"heavy":"fire","burst":"control","single":"direct"}[gun];role_build=build_kind=="fire"
			preferred_core={"single":"siege_drive","burst":"volley_drive","heavy":"thermal_drive"}[gun]
			var c=Campaign.new();c.start(gun,run_seed,0,"balanced",4,"carrier",true)
			check(c.s.combat_roles_version==3 and c.model.s.combat_roles_version==3,"new full climb uses build choices")
			roundtrip(c)
			var won: bool=await play_run(c)
			endpoints.append({"gun":gun,"seed":run_seed,"role_version":3,"build":build_kind,"won":won,"region":int(c.s.region)+1,"phase":c.s.phase,"deck":c.model.s.deck,"parts":c.s.equipped_parts,"gate_mods":c.model.s.gate_mods,"commands":commands.duplicate(true)})
			check(won,"earned build climb "+gun+"/"+seed_text);write_report()
	print("BUILD ROLES COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
