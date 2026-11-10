extends "res://tests/reactor_rules_runner.gd"

var cases := 0

func active(ids: Array, gun: String = "heavy", rows: Array = []) -> RefCounted:
	var m = fixture(ids, rows if not rows.is_empty() else [["runner",200,0,1,80]], gun)
	m.s.sustained_version = 1
	m.s.sustained_attacks = 0
	return m

func assert_restore(m: RefCounted) -> RefCounted:
	var copy = Model.new()
	check(copy.restore_state(JSON.parse_string(JSON.stringify(m.s))), "active save accepted")
	check(Ammo.Sustained.count(copy.s) == Ammo.Sustained.count(m.s), "save preserves consecutive attacks")
	return copy

func run_exact() -> void:
	var six: Array = ["basic_p2","basic_p2","basic_p2","basic_p2","basic_p2","basic_p2"]
	var m = active(six)
	var detail := execute(m,six)
	check(detail.results.map(func(r):return int(r.heat_added)) == [2,2,3,3,4,4], "six attacks add 2,2,3,3,4,4 heat")
	check(detail.results.map(func(r):return int(r.sustained_heat)) == [0,0,1,1,2,2], "B1 starts on third attack and caps at two")
	check(detail.heat_peak == 18 and detail.results.size() == 6 and detail.forced_reload.cost == 4 and m.s.turns == 5, "Reactor six basic cards pays firing plus four reload turns")
	check(Ammo.Sustained.count(m.s) == 0, "forced reload resets count")
	var cold: Array = six.duplicate();cold[5] = "cool"
	m = active(cold);detail = execute(m,cold)
	check(detail.forced_reload.is_empty() and m.s.heat == 11 and m.s.turns == 1, "sixth cooling card escapes forced reload")
	check(detail.results.back().sustained_after == 0 and Ammo.Sustained.count(m.s) == 0, "cooling breaks streak")
	check(m.reload_magazine() and m.s.turns == 3 and Ammo.Sustained.count(m.s) == 0, "voluntary reload pays actual cost")
	m = fixture(six,[["runner",200,0,1,80]],"heavy");detail = execute(m,six)
	check(m.s.heat == 12 and m.s.turns == 1 and detail.forced_reload.is_empty(), "unmarked legacy retains old heat")
	m = active(["basic_p2","basic_p2","basic_p2"],"amplifier")
	execute(m,["basic_p2","basic_p2","basic_p2"])
	check(m.s.heat == 2 and Ammo.Sustained.count(m.s) == 1, "Spike first trigger counts one attack")
	check(m.fire() and m.s.heat == 4 and Ammo.Sustained.count(m.s) == 2, "second trigger does not reset")
	var copy = assert_restore(m)
	check(copy.fire() and m.fire() and copy.s.heat == 7 and m.s.heat == 7 and Ammo.Sustained.count(copy.s) == 3, "save between triggers cannot erase third attack heat")
	check(JSON.parse_string(JSON.stringify(copy.s.enemies)) == JSON.parse_string(JSON.stringify(m.s.enemies)) and copy.s.target_rng_state == m.s.target_rng_state, "restored third attack has same result and RNG")
	check(m.reload_magazine() and Ammo.Sustained.count(m.s) == 0, "Spike reload resets count")

func run_effects() -> void:
	var ids: Array = ["basic_p2","charge","precise","basic_p2","cool"]
	var m = active(ids)
	var detail := execute(m,ids)
	check(detail.results.map(func(r):return int(r.sustained_after)) == [1,1,2,3,0], "support preserves, multihit/compression count once, cool resets")
	check(detail.results[2].hits > 1 and detail.results[2].sustained_heat == 0 and detail.results[3].sustained_heat == 1, "extra hits do not reach next heat tier")
	m = active(["pierce_c","basic_p2","basic_p2"])
	detail = execute(m,["pierce_c","basic_p2","basic_p2"])
	check(detail.results.map(func(r):return int(r.sustained_after)) == [1,2,3], "compressed card counts once")
	m = active(["basic_p2","basic_p2","vent"])
	detail = execute(m,["basic_p2","basic_p2","vent"])
	check(detail.results.back().sustained_heat == 0 and detail.results.back().sustained_after == 0, "vent attack clears without additional heat")
	m = active(["basic_p2","basic_p2","basic_p2"])
	m.s.equipped_parts = ["chain_sink"]
	detail = execute(m,["basic_p2","basic_p2","basic_p2"])
	check(detail.results.back().chain_cooled > 0 and detail.results.back().sustained_after == 3, "passive third-shot cooling does not clear count")
	m = active(["basic_p2","basic_p2"],"heavy",[["runner",1,0,1,75],["runner",200,0,1,80]])
	m.s.equipped_parts = ["reclaimer"]
	detail = execute(m,["basic_p2","basic_p2"])
	check(detail.results[0].kill_cooled > 0 and detail.results[1].sustained_after == 2, "kill cooling preserves streak")
	m = active(["basic_p2"],"single",[["runner",1,0,1,80]])
	execute(m,["basic_p2"])
	check(m.s.phase == "reward" and Ammo.Sustained.count(m.s) == 0, "terminal kill resets encounter count")
	m = active(["basic_p2"],"single",[["runner",1,0,1,75]])
	m.s.reinforcements = [Data._enemy(["runner",200,0,1,80])];m.s.encounter_total = 2
	execute(m,["basic_p2"])
	check(m.s.phase == "ready" and Ammo.Sustained.count(m.s) == 1, "reinforcement is same encounter and keeps count")
	m.begin_encounter();check(Ammo.Sustained.count(m.s) == 0, "new encounter clears count")
	m = active(["basic_p2"],"single")
	m.s.reserve_version = 1;m.s.emergency_version = 1;m.s.inventory_version = 1;m.s.emergency_uses = 0
	m.s.draw = [];m.s.discard = m.s.deck.duplicate();m.s.discard.erase("basic_p2")
	execute(m,["basic_p2"])
	check(m.can_emergency_resupply() and m.emergency_resupply() and Ammo.Sustained.count(m.s) == 0, "emergency reload clears streak")
	assert_restore(m)

func run_saves() -> void:
	var m = active(["basic_p2","basic_p2","basic_p2"],"amplifier")
	execute(m,["basic_p2","basic_p2","basic_p2"])
	var target = assert_restore(m)
	var untouched := JSON.stringify(target.s)
	for change in [{"sustained_version":2},{"sustained_version":0.5},{"sustained_attacks":-1},{"sustained_attacks":1.5},{"sustained_attacks":1000001},{"sustained_attacks":2},{"sustained_version":0}]:
		var invalid: Dictionary = m.s.duplicate(true);invalid.merge(change,true)
		check(not target.restore_state(invalid) and JSON.stringify(target.s) == untouched, "invalid version/count rejected atomically " + str(change))
	var missing: Dictionary = m.s.duplicate(true);missing.erase("sustained_attacks")
	check(not target.restore_state(missing), "active save requires explicit count")
	var c = Campaign.new();c.start("amplifier",731042)
	check(c.s.sustained_version == 1 and c.model.s.sustained_version == 1 and Ammo.Sustained.count(c.model.s) == 0, "new campaign opts into B1")
	check(c.save("user://sustained.json") == OK, "new campaign saves")
	var restored = Campaign.new();check(restored.restore("user://sustained.json"), "new campaign restores")
	var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://sustained.json"))
	var mismatch: Dictionary = record.duplicate(true);mismatch.campaign.sustained_version = 0
	check(not restored.restore_state(mismatch), "campaign and combat rule mismatch rejected")
	record.campaign.erase("sustained_version");record.combat.erase("sustained_version");record.combat.erase("sustained_attacks")
	check(restored.restore_state(record) and not Ammo.Sustained.enabled(restored.model.s), "unmarked previous campaign remains legacy")
	check(restored.save("user://sustained_legacy.json") == OK and Campaign.new().restore("user://sustained_legacy.json"), "legacy stays loadable after saving again")

func run_matrix() -> void:
	for gun in Ammo.GUNS:
		for core in ["","volley_drive","siege_drive","thermal_drive"]:
			for initial_heat in [0,7]:
				for prior in [0,2]:
					cases += 1
					var ids: Array = ["basic_p2","basic_p2"]
					var m = active(ids,gun)
					m.s.heat = initial_heat
					if not core.is_empty():m.s.equipped_parts = [core]
					for id in Ammo.loading_order(ids):check(m.load_round(id), "matrix legal load")
					check(m.confirm(), "matrix confirms")
					m.s.sustained_attacks = prior;m.s.shots = prior
					while m.s.phase == "ready" and not m.s.magazine.is_empty():
						var original := JSON.stringify(m.s)
						var pred := Forecast.analyze(m.s,true,true)
						check(JSON.stringify(m.s) == original, "matrix forecast pure")
						check(m.fire(), "matrix real fire")
						var detail: Dictionary = m.s.history.back().detail
						check(m.s.heat >= pred.heat.end_min and m.s.heat <= pred.heat.end_max, "matrix forecast contains actual heat")
						check(detail.results.size() >= pred.heat.fired_min and detail.results.size() <= pred.heat.fired_max, "matrix forecast contains actual fired count")
						if gun != "scatter":
							check(pred.enemies == m.s.enemies and pred.projectiles == m.s.projectiles and pred.remaining == m.s.magazine, "matrix exact enemies/projectiles/remaining")
						else:
							for i in detail.results.size():check(detail.results[i].sustained_heat == pred.shots[i].sustained_heat, "random branches carry same attack count")
						assert_restore(m)
	# Same inventory, RNG and temperature; only count differs. Cached scatter result must differ.
	var m = active(["basic_p2","basic_p2","basic_p2"],"scatter",[["runner",200,0,1,75],["runner",200,0,1,80]])
	for id in m.s.hand.duplicate():m.load_round(id)
	m.confirm();m.s.shots = 2
	var before := Forecast.analyze(m.s,true,true)
	m.s.sustained_attacks = 2
	var after := Forecast.analyze(m.s,true,true)
	check(before.shots[0].sustained_heat == 0 and after.shots[0].sustained_heat == 1 and before.heat.peak_max < after.heat.peak_min, "scatter cache distinguishes consecutive count")
	check(m.fire() and m.s.heat == after.heat.end_max, "scatter branches match actual cumulative heat")
	assert_restore(m)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/playtest_revision_20261026/"):quit(2);return
	run_exact();run_effects();run_saves();run_matrix()
	FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("rules.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"matrix_cases":cases},"  "))
	print("PLAYTEST REVISION SUSTAINED COMPLETE checks=%d failures=%d matrix=%d" % [checks,failures,cases])
	quit(1 if failures else 0)
