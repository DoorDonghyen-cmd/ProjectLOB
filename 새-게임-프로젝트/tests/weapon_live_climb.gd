extends "res://tests/playtest_rework_climb.gd"
func _run() -> void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").ends_with("/qa_runtime/weapon_live_20261106/climb"):quit(2);return
	solver=preload("res://tests/fire_control_solver.gd").new()
	route_policy="safe";acquisition_policy="refit"
	for gun in ["deadbolt","rewinder"]:
		run_gun=gun;run_seed=731042;commands=[]
		preferred_core="siege_drive" if gun=="deadbolt" else "volley_drive"
		var c=Campaign.new();c.start(gun,run_seed,0,"balanced",4,"carrier",true)
		roundtrip(c)
		var won: bool=await play_run(c)
		endpoints.append({"gun":gun,"seed":run_seed,"won":won,"region":int(c.s.region)+1,"phase":c.s.phase,"deck":c.model.s.deck,"parts":c.s.equipped_parts,"gate_mods":c.model.s.gate_mods,"commands":commands.duplicate(true),"scope":"deterministic path search with private state, functional reachability; not player success or final balance"})
		check(won,"native new-gun full run "+gun);write_report()
	print("WEAPON LIVE CLIMB COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
