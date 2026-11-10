extends "res://tests/foundry_campaign_runner.gd"
## Earn third-region progression before testing the fourth. No fabricated upgrades.

func write_report() -> void:
	var file=FileAccess.open(output.path_join("balance.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"battles":battles,"endpoints":endpoints},"  "));file.close()

func play_region(c, gun: String, target_region: int) -> bool:
	for iteration in range(160):
		if c.s.phase=="gate" and int(c.s.region)==target_region:break
		match str(c.s.phase):
			"map":
				var options:Array=c.choices()
				if not check(not options.is_empty(),"connected route"):return false
				var selected:Dictionary=options[0]
				for option in options:
					if option.kind=="shop" or option.get("workshop",false):selected=option
				if not command(c,{"action":"enter","id":selected.id}):return false
			"combat":
				var initial:Dictionary=c.model.s.duplicate(true)
				snapshot(c,"combat_%s_%d"%[gun,c.s.node])
				var path:Array=solver.solve(c.model,6,18)
				if path.is_empty():path=solver.solve(c.model,12,24)
				for step in path:
					if not command(c,step):return false
				var row={"gun":gun,"region":target_region,"node":c.s.node,"depth":c.s.floor,"elite":c.node().get("elite",false),"boss":c.node().kind=="boss","deck":initial.deck,"parts":initial.equipped_parts,"total":initial.encounter_total,"solved":not path.is_empty() and c.s.phase=="reward","turns":int(before_save.get("turns",0))-int(initial.turns),"path":path}
				battles.append(row);write_report()
				print("NOBLE ROUTE ",gun," region=",target_region+1," depth=",c.s.floor," solved=",row.solved," turns=",row.turns)
				if not check(row.solved,"earned progression "+gun+"/"+str(c.s.node)):return false
			"reward":
				var choice:="credits"
				var parts:Array=c.part_rewards()
				var ammo:Array=c.reward_options()
				if not parts.is_empty():choice=preferred_core if parts.has(preferred_core) else str(parts[0])
				elif not ammo.is_empty() and int(c.s.clears)%2==0:choice=str(ammo[0])
				if not command(c,{"action":"reward","id":choice,"replace":replacement(c,choice)}):return false
			"shop":
				for i in range(c.s.offers.size()):
					var offer:Dictionary=c.s.offers[i]
					if offer.sold or int(c.s.credits)<int(offer.price):continue
					if offer.type=="part" or (offer.type=="ammo" and i==0):
						if not command(c,{"action":"buy","id":i,"replace":replacement(c,str(offer.id))}):return false
				if not command(c,{"action":"leave"}):return false
			"supply":
				var options:Array=c.reward_options()
				if c.node().get("workshop",false):
					if not command(c,{"action":"resolve","id":"skip"}):return false
				elif not options.is_empty():
					if not command(c,{"action":"resolve","id":"ammo","ammo":options[0],"replace":replacement(c,str(options[0]))}):return false
				else:
					if not command(c,{"action":"resolve","id":"skip"}):return false
				if not command(c,{"action":"leave"}):return false
			"event":
				if not command(c,{"action":"resolve","id":"skip"}) or not command(c,{"action":"leave"}):return false
			"bypass":
				if not command(c,{"action":"leave"}):return false
			_:return false
		await process_frame
	return check(c.s.phase=="gate" and int(c.s.region)==target_region,"region cleared by earned deck")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/noble_live/"):quit(1);return
	output=OS.get_environment("QA_OUTPUT_DIR");solver.candidate_limit=1000
	var guns:=OS.get_environment("QA_GUNS").split(",") if not OS.get_environment("QA_GUNS").is_empty() else PackedStringArray(["single","burst","scatter","heavy","amplifier"])
	for gun in guns:
		preferred_core={"single":"siege_drive","burst":"volley_drive","scatter":"volley_drive","heavy":"thermal_drive","amplifier":"siege_drive"}[gun]
		var c=Campaign.new()
		var saved=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/garden_arrivals_20261024/"+gun+".json"))
		if not check(c.restore_state(saved),"earned second gate restores "+gun):continue
		c.s.roster_version=10
		# Keep earned cards/parts; evaluate the current weapon rule at this boundary.
		# Legacy heavy archives used the retired elemental weapon, not Reactor.
		c.model.s.weapon_version=1
		if not command(c,{"action":"gate","id":"bag" if c.can_grow_bag() else "credits"}):continue
		print("NOBLE EARNED ROUTE START ",gun)
		if not await play_region(c,gun,2):continue
		snapshot(c,"third_gate_"+gun)
		if not command(c,{"action":"gate","id":"bag" if c.can_grow_bag() else "credits"}):continue
		snapshot(c,"noble_entry_"+gun)
		if not await play_region(c,gun,3):continue
		snapshot(c,"fourth_gate_"+gun)
		if not command(c,{"action":"gate","id":"credits"}):continue
		check(c.s.region==4 and c.s.phase=="map" and not c.choices().is_empty(),"fourth gate opens fifth region")
		endpoints.append({"gun":gun,"region":c.s.region,"phase":c.s.phase,"deck":c.model.s.deck,"parts":c.s.equipped_parts})
		write_report()
	write_report()
	print("NOBLE LIVE BALANCE COMPLETE checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
