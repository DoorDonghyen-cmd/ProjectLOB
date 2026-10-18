extends SceneTree
const Campaign = preload("res://redesign/campaign.gd")
const Data = preload("res://redesign/campaign_content.gd")
var checks := 0
var failures: Array = []
var metrics: Array = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		printerr("FAIL: " + label)

func roundtrip(c):
	check(c.save("user://map_probe.json") == OK, "save " + str(c.s.phase))
	var loaded = Campaign.new()
	check(loaded.restore("user://map_probe.json"), "restore " + str(c.s.phase))
	check(JSON.stringify(JSON.parse_string(JSON.stringify(c.s))) == JSON.stringify(loaded.s), "exact map persistence")
	check(c.choices() == loaded.choices(), "same next rooms after restore")
	return loaded

func clear_fixture(c) -> void:
	# Flow fixture only. Real combat uses the campaign solver in a separate suite.
	for enemy in c.model.s.enemies: enemy.hp = 0
	c.model.s.reinforcements = []
	c.model.s.phase = "reward"
	c.sync_combat()

func service_guards() -> void:
	var c = Campaign.new()
	c.start("burst", 17)
	var workshop: Dictionary = c.current_nodes().filter(func(n): return n.get("workshop", false))[0]
	c.s.node = workshop.id
	c.s.floor = workshop.floor
	c.s.phase = "supply"
	c.s.resolved = false
	check(not c.resolve("ammo", "pierce"), "workshop cannot grant normal supply too")
	check(not c.resolve("compress", "missing") and not c.resolve("remove", "missing"), "invalid workshop target inert")
	c.s.compressor_charges = 2
	check(not c.resolve("core") and not c.s.resolved, "full core stock does not spend service")
	c.model.s.deck = c.model.s.deck.slice(0, 8)
	check(not c.resolve("remove", str(c.model.s.deck[0])) and not c.resolve("compress", "charge"), "both mutations preserve minimum eight")
	check(c.resolve("skip") and not c.resolve("core"), "skip closes one-time service")
	c = Campaign.new()
	c.start("burst", 17, 0, "balanced", 1)
	c.enter(101)
	c.save("user://map_probe.json")
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://map_probe.json"))
	old.campaign.erase("map_version")
	var restored = Campaign.new()
	check(restored.restore_state(old) and restored.total_floors() == 35 and restored.model.s.phase == "plan", "unversioned mid-combat legacy save remains playable")
	old.campaign.map_version = 99
	check(not Campaign.new().restore_state(old), "unsupported map version rejected")

func journey(seed_value: int, preference: String, version: int = 2) -> void:
	var c = Campaign.new()
	c.start("burst", seed_value, 0, "balanced", version)
	c.advance_departure(true)
	var guard := 0
	while c.s.phase != "won" and guard < 250:
		guard += 1
		match str(c.s.phase):
			"map":
				var choices: Array = c.choices()
				check(not choices.is_empty(), "map never dead-ends")
				if choices.is_empty(): break
				var room: Dictionary = choices[0]
				for candidate in choices:
					if Data.room_kind(candidate) == preference: room = candidate
				check(c.enter(int(room.id)), "enter real connected room")
			"combat": clear_fixture(c)
			"reward":
				var parts: Array = c.part_rewards()
				check(c.reward(str(parts[0]) if not parts.is_empty() else "credits"), "reward selection")
			"gate": check(c.gate("slot" if int(c.s.slots) < 2 else "credits"), "region transition")
			"shop", "bypass": check(c.leave(), "leave facility")
			"supply", "event":
				if c.node().get("workshop", false):
					var ids: Array = c.compressible_ids()
					var action := "compress" if not ids.is_empty() else ("core" if int(c.s.compressor_charges) < 2 else "skip")
					check(c.resolve(action, str(ids[0]) if not ids.is_empty() else ""), "workshop action")
					var prior: String = JSON.stringify(c.s)
					check(not c.resolve("core") and JSON.stringify(c.s) == prior, "workshop cannot pay twice")
				else: check(c.resolve("skip"), "optional service")
				check(c.leave(), "leave resolved service")
		c = roundtrip(c)
	check(c.s.phase == "won" and c.absolute_floor() == c.total_floors(), "full " + str(c.total_floors()) + " floor journey")
	check(c.s.visited.size() == c.total_floors(), "one room per floor")
	if version == 1:
		var old := {"campaign": c.s.duplicate(true), "combat": c.model.s.duplicate(true), "profile": c.profile.duplicate(true)}
		old.campaign.erase("map_version")
		var migrated = Campaign.new()
		check(migrated.restore_state(old) and migrated.total_floors() == 35 and migrated.current_nodes() == c.current_nodes(), "unversioned legacy winner keeps old map")

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/maps/"):
		printerr("Map QA requires isolated storage")
		quit(2)
		return
	for region in range(5):
		var layouts: Dictionary = {}
		var connections: Dictionary = {}
		var facilities: Dictionary = {}
		var minimum_paths := 999999
		var max_paths := 0
		var combats := [999, 0]
		for seed_value in range(100):
			var rooms := Data.nodes(region, seed_value, 2)
			check(rooms == Data.nodes(region, seed_value, 2), "deterministic seed")
			check(rooms.filter(func(n): return int(n.floor) == 1).size() == 4, "four starting choices")
			var ways: Dictionary = {}
			var counts: Dictionary = {}
			var topology: Array = []
			for room in rooms:
				var incoming := rooms.filter(func(n): return n.next.has(room.id))
				check(int(room.floor) == 1 or not incoming.is_empty(), "every room reachable")
				check(room.kind == "boss" or not room.next.is_empty(), "every room has exit")
				check(room.kind != "boss" or room.next.is_empty(), "boss terminates region")
				ways[room.id] = 1 if int(room.floor) == 1 else 0
				var is_fight := 1 if room.kind in ["combat", "boss"] else 0
				counts[room.id] = [is_fight, is_fight] if incoming.is_empty() else [999, 0]
				for previous in incoming:
					check(int(previous.floor) + 1 == int(room.floor), "edges advance exactly one floor")
					ways[room.id] += int(ways[previous.id])
					counts[room.id][0] = mini(int(counts[room.id][0]), int(counts[previous.id][0]) + is_fight)
					counts[room.id][1] = maxi(int(counts[room.id][1]), int(counts[previous.id][1]) + is_fight)
				topology.append([room.id, room.next, Data.room_kind(room)])
				for other in rooms:
					if other.floor != room.floor: continue
					for a in room.next:
						for b in other.next:
							check((int(room.lane) - int(other.lane)) * (int(a) % 100 - int(b) % 100) >= 0, "corridors do not cross")
			var last: Dictionary = rooms.back()
			minimum_paths = mini(minimum_paths, int(ways[last.id]))
			max_paths = maxi(max_paths, int(ways[last.id]))
			combats[0] = mini(int(combats[0]), int(counts[last.id][0]))
			combats[1] = maxi(int(combats[1]), int(counts[last.id][1]))
			layouts[JSON.stringify(topology)] = true
			connections[JSON.stringify(rooms.map(func(n): return [n.id, n.next]))] = true
			facilities[JSON.stringify(rooms.map(func(n): return [n.id, Data.room_kind(n)]))] = true
		check(layouts.size() >= 95, "seed diversity")
		check(connections.size() >= 90 and facilities.size() >= 90, "both geometry and facility layouts vary")
		check(minimum_paths >= 16, "meaningful route breadth")
		metrics.append({"region": region, "floors": Data.info(region, 2).floors, "layouts_per_100": layouts.size(), "connections_per_100": connections.size(), "facilities_per_100": facilities.size(), "path_range": [minimum_paths, max_paths], "combat_range": combats})
		print("MAP REGION " + JSON.stringify(metrics.back()))
	for seed_value in [17, 731042, 90210]:
		for preference in ["shop", "workshop", "elite"]: journey(seed_value, preference)
	journey(731042, "shop", 1)
	service_guards()
	# A disconnected jump must be rejected both by input and by restored history.
	var c = Campaign.new()
	c.start("single", 17)
	check(not c.enter(401), "cannot jump floors")
	check(c.enter(104), "fourth starting room legal")
	clear_fixture(c)
	c.reward("credits")
	var blocked := c.current_nodes().filter(func(n): return int(n.floor) == 2 and not c.node().next.has(n.id))
	if not blocked.is_empty():
		check(not c.enter(int(blocked[0].id)), "cannot traverse missing edge")
		c.save("user://map_probe.json")
		var forged: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://map_probe.json"))
		forged.campaign.visited.append(blocked[0].id)
		forged.campaign.node = blocked[0].id
		forged.campaign.floor = 2
		check(not Campaign.new().restore_state(forged), "forged path rejected")
	var report := {"checks": checks, "failures": failures, "regions": metrics}
	var file := FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("map_rules.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("MAP RULES COMPLETE checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
