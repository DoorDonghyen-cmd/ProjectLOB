extends "res://tests/earned_ammo_campaign_runner.gd"

func snapshot(c) -> Dictionary:
	return JSON.parse_string(JSON.stringify({"campaign":c.s,"combat":c.model.s,"profile":c.profile}))

func clone(c):
	c.save("user://earned_probe.json")
	var copy=Campaign.new()
	check(copy.restore("user://earned_probe.json"),"restore checkpoint")
	return copy

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/earned_ammo/"): quit(1);return
	output=OS.get_environment("QA_OUTPUT_DIR")
	solver.candidate_limit=1500
	for gun in Ammo.GUNS:
		for outfit in Ammo.OUTFITS:
			for loadout in Data.LOADOUTS:
				var c=Campaign.new();c.profile.unlocks=Data.LOADOUTS.keys()
				c.start(gun,17,0,loadout,2,outfit)
				check(c.model.s.deck.size()==10,"ten starting cards")
				check(c.model.s.deck.all(func(id):return Ammo.source_id(id)=="basic"),"every supply starts with basics only")
				check(c.model.s.deck.count("basic_p1")==2 and c.model.s.deck.count("basic_p2")==6 and c.model.s.deck.count("basic_p3")==2,"power/heat choices at start")
				check(roundtrip(c),"starter persists")
		var c=Campaign.new();c.start(gun,731042,0,"balanced",2,"carrier")
		check(command(c,{"action":"enter","id":c.choices()[0].id}),"enter actual opening")
		var path: Array=solver.solve(c.model,14,12)
		check(not path.is_empty(),"basic-only opening is winnable "+gun)
		for step in path: command(c,step)
		check(c.engine_reward() and c.reward_options().is_empty(),"first reward starts with core only")
		for core in ["volley_drive","thermal_drive","siege_drive","skip"]:
			var branch=clone(c)
			check(command(branch,{"action":"reward","id":core}),"core selection")
			check(branch.first_ammo_reward() and branch.part_rewards().is_empty(),"special acquisition follows core")
			var options: Array=branch.reward_options()
			check(options.size()==3 and options==clone(branch).reward_options(),"three stable choices across save/reload")
			check(not branch.reward("volley_drive"),"cannot claim another core during ammo step")
			for id in options:
				check(Ammo.source_id(id)!="basic","first discovery is special")
				var chosen=clone(branch)
				var before: Array=chosen.model.s.deck.duplicate()
				check(command(chosen,{"action":"reward","id":id,"replace":"basic_p1"}),"exchange one basic for selected special")
				check(chosen.s.phase=="map" and chosen.s.opening_reward_step==2,"both decisions complete once")
				check(chosen.model.s.deck.size()==10 and chosen.model.s.deck.count("basic_p1")==1 and chosen.model.s.deck.count(id)==1,"replacement conserves deck size")
				check(not chosen.reward(id),"no double reward")
			var full=clone(branch)
			full.model.s.deck.append_array(["basic_p2","basic_p2","basic_p2","basic_p2"])
			var before:=snapshot(full)
			check(not full.reward(options[0]) and snapshot(full)==before,"full deck cannot append")
			check(not full.reward(options[0],"charge") and snapshot(full)==before,"unowned or special removal rejected atomically")
			check(command(full,{"action":"reward","id":options[0],"replace":"basic_p2"}) and full.model.s.deck.size()==14,"full deck still accepts basic exchange")
		var legacy=clone(c)
		var old:=snapshot(legacy);old.campaign.discovery_version=2;old.campaign.roster_version=3;old.campaign.erase("opening_reward_step")
		check(legacy.restore_state(old),"old pending reward migrates without losing deck")
		var old_deck: Array=legacy.model.s.deck.duplicate()
		check(legacy.reward("volley_drive") and legacy.s.phase=="map" and legacy.model.s.deck==old_deck,"legacy reward stays one step")
		check(legacy.replaceable_basics().is_empty(),"legacy acquisition policy unchanged")
	for seed_value in range(30):
		for gun in Ammo.GUNS:
			for loadout in Data.LOADOUTS:
				var options: Array=Data.Acquisition.first_options(seed_value,gun,[],loadout)
				check(options.size()==3 and options[0]!=options[1] and options[0]!=options[2] and options[1]!=options[2],"different first discoveries")
				if gun=="heavy": check(options.has("bore") or options.has("arc"),"elemental weapon always has an elemental choice")
				if loadout!="balanced": check(options.has({"amplify":"precise_p2","thermal":"bore","voltage":"arc"}[loadout]),"earned supply preference respected")
	var shop=Campaign.new();shop.start("burst",731042,0,"balanced",1)
	shop.s.floor=3;shop.s.node=301;shop.s.visited=[101,201,301]
	check(shop.enter(401),"shop entry")
	shop.s.credits=100;shop.s.offers[0]={"id":"precise_p2","type":"ammo","price":12,"sold":false}
	check(command(shop,{"action":"buy","id":0,"replace":"basic_p2"}),"shop basic exchange")
	check(shop.s.credits==88 and shop.model.s.deck.size()==10,"exchange pays stated price")
	var unchanged:=snapshot(shop)
	check(not shop.buy(0,"basic_p2") and snapshot(shop)==unchanged,"sold exchange cannot repeat")
	for depth in [1,2,3]:
		var node: Dictionary=Data.nodes(0,17,2).filter(func(n):return int(n.floor)==depth)[0]
		var pack:=Data.encounter_pack(node,17,"burst",0,0,4)
		check(pack.active.all(func(e):return int(e.def)<=1),"opening does not demand a particular counter-card")
	var bad:=snapshot(shop);bad.campaign.opening_reward_step=1
	check(not Campaign.new().restore_state(bad),"pending ammo stage only restores in first reward")
	var file=FileAccess.open(output.path_join("rules.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures},"  "));file.close()
	print("EARNED AMMO RULES COMPLETE checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
