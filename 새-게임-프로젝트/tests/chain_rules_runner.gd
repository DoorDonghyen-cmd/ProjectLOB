extends SceneTree
## Independent v2 functional audit. Synthetic fixtures are not campaign win tests.
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const Forecast = preload("res://redesign/forecast.gd")
var checks: Array = []
var evidence: Array = []

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--reward-only"):
		_reward_only()
	else:
		_run()

func _reward_only() -> void:
	for seed_value in [1, 2, 3, 731042]:
		for gun in ["single", "burst"]:
			for floor_index in [1, 4]:
				for part in ["none", "lens", "loader", "supply", "coil"]:
					var m = Model.new()
					m.start(gun, seed_value)
					m.s.floor = floor_index
					m.s.part = part
					m.begin_encounter()
					m.s.phase = "reward"
					var before: Dictionary = m.s.duplicate(true)
					var generated: Array = Content.rewards_for(floor_index, seed_value, gun)
					var expected: Array = generated.duplicate()
					expected.erase(part)
					var offered: Array = m.reward_options()
					var label := "reward seed%d %s floor%d part%s" % [seed_value, gun, floor_index, part]
					check(offered == expected and not offered.has(part), label + " excludes current only, keeps seeded order")
					check(m.s == before and m.reward_options() == offered, label + " query pure and deterministic including RNG")
					check(not m.choose_reward(part) and m.s == before, label + " same part cannot be chosen and state stays intact")
					for candidate in offered:
						var selected = Model.new()
						selected.s = before.duplicate(true)
						check(selected.choose_reward(candidate) and selected.s.part == candidate and selected.s.floor == floor_index + 1 and selected.s.phase == "plan", label + " valid other part advances " + candidate)
					evidence.append({"id": label, "generated": generated, "offered": offered})
	# Ammo reward floors must remain exactly the generated three choices.
	for gun in ["single", "burst"]:
		for floor_index in [0, 2, 3, 5]:
			var m = Model.new()
			m.start(gun, 731042)
			m.s.floor = floor_index
			m.s.part = "coil"
			check(m.reward_options() == Content.rewards_for(floor_index, 731042, gun), "ammo floor untouched by current-part filter")
	var failed := 0
	for row in checks:
		if not row.pass: failed += 1
	var out := FileAccess.open("user://chain_reward_followup.json", FileAccess.WRITE)
	out.store_string(JSON.stringify({"passed": checks.size() - failed, "failed": failed, "checks": checks, "evidence": evidence}, "\t"))
	out.close()
	print("CHAIN_REWARD_FOLLOWUP %d passed / %d failed" % [checks.size() - failed, failed])
	quit(1 if failed else 0)

func check(ok: bool, label: String, detail: Variant = null) -> void:
	checks.append({"pass": ok, "label": label, "detail": detail})
	if not ok: printerr("CHAIN_QA_FAIL " + label + " " + JSON.stringify(detail))

func normalized(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

func enemy(hp: int = 100, distance: int = 50, defense: int = 0, evasion: int = 1, speed: int = 1, crack: int = 0) -> Dictionary:
	return {"kind": "wall", "name": "QA", "hp": hp, "max_hp": hp, "distance": distance, "def": defense, "eva": evasion, "speed": speed, "slow": 0, "crack": crack}

func fixture(rounds: Array, gun: String = "burst", part: String = "none", enemies: Array = []):
	var m = Model.new()
	m.start(gun, 4242)
	m.s.part = part
	m.s.supply = m.supply_capacity()
	m.s.deck = []
	for id in rounds:
		if id != "basic": m.s.deck.append(id)
	while m.s.deck.size() < 10: m.s.deck.append("mark")
	m.s.hand = m.s.deck.slice(0, 5)
	m.s.draw = m.s.deck.slice(5)
	m.s.discard = []
	m.s.enemies = [enemy()] if enemies.is_empty() else enemies.duplicate(true)
	for id in rounds: check(m.load_round(id), "fixture legal FIFO load " + id)
	return m

func inventory(m, label: String) -> void:
	var owned: Array = m.s.hand + m.s.draw + m.s.discard
	for id in m.s.magazine:
		if id != "basic": owned.append(id)
	var deck: Array = m.s.deck.duplicate()
	owned.sort()
	deck.sort()
	check(owned == deck, label + " tactical multiset conserved")
	check(m.s.hand.size() <= 5 and m.s.plan.size() <= m.capacity() and m.s.magazine.size() <= m.capacity(), label + " hand and magazine bounds")
	for id in m.s.plan: check(m.available(id) >= 0, label + " planned ammo owned")

func roundtrip(m, label: String) -> void:
	var before: Dictionary = m.s.duplicate(true)
	check(m.save_run("user://chain_roundtrip.json") == OK, label + " save successful")
	var restored = Model.new()
	check(restored.restore_run("user://chain_roundtrip.json") and restored.s == normalized(before), label + " v2 restore exact")
	if restored.s.is_empty(): return
	check(normalized(Forecast.analyze(restored.s)) == normalized(Forecast.analyze(m.s)), label + " restored forecast exact")
	check(m.s == before, label + " save and forecast do not mutate source")

func compare_forecast(m, label: String, keep: bool = true) -> Dictionary:
	var before: Dictionary = m.s.duplicate(true)
	var forecast: Dictionary = Forecast.analyze(m.s)
	check(m.s == before and Forecast.analyze(m.s) == forecast, label + " forecast pure and repeatable including RNG")
	var actual = Model.new()
	actual.s = before.duplicate(true)
	if actual.s.phase == "plan": actual.confirm()
	var shots: Array = []
	var actions := 0
	while actual.s.phase == "ready" and not actual.s.magazine.is_empty() and actions < 8:
		check(actual.fire(), label + " actual fire accepted")
		for row in actual.s.history.back().detail.results:
			var result: Dictionary = row.duplicate(true)
			result.action = actions
			shots.append(result)
		actions += 1
	check(forecast.shots == shots, label + " predicted primary secondary effects and grouping exact")
	check(forecast.phase == actual.s.phase and forecast.remaining == actual.s.magazine and forecast.enemies == actual.s.enemies and forecast.turns == actual.s.turns - before.turns, label + " predicted terminal residual movement cost exact")
	if not forecast.shots.is_empty():
		var first: Dictionary = forecast.shots[0].duplicate(true)
		first.erase("action")
		check(m.preview() == first, label + " immediate preview equals first FIFO shot")
	if keep: evidence.append({"id": label, "before": before, "forecast": forecast.duplicate(true), "after": actual.s.duplicate(true)})
	inventory(actual, label)
	return {"forecast": forecast, "after": actual.s.duplicate(true)}

func damage_list(result: Dictionary) -> Array:
	var out: Array = []
	for row in result.forecast.shots: out.append(row.damage)
	return out

func target_list(result: Dictionary) -> Array:
	var out: Array = []
	for row in result.forecast.shots: out.append(row.target)
	return out

func invalid_save(base: Dictionary, label: String) -> void:
	var file := FileAccess.open("user://chain_invalid.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(base))
	file.close()
	var m = Model.new()
	m.start("single", 9876)
	var before: Dictionary = m.s.duplicate(true)
	check(not m.restore_run("user://chain_invalid.json") and m.s == before, label + " rejected without live state damage")

func _run() -> void:
	var r := compare_forecast(fixture(["charge", "precise", "basic"]), "fifo_charge_double_basic")
	check(damage_list(r) == [1, 8, 6] and r.after.buff.is_empty(), "manual next2 bullets buffs both double hits once")
	r = compare_forecast(fixture(["precise", "basic", "charge"]), "reversed_combo")
	check(damage_list(r) == [4, 4, 1] and r.after.buff == {"dmg": 2, "dmg_left": 2}, "manual FIFO reversal changes damage and residual buff")
	r = compare_forecast(fixture(["charge", "mark", "precise", "basic"], "burst", "none", [enemy(100, 50, 0, 10)]), "independent_dmg_acc_durations")
	check(damage_list(r) == [1, 4, 8, 4] and r.after.buff.is_empty(), "manual charge consumed by mark while guidance survives2 more bullets")
	r = compare_forecast(fixture(["bore", "bore", "pierce", "basic"], "burst", "none", [enemy(100, 50, 4)]), "crack_cap_and_shatter_consumption")
	check(damage_list(r) == [1, 1, 11, 1] and r.after.enemies[0].crack == 0, "manual crack2 then cap3 then shatter uses old armor and resets")
	r = compare_forecast(fixture(["bore", "precise", "basic"], "burst", "none", [enemy(100, 50, 3)]), "crack_applies_each_hit")
	check(damage_list(r) == [1, 2, 3] and r.after.enemies[0].crack == 2, "manual crack persists through double and basic")
	r = compare_forecast(fixture(["bore", "arc"], "burst", "none", [enemy(100, 20, 3), enemy(100, 21, 50, 50)]), "cracked_arc_fixed_secondary")
	check(r.forecast.shots[1].secondary == [{"target": 1, "damage": 3, "hp": 97}] and r.after.enemies[0].crack == 2, "manual arc3 ignores secondary armor evasion preserves primary crack")
	r = compare_forecast(fixture(["charge", "arc"], "single", "lens", [enemy(100, 20), enemy(100, 21, 50, 50)]), "uncracked_arc_not_buffed")
	check(r.forecast.shots[1].damage == 6 and r.forecast.shots[1].secondary[0].damage == 1, "manual arc auxiliary1 ignores gun and charge bonus")
	r = compare_forecast(fixture(["arc", "basic"], "burst", "none", [enemy(2, 20, 0, 1, 1, 1), enemy(3, 21)]), "arc_kills_two_and_stops")
	check(r.forecast.phase == "reward" and r.forecast.shots.size() == 1 and r.forecast.remaining == ["basic"], "arc uses dead primary prior crack and stops before reserved basic")
	r = compare_forecast(fixture(["precise", "basic"], "burst", "none", [enemy(1, 20), enemy(100, 21)]), "double_same_target_no_spill")
	check(target_list(r) == [0, 1] and r.forecast.shots[0].damage == 1 and r.forecast.shots[0].secondary.is_empty() and r.after.enemies[1].hp == 96, "double overkill never transfers second hit to next enemy")
	r = compare_forecast(fixture(["basic", "finish"] , "burst", "none", [enemy(8)]), "finish_half_threshold")
	check(damage_list(r) == [4, 4] and r.forecast.shots[1].combo.has("수확"), "finish triggers exactly half and clips actual damage to HP")
	r = compare_forecast(fixture(["finish", "basic"] , "burst", "none", [enemy(8)]), "finish_before_threshold")
	check(damage_list(r) == [3, 4] and not r.forecast.shots[0].combo.has("수확") and r.after.enemies[0].hp == 1, "finish evaluates health before its own shot")
	r = compare_forecast(fixture(["bore", "push", "arc", "pierce"], "burst", "none", [enemy(100, 20), enemy(100, 21)]), "crack_attached_to_enemy_after_push")
	check(target_list(r) == [0, 0, 1, 1] and r.after.enemies[0].crack == 2 and r.forecast.shots[2].secondary[0].damage == 1 and r.forecast.shots[3].damage == 5, "crack does not follow aim or buff other target shatter")
	r = compare_forecast(fixture(["push", "push", "basic"], "burst", "none", [enemy(100, 20)]), "shared_knockback_limit")
	check(r.forecast.shots[0].push == 2 and r.forecast.shots[1].push == 0 and r.after.push_left == 0 and r.after.enemies[0].distance == 21, "manual push shared2m then final movement")
	r = compare_forecast(fixture(["slow", "basic"], "single", "none", [enemy(100, 20, 0, 1, 3)]), "slow_single_advance")
	check(r.after.enemies[0].distance == 16 and r.after.enemies[0].slow == 0 and r.forecast.turns == 2, "manual slow first advance1 then3")
	r = compare_forecast(fixture(["basic", "basic", "basic", "basic", "basic"], "single", "supply", [enemy(100, 20)]), "five_slot_single")
	check(r.forecast.shots.size() == 5 and r.forecast.turns == 5 and r.after.enemies[0].distance == 15, "five slot forecast executes5 single actions")
	r = compare_forecast(fixture(["basic", "basic", "basic", "basic", "basic"], "burst", "supply", [enemy(100, 20)]), "five_slot_burst")
	check(r.forecast.shots.size() == 5 and r.forecast.turns == 1 and r.after.enemies[0].distance == 19, "five slot burst executes5 bullets in1 action")
	r = compare_forecast(fixture(["basic", "basic"], "single", "none", [enemy(100, 1)]), "loss_interrupt")
	check(r.forecast.phase == "lost" and r.forecast.shots.size() == 1 and r.forecast.remaining == ["basic"], "contact loss leaves residual bullet")
	# Independent arithmetic oracle, including high armor/evasion minimum and clip.
	for gun in ["single", "burst"]:
		for id in Content.AMMO:
			for variant in range(4):
				var e := enemy(100, 50, [0, 4, 9, 2][variant], [1, 10, 30, 8][variant], 1, [0, 2, 3, 1][variant])
				if variant == 3: e.hp = 50
				var m = fixture([id], gun, "lens" if variant == 3 else "none", [e])
				if variant == 3: m.s.buff = {"dmg": 2, "dmg_left": 1, "acc": 4, "acc_left": 2}
				var spec: Dictionary = Content.AMMO[id]
				var raw: int = spec.dmg + (1 if gun == "single" else 0) + (2 if variant == 3 else 0)
				if id == "pierce": raw += e.crack * 2
				if id == "finish" and e.hp * 2 <= e.max_hp: raw += 4
				var acc: int = spec.acc + (6 if variant == 3 else 0)
				var amount := maxi(1, raw - maxi(0, e.def - e.crack - spec.pen) - maxi(0, e.eva - acc))
				amount = mini(e.hp, amount * (2 if id == "precise" else 1))
				m.confirm()
				m.fire()
				var shot: Dictionary = m.s.history.back().detail.results[0]
				check(shot.damage == amount and shot.hp == e.hp - amount and shot.graze == (e.eva > acc), "independent arithmetic %s %s %d" % [gun, id, variant], {"expected": amount, "actual": shot.damage})
	# Plan manipulation, capacity guards, exchange conservation and resume.
	var m = fixture(["charge", "basic", "precise"])
	var original_supply: int = m.s.supply
	check(m.remove_planned(1) and m.s.plan == ["charge", "precise"] and m.s.supply == original_supply, "remove middle slot returns supply without spending turn")
	check(m.undo() and m.s.plan == ["charge"] and m.load_round("basic"), "undo removes last planned only")
	var planned_before: Dictionary = m.s.duplicate(true)
	check(not m.exchange("charge") and m.s == planned_before, "exchange refuses only copy reserved in plan")
	check(m.exchange("mark") and m.s.plan == planned_before.plan and m.s.hand.size() == 5 and m.s.turns == 0 and m.s.exchange_left == 0, "exchange unreserved card preserves plan and costs no turn")
	inventory(m, "exchange with plan")
	var after_exchange: Dictionary = m.s.duplicate(true)
	check(not m.exchange("mark") and not m.exchange("basic") and m.s == after_exchange, "second exchange and basic exchange rejected atomically")
	roundtrip(m, "planned after exchange")
	check(m.confirm(), "confirm reserved plan after exchange")
	var ready_before: Dictionary = m.s.duplicate(true)
	check(not m.load_round("basic") and not m.remove_planned(0) and not m.undo() and not m.exchange("mark") and m.s == ready_before, "ready rejects editing and exchange atomically")
	check(m.fire(), "single burst charge basic executed")
	roundtrip(m, "ready with residual buff")
	check(m.reload_magazine() and m.s.exchange_left == 1 and m.s.buff.is_empty() and m.s.supply == 4 and m.s.hand.size() == 5 and m.s.push_left == 2, "reload resets transient effects exchange supply and push")
	inventory(m, "reload after exchange")
	# Explicit duplicate identity: may exchange spare copy while one is reserved.
	m = fixture(["bore", "bore"])
	m.remove_planned(1)
	check(m.exchange("bore") and m.s.plan == ["bore"] and m.s.hand.count("bore") == 1, "exchange duplicate spare does not consume reserved copy")
	inventory(m, "duplicate exchange")
	# Exhaust draw; replacement comes from existing discard before returned card.
	m = fixture([])
	m.s.deck = ["charge", "mark", "bore", "pierce", "precise", "arc"]
	m.s.hand = ["charge", "mark", "bore", "pierce", "precise"]
	m.s.draw = []
	m.s.discard = ["arc"]
	check(m.exchange("charge") and not m.s.hand.has("charge") and m.s.hand.has("arc") and m.s.discard == ["charge"], "exchange refill cannot redraw returned physical card")
	inventory(m, "discard refill exchange")
	roundtrip(m, "exchange shuffled discard")
	# Crack persists over reload; buffs do not. Cost counts only lived ticks.
	m = fixture(["bore", "charge"], "burst", "none", [enemy(100, 20, 2)])
	m.confirm()
	m.fire()
	check(m.s.enemies[0].crack == 2 and not m.s.buff.is_empty(), "crack and charge exist before reload")
	m.reload_magazine()
	check(m.s.enemies[0].crack == 2 and m.s.buff.is_empty() and m.s.enemies[0].distance == 16 and m.s.turns == 4, "reload keeps enemy crack clears player buff costs3")
	roundtrip(m, "persistent crack plan")
	m = fixture(["basic"], "burst", "none", [enemy(100, 3, 0, 1, 2)])
	m.confirm()
	m.reload_magazine()
	check(m.s.phase == "lost" and m.s.turns == 2, "lethal reload ends at actual second tick")
	roundtrip(m, "lost during reload")
	for part in ["none", "supply"]:
		m = fixture([], "single", part)
		for i in range(m.capacity()): check(m.load_round("basic"), "fill capacity " + part)
		var full: Dictionary = m.s.duplicate(true)
		check(not m.load_round("basic") and m.s == full, "reject above capacity " + part)
		roundtrip(m, "full plan " + part)
		m.confirm()
		roundtrip(m, "full ready " + part)
	# Strict malformed-save rejection; never overwrite current valid model.
	m = fixture(["basic"])
	var base: Dictionary = m.s.duplicate(true)
	for mutation in ["v1", "crack4", "missing_buff_counter", "buff_counter3", "exchange2", "supply6", "missing_owned", "six_slots", "unsafe_seed"]:
		var bad: Dictionary = base.duplicate(true)
		match mutation:
			"v1": bad.version = 1
			"crack4": bad.enemies[0].crack = 4
			"missing_buff_counter": bad.buff = {"dmg": 2}
			"buff_counter3": bad.buff = {"acc": 4, "acc_left": 3}
			"exchange2": bad.exchange_left = 2
			"supply6": bad.supply = 6
			"missing_owned": bad.hand.pop_back()
			"six_slots": bad.plan = ["basic", "basic", "basic", "basic", "basic", "basic"]
			"unsafe_seed": bad.seed = 9007199254740994
		invalid_save(bad, mutation)
	# Bounded real seeded starts: no synthetic deck/enemy edits in this section.
	var formations: Dictionary = {}
	var rewards: Dictionary = {}
	for seed_value in [1, 2, 3, 4, 5, 6, 731042, 9007199254740993]:
		for gun in ["single", "burst"]:
			m = Model.new()
			m.start(gun, seed_value)
			check(m.s.version == 2 and m.s.deck.size() == 10 and m.s.hand.size() == 5 and m.s.supply == 4, "v2 seeded start " + str(seed_value))
			var copy = Model.new()
			copy.start(gun, seed_value)
			check(m.s == copy.s, "same seed exact initial state " + str(seed_value))
			formations[str(m.s.enemies)] = true
			rewards[str(m.reward_options())] = true
			for step in range(8):
				if m.s.phase in ["lost", "won"]: break
				if m.s.phase == "reward":
					check(m.choose_reward("skip"), "seeded skip advances encounter")
				elif m.s.phase == "plan":
					m.exchange(m.s.hand[0])
					m.load_round(m.s.hand[0])
					m.load_round("basic")
					m.load_round("basic")
					compare_forecast(m, "seed%d_%s_step%d" % [seed_value, gun, step], false)
					m.confirm()
				elif not m.s.magazine.is_empty(): m.fire()
				else: m.reload_magazine()
				inventory(m, "seeded action")
				roundtrip(m, "seeded action")
	check(formations.size() > 1 and rewards.size() > 1, "seed changes public formation and reward set", {"formations": formations.size(), "rewards": rewards.size()})
	for floor_index in range(7):
		for seed_value in [1, 2, 3]:
			var es: Array = Content.enemies_for(floor_index, seed_value)
			check(es == Content.enemies_for(floor_index, seed_value) and es.size() >= 1 and es.size() <= 3, "seeded formation deterministic bounded")
			for gun in ["single", "burst"]:
				var options: Array = Content.rewards_for(floor_index, seed_value, gun)
				check(options == Content.rewards_for(floor_index, seed_value, gun) and options.size() == (0 if floor_index == 6 else 3), "seeded reward deterministic3 or final0")
				check(gun != "single" or not options.has("loader"), "single excludes ineffective loader")
	# All part reset contracts; new encounter destroys prior cracks/effects.
	for part in ["lens", "loader", "supply", "coil"]:
		m = Model.new()
		m.start("burst", 42)
		m.s.part = part
		m.begin_encounter()
		check(m.capacity() == (5 if part == "supply" else 4) and m.reload_cost() == (2 if part == "loader" else 3), "part capacity and cost " + part)
		for e in m.s.enemies: check(e.crack == (1 if part == "coil" else 0), "part opening crack " + part)
		roundtrip(m, "part " + part)
	var failed := 0
	for row in checks:
		if not row.pass: failed += 1
	var out := FileAccess.open("user://chain_combat_independent.json", FileAccess.WRITE)
	out.store_string(JSON.stringify({"passed": checks.size() - failed, "failed": failed, "checks": checks, "evidence": evidence}, "\t"))
	out.close()
	print("CHAIN_COMBAT_INDEPENDENT %d passed / %d failed" % [checks.size() - failed, failed])
	quit(1 if failed else 0)
