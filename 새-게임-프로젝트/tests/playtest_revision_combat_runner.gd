extends "res://tests/ammo_expansion_rules_runner.gd"
const Readability = preload("res://redesign/readability.gd")
const PartCard = preload("res://redesign/part_card_view.gd")

func revised(order: Array, parts: Array, gun: String = "burst", armor: int = 0, hp: int = 300):
	var m=fixture(order,[["wall",hp,armor,1,40],["runner",hp,armor,1,45]],gun)
	m.s.combat_revision=1
	m.s.equipped_parts=parts.duplicate()
	return m

func saved(c) -> Dictionary:
	return {"campaign":c.s.duplicate(true),"combat":c.model.s.duplicate(true),"profile":c.profile.duplicate(true)}

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/playtest_revision_20261026/"):quit(2);return
	# Ordering and condition failures are as important as the successful combo.
	for recipe in [
		{"order":["charge","pierce","cool"],"at":1,"factor":2},
		{"order":["pierce","charge","cool"],"at":0,"factor":1},
		{"order":["pierce","cool"],"at":0,"factor":1},
		{"order":["charge","precise","cool"],"at":1,"factor":1},
		{"order":["charge","pierce","basic"],"at":1,"factor":1},
		{"order":["charge_heat","pierce","cool"],"at":1,"factor":1}
	]:
		var m=revised(recipe.order,["afterburner","sequencer"])
		var shots=fire(m,recipe.order)
		check(shots[int(recipe.at)].part_factor==recipe.factor,"afterburner requires boosted last single attack "+str(recipe.order))
		if int(recipe.factor)==2:
			check(int(shots[1].damage)==16,"boosted pierce applies tail multiplier exactly once")
			check(shots[1].part_effects.any(func(e):return e.id=="afterburner" and e.label.contains("×2")),"tail receipt exposes actual multiplier")
	# Core carryover uses the fully multiplied shot, without multiplying again.
	var siege=revised(["charge","pierce","cool"],["siege_drive","sequencer","afterburner"],"burst",0,10)
	var siege_shots=fire(siege,["charge","pierce","cool"])
	check(siege_shots[1].damage==10 and siege_shots[1].relay_damage==10,"tail overflow kills two targets without duplicate multiplier")
	# Penetration: equal-grade basic and AP separate on armor, equal on unarmored.
	for armor in [0,3,5]:
		var totals: Array=[]
		for id in ["basic_p3","pierce_p3"]:
			var m=revised([id],[],"burst",armor)
			totals.append(int(fire(m,[id])[0].damage))
		check(totals[0]==totals[1] if armor==0 else totals[1]>totals[0],"AP gains value only on armored targets %d"%armor)
	# Extra hits consume barriers, relay through the core, and cost real heat.
	var volley=revised(["charge","precise"],["volley_drive","duplex","sequencer"],"burst",0,8)
	volley.s.enemies[0].barrier=2
	var volley_shots=fire(volley,["charge","precise"])
	check(volley_shots[1].blocked_hits==2 and volley_shots[1].relay_hits>0,"extra hits break barrier and carry into next target")
	var hot=revised(["precise","cool"],["duplex"],"burst")
	hot.s.heat=Ammo.heat_limit(hot.s)-Ammo.heat_delta("precise",hot.s)
	var hot_shots=fire(hot,["precise","cool"])
	check(hot_shots.size()==1 and not hot.s.history.back().detail.forced_reload.is_empty(),"overheat stops late cooling and forces enemy turns")
	var safe=revised(["precise","cool"],["duplex"],"burst")
	safe.s.heat=Ammo.heat_limit(safe.s)-Ammo.heat_delta("precise",safe.s)
	var safe_shots=fire(safe,["cool","precise"])
	check(safe_shots.size()==2 and safe.s.turns<hot.s.turns,"cooling first avoids extra enemy turns")
	# Thermal reward depends on heat before the attack; early cooling sacrifices it.
	var thermal_damage: Array=[]
	for order in [["charge_heat","pierce","cool"],["charge_heat","cool","pierce"]]:
		var m=revised(order,["thermal_drive","sequencer"])
		m.s.heat=Ammo.hot_threshold(m.s)
		var shots=fire(m,order)
		for shot in shots:
			if shot.id=="pierce":thermal_damage.append(int(shot.damage))
	check(thermal_damage[0]>thermal_damage[1],"cooling order changes thermal payoff")
	# Exact scatter forecasts must include the new revision in their cache identity.
	for revision in [0,1,0,1]:
		var m=revised(["charge","precise"],["duplex","sequencer","volley_drive"],"scatter")
		m.s.combat_revision=revision
		for id in Ammo.loading_order(["charge","precise"]):check(m.load_round(id),"scatter legal load")
		var prediction=Forecast.analyze(m.s,true,true)
		check(m.confirm() and m.fire(),"scatter legal fire")
		for index in m.s.enemies.size():
			check(int(m.s.enemies[index].hp)>=int(prediction.enemies[index].hp_min) and int(m.s.enemies[index].hp)<=int(prediction.enemies[index].hp_max),"scatter outcome in exact predicted range")
	# The new flag survives campaign boundaries and rejects mismatched/future saves.
	for gun in Ammo.GUNS:
		var m=revised(["charge","pierce"],["siege_drive","afterburner","sequencer"],str(gun))
		for id in Ammo.loading_order(["charge","pierce"]):check(m.load_round(id),"tail across guns legal load")
		check(m.confirm(),"tail across guns confirms")
		var activated:=false
		for trigger in 3:
			if m.s.phase!="ready" or m.s.magazine.is_empty():break
			var predicted=Forecast.analyze(m.s,true,true)
			check(m.fire(),"tail across guns legal trigger")
			if gun!="scatter":check(predicted.enemies==m.s.enemies,"tail across separate triggers forecast "+str(gun))
			for shot in m.s.history.back().detail.results:
				if int(shot.get("part_factor",1))==2:activated=true
			var loaded=Model.new()
			check(loaded.restore_state(JSON.parse_string(JSON.stringify(m.s))),"tail across triggers saves "+str(gun))
			m=loaded
		check(activated,"tail activates for every weapon "+str(gun))
	var c=Campaign.new();c.start("burst",731042)
	check(c.s.combat_revision==Ammo.COMBAT_REVISION and c.model.s.combat_revision==Ammo.COMBAT_REVISION,"fresh campaign opts in")
	var copy=Campaign.new()
	check(copy.restore_state(saved(c)),"new campaign roundtrip")
	check(copy.model.s.combat_revision==Ammo.COMBAT_REVISION,"roundtrip keeps rules")
	for bad in [-1,0.5,Ammo.COMBAT_REVISION+1,"1",true]:
		var data=saved(c);data.campaign.combat_revision=bad;data.combat.combat_revision=bad
		check(not Campaign.new().restore_state(data),"invalid revision rejected "+str(bad))
	var mismatch=saved(c);mismatch.combat.erase("combat_revision")
	check(not Campaign.new().restore_state(mismatch),"campaign/combat mismatch rejected")
	var legacy=saved(c);legacy.campaign.erase("combat_revision");legacy.combat.erase("combat_revision")
	check(copy.restore_state(legacy) and not Ammo.revised_combat(copy.model.s),"missing revision stays legacy")
	# Every changed part surface uses the same state-aware description.
	for revision in [0,1]:
		for id in Ammo.REVISED_PARTS:
			var state={"combat_revision":revision,"engine":Model.Engines.fresh()}
			state.engine.levels[id]=8
			var card=PartCard.new();card.setup(id,state)
			check(card.tooltip_text.contains(str(Ammo.part_spec(id,state).text)),"card tooltip follows saved rules")
			if not Model.Engines.IDS.has(id):check(card.effect_value()==str(Ammo.part_spec(id,state).value),"card face follows saved rules")
			card.free()
	# All compressed/graded boost grants fit the save schema after sequencer.
	for id in Ammo.AMMO:
		if str(Ammo.AMMO[id].effect)!="boost":continue
		for gun in Ammo.GUNS:
			var state={"gun":gun,"weapon_version":1,"combat_revision":1,"equipped_parts":["sequencer"]}
			var granted=Model.AttackBoosts.prepare({},Ammo.effect_value(id,state),Ammo.boost_factor(id,state),Ammo.boost_rounds(id),bool(Ammo.AMMO[id].get("persistent",false)),bool(Ammo.AMMO[id].get("boost_hot",false)),int(Ammo.AMMO[id].get("boost_heat",0)))
			check(Model.AttackBoosts.valid(granted),"every revised grant saves "+str(id)+"/"+str(gun))
	print("PLAYTEST REVISION COMBAT COMPLETE checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
