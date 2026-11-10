extends "res://tests/weapon_magazine_rules.gd"
var examples: Array = []

func rejected(m, indices: Array, label: String) -> void:
	var before:=JSON.stringify(m.s)
	check(not m.eject_magazine_rounds(indices) and JSON.stringify(m.s)==before,"Atomic rejection: "+label)

func eject_checked(m, indices: Array) -> void:
	var before: Dictionary=m.s.duplicate(true)
	var expected: Array=[];var removed: Array=[]
	for i in range(before.magazine.size()):
		if indices.has(i): removed.append(before.magazine[i])
		else: expected.append(before.magazine[i])
	check(m.eject_magazine_rounds(indices),"Legal selective ejection")
	check(m.s.magazine==expected,"Survivors keep relative order and do not refill")
	check(m.s.discard==before.discard+removed,"Selected physical cards are spent for this fight")
	for key in before:
		if key in ["magazine","discard","history","message","magazine_ejected"]: continue
		check(m.s[key]==before[key],"Ejection preserves "+str(key))
	check(m.s.magazine_ejected==int(before.get("magazine_ejected",0))+indices.size(),"Quota counts removed cards")
	check(m.s.history.back().action=="eject" and m.s.history.back().detail.cost==0,"Ejection is recorded without acting time")
	conserved(m)
	if not m.s.magazine.is_empty(): forecast_action(m)

# A controlled order of genuinely owned cards; not presented as a naturally
# drawn checkpoint. Other available cards keep their existing order.
func arranged() -> RefCounted:
	var m=weapon("single","breach")
	var pool: Array=m.s.magazine+m.s.draw+m.s.hand
	var chosen: Array=["charge","basic_p1","pierce_p2","basic_p2"]
	for id in chosen: check(pool.has(id),"Example owns "+id);pool.erase(id)
	m.s.magazine=chosen;m.s.hand=[];m.s.draw=pool
	return m

func focused() -> void:
	var m=arranged()
	var original:=Forecast.analyze(m.s,true)
	eject_checked(m,[1])
	var after:=Forecast.analyze(m.s,true)
	check(after.shots.size()==2 and after.shots[0].id=="charge" and after.shots[1].id=="pierce_p2","Removing middle basic joins boost and piercing round")
	check(after.shots[1].damage>original.shots[1].damage,"The supported piercing shot changes actual damage")
	var front=arranged();front.eject_magazine_rounds([0])
	var front_prediction:=Forecast.analyze(front.s,true)
	check(front_prediction.shots[0].id=="basic_p1","Front removal sacrifices boost")
	examples.append({"kind":"controlled_owned_order","before":original.shots,"middle_removed":after.shots,"front_removed":front_prediction.shots,"winning_path":Solver.solve(m.s)})
	var before_shots: int=m.s.shots;m.fire()
	check(m.s.shots>before_shots and m.ejection_remaining()==1,"Firing does not reset quota")
	if m.s.phase=="ready" and m.s.heat>0:
		var used: int=m.s.magazine_ejected;m.cool_magazine()
		check(m.s.magazine_ejected==used,"Cooling does not reset quota")
	# Near-contact, active burn/projectiles and existing combos do not advance.
	m=weapon("heavy","boss");m.fire()
	if m.s.phase=="ready":
		for enemy in m.s.enemies:
			if enemy.hp>0 and enemy.speed>0:enemy.distance=1
		eject_checked(m,[1])
	m=weapon("amplifier","breach");m.fire()
	check(not m.s.buff.is_empty(),"Real boost is pending before removal")
	eject_checked(m,[1]);check(not m.s.buff.is_empty(),"Ejection does not consume pending Spike boost")
	for indices in [[],[0,0],[1,1.0],[-1],[99],[0,1,2],[true],["1"],[1.5]]:
		rejected(weapon("single","boss"),indices,str(indices))
	m=weapon("single","boss");eject_checked(m,[1]);rejected(m,[0,1],"Remaining one allowance")
	eject_checked(m,[0]);rejected(m,[0],"Spent allowance")
	var turns: int=m.s.turns
	check(m.reload_magazine(),"Full replacement remains available")
	check(m.s.turns>turns and m.s.phase=="ready" and m.ejection_remaining()==2,"Paid replacement alone renews allowance")
	var snapshot:=JSON.stringify(m.s);check(not m.trial_load_magazine() and JSON.stringify(m.s)==snapshot,"Cannot renew allowance by re-loading a ready magazine")
	# Zero allowance, one allowance and legacy saves all restore safely.
	for quota in [0,1,2]:
		m=weapon("single","boss")
		if quota>0:m.eject_magazine_rounds([0] if quota==1 else [0,2])
		conserved(m)
		var restored=Model.new();check(restored.restore_state(normalized(m.s)) and restored.ejection_remaining()==2-quota,"JSON quota survives resume")
	for bad in [true,-1,3,0.5,"1",null]:
		m=weapon("single","boss");m.s.magazine_ejected=bad
		check(not Model.new().restore_state(m.s),"Invalid quota rejected")
	m=weapon("single","boss");m.s.erase("magazine_ejected")
	var restored=Model.new();check(restored.restore_state(normalized(m.s)) and restored.ejection_remaining()==2,"Earlier weapon comparison save starts with unused allowance")
	m=weapon("single","boss");m.s.erase("weapon_magazine_version");m.s.erase("magazine_ejected");rejected(m,[0],"Original Rivet comparison unchanged")
	for phase in ["plan","reward","won","lost"]:
		m=weapon("single","boss");m.s.phase=phase;rejected(m,[0],"Not ready: "+phase)
	# Anchor and multi-slot cards cost one removal each; no automatic repair/fill.
	m=weapon("single","breach")
	m.s.deck=["shatter_c","basic_p1","basic_p1","detonate_c"]
	m.s.magazine=m.s.deck.duplicate();m.s.hand=[];m.s.draw=[];m.s.discard=[]
	for i in range(6):m.s.deck.append("basic_p1");m.s.draw.append("basic_p1")
	eject_checked(m,[1]);check(m.s.magazine.front()=="shatter_c" and m.s.magazine.back()=="detonate_c","Anchors retained after middle removal")
	eject_checked(m,[0]);check(m.ejection_remaining()==0,"Multi-slot compressed card uses one removal")
	# Removing the last loaded attacks permits emergency supply, never generates it.
	m=weapon("single","boss");m.s.magazine=["basic_p2"];m.s.draw=[];m.s.hand=[];m.s.discard=m.s.deck.duplicate();m.s.discard.erase("basic_p2")
	eject_checked(m,[0]);check(m.s.magazine.is_empty() and m.can_emergency_resupply() and int(m.s.emergency_uses)==0,"Empty ejected magazine requires explicit emergency action")
	check(m.emergency_resupply() and m.s.phase=="ready" and m.ejection_remaining()==2,"Paid emergency magazine renews allowance")
	# Spending the final card also follows the older finite-reserve exhaustion rule.
	m=weapon("single","boss");m.s.emergency_version=0;m.s.magazine=["basic_p2"];m.s.draw=[];m.s.hand=[];m.s.discard=m.s.deck.duplicate();m.s.discard.erase("basic_p2")
	turns=m.s.turns;check(m.eject_magazine_rounds([0]) and m.s.phase=="lost" and m.s.loss_reason=="ammo" and m.s.turns==turns,"Terminal exhaustion without enemy action")
	m=arranged();var owned: Array=m.s.deck.duplicate();m.eject_magazine_rounds([1,2]);m.begin_encounter();m.trial_load_magazine()
	var available: Array=m.s.magazine+m.s.hand+m.s.draw;available.sort();owned.sort()
	check(m.s.discard.is_empty() and available==owned and m.ejection_remaining()==2,"Next encounter restores spent cards from unchanged owned deck")

func run() -> void:
	var out:=OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/magazine_ejection_20261031/"):quit(2);return
	focused()
	for gun in GUNS:
		for role in ROLES:
			for seed_value in [0,17]:
				var m=weapon(gun,role,seed_value)
				eject_checked(m,[m.s.magazine.size()-1,1])
				if gun=="scatter":random_distribution(m)
				if m.s.phase=="ready":m.fire();conserved(m);check(m.ejection_remaining()==0,"Shot cannot replenish allowance")
	FileAccess.open(out.path_join("rules.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"examples":examples},"  "))
	print("EJECTION RULES COMPLETE checks=%d failures=%d" % [checks,failures.size()]);quit(0 if failures.is_empty() else 1)
