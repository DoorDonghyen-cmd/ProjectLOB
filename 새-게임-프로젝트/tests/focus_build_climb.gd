extends "res://tests/fire_control_climb.gd"
func replacement(c, id: String) -> String:
	if c.first_ammo_reward() and c.model.FocusBuild.enabled(c.s): return ""
	return super.replacement(c,id)
func choose_ammo(c, options: Array) -> String:
	if options.is_empty(): return ""
	if c.first_ammo_reward(): return str(options[0])
	var main: String = c.model.FocusBuild.main_round(c.model.s)
	if not main.is_empty():
		var improved: String = c.model.FocusBuild.upgrade(main)
		if options.has(improved): return improved
	if not main.is_empty() and options.has(main):
		var count: int = c.model.s.deck.filter(func(id):return Ammo.source_id(str(id)) == Ammo.source_id(main)).size()
		if count < 7: return main
	for id in options:
		var source := Ammo.source_id(str(id))
		var count: int = c.model.s.deck.filter(func(held):return Ammo.source_id(str(held)) == source).size()
		if source in ["charge","charge_hot","charge_heat"] and count < 2: return str(id)
		if source in ["cool","shatter","chase"] and count < 1: return str(id)
	return ""
func choose_parts(c) -> bool:
	var chosen: Array = []
	var support: Array = ["duplex","sequencer","reclaimer","chain_sink","radiator"] if preferred_core == "volley_drive" else ["afterburner","sequencer","lens","chain_sink","radiator","reclaimer"]
	for id in [preferred_core,"third_striker"] + support + ["opening","compression_sink","lens","supply","breaker","ember_core","coil"]:
		if c.s.parts.has(id) and Ammo.valid_part_set(run_gun,chosen+[id]): chosen.append(id)
		if chosen.size() == 5: break
	if chosen == c.s.equipped_parts: return true
	if not c.s.equipped_parts.is_empty() and not command(c,{"action":"equip","id":"none"}): return false
	for id in chosen:
		if not command(c,{"action":"equip","id":id}): return false
	return true
func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/focus_build_20261103/"): quit(2); return
	output = OS.get_environment("QA_OUTPUT_DIR")
	solver = preload("res://tests/fire_control_solver.gd").new()
	route_policy = "safe"; acquisition_policy = "refit"
	for gun in OS.get_environment("QA_GUNS").split(","):
		run_gun = gun; run_seed = int(OS.get_environment("QA_SEED")); commands = []
		preferred_core = {"single":"siege_drive","burst":"volley_drive","scatter":"volley_drive","heavy":"thermal_drive","amplifier":"siege_drive"}[gun]
		var c = Campaign.new(); c.start(gun,run_seed,0,"balanced",3,"carrier",true)
		check(c.model.FocusBuild.enabled(c.s),"new campaign enables focus acquisition and parts")
		roundtrip(c)
		var won: bool = await play_run(c)
		endpoints.append({"gun":gun,"seed":run_seed,"won":won,"region":int(c.s.region)+1,"phase":c.s.phase,"deck":c.model.s.deck,"parts":c.s.equipped_parts,"commands":commands.duplicate(true)})
		check(won,"focus full climb "+gun); write_report()
	print("FOCUS BUILD COMPLETE checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
