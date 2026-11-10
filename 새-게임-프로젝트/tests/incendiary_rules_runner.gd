extends "res://tests/heat_rules_runner.gd"
const Readability = preload("res://redesign/readability.gd")
const Readout = preload("res://redesign/damage_readout.gd")
var evidence: Array = []

func legacy(state: Dictionary) -> Dictionary:
	var result := state.duplicate(true)
	for key in ["deck","hand","draw","discard","magazine","plan","plan_load_order","prepared"]:
		for i in range(result.get(key,[]).size()):
			result[key][i] = {"bore":"thermal","bore_c":"thermal_c","bore_f":"thermal_f"}.get(result[key][i],result[key][i])
	if not result.get("field_compression",{}).is_empty():
		result.field_compression.source = "thermal"
		result.field_compression.id = "thermal_f"
	return result

func persisted(model: RefCounted, message: String) -> void:
	check(model.save_run("user://incendiary.json") == OK, message + " saves")
	var restored = Model.new()
	check(restored.restore_run("user://incendiary.json"), message + " restores")
	var expected = JSON.parse_string(JSON.stringify(model.s))
	var actual = JSON.parse_string(JSON.stringify(restored.s))
	if actual != expected:
		for key in expected:
			if actual.get(key) != expected[key]: print("ROUNDTRIP DIFF ",key,": ",expected[key]," -> ",actual.get(key))
	check(actual == expected, message + " exact roundtrip")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/incendiary/"):
		quit(1); return
	for id in ["bore","bore_c","bore_f","thermal","thermal_c","thermal_f"]:
		check(Ammo.AMMO[id].name == "소이탄" and Ammo.AMMO[id].effect == "burn", "one incendiary identity " + id)
		check(Readability.description(id,{"gun":"single"}).contains("보호막·장갑 무시"), "live shield rule " + id)
	check(not Ammo.TACTICAL_AMMO.has("thermal") and not Ammo.COMPRESSIONS.has("thermal"), "retired family not newly acquired")
	for gun in Ammo.GUNS:
		for initial_heat in [0,Ammo.hot_threshold({"gun":gun})]:
			var m = fixture(["bore"],[["absorber",40,9,1,30]],gun)
			m.s.heat = initial_heat
			var shots := fire(m,["bore"])
			var shot: Dictionary = shots[0]
			var tick := Ammo.burn_damage(m.s)
			check(shot.damage == 0 and shot.blocked_hits == 1 and shot.burn == 3, "shield blocks impact but not burn " + gun)
			check(m.s.enemies[0].hp == 40-tick and m.s.enemies[0].barrier == 1 and m.s.enemies[0].burn == 2, "burn ignores both armor and remaining shield")
			check(m.s.heat == initial_heat+4 and m.s.turns == 1, "heat paid without threshold condition")
			check(Readout.entry(shot).number == "화상" and Readout.entry(shot).label.contains("3턴"), "blocked application visibly succeeds")
			check(m.reload_magazine(), "legal reload with burn")
			var ticks := mini(2,m.base_reload_cost())
			check(m.s.enemies[0].hp == 40-tick*(1+ticks) and m.s.enemies[0].burn == 2-ticks, "reload ticks once per enemy turn")
			check(m.s.enemies[0].barrier == 1, "burn does not spend shield")
			check(m.s.enemies[0].distance == 30-1-m.base_reload_cost(), "enemy still approaches while burning")
			persisted(m,"burning reload " + gun)
			evidence.append({"gun":gun,"initial_heat":initial_heat,"burn_tick":tick,"after_reload_hp":m.s.enemies[0].hp,"turns":m.s.turns})
	# Ordinary damage wins a close race; delayed damage is not a universal replacement.
	var burn = fixture(["bore"],[["runner",5,0,1,1]],"burst")
	fire(burn,["bore"])
	var direct = fixture(["basic_p5"],[["runner",5,0,1,1]],"burst")
	fire(direct,["basic_p5"])
	check(burn.s.phase == "lost" and direct.s.phase in ["reward","won"], "nearby enemy needs immediate damage")
	var forced = fixture(["bore","cool"],[["absorber",40,9,1,30]],"burst")
	forced.s.heat = 10
	for id in Ammo.loading_order(["bore","cool"]): check(forced.load_round(id),"plan forced preview")
	var forced_preview := Forecast.analyze(forced.s,true)
	check(Forecast.compact_summary(forced_preview).contains("피해 6(화상 6)"),"summary includes forced-reload burn, not just impact")
	check(Forecast.burn_ticks_for_shot(forced_preview,0)==3,"all forced-wait burn ticks are forecast")
	while not forced.s.plan.is_empty(): check(forced.remove_planned(0),"reset preview plan")
	fire(forced,["bore","cool"])
	check(forced.s.turns == 4 and forced.s.reloads == 1 and forced.s.heat == 0, "overheat stops later cooling and pays full reload")
	check(forced.s.enemies[0].hp == 34 and forced.s.enemies[0].burn == 0 and forced.s.enemies[0].distance == 26, "three burn ticks expire during forced wait")
	persisted(forced,"forced reload")
	var kill = fixture(["bore"],[["absorber",2,7,1,1]],"burst")
	fire(kill,["bore"])
	check(kill.s.phase in ["reward","won"] and kill.s.enemies[0].distance == 1, "burn kill happens before contact")
	var stack = fixture(["bore","bore","bore"],[["absorber",50,5,1,30]],"burst")
	var stack_shots := fire(stack,["bore","bore","bore"])
	check(stack_shots.back().burn == 6 and stack.s.enemies[0].burn == 5, "duration caps at six, one tick per volley")
	check(Ammo.burn_damage(stack.s)==2, "stacking does not multiply tick damage")
	var combo = fixture(["bore","detonate"],[["absorber",40,9,1,30]],"burst")
	var combo_shots := fire(combo,["bore","detonate"])
	check(combo_shots[1].detonation == 6 and combo.s.enemies[0].hp == 34 and combo.s.enemies[0].burn == 0, "detonation consumes remaining damage through shield")
	var spread = fixture(["bore","spread"],[["absorber",40,9,1,30],["absorber",40,9,1,34]],"burst")
	var spread_shots := fire(spread,["bore","spread"])
	check(spread_shots[1].transferred == 2 and spread.s.enemies[0].hp == 38 and spread.s.enemies[1].hp == 38, "spread transfers duration and both shielded targets tick")
	for parts in [["coil"],["inferno"],["coil","inferno"]]:
		var m = fixture(["bore"],[["wall",50,9,1,30]],"single")
		m.s.equipped_parts = parts
		var shots := fire(m,["bore"])
		check(shots[0].burn == (4 if parts==["coil"] else 5 if parts==["inferno"] else 6), "duration parts remain meaningful")
	# Mixed old/current cards in every ownership zone are conserved, in the same order.
	var mixed = fixture(["bore"])
	mixed.s.deck = ["thermal","bore","thermal_c","bore_c","thermal","bore","pierce","pierce","pierce","pierce"]
	mixed.s.hand = ["thermal","bore","thermal_c"]
	mixed.s.draw = ["thermal","bore","pierce","pierce"]
	mixed.s.discard = ["bore_c","pierce","pierce"]
	mixed.s.plan = ["thermal_c","thermal"]
	mixed.s.plan_load_order = ["thermal","thermal_c"]
	mixed.s.prepared = ["thermal"]
	var source := JSON.stringify(mixed.s)
	var migrated = Model.new()
	check(migrated.restore_state(mixed.s), "mixed legacy ownership migrates")
	check(JSON.stringify(mixed.s)==source,"migration leaves caller untouched")
	check(migrated.s.deck.count("bore")==4 and migrated.s.deck.count("bore_c")==2,"no copies lost or gained")
	check(migrated.s.plan==["bore_c","bore"] and migrated.s.plan_load_order==["bore","bore_c"] and migrated.s.prepared==["bore"],"pending order and reservation preserved")
	check(migrated.remove_planned(0) and migrated.remove_planned(0) and migrated.field_compress("bore"),"old and new copies compress together")
	persisted(migrated,"mixed compression")
	for confirmed in [false,true]:
		var m = fixture(["bore","bore","bore_c","bore_c"])
		check(m.field_compress("bore"),"setup temporary pressure")
		if confirmed: check(m.confirm(),"confirm temporary")
		var copy = Model.new()
		check(copy.restore_state(legacy(m.s)),"legacy temporary restores " + str(confirmed))
		check(copy.s.field_compression.source=="bore" and copy.s.field_compression.id=="bore_f","temporary source canonical")
		if confirmed:
			check(copy.fire(),"fire restored temporary")
			check(copy.s.discard.count("bore")==2,"temporary returns exactly two canonical copies")
		else:
			check(copy.remove_planned(0) and copy.s.hand.count("bore")==2,"cancel returns canonical copies and charge")
		persisted(copy,"temporary " + str(confirmed))
	var packed = fixture(["bore_c","bore_c","bore_c","bore_c"])
	for id in ["bore_c","bore_c","bore_c","bore_c"]: check(packed.load_round(id),"one-slot packed compressed")
	check(packed.confirm(),"packed confirmation")
	var packed_copy=Model.new()
	check(packed_copy.restore_state(legacy(packed.s)) and packed_copy.s.magazine==packed.s.magazine,"old full one-slot magazine survives migration")
	persisted(packed_copy,"packed magazine")
	# Saved shop stock keeps sold flags/prices and does not reset the loadout named thermal.
	var c=Campaign.new();c.start("burst",731042,0,"balanced",1)
	c.s.floor=3;c.s.node=301;c.s.visited=[101,201,301]
	check(c.enter(401),"legacy-map shop fixture")
	c.s.offers[0]={"id":"thermal","type":"ammo","price":12,"sold":false}
	c.s.shop_seen_ammo=["thermal","bore"]
	c.model.s.deck[0]="thermal"
	check(c.save("user://old_shop.json")==OK,"serialize old stock")
	var next=Campaign.new()
	check(next.restore("user://old_shop.json"),"campaign stock and ownership migrate together")
	check(next.s.offers[0].id=="bore" and next.s.offers[0].price==12 and next.s.shop_seen_ammo==["bore"],"stock and discovery history canonical")
	check(next.buy(0,"basic_p1") and next.model.s.deck.count("bore")==2,"migrated offer purchases normally")
	next.s.credits=100
	check(next.shop_compress("bore") and next.model.s.deck.count("bore")==0 and next.model.s.deck.count("bore_c")==1,"mixed acquired originals permanently compress as one family")
	check(next.save("user://new_shop.json")==OK and Campaign.new().restore("user://new_shop.json"),"purchased migrated stock saves")
	var invalid=next.model.s.duplicate(true);invalid.draw.append("bore")
	var guard=Model.new();guard.start("single",77)
	var intact=JSON.stringify(guard.s)
	check(not guard.restore_state(invalid) and JSON.stringify(guard.s)==intact,"invalid inventory rejected atomically")
	var helper={"loadout":"thermal","supply_offers":["thermal","bore_c"],"encounter":{"offers":["thermal_c"]}}
	Ammo.Merge.campaign(helper)
	check(helper.loadout=="thermal" and helper.supply_offers==["bore","bore_c"] and helper.encounter.offers==["bore_c"],"only ammo IDs migrate, not loadout IDs")
	for seed_value in range(30):
		for gun in Ammo.GUNS:
			for loadout in Data.LOADOUTS:
				var options: Array=Data.Acquisition.first_options(seed_value,gun,["thermal_drive"],loadout)
				check(options.size()==3 and options[0]!=options[1] and options[0]!=options[2] and options[1]!=options[2],"distinct earned choices")
				check(not options.any(func(id):return Ammo.Merge.IDS.has(id)),"no old heat round in first discovery")
		for version in [0,1,2,3]:
			var options:=Data.rewards({"id":601,"floor":6,"region":0},seed_value,["bore"],["thermal_drive"],version)
			check(not options.any(func(id):return Ammo.Merge.IDS.has(id)),"no retired reward in any save generation")
	check(not Ammo.uses_hot_effect({"deck":["bore"],"gun":"single"}),"incendiary needs no activation threshold")
	check(Ammo.uses_hot_effect({"deck":["charge_heat"],"gun":"single"}),"residual heat booster retains marker")
	check(Ammo.uses_hot_effect({"deck":["bore"],"gun":"single","equipped_parts":["thermal_drive"]}),"heat core retains marker")
	var random=fixture(["bore"],[["absorber",40,5,1,30],["absorber",40,5,1,34]],"scatter")
	random.s.equipped_parts=["coil"]
	check(random.load_round("bore"),"plan scatter incendiary")
	var random_forecast:=Forecast.analyze(random.s,true)
	var lines:=preload("res://redesign/magazine_view.gd").compact_lines(random_forecast,0)
	check(lines[0].contains("무작위") and lines[0].contains("2/턴") and lines[1].contains("4턴"),"random card names conditional burn and respects duration part")
	var file=FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("rules.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"weapons":evidence},"  "));file.close()
	print("INCENDIARY RULES COMPLETE checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
