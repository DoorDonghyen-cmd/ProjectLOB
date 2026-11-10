extends "res://tests/challenge_rules_runner.gd"
const Foundry = preload("res://redesign/foundry_roster.gd")

func foundry_model(kind: String, ids: Array, gun: String = "single"):
	var node := {"region":1,"kind":"boss" if kind=="boss" else "combat","elite":kind=="elite","floor":6}
	var rows := Foundry.rows(node,Data.rng(731042,11),[])
	var model=fixture(ids,rows.slice(0,1),gun)
	model.s.reserve_version=1
	return model

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/foundry/"):quit(1);return
	for seed_value in [17,731042,931104]:
		for depth in range(1,10):
			for kind in ["normal","elite","boss"]:
				var node := {"region":1,"floor":depth,"id":10000+depth*100+1,"kind":"boss" if kind=="boss" else "combat","elite":kind=="elite","name":"QA"}
				var expected := 8 if kind=="boss" else 7 if kind=="elite" else 6+mini(2,(depth-1)/3)
				var first := Data.encounter_pack(node,seed_value,"single",0,0,6)
				check(first.total==expected and first.active.size()==4,"phased finite population")
				check(first==Data.encounter_pack(node,seed_value,"single",0,0,6),"seed repeatable")
				for gun in Ammo.GUNS:
					check(first==Data.encounter_pack(node,seed_value,gun,0,0,6),"formation independent of selected gun")
				for enemy in first.active+first.reserve:
					check(int(enemy.distance)>=18 and int(enemy.distance)<=29,"normal difficulty reaction window")
				check(first.reserve.all(func(e):return int(e.lane)==-1),"reserves have no active lane")
				if kind!="normal":
					check(first.active[0].rank==kind,"rank is authored without extra elite HP multiplier")
					check(first.active[0].hp==(48 if kind=="boss" else 26),"explicit challenge HP")
					check(Foundry.named(first.active[0]),"named foundry challenge")
				for region in [0,2,3,4]:
					node.region=region
					check(Data.encounter_pack(node,seed_value,"single",0,0,5)==Data.encounter_pack(node,seed_value,"single",0,0,6),"other regions preserved")
	var run=Campaign.new()
	run.start("single",731042,0,"balanced",3,"carrier")
	check(run.s.roster_version==Data.Residential.VERSION,"new run opts into current roster")
	var saved={"campaign":run.s.duplicate(true),"combat":run.model.s.duplicate(true),"profile":run.profile.duplicate(true)}
	saved.campaign.roster_version=5
	var old=Campaign.new()
	check(old.restore_state(saved) and old.s.roster_version==5,"old run retains earlier formation")
	# Real enemy turns: armor flips each tick, including both ticks of a burst reload.
	var m=foundry_model("boss",["basic_p3"])
	m.s.enemies.append(Data._enemy(["runner",10,0,2,40]))
	m.s.encounter_total=2;m.s.deployed=2;m.assign_opening_lanes()
	for tick in range(1,4):
		reload_exact(m)
		check(m.s.enemies[0].def==(0 if tick%2==1 else 6),"boss armor public after each turn")
	check(m.s.enemies[1].distance==31 and m.s.enemies[0].distance==35,"third tick moves escorts extra 3m, never itself")
	check(m.s.enemies[0].charge==0,"boss clock resets")
	m=foundry_model("boss",["basic_p3"],"burst")
	reload_exact(m)
	check(m.s.enemies[0].def==6 and m.s.enemies[0].charge==2,"two-turn reload closes plate and advances clock twice")
	m=foundry_model("boss",["shatter"])
	fire(m,["shatter"])
	check(m.s.enemies[0].stance_def==3,"shatter permanently lowers boss plate")
	reload_exact(m)
	check(m.s.enemies[0].def==3,"reclosing does not restore destroyed armor")
	m=foundry_model("boss",["disrupt"])
	fire(m,["disrupt"])
	check(m.s.enemies[0].charge==0 and m.s.enemies[0].def==0,"interruption freezes support, not armor clock")
	# Different tools have distinct value against closed armor; open armor is an alternative.
	var damage: Dictionary={}
	for id in ["basic_p3","pierce_p3"]:
		m=foundry_model("elite",[id])
		damage[id]=int(fire(m,[id])[0].damage)
	check(damage.pierce_p3>damage.basic_p3,"piercing saves ammunition against plate")
	m=foundry_model("elite",["basic_p3"])
	reload_exact(m)
	check(int(fire(m,["basic_p3"])[0].damage)>int(damage.basic_p3),"waiting for opening makes basic round stronger")
	m=foundry_model("boss",["bore"],"heavy")
	fire(m,["bore"])
	check(m.s.enemies[0].burn>0 and m.s.enemies[0].hp<48,"incendiary ticks through closed armor")
	# Near the heat threshold, forced cooling must retain exact charge and armor changes.
	for gun in ["single","burst","heavy","amplifier"]:
		m=foundry_model("boss",["pierce_p3","bore"],gun)
		m.s.heat=Ammo.heat_limit(m.s)-1
		fire(m,["pierce_p3","bore"])
		check(m.s.reloads==1 and m.s.phase=="plan","overheat imposes forced cooling")
	var icon=preload("res://redesign/enemy_status_icons.gd").entries(Data._enemy(["caster",8,0,1,30]))
	check(icon[0].text.contains("2m") and icon[0].value=="3턴","support clock gives concrete effect and remaining time")
	print("FOUNDRY RULES COMPLETE checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
