extends SceneTree
## Fire tag parts bench (2026-11-10, user "화염파츠 추가해 줘"). Earned reactor fights from the
## tag climb (QA_FIRE_DIR, seed 17, region 4-5 boss and elites) are replayed with different
## part sets on the same state; the solver's winning path length is the turn count.
const Campaign = preload("res://redesign/campaign.gd")
const Solver = preload("res://tests/fire_control_solver.gd")
const FIGHTS := ["combat_heavy_17_r4_n30902.json", "combat_heavy_17_r5_n40201.json", "combat_heavy_17_r5_n40602.json", "combat_heavy_17_r5_n41002.json"]
const SETS := {
	"climb (as bought)": [true, []],
	"fire tags": [true, ["compression_sink", "radiator", "tag_fire_add", "tag_fire_burn", "tag_burning_mult"]],
	"fire tags + copy": [true, ["radiator", "tag_fire_add", "tag_fire_burn", "tag_burning_mult", "tag_copy"]],
	"no fire status": [true, ["compression_sink", "radiator", "tag_fire_add", "tag_low_mult", "tag_variety"]],
	"current scheme": [false, ["coil", "igniter", "rammer", "compression_sink", "radiator"]],
}

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var output := OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\", "/").contains("/qa_runtime/tag_build_20261110/"): quit(2); return
	var solver = Solver.new()
	var report := {}
	var failures := 0
	for name in SETS:
		var row := []
		for file in FIGHTS:
			var c = Campaign.new()
			if not c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_FIRE_DIR").path_join(file)))):
				failures += 1; row.append(-1); continue
			var tags: bool = SETS[name][0]
			var parts: Array = SETS[name][1]
			if not tags: c.model.s.erase("tag_build_version")
			if not parts.is_empty():
				for id in parts:
					if not c.s.parts.has(id): c.s.parts.append(id)
				c.s.equipped_parts = parts.duplicate()
				c._sync_equipped_parts()
			var path: Array = solver.solve(c.model)
			if path.is_empty(): path = solver.solve(c.model, 12, 10)
			if path.is_empty():
				failures += 1; row.append(-1); continue
			# Turns as the climb counts them: enemy turns elapsed (reloads and forced cooling cost more).
			var m = c.model
			var start: int = int(m.s.turns)
			for step in path:
				match str(step.action):
					"fire":
						m.s.fire_heat_trial.rounds = int(step.get("rounds", 0)); m.fire()
					"cool": m.cool_magazine()
					"reload": m.reload_magazine()
					"emergency": m.emergency_resupply()
					"eject": m.eject_magazine_rounds(step.indices)
			if not m.s.phase in ["reward", "won"]: failures += 1
			row.append(int(m.s.turns) - start)
		var total := 0
		for value in row: total += maxi(0, int(value))
		report[name] = {"turns": row, "total": total}
		print("BENCH %-18s %s total %d" % [name, str(row), total])
	FileAccess.open(output.path_join("fire_bench.json"), FileAccess.WRITE).store_string(JSON.stringify({"fights": FIGHTS, "sets": report}, "  "))
	print("TAG FIRE BENCH failures=%d" % failures)
	quit(0 if failures == 0 else 1)
