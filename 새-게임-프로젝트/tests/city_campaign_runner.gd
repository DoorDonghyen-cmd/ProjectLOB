extends SceneTree
const Campaign = preload("res://redesign/campaign.gd")
const Data = preload("res://redesign/campaign_content.gd")
const Ammo = preload("res://redesign/content.gd")
const Solver = preload("res://tests/city_combat_solver.gd")
var checks := 0
var failures: Array = []
var reports: Array = []
var commands: Array = []
var solver = Solver.new()
var output := ""
var compression_build := false

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures.append(label)
		print("FAIL: " + label)
	return condition

func roundtrip(campaign) -> bool:
	var path := "user://city_probe.json"
	if not check(campaign.save(path) == OK, "atomic campaign save"): return false
	var loaded = Campaign.new()
	if not check(loaded.restore(path), "full campaign restore " + str(campaign.s.phase)): return false
	check(JSON.stringify(loaded.s) == JSON.stringify(JSON.parse_string(JSON.stringify(campaign.s))), "campaign exact persistence")
	check(JSON.stringify(loaded.model.s) == JSON.stringify(JSON.parse_string(JSON.stringify(campaign.model.s))), "combat exact persistence")
	check(JSON.stringify(loaded.profile) == JSON.stringify(JSON.parse_string(JSON.stringify(campaign.profile))), "profile exact persistence")
	return true

func command(campaign, item: Dictionary) -> bool:
	var accepted := false
	match str(item.action):
		"enter": accepted = campaign.enter(int(item.id))
		"reward": accepted = campaign.reward(str(item.id))
		"gate": accepted = campaign.gate(str(item.id), str(item.get("ammo", "")))
		"buy": accepted = campaign.buy(int(item.id))
		"buy_compressor": accepted = campaign.buy_compressor_charge()
		"reroll": accepted = campaign.reroll()
		"shop_refine": accepted = campaign.shop_refine(str(item.id))
		"equip": accepted = campaign.equip(str(item.id))
		"dismantle": accepted = campaign.dismantle(str(item.id))
		"resolve": accepted = campaign.resolve(str(item.id), str(item.get("ammo", "")))
		"leave": accepted = campaign.leave()
		"load": accepted = campaign.model.load_round(str(item.id))
		"confirm": accepted = campaign.model.confirm()
		"fire": accepted = campaign.model.fire()
		"reload": accepted = campaign.model.reload_magazine()
	campaign.sync_combat()
	if not check(accepted, "real command " + JSON.stringify(item)): return false
	if not roundtrip(campaign): return false
	item["phase"] = campaign.s.phase
	item["node"] = campaign.s.node
	item["credits"] = campaign.s.credits
	item["turns"] = campaign.model.s.turns
	commands.append(item)
	return true

func fixture_shop():
	var campaign = Campaign.new()
	campaign.start("burst", 731042)
	campaign.s.phase = "shop"
	campaign.s.floor = 4
	campaign.s.node = 401
	campaign.s.credits = 100
	campaign.s.offers = Data.offers(campaign.node(), 731042, 0, "burst", [])
	return campaign

func rules() -> void:
	var total := 0
	for region in range(5):
		var nodes := Data.nodes(region, 17)
		var floors := int(Data.info(region).floors)
		total += floors
		for f in range(1, floors + 1): check(not nodes.filter(func(item): return int(item.floor) == f).is_empty(), "every floor generated")
		check(nodes.back().kind == "boss", "every region has a gate")
	check(total == 35, "production 35-floor ladder retained")
	var campaign = fixture_shop()
	var before: Dictionary = campaign.s.duplicate(true)
	check(not campaign.buy(-1) and campaign.s == before, "invalid shop transaction is inert")
	check(campaign.buy(1), "first part purchase")
	check(campaign.s.credits == 70 and campaign.s.parts.size() == 1 and campaign.equipped_parts().size() == 1, "part costs exactly 30 and fills one slot")
	check(not campaign.buy(1) and campaign.buy(2), "sold duplicate blocked while second offered part remains purchasable")
	check(campaign.s.credits == 40 and campaign.s.parts.size() == 2 and campaign.equipped_parts().size() == 2, "one shop may advance a multi-part build")
	check(campaign.reroll(), "shop reroll")
	check(campaign.s.credits == 37, "reroll exactly 3Cr")
	before = campaign.s.duplicate(true)
	check(not campaign.shop_refine("push") and campaign.s == before, "retired shop refinement cannot mutate the new deck")
	var id: String = str(campaign.equipped_parts()[0])
	check(not campaign.dismantle(id), "equipped item cannot be dismantled")
	check(campaign.equip(id) and campaign.dismantle(id) and campaign.s.credits == 47, "unequip then dismantle gives exactly 10")
	var core_shop = fixture_shop()
	check(core_shop.s.compressor_charges == 1 and core_shop.buy_compressor_charge(), "shop sells a persistent compression core")
	check(core_shop.s.compressor_charges == 2 and core_shop.s.credits == 82 and core_shop.s.shop_compressor_bought, "compression core costs 18Cr and respects the two-core cap")
	before = core_shop.s.duplicate(true)
	check(not core_shop.buy_compressor_charge() and core_shop.reroll() and not core_shop.buy_compressor_charge() and core_shop.s.compressor_charges == 2, "reroll never resets compression core visit lock")
	var part_build = Campaign.new()
	part_build.start("burst", 731042)
	part_build.s.parts = ["lens", "coil", "capacitor", "rammer", "field_press", "reserve", "overbore"]
	for part_id in ["lens", "coil", "capacitor", "rammer", "field_press"]:
		check(part_build.equip(part_id), "five-part build equips " + part_id)
	check(part_build.equipped_parts().size() == 5 and Ammo.valid_part_set("burst", part_build.equipped_parts()), "five distinct parts operate together")
	check(not part_build.equip("reserve") and not part_build.equip("overbore"), "sixth slot and second core are both rejected")
	check(part_build.equip("lens") and part_build.equip("reserve"), "one module can be swapped without disturbing four other parts")
	check(part_build.equip("field_press") and part_build.equip("overbore"), "the single core slot can be exchanged")
	check(part_build.equipped_parts() == ["coil", "capacitor", "rammer", "reserve", "overbore"], "part order and the remaining build survive swaps")
	check(roundtrip(part_build), "five-part campaign build restores exactly")
	var two_core_data := {"campaign": part_build.s.duplicate(true), "combat": part_build.model.s.duplicate(true), "profile": part_build.profile.duplicate(true)}
	two_core_data.campaign.equipped_parts = ["field_press", "overbore"]
	two_core_data.combat.equipped_parts = ["field_press", "overbore"]
	check(not Campaign.new().restore_state(two_core_data), "tampered save cannot equip two core parts")
	var field_build = Campaign.new()
	field_build.start("burst", 731042)
	field_build.s.parts = ["field_press"]
	check(field_build.equip("field_press") and field_build.enter(101), "field press build enters combat")
	check(not field_build.equip("field_press") and field_build.is_equipped("field_press"), "parts cannot change during combat")
	check(field_build.s.compressor_charges == 1 and field_build.model.s.field_compression_left == 2, "field press grants one temporary compression above run stock")
	field_build.model.s.deck = ["bore", "bore", "charge", "precise", "pierce", "push", "arc", "charge"]
	field_build.model.s.hand = ["bore", "bore", "charge", "precise", "pierce"]
	field_build.model.s.draw = ["push", "arc", "charge"]
	field_build.model.s.discard = []
	check(field_build.model.field_compress("bore"), "field press temporary compression can be used in combat")
	field_build.sync_combat()
	check(field_build.model.s.field_compression_left == 1 and field_build.s.compressor_charges == 1, "temporary compression is spent before persistent shop stock")
	check(roundtrip(field_build), "field press pending compression restores exactly")
	campaign = fixture_shop()
	campaign.s.credits = 0
	before = campaign.s.duplicate(true)
	check(not campaign.buy(0) and not campaign.reroll() and before == campaign.s, "no debt and no free reroll")
	campaign = Campaign.new()
	campaign.start("single", 17)
	before = campaign.s.duplicate(true)
	check(not campaign.enter(401) and before == campaign.s, "cannot skip map floors")
	campaign.s.pressure = 2
	var opening_node: Dictionary = campaign.current_nodes().filter(func(node): return int(node.id) == 101)[0]
	var expected_opening_distance := int(Data.encounter_pack(opening_node, 17, "single", 0, 2).active[0].distance)
	check(campaign.enter(101) and campaign.s.pressure == 0 and campaign.model.s.enemies[0].distance == expected_opening_distance, "carried distance cost consumed once")
	check(roundtrip(campaign), "combat fixture restores")
	var bad: Dictionary = {"campaign": campaign.s.duplicate(true), "combat": campaign.model.s.duplicate(true), "profile": campaign.profile.duplicate(true)}
	bad.campaign.phase = "shop"
	check(not Campaign.new().restore_state(bad), "node/phase mismatch rejected")
	bad.campaign = campaign.s.duplicate(true)
	bad.campaign.visited.append(101)
	check(not Campaign.new().restore_state(bad), "duplicate visited node rejected")
	bad.campaign = campaign.s.duplicate(true)
	bad.combat.capacity_bonus = -1
	check(not Campaign.new().restore_state(bad), "invalid expansion rejected")
	bad = {"campaign": campaign.s.duplicate(true), "combat": campaign.model.s.duplicate(true), "profile": campaign.profile.duplicate(true)}
	bad.campaign.compressor_charges = 3
	check(not Campaign.new().restore_state(bad), "compression core inventory cannot exceed two")
	var legacy_data := {"campaign": campaign.s.duplicate(true), "combat": campaign.model.s.duplicate(true), "profile": campaign.profile.duplicate(true)}
	legacy_data.campaign.version = 1
	legacy_data.campaign.erase("compressor_charges")
	legacy_data.campaign.erase("shop_compressor_bought")
	var migrated_campaign = Campaign.new()
	legacy_data.campaign.erase("shop_seen_parts")
	legacy_data.campaign.erase("equipped_parts")
	check(migrated_campaign.restore_state(legacy_data) and migrated_campaign.s.version == 4 and migrated_campaign.s.compressor_charges == 1 and migrated_campaign.s.shop_seen_parts.is_empty() and not migrated_campaign.s.shop_compressor_bought, "campaign v1 migrates through current multi-part shop format")
	var seen_parts: Array = []
	var shop_node: Dictionary = Data.nodes(0, 731042).filter(func(item): return item.kind == "shop")[0]
	for revision in range(10):
		var rotating_offers: Array = Data.offers(shop_node, 731042, revision, "burst", [], seen_parts)
		for offer in rotating_offers:
			if offer.type == "part" and not seen_parts.has(offer.id): seen_parts.append(offer.id)
	check(seen_parts.size() == Data.eligible_parts("burst").size() and seen_parts.has("supply") and seen_parts.has("duplex") and seen_parts.has("field_press") and seen_parts.has("triad"), "ten shop views expose every eligible part before repeating")
	check(Data.eligible_parts("single").size() == 19 and not Data.eligible_parts("single").has("loader"), "only ineffective loader is excluded from walker twenty-part pool")
	for value in [1, 2]:
		campaign.model.s.capacity_bonus = value
		check(campaign.model.capacity() == 4 + value, "capacity growth separate from part")
		campaign.model.s.part = "lens"
		check(campaign.model.capacity() == 4 + value, "part change retains expansion")
		campaign.model.s.part = "none"
	campaign.profile.cores = 30
	check(campaign.unlock("thermal") and campaign.profile.cores == 0, "loadout sidegrade unlock")
	check(not campaign.unlock("thermal"), "unlock cannot charge twice")
	campaign = Campaign.new()
	campaign.start("single", 17)
	campaign.enter(101)
	for enemy in campaign.model.s.enemies: enemy.hp = 0
	campaign.model.s.phase = "reward"
	campaign.sync_combat()
	var deck_before: Array = campaign.model.s.deck.duplicate()
	check(not campaign.reward("remove", "push") and campaign.model.s.deck == deck_before, "retired reward refinement is rejected")
	check(campaign.reward("credits"), "valid reward still advances after rejected refinement")
	check(not campaign.reward("credits"), "reward cannot be claimed twice")
	campaign = Campaign.new()
	campaign.start("single", 17)
	campaign.s.phase = "gate"
	check(campaign.compressible_ids().has("bore") and campaign.compressible_ids().has("pierce"), "gate exposes only duplicate ordinary families")
	check(campaign.gate("compress", "bore") and campaign.model.s.deck.size() == 9 and campaign.model.s.deck.count("bore") == 0 and campaign.model.s.deck.count("bore_c") == 1, "gate compression consumes two and creates one")
	campaign = Campaign.new()
	campaign.start("single", 17)
	campaign.model.s.deck.resize(8)
	campaign.s.phase = "gate"
	deck_before = campaign.model.s.deck.duplicate()
	check(campaign.compressible_ids().is_empty() and not campaign.gate("compress", "pierce") and campaign.model.s.deck == deck_before, "compression preserves eight-card floor")
	campaign = Campaign.new()
	campaign.start("single", 17)
	check(campaign.enter(101), "persistent core combat fixture enters")
	campaign.model.s.deck = ["bore", "bore", "charge", "precise", "pierce", "push", "arc", "charge"]
	campaign.model.s.hand = ["bore", "bore", "charge", "precise", "pierce"]
	campaign.model.s.draw = ["push", "arc", "charge"]
	campaign.model.s.discard = []
	campaign.model.s.enemies = [{"kind": "wall", "name": Ammo.ENEMY_NAMES.wall, "hp": 1, "max_hp": 1, "def": 0, "speed": 1, "distance": 20, "burn": 0}]
	check(campaign.model.field_compress("bore") and campaign.model.confirm() and campaign.model.fire(), "field compression resolves with one run core")
	campaign.sync_combat()
	check(campaign.s.phase == "reward" and campaign.s.compressor_charges == 0, "spent compression core persists after combat")
	check(campaign.reward("skip") and campaign.enter(int(campaign.choices()[0].id)), "next combat starts from the same run resource")
	check(campaign.model.s.field_compression_left == 0 and campaign.model.field_compressible_ids().is_empty(), "new encounter cannot restore a spent compression core for free")
	for loadout in Data.LOADOUTS:
		campaign.profile.unlocks = Data.LOADOUTS.keys()
		campaign.start("single", 731042, 0, str(loadout))
		check(campaign.model.s.deck == Data.LOADOUTS[loadout].deck, "loadout owns exact chosen starting bullets")
		var state: Dictionary = campaign.s.duplicate(true)
		var random_state: String = campaign.model.s.rng_state
		campaign.current_nodes()
		campaign.choices()
		check(campaign.s == state and campaign.model.s.rng_state == random_state, "map preview cannot mutate live state or RNG")
	campaign = Campaign.new()
	campaign.start("single", 17)
	for fragment_id in range(1, 21): campaign.collect_lore(fragment_id); campaign.collect_lore(fragment_id)
	check(campaign.profile.lore.size() == 20, "twenty production lore fragments retained without duplicates")
	campaign.s.clears = 3
	campaign.settle(false)
	check(campaign.profile.cores == 6 and campaign.profile.runs == 1 and campaign.profile.wins == 0, "loss awards earned data once")
	campaign.settle(false)
	check(campaign.profile.cores == 6 and campaign.profile.runs == 1, "loss settlement idempotent")

func replay_previous(expected: Dictionary) -> void:
	var campaign = Campaign.new()
	campaign.profile.ascension = int(expected.difficulty)
	campaign.start(str(expected.gun), int(expected.seed), int(expected.difficulty))
	commands = []
	for previous in expected.commands:
		if not command(campaign, previous.duplicate(true)): return
		if not check(campaign.s.phase == previous.phase and int(campaign.s.node) == int(previous.node), "previous path retains exact progress"): return
		if commands.size() % 50 == 0: await process_frame
	check(campaign.s.phase == "won" and campaign.s.visited.size() == 35, "unchanged combat paths complete city after economy tuning")
	check(JSON.stringify(JSON.parse_string(JSON.stringify(campaign.model.s))) == JSON.stringify(expected.combat), "economy tuning preserves exact combat history")
	var report := {"gun": expected.gun, "seed": expected.seed, "route": expected.route, "difficulty": expected.difficulty, "won": campaign.s.phase == "won", "visits": expected.visits, "commands": commands.duplicate(true), "campaign": campaign.s.duplicate(true), "combat": campaign.model.s.duplicate(true), "profile": campaign.profile.duplicate(true)}
	reports.append(report)
	print("CITY REPLAY " + str(expected.gun) + " seed=" + str(expected.seed) + " route=" + str(expected.route) + " difficulty=" + str(expected.difficulty) + " credits=" + str(campaign.s.credits))

func play(gun: String, seed_value: int, route: String, difficulty: int = 0) -> void:
	var campaign = Campaign.new()
	campaign.profile.ascension = difficulty
	campaign.start(gun, seed_value, difficulty)
	commands = []
	var visits := {"combat": 0, "boss": 0, "shop": 0, "supply": 0, "event": 0, "bypass": 0}
	for iteration in range(300):
		match str(campaign.s.phase):
			"map":
				var available := campaign.choices()
				if not check(not available.is_empty(), "map never dead ends"): break
				var selected: Dictionary = available[0]
				if route == "mixed" and available.size() > 1 and int(campaign.s.floor) in [1, 4]: selected = available.back()
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
				var ammo_options := Data.rewards(campaign.node(), seed_value)
				if campaign.model.s.deck.size() < 12 and int(campaign.s.clears) % 3 == 0:
					reward = str(ammo_options[0])
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
	var won: bool = campaign.s.phase == "won"
	check(won and campaign.absolute_floor() == 35 and campaign.s.visited.size() == 35, "all 35 floors completed")
	var progress: Dictionary = campaign.profile.duplicate(true)
	campaign.sync_combat()
	campaign.settle(won)
	check(progress == campaign.profile, "debrief cannot pay twice")
	if compression_build:
		check(campaign.model.s.deck.any(func(id): return Ammo.is_compressed(str(id))), "compression route retains at least one compressed round")
	else:
		var part_capacity := (1 if Ammo.has_part(campaign.model.s, "supply") else 0) - (2 if Ammo.has_part(campaign.model.s, "field_press") else 0) - (1 if Ammo.has_part(campaign.model.s, "overbore") else 0)
		check(campaign.s.slots == 2 and campaign.model.capacity() == maxi(1, int(Ammo.GUNS[gun].capacity) + 2 + part_capacity), "endgame growth retains expansion and active part capacity costs")
	var report := {"gun": gun, "seed": seed_value, "route": route, "difficulty": difficulty, "won": won, "visits": visits, "commands": commands.duplicate(true), "campaign": campaign.s.duplicate(true), "combat": campaign.model.s.duplicate(true), "profile": campaign.profile.duplicate(true)}
	reports.append(report)
	print("CITY RUN " + gun + " seed=" + str(seed_value) + " route=" + route + " difficulty=" + str(difficulty) + " won=" + str(won) + " nodes=" + str(campaign.s.visited.size()) + " commands=" + str(commands.size()))

func _run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	compression_build = OS.get_environment("QA_CITY_COMPRESSION") == "1"
	if output.is_empty(): output = "user://city_qa"
	DirAccess.make_dir_recursive_absolute(output)
	rules()
	if not OS.get_environment("QA_CITY_REPLAY_SOURCE").is_empty():
		var source = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_CITY_REPLAY_SOURCE")))
		if not check(source is Dictionary and source.get("runs", null) is Array and source.get("failures", ["invalid"]).is_empty(), "replay source is a validated report"):
			finish()
			return
		for expected in source.runs: await replay_previous(expected)
		finish()
		return
	var seeds: Array = [731042, 17]
	var guns: Array = ["single", "burst"]
	if not OS.get_environment("QA_CITY_GUNS").is_empty(): guns = Array(OS.get_environment("QA_CITY_GUNS").split(","))
	if not OS.get_environment("QA_CITY_SEED").is_empty(): seeds = [int(OS.get_environment("QA_CITY_SEED"))]
	if OS.get_environment("QA_CITY_HARD_ONLY") != "1":
		for seed_value in seeds:
			for gun in guns:
				for route in ["safe", "mixed"]: await play(gun, int(seed_value), route)
	if OS.get_environment("QA_CITY_HARD") == "1":
		var difficulties: Array = [10]
		if not OS.get_environment("QA_CITY_DIFFICULTIES").is_empty():
			difficulties.clear()
			for value in OS.get_environment("QA_CITY_DIFFICULTIES").split(","): difficulties.append(int(value))
		for difficulty in difficulties:
			for gun in guns: await play(gun, 90210 + int(difficulty), "mixed", int(difficulty))
	finish()

func finish() -> void:
	var file := FileAccess.open(output.path_join("city_campaign_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "explored": solver.explored, "runs": reports}, "\t"))
	file.close()
	print("CITY CAMPAIGN COMPLETE checks=" + str(checks) + " failures=" + str(failures.size()))
	quit(0 if failures.is_empty() else 1)
