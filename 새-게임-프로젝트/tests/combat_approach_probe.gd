extends SceneTree
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const Forecast = preload("res://redesign/forecast.gd")
const SOURCES := {
	"sweep": "matrix_final/combat_single_731042_v12_carrier_n201.json",
	"breach": "matrix_final/combat_single_731042_v12_carrier_n401.json",
	"ambush": "work17_final/combat_single_17_v12_work_n301.json",
	"payoff": "matrix_final/combat_single_731042_v12_carrier_n602.json",
	"boss": "matrix_final/combat_single_731042_v12_carrier_n802.json"
}
var rows: Array = []

func _initialize() -> void: call_deferred("run")

func source(role: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://redesign/samples/combat_approach_%s.json" % role)).state

func build(role: String, scale_value: float, speed_bonus: int, order_seed: int):
	var model = Model.new(); model.restore_state(source(role))
	model.s.magazine_trial_version = 1
	model.s.history = []
	for enemy in model.s.enemies + model.s.reinforcements:
		if int(enemy.speed) <= 0: continue
		enemy.distance = maxi(4, ceili(float(enemy.distance) * scale_value))
		enemy.speed = int(enemy.speed) + speed_bonus
	if order_seed > 0:
		var rng := RandomNumberGenerator.new(); rng.seed = order_seed; model.s.rng_state = str(rng.state)
		model.s.draw = model.s.hand + model.s.draw; model.s.hand = []; model._shuffle(model.s.draw)
	model.trial_load_magazine()
	return model

func margin(model) -> int:
	var result := 999
	for enemy in model.s.enemies:
		if int(enemy.hp) > 0 and int(enemy.speed) > 0: result = mini(result, ceili(float(enemy.distance) / int(enemy.speed)))
	return result

func command(model, action: String) -> bool:
	match action:
		"fire": return model.fire()
		"cool": return model.cool_magazine()
		"swap": return model.reload_magazine()
		"emergency": return model.emergency_resupply()
	return false

func policy(model, careful: bool) -> String:
	if model.can_emergency_resupply(): return "emergency"
	if model.s.magazine.is_empty(): return "swap"
	if careful and int(model.s.heat) > 0:
		var prediction := Forecast.analyze(model.s, true)
		if float(prediction.heat.forced_probability) > 0: return "cool"
	return "fire"

func simulate(model, careful: bool) -> Dictionary:
	var start: int = model.s.turns
	var min_margin := margin(model)
	var close_decisions := 0
	var danger_choices := 0
	var path: Array = []
	for step in range(40):
		if model.s.phase not in ["ready", "plan"]: break
		var m := margin(model); min_margin = mini(min_margin, m)
		if m <= 2: close_decisions += 1
		var action := policy(model, careful)
		path.append(action)
		if not command(model, action): break
	return {"phase": model.s.phase, "turns": int(model.s.turns) - start, "min_contact_actions": min_margin, "close_decisions": close_decisions, "used": model.s.discard.size(), "path": path, "loss_reason": model.s.get("loss_reason", "")}

func run() -> void:
	var out := OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/combat_approach_20261031/"): quit(2); return
	for role in SOURCES:
		for scale_value in [1.0, 0.8, 0.65, 0.5, 0.4]:
			for bonus in [0, 1]:
				for seed_value in [0, 17, 1042, 731042, 900001, 1200411]:
					for careful in [false, true]:
						var result := simulate(build(role, scale_value, bonus, seed_value), careful)
						result.merge({"role": role, "scale": scale_value, "speed_bonus": bonus, "order_seed": seed_value, "careful": careful})
						rows.append(result)
	FileAccess.open(out.path_join("probe.json"), FileAccess.WRITE).store_string(JSON.stringify({"rows": rows, "note": "Same earned state, candidate mover-distance/speed and shuffled-order variations. Fixed policies; not optimal play or human win rate."}, "  "))
	print("APPROACH PROBE COMPLETE rows=%d" % rows.size())
	quit()
