extends "res://tests/challenge_rules_runner.gd"
const Workers = preload("res://redesign/foundry_workers.gd")

func machine(id: String = Workers.BOSS, gun: String = "single", ammo: Array = ["basic_p3"]):
	return fixture(ammo,[Workers.leader(id,56,40)],gun)

func same_registration(a: Variant, b: Variant) -> bool:
	# GDScript constants retain integer coordinates; JSON reads numeric fields as floats.
	if (a is int or a is float) and (b is int or b is float):return absf(float(a)-float(b))<0.000000001
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for key in a:
			if not b.has(key) or not same_registration(a[key],b[key]):return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for i in range(a.size()):
			if not same_registration(a[i],b[i]):return false
		return true
	return a==b

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/foundry_live/"): quit(1);return
	var art=preload("res://redesign/foundry_art.gd")
	var measured: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/foundry_motion_20261023/registration.json")).species
	check(same_registration(art.data(),measured),"export-safe registry matches preserved measurement")
	for texture in art.TEXTURES.values():check(texture is Texture2D,"explicit imported runtime texture")
	for seed_value in [17,731042,931104]:
		for floor_value in range(1,10):
			for kind in ["normal","elite","boss"]:
				var node := {"id":10000+floor_value*100+1,"region":1,"floor":floor_value,"kind":"boss" if kind=="boss" else "combat","elite":kind=="elite","name":"QA"}
				var pack := Data.encounter_pack(node,seed_value,"single",0,0,8)
				check(pack.total==(8 if kind=="boss" else 7 if kind=="elite" else 6+mini(2,(floor_value-1)/3)),"finite population")
				check(pack.active.size()==4 and (pack.active+pack.reserve).all(Workers.active),"all slots have authored machines")
				check((pack.active+pack.reserve).filter(func(e):return e.kind=="spitter").size()==1,"one ranged source, no simultaneous barrage")
				check((pack.active+pack.reserve).all(func(e):return e.def<=2 and e.speed<=2 and not e.get("stance",false) and e.get("barrier",0)==0 and e.get("charge_max",0)==0),"high HP without stacked armor or command clocks")
				for gun in Ammo.GUNS: check(pack==Data.encounter_pack(node,seed_value,gun,0,0,8),"seed stable and independent of gun")
				check(not Data.encounter_pack(node,seed_value,"single",0,0,7).active.any(Workers.active),"old roster retains old encounters")
				for region in [0,2,3,4]:
					node.region=region
					check(Data.encounter_pack(node,seed_value,"single",0,0,7)==Data.encounter_pack(node,seed_value,"single",0,0,8),"other regions preserved")
	for id in [Workers.ELITE,Workers.BOSS]:
		var m=machine(id)
		m.s.enemies.append(Data._enemy(Workers.worker("labor_effigy",20,50)))
		m.s.encounter_total=2;m.s.deployed=2;m.assign_opening_lanes()
		var spent:=0
		for tick in range(8):
			var step:=0 if tick%4==3 else (4 if id==Workers.ELITE else 5) if tick%4==2 else 1
			spent+=step
			reload_exact(m)
			check(m.s.enemies[0].distance==40-spent,"winding/release/rest exact position")
			check(m.s.enemies[1].distance==50-tick-1,"escorts never receive source surge")
			check(bool(m.s.enemies[0].recovering)==(tick%4==2),"recovery visible for the next decision")
			check(not m.last_reload_detail.advance_events.any(func(e):return e.kind=="pull"),"no hidden pull event")
			check(m.s.enemies[0].hp==56,"rest never heals HP")
	var m=machine(Workers.BOSS,"burst")
	reload_exact(m)
	check(m.s.enemies[0].windup==2 and m.s.enemies[0].distance==38,"two-turn reload reaches imminent surge")
	reload_exact(m)
	check(m.s.enemies[0].distance==33 and not m.s.enemies[0].recovering,"two-turn reload resolves surge then rest")
	m=machine(Workers.BOSS,"single",["disrupt"])
	m.s.enemies[0].windup=2
	fire(m,["disrupt"])
	check(m.s.enemies[0].windup==2 and m.s.enemies[0].distance==39,"interrupt delays surge, ordinary approach remains")
	m=machine();m.s.enemies[0].windup=2;m.s.enemies[0].hp=1;m.s.enemies[0].burn=1
	reload_exact(m)
	check(m.s.enemies[0].hp==0 and m.s.enemies[0].distance==40,"burn kill cancels impending movement")
	m=machine();m.s.enemies[0].windup=2;m.s.enemies[0].distance=5
	reload_exact(m);check(m.s.phase=="lost","surge can reach contact defeat")
	for gun in ["single","burst","heavy","amplifier"]:
		m=machine(Workers.BOSS,gun,["pierce_p3","bore"])
		m.s.enemies[0].windup=1;m.s.heat=Ammo.heat_limit(m.s)-1
		fire(m,["pierce_p3","bore"])
		check(m.s.reloads==1,"forced cooling consumes actual enemy clocks")
	m=machine()
	for key in ["windup","windup_max","surge","foundry_version"]:
		for value in [-1,0.5,100,"bad"]:
			var bad:Dictionary=m.s.duplicate(true);bad.enemies[0][key]=value
			check(not Model.new().restore_state(bad),"reject invalid machine state "+key)
	var bad:Dictionary=m.s.duplicate(true);bad.enemies[0].recovering=true;bad.enemies[0].windup=1
	check(not Model.new().restore_state(bad),"recovery cannot contain unfinished charge")
	m=fixture(["basic_p3"],[Workers.worker("pressure_worker",10,24)])
	reload_exact(m);reload_exact(m)
	check(m.s.projectiles.size()==1 and m.s.projectiles[0].distance==24,"real pressure shot birth tick")
	fire(m,["basic_p3"])
	check(Ranged.active(m.s).is_empty(),"ordinary round intercepts pressure shot")
	var c=Campaign.new();c.start("single",731042)
	check(c.s.roster_version==Data.Residential.VERSION,"new campaign gets current roster")
	for version in [6,7,8]:
		var saved={"campaign":c.s.duplicate(true),"combat":c.model.s.duplicate(true),"profile":c.profile.duplicate(true)}
		saved.campaign.roster_version=version
		var restored=Campaign.new()
		check(restored.restore_state(saved) and restored.s.roster_version==version,"saved roster version is preserved")
	print("FOUNDRY LIVE RULES COMPLETE checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
