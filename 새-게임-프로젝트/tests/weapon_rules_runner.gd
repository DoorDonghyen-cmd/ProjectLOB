extends SceneTree
## Boundary tests execute actual commands; scatter forecast is audited as a distribution.
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const Campaign = preload("res://redesign/campaign.gd")
const Data = preload("res://redesign/campaign_content.gd")
const Forecast = preload("res://redesign/forecast.gd")
const Readability = preload("res://redesign/readability.gd")
const Insight = preload("res://redesign/run_insight.gd")
var checks := 0
var failures: Array = []
var measurements: Dictionary = {}

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		print("FAIL: " + label)

func enemy(hp: int = 100, armor: int = 0, distance: int = 20) -> Dictionary:
	return {"kind": "wall", "name": Content.ENEMY_NAMES.wall, "hp": hp, "max_hp": hp, "def": armor, "speed": 1, "distance": distance, "burn": 0}

func fixture(gun: String, enemies: Array, rounds: Array = ["basic"], seed_value: int = 731042):
	var model = Model.new()
	model.start(gun, seed_value)
	model.s.deck = ["charge", "precise", "pierce", "bore", "arc", "push"]
	model.s.hand = []
	for id in rounds:
		if id == "basic": continue
		if model.s.hand.count(id) >= model.s.deck.count(id): model.s.deck.append(id)
		model.s.hand.append(id)
	for id in model.s.deck:
		if model.s.hand.size() < 5 and not model.s.hand.has(id): model.s.hand.append(id)
	model.s.draw = model.s.deck.duplicate()
	for id in model.s.hand: model.s.draw.erase(id)
	model.s.discard = []
	model.s.enemies = enemies.duplicate(true)
	for id in rounds: check(model.load_round(id), "fixture load " + gun + "/" + id)
	return model

func fire(model) -> Array:
	if model.s.phase == "plan": check(model.confirm(), "confirm fixture")
	check(model.fire(), "fire fixture")
	return model.s.history.back().detail.results

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	check(Content.GUNS.size() == 5, "five playable weapon archetypes")
	for gun in Content.GUNS:
		var campaign = Campaign.new()
		campaign.start(gun, 731042)
		check(campaign.model.s.deck == Content.start_deck(gun) and campaign.model.s.deck.size() == 10, "weapon starting deck " + gun)
		campaign.profile.unlocks = Data.LOADOUTS.keys()
		for loadout in Data.LOADOUTS:
			campaign.start(gun, 731042, 0, loadout)
			check(campaign.model.s.deck == (Content.start_deck(gun) if loadout == "balanced" else Data.LOADOUTS[loadout].deck), "sidegrades " + gun)
		for bonus in range(3):
			campaign.model.s.capacity_bonus = bonus
			check(campaign.model.capacity() == int(Content.GUNS[gun].capacity) + bonus, "capacity growth " + gun)
		var seen_parts: Array = []
		for revision in range(12):
			for offer in Data.offers({"id": 401}, 731042, revision, gun, []):
				if offer.type == "part":
					check(Content.accepts_part(gun, offer.id) and offer.id != "none", "eligible city shop " + gun)
					if not seen_parts.has(offer.id): seen_parts.append(offer.id)
		check(seen_parts.has("loader") == (gun in ["burst", "scatter"]), "loader useful shop stock " + gun)
		check(Content.accepts_part(gun, "loader") == (gun in ["burst", "scatter"]), "loader eligibility " + gun)
		var tempo = fixture(gun, [enemy()], ["basic", "basic", "basic"])
		var shots := fire(tempo)
		check(shots.size() == (1 if gun == "amplifier" else 3), "whole magazine versus single " + gun)
		check(tempo.s.turns == 1 and tempo.s.enemies[0].distance == 19, "one enemy advance per fire " + gun)
		var model = fixture(gun, [enemy(), enemy(100, 1, 22), enemy(100, 2, 23)], ["charge", "precise", "arc"])
		for part in ["none", "lens", "coil"]:
			model.s.part = part
			var before := JSON.stringify(model.s)
			var prediction := Forecast.analyze(model.s)
			check(JSON.stringify(model.s) == before, "forecast never changes state or RNG " + gun)
			var actual = Model.new()
			actual.s = model.s.duplicate(true)
			check(actual.confirm(), "confirm clone")
			var actual_shots: Array = []
			while actual.fire():
				actual_shots.append_array(actual.s.history.back().detail.results)
			if gun == "scatter":
				check(prediction.random and prediction.shots[0].target == -1 and prediction.shots[0].secondary.is_empty(), "random preview conceals future target")
				for i in range(actual.s.enemies.size()):
					check(actual.s.enemies[i].hp >= prediction.enemies[i].hp_min and actual.s.enemies[i].hp <= prediction.enemies[i].hp_max, "random actual HP lies in forecast")
			else:
				check(actual_shots.size() == prediction.shots.size(), "exact forecast shot count " + gun)
				for i in range(actual_shots.size()):
					var expected: Dictionary = prediction.shots[i].duplicate(true)
					expected.erase("action")
					check(actual_shots[i] == expected, "exact shot forecast " + gun)
				check(actual.s.enemies == prediction.enemies and actual.s.phase == prediction.phase, "exact final forecast " + gun)
			check(Model.new().restore_state(actual.s), "battle restores " + gun)
	# Independent numeric contracts, including part stacking and armor subtraction.
	for gun in Content.GUNS:
		for armor in range(8):
			for id in ["basic", "pierce", "precise"]:
				var model = fixture(gun, [enemy(100, armor)], [id])
				model.s.part = "lens"
				var shot: Dictionary = fire(model)[0]
				var raw: int = {"basic": 2, "pierce": 3, "precise": 2}[id] * (2 if gun == "amplifier" else 1) + ((1 if id == "basic" else 2) if gun == "single" else 0)
				var pen: int = (3 if id == "pierce" else 0) * (2 if gun == "amplifier" else 1) + 2
				var expected := maxi(1, raw - maxi(0, armor - pen)) * (2 if id == "precise" else 1)
				check(shot.damage == expected and shot.pen == pen, "raw/armor/lens contract " + gun + "/" + id + "/" + str(armor))
	# Focus counts actual primary hits, retains across reload, and never spills on death.
	var focus = fixture("burst", [enemy()], ["precise", "basic"])
	var focused := fire(focus)
	check(focused[0].hits == 2 and focused[0].focus_after == 2 and focused[1].focus_damage == 4 and focused[1].focus_after == 0, "double hit completes focus with third main hit")
	check(focus.s.enemies[0].hp == 90 and focused[1].damage == 6, "focus fixed four damage")
	check(Insight.combat_report(focus.s).focus == 4, "debrief focus is subset of direct damage")
	focus = fixture("burst", [enemy()], ["basic", "basic"])
	fire(focus)
	check(focus.reload_magazine(), "focus reload")
	check(focus.s.enemies[0].focus_hits == 2, "focus survives reload")
	check(focus.load_round("basic"), "focus reload bullet")
	check(fire(focus)[0].focus_damage == 4, "focus resumes after reload")
	focus = fixture("burst", [enemy(1), enemy(30, 0, 22)], ["precise", "precise", "basic"])
	focused = fire(focus)
	check(focused[0].hits == 1 and focused[0].focus_after == 1 and focused[0].damage == 1, "dead target gets no phantom second hit")
	check(focused[1].focus_after == 2 and focused[2].focus_damage == 4, "new target has independent focus")
	focus = fixture("burst", [enemy(6), enemy(30, 0, 22)], ["precise", "basic"])
	focused = fire(focus)
	check(focused[1].focus_triggers == 1 and focused[1].focus_damage == 0 and focus.s.enemies[1].hp == 30, "lethal third hit bonus cannot spill")
	focus = fixture("burst", [enemy(), enemy(100, 0, 22)], ["bore", "arc"])
	fire(focus)
	check(focus.s.enemies[0].focus_hits == 2 and focus.s.enemies[1].get("focus_hits", 0) == 0, "burn and transferred damage never increment focus")
	focus = fixture("burst", [enemy(), enemy(100, 0, 21)], ["push", "basic", "basic"])
	focused = fire(focus)
	check(focused[0].target == 0 and focused[1].target == 1 and focus.s.enemies[0].focus_hits == 1 and focus.s.enemies[1].focus_hits == 2, "focus retains separate target counters when push changes closest")
	# Element specialist and amplifier change strength, never duration or hit count.
	for gun in ["single", "heavy", "amplifier"]:
		var burning = fixture(gun, [enemy()], ["bore"])
		var shot: Dictionary = fire(burning)[0]
		check(shot.burn_added == 3 and burning.s.enemies[0].burn == 2, "burn duration stays three " + gun)
		check(burning.s.enemies[0].hp == 100 - shot.damage - (1 if gun == "single" else 2), "burn tick strength " + gun)
		burning = fixture(gun, [enemy()], ["bore"])
		burning.s.part = "coil"
		check(fire(burning)[0].burn_added == 4, "coil increases duration by one " + gun)
		var transfer = fixture(gun, [enemy(), enemy(100, 9, 22)], ["arc"])
		shot = fire(transfer)[0]
		check(shot.secondary.size() == 1 and shot.secondary[0].damage == {"single": 2, "heavy": 3, "amplifier": 4}[gun], "fixed transfer ignores secondary armor " + gun)
	var weak_basic: Dictionary = fire(fixture("single", [{"kind": "evader", "name": Content.ENEMY_NAMES.evader, "hp": 30, "max_hp": 30, "def": 0, "speed": 1, "distance": 20, "burn": 0, "weakness": "electric"}], ["basic"]))[0]
	var weak_arc: Dictionary = fire(fixture("single", [{"kind": "evader", "name": Content.ENEMY_NAMES.evader, "hp": 30, "max_hp": 30, "def": 0, "speed": 1, "distance": 20, "burn": 0, "weakness": "electric"}], ["arc"]))[0]
	check(weak_basic.damage == 3 and weak_arc.damage == 7 and weak_arc.math.weakness == 2, "electric weakness makes the tactical round visibly superior to basic")
	var part_model = fixture("single", [enemy(100), enemy(100, 0, 22)], ["arc"])
	part_model.s.part = "capacitor"
	check(fire(part_model)[0].secondary[0].damage == 3, "capacitor strengthens arc build")
	part_model = fixture("single", [enemy(100)], ["push"])
	part_model.s.part = "rammer"
	part_model.s.push_left = Content.push_budget(part_model.s)
	check(fire(part_model)[0].push == 3, "rammer strengthens distance-control build")
	part_model = fixture("single", [enemy(100)], ["charge"])
	part_model.s.part = "sequencer"
	check(fire(part_model)[0].boost_granted == 3, "sequencer strengthens ordered boost build")
	part_model = fixture("single", [enemy(100)], ["precise"])
	part_model.s.part = "duplex"
	check(fire(part_model)[0].hits == 3, "duplex strengthens repeated-hit build")
	# Multi-part builds stack up to five modules while only one rule-changing core
	# can be active. Strong cores expose their cost through the same live math.
	check(Content.PARTS.size() == 21, "twenty collectible parts plus the empty slot")
	var five_parts := ["lens", "coil", "capacitor", "rammer", "duplex"]
	check(Content.valid_part_set("single", five_parts) and not Content.valid_part_set("single", five_parts + ["opening"]), "five simultaneous part slots")
	check(not Content.valid_part_set("single", ["field_press", "overbore"]), "only one core part may be equipped")
	var stacked_state := {"gun": "single", "capacity_bonus": 0, "part": "none", "equipped_parts": five_parts}
	check(Content.penetration("basic", stacked_state) == 2 and Content.burn_amount("bore", stacked_state) == 4 and Content.effect_value("arc", stacked_state) == 3 and Content.effect_value("push", stacked_state) == 3 and Content.hit_count("precise", stacked_state) == 3, "five equipped modules apply together")
	var press = Model.new()
	press.start("single", 731042)
	press.s.equipped_parts = ["field_press"]
	press.begin_encounter(1)
	check(press.capacity() == 2 and press.s.field_compression_left == 2, "field press grants one compression and costs two magazine slots")
	var caliber = fixture("single", [enemy(100, 3)], ["basic"])
	caliber.s.equipped_parts = ["overbore"]
	caliber.s.part = "none"
	var caliber_shot: Dictionary = fire(caliber)[0]
	check(caliber.capacity() == 3 and caliber_shot.math.base == 5 and caliber_shot.pen == 2, "overbore trades one slot for damage and penetration")
	var ordered = fixture("single", [enemy(200)], ["basic", "pierce", "bore"])
	ordered.s.equipped_parts = ["opening", "triad"]
	ordered.s.part = "none"
	var ordered_shots := fire(ordered)
	check(ordered_shots[0].math.part_bonus == 2 and ordered_shots[1].math.part_bonus == 0 and ordered_shots[2].math.part_bonus == 5, "opening and triad read actual firing order")
	var closing = fixture("single", [enemy(200)], ["basic", "pierce"])
	closing.s.equipped_parts = ["afterburner"]
	closing.s.part = "none"
	var closing_shots := fire(closing)
	check(closing_shots[0].math.part_bonus == 0 and closing_shots[1].math.part_bonus == 3 and closing.reload_cost() == 2, "afterburner rewards the last round and lengthens reload")
	var barrier_enemy := enemy(100)
	barrier_enemy.barrier = 2
	barrier_enemy.barrier_max = 2
	var breaking = fixture("single", [barrier_enemy], ["precise"])
	breaking.s.equipped_parts = ["breaker"]
	breaking.s.part = "none"
	var break_shot: Dictionary = fire(breaking)[0]
	check(break_shot.barrier_removed == 2 and break_shot.blocked_hits == 1 and break_shot.damage > 0, "barrier breaker removes an extra layer per hit")
	var split = fixture("single", [enemy(100), enemy(100, 0, 22), enemy(100, 0, 24)], ["arc"])
	split.s.equipped_parts = ["arc_splitter"]
	split.s.part = "none"
	var split_shot: Dictionary = fire(split)[0]
	check(split_shot.secondary.size() == 2 and split_shot.secondary[0].damage == 4 and split_shot.math.base == 4, "arc splitter trades direct damage for two stronger transfers")
	var amplified = fixture("amplifier", [enemy()], ["charge", "precise", "basic"])
	var first: Dictionary = fire(amplified)[0]
	var second: Dictionary = fire(amplified)[0]
	var third: Dictionary = fire(amplified)[0]
	check(first.damage == 2 and first.boost_granted == 4 and second.hits == 2 and second.damage == 16 and third.damage == 8, "amplifier base double and next-two buff applied once")
	check(not amplified.s.buff.has("dmg") and amplified.s.turns == 3, "amplifier keeps hit count, buff count and single timing")
	var pushing = fixture("amplifier", [enemy()], ["push"])
	check(fire(pushing)[0].push == 4 and pushing.s.push_left == 0 and pushing.s.enemies[0].distance == 23, "amplifier four meter shared magazine budget")
	check(pushing.reload_magazine() and pushing.s.push_left == 4, "amplifier push budget resets on reload")
	# Compressed rounds trade frequency, magazine space, or firing position for a
	# concentrated effect. Placement is automatic so the visual fit is the rule.
	check(Content.COMPRESSIONS.size() == 6, "six ordinary families have one compressed form")
	for source in Content.COMPRESSIONS:
		var compressed_id: String = Content.compressed_id(source)
		check(Content.is_compressed(compressed_id) and Content.source_id(compressed_id) == source and Content.AMMO[compressed_id].name == Content.AMMO[source].name, "compressed family keeps familiar name " + source)
	var fitted = fixture("single", [enemy(200)], ["push_c", "precise_c", "pierce"])
	check(fitted.s.plan == ["precise_c", "pierce", "push_c"] and Content.slots_used(fitted.s.plan) == 3, "first and last compressed rounds auto-fit regardless of tap order")
	fitted.s.deck.append_array(["arc_c", "charge_c"])
	fitted.s.hand.append_array(["arc_c", "charge_c"])
	check(not fitted.can_load("arc_c") and not fitted.can_load("charge_c"), "one first and one last anchor per magazine")
	check(fitted.undo() and fitted.s.plan == ["precise_c", "push_c"], "undo removes the most recently tapped round after auto placement")
	var bulky = fixture("single", [enemy(200)], ["pierce_c", "basic", "basic"])
	check(Content.slots_used(bulky.s.plan) == 4 and not bulky.load_round("basic"), "heavy compressed round physically consumes two slots")
	var compressed_shot: Dictionary = fire(fixture("burst", [enemy(100)], ["precise_c"]))[0]
	check(compressed_shot.hits == 3 and compressed_shot.focus_triggers == 1 and compressed_shot.focus_damage == 4, "compressed repeat round completes surge focus in one shot")
	compressed_shot = fire(fixture("single", [enemy(100), enemy(100, 0, 22), enemy(100, 0, 24)], ["arc_c"]))[0]
	check(compressed_shot.secondary.size() == 2 and compressed_shot.secondary[0].damage == 2 and compressed_shot.secondary[1].damage == 2, "compressed electric round transfers to every other survivor")
	compressed_shot = fire(fixture("single", [enemy(100)], ["bore_c"]))[0]
	check(compressed_shot.burn_added == 6, "compressed incendiary fills burn duration in one shot")
	compressed_shot = fire(fixture("single", [enemy(100)], ["push_c"]))[0]
	check(compressed_shot.push == 3, "compressed impact receives its disclosed local push budget")
	var delayed = fixture("single", [enemy(200)], ["charge_c", "basic"])
	fire(delayed)
	check(delayed.s.buff.get("dmg", 0) == 4 and delayed.s.buff.get("persistent", false), "compressed boost is forced last and survives into reload")
	check(delayed.reload_magazine() and delayed.s.buff.get("dmg", 0) == 4 and not delayed.s.buff.has("persistent"), "compressed boost crosses exactly one reload boundary")
	check(delayed.load_round("basic") and delayed.confirm() and delayed.fire() and delayed.s.history.back().detail.results[0].damage == 7, "next magazine consumes carried compressed boost")
	# Field compression spends one run-owned core. It is independent from the hand
	# exchange, reversible before confirmation, and never changes the persistent deck.
	check(Content.FIELD_COMPRESSIONS.size() == 6, "six ordinary families support field compression")
	var field_model = Model.new()
	field_model.start("single", 731042)
	field_model.s.deck = ["precise", "precise", "charge", "charge", "pierce", "bore", "arc", "push"]
	field_model.s.hand = ["precise", "precise", "charge", "charge", "pierce"]
	field_model.s.draw = ["bore", "arc", "push"]
	field_model.s.discard = []
	field_model.s.enemies = [enemy(200)]
	var field_deck: Array = field_model.s.deck.duplicate()
	var field_hand: Array = field_model.s.hand.duplicate()
	check(field_model.field_compressible_ids().has("precise") and field_model.field_compressible_ids().has("charge"), "duplicate ordinary cards light eligible field choices")
	check(not field_model.can_field_compress("basic") and not field_model.can_field_compress("precise_c") and not field_model.can_load("precise_f"), "basic permanent and transient cards cannot enter field conversion directly")
	check(field_model.field_compress("precise"), "field compression combines an eligible pair")
	check(field_model.s.plan == ["precise_f"] and field_model.s.hand.count("precise") == 0 and field_model.s.exchange_left == 1 and field_model.s.field_compression_left == 0, "field compression auto-fits and spends only one run core")
	var field_plan_restore = Model.new()
	check(field_plan_restore.restore_state(field_model.s) and field_plan_restore.s.field_compression.zone == "plan", "active field compression restores before confirmation")
	var field_save_path := "user://field_compression_active.json"
	check(field_model.save_run(field_save_path) == OK, "active field compression saves atomically")
	var field_disk_restore = Model.new()
	var field_disk_ok := field_disk_restore.restore_run(field_save_path)
	check(field_disk_ok and field_disk_restore.s.plan == field_model.s.plan and field_disk_restore.s.hand == field_model.s.hand and field_disk_restore.s.deck == field_model.s.deck and field_disk_restore.s.field_compression == field_model.s.field_compression and int(field_disk_restore.s.exchange_left) == 1 and int(field_disk_restore.s.field_compression_left) == 0, "active field compression disk round-trip exact")
	DirAccess.remove_absolute(field_save_path)
	var invalid_field: Dictionary = field_model.s.duplicate(true)
	invalid_field.field_compression_left = 2
	check(not field_plan_restore.restore_state(invalid_field) and field_plan_restore.s == field_model.s, "active field compression rejects impossible unspent core state transactionally")
	check(field_model.undo(), "undo cancels active field compression")
	var restored_hand: Array = field_model.s.hand.duplicate()
	field_hand.sort()
	restored_hand.sort()
	check(restored_hand == field_hand and field_model.s.plan.is_empty() and field_model.s.field_compression.is_empty() and field_model.s.field_compression_left == 1 and field_model.s.exchange_left == 1, "pre-confirm cancel restores cards and core without changing exchange")
	check(field_model.field_compress("charge") and field_model.remove_planned(field_model.s.plan.find("charge_f")), "slot removal also cancels field compression")
	check(field_model.s.hand.count("charge") == 2 and field_model.s.field_compression_left == 1, "slot cancel returns source pair")
	check(field_model.field_compress("precise") and field_model.confirm(), "field compression confirms as one temporary round")
	var field_ready_restore = Model.new()
	check(field_ready_restore.restore_state(field_model.s) and field_ready_restore.s.field_compression.zone == "magazine", "active field compression restores after confirmation")
	var field_prediction := Forecast.analyze(field_model.s)
	check(field_model.fire(), "temporary compressed round fires")
	check(field_model.s.discard.count("precise") == 2 and not field_model.s.discard.has("precise_f") and field_model.s.field_compression.is_empty() and field_model.s.deck == field_deck, "fired field round splits to two originals without changing deck")
	check(field_prediction.shots.size() == 1 and field_prediction.shots[0].id == "precise_f" and field_prediction.shots[0].damage == field_model.s.history.back().detail.results[0].damage, "field round forecast uses live resolver")
	check(field_model.reload_magazine() and field_model.s.field_compression_left == 0 and field_model.s.exchange_left == 1 and not field_model.can_field_compress("charge"), "reload restores exchange but never spent encounter charge")
	var abandoned = Model.new()
	abandoned.start("single", 731042)
	abandoned.s.deck = ["push", "push", "charge", "precise", "pierce", "bore", "arc", "charge"]
	abandoned.s.hand = ["push", "push", "charge", "precise", "pierce"]
	abandoned.s.draw = ["bore", "arc", "charge"]
	abandoned.s.discard = []
	abandoned.s.enemies = [enemy(200)]
	check(abandoned.field_compress("push") and abandoned.confirm() and abandoned.reload_magazine(), "confirmed field round may be abandoned by reload")
	check(abandoned.s.discard.count("push") == 2 and not abandoned.s.discard.has("push_f") and abandoned.s.field_compression_left == 0, "post-confirm reload splits originals without refund")
	var stocked = Model.new()
	stocked.start("single", 731042)
	stocked.begin_encounter(2)
	stocked.s.deck = ["push", "push", "charge", "charge", "precise", "pierce", "arc", "bore"]
	stocked.s.hand = ["push", "push", "charge", "charge", "precise"]
	stocked.s.draw = ["pierce", "arc", "bore"]
	stocked.s.discard = []
	stocked.s.enemies = [enemy(200)]
	check(stocked.field_compress("push") and stocked.s.field_compression_left == 1 and stocked.s.exchange_left == 1, "two stocked cores spend one and preserve hand exchange")
	check(stocked.undo() and stocked.s.field_compression_left == 2, "cancel returns one core without exceeding the two-core cap")
	var cramped = Model.new()
	cramped.start("amplifier", 731042)
	cramped.s.deck = ["pierce", "pierce", "charge", "precise", "bore", "arc", "push", "charge"]
	cramped.s.hand = ["pierce", "pierce", "charge", "precise", "bore"]
	cramped.s.draw = ["arc", "push", "charge"]
	cramped.s.discard = []
	check(cramped.load_round("charge") and cramped.load_round("precise") and not cramped.can_field_compress("pierce"), "two-slot field compression respects remaining magazine space")
	var course = Model.new()
	course.start("single", 731042, true)
	course.s.hand = ["charge", "charge"]
	check(course.s.field_compression_left == 0 and course.field_compressible_ids().is_empty(), "guided course hides field compression")
	var predicted = fixture("single", [enemy(200), enemy(100, 0, 22), enemy(100, 0, 24)], ["push_c", "precise_c", "arc"])
	var prediction_before := Forecast.analyze(predicted.s)
	var actual_copy = Model.new()
	actual_copy.s = predicted.s.duplicate(true)
	fire(actual_copy)
	var actual_results: Array = actual_copy.s.history.back().detail.results
	check(prediction_before.enemies == actual_copy.s.enemies and prediction_before.shots.size() == actual_results.size() and prediction_before.shots.map(func(value): return [value.id, value.damage, value.hits, value.secondary]) == actual_results.map(func(value): return [value.id, value.damage, value.hits, value.secondary]), "compressed automatic order uses the same forecast and resolver")
	# Random bullets choose living enemies at each bullet, not distance spread.
	var random = fixture("scatter", [enemy(2), enemy(2, 0, 22)], ["basic", "basic"])
	var prediction := Forecast.analyze(random.s)
	check(is_equal_approx(float(prediction.win_probability), 1.0) and prediction.enemies[0].hp_max == 0, "lethal rounds always retarget survivors")
	var random_shots := fire(random)
	check(random_shots.size() == 2 and random_shots[0].target != random_shots[1].target and random.s.phase == "reward", "actual lethal bullet retargets survivor")
	check(random.s.history.back().detail.advance_events.is_empty(), "clear has no extra enemy advance")
	random = fixture("scatter", [enemy(4), enemy(4, 0, 100)], ["basic", "basic"])
	prediction = Forecast.analyze(random.s)
	check(is_equal_approx(float(prediction.win_probability), 0.0) and is_equal_approx(float(prediction.enemies[0].kill_probability), 0.25), "two shots exact one-enemy kill probability quarter")
	check(prediction.enemies[0].hp_min == 0 and prediction.enemies[0].hp_max == 4 and prediction.shots[0].damage_min == 2, "exact random HP ranges")
	check(is_equal_approx(float(prediction.shots[0].targets[0].probability), 0.5), "primary uniform independent of distance")
	var concealed: Dictionary = random.s.duplicate(true)
	concealed.target_rng_state = "12345"
	check(Forecast.analyze(concealed) == prediction and random.preview().is_empty(), "different hidden target RNG gives identical public forecast")
	random = fixture("scatter", [enemy(4, 0, 1), enemy(4, 0, 100)], ["basic", "basic"])
	prediction = Forecast.analyze(random.s)
	check(is_equal_approx(float(prediction.lost_probability), 0.75), "random contact risk exact including lethal closest branch")
	var hits_by_target := [0, 0, 0]
	for seed_value in range(240):
		random = fixture("scatter", [enemy(), enemy(100, 0, 100), enemy(100, 0, 200)], ["precise"], seed_value)
		var draw_rng: String = random.s.rng_state
		var shot: Dictionary = fire(random)[0]
		hits_by_target[shot.target] += 1
		check(shot.hits == 2 and shot.damage == 4 and shot.secondary.is_empty(), "double stays one target without spread")
		check(random.s.rng_state == draw_rng, "target RNG never consumes draw RNG")
		check(random.s.enemies.filter(func(e): return e.hp == 96).size() == 1, "double changes exactly one enemy")
	check(hits_by_target.min() > 45 and hits_by_target.max() < 115, "seeded random target coverage")
	measurements.target_counts = hits_by_target
	for seed_value in range(60):
		random = fixture("scatter", [enemy(8), enemy(8, 2, 22), enemy(5, 0, 23)], ["charge", "precise", "arc"], seed_value)
		var before: Dictionary = random.s.duplicate(true)
		prediction = Forecast.analyze(random.s)
		var restored = Model.new()
		check(restored.restore_state(before), "scatter restore before fire")
		fire(random)
		fire(restored)
		check(random.s.enemies == restored.s.enemies and random.s.target_rng_state == restored.s.target_rng_state, "saved scatter RNG replays exact results")
		for i in range(3):
			check(random.s.enemies[i].hp >= prediction.enemies[i].hp_min and random.s.enemies[i].hp <= prediction.enemies[i].hp_max, "many-seed random forecast contains actual")
	# Maximum-size scatter distribution and cached redraw cost.
	random = fixture("scatter", [enemy(), enemy(100, 2, 22), enemy(100, 1, 23)], ["charge", "precise", "bore", "arc", "push"])
	random.s.capacity_bonus = 2
	random.s.supply = 7
	for id in ["basic", "basic"]: check(random.load_round(id), "seven slot fixture")
	var started := Time.get_ticks_msec()
	prediction = Forecast.analyze(random.s)
	measurements.seven_slot_ms = Time.get_ticks_msec() - started
	started = Time.get_ticks_msec()
	for i in range(100): Forecast.analyze(random.s)
	measurements.cached_100_ms = Time.get_ticks_msec() - started
	check(prediction.shots.size() == 7 and measurements.seven_slot_ms < 2000 and measurements.cached_100_ms < 1000, "seven slot forecast bounded and redraw cached")
	measurements.seven_slot_branches = prediction.branches
	# The city expansion part may add an eighth slot at maximum progression.
	random.s.part = "supply"
	random.s.supply = 8
	check(random.load_round("basic") and random.capacity() == 8, "legacy eighth scatter slot")
	started = Time.get_ticks_msec()
	prediction = Forecast.analyze(random.s)
	measurements.legacy_eight_slot_ms = Time.get_ticks_msec() - started
	check(prediction.shots.size() == 8 and measurements.legacy_eight_slot_ms < 3000, "legacy eight slot forecast bounded")
	for phase in ["lost", "reward", "won"]:
		var terminal: Dictionary = random.s.duplicate(true)
		terminal.magazine = terminal.plan.duplicate()
		terminal.plan = []
		terminal.phase = phase
		var terminal_forecast := Forecast.analyze(terminal)
		check(terminal_forecast.shots.is_empty() and terminal_forecast.turns == 0 and terminal_forecast.enemies == terminal.enemies and terminal_forecast.phase == phase, "terminal random state cannot forecast future firing")
	var amp_note = fixture("amplifier", [enemy()], ["charge"])
	check(Forecast.note(Forecast.analyze(amp_note.s), 0) == "다음 2발 +4", "amplifier forecast shows actual boost strength")
	for gun in ["heavy", "amplifier"]:
		var lesson_state := {"gun": gun, "floor": 2}
		check(Content.lesson(lesson_state).contains("턴당 2피해"), "lesson reflects enhanced burn " + gun)
	# Save migration and corrupt state rejection are transactional.
	var saved: Dictionary = random.s.duplicate(true)
	for old_version in [2, 3, 4]:
		var legacy: Dictionary = saved.duplicate(true)
		legacy.version = old_version
		legacy.erase("plan_load_order")
		if old_version < 4: legacy.erase("target_rng_state")
		var migrated = Model.new()
		check(migrated.restore_state(legacy) and migrated.s.version == Model.VERSION and migrated.s.has("target_rng_state") and migrated.s.has("plan_load_order") and migrated.s.has("reinforcements") and migrated.s.field_compression.is_empty(), "legacy battle migration v" + str(old_version))
	var survivor = Model.new()
	check(survivor.restore_state(saved), "current v6 restores")
	for bad_counter in [-1, 3, 1.5]:
		var bad: Dictionary = saved.duplicate(true)
		bad.enemies[0].focus_hits = bad_counter
		check(not survivor.restore_state(bad) and survivor.s == saved, "reject corrupt focus transactionally")
	var bad: Dictionary = saved.duplicate(true)
	bad.target_rng_state = "not-an-integer"
	check(not survivor.restore_state(bad) and survivor.s == saved, "reject corrupt target RNG transactionally")
	bad = saved.duplicate(true)
	bad.equipped_parts = ["field_press"]
	bad.part = "overbore"
	check(not survivor.restore_state(bad) and survivor.s == saved, "legacy part field cannot bypass the one-core save limit")
	bad = saved.duplicate(true)
	bad.equipped_parts = ["lens", "coil", "capacitor", "rammer", "duplex"]
	bad.part = "opening"
	check(not survivor.restore_state(bad) and survivor.s == saved, "legacy part field cannot become a hidden sixth effect")
	for field in ["seed", "floor"]:
		for value in [[], {}, null, "oops"]:
			bad = saved.duplicate(true)
			bad.version = 3
			bad.erase("target_rng_state")
			bad[field] = value
			check(not survivor.restore_state(bad) and survivor.s == saved, "malformed legacy seed/floor rejected before conversion")
	var path := OS.get_environment("QA_OUTPUT_DIR")
	if not path.is_empty():
		DirAccess.make_dir_recursive_absolute(path)
		var file := FileAccess.open(path.path_join("weapon_rules_report.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks": checks, "failures": failures, "measurements": measurements}, "\t"))
		file.close()
	print("WEAPON RULES COMPLETE checks=" + str(checks) + " failures=" + str(failures.size()))
	quit(0 if failures.is_empty() else 1)
