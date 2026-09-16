extends SceneTree
## Check real commands, conditional forecasts and persistence at rule boundaries.
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const Campaign = preload("res://redesign/campaign.gd")
const Data = preload("res://redesign/campaign_content.gd")
const Forecast = preload("res://redesign/forecast.gd")
const Readability = preload("res://redesign/readability.gd")
const Insight = preload("res://redesign/run_insight.gd")
var checks := 0
var failures: Array = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("FAIL: " + label)

func enemy(hp: int = 100, armor: int = 0, distance: int = 20) -> Dictionary:
	return {"kind": "wall", "name": Content.ENEMY_NAMES.wall, "hp": hp, "max_hp": hp, "def": armor, "speed": 1, "distance": distance, "burn": 0}

func fixture(gun: String, enemies: Array, rounds: Array = ["basic"]):
	var model = Model.new()
	model.start(gun, 731042)
	model.s.deck = ["charge", "precise", "pierce", "bore", "arc", "push"]
	model.s.hand = model.s.deck.slice(0, 5)
	model.s.draw = ["push"]
	model.s.discard = []
	model.s.enemies = enemies.duplicate(true)
	for id in rounds: check(model.load_round(id), "fixture load " + gun + "/" + id)
	return model

func fire(model) -> Dictionary:
	if model.s.phase == "plan": check(model.confirm(), "confirm fixture")
	check(model.fire(), "fire fixture")
	return model.s.history.back().detail.results[0]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for gun in Content.GUNS:
		var campaign = Campaign.new()
		campaign.start(gun, 731042)
		check(campaign.model.s.deck == Content.start_deck(gun) and campaign.model.s.deck.size() == 10, "weapon starting deck")
		campaign.profile.unlocks = Data.LOADOUTS.keys()
		for loadout in Data.LOADOUTS:
			campaign.start(gun, 731042, 0, loadout)
			check(campaign.model.s.deck == (Content.start_deck(gun) if loadout == "balanced" else Data.LOADOUTS[loadout].deck), "sidegrade available to each weapon")
		for bonus in range(3):
			campaign.model.s.capacity_bonus = bonus
			check(campaign.model.capacity() == int(Content.GUNS[gun].capacity) + bonus, "independent capacity growth")
		var seen_parts: Array = []
		for revision in range(12):
			for offer in Data.offers({"id": 401}, 731042, revision, gun, []):
				if offer.type == "part":
					check(Content.accepts_part(gun, offer.id) and offer.id != "supply", "shop never offers unsuitable part")
					if not seen_parts.has(offer.id): seen_parts.append(offer.id)
		check(seen_parts.has("loader") == (gun != "single"), "reload part actually appears in eligible shop stock")
		check(Content.accepts_part(gun, "loader") == (gun != "single"), "reload part eligibility")
		var model = fixture(gun, [enemy(), enemy(100, 1, 22), enemy(100, 2, 23)], ["charge", "precise", "arc"])
		for part in ["none", "lens", "coil", "loader"]:
			model.s.part = part
			var before := JSON.stringify(model.s)
			var prediction := Forecast.analyze(model.s)
			check(JSON.stringify(model.s) == before, "forecast never changes state or RNG")
			var actual = Model.new()
			actual.s = model.s.duplicate(true)
			check(actual.confirm(), "confirm clone")
			var shots: Array = []
			while actual.fire():
				for result in actual.s.history.back().detail.results: shots.append(result)
			check(shots.size() == prediction.shots.size(), "forecast exact shot count")
			for i in range(shots.size()):
				var expected: Dictionary = prediction.shots[i].duplicate(true)
				expected.erase("action")
				check(shots[i] == expected, "all primary and secondary forecast values exact")
			check(actual.s.enemies == prediction.enemies and actual.s.phase == prediction.phase, "forecast final state exact")
			check(Model.new().restore_state(actual.s), "gun battle state restores")
	# Spread uses each target armor and an inclusive 3m boundary.
	for distance in [22, 23, 24]:
		var model = fixture("scatter", [enemy(100, 0, 20), enemy(100, 0, distance)])
		var shot := fire(model)
		check(shot.secondary.size() == (1 if distance <= 23 else 0), "spread distance boundary " + str(distance))
		if distance <= 23: check(shot.secondary[0].damage == 2, "basic spread half damage")
	var model = fixture("scatter", [enemy(), enemy(100, 3, 22)], ["charge", "precise"])
	var first := fire(model)
	var second := fire(model)
	check(first.secondary[0].damage == 1 and second.damage == 8 and second.secondary[0].damage == 2, "boosted double spread applies both hits and secondary armor")
	check(Readability.explain(second).contains("확산") and Readability.explain(second).contains("장갑3"), "spread math exposed")
	model = fixture("scatter", [enemy(1), enemy(1, 0, 22), enemy(10, 0, 23)], ["arc"])
	var shot := fire(model)
	check(shot.secondary.size() == 3 and shot.secondary[0].hp == 0 and shot.secondary[2].target == 2, "arc selects a survivor after spread kills")
	var report := Insight.combat_report(model.s)
	check(report.spread == 2 and report.arc == 2 and report.kills == 2, "spread and arc debrief distinguished without double counted kills")
	model = fixture("scatter", [enemy(100), enemy(100, 0, 22)], ["bore"])
	shot = fire(model)
	check(model.s.enemies[0].burn == 2 and model.s.enemies[1].burn == 0, "spread does not replicate burn")
	model = fixture("scatter", [enemy(100), enemy(100, 0, 22)])
	model.s.hand.erase("charge")
	model.s.draw.append("charge")
	model.s.draw.erase("push")
	model.s.hand.append("push")
	model.s.plan = ["push"]
	shot = fire(model)
	check(shot.push == 2 and shot.secondary.size() == 1 and model.s.enemies[1].distance == 21 and model.s.push_left == 0, "spread never adds secondary knockback")
	model = fixture("scatter", [enemy(1), enemy(1, 0, 22)])
	shot = fire(model)
	check(model.s.phase == "reward" and model.s.history.back().detail.advance_events.is_empty(), "spread clear ends combat before movement")
	# Overpenetration preserves minimum damage and armor boundaries.
	for armor in range(7):
		for id in ["basic", "pierce", "precise"]:
			model = fixture("heavy", [enemy(100, armor)], [id])
			shot = fire(model)
			var expected := {"basic": [5, 5, 4, 3, 2, 1, 1], "pierce": [4, 4, 4, 4, 4, 3, 2], "precise": [6, 6, 4, 2, 2, 2, 2]}
			check(shot.damage == expected[id][armor], "heavy damage table " + id + "/" + str(armor))
			check(shot.math.overflow >= 0 and shot.math.overflow <= 1, "overflow capped")
	model = fixture("heavy", [enemy(100, 3)], ["pierce"])
	model.s.part = "lens"
	shot = fire(model)
	check(shot.pen == 6 and shot.damage == 4 and Readability.explain(shot).contains("초과관통 1"), "lens overflow correctly capped and explained")
	# Same rounds matter differently across formations, not just renamed stats.
	var totals := {}
	for gun in Content.GUNS:
		model = fixture(gun, [enemy(), enemy(100, 0, 22), enemy(100, 0, 23)])
		shot = fire(model)
		var damage: int = shot.damage
		for other in shot.secondary: damage += int(other.damage)
		totals[gun] = damage
	check(totals.scatter == 8 and totals.single == 5 and totals.heavy == 5 and totals.burst == 4, "formation-specific weapon payoff")
	for armor in [0, 3]:
		var cycle_damage := {}
		for gun in ["single", "heavy"]:
			model = Model.new()
			model.start(gun, 731042)
			model.s.capacity_bonus = 2
			model.s.supply = model.capacity()
			model.s.part = "loader" if gun == "heavy" else "none"
			model.s.enemies = [enemy(1000, armor, 1000)]
			for i in range(model.capacity()): check(model.load_round("basic"), "cycle loads basic")
			check(model.confirm(), "cycle confirms")
			while not model.s.magazine.is_empty(): check(model.fire(), "cycle fires")
			check(model.reload_magazine(), "cycle includes actual reload time")
			cycle_damage[gun] = float(1000 - int(model.s.enemies[0].hp)) / int(model.s.turns)
		check(cycle_damage.single > cycle_damage.heavy if armor == 0 else cycle_damage.heavy > cycle_damage.single, "standard retains unarmored tempo; heavy wins armor even with reload part")
	var path := OS.get_environment("QA_OUTPUT_DIR")
	if not path.is_empty():
		DirAccess.make_dir_recursive_absolute(path)
		var file := FileAccess.open(path.path_join("weapon_rules_report.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "formation_damage": totals}, "\t"))
		file.close()
	print("WEAPON RULES COMPLETE checks=" + str(checks) + " failures=" + str(failures.size()))
	quit(0 if failures.is_empty() else 1)
