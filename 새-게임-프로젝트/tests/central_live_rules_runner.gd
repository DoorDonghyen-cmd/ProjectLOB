extends "res://tests/foundry_live_rules_runner.gd"
const Guard=preload("res://redesign/central_guard.gd")

func guard(id:String=Guard.RULER,gun:String="single",ammo:Array=["basic_p3"]):
	return fixture(ammo,[Guard.unit(id,80 if id==Guard.RULER else 38 if id==Guard.CAPTAIN else 14,60)],gun)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/central_live/"):quit(1);return
	for seed_value in [17,731042,931104]:
		for depth in range(1,11):
			for kind in ["normal","elite","boss"]:
				var node={"id":40000+depth*100+1,"region":4,"floor":depth,"kind":"boss" if kind=="boss" else "combat","elite":kind=="elite","name":"QA"}
				var pack=Data.encounter_pack(node,seed_value,"single",0,0,11)
				var units:Array=pack.active+pack.reserve
				check(pack.active.size()==4 and pack.total>=6 and pack.total<=8,"finite declared population")
				check(units.all(Guard.active) and units.all(Guard.valid),"every central actor registered and valid")
				check(units.filter(func(e):return e.kind=="spitter").size()<=1,"at most one ranged source")
				check(units.filter(Guard.leader).size()==(0 if kind=="normal" else 1),"one public command source")
				if kind=="normal":
					var species:Array=[]
					for e in units:
						if not species.has(e.species):species.append(e.species)
					check(species.size()<=3,"ordinary fights do not stack all four roles")
				var m=fixture(["basic"])
				m.s.enemies=pack.active.duplicate(true);m.s.reinforcements=pack.reserve.duplicate(true)
				m.s.encounter_total=pack.total;m.s.deployed=4;m.assign_opening_lanes()
				check(Model.new().restore_state(m.s),"whole encounter saves")
				for gun in Ammo.GUNS:check(pack==Data.encounter_pack(node,seed_value,gun,0,0,11),"same enemies for every weapon")
				check(not Data.encounter_pack(node,seed_value,"single",0,0,10).active.any(Guard.active),"roster 10 unchanged")
				for region in range(4):
					node.region=region
					var previous=Data.encounter_pack(node,seed_value,"single",0,0,10)
					var current=Data.encounter_pack(node,seed_value,"single",0,0,11)
					if region==0 and kind=="boss":
						check(previous.active[0].hp==44 and current.active[0].hp==32,"new first gate lowers ammo demand; old roster retained")
						current.active[0].hp=44;current.active[0].max_hp=44
					check(previous==current,"earlier formations retained apart from declared first gate HP")
	for id in [Guard.CAPTAIN,Guard.RULER]:
		var m=fixture(["basic"],[Guard.unit(id,80,60),Guard.unit(Guard.RUSHER,12,40),Guard.unit(Guard.SHIELD,12,50),Guard.unit(Guard.ARTILLERY,12,70)])
		m.s.enemies[0].barrier=0;m.s.enemies[2].barrier=0
		m.s.reinforcements=[Data._enemy(Guard.unit(Guard.HEAVY,20,45))]
		m.s.encounter_total=5
		var reserve=m.s.reinforcements.duplicate(true)
		for tick in range(6):reload_exact(m)
		check(m.s.enemies[0].command_order=="advance" and m.s.enemies[0].command_left==3,"alternates exactly one order per period")
		check(m.s.enemies[0].distance==52 and m.s.enemies[1].distance==26,"public advance includes source and mobile ally")
		check(m.s.enemies[3].distance==70 and m.s.reinforcements==reserve,"artillery and reserves do not move on command")
		check(m.s.enemies[0].barrier==Guard.CAPACITY[id] and m.s.enemies[1].barrier==1 and m.s.enemies[2].barrier==0,"shield refills source and nearest eligible ally only")
		check(m.s.enemies[0].hp==80,"command never heals or caps HP")
	var m=guard(Guard.SHIELD,"single",["arc","basic"])
	var shots=fire(m,["arc","basic"])
	check(shots[0].barrier_removed==2 and shots[1].damage>0,"electric opening followed by direct HP damage")
	for tick in range(4):reload_exact(m)
	check(m.s.enemies[0].barrier==0,"shield guard never regenerates on its own")
	m=guard(Guard.SHIELD,"single",["precise_p3"]);m.s.enemies[0].barrier=1
	shots=fire(m,["precise_p3"])
	check(shots[0].blocked_hits==1 and shots[0].damage>0,"remaining multihit reaches exposed HP")
	m=fixture(["arc"],[Guard.unit(Guard.RUSHER,40,40),Guard.unit(Guard.SHIELD,12,50)])
	shots=fire(m,["arc"])
	check(m.s.enemies[1].barrier==2 and m.s.enemies[1].hp==10,"ordinary electric transfer preserves existing direct secondary damage rule")
	m=fixture(["precise_p3"],[Guard.unit(Guard.RUSHER,1,40),Guard.unit(Guard.SHIELD,12,50)])
	m.s.equipped_parts=["volley_drive"]
	shots=fire(m,["precise_p3"])
	var relays:Array=shots[0].secondary.filter(func(item):return item.kind=="relay")
	check(not relays.is_empty() and relays.back().has("barrier_removed") and relays.back().has("exposure_left"),"core relay reports central shield damage")
	m=fixture(["basic_p3"],[Guard.unit(Guard.RUSHER,80,40),Guard.unit(Guard.SHIELD,12,50)],"heavy")
	m.s.equipped_parts=["thermal_drive"];m.s.engine.levels.thermal_drive=8
	m.s.heat=Ammo.heat_limit(m.s)-1
	shots=fire(m,["basic_p3"])
	var waves:Array=shots[0].secondary.filter(func(item):return item.kind=="heat_wave")
	check(waves.size()==1 and waves[0].barrier_removed==1 and waves[0].exposure_left==0,"heat wave shows remaining central shield")
	m=guard(Guard.RULER,"single",["bore"])
	fire(m,["bore"]);check(m.s.enemies[0].hp<80,"burn bypasses shield")
	m=guard(Guard.HEAVY,"single",["shatter"])
	fire(m,["shatter"]);check(m.s.enemies[0].def==0 and Model.new().restore_state(m.s),"shattered armor persists without regrowth")
	m=guard(Guard.RULER,"single",["disrupt"]);m.s.enemies[0].command_left=1
	fire(m,["disrupt"]);check(m.s.enemies[0].command_left==1 and m.s.enemies[0].distance==59,"disrupt freezes command but not ordinary movement")
	m=fixture(["basic"],[Guard.unit(Guard.CAPTAIN,1,60),Guard.unit(Guard.RUSHER,10,40)])
	m.s.enemies[0].burn=1;m.s.enemies[0].command_left=1
	reload_exact(m);check(m.s.enemies[0].hp==0 and m.s.enemies[1].distance==38,"burn kill cancels imminent order")
	m=guard();m.s.enemies[0].command_left=1;m.s.enemies[0].distance=2
	reload_exact(m);check(m.s.phase=="lost","advance contact has predicted defeat")
	m=guard(Guard.RULER,"amplifier",["charge","basic_p5"]);m.s.enemies[0].barrier=0
	m.s.enemies[0].hp=60 # Wounded live ruler: there is no forced last-HP phase gate.
	m.s.equipped_parts=["siege_drive"];m.s.engine.levels.siege_drive=8
	fire(m,["charge","basic_p5"]);check(m.fire() and m.s.enemies[0].hp==0,"powerful build can kill without mandatory command cycle")
	for gun in ["single","burst","heavy","amplifier"]:
		m=guard(Guard.RULER,gun,["arc","basic_p3"]);m.s.enemies[0].command_left=1
		m.s.heat=Ammo.heat_limit(m.s)-1
		fire(m,["arc","basic_p3"])
		check(Model.new().restore_state(m.s),"forced cooling preserves command state "+gun)
	for seed_value in range(1,13):
		m=fixture(["arc","basic","disrupt"],[Guard.unit(Guard.RULER,80,60),Guard.unit(Guard.SHIELD,14,55)],"scatter")
		m.s.enemies[0].command_left=1;m.s.enemies[0].command_order="shield"
		m.s.enemies[0].barrier=1;m.s.enemies[1].barrier=0
		var rng=RandomNumberGenerator.new();rng.seed=seed_value;m.s.target_rng_state=str(rng.state)
		for ammo in ["arc","basic","disrupt"]:check(m.load_round(ammo),"scatter load")
		var before:=JSON.stringify(m.s)
		var prediction=Forecast.analyze(m.s,true,true)
		check(before==JSON.stringify(m.s),"random command preview does not consume live RNG")
		check(m.confirm() and m.fire(),"random volley")
		for i in range(2):
			var e=m.s.enemies[i];var p=prediction.enemies[i]
			check(e.hp>=p.hp_min and e.hp<=p.hp_max and e.distance>=p.distance_min and e.distance<=p.distance_max,"random result within published range")
		check(Model.new().restore_state(m.s),"random command persistence")
	m=guard()
	for key in ["central_version","command_left","barrier_max"]:
		for value in [-1,0.5,100,"bad"]:
			var bad=m.s.duplicate(true);bad.enemies[0][key]=value
			check(not Model.new().restore_state(bad),"reject malformed central state "+key)
	var c=Campaign.new();c.start("single",17)
	check(c.s.roster_version==11,"new run uses central roster")
	for version in range(1,12):
		var saved={"campaign":c.s.duplicate(true),"combat":c.model.s.duplicate(true),"profile":c.profile.duplicate(true)}
		saved.campaign.roster_version=version
		var copy=Campaign.new();check(copy.restore_state(saved) and copy.s.roster_version==version,"saved roster remains pinned")
		copy.s.region=4
		check((copy.current_nodes().filter(func(n):return n.kind=="boss")[0].name=="탑의 지배자")== (version>=11),"final gate identity follows saved roster")
	var file=FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("rules.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures}));file.close()
	print("CENTRAL LIVE RULES COMPLETE checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
