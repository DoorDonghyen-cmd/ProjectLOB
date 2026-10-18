extends "res://tests/heat_rules_runner.gd"

func service(outfit: String = "work", region: int = 0):
	var c = Campaign.new()
	c.start("single", 731042, 0, "balanced", 2, outfit)
	c.s.region = region
	var room: Dictionary = c.current_nodes().filter(func(n): return n.get("workshop", false))[0]
	c.s.floor = room.floor
	c.s.node = room.id
	c.s.phase = "supply"
	c.s.resolved = false
	return c

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/bag_growth/rules"):
		quit(1)
		return
	check(Ammo.hand_capacity({"outfit": "work", "bag_version": 2, "bag_upgrades": 0}) == 5, "default starts five")
	for outfit in Ammo.OUTFITS:
		for gun in Ammo.GUNS:
			var c = service(outfit)
			var base: int = Ammo.OUTFITS[outfit].hand
			check(c.resolve("bag") == (base < 6), "opening cap six")
			var state := JSON.stringify(c.s)
			check(not c.resolve("bag") and state == JSON.stringify(c.s), "one workbench choice prevents duplicate growth")
			var m = Model.new()
			m.start(gun, 731042, false, outfit)
			m.s.bag_upgrades = 10 - base
			m.begin_encounter()
			check(m.s.hand.size() == 10 and m.s.draw.is_empty(), "max bag draws all ten owned rounds")
			check(Model.new().restore_state(m.s), "ten-round model saves")
			var invalid: Dictionary = m.s.duplicate(true)
			invalid.bag_upgrades += 1
			check(not Model.new().restore_state(invalid), "reject overflow upgrades")
			invalid.bag_upgrades = -1
			check(not Model.new().restore_state(invalid), "reject negative upgrade")
			invalid.bag_upgrades = 0.5
			check(not Model.new().restore_state(invalid), "reject fractional upgrade")
		# Trace a real connected route favoring workbenches; combat outcomes are fixtures.
		var run = Campaign.new()
		run.start("single", 731042, 0, "balanced", 2, outfit)
		var grew := 0
		var saved_once := false
		while run.s.phase != "won":
			var scores: Dictionary = {}
			var rooms: Array = run.current_nodes()
			rooms.reverse()
			for room in rooms:
				var best := 0
				for next_id in room.next: best = maxi(best, int(scores.get(next_id, 0)))
				scores[room.id] = best + (1 if room.get("workshop", false) else 0)
			var options: Array = run.choices()
			options.sort_custom(func(a, b): return int(scores[a.id]) > int(scores[b.id]))
			check(not options.is_empty(), "connected growth route")
			if options.is_empty(): break
			check(run.enter(int(options[0].id)), "legal route entry")
			if run.s.phase == "combat":
				for e in run.model.s.enemies: e.hp = 0
				run.model.s.reinforcements = []
				run.model.s.encounter_total = run.model.s.deployed
				run.model.s.phase = "reward"
				run.sync_combat()
				check(run.reward("skip"), "resolve combat fixture")
			if run.s.phase == "gate":
				var grow: bool = run.can_grow_bag()
				check(run.gate("bag" if grow else "credits"), "gate trades other reward for bag")
				if grow: grew += 1
			elif run.s.phase in ["supply", "event"]:
				var grow: bool = run.node().get("workshop", false) and run.can_grow_bag()
				check(run.resolve("bag" if grow else "skip"), "workbench trades service for bag")
				if grow: grew += 1
				run.s.phase = "map"
			elif run.s.phase in ["shop", "bypass"]: run.s.phase = "map"
			if not saved_once and run.s.phase == "map" and Ammo.hand_capacity(run.model.s) == 10:
				var path: String = "user://grown_" + str(outfit) + ".json"
				check(run.save(path) == OK, "grown bag file saved on real route")
				var restored = Campaign.new()
				check(restored.restore(path) and Ammo.hand_capacity(restored.model.s) == 10, "grown bag file restored")
				saved_once = true
			check(Ammo.hand_capacity(run.model.s) <= 10, "never above ten")
			if int(run.s.region) < 3: check(Ammo.hand_capacity(run.model.s) < 10, "ten not reached early")
		check(Ammo.hand_capacity(run.model.s) == 10 and grew == 10 - int(Ammo.OUTFITS[outfit].hand), "every outfit can reach ten through connected route")
		check(saved_once, "route reaches ten before final battle")
		var legacy = Campaign.new()
		legacy.start("single", 44, 0, "balanced", 2, outfit)
		for key in ["bag_version", "bag_upgrades"]:
			legacy.s.erase(key)
			legacy.model.s.erase(key)
		legacy.model.begin_encounter()
		var expected: int = Ammo.LEGACY_OUTFIT_HAND[outfit]
		check(legacy.model.s.hand.size() == expected, "previous six/seven/five kept")
		check(Campaign.new().restore_state({"campaign": legacy.s, "combat": legacy.model.s, "profile": legacy.profile}), "previous outfit campaign remains readable")
		var mixed := {"campaign": legacy.s.duplicate(true), "combat": legacy.model.s.duplicate(true), "profile": legacy.profile}
		mixed.campaign.bag_version = 2
		mixed.campaign.bag_upgrades = 0
		check(not Campaign.new().restore_state(mixed), "reject mixed growth versions")
	var cap = service("work", 0)
	cap.s.bag_upgrades = 1
	cap.model.s.bag_upgrades = 1
	var before := JSON.stringify(cap.s)
	check(not cap.resolve("bag") and JSON.stringify(cap.s) == before and not cap.s.resolved, "regional cap never spends service")
	cap = service("work", 4)
	cap.s.bag_upgrades = 5
	cap.model.s.bag_upgrades = 5
	before = JSON.stringify(cap.s)
	check(not cap.resolve("bag") and JSON.stringify(cap.s) == before, "absolute cap never spends service")

	print("BAG GROWTH RULES COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
