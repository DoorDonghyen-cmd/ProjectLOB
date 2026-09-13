extends SceneTree
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
var report := {"scope": "Actual model, first magazine only; later floors use starting-deck fixtures, not campaign progression. Order sensitivity is not a fun score.", "seeds": 256, "hands": {}, "fixtures": [], "examples": []}
var plans: Array = []

func _initialize() -> void:
	_run.call_deferred()

func enumerate(hand: Array, plan: Array) -> void:
	if plan.size() == 4:
		plans.append(plan.duplicate())
		return
	for id in ["basic"] + hand:
		if plan.count(id) < (3 if id == "basic" else 1):
			plan.append(id)
			enumerate(hand, plan)
			plan.pop_back()

func resolve(state: Dictionary, firing_order: Array) -> Dictionary:
	var m = Model.new()
	m.s = state.duplicate(true)
	var loading: Array = firing_order.duplicate()
	loading.reverse()
	for id in loading:
		assert(m.load_round(id))
	assert(m.confirm())
	while m.s.phase == "ready" and not m.s.magazine.is_empty():
		assert(m.fire())
	var hp: Array = []
	var distance: Array = []
	for e in m.s.enemies:
		hp.append(e.hp)
		distance.append(e.distance)
	return {"hp": hp, "distance": distance, "phase": m.s.phase, "turns": m.s.turns, "shots": m.s.shots}

func _run() -> void:
	for seed in range(256):
		var m = Model.new()
		m.start("single", seed)
		var hand: Array = m.s.hand.duplicate()
		hand.sort()
		var key := str(hand)
		report.hands[key] = int(report.hands.get(key, 0)) + 1
	for gun in ["single", "burst"]:
		for floor_index in [0, 1, 2, 3, 6]:
			for missing in Content.START_DECK:
				var m = Model.new()
				m.start(gun, 0)
				m.s.floor = floor_index
				m.begin_encounter()
				m.s.hand = Content.START_DECK.duplicate()
				m.s.hand.erase(missing)
				m.s.draw = [missing]
				plans.clear()
				enumerate(m.s.hand, [])
				var groups := {}
				var wins := 0
				for order in plans:
					var sorted: Array = order.duplicate()
					sorted.sort()
					var key := str(sorted)
					if not groups.has(key): groups[key] = {"hp": {}, "end": {}}
					var result := resolve(m.s, order)
					groups[key].hp[str(result.hp)] = true
					groups[key].end[JSON.stringify(result)] = true
					if result.phase in ["reward", "won"]: wins += 1
				var hp_sensitive := 0
				var end_sensitive := 0
				for group in groups.values():
					if group.hp.size() > 1: hp_sensitive += 1
					if group.end.size() > 1: end_sensitive += 1
				report.fixtures.append({"gun": gun, "floor": floor_index + 1, "missing": missing, "plans": plans.size(), "multisets": groups.size(), "hp_sensitive": hp_sensitive, "end_sensitive": end_sensitive, "winning_plans": wins})
	for gun in ["single", "burst"]:
		for item in [[0, ["basic", "basic", "basic"]], [1, ["bore", "basic"]], [1, ["basic", "bore"]], [1, ["charge", "bore", "basic"]], [1, ["bore", "charge", "basic"]]]:
			var m = Model.new()
			m.start(gun, 0)
			m.s.floor = item[0]
			m.begin_encounter()
			m.s.hand = ["bore", "charge", "pierce", "mark", "precise"]
			m.s.draw = ["push"]
			report.examples.append({"gun": gun, "floor": item[0]+1, "firing_order": item[1], "result": resolve(m.s, item[1])})
	var output := OS.get_environment("ORDER_PROBE_OUTPUT")
	var file := FileAccess.open(output, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("ORDER PROBE DONE: ", report.fixtures.size(), " fixtures; unique initial hands=", report.hands.size())
	quit()
