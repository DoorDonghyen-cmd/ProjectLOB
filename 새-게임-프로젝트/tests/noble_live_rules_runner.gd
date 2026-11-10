extends "res://tests/foundry_live_rules_runner.gd"
const House=preload("res://redesign/noble_house.gd")

func noble(id: String=House.BOSS,gun: String="single",ammo: Array=["basic_p3"]):
	return fixture(ammo,[House.unit(id,64 if id==House.BOSS else 36 if id==House.ELITE else 12,50)],gun)

func chain_and_scatter_checks() -> void:
	var readout=preload("res://redesign/damage_readout.gd")
	for core in ["volley_drive","siege_drive","thermal_drive"]:
		var ammo="precise_p3" if core=="volley_drive" else "basic_p3"
		var m=fixture([ammo],[House.unit(House.LABOR,1,40),House.unit(House.BOSS,64,50)])
		m.s.enemies[1].barrier=1
		m.s.equipped_parts=[core];m.s.engine.levels[core]=4
		if core=="thermal_drive":m.s.heat=Ammo.heat_limit(m.s)-1
		var shots=fire(m,[ammo])
		var effects:Array=shots[0].secondary
		check(effects.any(func(e):return e.target==1 and e.barrier==0 and e.exposure_left==5),"core followup opens a full shield clock "+core)
		var opening:Dictionary=effects.filter(func(e):return e.get("exposure_left",0)==5)[0]
		check(readout.entry(opening,str(opening.kind)).number=="파손","secondary opening is explicit "+core)
		check(Model.new().restore_state(m.s),"secondary opening survives save "+core)
	for seed_value in range(1,13):
		var m=fixture(["basic","arc","disrupt"],[House.unit(House.NOBLE,12,40),House.unit(House.BOSS,64,50)],"scatter")
		m.s.enemies[0].barrier=1
		House.strip(m.s.enemies[1],4);m.s.enemies[1].exposure_left=1
		var rng=RandomNumberGenerator.new();rng.seed=seed_value;m.s.target_rng_state=str(rng.state)
		for id in Ammo.loading_order(["basic","arc","disrupt"]):check(m.load_round(id),"scatter load")
		var before=JSON.stringify(m.s)
		var prediction=Forecast.analyze(m.s,true,true)
		check(before==JSON.stringify(m.s),"random shield forecast preserves live state")
		check(m.confirm() and m.fire(),"scatter shield volley")
		for i in range(m.s.enemies.size()):
			var e=m.s.enemies[i];var p=prediction.enemies[i]
			check(e.hp>=p.hp_min and e.hp<=p.hp_max and e.distance>=p.distance_min and e.distance<=p.distance_max,"random exposed/rearm actual state within public range")
		check(Model.new().restore_state(m.s),"scatter shield clock survives save")
	var closed=readout.entry({"damage":0,"blocked_hits":1,"barrier_removed":2,"barrier":2,"exposure_left":0})
	check(closed.number=="차폐" and closed.label=="−2회 · 2 남음","blocked electric hit shows exact progress")
	var opened=readout.entry({"damage":0,"blocked_hits":1,"barrier_removed":2,"barrier":0,"exposure_left":5})
	check(opened.number=="파손" and opened.label=="본체 노출","last blocked hit communicates vulnerability")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/noble_live/"):quit(1);return
	chain_and_scatter_checks()
	var art=preload("res://redesign/noble_art.gd")
	check(same_registration(art.data(),JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/noble_enemies_20261025/registration.json")).species),"runtime atlas matches measured source")
	for texture in art.TEXTURES.values():check(texture is Texture2D,"authored texture imported")
	for seed_value in [17,731042,931104]:
		for depth in [1,4,8]:
			for kind in ["normal","elite","boss"]:
				var node={"id":30601,"region":3,"floor":depth,"kind":"boss" if kind=="boss" else "combat","elite":kind=="elite","name":"QA"}
				var pack=Data.encounter_pack(node,seed_value,"single",0,0,10)
				check(pack.active.size()==4 and pack.total>=6 and pack.total<=7,"finite formation")
				check((pack.active+pack.reserve).all(House.active),"every noble district actor authored")
				check((pack.active+pack.reserve).all(House.valid),"spawn state valid")
				check((pack.active+pack.reserve).filter(func(e):return e.kind=="spitter").size()==1,"one pressure source including reserve")
				var full=fixture(["basic"])
				full.s.enemies=pack.active.duplicate(true);full.s.reinforcements=pack.reserve.duplicate(true)
				full.s.encounter_total=pack.total;full.s.deployed=pack.active.size();full.assign_opening_lanes()
				check(Model.new().restore_state(full.s),"every route band full combat state restores")
				check((pack.active+pack.reserve).any(func(e):return e.species==House.LABOR),"unshielded chain target always available")
				check((pack.active+pack.reserve).all(func(e):return e.def==0 and not e.get("stance",false)),"shield role without stacked armor")
				for gun in Ammo.GUNS:check(pack==Data.encounter_pack(node,seed_value,gun,0,0,10),"same opposition for all weapons")
				check(not Data.encounter_pack(node,seed_value,"single",0,0,9).active.any(House.active),"old encounters preserved")
				for region in [0,1,2,4]:
					node.region=region
					check(Data.encounter_pack(node,seed_value,"single",0,0,9)==Data.encounter_pack(node,seed_value,"single",0,0,10),"other regions unchanged")
	for id in House.SHIELDS:
		var m=noble(id,"single",["basic","basic","basic","basic"])
		var shots=fire(m,["basic","basic","basic","basic"])
		check(shots[0].blocked_hits==1 and shots[0].damage==0,"direct hit absorbed")
		check(shots[int(House.SHIELDS[id])-1].barrier==0,"ordinary hits strip entire shield")
		check(int(m.s.enemies[0].barrier)==0 and int(m.s.enemies[0].exposure_left)==House.exposure(m.s.enemies[0])-1,"visible opening survives fire tick")
		var left:int=m.s.enemies[0].exposure_left
		var start:int=m.s.enemies[0].distance
		var hp:int=m.s.enemies[0].hp
		for tick in range(left):reload_exact(m)
		check(m.s.enemies[0].barrier==House.SHIELDS[id] and m.s.enemies[0].exposure_left==0,"shield restores after public clock")
		check(m.s.enemies[0].distance==start-left-House.surge(m.s.enemies[0]),"only named leader gets telegraphed surge")
		check(m.s.enemies[0].hp==hp,"rearm never heals")
	var m=noble(House.BOSS,"single",["arc"])
	var shots=fire(m,["arc"])
	check(shots[0].barrier_removed==2 and shots[0].damage==0,"electric primary strips two")
	m=noble(House.BOSS,"single",["arc"]);m.s.equipped_parts=["breaker"]
	shots=fire(m,["arc"])
	check(shots[0].barrier_removed==3,"breaker stacks one extra hit removal")
	m=noble(House.NOBLE,"single",["precise_p3"]);m.s.enemies[0].barrier=1
	shots=fire(m,["precise_p3"])
	check(shots[0].blocked_hits==1 and shots[0].damage>0 and shots[0].exposure_left==3,"same round remaining hits reach exposed body")
	m=noble(House.BOSS,"burst",["arc","arc"])
	fire(m,["arc","arc"]);reload_exact(m)
	check(m.s.enemies[0].barrier==0 and m.s.enemies[0].exposure_left==2,"two-turn reload still leaves a boss opening")
	m=noble(House.BOSS,"single",["bore"])
	shots=fire(m,["bore"])
	check(shots[0].blocked_hits==1 and m.s.enemies[0].hp<64 and m.s.enemies[0].burn>0,"fire applies through shield and ticks HP")
	m=noble(House.BOSS,"single",["disrupt"]);House.strip(m.s.enemies[0],4);m.s.enemies[0].exposure_left=1
	fire(m,["disrupt"])
	check(m.s.enemies[0].barrier==0 and m.s.enemies[0].exposure_left==1,"disrupt delays last open action")
	m=noble();House.strip(m.s.enemies[0],4);m.s.enemies[0].exposure_left=1;m.s.enemies[0].hp=1;m.s.enemies[0].burn=1
	reload_exact(m);check(m.s.enemies[0].hp==0 and m.s.enemies[0].distance==50,"burn kill cancels rearm and surge")
	m=noble();House.strip(m.s.enemies[0],4);m.s.enemies[0].exposure_left=1;m.s.enemies[0].distance=4
	reload_exact(m);check(m.s.phase=="lost","telegraphed surge reaches player")
	# A deliberately powerful fixture proves there is no forced phase/HP gate.
	m=noble(House.BOSS,"amplifier",["charge","basic_p5"]);House.strip(m.s.enemies[0],4)
	m.s.equipped_parts=["siege_drive"];m.s.engine.levels.siege_drive=8
	fire(m,["charge","basic_p5"]);check(m.fire(),"single heavy followup fires")
	check(m.s.enemies[0].hp==0 and m.s.phase in ["reward","won"],"build can kill in one opening")
	for gun in ["single","burst","heavy","amplifier","reactor"]:
		if not Ammo.GUNS.has(gun):continue
		m=noble(House.BOSS,gun,["arc","basic_p3"]);House.strip(m.s.enemies[0],4)
		m.s.heat=Ammo.heat_limit(m.s)-1
		fire(m,["arc","basic_p3"])
		check(Model.new().restore_state(m.s),"forced heat transitions preserve noble save "+gun)
	m=noble()
	for key in ["noble_version","exposure_left","barrier_max"]:
		for value in [-1,0.5,100,"bad"]:
			var bad=m.s.duplicate(true);bad.enemies[0][key]=value
			check(not Model.new().restore_state(bad),"reject invalid shield state "+key)
	var bad=m.s.duplicate(true);bad.enemies[0].barrier=0
	check(not Model.new().restore_state(bad),"opening must have a clock")
	bad=m.s.duplicate(true);bad.enemies[0].exposure_left=3
	check(not Model.new().restore_state(bad),"closed shield cannot have exposure clock")
	var c=Campaign.new();c.start("single",731042)
	check(c.s.roster_version==Data.Residential.VERSION,"new games get current roster")
	for version in [6,7,8,9,10]:
		var saved={"campaign":c.s.duplicate(true),"combat":c.model.s.duplicate(true),"profile":c.profile.duplicate(true)};saved.campaign.roster_version=version
		var copy=Campaign.new();check(copy.restore_state(saved) and copy.s.roster_version==version,"old campaign does not migrate opposition")
		copy.s.region=3
		var boss=copy.current_nodes().filter(func(n):return n.kind=="boss")[0]
		check((boss.name=="백동 후작")== (version>=10),"map identity follows roster")
	print("NOBLE LIVE RULES COMPLETE checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
