extends "res://tests/leader_patterns_rules.gd"
const Skills = preload("res://redesign/boss_skills.gd")
const Ranged = preload("res://redesign/ranged.gd")

func boss(region: int = 0, gun: String = "single", rounds: Array = ["basic_p2","basic_p2","basic_p2"]):
	var m = current(rounds,[],gun)
	m.s.enemy_pattern_version = 1; m.s.boss_skills_version = 1
	var node := {"region":region,"floor":9,"id":region*10000+902,"kind":"boss","name":"검사 보스"}
	var pack: Dictionary = Campaign.Content.encounter_pack(node,17,gun,0,0,12,2)
	m.s.enemies = pack.active; m.s.reinforcements = pack.reserve
	if region == 0:
		m.s.enemies = [m.s.enemies[0]]; m.s.reinforcements = []; m.s.enemies[0].distance = 24
	else:
		for enemy in m.s.enemies + m.s.reinforcements: enemy.distance = 100
	m.s.encounter_total = m.s.enemies.size()+m.s.reinforcements.size(); m.s.deployed = m.s.enemies.size()
	Skills.prepare(m.s,node)
	restore_check(m)
	return m

func run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/boss_skills_20261106/"): quit(2); return
	var gate = boss()
	for tick in range(4): gate._advance(1,true); restore_check(gate)
	check(gate.s.enemies[0].ranged_phase == "burst" and Ranged.active(gate.s).size()==1,"first pressure shot leaves a public second-shot warning")
	check(gate.s.projectiles[0].distance==24,"first shot does not move on its birth action")
	var events: Array = gate._advance(1,true)
	check(gate.s.projectiles.size()==2 and gate.s.projectiles[0].uid!=gate.s.projectiles[1].uid,"second pressure shot preserves the first and has a stable distinct ID")
	check(gate.s.projectiles[0].distance==18 and gate.s.projectiles[1].distance==24,"two shots travel one action apart")
	check(events.any(func(e):return e.kind=="projectile_launch" and e.projectiles.size()==2),"native launch receipt retains both shots")
	restore_check(gate)
	shot(gate)
	check(Ranged.active(gate.s).size()==1 and gate.s.enemies[0].ranged_phase=="waiting","one intercept leaves the second threat and keeps the boss open")
	shot(gate)
	check(Ranged.active(gate.s).is_empty() and gate.s.enemies[0].ranged_phase=="recover" and gate.s.enemies[0].ranged_left==2,"intercepting both opens the full two-action recovery")
	gate._advance(2,true)
	check(gate.s.enemies[0].ranged_phase=="guard" and gate.s.enemies[0].salvo_left==2,"completed recovery resets one finite two-shot salvo")
	restore_check(gate)
	var dead = boss(); dead._advance(4,true); dead.s.enemies[0].hp=1; dead.s.enemies[0].burn=1
	dead._advance(1,true)
	check(dead.s.projectile_serial==1 and Ranged.active(dead.s).size()==1 and dead.s.enemies[0].hp==0,"burning down the source cancels the unlaunched shot while preserving the flying shot")
	restore_check(dead)
	var interrupted = boss(); interrupted._advance(4,true)
	interrupted.s.enemies[0].jammed=2; interrupted.s.enemies[0].disrupted=true
	interrupted._advance(2,true)
	check(interrupted.s.projectile_serial==1 and interrupted.s.enemies[0].salvo_left==1,"finite disruption delays the second shot without freezing the first")
	interrupted._advance(1,true)
	check(interrupted.s.projectile_serial==2,"second shot resumes after disruption expires")
	# A real, reachable counter: intercept first, then hit the now-nearest source
	# with disruption in the SAME firing action, before its next launch tick.
	var aligned = boss(0,"single",["basic_p2","disrupt","basic_p2"])
	aligned._advance(4,true); aligned.s.fire_heat_trial.rounds=2
	var paired: Dictionary = verify_fire(aligned)
	check(paired.results[0].intercept and paired.results[1].interrupted>0,"ordered intercept then disruption reaches the actual boss")
	check(aligned.s.projectile_serial==1 and aligned.s.enemies[0].salvo_left==1,"real two-round command delays the pending second launch")
	aligned._advance(1,true)
	check(aligned.s.projectile_serial==2,"second launch resumes after the real one-action disruption is consumed")
	var executed = boss(0,"single",["basic_p2","basic_p5","basic_p2"])
	executed._advance(4,true); executed.s.enemies[0].hp=1; executed.s.fire_heat_trial.rounds=2
	paired=verify_fire(executed)
	check(paired.results[0].intercept and executed.s.enemies[0].hp==0 and executed.s.projectile_serial==1,"ordered intercept then lethal shot cancels the actual pending second launch")
	for gun in ["single","burst","scatter","heavy","amplifier"]:
		var exact = boss(0,gun); exact._advance(5,true)
		shot(exact); check(Ranged.active(exact.s).size()==1,"every gun can intercept the leading shot "+gun)
	var old = boss(); old.s.erase("boss_skills_version")
	old.s.enemies[0].erase("salvo_total"); old.s.enemies[0].erase("salvo_left")
	old._advance(5,true)
	check(old.s.projectiles.size()==1 and old.s.projectile_serial==1,"old gatekeeper retains its single-shot cycle")
	restore_check(old)
	var malformed = boss(); malformed._advance(5,true)
	for defect in ["duplicate","serial","serial_ahead","third","unmarked"]:
		var bad: Dictionary=canonical(malformed.s)
		match defect:
			"duplicate": bad.projectiles[1].uid=bad.projectiles[0].uid
			"serial": bad.projectile_serial=1
			"serial_ahead": bad.projectile_serial=3
			"third": bad.projectiles.append(bad.projectiles[0].duplicate(true))
			"unmarked": bad.erase("boss_skills_version")
		check(not Model.new().restore_state(bad),"invalid multi-projectile save rejected "+defect)
	var mother = boss(2)
	for i in range(1,4): mother.s.enemies[i].hp=0
	var ordinary: Array=mother._deploy_reinforcements(true)
	check(ordinary.size()==1 and not ordinary[0].enemy.get("brood_reserve",false),"automatic arrival cannot spend the two reserved summons before the warning")
	check(mother.s.reinforcements.size()==2,"finite two-monster call remains visible in reserve")
	mother._advance(2,true); check(mother.s.enemies[0].summon_left==1,"two public actions leave one action before the call")
	restore_check(mother)
	mother._advance(1,true)
	var called: Array=mother._deploy_reinforcements()
	check(called.size()==2 and mother.alive_count()==4 and mother.s.reinforcements.is_empty(),"announced call fills two free front-line slots")
	check(called.all(func(d):return d.enemy.brood_reserve and d.enemy.distance==100),"called monsters do not move on arrival")
	check(mother.s.enemies[0].summon_done and mother.s.encounter_total==7,"call is finite and preserves total encounter size")
	restore_check(mother)
	mother._advance(3,true); check(mother._deploy_reinforcements().is_empty(),"caller cannot regenerate spent reinforcements")
	var full = boss(2); full._advance(3,true)
	check(full._deploy_reinforcements().is_empty() and full.alive_count()==4,"summon respects the four living actor cap")
	full.s.enemies[1].hp=0
	check(full._deploy_reinforcements().size()==1 and full.alive_count()==4,"queued summon can fill one slot while three remain alive")
	restore_check(full)
	var jam = boss(2); jam._advance(2,true); jam.s.enemies[0].jammed=2; jam.s.enemies[0].disrupted=true
	jam._advance(2,true)
	check(jam.s.enemies[0].summon_left==1,"disruption delays the public summon clock")
	jam._advance(1,true); check(jam.s.enemies[0].summon_done,"summon resumes when disruption ends")
	var orphan = boss(2); for enemy in orphan.s.enemies: enemy.hp=0
	check(orphan._deploy_reinforcements(true).size()==3,"defeated caller never strands locked reserves or prevents completion")
	restore_check(orphan)
	var predicted = boss(2); predicted.s.enemies[1].hp=0; predicted._advance(2,true)
	shot(predicted); check(predicted.s.enemies[0].summon_done,"actual firing and forecast advance the same summon")
	var fresh = Campaign.new(); fresh.start("single",17,0,"balanced",4,"carrier",true)
	check(Skills.enabled(fresh.s) and Skills.enabled(fresh.model.s),"new production campaign opts in both saved halves")
	check(fresh.save()==OK and Campaign.new().restore(),"new skill version saves and resumes")
	var mismatch: Dictionary=canonical({"campaign":fresh.s,"combat":fresh.model.s,"profile":fresh.profile})
	mismatch.campaign.erase("boss_skills_version"); check(not Campaign.new().restore_state(mismatch),"mismatched campaign/skill version rejected")
	for version in [-1,0.5,2,"1",true]:
		var bad: Dictionary=canonical(fresh.model.s); bad.boss_skills_version=version
		check(not Model.new().restore_state(bad),"malformed skill version rejected "+str(version))
	FileAccess.open(output.path_join("rules.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("BOSS SKILLS COMPLETE checks=%d failures=%d" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
