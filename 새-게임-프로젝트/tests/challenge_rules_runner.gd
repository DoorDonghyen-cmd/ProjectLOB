extends "res://tests/heat_rules_runner.gd"
const Challenges = preload("res://redesign/residential_challenges.gd")

func challenge_model(kind: String, ids: Array = ["basic"], gun: String = "single") -> RefCounted:
	var rows := Challenges.rows({"region":0,"kind":"boss" if kind == "boss" else "combat","elite":kind == "elite"},[])
	return fixture(ids,rows.slice(0,1),gun)

func reload_exact(model: RefCounted) -> void:
	var snapshot := JSON.stringify(model.s)
	var expected := Forecast.reload_now(model.s,true)
	check(JSON.stringify(model.s) == snapshot,"reload forecast pure")
	check(model.reload_magazine(),"legal reload")
	check(expected.enemies == model.s.enemies and expected.projectiles == model.s.projectiles and expected.phase == model.s.phase,"exact reload including gate cycle")
	check(Model.new().restore_state(JSON.parse_string(JSON.stringify(model.s))),"cycle state round trips")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/elite_boss/"): quit(1);return
	var run = Campaign.new()
	run.start("single",731042)
	check(run.s.roster_version == 5,"new runs use challenge roster")
	for kind in ["elite","boss"]:
		var node := {"region":0,"kind":"boss" if kind == "boss" else "combat","elite":kind == "elite","floor":8,"id":801,"name":"test"}
		var legacy := Data.encounter_pack(node,731042,"single",0,0,4)
		var modern := Data.encounter_pack(node,731042,"single",0,0,5)
		check(not Challenges.named(legacy.active[0]),"older roster unchanged " + kind)
		check(Challenges.named(modern.active[0]) and modern.active[0].rank == kind,"new authored threat " + kind)
		check(modern.total == (6 if kind == "boss" else 5) and modern.active.size() == 4,"finite escort formation " + kind)
		check(modern.active[0].max_hp == (44 if kind == "boss" else 16),"no duplicate legacy elite HP scaling")
		for region in range(1,5):
			node.region = region
			check(Data.encounter_pack(node,731042,"single",0,0,4) == Data.encounter_pack(node,731042,"single",0,0,5),"later region unchanged")
	var m = challenge_model("boss")
	for phase in ["guard","prepare","prepare","waiting"]:
		reload_exact(m)
		check(m.s.enemies[0].ranged_phase == phase,"guard/open/launch tick " + phase)
		check(m.s.enemies[0].def == (2 if phase == "guard" else 0),"armor matches body state")
	check(m.s.projectiles[0].distance == 32,"projectile does not move on birth turn")
	# Kill by burn after launch: the independent projectile still prevents victory.
	m.s.enemies[0].hp = 1;m.s.enemies[0].burn = 1
	reload_exact(m)
	check(m.s.enemies[0].hp == 0 and m.s.phase == "plan" and not Ranged.active(m.s).is_empty(),"boss death leaves projectile active")
	# A real ordinary attack intercepts. Hand conservation is kept by a fresh fixture.
	m = challenge_model("boss",["basic","basic","basic","basic"])
	for tick in range(4): reload_exact(m)
	var card: String = m.s.hand[0]
	var shots := fire(m,[card])
	check(shots[0].target >= Ranged.TARGET_BASE and Ranged.active(m.s).is_empty(),"any direct hit intercepts boss shot")
	check(m.s.enemies[0].ranged_phase == "recover" and m.s.enemies[0].ranged_left == 2,"interception starts two-turn open recovery")
	reload_exact(m);check(m.s.enemies[0].ranged_phase == "recover","first recovery tick open")
	reload_exact(m);check(m.s.enemies[0].ranged_phase == "guard" and m.s.enemies[0].def == 2,"second recovery tick closes")
	# Two-turn reload cannot skip state transitions or invalidate armor damage.
	m = challenge_model("boss",["shatter"],"burst")
	reload_exact(m)
	check(m.s.enemies[0].ranged_phase == "prepare" and m.s.enemies[0].ranged_left == 2,"burst two-turn reload opens gate")
	m = challenge_model("boss",["shatter"])
	shots = fire(m,["shatter"])
	check(m.s.enemies[0].guard_armor == 0,"shatter permanently reduces door armor")
	for tick in range(3): reload_exact(m)
	var invalid: Dictionary = m.s.duplicate(true)
	invalid.enemies[0].guard_armor = -1
	check(not Model.new().restore_state(invalid),"invalid guard armor rejected")
	invalid = m.s.duplicate(true);invalid.enemies[0].ranged_left = 3
	check(not Model.new().restore_state(invalid),"invalid gate clock rejected")
	invalid = m.s.duplicate(true);invalid.enemies[0].def = 2
	check(not Model.new().restore_state(invalid),"closed armor cannot exist in open state")
	m = challenge_model("boss",["disrupt"])
	m.s.enemies[0].ranged_phase = "prepare";m.s.enemies[0].ranged_left = 2;m.s.enemies[0].def = 0
	fire(m,["disrupt"])
	check(m.s.enemies[0].ranged_left == 2 and m.s.enemies[0].disrupted,"interruption freezes open preparation on the actual turn")
	# A developed single-hit build can kill through the closed doors. No HP gate.
	m = challenge_model("boss",["charge","basic_p5"],"amplifier")
	m.s.equipped_parts = ["siege_drive"];m.s.engine.levels.siege_drive = 8
	fire(m,["charge","basic_p5"])
	check(m.fire(),"single-shot gun fires next round")
	check(m.s.phase in ["reward","won"] and m.s.enemies[0].hp == 0 and m.s.projectile_serial == 0,"strong build bypasses whole boss cycle by lethal damage")
	# Elite affects living allies, not itself, reserves or dead units.
	m = challenge_model("elite")
	m.s.enemies.append(Data._enemy(["runner",4,0,2,30]))
	m.s.enemies.append(Data._enemy(["runner",0,0,2,30]))
	m.s.encounter_total = 3;m.s.deployed = 3;m.assign_opening_lanes()
	for tick in range(3): reload_exact(m)
	check(m.s.enemies[0].distance == 22 and m.s.enemies[1].distance == 22,"resonance adds two meters only to live escort")
	check(m.s.enemies[2].distance == 30,"dead escort never moves")
	check(m.s.enemies[0].charge == 0,"resonance resets public clock")
	for gun in Ammo.GUNS:
		for kind in ["elite","boss"]:
			m = challenge_model(kind,["basic_p3","precise_p3","charge","cool"],gun)
			fire(m,["charge","precise_p3","cool","basic_p3"].slice(0,m.capacity()))
			if m.s.phase not in ["reward","won","lost"]: reload_exact(m)
	# Saved roster4 must not silently migrate to new threats.
	run.s.roster_version = 4
	var old_state := {"campaign":run.s.duplicate(true),"combat":run.model.s.duplicate(true),"profile":run.profile.duplicate(true)}
	var restored = Campaign.new()
	check(restored.restore_state(JSON.parse_string(JSON.stringify(old_state))) and restored.s.roster_version == 4,"existing campaign keeps roster4")
	print("CHALLENGE RULES COMPLETE checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
