extends "res://tests/combat_approach_probe.gd"
const Approach = preload("res://redesign/combat_approach_trial.gd")
const GUNS := ["single", "burst", "scatter", "heavy", "amplifier"]
const ROLES := ["breach", "boss", "sweep", "payoff"]

func weapon(gun: String, role: String, seed_value: int = 0, scale_value: float = -1.0):
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://redesign/samples/combat_weapon_%s_%s.json" % [gun,role]))
	var m = Model.new()
	if not m.restore_state(data.state): push_error("Invalid earned source"); return m
	m.s.magazine_trial_version = 1; m.s.weapon_magazine_version = 1
	Approach.apply_opening(m.s, role)
	if scale_value > 0 and role in ["breach", "boss"]:
		for zone in ["enemies", "reinforcements"]:
			for i in range(m.s[zone].size()):
				if int(m.s[zone][i].speed) > 0: m.s[zone][i].distance = maxi(4, ceili(float(data.state[zone][i].distance)*scale_value))
	if seed_value > 0:
		var rng := RandomNumberGenerator.new(); rng.seed = seed_value
		m.s.rng_state = str(rng.state); m.s.target_rng_state = str(rng.state)
		m.s.draw = m.s.hand + m.s.draw; m.s.hand = []; m._shuffle(m.s.draw)
	m.trial_load_magazine()
	return m

func run() -> void:
	var out := OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/weapon_magazine_20261031/"): quit(2); return
	for scale_value in [0.5, 0.65, 0.8]:
		for gun in GUNS:
			for role in ROLES:
				for seed_value in [0,17,1042,731042,900001,1200411]:
					var m = weapon(gun, role, seed_value, scale_value)
					var capacity: int = m.capacity()
					var result := simulate(m, true)
					result.merge({"gun":gun, "role":role, "seed":seed_value,"capacity":capacity,"distance_scale":scale_value})
					rows.append(result)
	var audit: Array = []
	for row in rows:
		if row.seed != 0 or row.phase in ["won", "reward"]: continue
		var m = weapon(row.gun,row.role,0,row.distance_scale)
		var path: Array = preload("res://tests/weapon_magazine_solver.gd").solve(m.s)
		for action in path: command(m,action)
		audit.append({"gun":row.gun,"role":row.role,"scale":row.distance_scale,"path":path,"phase":m.s.phase})
	FileAccess.open(out.path_join("audit.json"),FileAccess.WRITE).store_string(JSON.stringify(audit,"  "))
	FileAccess.open(out.path_join("probe.json"), FileAccess.WRITE).store_string(JSON.stringify({"rows":rows}, "  "))
	print("WEAPON PROBE COMPLETE rows=%d" % rows.size()); quit()
