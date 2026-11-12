extends SceneTree
## Part value bench (2026-11-11, user: "파츠 효과가 지금 탄환과 전투에 적합한지 검토해 줘").
## Earned region-4/5 fights from the latest climb (QA_FIGHT_DIR, mixed decks, current rules) are
## replayed with ONE part equipped at a time (the gun's built-in drive stays on). The solver's
## winning path gives enemy turns; activations count shots whose part_effects name the part.
## QA_GUN picks the gun; results go to QA_OUTPUT_DIR/part_value_<gun>.json.
const Campaign = preload("res://redesign/campaign.gd")
const Content = preload("res://redesign/content.gd")
const Solver = preload("res://tests/fire_control_solver.gd")
const PARTS := ["ordinary_chain", "compression_sink", "cooling_breech", "chain_sink", "radiator", "reclaimer", "ember_core",
	"lens", "loader", "supply", "coil", "capacitor", "rammer", "sequencer", "duplex", "igniter", "breaker", "executioner",
	"reserve", "opening", "third_striker", "resonator", "tally", "afterburner", "field_press", "overbore", "inferno",
	"arc_splitter", "momentum", "triad"]

func _initialize() -> void: run.call_deferred()

func play(file: String, part: String) -> Dictionary:
	var c = Campaign.new()
	if not c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(file))): return {"error": "restore"}
	var parts: Array = [] if part.is_empty() else [part]
	if not part.is_empty():
		if not Content.valid_part_set(str(c.s.gun), parts, c.model.s): return {"invalid": true}
		if not c.s.parts.has(part): c.s.parts.append(part)
	c.s.equipped_parts = parts
	c._sync_equipped_parts()
	var solver = Solver.new()
	var path: Array = solver.solve(c.model)
	if path.is_empty(): path = solver.solve(c.model, 12, 10)
	if path.is_empty(): return {"won": false, "turns": 0, "shots": 0, "active": 0}
	var m = c.model
	var start := int(m.s.turns)
	var first_history: int = m.s.history.size()
	for step in path:
		match str(step.action):
			"fire":
				m.s.fire_heat_trial.rounds = int(step.get("rounds", 0)); m.fire()
			"cool": m.cool_magazine()
			"reload": m.reload_magazine()
			"emergency": m.emergency_resupply()
			"eject": m.eject_magazine_rounds(step.indices)
	var shots := 0
	var active := 0
	for i in range(first_history, m.s.history.size()):
		for shot in m.s.history[i].get("detail", {}).get("results", []):
			shots += 1
			if shot.get("part_effects", []).any(func(effect): return str(effect.get("id", "")) == part): active += 1
	return {"won": m.s.phase in ["reward", "won"], "turns": int(m.s.turns) - start, "shots": shots, "active": active}

func run() -> void:
	var output := OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	var gun := OS.get_environment("QA_GUN")
	var folder := OS.get_environment("QA_FIGHT_DIR")
	var files: Array = []
	for name in DirAccess.get_files_at(folder):
		if name.begins_with("combat_%s_" % gun) and ("_r4_" in name or "_r5_" in name): files.append(folder.path_join(name))
	files.sort()
	# Four fights spread over regions 4-5.
	var picked: Array = []
	for k in range(4): picked.append(files[int(k * (files.size() - 1) / 3.0)])
	var report := {"gun": gun, "fights": picked.map(func(f): return str(f).get_file()), "parts": {}}
	var base := {"turns": 0, "won": 0}
	for file in picked:
		var r := play(file, "")
		base.turns += int(r.get("turns", 0)); base.won += 1 if r.get("won", false) else 0
	report.base = base
	print("BASE %s turns %d won %d/4" % [gun, base.turns, base.won])
	# QA_PARTS=a,b: only these parts (re-measuring after a fix).
	var only := OS.get_environment("QA_PARTS")
	for part in (PARTS if only.is_empty() else Array(only.split(","))):
		var row := {"turns": 0, "won": 0, "shots": 0, "active": 0, "invalid": false}
		for file in picked:
			var r := play(file, part)
			if r.get("invalid", false): row.invalid = true; break
			row.turns += int(r.get("turns", 0)); row.won += 1 if r.get("won", false) else 0
			row.shots += int(r.get("shots", 0)); row.active += int(r.get("active", 0))
		report.parts[part] = row
		print("PART %s %s turns %d (base %d) won %d active %d/%d%s" % [gun, part, row.turns, base.turns, row.won, row.active, row.shots, " INVALID" if row.invalid else ""])
	FileAccess.open(output.path_join("part_value_%s.json" % gun), FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	quit(0)
