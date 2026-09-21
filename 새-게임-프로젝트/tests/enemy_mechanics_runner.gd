extends SceneTree
## Deterministic lock tests for the six pre-art enemy silhouettes.

const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const CampaignContent = preload("res://redesign/campaign_content.gd")
const Forecast = preload("res://redesign/forecast.gd")
const Insight = preload("res://redesign/run_insight.gd")
var checks := 0
var failures: Array = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)

func enemy(kind: String, hp: int, armor: int, speed: int, distance: int, extra: Dictionary = {}) -> Dictionary:
	var result := {"kind": kind, "name": Content.ENEMY_NAMES[kind], "hp": hp, "max_hp": hp, "def": armor, "speed": speed, "distance": distance, "burn": 0}
	for key in extra: result[key] = extra[key]
	return result

func _run() -> void:
	var output := OS.get_environment("QA_OUTPUT_DIR")
	DirAccess.make_dir_recursive_absolute(output)

	var barrier = Model.new()
	barrier.start("single", 731042)
	barrier.s.enemies = [enemy("absorber", 10, 0, 1, 20, {"barrier": 2, "barrier_max": 2})]
	barrier.s.deck.erase("precise")
	barrier.s.deck.erase("precise")
	barrier.s.deck.append("precise_c")
	barrier.s.hand = ["precise_c"]
	barrier.s.draw = []
	barrier.s.discard = barrier.s.deck.duplicate()
	barrier.s.discard.erase("precise_c")
	check(barrier.load_round("precise_c") and barrier.confirm(), "three-hit round loads against barrier")
	var barrier_preview := Forecast.analyze(barrier.s)
	check(barrier_preview.shots[0].blocked_hits == 2 and barrier_preview.shots[0].damage == 4 and barrier_preview.enemies[0].barrier == 0, "forecast spends two barrier cells before HP")
	check(barrier.fire(), "barrier shot fires")
	var barrier_result: Dictionary = barrier.s.history.back().detail.results[0]
	check(barrier_result.blocked_hits == 2 and barrier_result.damage == 4 and barrier.s.enemies[0].hp == 6 and barrier.s.enemies[0].barrier == 0, "actual barrier settlement matches forecast")
	check(Forecast.outcome({"random": false, "hit": true, "damage": 0, "blocked_hits": 1, "hp": 10}) == "배리어 −1", "barrier forecast uses its own label")

	var caster = Model.new()
	caster.start("single", 17)
	caster.s.enemies = [
		enemy("caster", 8, 0, 1, 20, {"charge": 2, "charge_max": 3, "charge_pull": 2}),
		enemy("runner", 8, 0, 2, 10),
	]
	var events: Array = caster._advance(1)
	check(caster.s.enemies[0].charge == 0 and caster.s.enemies[0].distance == 19, "caster releases then advances normally")
	check(caster.s.enemies[1].distance == 6, "charge pull and ordinary movement both settle")
	check(events.any(func(event): return event.kind == "charge" and event.released) and events.any(func(event): return event.kind == "pull" and event.target == 1), "charge and pull are public events")
	check(Insight.threat_data([enemy("caster", 8, 0, 1, 20, {"charge": 2, "charge_max": 3, "charge_pull": 2}), enemy("runner", 8, 0, 2, 10)]).contact_turns == 4, "threat timing includes future charge pull")

	var stance = Model.new()
	stance.start("single", 17)
	stance.s.enemies = [enemy("stance", 12, 4, 1, 20, {"stance": true, "stance_def": 4, "stance_closed": true})]
	stance._advance(1)
	check(stance.s.enemies[0].def == 0 and not stance.s.enemies[0].stance_closed, "closed stance opens after one turn")
	stance._advance(1)
	check(stance.s.enemies[0].def == 4 and stance.s.enemies[0].stance_closed, "open stance closes after next turn")
	check(Content.enemy_rule(stance.s.enemies[0]).contains("장갑 4 → 0"), "stance next value is explicit")

	var seen_by_region := {}
	for region in range(5):
		seen_by_region[region] = []
		for seed_value in range(8):
			for node in CampaignContent.nodes(region, seed_value):
				if node.kind not in ["combat", "boss"]: continue
				var pack := CampaignContent.encounter_pack(node, seed_value, "single", 0, 0)
				for candidate in pack.active + pack.reserve:
					if not seen_by_region[region].has(candidate.kind): seen_by_region[region].append(candidate.kind)
	check(not seen_by_region[0].has("caster") and seen_by_region[1].has("caster"), "caster begins in the airworks")
	check(not seen_by_region[1].has("absorber") and seen_by_region[2].has("absorber"), "absorber begins in maintenance")
	check(not seen_by_region[2].has("stance") and seen_by_region[3].has("stance") and seen_by_region[4].has("stance"), "stance begins in management and returns at summit")

	for region in range(5):
		var floor_count := int(CampaignContent.info(region).floors)
		var boss_node: Dictionary = CampaignContent.nodes(region, 731042).filter(func(node): return int(node.floor) == floor_count)[0]
		var pack := CampaignContent.encounter_pack(boss_node, 731042, "single", 0, 0)
		var formation: Array = pack.active
		check(not formation.is_empty() and formation.size() <= 4 and int(pack.total) <= 8, "gate formation bounded region %d" % region)
		if region == 1: check(int(formation[0].charge_max) == 3, "airworks gate examines charge")
		if region == 2: check(int(formation[0].barrier) == 3, "maintenance gate examines barrier")
		if region == 3: check(bool(formation[0].stance), "management gate examines stance")
		if region == 4: check(bool(formation[0].stance) and int(formation[0].barrier) == 3 and int(formation[0].charge_max) == 3, "summit gate combines learned locks")

	var save_path := output.path_join("enemy_state.json")
	check(stance.save_run(save_path) == OK, "mechanic state saves")
	var restored := Model.new()
	check(restored.restore_run(save_path), "mechanic state restores")
	check(not restored.s.is_empty() and int(restored.s.enemies[0].def) == int(stance.s.enemies[0].def) and bool(restored.s.enemies[0].stance_closed) == bool(stance.s.enemies[0].stance_closed) and int(restored.s.enemies[0].distance) == int(stance.s.enemies[0].distance), "mechanic fields round trip exactly")

	var report := FileAccess.open(output.path_join("enemy_mechanics_report.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures, "seen_by_region": seen_by_region}, "\t"))
	report.close()
	print("ENEMY MECHANICS COMPLETE checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
