extends SceneTree
## Build engine trial: the same earned 래칫 fights (2026-11-06 full climb, regions 3-5)
## with the recorded parts versus the 연타·결정타 trial set. Two policies: the beam
## solver's best line, and 'keep firing' (fire when ready, otherwise swap/cool).
## Outputs QA_OUTPUT_DIR/build_engine_fights.json for the design report.
const Campaign = preload("res://redesign/campaign.gd")
const Model = preload("res://redesign/model.gd")
const Search = preload("res://tests/weapon_magazine_solver.gd")
const Solver = preload("res://tests/campaign_magazine_solver.gd")
const BuildEngine = preload("res://redesign/build_engine.gd")
const FIGHTS := ["combat_burst_17_r3_n20502.json", "combat_burst_17_r3_n20902.json", "combat_burst_17_r4_n30501.json", "combat_burst_17_r4_n30701.json", "combat_burst_17_r5_n40201.json", "combat_burst_17_r5_n41002.json"]
var solver = Solver.new()

func _initialize() -> void: run.call_deferred()

func variant(state: Dictionary, label: String) -> Model:
	var m := Model.new()
	m.s = Model.simulation_state(state)
	match label:
		"trial":
			# Keep the core, duplex and third striker; swap the two side parts.
			m.s.build_engine_version = BuildEngine.VERSION
			m.s.equipped_parts = ["volley_drive", "third_striker", "duplex", "resonator", "tally"]
			m.s.part_growth = {"tally": 0}
		"trial_grown":
			m.s.build_engine_version = BuildEngine.VERSION
			m.s.equipped_parts = ["volley_drive", "third_striker", "duplex", "resonator", "tally"]
			m.s.part_growth = {"tally": 9}
	return m

func summary(m: Model, steps: int) -> Dictionary:
	var nearest := 999
	for e in m.s.enemies:
		if int(e.hp) > 0: nearest = mini(nearest, int(e.distance))
	return {"won": m.s.phase in ["reward", "won"], "turns": int(m.s.get("turns", 0)), "steps": steps, "phase": str(m.s.phase), "alive": m.s.enemies.filter(func(e): return int(e.hp) > 0).size()}

func keep_firing(m: Model) -> Dictionary:
	var steps := 0
	while m.s.phase in ["plan", "ready"] and steps < 80:
		var options: Array = Search.actions(m)
		if options.is_empty(): break
		var action: String = "fire" if options.has("fire") else ("swap" if options.has("swap") else options[0])
		if not Search.command(m, action): break
		steps += 1
	return summary(m, steps)

func best_line(m: Model) -> Dictionary:
	var path: Array = solver.solve(m, 4, 18)
	var steps := 0
	for step in path:
		var ok := false
		if step.action == "eject": ok = m.eject_magazine_rounds(step.indices)
		else: ok = Search.command(m, "swap" if step.action == "reload" else str(step.action))
		if not ok: break
		steps += 1
	var result := summary(m, steps)
	result.found = not path.is_empty()
	return result

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	var rows: Array = []
	for file in FIGHTS:
		var c = Campaign.new()
		if not c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_BUILD_DIR").path_join(file)))):
			print("SKIP ", file); continue
		var hp: Array = c.model.s.enemies.map(func(e): return int(e.hp))
		for label in ["recorded", "trial", "trial_grown"]:
			var fire := keep_firing(variant(c.model.s, label))
			var best := best_line(variant(c.model.s, label))
			var row := {"fight": file, "enemy_hp": hp, "parts": label, "keep_firing": fire, "best": best}
			rows.append(row)
			print("FIGHT %s %-12s fire:%s t%d  best:%s t%d" % [file.get_slice("_", 3) + "_" + file.get_slice("_", 4).get_basename(), label, "W" if fire.won else "L", fire.turns, "W" if best.won else "L", best.turns])
	var out := FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("build_engine_fights.json"), FileAccess.WRITE)
	out.store_string(JSON.stringify(rows, "\t"))
	out.close()
	print("BUILD ENGINE FIGHTS COMPLETE rows=%d" % rows.size())
	quit(0)
