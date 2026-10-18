extends "res://tests/heat_rules_runner.gd"
const Engines = preload("res://redesign/damage_engines.gd")
var comparisons: Array = []

func equip(m: RefCounted, id: String, level: int = 0, extra: Array = []) -> void:
	m.s.equipped_parts = [id]+extra
	m.s.engine.levels[id] = level

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/damage_engines/"): quit(1); return
	var m = fixture(["precise"],[["runner",3,0,1,24],["runner",3,0,1,27],["runner",3,0,1,30]])
	equip(m,"volley_drive",0,["duplex"])
	var shots := fire(m,["precise"])
	check(shots[0].damage==3 and shots[0].relay_damage==6 and shots[0].secondary.size()==2,"remaining hits reach two new targets")
	check(shots[0].heat_added==5 and m.s.shots==1,"relay costs one card, multihit heat once")
	check(Ammo.heat_label("precise",m.s)=="+5" and Ammo.heat_label("basic",m.s)=="+1","hand card includes unconditional core heat penalty")
	check(m.s.engine.levels.volley_drive==1 and m.s.engine.gains==["volley_drive"],"three actual damaging hits earn one victory growth")
	Engines.settle(m.s,Ammo.equipped_parts(m.s))
	check(m.s.engine.levels.volley_drive==1,"settlement is idempotent")
	m.begin_encounter()
	check(Engines.level(m.s,"volley_drive")==1 and m.s.engine.hits==0 and not m.s.engine.settled,"run growth persists, encounter progress resets")
	# Barriers and new-target armor absorb continuation normally.
	m=fixture(["precise"],[["runner",1,0,1,24],["wall",20,3,1,28]])
	equip(m,"volley_drive",0,["duplex"])
	m.s.enemies[1].barrier=1
	shots=fire(m,["precise"])
	check(shots[0].secondary.size()==2 and shots[0].secondary[0].damage==0 and shots[0].secondary[1].damage==1,"relay respects barrier then armor")
	check(m.s.engine.hits==2 and m.s.engine.gains.is_empty(),"blocked hit is not growth")
	check(shots[0].part_effects.any(func(effect): return effect.id=="duplex"),"extra hit part feedback counts relayed hits")
	# Overflow is conserved, subtracts each target's armor, never reapplies xMult.
	m=fixture(["charge","basic"],[["runner",2,0,1,24],["wall",6,1,1,27],["wall",20,2,1,30]])
	equip(m,"siege_drive")
	shots=fire(m,["charge","basic"])
	check(shots[1].math.raw==12 and shots[1].damage==2 and shots[1].relay_damage==7,"single x2 overkill 10 becomes 6+1 through armor")
	check(shots[1].secondary[0].damage==6 and shots[1].secondary[1].damage==1,"overflow decreases monotonically")
	check(m.s.engine.siege and not m.s.engine.settled,"growth qualification waits for win")
	m=fixture(["charge","basic"],[["runner",2,0,1,24],["wall",6,0,1,27],["runner",5,0,1,30]])
	equip(m,"siege_drive"); m.s.enemies[1].barrier=1
	shots=fire(m,["charge","basic"])
	check(shots[1].relay_damage==0 and m.s.enemies[2].hp==5,"barrier stops entire overflow, no bypass")
	m=fixture(["precise"],[["runner",100,0,1,24]])
	equip(m,"siege_drive",8)
	shots=fire(m,["precise"])
	check(shots[0].engine_percent==100 and shots[0].relay_damage==0,"single build never multiplies multihit")
	# High-heat uses pre-shot temperature, support and DoT never gain direct multipliers.
	for hot in [false,true]:
		m=fixture(["basic"],[["runner",100,0,1,24]])
		equip(m,"thermal_drive",4)
		m.s.heat=5 if hot else 4
		shots=fire(m,["basic"])
		check(shots[0].damage==(7 if hot else 3),"heat threshold precedes shot heat")
		check(m.s.engine.hot==hot,"hot growth requires effective hot attack")
	m=fixture(["shatter"],[["wall",100,3,1,24]])
	equip(m,"thermal_drive",8); m.s.heat=5
	shots=fire(m,["shatter"])
	check(shots[0].damage==0 and not m.s.engine.hot,"support never becomes raw damage or growth")
	m=fixture(["basic"],[["runner",4,0,1,24]])
	equip(m,"thermal_drive"); m.s.heat=5
	shots=fire(m,["basic"])
	check(Engines.level(m.s,"thermal_drive")==1 and m.s.phase=="reward","hot victory grows once")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(m.s))
	var restored=Model.new()
	check(restored.restore_state(saved) and restored.s.engine==saved.engine,"new growth save round-trip")
	var bad: Dictionary=saved.duplicate(true); bad.engine.levels.thermal_drive=99
	check(not restored.restore_state(bad),"reject excessive growth")
	bad=saved.duplicate(true); bad.engine.hot=1
	check(not restored.restore_state(bad),"reject invalid qualification type")
	bad=saved.duplicate(true); bad.version=14; bad.erase("engine")
	check(restored.restore_state(bad) and restored.s.engine.levels.is_empty() and restored.s.buff==bad.buff,"old save migrates without invented growth")
	for id in Engines.IDS:
		m=fixture(["basic"],[["runner",1,0,1,24]])
		equip(m,id,8)
		m.s.engine.hits=3; m.s.engine.hot=true; m.s.engine.siege=true
		fire(m,["basic"])
		check(Engines.level(m.s,id)==8 and m.s.engine.gains.is_empty(),"growth cap "+id)
	# Unequipping cannot erase growth; loss cannot award growth.
	m=fixture(["basic"],[["runner",100,0,3,1]])
	equip(m,"volley_drive",2); m.s.engine.hits=3
	fire(m,["basic"])
	check(m.s.phase=="lost" and Engines.level(m.s,"volley_drive")==2,"loss awards nothing")
	m.s.equipped_parts=[]; m.begin_encounter()
	check(Engines.level(m.s,"volley_drive")==2 and Engines.flat(m.s,[])==0,"stored growth inert while unequipped")
	# Same ordinary basic bullet has independent, testable growth paths.
	for id in Engines.IDS:
		var damage_curve: Array=[]
		for level in [0,4,8]:
			m=fixture(["basic"],[["runner",100,0,1,24]])
			equip(m,id,level)
			if id=="thermal_drive": m.s.heat=5
			shots=fire(m,["basic"])
			damage_curve.append(int(shots[0].damage))
		check(damage_curve[0]<damage_curve[1] and damage_curve[1]<damage_curve[2],"basic grows through "+id)
		comparisons.append({"core":id,"basic_damage_at_0_4_8":damage_curve})
	# Exact random analysis must include growth in cache/branch keys and own mutable data.
	for id in Engines.IDS:
		for seed_value in range(1,13):
			m=fixture(["charge","precise","basic"],[["runner",3,0,1,24],["wall",20,2,1,27],["runner",20,0,1,30]],"scatter")
			equip(m,id,seed_value%4,["duplex"] if id=="volley_drive" else [])
			m.s.target_rng_state=str(seed_value*99871)
			if id=="thermal_drive": m.s.heat=5
			for bullet in Ammo.loading_order(["charge","precise","basic"]): check(m.load_round(bullet),"random legal load")
			var before:=JSON.stringify(m.s)
			var prediction:=Forecast.analyze(m.s)
			check(JSON.stringify(m.s)==before,"scatter preview cannot mutate growth")
			check(m.confirm() and m.fire(),"actual random fire")
			for i in range(m.s.enemies.size()): check(m.s.enemies[i].hp>=prediction.enemies[i].hp_min and m.s.enemies[i].hp<=prediction.enemies[i].hp_max,"actual random hp in exact range")
			check(restored.restore_state(JSON.parse_string(JSON.stringify(m.s))),"random growth state restores")
	# Direct modifiers multiply in one subtotal, rather than a named recipe bonus.
	for core in ["volley_drive","thermal_drive","siege_drive"]:
		m=fixture(["charge","charge_hot","basic"],[["runner",500,0,1,30]])
		equip(m,core,4)
		shots=fire(m,["charge","charge_hot","basic"])
		var expected := 22 if core=="volley_drive" else 30 if core=="thermal_drive" else 36
		check(shots.back().damage==expected,"additive support x bullet multiplier x growing core " + core)
	# Qualification survives save/reload, including a later burn victory on reload.
	m=fixture(["basic"],[["runner",100,0,1,30]])
	equip(m,"thermal_drive"); m.s.heat=5
	fire(m,["basic"])
	check(restored.restore_state(JSON.parse_string(JSON.stringify(m.s))) and restored.s.engine.hot,"save active qualification")
	restored.s.enemies[0].hp=1; restored.s.enemies[0].burn=1
	check(restored.reload_magazine() and restored.s.phase=="reward" and Engines.level(restored.s,"thermal_drive")==1,"reload burn victory settles earned growth")
	# Remaining direct hits and overkill can intercept the nearest pressure projectile.
	for core in ["volley_drive","siege_drive"]:
		m=fixture(["precise" if core=="volley_drive" else "basic"],[["runner",1,0,1,24],["spitter",100,0,0,30]])
		equip(m,core,4,["duplex"] if core=="volley_drive" else [])
		m.s.enemies[1].ranged_phase="waiting"; m.s.enemies[1].ranged_left=0
		m.s.projectiles=[{"uid":1,"source":1,"kind":"pressure","name":"압력탄","hp":1,"max_hp":1,"def":0,"speed":6,"distance":26,"burn":0,"barrier":0,"focus_hits":0,"lane":0}]
		m.s.projectile_serial=1
		shots=fire(m,["precise" if core=="volley_drive" else "basic"])
		check(shots[0].secondary[0].target==10001 and shots[0].secondary[0].intercept,"continuation intercepts hazard before back enemy")
	# Campaign core offers use normal reward/equip/save paths, old campaigns remain eligible for old ammo rewards.
	var c=Campaign.new(); c.start("single",731042,0,"balanced",Data.RouteMap.VERSION,"carrier")
	check(c.enter(int(c.choices()[0].id)),"enter first encounter")
	c.s.clears=1; c.s.phase="reward"
	check(c.part_rewards().size()==3 and c.reward_options().is_empty(),"first victory offers three build directions")
	check(c.reward("thermal_drive") and c.equipped_parts().has("thermal_drive"),"real reward equips core")
	c.model.s.engine.levels.thermal_drive=3
	var save_path:= "user://engine_campaign.json"
	check(c.save(save_path)==OK,"save campaign growth")
	var loaded=Campaign.new(); check(loaded.restore(save_path) and Engines.level(loaded.model.s,"thermal_drive")==3,"campaign atomic growth restore")
	c.s.erase("build_version"); c.s.phase="reward"; c.s.resolved=false
	check(not c.engine_reward() and not c.reward_options().is_empty(),"legacy campaign keeps ordinary rewards")
	var file=FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("comparisons.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(comparisons,"  ")); file.close()
	print("DAMAGE ENGINES RULES COMPLETE checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
