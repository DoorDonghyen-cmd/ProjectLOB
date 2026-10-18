extends "res://tests/ammo_expansion_rules_runner.gd"
func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/ammo_expansion/"):
		quit(1)
		return
	var results: Array = []
	for scenario in ["campaign", "stress", "cooled_eight"]:
		for capacity in [5, 8]:
			var rows: Array = []
			for i in range(4): rows.append(["wall", 40, 4, 1, 26 + i * 2])
			var ids: Array = ["charge_hot", "shatter", "precise", "bore", "detonate"]
			if scenario == "cooled_eight": ids = ["charge_hot", "precise", "cool", "shatter", "bore"]
			var model = fixture(ids, rows, "scatter")
			if scenario == "campaign":
				var pack := Data.encounter_pack({"id": 40801, "region": 4, "floor": 8, "kind": "boss", "name": "audit"}, 731042, "scatter", 0, 0)
				model.s.enemies = pack.active
				model.s.reinforcements = pack.reserve
				model.s.encounter_total = pack.total
				model.s.deployed = pack.active.size()
			if capacity == 8:
				model.s.capacity_bonus = 2
				model.s.equipped_parts = ["supply"]
			for id in ids: model.load_round(id)
			for i in range(capacity - 5): model.load_round("basic")
			var before := Time.get_ticks_usec()
			var result := Forecast.analyze(model.s, false, true)
			var elapsed := float(Time.get_ticks_usec() - before) / 1000.0
			results.append({"scenario": scenario, "capacity": capacity, "milliseconds": elapsed, "branches": result.branches, "fired_max": result.heat.fired_max, "peak_max": result.heat.peak_max})
			print("FORECAST ", scenario, " ", capacity, " rounds: ", elapsed, " ms / ", result.branches, " branches")
	FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("forecast_performance.json"), FileAccess.WRITE).store_string(JSON.stringify(results, "\t"))
	print("AMMO EXPANSION PERFORMANCE COMPLETE")
	quit()
