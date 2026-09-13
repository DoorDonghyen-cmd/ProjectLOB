extends SceneTree
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const Forecast = preload("res://redesign/forecast.gd")
const Readability = preload("res://redesign/readability.gd")
var checks: Array = []
var evidence: Array = []

func _initialize() -> void:
	_run()

func check(ok: bool, label: String, detail: Variant = null) -> void:
	checks.append({"pass": ok, "label": label, "detail": detail})
	if not ok: printerr("READABILITY_QA_FAIL " + label + " " + JSON.stringify(detail))

func norm(value: Variant) -> Variant:
	return JSON.parse_string(JSON.stringify(value))

func strip_presentation(value: Variant) -> Variant:
	if value is Dictionary:
		var copy: Dictionary = value.duplicate(true)
		for key in ["course", "math", "combo", "text", "message"]: copy.erase(key)
		for key in copy: copy[key] = strip_presentation(copy[key])
		return copy
	if value is Array:
		var copy: Array = []
		for item in value: copy.append(strip_presentation(item))
		return copy
	return value

func inventory(m, label: String) -> void:
	var owned: Array = m.s.hand + m.s.draw + m.s.discard
	for id in m.s.magazine:
		if id != "basic": owned.append(id)
	var expected: Array = m.s.deck.duplicate()
	owned.sort()
	expected.sort()
	check(owned == expected and m.s.hand.size() <= 5 and m.s.deck.size() <= 14, label + " ownership and bounds")
	for id in m.s.plan: check(m.available(id) >= 0, label + " reserved owned")

func restore_state(state: Dictionary, label: String, accept: bool = true):
	var file := FileAccess.open("user://readability_state.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(state))
	file.close()
	var restored = Model.new()
	restored.start("single", 998)
	var before: Dictionary = restored.s.duplicate(true)
	var ok: bool = restored.restore_run("user://readability_state.json")
	check(ok == accept and (ok or restored.s == before), label + " restore acceptance atomic")
	if ok:
		var expected: Dictionary = state.duplicate(true)
		if not expected.has("course"): expected.course = false
		check(restored.s == norm(expected), label + " restore full state exact")
	return restored

func audit_forecast(m, label: String) -> void:
	var before: Dictionary = m.s.duplicate(true)
	var predicted: Dictionary = Forecast.analyze(m.s)
	check(m.s == before and Forecast.analyze(m.s) == predicted, label + " forecast state RNG purity")
	var actual = Model.new()
	actual.s = before.duplicate(true)
	if actual.s.phase == "plan": actual.confirm()
	var all_shots: Array = []
	var actions := 0
	while actual.s.phase == "ready" and not actual.s.magazine.is_empty() and actions < 8:
		actual.fire()
		for shot_value in actual.s.history.back().detail.results:
			var shot: Dictionary = shot_value.duplicate(true)
			shot.action = actions
			all_shots.append(shot)
			var trace: Dictionary = shot.math
			check(trace.raw == trace.base + trace.boost + trace.special, label + " trace additive raw")
			check(trace.armor == maxi(0, trace.armor_before - trace.crack_before - shot.pen) and trace.evasion == maxi(0, trace.evasion_before - shot.acc), label + " trace reductions use prehit stats")
			check(trace.per_hit == maxi(1, trace.raw - trace.armor - trace.evasion) and trace.hits == shot.hits, label + " trace perhit and multiplicity")
			check(shot.damage == mini(trace.hp_before, trace.per_hit * trace.hits) and shot.hp == trace.hp_before - shot.damage, label + " trace HP cap and result")
			check(trace.base == Content.AMMO[shot.id].dmg + Content.GUNS[actual.s.gun].bonus, label + " trace base includes gun bonus")
			var explanation: String = Readability.explain(shot)
			check(explanation.begins_with("%s · %d피해  HP %d → %d" % [Forecast.tag(shot.target), shot.damage, trace.hp_before, shot.hp]) and explanation.contains("위력 %d" % trace.base) and explanation.contains(" = %d" % trace.per_hit), label + " formatter actual HP and perhit trace")
			check(explanation.contains("최소 1") == (trace.raw - trace.armor - trace.evasion < 1) and explanation.contains("남은 HP까지만 피해") == (trace.per_hit * trace.hits > trace.hp_before), label + " formatter minimum and overkill reasons")
			if trace.hits > 1: check(explanation.contains("%d회" % trace.hits), label + " formatter double hit distinct from perhit")
			if trace.boost > 0: check(explanation.contains("강화 %d" % trace.boost), label + " formatter boost")
			if trace.special > 0: check(explanation.contains("%s %d" % ["파쇄" if shot.id == "pierce" else "마무리", trace.special]), label + " formatter special")
			for other in shot.secondary: check(explanation.contains("%s 도약 %d피해 (고정)" % [Forecast.tag(other.target), other.damage]), label + " formatter secondary actual damage")
		actions += 1
	check(norm(predicted.shots) == norm(all_shots) and norm(predicted.enemies) == norm(actual.s.enemies) and predicted.remaining == actual.s.magazine and predicted.phase == actual.s.phase and predicted.turns == actual.s.turns - before.turns, label + " trace forecast actual full agreement")
	if not predicted.shots.is_empty():
		var first: Dictionary = predicted.shots[0].duplicate(true)
		first.erase("action")
		check(m.preview() == first, label + " immediate first shot trace agrees")

func execute(m, rounds: Array) -> void:
	for id in rounds: check(m.load_round(id), "actual lesson legal load " + id)
	check(m.confirm(), "actual lesson confirm")
	while m.s.phase == "ready" and not m.s.magazine.is_empty(): m.fire()

func _run() -> void:
	# Old independent v2 evidence provides pre-change numerical regression cases.
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../docs/qa/reports/chain_combat_2026-09-13.json"))
	for entry in baseline.evidence:
		var m = Model.new()
		m.s = entry.before.duplicate(true)
		m.s.course = false
		var current: Dictionary = Forecast.analyze(m.s)
		check(norm(strip_presentation(current)) == norm(strip_presentation(entry.forecast)), "normal v2 numerical baseline " + entry.id)
		audit_forecast(m, entry.id)
		evidence.append({"kind": "trace", "id": entry.id, "forecast": current})
	# Genuine first two lesson wins: reproduce the minimum-deck removal contract.
	for seed_value in [1, 2]:
		for gun in ["single", "burst"]:
			var m = Model.new()
			m.start(gun, seed_value, true)
			execute(m, ["charge", "basic", "basic"] if gun == "single" else ["charge", "basic", "basic", "basic"])
			check(m.s.phase == "reward" and m.s.deck.size() == 2, "actual first lesson victory")
			var minimum_before: Dictionary = m.s.duplicate(true)
			check(not m.choose_reward("remove", "charge") and m.s == minimum_before, "course minimum2 rejects removal atomically")
			check(m.choose_reward("skip") and m.s.deck == ["charge", "charge", "bore", "pierce"], "actual first automatic grants exactly once")
			execute(m, ["bore", "charge", "basic", "pierce"])
			check(m.s.phase == "reward", "actual second lesson victory")
			var before: Dictionary = m.s.duplicate(true)
			var removed: bool = m.choose_reward("remove", "charge")
			check(removed and m.s.floor == 2 and m.s.deck.count("charge") == 1 and m.s.deck.count("precise") == 1, "course minimum2 permits removing from deck4", {"seed": seed_value, "gun": gun, "minimum": m.minimum_deck(), "actual_return": removed, "before_size": before.deck.size(), "after_size": m.s.deck.size()})
			evidence.append({"kind": "course_remove_repro", "seed": seed_value, "gun": gun, "before": before, "return": removed, "after": m.s.duplicate(true)})
	# Finite lifecycle fixtures: reward phase is explicitly set to isolate transitions.
	for seed_value in [1, 2, 3, 42, 731042, 9007199254740993]:
		for gun in ["single", "burst"]:
			for policy in ["skip", "take"]:
				var m = Model.new()
				m.start(gun, seed_value, true)
				var expected_deck: Array = ["charge", "charge"]
				for stage in range(7):
					var label := "course %d %s %s stage%d" % [seed_value, gun, policy, stage]
					check(m.s.floor == stage and m.s.course and m.s.deck == expected_deck, label + " stage grants exact no duplicates")
					check(m.minimum_deck() == 2 and m.s.deck.size() <= m.deck_limit(), label + " minimum and future grant reservation")
					for id in Content.COURSE_GRANTS[stage]: check(m.s.hand.has(id), label + " novel round in first hand " + id)
					var axes: Dictionary = Content.axes(m.s)
					check(axes.armor == (stage >= 1) and axes.accuracy == (stage >= 3), label + " stage axis visibility contract")
					for enemy in m.s.enemies:
						check((axes.armor or enemy.def == 0) and (axes.accuracy or enemy.eva == 0), label + " unintroduced axes truly zero")
						var shown_enemy: String = Readability.enemy_stats(enemy, m.s)
						check(shown_enemy.contains("장갑") == axes.armor and shown_enemy.contains("회피") == axes.accuracy and shown_enemy.contains("접근"), label + " enemy formatter stage axes")
					for id in m.s.hand:
						var shown_stats: String = Readability.stats(id, m.s)
						check(shown_stats.contains("관통") == axes.armor and shown_stats.contains("명중") == axes.accuracy, label + " ammo formatter stage axes")
						check(Readability.stats(id, m.s, true).contains("관통") and Readability.stats(id, m.s, true).contains("명중"), label + " full detail reveals complete stats")
					inventory(m, label)
					var restored = restore_state(m.s, label)
					check(norm(Forecast.analyze(restored.s)) == norm(Forecast.analyze(m.s)), label + " resumed forecast stable")
					var repeat = Model.new()
					repeat.s = m.s.duplicate(true)
					repeat.begin_encounter()
					check(repeat.s.deck == m.s.deck and repeat.s.hand == m.s.hand and repeat.s.draw == m.s.draw and repeat.s.rng_state == m.s.rng_state, label + " reinitialize preserves deck and seeded hand")
					var pool: Array = Content.course_pool(stage)
					if stage != 4:
						for id in m.reward_options(): check(pool.has(id), label + " reward cannot reveal future ammo")
					# Exchange both live and restored state and compare full continuation.
					var pre_exchange: Dictionary = m.s.duplicate(true)
					var exchanged: bool = m.exchange(m.s.hand[0])
					var resumed_exchange: bool = restored.exchange(restored.s.hand[0])
					check(exchanged == resumed_exchange and norm(m.s) == norm(restored.s), label + " exchange after resume same RNG and ownership")
					if not exchanged: check(m.s == pre_exchange, label + " unavailable exchange is atomic")
					inventory(m, label + " after exchange")
					if stage == 6: break
					m.s.phase = "reward"
					m.s.reward_taken = false
					var choice := "skip"
					if policy == "take" and not m.reward_options().is_empty():
						var candidate: String = m.reward_options()[0]
						if Content.PARTS.has(candidate) or m.s.deck.size() < m.deck_limit(): choice = candidate
					if Content.AMMO.has(choice): expected_deck.append(choice)
					expected_deck.append_array(Content.COURSE_GRANTS[stage + 1])
					check(m.choose_reward(choice), label + " accepted reward advances")
					var after_reward: Dictionary = m.s.duplicate(true)
					check(not m.choose_reward(choice) and m.s == after_reward, label + " repeat reward cannot duplicate grants")
	# Exact cap reserve: max accepted deck size now still permits all future grants.
	for stage in range(6):
		var m = Model.new()
		m.start("burst", 42, true)
		m.s.floor = stage
		m.s.deck = []
		for i in range(m.deck_limit()): m.s.deck.append("charge")
		m.begin_encounter()
		m.s.phase = "reward"
		var cap_before: Dictionary = m.s.duplicate(true)
		for id in m.reward_options():
			if Content.AMMO.has(id): check(not m.choose_reward(id) and m.s == cap_before, "at reserved cap reject optional ammo stage%d" % stage)
		check(m.choose_reward("skip") and m.s.deck.size() <= m.deck_limit() and m.s.deck.size() <= 14, "at reserved cap mandatory grants fit stage%d" % stage)
	# Legacy normal v2 save lacks course. Course type and new min save contracts.
	var normal = Model.new()
	normal.start("burst", 4242)
	check(not normal.s.course and normal.minimum_deck() == 6 and normal.deck_limit() == 14 and normal.s.deck == Content.START_DECK, "default start remains normal v2")
	var old: Dictionary = normal.s.duplicate(true)
	old.erase("course")
	var compat = restore_state(old, "legacy v2 missing course")
	check(not compat.s.course, "legacy v2 becomes normal")
	for bad_value in ["true", 1, 0, null, [], {}]:
		var bad: Dictionary = normal.s.duplicate(true)
		bad.course = bad_value
		restore_state(bad, "invalid course type " + str(bad_value), false)
	var course = Model.new()
	course.start("single", 4242, true)
	restore_state(course.s, "course2 deck valid")
	var bad_course: Dictionary = course.s.duplicate(true)
	bad_course.course = false
	restore_state(bad_course, "normal2 deck invalid", false)
	# Existing normal formations/rewards are untouched by default parameter.
	for stage in range(7):
		for seed_value in [1, 731042]:
			check(Content.enemies_for(stage, seed_value) == Content.enemies_for(stage, seed_value, false, "burst"), "normal formation explicit/default identical")
			for gun in ["single", "burst"]:
				check(Content.rewards_for(stage, seed_value, gun) == Content.rewards_for(stage, seed_value, gun, false), "normal rewards explicit/default identical")
	check(Content.AMMO.charge.name == "강화탄" and Content.AMMO.mark.name == "조준탄" and Content.AMMO.finish.name == "마무리탄", "three renamed ammo labels")
	check(Readability.explain({}) == "탄환을 넣으면 실제 피해와 계산 근거를 보여 줍니다." and Readability.explain({"text": "legacy shot"}) == "legacy shot", "formatter handles empty and legacy trace")
	normal.s.part = "lens"
	check(Readability.stats("precise", normal.s) == "위력 2×2  관통 0  명중 11", "formatter burst double and permanent lens")
	normal.s.gun = "single"
	check(Readability.stats("precise", normal.s) == "위력 3×2  관통 0  명중 11", "formatter single bonus applies per hit")
	check(Readability.enemy_stats({"def": 2, "crack": 3, "eva": 9, "speed": 1, "slow": 2}, normal.s) == "장갑0  회피9  접근0m", "enemy formatter clamped effective armor and approach")
	var failed := 0
	for row in checks:
		if not row.pass: failed += 1
	var file := FileAccess.open("user://readability_combat_independent.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": checks.size() - failed, "failed": failed, "checks": checks, "evidence": evidence}, "\t"))
	file.close()
	print("READABILITY_COMBAT_INDEPENDENT %d passed / %d failed" % [checks.size() - failed, failed])
	quit(1 if failed else 0)
