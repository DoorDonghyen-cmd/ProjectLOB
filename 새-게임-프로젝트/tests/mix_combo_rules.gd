extends SceneTree
## 교차 사격 rules (2026-11-11, mix_combo.gd): switching attack families within a magazine adds
## +1 per hit per switch in a row (max +3); real fire() on an earned region-3 combat.
const Campaign = preload("res://redesign/campaign.gd")
const Model = preload("res://redesign/model.gd")
const Mix = preload("res://redesign/mix_combo.gd")
const Readout = preload("res://redesign/damage_readout.gd")
var checks := 0
var failures: Array = []
var base_state: Dictionary

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label); print("FAIL: " + label)
	return ok

## Fire the magazine one round per action from a fresh load; returns each shot result.
func volley(rounds: Array, flag := true) -> Array:
	var m := Model.new()
	m.s = Model.simulation_state(base_state)
	if flag: m.s.mix_combo_version = Mix.VERSION
	else: m.s.erase("mix_combo_version")
	m.s.equipped_parts = []; m.s.heat = 0; m.s.buff = {}
	for e in m.s.enemies:
		e.hp = 999; e.max_hp = 999; e.def = 0; e.barrier = 0
	m.s.magazine = rounds.duplicate()
	m.s.history.append({"action": "load", "floor": m.s.floor, "turn": m.s.turns, "detail": {}})
	var shots: Array = []
	for i in range(rounds.size()):
		if m.s.phase != "ready": break
		m.s.heat = 0
		if m.FireHeatTrial.enabled(m.s): m.s.fire_heat_trial.rounds = 1
		m.fire()
		shots.append_array(m.s.history.back().detail.get("results", []))
	return shots

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	var c = Campaign.new()
	check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_BUILD_DIR").path_join("combat_heavy_17_r3_n20101.json")))), "earned combat restores")
	base_state = c.model.s
	# Levels.
	check(Mix.level(["precise", "pierce", "precise", "bore"]) == 3, "three switches → 3")
	check(Mix.level(["precise", "precise"]) == 0, "same family → 0")
	check(Mix.level(["precise", "pierce", "pierce"]) == 0, "same again resets")
	check(Mix.level(["precise", "basic", "charge", "pierce"]) == 1, "basic and support neither count nor reset")
	check(Mix.level(["precise", "pierce", "bore", "arc", "precise"]) == 3, "capped at 3")
	# Real shots.
	var mixed := volley(["precise", "pierce", "precise", "bore"])
	var crosses: Array = mixed.map(func(r): return int(r.get("math", {}).get("cross", 0)))
	print("CROSS ", crosses)
	check(crosses == [0, 1, 2, 3], "fired one by one: +0 +1 +2 +3")
	var plain := volley(["precise", "pierce", "precise", "bore"], false)
	check(plain.all(func(r): return int(r.get("math", {}).get("cross", 0)) == 0), "older saves: no 교차")
	for i in range(mini(mixed.size(), plain.size())):
		check(int(mixed[i].math.subtotal) == int(plain[i].math.subtotal) + int(crosses[i]), "subtotal +%d on shot %d" % [crosses[i], i + 1])
	var mono := volley(["precise", "precise", "precise"])
	check(mono.all(func(r): return int(r.get("math", {}).get("cross", 0)) == 0), "one-family magazine: nothing")
	check(str(Readout.entry(mixed[2]).label).begins_with("교차+2"), "hit float starts with 교차+2: " + str(Readout.entry(mixed[2]).label))
	check(not str(Readout.entry(mono[1]).label).contains("교차"), "no 교차 label without a switch")
	# New runs and saves.
	var fresh = Campaign.new(); fresh.start("burst", 731042, 0, "balanced", Campaign.Content.RouteMap.VERSION, "carrier", true)
	check(Mix.enabled(fresh.model.s), "new runs carry 교차 사격")
	var broken: Dictionary = JSON.parse_string(fresh.model.serialized_state())
	broken.mix_combo_version = 2
	check(not Model.new().restore_state(broken), "unknown version rejected")
	print("MIX COMBO RULES checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
