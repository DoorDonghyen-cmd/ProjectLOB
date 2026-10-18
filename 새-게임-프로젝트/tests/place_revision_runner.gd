extends SceneTree
const Campaign = preload("res://redesign/campaign.gd")
const Data = preload("res://redesign/campaign_content.gd")
const Ammo = preload("res://redesign/content.gd")
var checks := 0
var failures := 0

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + label)

func roundtrip(c):
	check(c.save("user://place_probe.json") == OK, "atomic save " + str(c.s.phase))
	var loaded = Campaign.new()
	var restored: bool = loaded.restore("user://place_probe.json")
	check(restored, "restore " + str(c.s.phase) + "/" + str(c.s.encounter))
	if restored:
		check(JSON.stringify(JSON.parse_string(JSON.stringify(c.s))) == JSON.stringify(loaded.s), "campaign state exact roundtrip")
		check(c.choices() == loaded.choices(), "same connected choices")
	return loaded if restored else c

func clear_fixture(c) -> void:
	# Only campaign transition fixtures, not claimed as gameplay victories.
	for enemy in c.model.s.enemies: enemy.hp = 0
	c.model.s.reinforcements = []
	c.model.s.phase = "reward"
	c.sync_combat()

func finish_room(c) -> void:
	if c.s.phase == "combat": clear_fixture(c)
	while c.s.phase == "reward":
		var parts: Array = c.part_rewards()
		check(c.reward(str(parts[0]) if not parts.is_empty() else "credits"), "take reward")
	if c.s.phase == "gate": c.gate("credits")
	if c.s.phase in ["supply", "event"] and not c.s.resolved: c.resolve("skip")
	if c.s.phase in ["shop", "supply", "event", "bypass"]: c.leave()

func at_room(seed_value: int, kind: String, event_kind: String = "", version: int = 3, target_id: int = 0):
	var c = Campaign.new()
	c.start("burst", seed_value, 0, "balanced", version)
	c.advance_departure(true)
	var rooms: Array = c.current_nodes()
	var parents := {}
	for room in rooms:
		if int(room.floor) == 1: parents[int(room.id)] = 0
		for next_id in room.next:
			if not parents.has(int(next_id)): parents[int(next_id)] = int(room.id)
	var targets: Array = rooms.filter(func(n): return n.id == target_id if target_id > 0 else Data.room_kind(n) == kind and (event_kind.is_empty() or n.event == event_kind))
	if targets.is_empty(): return null
	var path: Array = []
	var id: int = targets[0].id
	while id != 0:
		path.push_front(id)
		id = parents[id]
	for step in path:
		finish_room(c)
		check(c.enter(step), "enter connected path")
	return c

func map_checks() -> void:
	var old_hashes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/place_v2_graph_hashes.json"))
	for region in range(5):
		for seed_value in range(40):
			var legacy: Array = Data.RouteMap.generate(region, seed_value, 2)
			check(JSON.stringify(legacy).sha256_text() == old_hashes["%d:%d" % [region, seed_value]], "v2 graph unchanged")
			var rooms: Array = Data.RouteMap.generate(region, seed_value)
			check(rooms == Data.RouteMap.generate(region, seed_value), "stable seeded graph")
			check(rooms.filter(func(n): return n.floor == 1).size() == 4, "four starting routes")
			check(rooms.filter(func(n): return n.kind == "boss").size() == 1, "one mandatory gate")
			check(rooms.filter(func(n): return n.kind == "bypass").is_empty(), "no bypass room")
			var shortcuts := 0
			for room in rooms:
				for dest in room.shortcuts:
					shortcuts += 1
					var target: Dictionary = rooms.filter(func(n): return n.id == dest)[0]
					check(target.floor == room.floor + 2 and room.floor >= 2, "shortcut skips one after opening")
					var middles: Array = rooms.filter(func(n): return room.next.has(n.id) and n.next.has(dest) and n.floor == room.floor + 1 and n.kind == "combat" and not n.elite)
					check(not middles.is_empty() and target.kind != "boss", "shortcut only skips ordinary battle")
			check(shortcuts <= 1, "at most one shortcut per region")
	var sample := Data.nodes(0, 17, 3)
	var origin: Dictionary = sample.filter(func(n): return not n.shortcuts.is_empty())[0]
	var reached = at_room(17, "", "", 3, int(origin.id))
	finish_room(reached)
	var clears_before: int = reached.s.clears
	var credits_before: int = reached.s.credits
	check(reached.enter(int(origin.shortcuts[0])), "explicit shortcut traversable")
	check(reached.s.clears == clears_before and reached.s.credits == credits_before, "explicit skip no rewards")
	roundtrip(reached)
	# Traverse all five regions, always using a shortcut when available; validate
	# skipped nodes never award clears or rewards and serialized history accepts edges.
	var c = Campaign.new()
	c.start("burst", 731042)
	var guard := 0
	var skipped := 0
	while c.s.phase != "won" and guard < 120:
		guard += 1
		if c.s.phase == "map":
			var options: Array = c.choices()
			check(not options.is_empty(), "route never dead ends")
			if options.is_empty(): break
			var choice: Dictionary = options[0]
			for option in options:
				if c.is_shortcut(option.id): choice = option
			var is_short: bool = c.is_shortcut(choice.id)
			var clears: int = c.s.clears
			var credits: int = c.s.credits
			check(c.enter(choice.id), "enter v3 room")
			if is_short:
				skipped += 1
				check(c.s.clears == clears and c.s.credits == credits, "skip grants nothing")
		else: finish_room(c)
		c = roundtrip(c)
	check(c.s.phase == "won", "all five region gates reachable")
	check(c.s.visited.size() == c.total_floors() - skipped, "actual visits exclude skipped fights")

func workshop_checks() -> void:
	for mode in ["power", "cool"]:
		var c = at_room(17, "workshop")
		c.s.credits = 0
		var original: String = c.model.s.deck[3]
		var count: int = c.model.s.deck.size()
		check(not c.resolve("core"), "workshop cannot refill charges")
		check(not c.tune(-1, mode) and not c.s.resolved, "invalid tune does not spend operation")
		check(c.tune(3, mode) and c.s.resolved and c.s.credits == 0, "free workshop tune")
		check(c.model.s.deck.size() == count and c.model.s.deck[3] == Ammo.Variants.tuned(original, Ammo.AMMO, mode), "one exact copy tuned")
		check(not c.tune(4, "power") and not c.resolve("bag") and not c.resolve("compress", original), "one operation across services")
		roundtrip(c)
	for action in ["compress", "remove", "bag"]:
		var c = at_room(17, "workshop")
		var source: String = c.compressible_ids()[0]
		check(c.resolve(action, source), "workshop " + action)
		check(not c.tune(3, "power") and not c.resolve(action, source), "operation cannot repeat")
		roundtrip(c)
	var shop = at_room(17, "shop")
	shop.s.credits = 100
	check(not shop.tune(3, "power") and not shop.shop_compress(str(shop.compressible_ids()[0])), "new shop cannot tune/compress")
	check(shop.buy_compressor_charge() and not shop.buy_compressor_charge(), "shop charge one purchase")
	check(shop.reroll() and not shop.buy_compressor_charge(), "reroll preserves charge limit")
	roundtrip(shop)
	var old = at_room(17, "shop", "", 2)
	old.s.credits = 100
	check(old.tune(3, "power") and old.s.credits == 88, "v2 shop priced tune retained")
	check(old.shop_compress(str(old.compressible_ids()[0])), "v2 shop compression retained")
	roundtrip(old)

func supply_checks() -> void:
	var c = at_room(17, "supply")
	check(c.reward_options().size() == 3 and c.model.s.deck.has(c.reward_options()[0]), "basic-only deck also has matching material")
	c.model.s.deck[0] = "pierce_p2_cool"
	c.model.s.deck[1] = Ammo.compressed_id("basic_p2")
	c.s.supply_offers = c._supply_options()
	var offers: Array = c.reward_options()
	check(offers[0] == "pierce_p2_cool", "supply matches exact ordinary tuned profile")
	check(offers.size() == 3, "matching ingredient plus discoveries")
	var loaded = roundtrip(c)
	check(loaded.reward_options() == offers, "supply offers stable across restore")
	while c.model.s.deck.size() < 14: c.model.s.deck.append("basic_p2")
	check(not c.resolve("ammo", str(offers[0])) and not c.s.resolved, "full bag cannot add")
	check(c.resolve("ammo", str(offers[0]), "basic_p2") and c.model.s.deck.size() == 14, "full bag can replace basic")
	check(c.model.s.deck.count("pierce_p2_cool") == 2, "matching pair acquired")
	check(not c.resolve("ammo", str(offers[1])), "supply one choice only")
	roundtrip(c)

func encounter_checks() -> void:
	var types := {}
	for kind in ["siphon", "archive", "salvage"]:
		for seed_value in range(1, 20):
			var c = at_room(seed_value, "event", kind)
			if c == null: continue
			for option in c.encounter_scene().choices:
				var fork = roundtrip(c)
				fork.s.credits = 30
				var previous: int = fork.s.credits
				check(fork.resolve("encounter", str(option.id)), "clue choice accepted")
				var outcome: Dictionary = Campaign.Encounters.outcome(kind, option.id, int(fork.s.seed), int(fork.s.node))
				types[kind + ":" + str(outcome.type)] = true
				check(fork.profile.lore.has(2), "lore accompanies actual interaction")
				check(not fork.resolve("encounter", str(option.id)), "cannot reroll event")
				fork = roundtrip(fork)
				var serialized: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://place_probe.json"))
				var damaged: Dictionary = serialized.duplicate(true)
				damaged.campaign.encounter.stage = "paid_twice"
				check(not Campaign.new().restore_state(damaged), "unknown event checkpoint rejected")
				damaged = serialized.duplicate(true)
				damaged.campaign.encounter.choice = "missing"
				check(not Campaign.new().restore_state(damaged), "unknown event choice rejected")
				if fork.s.encounter.stage == "ambush":
					check(not fork.leave() and not fork.resolve("skip"), "ambush cannot vanish on exit")
					check(fork.resolve("fight"), "ambush enters normal combat")
					check(fork.model.s.phase == "plan" and fork.model.s.heat == 0 and not fork.model.s.hand.is_empty(), "ambush fair planning phase")
					check(fork.model.s.enemies.all(func(e): return e.distance > 0), "ambush no immediate contact")
					fork = roundtrip(fork)
					var losing = roundtrip(fork)
					losing.model.s.phase = "lost"
					losing.sync_combat()
					roundtrip(losing)
					clear_fixture(fork)
					check(fork.s.credits == previous - int(option.cost) + int(outcome.bonus), "scene loot awarded in addition to ordinary reward")
					var once: int = fork.s.credits
					fork.sync_combat()
					check(fork.s.credits == once, "loot exactly once")
					fork = roundtrip(fork)
					check(fork.reward("skip"), "event victory returns to map")
				elif fork.s.encounter.stage == "loot":
					var before: int = fork.model.s.deck.size()
					check(fork.resolve("ammo", str(fork.reward_options()[0])), "event loot selected after reveal")
					check(fork.model.s.deck.size() == before + 1, "event grants one ammo")
					check(fork.leave(), "leave revealed scene")
				else: check(fork.leave(), "leave friendly scene")
				fork = roundtrip(fork)
				check(fork.s.phase == "map" and not fork.choices().is_empty(), "event route resumes")
			if c.encounter_scene().choices[0].cost > 0:
				c.s.credits = 0
				var before: Dictionary = c.s.duplicate(true)
				check(not c.resolve("encounter", str(c.encounter_scene().choices[0].id)) and c.s == before, "insufficient credits inert")
			c.resolve("skip")
			c = roundtrip(c)
			check(c.leave(), "decline event")
	check(types.size() == 7, "all seven scene outcome categories exercised: " + str(types))

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/place_revision/"): quit(2); return
	map_checks()
	workshop_checks()
	supply_checks()
	encounter_checks()
	print("PLACE RULES COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
