extends "res://tests/ammo_expansion_rules_runner.gd"

const Insight = preload("res://redesign/run_insight.gd")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/build_synergy/"):
		quit(1)
		return
	var configurations := {
		"base": [], "extended": ["supply"], "third_cooling": ["chain_sink"],
		"short_cooling": ["cooling_breech"], "reservation": ["indexer"],
		"long_build": ["supply", "indexer", "chain_sink", "radiator", "triad"],
		"short_build": ["cooling_breech", "opening", "indexer", "coil", "igniter"]}
	var formations := {
		"swarm": [["runner", 12, 0, 2, 16], ["runner", 8, 0, 2, 20], ["runner", 8, 0, 2, 24]],
		"armored_support": [["wall", 24, 4, 1, 18], ["spitter", 14, 0, 0, 23], ["caster", 18, 1, 1, 25]]}
	var rows: Array = []
	for gun in Ammo.GUNS:
		for growth in range(3):
			for setup in configurations:
				for seed_value in [731042, 91407, 20261005]:
					for hot in [false, true]:
						for formation in formations:
							for strategy in ["short", "full"]:
								var model = Model.new()
								model.start(gun, seed_value)
								model.s.deck = ["prepare", "bore", "spread", "cool", "arc", "pierce", "sequence", "disrupt", "charge", "precise"]
								model.s.capacity_bonus = growth
								model.s.equipped_parts = configurations[setup].duplicate()
								model.begin_encounter()
								var order: Array = ["bore", "spread"] if strategy == "short" else ["prepare", "bore", "spread", "cool", "arc", "pierce", "basic"].slice(0, model.capacity() - 1) + ["sequence"]
								model.s.hand = order.filter(func(id): return id != "basic")
								model.s.draw = model.s.deck.duplicate()
								for id in model.s.hand: model.s.draw.erase(id)
								model.s.discard = []
								model.s.enemies = []
								for row in formations[formation]: model.s.enemies.append(Data._enemy(row))
								model.assign_opening_lanes()
								model.s.encounter_total = model.s.enemies.size()
								model.s.deployed = model.s.enemies.size()
								model.s.heat = Ammo.hot_threshold(model.s) if hot else 0
								for id in Ammo.loading_order(order): check(model.load_round(id), "scripted load legal")
								check(model.confirm(), "scripted confirm legal")
								while model.s.phase == "ready" and not model.s.magazine.is_empty(): check(model.fire(), "scripted trigger legal")
								var reserved: int = model.s.get("prepared", []).size()
								if model.s.phase == "ready": check(model.reload_magazine(), "optional manual reload legal")
								check(Model.new().restore_state(JSON.parse_string(JSON.stringify(model.s))), "inventory conserved")
								var report := Insight.combat_report(model.s)
								rows.append({"gun": gun, "growth": growth, "setup": setup, "seed": seed_value, "hot": hot, "formation": formation, "strategy": strategy, "capacity": model.capacity(), "cooling": Ammo.reload_cooling(model.s), "heat_limit": Ammo.heat_limit(model.s), "shots": report.shots, "turns": model.s.turns, "damage": report.direct + report.arc + report.burn, "kills": report.kills, "forced": report.forced_reloads, "chain_cooled": report.chain_cooled, "reserved": reserved, "heat_end": model.s.heat, "phase": model.s.phase})
	var output := OS.get_environment("QA_OUTPUT_DIR").path_join("build_synergy_audit.json")
	var file := FileAccess.open(output, FileAccess.WRITE)
	var timings: Array = []
	for enemy_kind in ["wall", "spitter", "caster"]:
		var enemies: Array = []
		for i in range(4): enemies.append([enemy_kind, 40, 0, 0 if enemy_kind == "spitter" else 1, 26 + i * 2])
		var model = fixture(["prepare", "bore", "spread", "cool", "disrupt", "sequence"], enemies, "scatter")
		model.s.capacity_bonus = 2
		model.s.equipped_parts = ["supply", "indexer", "chain_sink", "radiator"]
		model.s.supply = model.supply_capacity()
		for id in Ammo.loading_order(["prepare", "bore", "spread", "cool", "disrupt", "basic", "basic", "sequence"]): check(model.load_round(id), "stress eight-slot plan legal")
		var before := JSON.stringify(model.s)
		var started := Time.get_ticks_usec()
		var forecast := Forecast.analyze(model.s, true, true)
		var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
		check(JSON.stringify(model.s) == before, "stress forecast pure")
		timings.append({"enemies": enemy_kind, "count": 4, "slots": 8, "milliseconds": elapsed, "branches": forecast.branches})
		print("BUILD SYNERGY FOUR-ENEMY FORECAST %s elapsed_ms=%.1f branches=%d" % [enemy_kind, elapsed, forecast.branches])
	file.store_string(JSON.stringify({"cases": rows, "performance": timings, "checks": checks, "failures": failures, "scope": "Scripted volleys plus one optional reload; not optimized play or win rates."}, "\t"))
	print("BUILD SYNERGY AUDIT COMPLETE cases=%d checks=%d failures=%d" % [rows.size(), checks, failures])
	quit(0 if failures == 0 else 1)
