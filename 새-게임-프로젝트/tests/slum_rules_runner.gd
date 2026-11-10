extends "res://tests/challenge_rules_runner.gd"
const Slum = preload("res://redesign/slum_roster.gd")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/slum/"):quit(1);return
	var art=preload("res://redesign/slum_art.gd")
	check(not Geometry2D.is_point_in_polygon(Vector2(1012,370),art.pose("slum_thief",1).uv),"walking thief excludes neighboring attack arm")
	check(Geometry2D.is_point_in_polygon(Vector2(1012,370),art.pose("slum_thief",2).uv),"attack retains its own arm")
	check(Geometry2D.is_point_in_polygon(Vector2(1005,750),art.pose("slum_thief",1).uv),"walking crowbar remains uncut")
	var seen: Dictionary={}
	for seed_value in [17,731042,931104]:
		for depth in range(1,10):
			for kind in ["normal","elite","boss"]:
				var node: Dictionary={"region":0,"floor":depth,"id":depth*100+1,"kind":"boss" if kind=="boss" else "combat","elite":kind=="elite","name":"QA"}
				var old:=Data.encounter_pack(node,seed_value,"single",0,0,6)
				var current:=Data.encounter_pack(node,seed_value,"single",0,0,7)
				check(current.total==old.total,"first region population unchanged")
				var expected: Array=old.active+old.reserve
				var actual: Array=current.active+current.reserve
				for i in range(actual.size()):
					seen[actual[i].species]=true
					check(Slum.human(actual[i]) or actual[i].species==Challenges.BOSS,"region one only humans and mechanical gate")
					var a: Dictionary=actual[i].duplicate(true)
					var b: Dictionary=expected[i].duplicate(true)
					for key in ["name","species"]:a.erase(key);b.erase(key)
					check(a==b,"identity revision preserves exact combat state")
				for region in [1,3,4]:
					node.region=region
					check(Data.encounter_pack(node,seed_value,"single",0,0,6)==Data.encounter_pack(node,seed_value,"single",0,0,7),"unrelated region unchanged")
				node.region=2
				var garden:=Data.encounter_pack(node,seed_value,"single",0,0,7)
				check(garden==Data.encounter_pack(node,seed_value,"single",0,0,7),"garden deterministic")
				check(garden.active.size()==4 and garden.total in [6,7],"garden finite reinforcements")
				for enemy in garden.active+garden.reserve:
					check(not Slum.human(enemy) and enemy.has("species"),"garden species identified")
				if kind=="elite":check(garden.active[0].species==Challenges.ELITE and garden.active[0].max_hp==26,"garden keeps organic commander without double multiplier")
	for id in Slum.SPECIES:
		check(seen.has(Slum.SPECIES[id].id),"human role occurs in authored encounters")
	check(seen.has(Slum.LEADER) and seen.has(Challenges.BOSS),"human elite and retained gate")
	for version in [5,6,7]:
		var run=Campaign.new();run.start("single",731042,0,"balanced",3,"carrier")
		run.s.roster_version=version
		var choice: Dictionary=run.choices()[0]
		check(run.enter(choice.id),"legal first encounter")
		var saved: Dictionary={"campaign":run.s.duplicate(true),"combat":run.model.s.duplicate(true),"profile":run.profile.duplicate(true)}
		var restored=Campaign.new()
		check(restored.restore_state(saved) and restored.s.roster_version==version,"saved roster retained")
		check(restored.model.s.enemies==run.model.s.enemies,"saved identity never rewritten")
		check(Slum.human(restored.model.s.enemies[0])==(version>=7),"legacy creature/current human separation")
	# Actual enemy ticks and prediction on the human commander; no calculation fork.
	var m=challenge_model("elite",["basic_p3"],"single")
	m.s.reserve_version=1
	Slum.identify(m.s.enemies[0])
	m.s.enemies.append(Data._enemy(["runner",8,0,2,40]));Slum.identify(m.s.enemies[1])
	m.s.encounter_total=2;m.s.deployed=2;m.assign_opening_lanes()
	for tick in range(3):reload_exact(m)
	check(m.s.enemies[1].distance==32 and m.s.enemies[0].distance==22,"human command advances ally only")
	check(Ammo.enemy_rule(m.s.enemies[0]).contains("지휘"),"human command explained")
	m=fixture(["arc"],[["evader",20,0,1,40]])
	Slum.identify(m.s.enemies[0])
	check(Ammo.enemy_rule(m.s.enemies[0]).contains("축전지"),"electrical weakness belongs to equipment")
	fire(m,["arc"])
	m=fixture(["basic_p3"],[["spitter",20,0,0,40]])
	m.s.enemies[0].species="slum_gunner";m.s.enemies[0].name="압력총 사수"
	for tick in range(2):reload_exact(m)
	check(m.s.projectiles.size()==1 and m.s.projectiles[0].distance==40,"gunner launches same interceptable projectile")
	print("SLUM RULES COMPLETE checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
