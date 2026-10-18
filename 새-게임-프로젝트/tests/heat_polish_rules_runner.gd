extends "res://tests/heat_rules_runner.gd"
const Insight = preload("res://redesign/run_insight.gd")
const Feedback = preload("res://redesign/part_feedback.gd")
const Guide = preload("res://redesign/build_guide.gd")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/heat_polish/"):
		quit(1)
		return
	var model = fixture(["charge_hot", "thermal", "vent", "cool"])
	model.s.equipped_parts = ["ember_core"]
	fire(model, ["charge_hot", "thermal", "vent"])
	var report := Insight.combat_report(model.s)
	check(report.heat_peak == 9 and report.cooled == 4 and report.vented == 4 and report.heat_used_shots == 2, "actual heat use and cooling, unique shots with multiple bonuses")
	check(report.forced_reloads == 0 and report.overheats == 0, "no invented penalty for a cooled chain")
	var saved := JSON.stringify(model.s)
	check(Insight.combat_report(JSON.parse_string(saved)) == report, "heat report survives serialized history")
	Insight.loss_advice(model.s)
	Insight.reward_impact("radiator", model.s, [])
	check(JSON.stringify(model.s) == saved, "all insights leave live state unchanged")
	model = fixture(["bore", "charge_hot", "precise", "pierce"], [["wall", 200, 4, 1, 30]])
	fire(model, ["bore", "charge_hot", "precise", "pierce"])
	report = Insight.combat_report(model.s)
	check(report.forced_reloads == 1 and report.overheats == 1, "nested and standalone reload counted once")
	check(report.burn == mini(3, Ammo.burn_amount("bore", model.s)) * Ammo.burn_damage(model.s), "forced reload burn counted once")
	check(report.heat_peak == 14 and report.cooled == 0, "reload reset is not credited to cooling builds")
	model = fixture(["pierce"], [["runner", 1, 0, 1, 10]])
	model.s.heat = 9
	fire(model, ["pierce"])
	report = Insight.combat_report(model.s)
	check(report.overheats == 1 and report.forced_reloads == 0, "terminal hot kill has no forced reload")
	model = fixture(["pierce"], [["runner", 1, 0, 1, 10], ["wall", 80, 4, 1, 30]])
	model.s.equipped_parts = ["reclaimer"]
	fire(model, ["pierce"])
	report = Insight.combat_report(model.s)
	check(report.cooled == 2 and report.kill_cooled == 2 and report.heat_peak == 1, "peak recorded after actual kill cooling")
	model = fixture(["thermal", "vent"], [["absorber", 80, 0, 1, 30]])
	model.s.heat = 6
	model.s.enemies[0].barrier = 8
	model.s.enemies[0].barrier_max = 8
	fire(model, ["thermal", "vent"])
	report = Insight.combat_report(model.s)
	check(report.heat_used_shots == 0 and report.vented == 4, "blocked hits consume heat but do not claim damage bonus application")
	# Real terminal actions, not hand-authored loss text.
	model = fixture(["charge_hot", "precise", "pierce", "cool"], [["wall", 40, 4, 2, 6]])
	fire(model, ["charge_hot", "precise", "pierce", "cool"])
	var advice := Insight.loss_advice(model.s)
	check(model.s.phase == "lost" and advice.contains("과열 후 강제 재장전 중") and advice.contains("기본 1턴 + 냉각 1턴"), "forced reload loss explains actual cost and cause")
	model = fixture(["basic"], [["wall", 80, 4, 2, 4]])
	model.s.deck.erase("basic")
	model.s.deck.append("pierce")
	model.s.hand.erase("basic")
	model.s.draw = model.s.deck.duplicate()
	fire(model, ["basic"])
	check(model.reload_magazine() and model.s.phase == "lost", "manual reload death fixture")
	advice = Insight.loss_advice(model.s)
	check(advice.begins_with("재장전 중") and not advice.contains("과열"), "ordinary reload never blamed on overheat")
	# Reload into actual ranged advancement: a surviving source is not contact.
	model = fixture(["pierce"], [["spitter", 80, 0, 0, 6]])
	fire(model, ["basic"])
	check(model.reload_magazine(), "launch pressure")
	check(model.load_round("basic") and model.confirm() and model.reload_magazine(), "reload into real projectile arrival")
	advice = Insight.loss_advice(model.s)
	check(model.s.loss_reason == "projectile" and advice.contains("압력탄이 도달") and not advice.contains("6m에서 접촉"), "projectile death correctly attributed with living distant source")
	# A new encounter report cannot inherit a previous fight's thermal penalty.
	model.begin_encounter()
	check(Insight.combat_report(Feedback.encounter_state(model.s)).forced_reloads == 0, "encounter report boundary")
	for gun in Ammo.GUNS:
		var state := {"gun": gun, "deck": ["thermal", "bore"], "equipped_parts": ["inferno", "afterburner"], "capacity_bonus": 2}
		for id in Ammo.PARTS:
			if id == "none": continue
			check(Insight.reward_impact(id, state, []) != "현재 구성에 적용", "all part IDs have concrete guidance " + id)
		check(Insight.reward_impact("supply", state, []).contains("%d→%d칸" % [Ammo.capacity(state), Ammo.capacity(state) + 1]), "capacity preview includes purchased expansion " + gun)
		check(Insight.reward_impact("coil", state, []).contains("화상 %d→%d턴" % [Ammo.burn_amount("bore", state), mini(6, Ammo.burn_amount("bore", state) + 1)]), "coil correctly describes duration with inferno " + gun)
		state.equipped_parts = ["radiator", "ember_core"]
		var before := JSON.stringify(state)
		check(Insight.reward_impact("radiator", state, []).contains("열 한계 %d→%d" % [Ammo.heat_limit(state) - 3, Ammo.heat_limit(state)]), "equipped radiator not added twice " + gun)
		check(Guide.connection("radiator", state).contains("높아짐") and Guide.connection("reclaimer", state).contains("고열 조건"), "cooling tradeoff visible " + gun)
		check(before == JSON.stringify(state), "equipped preview pure " + gun)
	check(Insight.combat_report({"history": []}).heat_peak == 0, "legacy empty history")
	check(not Insight.loss_advice({"enemies": [{"hp": 1, "distance": 9, "name": "테스트"}]}).contains("도달"), "missing terminal evidence does not invent contact")
	print("HEAT POLISH RULES COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
