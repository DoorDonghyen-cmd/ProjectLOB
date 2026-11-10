extends "res://tests/reactor_rules_runner.gd"
const Workers = preload("res://redesign/foundry_workers.gd")
const Guard = preload("res://redesign/central_guard.gd")
const Readability = preload("res://redesign/readability.gd")

func pressure(ids: Array, rows: Array = [], gun: String = "heavy"):
	var m=fixture(ids,rows,gun)
	m.s.combat_revision=2
	return m

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/playtest_revision_20261026/"):quit(2);return
	# Hand-calculated boundaries: fractional mitigation, cap, minimum, zero support.
	for example in [[20,3,14],[40,3,28],[7,3,4],[20,0,20],[20,8,4],[20,12,4],[1,3,1],[0,3,0]]:
		check(Ammo.armored_damage(example[0],example[1],{"combat_revision":2})==example[2],"percentage armor boundary "+str(example))
	check(Ammo.armored_damage(1,3,{"combat_revision":2},0)==0,"overflow has no invented minimum damage")
	for revision in [0,1]:check(Ammo.armored_damage(40,3,{"combat_revision":revision})==37,"saved flat armor preserved")
	# Real resolver and forecast: a boosted basic pays 30%, AP ignores all 3 armor.
	for revision in [1,2]:
		var damage:Array=[]
		for id in ["basic_p3","pierce_p3"]:
			var m=pressure(["charge",id],[["wall",200,3,1,70]])
			m.s.combat_revision=revision;m.s.equipped_parts=["sequencer","siege_drive"]
			var shot:Dictionary=execute(m,["charge",id]).results[1]
			damage.append(shot.damage)
			if revision==2 and id=="basic_p3":
				check(shot.math.raw==18 and shot.damage==12,"18 direct damage becomes 12 through armor 3")
				check(Readability.explain(shot).contains("×70% (장갑3, 버림)"),"receipt explains actual mitigation")
			if revision==2 and id=="pierce_p3":check(shot.damage==18 and shot.math.armor_percent==0,"AP keeps full boosted damage")
		check(damage[1]>damage[0],"penetration changes actual damage at revision "+str(revision))
	# Shatter applies after its own direct hit. Reversing order must lose damage.
	var forward=pressure(["shatter","basic_p3"],[["wall",200,3,1,70]])
	var reverse=pressure(["shatter","basic_p3"],[["wall",200,3,1,70]])
	var first=execute(forward,["shatter","basic_p3"]).results
	var last=execute(reverse,["basic_p3","shatter"]).results
	check(first[0].math.armor==3 and first[1].math.armor==0,"shatter only helps later shots")
	check(first[1].damage>last[0].damage,"shatter order matters against percentage armor")
	# Burn/detonation and electric transfer preserve their fixed bypass rules.
	var burn=pressure(["bore","detonate"],[["absorber",200,3,1,70]])
	var burn_shots=execute(burn,["bore","detonate"]).results
	check(burn_shots[1].detonation==3*Ammo.burn_damage(burn.s) and burn.s.enemies[0].burn==0,"detonation bypass remains exact behind barrier")
	var arc=pressure(["arc"],[["wall",100,8,1,70],["wall",100,8,1,75]])
	var arc_shot=execute(arc,["arc"]).results[0]
	check(arc_shot.secondary[0].damage==Ammo.effect_value("arc",arc.s),"electric transfer ignores armor")
	# Overflow is mitigated once on each new target; no factor or minimum is repeated.
	var overflow=pressure(["charge","basic_p3"],[["wall",10,0,1,70],["wall",100,3,1,75]])
	overflow.s.equipped_parts=["sequencer","siege_drive"]
	var spill=execute(overflow,["charge","basic_p3"]).results[1]
	check(spill.damage==10 and spill.relay_damage==5,"18 minus 10 spills 8, armor 3 leaves 5")
	var relay=pressure(["precise"],[["runner",1,0,1,70],["wall",100,3,1,75]])
	relay.s.equipped_parts=["volley_drive","duplex"]
	var relay_shot=execute(relay,["precise"]).results[0]
	check(relay_shot.relay_damage==6 and relay_shot.relay_hits==3,"three remaining 3-damage hits each become 2")
	# Overdrive affects only the extra attack, before armor, including all its hits.
	for order in [["basic","basic","basic"],["basic","cool","basic"],["basic","charge","basic"],["basic","precise","basic"]]:
		var m=pressure(order,[["wall",200,3,1,70]])
		m.s.heat=13
		var detail=execute(m,order)
		check(detail.results.size()==2 and detail.results[0].overdrive_percent==100,"threshold hit is never boosted")
		var extra:Dictionary=detail.results[1]
		check(extra.overdrive and extra.overdrive_percent==(200 if Ammo.is_attack(order[1]) else 100),"extra attack alone gets 200 percent")
		if order[1]=="basic":check(extra.math.raw==4 and extra.damage==2 and detail.forced_reload.cost==4,"overdrive rounds before armor and keeps forced cooling cost")
		if order[1]=="cool":check(detail.forced_reload.is_empty() and m.s.magazine==["basic"] and m.s.turns==1,"cool alternative avoids four enemy turns and preserves reserve")
		if order[1]=="precise":check(extra.damage==4 and extra.hits==2,"overdrive applies to the full multi-hit card")
		if Ammo.is_attack(order[1]):check(Readability.explain(extra).contains("×2.00(강행)"),"overdrive receipt matches resolver")
	var wave=pressure(["basic","basic_p3"],[["wall",200,0,1,70],["wall",200,3,1,75]])
	wave.s.equipped_parts=["thermal_drive"];wave.s.heat=11
	var waves=execute(wave,["basic","basic_p3"]).results
	check(waves[1].math.raw==9 and waves[1].secondary[0].damage==2,"overdrive thermal wave uses half of 9, floors to 4 then 30 percent mitigation")
	var heat_cases:Array=[]
	for order in [["basic","basic"],["basic","cool"]]:
		var m=pressure(order,Workers.revise([Workers.leader(Workers.BOSS,56,70)]))
		m.s.heat=13
		var detail=execute(m,order)
		var risky:bool=order[1]=="basic"
		check(m.s.enemies[0].distance==(58 if risky else 69),"forced cooling advances through surge and recovery")
		heat_cases.append({"order":order,"turns":m.s.turns,"boss_distance":m.s.enemies[0].distance,"damage":48-int(m.s.enemies[0].hp),"forced_cost":detail.forced_reload.get("cost",0)})
	# Every authored new encounter saves; older encounter constructors stay exact.
	for region in [1,4]:
		for seed_value in [17,731042,931104]:
			for kind in ["normal","elite","boss"]:
				var node={"id":region*10000+901,"region":region,"floor":9,"kind":"boss" if kind=="boss" else "combat","elite":kind=="elite","name":"QA"}
				var old=Data.encounter_pack(node,seed_value,"single",0,0,11,1)
				check(old==Data.encounter_pack(node,seed_value,"single",0,0,11),"legacy encounter remains exact")
				var pack=Data.encounter_pack(node,seed_value,"single",0,0,11,2)
				var m=pressure(["basic"])
				m.s.enemies=pack.active.duplicate(true);m.s.reinforcements=pack.reserve.duplicate(true)
				m.s.encounter_total=pack.total;m.s.deployed=pack.active.size();m.assign_opening_lanes()
				check(Model.new().restore_state(JSON.parse_string(JSON.stringify(m.s))),"new pack roundtrip")
				check(pack.total==old.total,"no unlimited reinforcements")
				for gun in Ammo.GUNS:check(pack==Data.encounter_pack(node,seed_value,gun,0,0,11,2),"same new enemies for every gun")
				var bad:Dictionary=m.s.duplicate(true);bad.combat_revision=1
				check(not Model.new().restore_state(bad),"new enemies cannot be silently loaded under old rules")
	# Foundry surge/recovery/jam: real actions and save/forecast at each transition.
	var machine=pressure(["basic"],Workers.revise([Workers.leader(Workers.BOSS,56,70)]),"single")
	for expected in [69,64,64,63,58,58]:
		var predicted=Forecast.reload_now(machine.s,true)
		check(machine.reload_magazine(),"legal foundry wait")
		check(machine.s.enemies[0].distance==expected,"two actions to surge then one recovery")
		check(Model.new().restore_state(JSON.parse_string(JSON.stringify(machine.s))),"foundry transition saves")
		check(predicted.enemies==machine.s.enemies and predicted.phase==machine.s.phase,"foundry wait forecast matches surge and recovery")
	var jam=pressure(["disrupt"],Workers.revise([Workers.leader(Workers.BOSS,56,70)]),"single")
	var stopped=execute(jam,["disrupt"])
	check(stopped.results[0].interrupted==1 and jam.s.enemies[0].windup==0,"disrupt delays new foundry windup")
	# Central alternates every two actions, adds one shield, excludes reserves.
	var guard=pressure(["basic"],[Guard.unit(Guard.RULER,80,70,2),Guard.unit(Guard.RUSHER,12,50,2),Guard.unit(Guard.SHIELD,12,60,2)],"single")
	guard.s.enemies[0].barrier=0;guard.s.enemies[2].barrier=0
	guard.s.reinforcements=[Data._enemy(Guard.unit(Guard.HEAVY,16,60,2))];guard.s.encounter_total=4
	var waiting=guard.s.reinforcements.duplicate(true)
	for tick in 4:
		var predicted=Forecast.reload_now(guard.s,true)
		check(guard.reload_magazine(),"legal central wait")
		check(predicted.enemies==guard.s.enemies and predicted.phase==guard.s.phase,"central wait forecast matches orders")
		check(Model.new().restore_state(JSON.parse_string(JSON.stringify(guard.s))),"central transition saves")
	check(guard.s.enemies[0].distance==64 and guard.s.enemies[1].distance==40,"central advance occurs after second action")
	check(guard.s.enemies[0].barrier==1 and guard.s.enemies[1].barrier==1 and guard.s.enemies[2].barrier==0,"shield command adds one to source and closest ally")
	check(guard.s.reinforcements==waiting and guard.s.enemies[0].command_left==2,"reserves excluded and period reset")
	check(Guard.detail(guard.s.enemies[0]).contains("2행동마다") and Guard.intent(guard.s.enemies[0]).contains("2턴"),"commander telegraph matches period")
	# Exact random forecasts must not reuse revision 1 armor outcomes.
	for kind in ["elite","boss"]:
		var preview=preload("res://redesign/foundry_preview.gd").campaign("single",kind,true,2)
		check(preview!=null and preview.model.s.enemies[0].windup_max==2,"developer foundry uses new rules "+kind)
		var central=preload("res://redesign/central_preview.gd").campaign(2,kind,11,2)
		check(central!=null and central.model.s.enemies[0].command_left==2,"developer central uses new rules "+kind)
		check(preview.model.s.combat_revision==2 and central.model.s.combat_revision==2,"developer rules explicitly opt in without migrating source saves")
	for revision in [1,2,1,2]:
		var m=pressure(["charge","basic_p3"],[["wall",100,3,1,70],["wall",100,5,1,75]],"scatter")
		m.s.combat_revision=revision
		for id in Ammo.loading_order(["charge","basic_p3"]):check(m.load_round(id),"random load")
		var forecast=Forecast.analyze(m.s,true,true)
		check(m.confirm() and m.fire(),"random fire")
		for i in m.s.enemies.size():check(m.s.enemies[i].hp>=forecast.enemies[i].hp_min and m.s.enemies[i].hp<=forecast.enemies[i].hp_max,"actual armor outcome in exact random range")
	var reactor_preview=preload("res://redesign/foundry_preview.gd").campaign("heavy","boss",true,2)
	check(Ammo.weapon_spec(reactor_preview.model.s).capacity==6 and Ammo.overdrive_percent(reactor_preview.model.s)==200,"old earned preview deck uses current Reactor mechanics only when requested")
	FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("pressure.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"heat_cases":heat_cases},"  "))
	print("PLAYTEST REVISION PRESSURE COMPLETE checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
