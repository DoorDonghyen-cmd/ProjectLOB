extends "res://tests/fire_heat_rules.gd"

const TrialData = preload("res://redesign/samples/wreckage_trial_data.gd")
const Insight = preload("res://redesign/run_insight.gd")

func fire_round(model) -> Dictionary:
	var result: Dictionary = verify_fire(model).results[0]
	return result

func run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\", "/").contains("/qa_runtime/wreckage_trial/"): quit(2); return
	var campaign := TrialData.make()
	if campaign == null: push_error("foundry trial cannot enter"); quit(2); return
	var m = campaign.model
	var death := fire_round(m)
	check(death.wreckage_spawn == {0: 2} and m.s.enemies[0].distance == 12, "mold worker leaves two stacks at the actual death point")
	var ash_hp: int = m.s.enemies[1].hp
	var stopped := fire_round(m)
	check(stopped.wreckage_hit == 1 and stopped.wreckage_left == 1 and m.s.enemies[1].hp == ash_hp, "ordinary round spends one stack with no rear damage")
	check(not m.s.previous_kill and m.alive_count() == 1, "wreck strike earns no kill")
	check(Insight.combat_report(m.s).kills == 1 and Forecast.outcome(stopped) == "잔해 −1칸", "wreck strike is not reported as another kill")
	var file := output.path_join("mid_encounter.json")
	check(campaign.save(file) == OK, "campaign can save active wreckage")
	var resumed = TrialData.Campaign.new()
	check(resumed.restore(file) and int(resumed.model.s.enemies[0].wreckage) == 1, "campaign resumes the remaining stack")
	var pierced := fire_round(m)
	check(pierced.wreckage_left == 0 and m.s.enemies[1].hp == ash_hp, "clearing projectile does not carry through")
	check(fire_round(m).target == 1 and m.s.enemies[1].hp < ash_hp, "next round damages the exposed enemy")
	m = TrialData.make().model
	m.s.fire_heat_trial.rounds = 2
	var salvo: Array = verify_fire(m).results
	check(salvo.size() == 2 and salvo[0].has("wreckage_spawn") and salvo[1].has("wreckage_hit"), "second round in the same salvo already meets the new wreck")
	m = TrialData.make().model
	fire_round(m)
	check(m.cool_magazine() and m.reload_magazine(), "cooling and reloading spend real approach actions")
	check(int(m.s.enemies[1].distance) <= int(m.s.enemies[0].distance), "survivor walks past its cover while the player waits")
	check(fire_round(m).target == 1 and int(m.s.enemies[0].wreckage) == 2, "waiting gives a clean shot without clearing cover")
	for id in ["pierce", "precise"]:
		m = TrialData.make("single", ["basic_p2", id, "basic_p2"]).model
		fire_round(m)
		var clearing := fire_round(m)
		check(clearing.wreckage_hit == 2 and clearing.wreckage_left == 0, "%s clears two stacks" % id)
	m = TrialData.make("single", ["basic_p2", "basic_p2"]).model
	fire_round(m)
	m.s.enemies[1].distance = 12
	m.s.enemies[1].hp = 1
	check(fire_round(m).target == 1 and m.s.phase == "reward" and m.s.enemies[0].wreckage == 2, "equal distance exposes the target and inert cover cannot block victory")
	m = TrialData.make().model
	fire_round(m)
	var shooter := TrialData.Data._enemy(TrialData.Workers.worker("pressure_worker", 6, 36))
	shooter.ranged_phase = "waiting"
	shooter.ranged_left = 0
	m.s.enemies.append(shooter)
	m.s.encounter_total = 3
	m.s.deployed = 3
	m.s.projectile_serial = 1
	m.s.projectiles = [{"uid": 1, "source": 2, "kind": "pressure", "name": "압력탄", "hp": 1, "max_hp": 1, "def": 0, "speed": 6, "distance": 14, "burn": 0}]
	m.assign_opening_lanes()
	var interception := fire_round(m)
	check(interception.get("intercept", false) and not interception.has("wreckage_hit"), "wreck shields enemies without absorbing a direct pressure projectile interception")
	m = TrialData.make().model
	m.s.enemies[0].hp = 1
	m.s.enemies[0].burn = 1
	var events: Array = m._advance(1)
	check(m.s.enemies[0].wreckage == 2 and events.any(func(event): return event.kind == "wreckage_spawn"), "burn death also leaves wreckage")
	var malformed: Dictionary = canonical(m.s)
	malformed.enemies[0].wreckage = 3
	check(not Model.new().restore_state(malformed), "malformed excess stacks are rejected")
	var second: Dictionary = m.s.enemies[0].duplicate(true)
	second.wreckage = -1
	var two_deaths: Array = [m.s.enemies[0].duplicate(true), second]
	check(Model.Wreckage.spawn(two_deaths).is_empty() and int(second.wreckage) == 0, "a second simultaneous pile cannot accumulate behind the first")
	m = TrialData.make("single", ["basic_p2", "arc", "basic_p2"]).model
	fire_round(m)
	stopped = fire_round(m)
	check(stopped.has("wreckage_hit") and not stopped.has("secondary"), "arc blocked by a wreck has no direct target to transfer from")
	m = TrialData.make("scatter").model
	m.s.enemies[0].hp = 0
	m.s.enemies[0].wreckage = 2
	var front: Dictionary = m.s.enemies[1].duplicate(true)
	front.distance = 10
	m.s.enemies.append(front)
	m.s.encounter_total = 3
	m.s.deployed = 3
	m.assign_opening_lanes()
	var prediction := Forecast.analyze(m.s)
	check(is_equal_approx(prediction.shots[0].wreckage_probability, 0.5), "scatter predicts 50% wreckage with one exposed and one covered target")
	check(prediction.shots[0].targets.map(func(candidate): return int(candidate.target)).has(0), "scatter names the actual impact rather than the covered enemy")
	check(fire_round(m).target in [0, 2], "actual scatter targets the wreckage or exposed enemy")
	print("WRECKAGE RULES COMPLETE checks=%d failures=%d" % [checks, failures.size()]); quit(0 if failures.is_empty() else 1)
