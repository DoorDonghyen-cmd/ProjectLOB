extends "res://tests/heat_rules_runner.gd"
const Boosts = preload("res://redesign/attack_boosts.gd")
const Readout = preload("res://redesign/damage_readout.gd")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/support_combo/"): quit(1); return
	var totals: Array = []
	for order in [["charge", "charge_hot", "cool", "precise"], ["charge_hot", "cool", "precise", "charge"]]:
		var m = fixture(order, [["runner",100,0,1,30]])
		var shots := fire(m, order)
		var dealt := 100-int(m.s.enemies[0].hp)
		totals.append(dealt)
		check(shots.filter(func(r): return not Ammo.is_attack(r.id)).all(func(r): return r.damage == 0 and r.hits == 0), "support deals no direct or hidden hit")
		check(shots.size() == 4, "cooling completes combination")
	check(totals == [24,12], "same four cards double damage through preparation order")
	print("SAME HAND DAMAGE ", totals)
	var m = fixture(["charge","charge","precise"], [["runner",100,0,1,30]])
	var shots := fire(m,["charge","charge","precise"])
	check(shots[1].damage == 0 and shots[1].boost_replaced and shots[2].math.boost == 3 and shots[2].damage == 12, "repeated flat preparation replaces instead of stacking")
	# Each support effect must remain zero even with weapon, weakness and parts.
	for gun in Ammo.GUNS:
		for id in ["charge","charge_hot","charge_heat","shatter","cool","prepare","disrupt","spread"]:
			m = fixture([id], [["evader",100,3,1,30]], gun)
			m.s.buff = {"dmg":6,"dmg_left":2}
			m.s.equipped_parts = ["opening", "igniter"]
			m.s.enemies[0].burn = 2
			shots = fire(m,[id])
			check(shots[0].damage == 0 and shots[0].hits == 0 and shots[0].math.raw == 0, "support gated under every weapon " + gun + id)
			check(int(m.s.buff.get("dmg_left",0)) == (1 if id in ["charge","charge_heat"] else 2), "support consumes nothing; new flat preparation replaces old flat effect")
	# A utility shot does not strip a barrier or award burst's third-hit damage.
	m = fixture(["charge","shatter","precise"], [["wall",100,3,1,30]], "burst")
	m.s.enemies[0].barrier = 2
	m.s.enemies[0].focus_hits = 2
	shots = fire(m,["charge","shatter","precise"])
	check(shots[0].barrier_removed == 0 and shots[1].barrier_removed == 0 and shots[1].armor_removed == 3, "support prepares armor without consuming barriers")
	check(shots[2].blocked_hits == 2 and shots[2].math.boost == 3, "attack consumes boost even when blocked")
	# Carry only the compressed layer, never smuggle ordinary preparation across reload.
	var buff := Boosts.grant({"dmg":3,"dmg_left":1},4,1,2,true)
	buff = Boosts.grant(buff,0,2,1,false)
	check(Boosts.valid(buff), "mixed duration valid")
	buff = Boosts.after_reload(buff)
	check(buff.dmg == 4 and buff.factor == 1 and buff.dmg_left == 2, "reload filters each independent layer")
	check(Boosts.after_reload(buff).is_empty(), "carry is exactly one reload")
	buff = Boosts.grant({"dmg":3,"dmg_left":1},4,1,2,true)
	buff = Boosts.consume(buff)
	check(buff.dmg == 4 and buff.dmg_left == 1, "stacking never extends a shorter layer")
	var broken := buff.duplicate(true)
	broken.factor = 99
	check(not Boosts.valid(broken), "forged aggregate rejected")
	broken = buff.duplicate(true)
	broken.layers[0].left = 3
	check(not Boosts.valid(broken), "invalid layer duration rejected")
	# Actual compressed insertion / reload / saved plan conservation.
	m = fixture(["charge_c","basic","cool"], [["wall",100,0,1,30]])
	shots = fire(m,["basic","charge_c"])
	check(m.reload_magazine() and m.s.buff.dmg == 4 and m.s.buff.dmg_left == 2, "compressed next-magazine support remains available")
	var restored = Model.new()
	var saved_ok: bool = restored.restore_state(JSON.parse_string(JSON.stringify(m.s)))
	check(saved_ok and JSON.stringify(restored.s.buff) == JSON.stringify(JSON.parse_string(JSON.stringify(m.s.buff))), "layered save restore")
	# Pure multiplier is visible as a setup effect, not a zero-damage miss.
	m = fixture(["charge_hot","basic"], [["runner",100,0,1,30]])
	shots = fire(m,["charge_hot","basic"])
	check(Readout.entry(shots[0]).number == "×2" and Readout.entry(shots[1]).strong, "multiplier feedback")
	check(shots[1].math.factor == 2 and shots[1].damage == 6, "multiplier applies after flat damage")
	# Random forecast runs the same stack without merging incompatible durations.
	m = fixture(["charge","charge_hot","cool","precise"], [["runner",100,0,1,30],["wall",100,2,1,33]], "scatter")
	shots = fire(m,["charge","charge_hot","cool","precise"])
	check(shots[3].math.factor == 2 and shots[3].math.boost == 3, "scatter retains compound boost")
	# Support aimed at a pressure projectile neither intercepts nor claims to.
	m = fixture(["charge","basic"], [["spitter",100,0,0,24]])
	m._advance(2)
	m.s.projectiles[0].distance = 12
	shots = fire(m,["charge","basic"])
	check(not shots[0].get("intercept",false) and Readout.entry(shots[0]).number == "증폭", "support never reports a false interception")
	check(shots[1].get("intercept",false) and shots[1].math.boost == 3, "attack can spend setup on actual interception")
	# Repeated multipliers replace, including interrupted one-shot amplifier triggers.
	for gun in ["single","amplifier"]:
		m = fixture(["charge_hot","cool","charge_hot","basic"], [["runner",100,0,1,30]], gun)
		if gun == "amplifier": m.s.capacity_bonus = 1
		shots = fire(m,["charge_hot","cool","charge_hot","basic"])
		while not m.s.magazine.is_empty() and m.s.phase == "ready":
			var prediction := Forecast.analyze(m.s, true, true)
			check(m.fire(), "resume one-shot compound setup")
			check(m.s.enemies == prediction.enemies, "one-shot preview respects remaining layers")
			shots = m.s.history.back().detail.results
		check(shots.back().math.factor == (2 if gun == "single" else 3), "single multiplier channel for " + gun)
	# Existing v12 effects keep their already-granted amount, duration and order.
	m = fixture(["cool","basic"], [["runner",100,0,1,30]])
	m.s.buff = {"dmg":4,"dmg_left":2,"persistent":true}
	m.s.version = 12
	restored = Model.new()
	check(restored.restore_state(m.s.duplicate(true)) and restored.s.version == Model.VERSION and restored.s.buff.dmg == 4 and restored.s.buff.dmg_left == 2, "v12 granted buff migrates unchanged")
	fire(restored,["cool","basic"])
	check(restored.s.buff.dmg == 4 and restored.s.buff.dmg_left == 1, "migration skips support then spends one attack")
	for seed_value in range(1,21):
		m = fixture(["charge","charge_hot","cool","precise"], [["wall",20,3,1,30],["runner",6,0,1,33]], "scatter")
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value
		m.s.target_rng_state = str(rng.state)
		for id in Ammo.loading_order(["charge","charge_hot","cool","precise"]): m.load_round(id)
		var before := JSON.stringify(m.s)
		var prediction := Forecast.analyze(m.s,false,true)
		check(before == JSON.stringify(m.s), "random compound forecast pure")
		check(m.confirm() and m.fire(), "random compound actual execution")
		for i in range(m.s.enemies.size()):
			check(m.s.enemies[i].hp >= prediction.enemies[i].hp_min and m.s.enemies[i].hp <= prediction.enemies[i].hp_max, "random compound outcome in advertised range")
	# Same four cards: distribute flat prep across attacks instead of piling up.
	var distributed: Array = []
	for order in [["charge","charge","basic","basic"],["charge","basic","charge","basic"]]:
		m = fixture(order, [["runner",100,0,1,30]])
		fire(m,order)
		distributed.append(100-int(m.s.enemies[0].hp))
	check(distributed == [9,12], "distribute preparation across two attacks")
	print("DISTRIBUTE FLAT ", distributed)
	# Heat-based setup checks attack PRE-heat; cooling competes with its payoff.
	var heat_orders: Array = []
	for order in [["charge_heat","basic","cool"],["charge_heat","cool","basic"]]:
		m = fixture(order, [["runner",100,0,1,30]])
		m.s.heat = 5
		shots = fire(m,order)
		heat_orders.append(100-int(m.s.enemies[0].hp))
		check(shots[0].damage == 0, "heat preparation remains support")
	check(heat_orders == [9,3], "cooling before the attack trades away heat amplification")
	print("COOLING ORDER ", heat_orders)
	m = fixture(["charge_heat","basic"], [["runner",100,0,1,30]])
	m.s.heat = 4
	shots = fire(m,["charge_heat","basic"])
	check(shots[1].math.boost == 0 and shots[1].boost_hot_failed and m.s.buff.is_empty(), "attack's own heat cannot qualify; failed setup consumed")
	# Normal and heat additive preparations compete: the last one wins.
	for order in [["charge_heat","charge","basic"],["charge","charge_heat","basic"]]:
		m = fixture(order, [["runner",100,0,1,30]])
		shots = fire(m,order)
		check(shots.back().math.boost == (3 if order[1] == "charge" else 0), "last flat preparation replaces even if colder or weaker")
	# Overload: same strong strike, different cooling placement / remaining shots.
	var overload_counts: Array = []
	for order in [["charge_hot","precise","cool","basic"],["charge_hot","cool","precise","basic"]]:
		m = fixture(order, [["runner",100,0,1,30]])
		shots = fire(m,order)
		overload_counts.append(shots.size())
		var attack_shots := shots.filter(func(r): return r.id == "precise")
		check(attack_shots[0].boost_heat_paid == 3, "overload heat paid once per card, not per hit")
	check(overload_counts == [2,4], "cooling placement avoids forced reload and preserves last shot")
	print("OVERLOAD SHOTS ", overload_counts)
	m = fixture(["charge_hot","basic"], [["wall",100,0,1,30]])
	m.s.enemies[0].barrier = 1
	shots = fire(m,["charge_hot","basic"])
	check(shots[1].damage == 0 and shots[1].boost_heat_paid == 3 and shots[1].heat_after == 9, "blocked empowered shot pays heat")
	# A waiting conditional boost survives a real save; old v13 granted stacks stay intact.
	m = fixture(["charge_heat","basic"], [["runner",100,0,1,30]], "amplifier")
	fire(m,["charge_heat","basic"])
	restored = Model.new()
	check(restored.restore_state(JSON.parse_string(JSON.stringify(m.s))), "conditional layer save")
	check(restored.s.buff.layers[0].hot and restored.s.buff.layers[0].channel == "flat", "conditional rule survives save")
	var bad: Dictionary = m.s.duplicate(true)
	bad.buff.layers[0].heat = 99
	check(not Model.new().restore_state(bad), "invalid future heat debt rejected")
	m = fixture(["basic"], [["runner",100,0,1,30]])
	m.s.version = 13
	m.s.buff = Boosts.grant(Boosts.grant({},0,2,1,false),0,2,1,false)
	restored = Model.new()
	check(restored.restore_state(JSON.parse_string(JSON.stringify(m.s))) and restored.s.buff.factor == 4, "v13 already-granted stacked factor preserved")
	shots = fire(restored,["basic"])
	check(shots[0].math.factor == 4 and shots[0].boost_heat_paid == 0, "no retroactive cost added to legacy granted effect")
	check(Data.ammo_pool({"region":0,"floor":5}).has("charge_heat") and not Data.ammo_pool({"region":0,"floor":2}).has("charge_heat"), "heat setup available later without crowding tutorial")
	for gun in Ammo.GUNS:
		for offset in [-2,-1]:
			m = fixture(["charge_heat","basic"], [["runner",100,0,1,30]],gun)
			m.s.equipped_parts = ["radiator","sequencer"]
			m.s.heat = Ammo.hot_threshold(m.s) + offset
			shots = fire(m,["charge_heat","basic"])
			while not m.s.magazine.is_empty() and m.s.phase == "ready":
				var predicted := Forecast.analyze(m.s,true,true)
				check(m.fire(), "continue conditional amplifier")
				check(m.s.enemies == predicted.enemies and m.s.heat == predicted.heat.end_max, "conditional amplifier preview matches")
				shots = m.s.history.back().detail.results
			var expected := Ammo.effect_value("charge_heat",m.s) if offset == -1 else 0
			check(shots.back().math.boost == expected, "threshold and sequencer respect weapon/part changes " + gun)
	print("SUPPORT COMBO RULES COMPLETE checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
