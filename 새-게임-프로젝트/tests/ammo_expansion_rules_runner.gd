extends SceneTree
const Model = preload("res://redesign/model.gd")
const Ammo = preload("res://redesign/content.gd")
const Data = preload("res://redesign/campaign_content.gd")
const Campaign = preload("res://redesign/campaign.gd")
const Forecast = preload("res://redesign/forecast.gd")
const Ranged = preload("res://redesign/ranged.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)

func fixture(ids: Array, rows: Array = [], gun: String = "single") -> RefCounted:
	var model = Model.new()
	model.start(gun, 731042)
	model.s.deck = ids.duplicate()
	while model.s.deck.size() < 10: model.s.deck.append("pierce")
	model.begin_encounter()
	model.s.hand = ids.duplicate()
	model.s.draw = model.s.deck.duplicate()
	for id in ids: model.s.draw.erase(id)
	model.s.enemies = []
	for row in rows if not rows.is_empty() else [["wall", 40, 4, 1, 30], ["runner", 40, 0, 2, 34]]:
		model.s.enemies.append(Data._enemy(row))
	model.assign_opening_lanes()
	model.s.encounter_total = model.s.enemies.size()
	model.s.deployed = model.s.enemies.size()
	return model

func fire(model: RefCounted, ids: Array) -> Array:
	for id in Ammo.loading_order(ids): check(model.load_round(id), "legal load " + str(id))
	var before := JSON.stringify(model.s)
	var prediction := Forecast.analyze(model.s, true, true)
	check(JSON.stringify(model.s) == before, "prediction pure")
	check(model.confirm() and model.fire(), "real confirm and fire")
	if model.s.gun != "scatter":
		check(prediction.enemies == model.s.enemies, "forecast matches enemies")
		check(prediction.projectiles == model.s.projectiles, "forecast matches projectiles")
		check(prediction.reload == Forecast.reload_now(model.s), "forecast matches real reload cost and aftermath")
	var restored = Model.new()
	check(restored.restore_state(JSON.parse_string(JSON.stringify(model.s))), "new state restores")
	check(restored.s.previous_kill == model.s.previous_kill and restored.s.heat == model.s.heat, "combo and heat survive save")
	return model.s.history.back().detail.results

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/ammo_expansion/"):
		quit(1)
		return
	var model = fixture(["shatter", "precise"])
	var result := fire(model, ["shatter", "precise"])
	check(result[0].damage == 1 and result[0].armor_removed == 3 and result[1].damage == 6, "shatter does not help itself, helps next multihit")
	var reverse = fixture(["shatter", "precise"])
	var reverse_result := fire(reverse, ["precise", "shatter"])
	check(model.s.enemies[0].hp < reverse.s.enemies[0].hp and reverse_result[0].damage == 2, "armor order changes outcome")
	model = fixture(["shatter", "shatter"], [["stance", 40, 4, 1, 30]])
	fire(model, ["shatter", "shatter"])
	check(model.s.enemies[0].stance_def == 0, "persistent armor removal reaches zero")
	model.reload_magazine()
	check(model.s.enemies[0].def == 0, "stance cannot regrow stripped armor")
	for gun in Ammo.GUNS:
		if gun == "amplifier": continue # Separate triggers advance burn between single shots.
		model = fixture(["bore", "detonate"], [["absorber", 40, 4, 1, 30]], gun)
		result = fire(model, ["bore", "detonate"])
		check(result[1].detonation == 3 * Ammo.burn_damage(model.s), "burn cash-out uses weapon tick " + gun)
		check(model.s.enemies[0].burn == 0 and result[1].blocked_hits == 1, "detonation bypasses barrier without double dipping " + gun)
	model = fixture(["detonate", "bore"])
	result = fire(model, ["detonate", "bore"])
	check(result[0].detonation == 0 and model.s.enemies[0].burn == 2, "detonation first has no fire to spend")
	model = fixture(["bore", "detonate"], [["wall", 40, 4, 1, 30]], "heavy")
	model.s.equipped_parts = ["coil", "inferno"]
	result = fire(model, ["bore", "detonate"])
	check(result[1].detonation == 12, "fire parts retain build value in detonation")
	model = fixture(["pierce", "chase"], [["runner", 5, 0, 1, 30], ["runner", 20, 0, 1, 32]])
	result = fire(model, ["pierce", "chase"])
	check(result[1].chase_bonus == 4 and result[1].damage == 8, "kill opens chase")
	model.reload_magazine()
	check(not model.s.previous_kill, "reload clears kill link")
	model = fixture(["pierce", "chase"])
	result = fire(model, ["pierce", "chase"])
	check(result[1].chase_bonus == 0, "nonkill closes chase")
	model = fixture(["arc", "chase"], [["wall", 40, 4, 1, 30], ["runner", 2, 0, 1, 32]])
	result = fire(model, ["arc", "chase"])
	check(result[1].chase_bonus == 4, "secondary kill counts as previous bullet kill")
	model = fixture(["bypass", "bypass"], [["wall", 20, 4, 1, 22], ["spitter", 7, 0, 0, 25]])
	result = fire(model, ["bypass", "bypass"])
	check(result[0].target == 1 and result[1].hp == 0 and model.s.enemies[0].hp == 20, "bypass kills backline while front advances")
	model = fixture(["bypass"], [["wall", 20, 4, 1, 22]])
	result = fire(model, ["bypass"])
	check(result[0].target == 0, "bypass falls back when only one enemy")
	model = fixture(["bypass", "chase"], [["spitter", 40, 0, 0, 25]])
	model._advance(2)
	model.s.projectiles[0].distance = 12
	result = fire(model, ["bypass", "chase"])
	check(result[0].intercept and result[1].chase_bonus == 0, "mandatory interception wins targeting and does not trigger chase")
	for order in [["charge_hot", "cool", "precise"], ["cool", "charge_hot", "precise"]]:
		model = fixture(order)
		result = fire(model, order)
		check(model.s.heat == (6 if order[0] == "charge_hot" else 9), "cooling order changes temperature")
		check(model.reload_cost() >= model.base_reload_cost(), "cooling never discounts base reload")
	model = fixture(["charge_hot", "cool", "charge_hot"], [], "amplifier")
	# Actual single-shot triggers, then doubled cooling intensity.
	for id in Ammo.loading_order(["charge_hot", "cool", "charge_hot"]): check(model.load_round(id), "amplifier load")
	check(model.confirm(), "amplifier confirm")
	for i in range(3): check(model.fire(), "amplifier trigger")
	check(model.s.heat == 5, "amplifier doubles cooling strength")
	# Every random result must be within the enumerated model branches, including conditional chase.
	for sequence in [["shatter", "precise", "chase"], ["bore", "detonate", "bypass"], ["charge_hot", "cool", "chase"]]:
		for seed_value in range(1, 31):
			model = fixture(sequence, [["wall", 10, 4, 1, 25], ["runner", 5, 0, 2, 29], ["absorber", 8, 0, 1, 32]], "scatter")
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			model.s.target_rng_state = str(rng.state)
			for id in Ammo.loading_order(sequence): model.load_round(id)
			var predicted := Forecast.analyze(model.s, false, true)
			model.confirm()
			model.fire()
			for i in range(model.s.enemies.size()):
				check(model.s.enemies[i].hp >= predicted.enemies[i].hp_min and model.s.enemies[i].hp <= predicted.enemies[i].hp_max, "random HP lies in forecast")
			if model.s.phase == "ready": check(model.reload_cost() >= predicted.reload.cost_min and model.reload_cost() <= predicted.reload.cost_max, "random reload lies in forecast")
	model = fixture(["chase"], [], "scatter")
	model.load_round("chase")
	model.confirm()
	var cold := Forecast.analyze(model.s)
	model.s.previous_kill = true
	var hot := Forecast.analyze(model.s)
	check(hot.shots[0].damage_max > cold.shots[0].damage_max, "random cache distinguishes kill link")
	var discovered: Array = []
	for gun in Ammo.GUNS:
		var distinct: Array = []
		for id in Ammo.start_deck(gun):
			if not distinct.has(id): distinct.append(id)
		check(distinct.size() >= 3 and distinct.size() <= 4, "focused start " + gun)
		for seed_value in range(1, 31):
			for region in range(5):
				for node in Data.nodes(region, seed_value):
					var options := Data.rewards(node, seed_value, Ammo.start_deck(gun))
					check(options.size() == 2 and options[0] != options[1], "two distinct reward choices")
					check(options[0] != "cool", "normal boost is not a cooling synergy")
					check(not Ammo.start_deck(gun).has(options[1]), "discovery alongside build support")
					for id in options:
						check(Data.ammo_pool(node).has(id), "reward respects introduction stage")
						if not discovered.has(id): discovered.append(id)
	check(discovered.size() == Ammo.TACTICAL_AMMO.size(), "all twelve tactical choices reachable")
	var seen: Array = []
	for revision in range(12):
		var offers := Data.offers({"id": 10401, "region": 1, "floor": 4}, 731042, revision, "single", [], [], seen)
		check(not seen.has(offers[0].id), "shop rotates unseen ammo")
		seen.append(offers[0].id)
	for region in range(5):
		for node in Data.nodes(region, 731042):
			if not node.kind in ["combat", "boss"]: continue
			var pack := Data.encounter_pack(node, 731042, "single", 0, 0)
			model = fixture(["bypass", "cool"])
			model.s.enemies = pack.active
			model.s.reinforcements = pack.reserve
			model.assign_opening_lanes()
			model.s.encounter_total = pack.total
			model.s.deployed = pack.active.size()
			check(Model.new().restore_state(model.s), "campaign formation save validity")
	var campaign = Campaign.new()
	campaign.start("single", 77)
	var legacy := {"campaign": campaign.s.duplicate(true), "combat": campaign.model.s.duplicate(true), "profile": campaign.profile.duplicate(true)}
	legacy.campaign.erase("shop_seen_ammo")
	legacy.combat.erase("previous_kill")
	check(Campaign.new().restore_state(legacy), "old run loads without new optional fields")
	legacy.combat.previous_kill = "yes"
	check(not Campaign.new().restore_state(legacy), "malformed combo state rejected")
	# Optimized random branches use the same resolver; skip explanatory output
	# only. Check every base card, weapon and representative multi-part build.
	for gun in Ammo.GUNS:
		for id in Ammo.TACTICAL_AMMO:
			for parts in [[], ["opening", "duplex", "coil", "executioner", "igniter"], ["overbore", "sequencer"], ["arc_splitter", "capacitor"]]:
				model = fixture([id], [["absorber", 10, 4, 1, 24], ["runner", 2, 0, 1, 26]], gun)
				model.s.enemies[0].burn = 3
				model.s.heat = 1
				model.s.previous_kill = true
				model.s.equipped_parts = parts
				model.s.buff = {"dmg": 2, "dmg_left": 2}
				var light = Model.new()
				light.s = model.s.duplicate(true)
				var context := {"first": true, "last": true, "triad": true}
				var full_result: Dictionary = model._shot(id, 0, context)
				context.profile = Model.shot_profile(id, light.s)
				context.forecast_minimal = true
				var light_result: Dictionary = light._shot(id, 0, context)
				check(full_result.damage == light_result.damage and model.s == light.s, "full and optimized resolver equivalence")
	print("AMMO EXPANSION RULES COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
