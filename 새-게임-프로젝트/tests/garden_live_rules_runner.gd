extends "res://tests/foundry_live_rules_runner.gd"
const Hunters=preload("res://redesign/garden_hunters.gd")

func hunter(id: String=Hunters.BOSS,gun: String="single",ammo: Array=["basic_p3"]):
	return fixture(ammo,[Hunters.leader(id)],gun)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/garden_live/"):quit(1);return
	var art=preload("res://redesign/garden_art.gd")
	check(same_registration(art.data(),JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/garden_leaders_20261024/registration.json")).species),"runtime atlas matches measurement")
	for texture in art.TEXTURES.values():check(texture is Texture2D,"authored texture imported")
	for seed_value in [17,731042,931104]:
		for kind in ["normal","elite","boss"]:
			var node={"id":20601,"region":2,"floor":6,"kind":"boss" if kind=="boss" else "combat","elite":kind=="elite","name":"QA"}
			var pack=Data.encounter_pack(node,seed_value,"single",0,0,9)
			if kind=="normal":check(pack==Data.encounter_pack(node,seed_value,"single",0,0,8),"ordinary garden preserved")
			else:
				check(pack.total==(7 if kind=="boss" else 6) and pack.active.size()==4,"finite pack with reserves")
				check(Hunters.active(pack.active[0]) and (pack.active+pack.reserve).filter(Hunters.active).size()==1,"one authored leader")
				check(pack.active[0].def==0 and pack.active[0].get("charge_max",0)==0,"no stacked armor or old surge clock")
			for gun in Ammo.GUNS:check(pack==Data.encounter_pack(node,seed_value,gun,0,0,9),"same seeded opposition for all guns")
			check(not Data.encounter_pack(node,seed_value,"single",0,0,8).active.any(Hunters.active),"legacy garden pack preserved")
			for region in [0,1,3,4]:
				node.region=region
				check(Data.encounter_pack(node,seed_value,"single",0,0,8)==Data.encounter_pack(node,seed_value,"single",0,0,9),"other regions unchanged")
	for id in [Hunters.ELITE,Hunters.BOSS]:
		var m=hunter(id)
		var start: int=m.s.enemies[0].distance
		m.s.enemies.append(Data._enemy(["runner",10,0,2,50]));m.s.encounter_total=2;m.s.deployed=2;m.assign_opening_lanes()
		var spent:=0
		for tick in range(9):
			if tick%3==1:spent+=6 if id==Hunters.ELITE else 7
			reload_exact(m)
			check(m.s.enemies[0].distance==start-spent,"prepare leap recover positions")
			check(m.s.enemies[1].distance==50-(tick+1)*2,"escorts advance independently")
			check(m.s.enemies[0].recovering==(tick%3==1),"recovery persists until next action")
			check(m.last_reload_detail.advance_events.any(func(e):return e.kind=="garden_state"),"presentation receives actual state event")
	var m=hunter(Hunters.BOSS,"burst")
	reload_exact(m)
	check(m.s.enemies[0].distance==37 and m.s.enemies[0].recovering,"two-turn reload resolves windup then leap")
	reload_exact(m)
	check(m.s.enemies[0].distance==37 and m.s.enemies[0].leap_left==1,"next reload covers recovery then preparation")
	m=hunter(Hunters.BOSS,"single",["disrupt"]);m.s.enemies[0].leap_left=1
	fire(m,["disrupt"])
	check(m.s.enemies[0].leap_left==1 and m.s.enemies[0].distance==44,"disrupt delays imminent leap")
	m=hunter();m.s.enemies[0].leap_left=1;m.s.enemies[0].hp=1;m.s.enemies[0].burn=1
	reload_exact(m)
	check(m.s.enemies[0].hp==0 and m.s.enemies[0].distance==44,"burn kill cancels leap")
	m=hunter();m.s.enemies[0].leap_left=1;m.s.enemies[0].distance=7
	reload_exact(m);check(m.s.phase=="lost","contact remains lethal")
	for gun in ["single","burst","heavy","amplifier"]:
		m=hunter(Hunters.BOSS,gun,["pierce_p3","bore"]);m.s.heat=Ammo.heat_limit(m.s)-1
		fire(m,["pierce_p3","bore"])
		check(m.s.reloads==1,"overheat forced reload consumes enemy actions")
	m=hunter()
	for key in ["garden_version","leap_left","leap_distance"]:
		for value in [-1,0.5,100,"bad"]:
			var bad=m.s.duplicate(true);bad.enemies[0][key]=value
			check(not Model.new().restore_state(bad),"reject invalid leap state "+key)
	var bad=m.s.duplicate(true);bad.enemies[0].recovering=true;bad.enemies[0].leap_left=1
	check(not Model.new().restore_state(bad),"reject incomplete preparation while resting")
	var c=Campaign.new();c.start("single",731042)
	check(c.s.roster_version==Data.Residential.VERSION,"new game uses current roster")
	for version in [6,7,8,9]:
		var saved={"campaign":c.s.duplicate(true),"combat":c.model.s.duplicate(true),"profile":c.profile.duplicate(true)};saved.campaign.roster_version=version
		var restored=Campaign.new();check(restored.restore_state(saved) and restored.s.roster_version==version,"saved roster preserved")
		c.s.region=2;c.s.roster_version=version
		var old_name=Data.nodes(2,731042,int(c.s.map_version)).filter(func(n):return n.kind=="boss")[0].name
		check(c.current_nodes().filter(func(n):return n.kind=="boss")[0].name==("수로의 어미" if version==9 else old_name),"map boss identity follows saved roster")
		c.s.region=0
	print("GARDEN LIVE RULES COMPLETE checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
