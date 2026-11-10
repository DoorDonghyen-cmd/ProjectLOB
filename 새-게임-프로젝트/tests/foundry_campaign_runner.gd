extends "res://tests/reserve_campaign_runner.gd"
var battles: Array=[]
var endpoints: Array=[]
var before_save: Dictionary={}
var search_width := 4

func roundtrip(c) -> bool:
	# Campaign.save reconciles piles outside combat. Capture actual consumption first.
	before_save=c.model.s.duplicate(true)
	return super.roundtrip(c)

func snapshot(c, name: String) -> void:
	var file=FileAccess.open(output.path_join(name+".json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"campaign":c.s,"combat":c.model.s,"profile":c.profile}));file.close()

func second_region(c, gun: String, seed_value: int) -> void:
	for iteration in range(120):
		if c.s.phase=="gate" and int(c.s.region)==1:break
		match str(c.s.phase):
			"map":
				var options: Array=c.choices()
				if not check(not options.is_empty(),"second region route available"):break
				var selected: Dictionary=options[0]
				for option in options:
					if option.kind=="shop" or option.get("workshop",false):selected=option
				if not command(c,{"action":"enter","id":selected.id}):break
			"combat":
				var before: Dictionary=c.model.s.duplicate(true)
				snapshot(c,"combat_%s_%d"%[gun,c.s.node])
				var path: Array=solver.solve(c.model,search_width,14)
				if path.is_empty():
					solver.candidate_limit=1500
					path=solver.solve(c.model,12,18)
					solver.candidate_limit=700
				var nearest:=1000000
				for step in path:
					if not command(c,step):break
					for enemy in c.model.s.enemies+c.model.Ranged.active(c.model.s):
						if int(enemy.hp)>0:nearest=mini(nearest,int(enemy.distance))
				var row={"gun":gun,"seed":seed_value,"node":c.s.node,"depth":c.s.floor,"elite":c.node().get("elite",false),"boss":c.node().kind=="boss","enemies":before.encounter_total,"start_deck":before.deck,"parts":c.s.equipped_parts.duplicate(),"solved":not path.is_empty(),"turns":int(before_save.turns)-int(before.turns),"used":before_save.discard.size(),"remaining":before_save.deck.size()-before_save.discard.size(),"margin":nearest if nearest<1000000 else -1,"path":path}
				battles.append(row);print("FOUNDRY BATTLE ",gun," node=",c.s.node," solved=",row.solved," turns=",row.turns," used=",row.used," remaining=",row.remaining)
				if not check(not path.is_empty() and c.s.phase=="reward","second region combat path "+gun+"/"+str(c.s.node)):break
			"reward":
				var choice: String="credits"
				var parts: Array=c.part_rewards()
				var ammo: Array=c.reward_options()
				if not parts.is_empty():choice=preferred_core if parts.has(preferred_core) else str(parts[0])
				elif not ammo.is_empty() and int(c.s.clears)%2==0:choice=str(ammo[0])
				if not command(c,{"action":"reward","id":choice,"replace":replacement(c,choice)}):break
			"shop":
				for i in range(c.s.offers.size()):
					var offer: Dictionary=c.s.offers[i]
					if offer.sold or int(c.s.credits)<int(offer.price):continue
					if offer.type=="part" or (offer.type=="ammo" and i==0):
						command(c,{"action":"buy","id":i,"replace":replacement(c,str(offer.id))})
				command(c,{"action":"leave"})
			"supply":
				var options: Array=c.reward_options()
				if c.node().get("workshop",false):command(c,{"action":"resolve","id":"skip"})
				elif not options.is_empty():command(c,{"action":"resolve","id":"ammo","ammo":options[0],"replace":replacement(c,str(options[0]))})
				else:command(c,{"action":"resolve","id":"skip"})
				command(c,{"action":"leave"})
			"event":
				command(c,{"action":"resolve","id":"skip"});command(c,{"action":"leave"})
			"bypass":command(c,{"action":"leave"})
			_:break
		await process_frame
	check(c.s.phase=="gate" and int(c.s.region)==1,"second gate reached "+gun)
	snapshot(c,"endpoint_"+gun)
	endpoints.append({"gun":gun,"seed":seed_value,"phase":c.s.phase,"region":c.s.region,"floor":c.s.floor,"visited":c.s.visited.size(),"deck":c.model.s.deck.duplicate(),"commands":commands.duplicate(true)})
	if c.s.phase=="gate":
		check(command(c,{"action":"gate","id":"bag" if c.can_grow_bag() else "credits"}),"second gate reward accepted")
		check(c.s.region==2 and c.s.phase=="map" and not c.choices().is_empty(),"second gate connects to next map")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/foundry/"):quit(1);return
	output=OS.get_environment("QA_OUTPUT_DIR")
	test_map_version=3;solver.candidate_limit=700
	var seed_value:=int(OS.get_environment("QA_SEED"))
	for gun in OS.get_environment("QA_GUNS").split(","):
		preferred_core={"single":"siege_drive","burst":"volley_drive","scatter":"volley_drive","heavy":"thermal_drive","amplifier":"siege_drive"}[gun]
		print("FOUNDRY RUN START ",gun," seed=",seed_value)
		await first_region(gun,seed_value,"safe")
		if reports.back().phase!="gate":continue
		var c=Campaign.new()
		if not check(c.restore("user://city_probe.json"),"earned first gate restores"):continue
		# The baseline keeps old second-region formations after production version changes.
		if OS.get_environment("QA_FOUNDRY_STAGE")=="baseline":c.s.roster_version=5
		if not command(c,{"action":"gate","id":"slot"}):continue
		snapshot(c,"entry_"+gun)
		await second_region(c,gun,seed_value)
		var partial=FileAccess.open(output.path_join("campaign.json"),FileAccess.WRITE)
		partial.store_string(JSON.stringify({"checks":checks,"failures":failures,"battles":battles,"runs":endpoints,"first_regions":reports},"  "));partial.close()
	print("FOUNDRY CAMPAIGN COMPLETE checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
