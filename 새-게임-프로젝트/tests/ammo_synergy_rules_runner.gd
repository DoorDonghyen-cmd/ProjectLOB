extends "res://tests/heat_rules_runner.gd"
const Synergy = preload("res://redesign/ammo_synergy.gd")

func hint(ids: Array, plan: Array, rows: Array = [], gun: String = "single", heat: int = 0) -> Dictionary:
	var m = fixture(ids,rows,gun)
	m.s.heat = heat
	for id in Ammo.loading_order(plan): check(m.load_round(id),"legal hint setup")
	var before := JSON.stringify(m.s)
	var result := Synergy.hand_hints(m.s)
	check(before == JSON.stringify(m.s),"hints preserve inventory, state and RNG")
	return result

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/ammo_synergy/"): quit(1); return
	var rows := [["wall",100,0,1,30]]
	var h := hint(["charge","precise","pierce"],["precise"],rows)
	check(h.has("charge") and not h.charge.move and h.charge.label == "2회 강화 적용", "load support last to fire first")
	h = hint(["charge","precise","pierce"],["charge"],rows)
	check(h.has("precise") and h.precise.move and h.has("pierce") and h.pierce.move,"one support offers two branches with explicit reorder")
	check(not hint(["charge","charge","basic"],["charge"],rows).has("charge"),"replacement is not advertised as a synergy")
	check(not hint(["shatter","precise"],["precise"],rows).has("shatter"),"no armor means no armor synergy")
	check(hint(["shatter","precise"],["precise"],[["wall",100,3,1,30]]).has("shatter"),"armor opener witnessed on actual target")
	check(not hint(["charge_heat","precise"],["charge_heat"],rows).has("precise"),"cold conditional boost not recommended")
	check(hint(["charge_heat","precise"],["charge_heat"],rows,"single",5).has("precise"),"hot conditional boost found")
	check(not hint(["cool","charge_hot"],["charge_hot"],rows).has("cool"),"empty-heat cooling not suggested")
	check(not hint(["bore","detonate"],["bore"],[["runner",1,0,1,30],["runner",30,0,1,34]]).has("detonate"),"dead burning target does not promise detonation on the next target")
	check(not hint(["charge_hot","precise","basic"],["charge_hot","precise"],rows).has("basic"),"no false link after an overheating stop")
	check(hint(["charge","precise"],["precise"],rows,"amplifier").charge.later_action,"amplifier marks the extra firing action")
	h = hint(["charge","precise"],["precise"],rows,"scatter")
	check(h.charge.conditional and not h.charge.has("damage"),"scatter shows a conditional candidate, never a secret seeded result")
	# The core branches already arise from per-hit damage and armor, without pair bonuses.
	var comparisons: Array = []
	for armor in [0,6]:
		var totals: Array = []
		for attack in ["precise","pierce"]:
			var m = fixture(["charge",attack],[["wall",100,armor,1,30]])
			fire(m,["charge",attack])
			totals.append(100-int(m.s.enemies[0].hp))
		comparisons.append(totals)
	check(comparisons == [[12,6],[2,3]],"armor changes the better boost recipient")
	print("BOOST BRANCHES armor0/6 ",comparisons)
	var m = fixture(["bore","push"],[["runner",6,0,2,2]],"heavy")
	fire(m,["bore","push"])
	check(m.s.phase == "ready" and m.reload_magazine() and m.s.phase in ["won","reward"],"burn/push buys time for a later burn kill")
	m = fixture(["bore","basic"],[["runner",6,0,2,2]],"heavy")
	fire(m,["bore","basic"])
	check(m.s.phase == "lost","immediate extra damage cannot replace distance at contact")
	# Each advertised deterministic pair has an actual resolved witness.
	for pair in [["bore","detonate"],["bore","spread"],["bore","push"],["bore","disrupt"],["prepare","charge"],["arc","sequence"],["charge_hot","vent"]]:
		m = fixture(pair,[["spitter",100,0,0,30],["runner",100,0,1,34]])
		var link := Synergy.evaluate(m.s,pair,0)
		check(not link.is_empty(),"actual relationship "+str(pair))
	m = fixture(["basic","chase"],[["runner",3,0,1,30],["runner",40,0,1,34]])
	check(not Synergy.evaluate(m.s,["basic","chase"],0).is_empty(),"kill transfers payoff to next target")
	# Anchors, full magazines and missing copies must not be offered.
	check(hint(["precise_c","charge"],["precise_c"],rows).is_empty(),"first-anchor insertion remains blocked")
	check(not hint(["charge_c","basic"],["basic"],rows).has("charge_c"),"last-anchor requires empty rail")
	m = fixture(["charge","precise","pierce","basic","cool"],rows)
	for id in Ammo.loading_order(["charge","precise","pierce","basic"]): m.load_round(id)
	check(Synergy.hand_hints(m.s).is_empty(),"full rail has no insertable candidates")
	# New-run experiment uses an existing six-card outfit; saves are not reconfigured.
	var campaign = Campaign.new()
	campaign.start("single",731042,0,"balanced",2,"carrier")
	check(Ammo.hand_capacity(campaign.s) == 6 and Ammo.capacity({"gun":"single"}) == 4,"six choices and four slots")
	m = fixture(["basic"],rows)
	m.s.outfit = "scout"
	m.s.bag_version = Ammo.BAG_VERSION
	var restored = Model.new()
	check(restored.restore_state(JSON.parse_string(JSON.stringify(m.s))) and Ammo.hand_capacity(restored.s)==4,"existing scout save retains four-card capacity")
	# Every normal tactical family has several real partners across public situations.
	var coverage := {}
	for id in Ammo.TACTICAL_AMMO:
		var partners: Array = []
		for other in ["basic"] + Ammo.TACTICAL_AMMO:
			if other == id: continue
			for order in [[id,other],[other,id]]:
				m = fixture(order,[["spitter",100,3,0,30],["runner",100,0,1,34]])
				m.s.heat = 5
				if not Synergy.evaluate(m.s,order,0).is_empty() and not partners.has(other): partners.append(other)
		coverage[id] = partners
		check(partners.size() >= 2,"at least two contextual partners for "+id)
	m = fixture(["charge","precise","pierce","bore","push","cool"],rows)
	var started := Time.get_ticks_usec()
	var original := JSON.stringify(m.s)
	var pairs := Synergy.hand_pairs(m.s)
	check(pairs.size() >= 3 and JSON.stringify(m.s)==original,"empty-plan guide has verified alternatives and stays read-only")
	print("SIX CARD GUIDE USEC ",Time.get_ticks_usec()-started)
	var report := {"partners":coverage,"boost_damage":comparisons}
	FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("branches.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("AMMO SYNERGY RULES COMPLETE checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
