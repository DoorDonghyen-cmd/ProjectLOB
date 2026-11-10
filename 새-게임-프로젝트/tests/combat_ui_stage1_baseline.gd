extends SceneTree
const Probe = preload("res://tests/combat_ui_stage1_probe_model.gd")
const Content = preload("res://redesign/content.gd")
const Forecast = preload("res://redesign/forecast.gd")
var failures: Array = []
var rows: Array = []
var out := ""

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)

func restore(path: String):
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var model = Probe.new()
	check(model.restore_state(data.combat), "Checkpoint restores: " + path)
	return model

func nearest(state: Dictionary) -> int:
	var result := 999
	for e in state.enemies:
		if e.hp > 0: result = mini(result, int(e.distance))
	for p in state.get("projectiles", []):
		if p.hp > 0: result = mini(result, int(p.distance))
	return result

func command(model, action: Dictionary) -> bool:
	match str(action.action):
		"load": return model.load_round(str(action.id))
		"confirm": return model.confirm()
		"fire": return model.fire()
		"reload": return model.reload_magazine()
	return false

func run() -> void:
	out = OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/combat_ui_stage1_20261031/") or out.is_empty():
		push_error("Isolated QA directory required"); quit(2); return
	var source := ProjectSettings.globalize_path("res://../qa_runtime/combat_rhythm_20261030/matrix_final")
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(source.path_join("results.json")))
	for item in report.battles:
		if int(item.version) != 12: continue
		var name := "combat_%s_%d_v12_%s_n%d.json" % [item.gun, int(item.seed), item.outfit, int(item.node)]
		var model = restore(source.path_join(name))
		var steps: Array = []
		var minimum := nearest(model.s)
		var total_advance := 0
		var start_turns: int = model.s.turns
		for action in item.path:
			var before: Dictionary = model.s.duplicate(true)
			model.advance_calls.clear()
			check(command(model, action), "Legal replay: " + name + ":" + str(action))
			var requested := 0
			for call in model.advance_calls: requested += int(call.requested_turns)
			total_advance += requested
			minimum = mini(minimum, nearest(model.s))
			var delta: int = int(model.s.turns) - int(before.turns)
			if action.action in ["load", "confirm"]: check(delta == 0 and requested == 0, "Preparation is free")
			steps.append({"action": action, "turns": delta, "enemy_action_turns": requested, "nearest_before": nearest(before), "nearest_after": nearest(model.s), "heat_before": before.heat, "heat_after": model.s.heat, "phase": model.s.phase, "shot_count": int(model.s.shots)-int(before.shots)})
		check(model.s.phase in ["reward", "won"], "Baseline still clears: " + name)
		check(int(model.s.turns)-start_turns == int(item.turns) and model.s.discard.size() == int(item.used), "Replay matches prior earned-route turns and ammo")
		rows.append({"checkpoint": name, "gun": item.gun, "node": item.node, "role": item.role, "boss": item.boss, "turns": int(model.s.turns)-start_turns, "enemy_action_turns": total_advance, "nearest_observed": minimum, "inputs": item.path.size(), "steps": steps})
	# One real, earned state for BOTH composition candidates. These are current
	# rules; the proposed whole-magazine mechanic is deliberately not simulated.
	var fixture_path := source.path_join("combat_single_731042_v12_carrier_n401.json")
	var original = restore(fixture_path)
	check(original.reload_magazine(), "Open shield through legal reload")
	for id in ["basic_p2", "basic_p3", "charge"]: check(original.load_round(id), "Earned preview round " + id)
	var state: Dictionary = original.s.duplicate(true)
	state.history = []
	var unchanged := JSON.stringify(state)
	var prediction := Forecast.analyze(state, true, true)
	check(JSON.stringify(state) == unchanged, "Forecast does not mutate fixture")
	var reload_copy = Probe.new(); reload_copy.s = state.duplicate(true)
	check(reload_copy.reload_magazine(), "Preview reload legal")
	var fixture := {"source": fixture_path, "note": "Legal earned checkpoint, one reload, three legal insertions; current rules, composition preview only.", "state": state, "prediction": prediction, "reload": {"turns": int(reload_copy.s.turns)-int(state.turns), "phase": reload_copy.s.phase, "enemies": reload_copy.s.enemies}, "capacity": original.capacity(), "heat_limit": Content.heat_limit(state), "reload_cost": original.reload_cost()}
	FileAccess.open(out.path_join("fixture.json"), FileAccess.WRITE).store_string(JSON.stringify(fixture, "  "))
	var danger = restore(fixture_path)
	var waits := 0
	while nearest(danger.s) > 2 and waits < 20:
		check(danger.reload_magazine(), "Legal wait for pressure fixture")
		waits += 1
	for id in ["basic_p2", "basic_p3", "charge"]: check(danger.load_round(id), "Pressure fixture earned round")
	danger.s.history = []
	var danger_prediction := Forecast.analyze(danger.s, true, true)
	var danger_reload = Probe.new(); danger_reload.s = danger.s.duplicate(true)
	check(danger_reload.reload_magazine(), "Pressure reload resolves")
	check(danger_reload.s.phase == "lost", "Pressure fixture truthfully warns of lethal reload")
	var pressure := {"source": fixture_path, "note": "Deliberate repeated empty reloads for a legal danger-state UI fixture; not evidence of ordinary gameplay pressure.", "waits": waits, "state": danger.s, "prediction": danger_prediction, "reload": {"turns": int(danger_reload.s.turns)-int(danger.s.turns), "phase": danger_reload.s.phase, "enemies": danger_reload.s.enemies}, "capacity": danger.capacity(), "heat_limit": Content.heat_limit(danger.s), "reload_cost": danger.reload_cost()}
	FileAccess.open(out.path_join("pressure.json"), FileAccess.WRITE).store_string(JSON.stringify(pressure, "  "))
	FileAccess.open(out.path_join("baseline.json"), FileAccess.WRITE).store_string(JSON.stringify({"note": "Replay of bounded solver routes with earned decks; not human play, typical difficulty, or optimal strategy.", "battles": rows, "failures": failures}, "  "))
	print("STAGE1 BASELINE COMPLETE battles=%d failures=%d" % [rows.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)
