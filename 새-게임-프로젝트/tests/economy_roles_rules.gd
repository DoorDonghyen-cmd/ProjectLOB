extends "res://tests/build_roles_rules.gd"
func earned(name: String):
	var c=Campaign.new()
	check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string("res://../qa_runtime/build_roles_20261103/climb_earned/"+name+".json"))),"historical earned fixture restores")
	return c
func activate(c)->void:
	c.s.economy_version=1;c.s.intro_part_bought=false;c.s.gate_bag_used=false
func resume(c)->void:
	c.normalize_for_save()
	var data: Dictionary=canonical({"campaign":c.s,"combat":c.model.s,"profile":c.profile})
	var other=Campaign.new();check(other.restore_state(data),"economy state resumes "+str(c.s.outfit)+"/"+str(c.s.phase)+"/"+str(c.s.bag_upgrades))
	check(canonical(other.s)==data.campaign and canonical(other.model.s)==data.combat,"economy and combat restore exactly")
func run()->void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/economy_roles_20261103/"):quit(2);return
	var c=earned("shop_heavy_17_r1_n503")
	check(not Campaign.Economy.enabled(c.s),"existing v3 run is not upgraded")
	var stock: Array=c.s.offers.duplicate(true)
	var previous=load("res://../qa_runtime/economy_roles_20261103/before/새-게임-프로젝트/redesign/campaign.gd").new()
	previous.s=c.s.duplicate(true);previous.model.s=c.model.s.duplicate(true)
	c._stock_shop(c.node());previous._stock_shop(previous.node())
	check(c.s.offers==previous.s.offers,"legacy stock and prices remain unchanged")
	activate(c);c.s.offers=stock.duplicate(true);Campaign.Economy.stock(c.s,c.model.s,c.s.offers)
	check(c.s.credits==30 and c.s.offers[0].price==12 and c.s.offers[1].price==18 and c.s.offers[2].price==30,"targeted support keeps initial budget and alternate price")
	resume(c)
	check(c.buy(0) and c.buy(1) and c.s.credits==0 and c.s.parts.has("coil"),"normal round plus fitting module fits actual starting wallet")
	var saved: Dictionary=canonical(c.s)
	check(not c.buy(1) and canonical(c.s)==saved,"duplicate purchase neither charges nor grants again")
	check(c.s.intro_part_bought,"discount is consumed by actual purchase")
	resume(c)
	var later: Array=stock.duplicate(true);Campaign.Economy.stock(c.s,c.model.s,later)
	check(later[1].price==30,"discount cannot repeat across rerolls or shops")
	for value in [-1,0.5,2,"1",true]:
		var data: Dictionary=canonical({"campaign":c.s,"combat":c.model.s,"profile":c.profile});data.campaign.economy_version=value
		check(not Campaign.new().restore_state(data),"invalid economy version rejected")
	for price in [17,19,30]:
		var data: Dictionary=canonical({"campaign":c.s,"combat":c.model.s,"profile":c.profile});data.campaign.offers[1].price=price
		check(not Campaign.new().restore_state(data),"discount provenance and price agree")
	for outfit in Content.OUTFITS:
		for gun in Content.GUNS:
			var fresh=Campaign.new();fresh.start(gun,17,0,"balanced",4,outfit,true)
			check(fresh.model.s.deck.size()>=fresh.minimum_deck() and fresh.model.s.deck.size()<=fresh.model.deck_limit(),"every outfit/weapon starts inside min/max")
			resume(fresh)
		var gate=earned("gate_heavy_17_r1")
		gate.s.outfit=outfit;gate.model.s.outfit=outfit;activate(gate)
		# Controlled outfit boundary, not a claim of an earned outfit swap.
		gate.model.s.deck=gate.model.s.deck.slice(0,gate.model.deck_limit());gate.normalize_for_save()
		var rounds: Array=gate.model.s.deck.duplicate();var capacity: int=gate.model.capacity();var minimum: int=gate.minimum_deck()
		check(not gate.buy_gate_bag(),"upgrade selection precedes paid reorganization")
		check(gate.gate("cadence"),"free gate upgrade remains available")
		var before: int=gate.model.deck_limit();var wallet: int=gate.s.credits
		check(gate.buy_gate_bag() and gate.model.deck_limit()==before+2 and gate.s.credits==wallet-18,"paid gate expands only capacity")
		check(gate.model.s.deck==rounds and gate.model.capacity()==capacity and gate.minimum_deck()==minimum and gate.model.s.gate_mods.cadence==1,"no free ammo, magazine/minimum/upgrade changes")
		resume(gate)
		saved=canonical(gate.s)
		check(not gate.buy_gate_bag() and canonical(gate.s)==saved,"one paid expansion per gate")
		check(gate.depart_gate() and not gate.s.gate_bag_used,"next region clears only visit lock")
		check(not gate.buy_gate_bag(),"map cannot purchase gate service")
		resume(gate)
	var poor=earned("gate_heavy_17_r1");activate(poor);poor.gate("skip");poor.s.credits=17
	saved=canonical(poor.s);check(not poor.buy_gate_bag() and canonical(poor.s)==saved,"insufficient credits reject atomically")
	var capped=earned("gate_heavy_17_r3");activate(capped);capped.gate("skip")
	for i in range(3):capped._grow_bag()
	check(not capped.buy_gate_bag() and capped.model.deck_limit()==Roles.CARRY.carrier+6,"workshop and paid gate share three upgrades")
	resume(capped)
	var legacy=earned("gate_heavy_17_r1");legacy.gate("skip")
	check(not legacy.buy_gate_bag(),"historical gate has no new paid service")
	resume(legacy)
	var copy=earned("gate_heavy_17_r1");activate(copy);copy.gate("skip")
	var main: String=Model.FocusBuild.main_round(copy.model.s)
	var count: int=copy.model.s.deck.count(main);var money: int=copy.s.credits
	check(copy.buy_gate_copy(main) and copy.model.s.deck.count(main)==count+1 and copy.s.credits==money-copy.gate_copy_price(main),"copy spends shop price and adds exact owned performance")
	check(not copy.buy_gate_copy(main) and not copy.buy_gate_bag(),"copy and expansion share one paid service")
	resume(copy)
	check(copy.depart_gate() and not copy.s.gate_ammo_used,"copy lock resets on next region")
	var full=earned("gate_heavy_17_r1");activate(full);full.gate("skip")
	while full.model.s.deck.size()<full.model.deck_limit():full.model.s.deck.append("basic_p2")
	full.normalize_for_save();saved=canonical(full.s)
	check(not full.buy_gate_copy(main) and canonical(full.s)==saved,"full carry limit rejects copy without charge")
	check(not full.buy_gate_copy("basic_p2") and not full.buy_gate_copy("not_owned"),"only owned special ammunition can be copied")
	check(not copy.can_buy_gate_copy(main),"copy not available outside gate")
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("ECONOMY ROLES COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
