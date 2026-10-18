extends "res://tests/heat_rules_runner.gd"
const Engines = preload("res://redesign/damage_engines.gd")
const Affinity = preload("res://redesign/build_affinity.gd")
const Payoff = preload("res://redesign/combat_payoff.gd")
var comparisons: Array = []

func setup_core(m, core: String, level: int = 2, modules: Array = []) -> void:
	m.s.equipped_parts = [core]+modules
	m.s.engine.levels[core] = level

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/build_payoff/"): quit(1); return
	var rows: Array = [["runner",6,0,1,24],["runner",6,0,1,27],["runner",6,0,1,30],["wall",30,3,1,33]]
	var m = fixture(["charge","precise"],rows)
	setup_core(m,"thermal_drive")
	m.s.heat=5
	var shots := fire(m,["charge","precise"])
	check(shots[1].shock_damage==15 and shots[1].secondary.size()==3,"hot limit impact hits other three targets once")
	check(shots[1].secondary[0].damage==6 and shots[1].secondary[2].damage==3,"half raw wave respects each armor")
	check(m.s.reloads==1 and m.s.turns==3 and m.s.heat==0,"surviving anchor preserves mandatory overheat cost")
	var cue := Payoff.describe(shots[1])
	check(cue.damage==21 and cue.kills==3 and cue.tier==2,"resolved sweep summary includes all actual targets")
	for condition in ["cold","blocked","support","under_limit"]:
		m=fixture(["basic" if condition!="support" else "shatter"],rows)
		setup_core(m,"thermal_drive")
		m.s.heat=9 if condition in ["blocked","support"] else 4 if condition=="cold" else 5
		if condition=="blocked": m.s.enemies[0].barrier=1
		shots=fire(m,["basic" if condition!="support" else "shatter"])
		check(shots[0].shock_damage==0 and shots[0].secondary.is_empty(),"no false pressure wave "+condition)
	m=fixture(["basic"],rows); setup_core(m,"thermal_drive",2);m.s.heat=9;m.s.enemies[1].barrier=1
	shots=fire(m,["basic"])
	check(shots[0].secondary[0].damage==0 and shots[0].secondary[0].barrier==0,"wave barrier absorbs one hit")
	check(shots[0].secondary[2].damage==0,"wave has no minimum damage through armor")
	# Kill cooling is earned after the pressure threshold, not a second activation.
	m=fixture(["basic"],[["runner",1,0,1,24],["runner",30,0,1,28]])
	setup_core(m,"thermal_drive",2,["reclaimer"]);m.s.heat=9
	shots=fire(m,["basic"])
	check(shots[0].shock_damage==3 and m.s.heat==8 and m.s.reloads==0,"kill cooling can avoid forced reload after earned wave")
	# Pressure is a real secondary target, but intercepting it is not an enemy kill.
	m=fixture(["basic"],[["runner",1,0,1,24],["spitter",100,0,0,30]])
	setup_core(m,"thermal_drive",2);m.s.heat=9
	m.s.enemies[1].ranged_phase="waiting";m.s.enemies[1].ranged_left=0
	m.s.projectiles=[{"uid":1,"source":1,"kind":"pressure","name":"압력탄","hp":1,"max_hp":1,"def":0,"speed":6,"distance":26,"burn":0,"barrier":0,"focus_hits":0,"lane":0}]
	m.s.projectile_serial=1
	shots=fire(m,["basic"])
	check(shots[0].secondary.any(func(e):return e.target==10001 and e.intercept),"heat wave intercepts actual pressure projectile")
	check(Payoff.describe(shots[0]).kills==1,"pressure intercept does not inflate crowd kill summary")
	# Preferences differ using the real model, without named-pair bonuses.
	for core in Engines.IDS:
		var record := {"core":core,"shots":{}}
		for ammo in ["precise","pierce","thermal"]:
			m=fixture([ammo],[["wall",500,0,1,30]])
			setup_core(m,core,4,["duplex"] if core=="volley_drive" else [])
			if core=="thermal_drive": m.s.heat=6
			shots=fire(m,[ammo])
			record.shots[ammo]={"damage":shots[0].damage,"heat":shots[0].heat_added}
		comparisons.append(record)
	check(comparisons[0].shots.precise.damage>comparisons[0].shots.pierce.damage*2,"volley values added hit count")
	check(comparisons[1].shots.thermal.damage>comparisons[1].shots.pierce.damage,"thermal values high heat attack")
	check(comparisons[2].shots.pierce.damage>comparisons[2].shots.precise.damage,"siege values single hit over multihit")
	# Core bias leaves discovery, stage gating, ownership and unseen variety intact.
	for seed_value in range(20):
		var node := {"id":5,"region":0,"floor":5,"kind":"shop","elite":false}
		for core in Engines.IDS:
			var choices := Data.rewards(node,seed_value,["basic","precise"],[core])
			check(choices.size()==2 and choices[0]!=choices[1] and Affinity.AMMO[core].has(choices[0]),"one aligned ammo option, two distinct choices")
			var stock := Data.offers(node,seed_value,0,"single",[core],[],[],[core])
			check(stock.size()==3 and Affinity.PARTS[core].has(stock[1].id),"aligned module in first stock")
			check(stock[1].id!=stock[2].id and not Ammo.is_core_part(stock[1].id),"different module candidates")
			var seen: Array = Affinity.PARTS[core].duplicate()
			stock=Data.offers(node,seed_value,0,"single",[core],seen,[],[core])
			check(not seen.has(stock[1].id) and not seen.has(stock[2].id),"unseen variety outranks forcing core recommendation")
	# Roster v2 keeps its two-enemy opening follow-up; v3 expands without HP inflation.
	for depth in range(1,9):
		var node := {"id":depth,"region":0,"floor":depth,"kind":"boss" if depth==8 else "combat","name":"QA","elite":false}
		var old := Data.encounter_pack(node,731042,"single",0,0,2)
		var fresh := Data.encounter_pack(node,731042,"single",0,0,3)
		check(fresh.active.size()<=4 and fresh.total<=8,"four visible lanes and bounded reserve")
		check(fresh.active.all(func(e):return e.has("species")),"residential species preserved")
		if depth==1: check(old==fresh,"first battle unchanged")
		else: check(fresh.total>=old.total and fresh.total>=4,"larger authored population")
		if depth==2: check(old.total==2 and fresh.total==4,"legacy v2 preserved")
	# Upper-region changes keep the original anchor and special roles; only escorts expand.
	for region in range(1,5):
		for seed_value in [17,731042]:
			for boss in [false,true]:
				for pressure in [0,2]:
					var node := {"id":region*1000+401,"region":region,"floor":8 if boss else 4,"kind":"boss" if boss else "combat","name":"QA","elite":false}
					var old := Data.encounter_pack(node,seed_value,"single",0,pressure,2)
					var fresh := Data.encounter_pack(node,seed_value,"single",0,pressure,3)
					check(fresh==Data.encounter_pack(node,seed_value,"single",0,pressure,3),"upper population is deterministic")
					check(fresh.total==8 and fresh.active.size()==4 and fresh.reserve.size()==4,"upper population bounded to four plus four")
					check(fresh.active[0]==old.active[0],"upper anchor keeps its original mechanics and hp")
					var prior: Array=old.active+old.reserve
					var expanded: Array=fresh.active+fresh.reserve
					for i in range(prior.size()):
						check(prior[i].kind==expanded[i].kind and int(expanded[i].hp)<=int(prior[i].hp),"original upper roles retained without hp inflation")
					if pressure==0 and not boss:
						m=fixture(["charge","precise"])
						m.s.enemies=fresh.active.duplicate(true);m.s.reinforcements=fresh.reserve.duplicate(true)
						m.s.encounter_total=fresh.total;m.s.deployed=4;m.assign_opening_lanes()
						setup_core(m,"thermal_drive",4);m.s.heat=5
						fire(m,["charge","precise"])
	# Reinforcements arrive after the action at published distance, not during a bullet.
	m=fixture(["charge","basic"],[["runner",1,0,1,24],["runner",1,0,1,27]])
	setup_core(m,"siege_drive",4)
	m.s.reinforcements=[Data._enemy(["runner",4,0,2,21]),Data._enemy(["wall",7,2,1,24])]
	for enemy in m.s.reinforcements: enemy.lane=-1
	m.s.encounter_total=4
	shots=fire(m,["charge","basic"])
	check(m.s.enemies.size()==4 and m.s.enemies[2].hp==4 and m.s.enemies[2].distance==21,"new group has a fresh decision window")
	check(m.s.enemies[2].lane!=m.s.enemies[3].lane,"new group uses separate existing lanes")
	# Exact random forecasts include wave targets and do not modify state.
	for seed_value in range(1,13):
		m=fixture(["basic"],rows,"scatter");setup_core(m,"thermal_drive",4);m.s.heat=Ammo.heat_limit(m.s)-1
		m.s.target_rng_state=str(seed_value*99871)
		m.load_round("basic")
		var before := JSON.stringify(m.s)
		var predicted := Forecast.analyze(m.s)
		check(JSON.stringify(m.s)==before,"wave forecast leaves live state unchanged")
		check(m.confirm() and m.fire(),"random overheat action")
		for i in range(m.s.enemies.size()): check(m.s.enemies[i].hp>=predicted.enemies[i].hp_min and m.s.enemies[i].hp<=predicted.enemies[i].hp_max,"wave actual hp in exact random range")
	var mock := {"target":0,"damage":4,"hp":0,"secondary":[{"target":10001,"damage":1,"hp":0},{"target":1,"damage":2,"hp":2},{"target":1,"damage":2,"hp":0}]}
	cue=Payoff.describe(mock)
	check(cue.kills==2 and cue.damage==9,"payoff excludes projectile kills and counts target once")
	var file=FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("comparisons.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(comparisons,"  "));file.close()
	print("BUILD PAYOFF RULES COMPLETE checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
