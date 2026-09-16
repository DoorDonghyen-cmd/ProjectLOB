extends SceneTree
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const Forecast = preload("res://redesign/forecast.gd")
const Readability = preload("res://redesign/readability.gd")
const RunInsight = preload("res://redesign/run_insight.gd")
var checks: Array = []
var failed := 0

func _initialize() -> void:
	_run()

func check(ok: bool, label: String, detail: Variant = null) -> void:
	checks.append({"pass": ok, "label": label, "detail": detail})
	if not ok:
		failed += 1
		printerr("READABILITY_QA_FAIL " + label + " " + JSON.stringify(detail))

func norm(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

func enemy(hp: int = 99, armor: int = 0, speed: int = 1, distance: int = 100, burn: int = 0, kind: String = "wall") -> Dictionary:
	return {"kind": kind, "name": Content.ENEMY_NAMES[kind], "hp": hp, "max_hp": hp, "def": armor, "speed": speed, "distance": distance, "burn": burn}

func armed(gun: String, rounds: Array, enemies: Array, part: String = "none"):
	var m = Model.new()
	m.start(gun, 7103)
	m.s.part = part
	m.s.enemies = enemies.duplicate(true)
	m.s.deck = []
	for id in rounds:
		if id != "basic": m.s.deck.append(id)
	m.s.hand = m.s.deck.duplicate()
	m.s.draw = []
	m.s.discard = []
	m.s.magazine = []
	m.s.plan = []
	m.s.buff = {}
	m.s.push_left = 2
	m.s.supply = m.supply_capacity()
	m.s.phase = "plan"
	for id in rounds: check(m.load_round(id), "fixture loads " + id)
	check(m.confirm(), "fixture confirms")
	return m

func collect_actual(m) -> Dictionary:
	var shots: Array = []
	var advance_events: Array = []
	var action := 0
	while m.s.phase == "ready" and not m.s.magazine.is_empty() and action < 10:
		check(m.fire(), "forecast fixture fires")
		var detail: Dictionary = m.s.history.back().detail
		for value in detail.results:
			var shot: Dictionary = value.duplicate(true)
			shot.action = action
			shots.append(shot)
		for value in detail.get("advance_events", []):
			var event: Dictionary = value.duplicate(true)
			event.action = action
			advance_events.append(event)
		action += 1
	return {"shots": shots, "advance_events": advance_events, "phase": m.s.phase, "remaining": m.s.magazine.duplicate(), "enemies": m.s.enemies.duplicate(true)}

func _run() -> void:
	var expected_ids := ["arc", "basic", "bore", "charge", "pierce", "precise", "push"]
	var actual_ids: Array = Content.AMMO.keys()
	actual_ids.sort()
	check(actual_ids == expected_ids, "exact seven-round roster", actual_ids)
	for id in actual_ids:
		var spec: Dictionary = Content.AMMO[id]
		check(spec.keys().has("dmg") and spec.keys().has("pen") and spec.keys().has("attribute") and spec.keys().has("effect"), id + " public schema")
		check(spec.attribute in ["physical", "fire", "electric"], id + " one known attribute")
		check(not spec.has("acc") and int(spec.dmg) >= 1 and int(spec.pen) >= 0, id + " only damage and penetration numbers")
		check(str(spec.effect) in ["", "push", "burn", "boost", "double", "arc"], id + " at most one known effect")
	for forbidden in ["mark", "slow", "finish"]: check(not Content.AMMO.has(forbidden), "removed round absent " + forbidden)
	for formation_set in Content.FORMATIONS:
		for formation in formation_set:
			for entry in formation: check(entry.size() == 5, "enemy formation has HP armor speed distance only", entry)

	# The same resolver formula is audited across every round, gun, armor, and penetration part.
	for gun in Content.GUNS:
		for part in ["none", "lens"]:
			for id in actual_ids:
				for armor in range(6):
					var m = armed(gun, [id], [enemy(999, armor)], part)
					check(m.fire(), "formula shot fires")
					var shot: Dictionary = m.s.history.back().detail.results[0]
					var expected_pen := int(Content.AMMO[id].pen) + (1 if part == "lens" else 0)
					var expected_raw := int(Content.AMMO[id].dmg) + int(Content.GUNS[gun].bonus)
					var expected_per_hit := maxi(1, expected_raw - maxi(0, armor - expected_pen))
					var expected_hits := 2 if id == "precise" else 1
					check(shot.pen == expected_pen and shot.math.raw == expected_raw and shot.math.armor == maxi(0, armor - expected_pen), "formula penetration " + gun + part + id + str(armor), shot)
					check(shot.math.per_hit == expected_per_hit and shot.hits == expected_hits and shot.damage == expected_per_hit * expected_hits, "formula damage " + gun + part + id + str(armor), shot)
					var explanation := Readability.explain(shot)
					check(explanation.contains("피해") and not explanation.contains("명중") and not explanation.contains("회피"), "explanation uses simplified axes " + id)

	# Amplify applies to two following rounds and multiplies through the double-hit round.
	for gun in Content.GUNS:
		var m = armed(gun, ["charge", "precise", "basic"], [enemy()])
		var combo_forecast: Dictionary = Forecast.analyze(m.s)
		var actual := collect_actual(m)
		var shots: Array = actual.shots
		check(shots.size() == 3 and shots[1].hits == 2 and shots[1].math.boost == 2 and shots[2].math.boost == 2, gun + " amplify covers next two rounds", shots)
		check(not m.s.buff.has("dmg"), gun + " amplify expires after two rounds")
		check(Forecast.is_combo_link(combo_forecast, 1) and Forecast.is_combo_link(combo_forecast, 2), gun + " forecast links both amplified rounds")
		check(Forecast.note(combo_forecast, 1) == "증폭 · 2타" and Forecast.note(combo_forecast, 2) == "증폭 적용", gun + " forecast names amplified results")
	var burst_combo = armed("single", ["charge", "precise"], [enemy(10)])
	collect_actual(burst_combo)
	var burst_wrong = armed("single", ["precise", "charge"], [enemy(10)])
	collect_actual(burst_wrong)
	check(burst_combo.s.phase == "reward" and burst_wrong.s.enemies[0].hp == 2, "amplify then double-hit converts a two-hp miss into a kill")
	var armor_combo = armed("single", ["charge", "pierce"], [enemy(7, 3)])
	collect_actual(armor_combo)
	var armor_wrong = armed("single", ["pierce", "charge"], [enemy(7, 3)])
	collect_actual(armor_wrong)
	check(armor_combo.s.phase == "reward" and armor_wrong.s.enemies[0].hp == 2, "amplify then armor-piercing converts a two-hp miss into a kill")

	# Burn applies after the shot, ticks before movement, and a burn kill prevents movement.
	var burn_kill = armed("burst", ["bore"], [enemy(3, 0, 2, 5)])
	check(burn_kill.fire(), "burn kill fires")
	var burn_detail: Dictionary = burn_kill.s.history.back().detail
	check(burn_detail.results[0].damage == 2 and burn_detail.results[0].burn == 3, "incendiary applies burn after direct damage", burn_detail)
	check(burn_detail.advance_events[0].kind == "burn" and burn_detail.advance_events[0].damage == 1, "burn ticks before movement", burn_detail.advance_events)
	check(burn_kill.s.enemies[0].hp == 0 and burn_kill.s.enemies[0].distance == 5 and burn_kill.s.phase == "reward", "burn kill blocks movement and wins", burn_kill.s)
	var stacked = armed("burst", ["bore"], [enemy(99, 0, 1, 20, 5)], "coil")
	stacked.fire()
	check(stacked.s.history.back().detail.results[0].burn == 6 and stacked.s.enemies[0].burn == 5, "burn caps six then consumes one with thermal coil")
	var reload_burn = armed("burst", ["basic"], [enemy(4, 0, 1, 9, 3)])
	reload_burn.s.magazine = ["basic"]
	check(reload_burn.reload_magazine(), "burn reload advances")
	check(reload_burn.s.enemies[0].hp == 1 and reload_burn.s.enemies[0].burn == 0 and reload_burn.s.enemies[0].distance == 6, "three-turn reload resolves three burn ticks before moves", reload_burn.s)
	var burn_forecast_model = armed("single", ["bore", "push", "basic"], [enemy(40, 0, 2, 20)])
	var burn_forecast: Dictionary = Forecast.analyze(burn_forecast_model.s)
	check(Forecast.burn_ticks_for_shot(burn_forecast, 0) == 3 and Forecast.note(burn_forecast, 0) == "화상 3회 예상", "forecast counts actual future burn events", burn_forecast)
	check(Forecast.note(burn_forecast, 1) == "거리 +2m", "forecast names push distance", burn_forecast)
	check(Forecast.summary(burn_forecast).contains("A HP") and Forecast.summary(burn_forecast).contains("안전"), "forecast summarizes final hp and distance", Forecast.summary(burn_forecast))
	var fire_push = armed("single", ["bore", "push", "basic"], [enemy(8, 2, 3, 6)])
	collect_actual(fire_push)
	var fire_wrong = armed("single", ["bore", "basic", "basic"], [enemy(8, 2, 3, 6)])
	collect_actual(fire_wrong)
	check(fire_push.s.phase == "reward" and fire_wrong.s.phase == "lost" and fire_wrong.s.enemies[0].hp == 1, "incendiary then impact buys the burn turn needed to finish")

	# Electricity hits only the nearest other living enemy for fixed two damage.
	var electric = armed("burst", ["arc"], [enemy(20, 0, 1, 10), enemy(2, 0, 1, 11, 0, "runner"), enemy(20, 0, 1, 12, 0, "evader")])
	electric.fire()
	var electric_shot: Dictionary = electric.s.history.back().detail.results[0]
	check(electric_shot.secondary.size() == 1 and electric_shot.secondary[0].target == 1 and electric_shot.secondary[0].damage == 2, "electric chains fixed damage to nearest other enemy", electric_shot)
	check(electric.s.enemies[2].hp == 20, "electric never chains twice")
	var electric_solo = armed("burst", ["arc"], [enemy()])
	electric_solo.fire()
	check(electric_solo.s.history.back().detail.results[0].secondary.is_empty(), "electric safely has no solo target")
	var amplified_arc = armed("single", ["charge", "arc"], [enemy(20, 0, 1, 20), enemy(6, 0, 1, 22, 0, "runner")])
	var arc_forecast: Dictionary = Forecast.analyze(amplified_arc.s)
	check(Forecast.note(arc_forecast, 1) == "증폭 · B 전이 −2", "forecast exposes boosted electric combination", arc_forecast)
	check(Forecast.outcome(arc_forecast.shots[1]).contains("HP"), "forecast outcome exposes remaining hp", arc_forecast.shots[1])
	var electric_combo = armed("single", ["charge", "arc"], [enemy(8), enemy(2, 0, 1, 102, 0, "runner")])
	collect_actual(electric_combo)
	var electric_wrong = armed("single", ["arc", "charge"], [enemy(8), enemy(2, 0, 1, 102, 0, "runner")])
	collect_actual(electric_wrong)
	check(electric_combo.s.phase == "reward" and electric_wrong.s.enemies[0].hp == 2, "amplify then electric converts a two-hp miss into a two-target clear")

	# Knockback budget remains two meters for the complete magazine.
	var push = armed("burst", ["push", "push"], [enemy()])
	push.fire()
	var push_results: Array = push.s.history.back().detail.results
	check(push_results[0].push == 2 and push_results[1].push == 0 and push.s.push_left == 0, "knockback magazine cap two")
	check(Content.AMMO.push.dmg == 3, "impact round trades only one base damage for distance")
	var push_lesson: Array = Content.enemies_for(4, 731042, true, "single")
	var arc_lesson: Array = Content.enemies_for(5, 731042, true, "single")
	check(push_lesson[0].distance == 6 and push_lesson[0].speed == 3 and push_lesson[0].def == 2, "impact lesson starts at one-shot safety margin")
	check(arc_lesson.size() == 3 and arc_lesson[1].hp == 2, "electric lesson exposes a fixed-two chain target")

	# Forecast and actual execution agree across seeds, guns, floors, and generated hands.
	for seed_value in range(1, 81):
		for gun in Content.GUNS:
			for floor_index in range(7):
				var m = Model.new()
				m.start(gun, seed_value)
				m.s.floor = floor_index
				m.begin_encounter()
				var rounds: Array = m.s.hand.slice(0, mini(m.capacity() - 1, m.s.hand.size()))
				rounds.append("basic")
				for id in rounds: check(m.load_round(id), "generated forecast load")
				var before: Dictionary = m.s.duplicate(true)
				var predicted: Dictionary = Forecast.analyze(m.s)
				check(m.s == before and Forecast.analyze(m.s) == predicted, "forecast pure %d %s %d" % [seed_value, gun, floor_index])
				var clone = Model.new()
				clone.s = before.duplicate(true)
				clone.confirm()
				var actual := collect_actual(clone)
				check(norm(predicted.shots) == norm(actual.shots) and norm(predicted.advance_events) == norm(actual.advance_events), "forecast events agree %d %s %d" % [seed_value, gun, floor_index])
				check(predicted.phase == actual.phase and predicted.remaining == actual.remaining and norm(predicted.enemies) == norm(actual.enemies), "forecast state agrees %d %s %d" % [seed_value, gun, floor_index])

	# Staged course reveals armor only when taught and grants each new round exactly once.
	for gun in Content.GUNS:
		var course = Model.new()
		course.start(gun, 42, true)
		var expected: Array = ["charge", "charge"]
		for stage in range(7):
			check(course.s.floor == stage and course.s.deck == expected, gun + " course exact grants stage" + str(stage), course.s.deck)
			check(Content.axes(course.s).armor == (stage >= 1), gun + " course armor visibility stage" + str(stage))
			for id in Content.COURSE_GRANTS[stage]: check(course.s.hand.has(id), gun + " taught round in first hand " + id)
			if stage == 6: break
			course.s.phase = "reward"
			course.s.reward_taken = false
			expected.append_array(Content.COURSE_GRANTS[stage + 1])
			check(course.choose_reward("skip"), gun + " course skip advances stage" + str(stage))

	# Debrief and reward guidance use only public state, stay pure, and state exact impacts.
	var insight_fixture = armed("single", ["charge", "precise"], [enemy(9, 1)])
	collect_actual(insight_fixture)
	var insight_before = norm(insight_fixture.s)
	var insight_report: Dictionary = RunInsight.combat_report(insight_fixture.s, 0)
	check(insight_report.direct == 9 and insight_report.boost_hits == 2 and insight_report.kills == 1, "combat report totals actual amplified hits", insight_report)
	check(RunInsight.combat_report_line(insight_fixture.s, 0).contains("직접 9") and RunInsight.combat_report_line(insight_fixture.s, 0).contains("증폭 타격 2"), "combat report exposes concise combo result")
	var threats := [enemy(12, 3, 2, 13), enemy(7, 0, 4, 9, 0, "runner")]
	var threat: Dictionary = RunInsight.threat_data(threats)
	check(threat.count == 2 and threat.max_armor == 3 and threat.max_speed == 4 and threat.contact_turns == 3, "next encounter threat summary is exact", threat)
	check(RunInsight.threat_line(threats) == "위협 · 2개체 · 장갑 최대 3 · 접촉 최소 3턴", "threat line stays compact")
	check(RunInsight.reward_impact("pierce", insight_fixture.s, threats).contains("장갑 최대 3"), "piercing reward names next armor")
	check(RunInsight.reward_impact("precise", insight_fixture.s, threats).contains("추가 피해 +4"), "double-hit reward names boost synergy")
	check(RunInsight.reward_impact("supply", insight_fixture.s, threats).contains("4→5칸"), "supply reward names capacity change")
	check(RunInsight.deck_summary(["bore", "bore", "arc"]) == "소이탄 ×2 · 전격탄 ×1", "deck summary collapses duplicates")
	check(norm(insight_fixture.s) == insight_before, "insight helpers never mutate run state")

	# Version 2 saves migrate without losing ownership; removed rounds map to new roles.
	var source = Model.new()
	source.start("single", 9898)
	var old: Dictionary = source.s.duplicate(true)
	old.version = 2
	var reverse := {"charge": "mark", "push": "slow", "pierce": "finish"}
	for key in ["deck", "hand", "draw", "discard", "magazine", "plan"]:
		for i in range(old[key].size()):
			if reverse.has(str(old[key][i])): old[key][i] = reverse[str(old[key][i])]
	old.buff = {"acc": 4, "acc_left": 2}
	for old_enemy in old.enemies:
		old_enemy.eva = 7
		old_enemy.slow = 1
		old_enemy.crack = 2
		old_enemy.erase("burn")
	var migration_path := "user://elemental_v2_save.json"
	var migration_file := FileAccess.open(migration_path, FileAccess.WRITE)
	migration_file.store_string(JSON.stringify(old))
	migration_file.close()
	var migrated = Model.new()
	migrated.start("burst", 1)
	check(migrated.restore_run(migration_path), "v2 save migrates")
	check(migrated.s.version == 3 and migrated.s.buff.is_empty(), "v2 buffs collapse to v3")
	for key in ["deck", "hand", "draw", "discard", "magazine", "plan"]:
		for id in migrated.s[key]: check(Content.AMMO.has(id), "migrated inventory uses live ammo " + key)
	for migrated_enemy in migrated.s.enemies:
		check(migrated_enemy.has("burn") and not migrated_enemy.has("eva") and not migrated_enemy.has("slow") and not migrated_enemy.has("crack"), "migrated enemy uses simplified state")

	var invalid: Dictionary = migrated.s.duplicate(true)
	invalid.enemies[0].burn = 7
	var invalid_file := FileAccess.open("user://elemental_invalid.json", FileAccess.WRITE)
	invalid_file.store_string(JSON.stringify(invalid))
	invalid_file.close()
	var atomic = Model.new()
	atomic.start("single", 5)
	var atomic_before: Dictionary = atomic.s.duplicate(true)
	check(not atomic.restore_run("user://elemental_invalid.json") and atomic.s == atomic_before, "invalid v3 save rejected atomically")

	var report := {"checks": checks.size(), "failed": failed, "attributes": ["physical", "fire", "electric"], "ammo": actual_ids}
	var file := FileAccess.open("user://readability_rules.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("READABILITY_RULES: %d checks / %d failed" % [checks.size(), failed])
	quit(1 if failed > 0 else 0)
