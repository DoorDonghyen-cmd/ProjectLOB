extends SceneTree
## 11-11 part fixes (part_tuning.gd): forced cooling ignores part changes to the swap cost,
## 잔열 노심 heat limit −1, 연타 공명기 no heat, 냉각 약실 bonus after a manual cool,
## 야전 압축기 not offered; older saves keep the old rules.
const Campaign = preload("res://redesign/campaign.gd")
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const Data = preload("res://redesign/campaign_content.gd")
const Tuning = preload("res://redesign/part_tuning.gd")
var checks := 0
var failures: Array = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label); print("FAIL: " + label)
	return ok

func first_combat(gun: String, parts: Array, tuned := true):
	var c = Campaign.new()
	c.start(gun, 731042, 0, "balanced", Campaign.Content.RouteMap.VERSION, "carrier", true)
	while c.departure_pending(): c.advance_departure(true)
	c.enter(int(c.choices()[0].id))
	if not tuned: c.model.s.erase("overheat_version")
	for id in parts:
		if not c.s.parts.has(id): c.s.parts.append(id)
	c.s.equipped_parts = parts.duplicate()
	c._sync_equipped_parts()
	return c

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	# Forced cooling vs swap cost.
	# 후미 점화기 lost its swap penalty in step 3 (checked below); 열폭주 노심 keeps it.
	for entry in [["heavy", "inferno", 1]]:
		var plain = first_combat(entry[0], [])
		var with_part = first_combat(entry[0], [entry[1]])
		check(with_part.model.reload_cost() == plain.model.reload_cost() + int(entry[2]), "%s still lengthens the swap by %+d" % [entry[1], entry[2]])
		check(with_part.model.forced_cooling_cost() == plain.model.forced_cooling_cost(), "%s does not lengthen forced cooling (%d)" % [entry[1], plain.model.forced_cooling_cost()])
	var loader_plain = first_combat("heavy", [])
	var loader_on = first_combat("heavy", ["loader"])
	check(loader_on.model.forced_cooling_cost() == loader_plain.model.forced_cooling_cost() - 1, "회수 가속기 still shortens forced cooling by 1")
	for entry in [["burst", "afterburner", 1], ["heavy", "inferno", 1], ["burst", "loader", -1]]:
		var old_plain = first_combat(entry[0], [], false)
		var old_part = first_combat(entry[0], [entry[1]], false)
		check(old_part.model.forced_cooling_cost() == old_plain.model.forced_cooling_cost() + int(entry[2]), "older saves: %s changes forced cooling as before" % entry[1])
	# 잔열 노심 and 연타 공명기.
	var base_limit: int = Content.heat_limit(first_combat("burst", []).model.s)
	check(Content.heat_limit(first_combat("burst", ["ember_core"]).model.s) == base_limit - 1, "잔열 노심 heat limit −1")
	check(Content.heat_limit(first_combat("burst", ["ember_core"], false).model.s) == base_limit - 2, "older saves: 잔열 노심 −2")
	var plain_heat := Content.heat_delta("precise_p2", first_combat("burst", []).model.s)
	check(Content.heat_delta("precise_p2", first_combat("burst", ["resonator"]).model.s) == plain_heat, "연타 공명기 adds no heat")
	check(Content.heat_delta("precise_p2", first_combat("burst", ["resonator"], false).model.s) == plain_heat + 1, "older saves: 연타 공명기 +1 heat")
	# 냉각 약실: the first attack round after a manual cool.
	for cooled in [true, false]:
		var c = first_combat("single", ["cooling_breech"])
		var m = c.model
		for e in m.s.enemies: e.hp = 999; e.max_hp = 999
		m.s.heat = 3
		if cooled: check(m.cool_magazine(), "manual cool")
		var attack_index: int = m.s.magazine.find(m.s.magazine.filter(func(id): return Content.is_attack(str(id)))[0])
		var first_attack: String = str(m.s.magazine[attack_index])
		m.s.magazine.remove_at(attack_index); m.s.magazine.push_front(first_attack)
		m.s.fire_heat_trial.rounds = 2
		m.fire()
		var shots: Array = m.s.history.back().detail.results
		var bonus: Array = shots.map(func(r): return int(r.get("math", {}).get("breech", 0)))
		if cooled:
			check(bonus[0] == Tuning.BREECH_BONUS and bonus.slice(1).all(func(v): return v == 0), "after a cool: first attack +3 only (%s)" % [bonus])
			check(shots[0].get("part_effects", []).any(func(e): return str(e.id) == "cooling_breech"), "냉각 약실 shows as acting")
			m.s.heat = 0; m.s.fire_heat_trial.rounds = 1
			m.fire()
			check(int(m.s.history.back().detail.results[0].get("math", {}).get("breech", 0)) == 0, "the next fire gets nothing")
		else:
			check(bonus.all(func(v): return v == 0), "no cool → no bonus")
	# 야전 압축기 offers.
	var tuned_state: Dictionary = first_combat("single", []).model.s
	var old_state: Dictionary = first_combat("single", [], false).model.s
	var tuned_seen := 0
	var old_seen := 0
	for region in range(0, 5):
		for k in range(16):
			var node := {"id": region * 10000 + 400 + k, "region": region, "floor": 4, "elite": k % 2 == 0, "kind": "shop"}
			for offer in Data.offers(node, 731042 + k, 0, "single", [], [], [], [], 4, 1, tuned_state):
				if offer.id == "field_press": tuned_seen += 1
			for offer in Data.offers(node, 731042 + k, 0, "single", [], [], [], [], 4, 1, old_state):
				if offer.id == "field_press": old_seen += 1
	print("FIELD PRESS offers tuned %d old %d" % [tuned_seen, old_seen])
	check(tuned_seen == 0, "야전 압축기 is not offered in tuned runs")
	# 3. Weak parts, bigger numbers (2026-11-11).
	var Tuned = first_combat("single", [])
	check(Content.damage("pierce", first_combat("single", ["lens"]).model.s) == Content.damage("pierce", Tuned.model.s) + 2, "가속 총열: 관통탄 +2 damage")
	check(Content.damage("precise", first_combat("single", ["lens"]).model.s) == Content.damage("precise", Tuned.model.s), "가속 총열: rounds without pierce unchanged")
	check(Content.damage("pierce", first_combat("single", ["lens"], false).model.s) == Content.damage("pierce", first_combat("single", [], false).model.s), "older saves: 가속 총열 no damage")
	check(Tuning.executes(tuned_state, 9, 30) and not Tuning.executes(tuned_state, 10, 30) and Tuning.execute_bonus(tuned_state) == 4, "처형 조준기: 30% 이하, +4")
	check(Tuning.executes(old_state, 5, 80) and not Tuning.executes(old_state, 6, 80) and Tuning.execute_bonus(old_state) == 2, "older saves: HP 5 이하 +2")
	var ex = first_combat("single", ["executioner"])
	for e in ex.model.s.enemies: e.def = 0; e.barrier = 0
	ex.model.s.enemies[0].max_hp = 100; ex.model.s.enemies[0].hp = 30
	var ex_plain = first_combat("single", [])
	for e in ex_plain.model.s.enemies: e.def = 0; e.barrier = 0
	ex_plain.model.s.enemies[0].max_hp = 100; ex_plain.model.s.enemies[0].hp = 30
	check(int(ex.model._shot("pierce", 0, {}).math.subtotal) == int(ex_plain.model._shot("pierce", 0, {}).math.subtotal) + 4, "처형 조준기 +4 on a real shot at 30%")
	check(Content.damage("pierce", first_combat("single", ["momentum"]).model.s) == Content.damage("pierce", Tuned.model.s), "충격 피스톤: no −1")
	check(first_combat("burst", ["afterburner"]).model.reload_cost() == first_combat("burst", []).model.reload_cost(), "후미 점화기: no +1 swap")
	check(str(Content.part_spec("ember_core", tuned_state).upside).contains("+3"), "잔열 노심 text +3")
	# 4. Name.
	check(str(Content.PARTS.ordinary_chain.name) == "다종 급탄기", "교차 급탄기 → 다종 급탄기")
	# Version layers stay under the fix text (후미 점화기 keeps its current effect text).
	# 2026-11-12 launch pass: the tuned text keeps the current effect (×3) and no longer states the
	# removed swap cost; the upside line still comes from the version layer.
	var burner: Dictionary = Content.part_spec("afterburner", tuned_state)
	check(str(burner.text).contains("×3") and not str(burner.text).contains("재장전") and str(burner.upside) == str(Content._version_part_spec("afterburner", tuned_state).upside) and str(burner.downside) == "", "후미 점화기 keeps its ×3 effect, no swap cost in text, no downside")
	# Texts.
	check(str(Content.part_spec("cooling_breech", tuned_state).upside).contains("냉각 직후") and str(Content.part_spec("cooling_breech", old_state).upside).contains("재장전 냉각"), "냉각 약실 text follows the rule")
	check(str(Content.part_spec("ember_core", tuned_state).downside) == "열 한계 −1", "잔열 노심 text −1")
	print("PART TUNING RULES checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
