extends SceneTree
const Campaign = preload("res://redesign/campaign.gd")
const Model = preload("res://redesign/model.gd")
const Data = preload("res://redesign/campaign_content.gd")
const Ammo = preload("res://redesign/content.gd")
const Guide = preload("res://redesign/build_guide.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + label)

func shop():
	var campaign = Campaign.new()
	campaign.start("burst", 731042)
	campaign.s.floor = 3
	campaign.s.node = 301
	campaign.s.visited = [101, 201, 301]
	check(campaign.enter(401), "enter legal next shop")
	return campaign

func run() -> void:
	for gun in Ammo.GUNS:
		for loadout in Data.LOADOUTS:
			var opening = Campaign.new()
			opening.profile.unlocks = Data.LOADOUTS.keys()
			opening.start(gun, 731042, 0, loadout)
			check(opening.enter(101), "unlocked starting loadout enters legally")
			for id in Data.opening_pair(opening.model.s):
				check(opening.model.s.hand.has(id), "lesson uses rounds actually owned by " + gun + "/" + loadout)
	for gun in Ammo.GUNS:
		for seed_value in range(24):
			var campaign = Campaign.new()
			campaign.start(gun, seed_value)
			check(campaign.s.credits == 30, "new run funds first part")
			var deck: Array = campaign.model.s.deck.duplicate()
			check(campaign.enter(101), "opening entry")
			check(campaign.model.s.deck == deck, "opening assistance never creates rounds")
			var wanted: Array = ["bore", "push"] if gun == "heavy" else ["charge", "precise"]
			for id in wanted: check(campaign.model.s.hand.has(id), "opening has legal example " + gun + "/" + id)
			var random_state: String = campaign.model.s.rng_state
			var inventory: String = JSON.stringify(campaign.model.s)
			Data.prepare_opening_hand(campaign.model)
			check(JSON.stringify(campaign.model.s) == inventory and campaign.model.s.rng_state == random_state, "opening preparation idempotent and RNG inert")
			check(Model.new().restore_state(campaign.model.s), "guided opening preserves inventory validation")
			var node_list := Data.nodes(0, seed_value)
			var first: Dictionary = node_list.filter(func(n): return n.id == 101)[0]
			var second: Dictionary = node_list.filter(func(n): return n.id == 201)[0]
			var third: Dictionary = node_list.filter(func(n): return n.id == 302)[0]
			var opening := Data.encounter(first, seed_value, gun, 0, 0)
			check(opening.all(func(e): return int(e.def) == 0 and not e.has("weakness") and not e.has("barrier")), "one opening concept")
			check(Data.encounter(second, seed_value, gun, 0, 0).any(func(e): return int(e.def) == 3), "second combat introduces armor")
			check(Data.rewards(first, seed_value).has("pierce"), "armor tool offered before armor")
			check(Data.encounter(third, seed_value, gun, 0, 0).any(func(e): return e.has("weakness")), "third combat introduces electric target")
			var left_reward: int = campaign.credit_reward()
			var other = Campaign.new()
			other.start(gun, seed_value)
			other.enter(102)
			check(other.credit_reward() == left_reward + Data.ROUTE_REWARD_BONUS and int(other.model.s.enemies[0].distance) == int(opening[0].distance) - 2, "duct risk has an explicit credit trade")
			var seen: Array = []
			for revision in range(10):
				var offers := Data.offers({"id": 401, "region": 0}, seed_value, revision, gun, [], seen)
				for offer in offers:
					if offer.type != "part": continue
					if seen.size() < Data.eligible_parts(gun).size(): check(not seen.has(offer.id), "all eligible unseen parts precede repeats")
					if not seen.has(offer.id): seen.append(offer.id)
				if revision == 0:
					check(not Ammo.is_core_part(offers[1].id) and not Ammo.is_core_part(offers[2].id), "first shelf teaches modules before cores")
					check(Guide.family(offers[1].id) != Guide.family(offers[2].id), "first shelf offers different build roles")
			check(seen.size() == Data.eligible_parts(gun).size(), "all parts remain obtainable")
	var campaign = shop()
	check(campaign.buy(1) and campaign.s.credits == 0 and campaign.equipped_parts().size() == 1, "first part affordable without choosing every credit reward")
	var untouched := JSON.stringify(campaign.s)
	check(not campaign.buy(2) and JSON.stringify(campaign.s) == untouched, "insufficient purchase is inert")
	campaign = shop()
	campaign.s.credits = 100
	for cost in [3, 5, 7, 9, 9]:
		var before: int = campaign.s.credits
		check(campaign.reroll_cost() == cost and campaign.reroll(), "advertised reroll cost")
		check(campaign.s.credits == before - cost and int(campaign.s.log.back().detail.cost) == cost, "reroll charged exactly once")
	var restore = Campaign.new()
	check(restore.restore_state({"campaign": campaign.s, "combat": campaign.model.s, "profile": campaign.profile}), "reroll state restores")
	if not restore.s.is_empty(): check(restore.reroll_cost() == 9 and restore.s.offers == campaign.s.offers, "restore never grants a free refresh")
	campaign.s.credits = campaign.reroll_cost() - 1
	untouched = JSON.stringify(campaign.s)
	check(not campaign.reroll() and JSON.stringify(campaign.s) == untouched, "insufficient refresh preserves stock and money")
	var model = Model.new()
	model.start("burst", 17)
	model.s.equipped_parts = ["reserve"]
	model.begin_encounter()
	check(model.s.exchange_left == 2, "reserve now expands actual choices")
	check(model.exchange(str(model.s.hand[0])) and model.exchange(str(model.s.hand[0])) and not model.exchange(str(model.s.hand[0])), "two legal exchanges then reject third")
	check(model.load_round("basic") and model.confirm() and model.reload_magazine(), "legal refill cycle")
	check(model.s.exchange_left == 2 and Model.new().restore_state(model.s), "reserve budget refills and saves")
	for reserve_equipped in [false, true]:
		var search = Model.new()
		search.start("burst", 17)
		search.s.equipped_parts = ["reserve"] if reserve_equipped else []
		search.begin_encounter()
		search.s.hand = ["bore", "push", "pierce", "arc", "precise"]
		search.s.draw = ["bore", "charge", "pierce"]
		search.s.discard = []
		search.s.deck = search.s.hand + search.s.draw
		check(Model.new().restore_state(search.s), "comparison uses an owned legal inventory")
		check(search.exchange("bore") and not search.s.hand.has("charge"), "one exchange alone does not find the combo piece")
		check(search.exchange("push") == reserve_equipped, "only reserve can search again in this magazine")
		check(search.s.hand.has("charge") == reserve_equipped, "extra exchange opens a different legal combination")
		if reserve_equipped:
			check(search.load_round("charge") and search.load_round("precise") and search.confirm() and search.fire(), "newly found combo can actually fire")
	campaign = shop()
	campaign.s.parts = ["reserve"]
	campaign.equip("reserve")
	campaign.model.s.exchange_left = 2
	check(campaign.equip("reserve") and int(campaign.model.s.exchange_left) == 1, "unequip clamps budget for valid saves")
	check(Campaign.new().restore_state({"campaign": campaign.s, "combat": campaign.model.s, "profile": campaign.profile}), "unequipped build restores")
	var old_source = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://").path_join("../qa_runtime/city/campaign_macro_uiux/city_campaign_report.json")))
	if old_source is Dictionary:
		for previous in old_source.get("runs", []):
			check(Campaign.new().restore_state({"campaign": previous.campaign, "combat": previous.combat, "profile": previous.profile}), "previous completed campaign remains loadable " + str(previous.gun))
	var report := {"checks": checks, "failures": failures, "seed_count": 24, "guns": 5}
	FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("progression_rules.json"), FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("PROGRESSION RULES COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
