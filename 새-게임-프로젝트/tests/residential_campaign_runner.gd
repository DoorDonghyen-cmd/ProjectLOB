extends "res://tests/city_campaign_runner.gd"

func first_region(gun: String, seed_value: int, route: String, difficulty: int = 0) -> void:
	var campaign = Campaign.new()
	campaign.profile.ascension = difficulty
	campaign.start(gun, seed_value, difficulty, "balanced", test_map_version)
	commands = []
	var visits := {"combat": 0, "boss": 0, "shop": 0, "supply": 0, "event": 0, "bypass": 0}
	for iteration in range(100):
		if campaign.s.phase == "gate": break
		match str(campaign.s.phase):
			"map":
				var available := campaign.choices()
				if not check(not available.is_empty(), "map never dead ends"): break
				var selected: Dictionary = available[0]
				if route == "mixed" and available.size() > 1 and int(campaign.s.floor) in [1, 4]: selected = available.back()
				if test_map_version == 2:
					var preference := "elite" if route == "mixed" else "shop"
					for option in available:
						if Data.room_kind(option) == preference: selected = option
					if route == "safe":
						for option in available:
							if option.kind == "shop" or option.get("workshop", false): selected = option
				visits[selected.kind] += 1
				if not command(campaign, {"action": "enter", "id": selected.id}): break
			"combat":
				var path := solver.solve(campaign.model)
				if path.is_empty(): path = solver.solve(campaign.model, 12, 10)
				if not check(not path.is_empty(), "public-state combat path " + gun + "/" + str(seed_value) + "/" + str(campaign.s.node)): break
				for step in path:
					if not command(campaign, step): break
			"reward":
				var reward := "credits"
				var ammo_options := campaign.reward_options()
				if not ammo_options.is_empty() and campaign.model.s.deck.size() < 12 and int(campaign.s.clears) % 3 == 0:
					reward = str(ammo_options[0])
				if not campaign.part_rewards().is_empty(): reward = str(campaign.part_rewards()[0])
				if not command(campaign, {"action": "reward", "id": reward}): break
			"gate":
				var compressible: Array = campaign.compressible_ids()
				if compression_build and not compressible.is_empty():
					if not command(campaign, {"action": "gate", "id": "compress", "ammo": str(compressible[0])}): break
				elif not command(campaign, {"action": "gate", "id": "slot" if int(campaign.s.slots) < 2 else "credits"}): break
			"shop":
				for i in range(campaign.s.offers.size()):
					var offer: Dictionary = campaign.s.offers[i]
					if offer.type == "part" and int(campaign.s.credits) >= int(offer.price): command(campaign, {"action": "buy", "id": i})
				if int(campaign.s.region) == 0 and int(campaign.s.credits) >= 3: command(campaign, {"action": "reroll"})
				if compression_build and campaign.model.s.deck.size() < 10 and not campaign.s.offers[0].sold and int(campaign.s.credits) >= 12:
					command(campaign, {"action": "buy", "id": 0})
				command(campaign, {"action": "leave"})
			"supply":
				command(campaign, {"action": "resolve", "id": "skip"})
				command(campaign, {"action": "leave"})
			"event":
				var choice: String = {"siphon": "power", "archive": "lore", "salvage": "sell"}[campaign.node().event]
				if choice == "sell" and campaign.model.s.deck.size() <= Campaign.MIN_DECK: choice = "skip"
				command(campaign, {"action": "resolve", "id": choice, "ammo": str(campaign.model.s.deck[0])})
				command(campaign, {"action": "leave"})
			"bypass": command(campaign, {"action": "leave"})
			"won", "lost": break
		await process_frame
	check(campaign.s.phase == "gate" and campaign.s.visited.size() == 8, "first-region gate reached " + gun)
	reports.append({"gun": gun, "seed": seed_value, "phase": campaign.s.phase, "commands": commands.duplicate(true), "state": campaign.s.duplicate(true), "combat": campaign.model.s.duplicate(true)})
	print("FIRST REGION " + gun + " " + str(campaign.s.phase) + " commands=" + str(commands.size()))

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/residential/"):
		quit(1)
		return
	output = OS.get_environment("QA_OUTPUT_DIR")
	test_map_version = 2
	solver.candidate_limit = 1500
	var guns: Array = Array(OS.get_environment("QA_GUNS").split(",")) if not OS.get_environment("QA_GUNS").is_empty() else Ammo.GUNS.keys()
	for gun in guns:
		print("FIRST REGION START " + str(gun))
		for seed_value in [731042, 17]:
			await first_region(str(gun), seed_value, "safe")
	var file := FileAccess.open(output.path_join("campaign.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "runs": reports}, "  "))
	print("RESIDENTIAL CAMPAIGN COMPLETE checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
