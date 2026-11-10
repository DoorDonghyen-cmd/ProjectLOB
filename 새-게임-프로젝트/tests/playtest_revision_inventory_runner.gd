extends "res://tests/reactor_rules_runner.gd"
## Transactions use production commands. Location fixtures are synthetic routes;
## fresh earned routes are tested separately by central_live_balance_runner.

func roundtrip(c) -> void:
	check(c.save("user://inventory.json")==OK,"atomic save")
	var copy=Campaign.new()
	check(copy.restore("user://inventory.json"),"whole campaign restores")
	check(JSON.stringify(copy.s)==JSON.stringify(JSON.parse_string(JSON.stringify(c.s))),"campaign exact persistence")
	check(JSON.parse_string(JSON.stringify(copy.model.s))==JSON.parse_string(JSON.stringify(c.model.s)),"combat exact persistence")

func location(kind: String, seed_value: int = 731042, region: int = 0):
	var c=Campaign.new();c.start("heavy",seed_value,0,"balanced",3,"carrier")
	c.s.region=region;c.s.departure_step=3;c.s.credits=100
	var nodes:Array=c.current_nodes()
	var target:Dictionary=nodes.filter(func(n):return n.get("workshop",false) if kind=="workshop" else n.kind==kind and not n.get("workshop",false))[0]
	var parent:Dictionary=nodes.filter(func(n):return n.next.has(target.id))[0]
	c.s.node=parent.id;c.s.floor=parent.floor;c.s.visited=[]
	for r in range(region+1):
		var rooms:Array=Data.nodes(r,seed_value,3)
		var end:Dictionary=parent if r==region else rooms.filter(func(n):return n.kind=="boss")[0]
		var path:Array=[end.id]
		while int(end.floor)>1:
			end=rooms.filter(func(n):return n.next.has(end.id))[0];path.push_front(end.id)
		c.s.visited.append_array(path)
	check(c.enter(target.id),"legal service entry "+kind)
	return c

func stable(c) -> String:
	return JSON.stringify([c.s,c.model.s,c.profile])

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/playtest_revision_20261026/"):quit(2);return
	var capacities={"scout":28,"work":30,"carrier":32,"heatworker":34,"hoist":36,"recovery":38,"expedition":40}
	for gun in Ammo.GUNS:
		for outfit in capacities:
			var c=Campaign.new();c.start(gun,731042,0,"balanced",3,outfit)
			check(c.model.deck_limit()==capacities[outfit] and c.model.s.deck.size()==20,"outfit carry cap without free ammunition")
			check(c.model.s.hand.size()==Ammo.OUTFITS[outfit].hand,"hand independent of total inventory")
			check(c.model.capacity()==Ammo.weapon_spec(c.model.s).capacity,"outfit does not enlarge magazine")
			while c.model.s.deck.size()<capacities[outfit]: c.model.s.deck.append("bore")
			check(not c.can_acquire_ammo("arc") and c.can_acquire_ammo("arc","bore"),"full bag permits replacement only")
			roundtrip(c)
			var oversized=c.model.s.duplicate(true);oversized.deck.append("bore");oversized.draw.append("bore")
			check(not Model.new().restore_state(oversized),"oversized save rejected")
			# Removing the new marker retains the old 32-card policy for every outfit.
			c.s.erase("inventory_version");c.model.s.erase("inventory_version")
			c.model.s.deck=Model.Reserve.start_deck()
			while c.model.s.deck.size()<32:c.model.s.deck.append("bore")
			check(c.model.deck_limit()==32 and not c.can_acquire_ammo("arc","bore"),"legacy bag and basic-only replacement retained")
			roundtrip(c)
	# Future/fractional policy and mismatched nested saves reject atomically.
	var current=Campaign.new();current.start("heavy",17,0,"balanced",3,"carrier");roundtrip(current)
	var record:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://inventory.json"))
	for version in [-1,0.5,2,"1"]:
		var bad=record.duplicate(true);bad.campaign.inventory_version=version;bad.combat.inventory_version=version
		var target=Campaign.new()
		check(not target.restore_state(bad) and target.s.is_empty(),"unknown policy rejection "+str(version))
	var mismatched=record.duplicate(true);mismatched.campaign.erase("inventory_version")
	check(not Campaign.new().restore_state(mismatched),"nested policy mismatch rejected")
	var incompatible=record.combat.duplicate(true);incompatible.reserve_version=0
	check(not Model.new().restore_state(incompatible),"inventory requires finite reserve")
	# Actual archived endings from the preceding phase retain their old policy.
	for seed_value in [731042,17]:
		var path="res://../docs/qa/reports/assets/pressure_revision_2026-10-27/won_heavy_%d.json"%seed_value
		var archived:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
		var resumed=Campaign.new()
		check(resumed.restore_state(archived),"archived actual ending restores")
		check(not resumed.s.has("inventory_version") and resumed.model.deck_limit()==32,"archived ending not upgraded")
		check(JSON.parse_string(JSON.stringify(resumed.model.s))==archived.combat and JSON.parse_string(JSON.stringify(resumed.s))==archived.campaign,"archived ownership and rules exact")
	# Every permanent profile, including compressed/tuned rounds, removes one copy.
	var c=location("shop")
	c.model.s.deck=["bore","bore","precise_c","pierce_p3_power","basic_p1","basic_p2","basic_p3","cool"]
	# Use a catalog-generated tuned key rather than assuming its naming.
	c.model.s.deck[3]=Ammo.Variants.tuned("pierce_p3",Ammo.AMMO,"power")
	for source in c.model.s.deck.duplicate():
		c.s.offers=[{"type":"ammo","id":"arc","price":12,"sold":false}]
		var before:int=c.model.s.deck.count(source)
		var credits:int=c.s.credits
		check(c.buy(0,source),"shop replaces owned profile "+source)
		check(c.model.s.deck.size()==8 and c.model.s.deck.count(source)==before-1 and c.s.credits==credits-12,"exactly one copy and same price")
		var snapshot:=stable(c)
		check(not c.buy(0,source) and stable(c)==snapshot,"sold purchase cannot repeat")
		roundtrip(c)
	c.s.offers=[{"type":"ammo","id":"arc","price":12,"sold":false}]
	c.s.credits=100
	for source in ["arc","missing",Ammo.field_id("bore")]:
		var snapshot:=stable(c)
		check(not c.buy(0,source) and stable(c)==snapshot,"invalid or identical replacement atomic")
	# Free workbench exchange: real candidates, one work, no credit/ammo increase.
	for seed_value in [731042,17,931104]:
		for region in [0,2,4]:
			c=location("workshop",seed_value,region)
			var options:Array=c.workshop_ammo_options()
			check(options.size()==3 and options==c.workshop_ammo_options(),"three deterministic region/build candidates")
			roundtrip(c)
			var source:=str(c.replaceable_basics()[0]);var incoming:=str(options[0])
			var snapshot:=stable(c)
			check(not c.resolve("refit",incoming) and stable(c)==snapshot,"workbench cannot generate a free extra round")
			check(not c.resolve("refit","not_an_offer",source) and stable(c)==snapshot,"only offered candidates accepted")
			check(c.resolve("refit",incoming,source),"workbench exchanges a card")
			check(c.s.resolved and c.model.s.deck.size()==20 and c.s.credits==100 and c.model.s.deck.has(incoming),"refit consumes only one workshop action")
			roundtrip(c)
			snapshot=stable(c)
			check(not c.resolve("bag") and not c.resolve("refit",incoming,source) and stable(c)==snapshot,"no repeated workshop use")
			check(c.leave(),"refit returns to map");roundtrip(c)
	# Growth expands hand and capacity, does not insert cards or change gun slots.
	c=location("workshop",17,1)
	var magazine:int=c.model.capacity()
	check(c.resolve("bag") and c.model.deck_limit()==34 and Ammo.hand_capacity(c.model.s)==7,"workbench grows carry and hand")
	check(c.model.s.deck.size()==20 and c.model.capacity()==magazine,"growth is storage, not free ammo or magazine slots")
	roundtrip(c)
	# The same offered reward/supply can replace a special at a full inventory.
	for kind in ["supply","reward"]:
		c=location("supply")
		if kind=="reward":c.s.phase="reward";c.s.clears=2
		c.model.s.deck.fill("bore")
		while c.model.s.deck.size()<32:c.model.s.deck.append("bore")
		var options:Array=c.reward_options().filter(func(id):return id!="bore")
		check(not options.is_empty(),"different candidate available")
		check(c.reward(options[0],"bore") if kind=="reward" else c.resolve("ammo",options[0],"bore"),"replacement accepted through "+kind)
		check(c.model.s.deck.size()==32 and c.model.s.deck.count("bore")==31,"special-only full inventory is not locked")
	# New ownership policy never recycles ammunition or changes combat prediction.
	for burning in [false,true]:
		var m=fixture(["basic_p1"],[["wall",2 if burning else 40,9,0,40]],"heavy")
		m.s.inventory_version=1;m.s.reserve_version=1;m.s.combat_revision=2
		m.s.draw.clear();m.s.discard=m.s.deck.duplicate();m.s.discard.erase("basic_p1")
		if burning:m.s.enemies[0].burn=1
		check(m.load_round("basic_p1"),"commit last round")
		var prediction=Forecast.reload_now(m.s,true)
		check(m.reload_magazine() and prediction.phase==m.s.phase and prediction.enemies==m.s.enemies,"exhaustion preview agrees")
		check(m.s.phase in ["reward","won"] if burning else m.s.phase=="lost" and m.s.loss_reason=="ammo","last burn wins or empty ammo loses")
		check(Model.new().restore_state(m.s),"terminal state restores")
		m.begin_encounter();check(m.s.discard.is_empty() and m.s.hand.size()+m.s.draw.size()==m.s.deck.size(),"next fight restores owned cards only")
	FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("inventory.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"capacities":capacities},"  "))
	print("PLAYTEST REVISION INVENTORY COMPLETE checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
