extends "res://tests/city_campaign_runner.gd"
## Compare already executed real-command traces; never manufacture a new replay.
func _run() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_LEGACY_EXPECTED")))
	var actual: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_LEGACY_ACTUAL")))
	check(actual.runs.size() == 10 and expected.runs.size() == 10, "ten executed legacy runs")
	check(actual.failures.size() == 10 and actual.failures.all(func(f): return f == "economy tuning preserves exact combat history"), "only known old comparison failed")
	var commands_total := 0
	for i in range(actual.runs.size()):
		var old: Dictionary = expected.runs[i]
		var now: Dictionary = actual.runs[i]
		check(old.gun == now.gun and old.route == now.route and now.won and now.campaign.visited.size() == 35, "same winning legacy route")
		check(old.commands == now.commands, "every command phase/node/credits/turn unchanged")
		commands_total += now.commands.size()
		for key in ["credits", "slots", "parts", "equipped_parts", "visited", "phase", "clears", "compressor_charges"]:
			check(old.campaign[key] == now.campaign[key], "legacy final " + key)
		check(JSON.stringify(now.combat) == JSON.stringify(current_story_names(old.combat)), "all combat fields equal after approved name migration")
		var tampered: Dictionary = now.combat.duplicate(true)
		tampered.shots += 1
		check(JSON.stringify(tampered) != JSON.stringify(current_story_names(old.combat)), "migration never masks numeric differences")
	var result := {"checks": checks, "failures": failures, "commands": commands_total, "runs": actual.runs.size(), "comparison": "Only final gate name and its localized hit text are migrated. All other combat fields and every recorded command match."}
	var file := FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("legacy_comparison.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("LEGACY COMPARISON COMPLETE checks=%d failures=%d commands=%d" % [checks, failures.size(), commands_total])
	quit(0 if failures.is_empty() else 1)
