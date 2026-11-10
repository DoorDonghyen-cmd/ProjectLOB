extends SceneTree
## Diagnostic only: uses the shipping generator, never modifies its graph or saves.
const Data = preload("res://redesign/campaign_content.gd")
const Campaign = preload("res://redesign/campaign.gd")
var checks := 0
var failures: Array = []

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func measure(rooms: Array, allow_shortcuts: bool) -> Dictionary:
	var state: Dictionary = {}
	for room in rooms:
		var cost := 1 if room.kind == "combat" else 0 # Gate is counted separately.
		var value := {"min":999, "max":-1, "path":[], "hist":{}}
		if int(room.floor) == 1:
			value = {"min":cost, "max":cost, "path":[room], "hist":{cost:1}}
		else:
			for prior in rooms:
				if not prior.next.has(room.id): continue
				if not allow_shortcuts and prior.get("shortcuts", []).has(room.id): continue
				check(state.has(prior.id), "forward edge")
				var before: Dictionary = state[prior.id]
				if int(before.min) + cost < int(value.min):
					value.min = int(before.min) + cost
					value.path = before.path + [room]
				value.max = maxi(int(value.max), int(before.max) + cost)
				for n in before.hist:
					value.hist[int(n)+cost] = int(value.hist.get(int(n)+cost, 0)) + int(before.hist[n])
		check(int(value.max) >= 0, "every node reachable")
		state[room.id] = value
	var end: Dictionary = state[rooms.back().id]
	var total := 0
	var sparse := 0
	for n in end.hist:
		total += int(end.hist[n])
		if int(n) <= 2: sparse += int(end.hist[n])
	return {"min":end.min, "max":end.max, "path":end.path.map(func(n): return {"id":n.id,"floor":n.floor,"kind":Data.room_kind(n)}), "path_count":total, "paths_le_two":sparse}

func flow_probe(seed_value: int, path: Array) -> void:
	# State-transition fixture: combat victories are simulated, not a gameplay win claim.
	var c = Campaign.new()
	c.start("single", seed_value, 0, "balanced", 3, "carrier", true)
	c.advance_departure(true)
	check(not c.enter(int(path.back().id)), "gate cannot be entered directly")
	var fights := 0
	for room in path:
		check(c.choices().any(func(n): return int(n.id)==int(room.id)), "path offered by Campaign.choices")
		check(c.enter(int(room.id)), "path enter accepted")
		if room.kind == "boss": break
		if c.s.phase == "combat":
			fights += 1
			for enemy in c.model.s.enemies: enemy.hp = 0
			c.model.s.reinforcements = []
			c.model.s.phase = "reward"
			c.sync_combat()
			var reward_guard := 0
			while c.s.phase == "reward" and reward_guard < 8:
				reward_guard += 1
				check(c.reward("credits"), "skip reward fixture")
		else:
			if c.s.phase in ["supply", "event"]: check(c.resolve("skip"), "optional location can be skipped")
			check(c.leave(), "noncombat location can be left")
		check(c.s.phase == "map", "return to map")
		check(c.save("user://density_probe.json") == OK, "save route fixture")
		var loaded = Campaign.new()
		check(loaded.restore("user://density_probe.json"), "restore route fixture")
		check(c.choices() == loaded.choices(), "restore preserves choices")
	check(fights == 2 and c.s.phase == "combat" and c.node().kind == "boss", "two fights lead to gate battle")

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/maps/route_density_"):
		quit(2)
		return
	var result := {"map_version":3,"seeds":"0..999 inclusive per region","seed_count":1000,"gate_counted_as_combat":false,"event_assumption":"Skip is legal; optional ambush is not a guaranteed fight.","regions":[]}
	var probe: Dictionary = {}
	for region in range(5):
		var summary := {"region":region+1,"name":Data.info(region,3).name,"floors":Data.info(region,3).floors,"with_shortcuts":{},"without_shortcuts":{},"shortcut_lowers_minimum":0,"example":{}}
		for mode in ["with_shortcuts", "without_shortcuts"]:
			summary[mode] = {"minimum_histogram":{},"maximum_histogram":{},"maps_le_two":0,"path_count":0,"paths_le_two":0}
		for seed_value in range(1000):
			var rooms := Data.nodes(region, seed_value, 3)
			var measures: Array = []
			for allow in [true,false]:
				var value := measure(rooms,allow)
				measures.append(value)
				var stat: Dictionary = summary["with_shortcuts" if allow else "without_shortcuts"]
				for metric in ["min","max"]:
					var hist: Dictionary = stat["minimum_histogram" if metric=="min" else "maximum_histogram"]
					hist[value[metric]] = int(hist.get(value[metric],0))+1
				if int(value.min)<=2: stat.maps_le_two += 1
				stat.path_count += int(value.path_count)
				stat.paths_le_two += int(value.paths_le_two)
			if int(measures[0].min)<int(measures[1].min):summary.shortcut_lowers_minimum += 1
			if summary.example.is_empty() and int(measures[1].min)<=(2 if region==0 else 1):
				summary.example = {"seed":seed_value,"without_shortcuts":measures[1]}
				if region==0: probe=summary.example
		var typical := Data.nodes(region,731042,3)
		summary["seed_731042"] = {"with_shortcuts":measure(typical,true),"without_shortcuts":measure(typical,false)}
		result.regions.append(summary)
		print("DENSITY " + JSON.stringify(summary))
	if not probe.is_empty(): flow_probe(int(probe.seed),probe.without_shortcuts.path)
	result["flow_probe"]={"seed":probe.get("seed",-1),"method":"Campaign choices/enter/skip/leave/save/restore; simulated combat victories"}
	result["checks"]=checks
	result["failures"]=failures
	var file := FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("density.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	print("ROUTE DENSITY COMPLETE checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
