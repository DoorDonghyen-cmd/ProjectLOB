extends SceneTree
const Model = preload("res://tests/combat_ui_stage1_probe_model.gd")
const Content = preload("res://redesign/content.gd")
const Forecast = preload("res://redesign/forecast.gd")
var checks := 0
var failures: Array = []
var comparisons: Array = []
var loops: Array = []
var out := ""

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message); push_error(message)

func fresh(boss := true):
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://redesign/samples/combat_magazine_loop_%s.json" % ("boss" if boss else "normal")))
	var model = Model.new()
	check(model.restore_state(data.state), "Earned checkpoint restores")
	model.s.magazine_trial_version = 1
	return model

func conserved(model, label: String) -> void:
	var expected: Array = model.s.deck.duplicate()
	for i in range(Model.Reserve.generated_count(model.s)): expected.append(Model.Reserve.EMERGENCY_ROUND)
	var owned: Array = model.s.hand + model.s.draw + model.s.discard + model.s.magazine
	expected.sort(); owned.sort()
	check(expected == owned, "Owned ammo conserved: " + label)
	var restored = Model.new()
	check(restored.restore_state(JSON.parse_string(model.serialized_state())), "Versioned state round trip: " + label)
	if not restored.s.is_empty():
		check(restored.s.magazine == model.s.magazine and restored.s.rng_state == model.s.rng_state and restored.s.target_rng_state == model.s.target_rng_state, "Magazine and RNG preserved: " + label)

func predicted_fire(model) -> Dictionary:
	var before := JSON.stringify(model.s)
	var prediction := Forecast.analyze(model.s, true, true)
	check(JSON.stringify(model.s) == before, "Preview preserves live state and RNG")
	var start: int = model.s.turns
	check(model.fire(), "Legal two-round firing command")
	check(model.s.enemies == prediction.enemies and model.s.projectiles == prediction.projectiles and model.s.phase == prediction.phase and model.s.magazine == prediction.remaining and int(model.s.turns) - start == int(prediction.turns), "Actual two-round result equals forecast, including forced cooling")
	var detail: Dictionary = model.s.history.back().detail
	check(detail.results.size() <= 2, "Pulse never fires more than two rounds")
	conserved(model, "fire")
	return detail

func synthetic_pool(rounds: Array):
	var model = fresh()
	model.s.deck = rounds.duplicate()
	model.s.draw = rounds.duplicate()
	model.s.hand = []; model.s.magazine = []; model.s.discard = []
	model.s.plan = []; model.s.plan_load_order = []; model.s.history = []
	model.s.buff = {}; model.s.prepared = []; model.s.heat = 0
	model.s.emergency_uses = 0; model.s.sustained_attacks = 0
	check(model.trial_load_magazine(), "Synthetic boundary scenario loads")
	return model

func boundary_cases() -> void:
	# Two-slot and pinned rounds execute through the actual model, not only the selector.
	var model = synthetic_pool(["arc_c", "precise_c", "vent_c", "charge_c", "pierce_c", "basic_p1", "basic_p2"])
	check(Content.slots_used(model.s.magazine) == 6, "Compressed ammunition fills slots rather than counting icons")
	conserved(model, "compressed anchors")
	predicted_fire(model)
	if model.s.phase == "ready": check(model.reload_magazine(), "Swap compressed and pinned rounds")
	conserved(model, "compressed swap")
	# Emergency supply is still finite and has escalating paid enemy actions.
	model = synthetic_pool(["charge", "charge", "charge", "charge", "charge", "charge"])
	check(model.can_emergency_resupply(), "Support-only reserve exposes emergency supply")
	var cost: int = model.emergency_cost()
	var start: int = model.s.turns
	check(model.emergency_resupply(), "Whole-magazine emergency supply is legal")
	check(model.s.turns == start + cost and model.s.magazine.count("basic_p2") == 4 and model.s.emergency_uses == 1, "Only four emergency rounds generated, full cost paid")
	conserved(model, "emergency")
	check(not model.can_emergency_resupply(), "Cannot buy emergency rounds while attacks remain")
	check(model.emergency_cost() == cost + 1, "Next emergency cost escalates")
	# Short final reserve stays short and cannot generate filler ammunition.
	model = synthetic_pool(["basic_p1", "basic_p1", "basic_p1", "basic_p1", "basic_p1", "basic_p1"])
	model.s.discard = model.s.magazine.slice(0, 4); model.s.magazine = model.s.magazine.slice(4)
	check(model.reload_magazine() and model.s.magazine.size() == 2 and model.s.draw.is_empty(), "Two remaining owned rounds make a two-round magazine")
	conserved(model, "short reserve")
	# Cooling invokes existing burn/terminal resolution, including a partial two-turn recovery.
	model = fresh(); model.trial_load_magazine()
	for i in range(model.s.enemies.size()): model.s.enemies[i].hp = 0
	model.s.enemies[0].hp = 2; model.s.enemies[0].burn = 1; model.s.reinforcements = []
	model.s.heat = 6
	var kept: Array = model.s.magazine.duplicate()
	check(model.cool_magazine() and model.s.phase == "reward" and model.s.heat == 0 and model.s.magazine == kept, "Burn can win during cooling without losing unfired rounds")
	check(not model.cool_magazine(), "Terminal cooling cannot repeat")
	# Split trigger input must not reset sustained heat or last-round part context.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://redesign/samples/combat_ui_capacity_boss_6.json"))
	model = Model.new(); model.s = data.state.duplicate(true)
	model.s.capacity_bonus = 0; model.s.magazine_trial_version = 1
	check(model.confirm(), "Controlled overheat setup")
	predicted_fire(model)
	var detail := predicted_fire(model)
	check(not detail.forced_cooling.is_empty() and detail.forced_cooling.cost == 2 and model.s.magazine.size() == 2 and model.s.discard.size() == 4, "Overheat retains exactly the last two rounds")
	check(int(detail.results.back().sustained_heat) > 0, "Second trigger retains continuous-fire heat burden")
	var before := JSON.stringify(model.s)
	var forecast := Forecast.analyze(model.s)
	check(JSON.stringify(model.s) == before, "Full remaining-magazine forecast is pure")
	while model.s.phase == "ready" and not model.s.magazine.is_empty(): check(model.fire(), "Remaining magazine plays out")
	check(model.s.enemies == forecast.enemies and model.s.projectiles == forecast.projectiles and model.s.phase == forecast.phase and model.s.magazine == forecast.remaining, "Full forecast agrees with repeated trigger actions")

func controlled() -> void:
	for boss in [false, true]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://redesign/samples/combat_ui_capacity_%s_6.json" % ("boss" if boss else "normal")))
		for policy in ["old_full", "pulse", "pulse_cool"]:
			var model = Model.new(); model.s = data.state.duplicate(true)
			if policy != "old_full":
				model.s.capacity_bonus = 0; model.s.magazine_trial_version = 1
			check(model.confirm(), "Controlled same owned six-round order")
			var start: int = model.s.turns
			var first: Array = model.s.magazine.duplicate()
			var peak := 0
			var rounds := 0
			var cooling := 0
			model.advance_calls.clear()
			for step in range(12):
				if model.s.phase != "ready" or model.s.magazine.is_empty(): break
				if policy == "pulse_cool" and int(model.s.heat) > 0:
					var prediction := Forecast.analyze(model.s, true)
					if float(prediction.heat.forced_probability) > 0.0:
						check(model.cool_magazine(), "Preemptive cooling"); cooling += 1
						if model.s.phase != "ready": break
				var detail: Dictionary
				if policy == "old_full":
					check(model.fire(), "Legacy control fires"); detail = model.s.history.back().detail
				else: detail = predicted_fire(model)
				peak = maxi(peak, int(detail.heat_peak)); rounds += detail.results.size()
			var advances := 0
			for call in model.advance_calls: advances += int(call.requested_turns)
			comparisons.append({"boss": boss, "policy": policy, "order": first, "fired": rounds, "remaining": model.s.magazine, "discarded": model.s.discard.size(), "heat_peak": peak, "cool_actions": cooling, "turns": int(model.s.turns) - start, "enemy_action_turns": advances, "phase": model.s.phase, "enemies": model.s.enemies})

func run() -> void:
	out = OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/combat_magazine_loop_20261031/"): quit(2); return
	controlled()
	boundary_cases()
	var model = fresh()
	var rng: String = model.s.rng_state
	check(model.trial_load_magazine() and model.capacity() == 6 and model.s.magazine.size() == 6, "Actual six-round magazine comes from owned deck")
	check(model.s.rng_state == rng, "Loading keeps original seeded shuffled queue")
	check(not model.trial_load_magazine() and not model.load_round("basic_p1") and not model.cool_magazine(), "No free reroll, individual insertion, or zero-heat waiting")
	conserved(model, "opening")
	var ordered: Array = model.s.magazine.duplicate()
	predicted_fire(model)
	check(model.s.magazine == ordered.slice(2), "Unfired suffix retained in the same order")
	var retained: Array = model.s.magazine.duplicate()
	var discard: Array = model.s.discard.duplicate()
	var before_heat: int = model.s.heat
	var turn: int = model.s.turns
	var budget: int = model.s.push_left
	check(model.cool_magazine(), "Manual cooling legal")
	check(model.s.magazine == retained and model.s.discard == discard and model.s.turns == turn + 1 and model.s.heat == maxi(0, before_heat - 6), "Manual cooling costs time without spending ammo")
	check(model.s.push_left == budget and int(model.s.get("sustained_attacks", 0)) == 0, "Cooling resets sustained heat without refreshing push budget")
	conserved(model, "cool")
	check(model.save_run(out.path_join("candidate.json")) == OK, "Candidate writes atomically")
	var restored = Model.new(); check(restored.restore_run(out.path_join("candidate.json")), "Candidate restores from disk")
	check(model.fire() and restored.fire(), "Resume continues firing")
	# JSON parses integral numbers as floats; compare both through that boundary.
	check(JSON.parse_string(JSON.stringify(model.s)) == JSON.parse_string(JSON.stringify(restored.s)), "Resume produces identical continuation")
	var returned: Array = model.s.magazine.duplicate()
	var reserve: Array = model.s.hand + model.s.draw + returned
	var picked := Model.MagazineTrial.take(reserve, 6, Content.slot_cost, Content.anchor)
	discard = model.s.discard.duplicate(); turn = model.s.turns
	check(model.reload_magazine(), "Whole magazine swap")
	check(model.s.magazine == picked.selected and model.s.draw == picked.remaining and model.s.discard == discard and model.s.turns == turn + 2, "Paid swap returns unused ammo to queue tail and fills another magazine")
	conserved(model, "swap")
	var bad: Dictionary = model.s.duplicate(true)
	for version in [-1, 2, 1.5, "1"]:
		bad.magazine_trial_version = version
		check(not Model.new().restore_state(bad), "Reject unknown or malformed trial version")
	bad = model.s.duplicate(true); bad.gun = "scatter"
	check(not Model.new().restore_state(bad), "Reject unsupported weapon rather than showing false deterministic prediction")
	bad = model.s.duplicate(true); bad.capacity_bonus = 3
	check(not Model.new().restore_state(bad), "Existing capacity bonus validation stays strict")
	bad = model.s.duplicate(true); bad.magazine_trial_version = 0
	check(not Model.new().restore_state(bad), "Six rounds require explicit candidate rules")
	# Conflicting fixed positions, two-slot rounds, and short reserves.
	for pool in [["arc_c", "precise_c", "vent_c", "charge_c", "pierce_c", "basic_p1", "basic_p2"], ["pierce_c"], ["charge", "cool"]]:
		var pick := Model.MagazineTrial.take(pool, 6, Content.slot_cost, Content.anchor)
		check(Content.valid_stack(pick.selected, 6), "Anchors and compressed slot costs remain legal")
		var all: Array = pick.selected + pick.remaining; var expected: Array = pool.duplicate(); all.sort(); expected.sort()
		check(all == expected, "Deferred anchors never disappear")
	# Same earned enemy/deck, shuffled order perturbations; these are not earned runs under new rules.
	for boss in [false, true]:
		for seed_value in [17, 1042, 731042, 900001, 1200411]:
			model = fresh(boss)
			var shuffle := RandomNumberGenerator.new(); shuffle.seed = seed_value; model.s.rng_state = str(shuffle.state)
			model.s.draw = model.s.hand + model.s.draw; model.s.hand = []; model._shuffle(model.s.draw)
			check(model.trial_load_magazine(), "Seeded shuffled trial opening")
			var opening: Array = model.s.magazine.duplicate(); var start: int = model.s.turns; var min_distance := 999
			var actions := 0; var cools := 0; var swaps := 0
			for step in range(80):
				if model.s.phase not in ["ready", "plan"]: break
				for e in model.s.enemies:
					if int(e.hp) > 0: min_distance = mini(min_distance, int(e.distance))
				actions += 1
				if model.can_emergency_resupply(): check(model.emergency_resupply(), "Finite reserve emergency supply"); swaps += 1
				elif model.s.magazine.is_empty(): check(model.reload_magazine(), "Empty magazine replaced"); swaps += 1
				else:
					var prediction := Forecast.analyze(model.s, true)
					if float(prediction.heat.forced_probability) > 0.0 and int(model.s.heat) > 0:
						check(model.cool_magazine(), "Heat-aware loop cools"); cools += 1
					else: predicted_fire(model)
				conserved(model, "loop")
			check(model.s.phase in ["lost", "reward", "won"], "Loop reaches a terminal state within bound")
			loops.append({"boss": boss, "shuffle_seed": seed_value, "opening": opening, "actions": actions, "cool_actions": cools, "swaps": swaps, "turns": int(model.s.turns) - start, "phase": model.s.phase, "nearest_observed": min_distance, "used": model.s.discard.size(), "remaining": Model.Reserve.remaining(model.s)})
	# Legal repeated swaps approach contact: exact two-action warning must match defeat.
	model = fresh(false); model.trial_load_magazine()
	for step in range(30):
		var copy = Model.new(); copy.s = model.s.duplicate(true); copy.reload_magazine()
		if copy.s.phase == "lost":
			check(model.reload_magazine() and model.s == copy.s, "Lethal swap prediction matches contact defeat")
			break
		check(model.reload_magazine(), "Paid waiting cannot prevent approach")
	check(model.s.phase == "lost" and model.s.get("loss_reason", "") != "projectile", "Repeated swapping cannot stall body contact")
	conserved(model, "contact")
	check(not model.fire() and not model.cool_magazine() and not model.reload_magazine(), "No commands after defeat")
	FileAccess.open(out.path_join("rules.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "comparisons": comparisons, "loops": loops, "scope": "Single weapon, two earned encounter fixtures, five shuffled-order perturbations; not full-run balance or human fun."}, "  "))
	print("MAGAZINE LOOP RULES COMPLETE checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
