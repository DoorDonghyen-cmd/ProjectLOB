extends SceneTree
const Campaign = preload("res://redesign/campaign.gd")
const Data = preload("res://redesign/campaign_content.gd")
const Solver = preload("res://tests/city_combat_solver.gd")
var checks := 0
var failures: Array = []
var reports: Array = []
var commands: Array = []
var solver = Solver.new()
var output := ""
var refine_build := false

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
		"gate": accepted = campaign.gate(str(item.id))
		"buy": accepted = campaign.buy(int(item.id))
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
	check(campaign.s.credits == 70 and campaign.s.parts.size() == 1, "part costs exactly 30")
	before = campaign.s.duplicate(true)
	check(not campaign.buy(1) and not campaign.buy(2) and campaign.s == before, "both duplicate and second part blocked")
	check(campaign.reroll(), "shop reroll")
	before = campaign.s.duplicate(true)
	check(not campaign.buy(1) and campaign.s == before, "part limit survives reroll")
	check(campaign.s.credits == 67, "reroll exactly 3Cr")
	check(campaign.shop_refine("push") and campaign.model.s.deck.size() == 9 and campaign.s.credits == 55, "paid refinement removes one round and costs 12")
	before = campaign.s.duplicate(true)
	check(not campaign.shop_refine("push") and campaign.s == before, "paid refinement once per visit")
	var id: String = campaign.model.s.part
	check(not campaign.dismantle(id), "equipped item cannot be dismantled")
	check(campaign.equip("none") and campaign.dismantle(id) and campaign.s.credits == 65, "unequip then dismantle gives exactly 10")
	campaign = fixture_shop()
	campaign.s.credits = 0
	before = campaign.s.duplicate(true)
	check(not campaign.buy(0) and not campaign.reroll() and before == campaign.s, "no debt and no free reroll")
	campaign = Campaign.new()
	campaign.start("single", 17)
	before = campaign.s.duplicate(true)
	check(not campaign.enter(401) and before == campaign.s, "cannot skip map floors")
	campaign.s.pressure = 2
	check(campaign.enter(101) and campaign.s.pressure == 0 and campaign.model.s.enemies[0].distance == 20, "carried distance cost consumed once")
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
	check(campaign.reward("remove", "push") and campaign.model.s.deck.size() == 9 and campaign.s.credits == 18, "reward refinement replaces credit/ammo")
	check(not campaign.reward("credits"), "reward cannot be claimed twice")
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
				if not command(campaign, {"action": "gate", "id": "slot" if int(campaign.s.slots) < 2 else "credits"}): break
			"shop":
				for i in range(campaign.s.offers.size()):
					var offer: Dictionary = campaign.s.offers[i]
					if offer.type == "part" and not campaign.s.shop_part_bought and int(campaign.s.credits) >= int(offer.price): command(campaign, {"action": "buy", "id": i})
				if int(campaign.s.region) == 0 and int(campaign.s.credits) >= 3: command(campaign, {"action": "reroll"})
				if refine_build and int(campaign.s.credits) >= 12 and campaign.model.s.deck.size() > 7:
					var remove_id: String = "push" if campaign.model.s.deck.has("push") else str(campaign.model.s.deck[0])
					command(campaign, {"action": "shop_refine", "id": remove_id})
				if refine_build and campaign.model.s.deck.size() < 10 and not campaign.s.offers[0].sold and int(campaign.s.credits) >= 12:
					command(campaign, {"action": "buy", "id": 0})
				command(campaign, {"action": "leave"})
			"supply":
				command(campaign, {"action": "resolve", "id": "remove" if campaign.model.s.deck.size() > 6 else "skip", "ammo": "push" if campaign.model.s.deck.has("push") else str(campaign.model.s.deck[0])})
				command(campaign, {"action": "leave"})
			"event":
				var choice: String = {"siphon": "power", "archive": "lore", "salvage": "sell"}[campaign.node().event]
				if choice == "sell" and campaign.model.s.deck.size() <= 6: choice = "skip"
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
	check(campaign.s.slots == 2 and campaign.model.capacity() == 6, "six-slot endgame with independent part")
	var report := {"gun": gun, "seed": seed_value, "route": route, "difficulty": difficulty, "won": won, "visits": visits, "commands": commands.duplicate(true), "campaign": campaign.s.duplicate(true), "combat": campaign.model.s.duplicate(true), "profile": campaign.profile.duplicate(true)}
	reports.append(report)
	print("CITY RUN " + gun + " seed=" + str(seed_value) + " route=" + route + " difficulty=" + str(difficulty) + " won=" + str(won) + " nodes=" + str(campaign.s.visited.size()) + " commands=" + str(commands.size()))

func _run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	refine_build = OS.get_environment("QA_CITY_REFINE") == "1"
	if output.is_empty(): output = "user://city_qa"
	DirAccess.make_dir_recursive_absolute(output)
	rules()
	if not OS.get_environment("QA_CITY_REPLAY_SOURCE").is_empty():
		var source = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_CITY_REPLAY_SOURCE")))
		for expected in source.runs: await replay_previous(expected)
		finish()
		return
	var seeds: Array = [731042, 17]
	if not OS.get_environment("QA_CITY_SEED").is_empty(): seeds = [int(OS.get_environment("QA_CITY_SEED"))]
	for seed_value in seeds:
		for gun in ["single", "burst"]:
			for route in ["safe", "mixed"]: await play(gun, int(seed_value), route)
	if OS.get_environment("QA_CITY_HARD") == "1":
		for gun in ["single", "burst"]: await play(gun, 90210, "mixed", 10)
	finish()

func finish() -> void:
	var file := FileAccess.open(output.path_join("city_campaign_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "explored": solver.explored, "runs": reports}, "\t"))
	file.close()
	print("CITY CAMPAIGN COMPLETE checks=" + str(checks) + " failures=" + str(failures.size()))
	quit(0 if failures.is_empty() else 1)
