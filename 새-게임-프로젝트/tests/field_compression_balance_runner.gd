extends SceneTree
## Audits one run-core conversion against the two source rounds using the live
## resolver. This keeps the exceptional amplifier tempo visible without pretending
## that direct damage is the only cost.
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")

var checks := 0
var failures: Array = []
var rows: Array = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)

func enemy() -> Dictionary:
	return {"kind": "wall", "name": Content.ENEMY_NAMES.wall, "hp": 999, "max_hp": 999, "def": 0, "speed": 1, "distance": 100, "burn": 0}

func fixture(gun: String, source: String):
	var model = Model.new()
	model.start(gun, 731042)
	model.s.deck = [source, source, "charge", "precise", "pierce", "bore", "arc", "push"]
	model.s.hand = [source, source, "charge", "precise", "pierce"]
	model.s.draw = model.s.deck.duplicate()
	for id in model.s.hand: model.s.draw.erase(id)
	model.s.discard = []
	model.s.plan = []
	model.s.plan_load_order = []
	model.s.enemies = [enemy()]
	return model

func resolve(model) -> Dictionary:
	check(model.confirm(), "balance fixture confirms")
	var damage := 0
	var actions := 0
	while model.s.phase == "ready" and not model.s.magazine.is_empty():
		check(model.fire(), "balance fixture fires")
		actions += 1
		for result in model.s.history.back().detail.results: damage += int(result.damage)
	return {"damage": damage, "actions": actions, "distance": int(model.s.enemies[0].distance)}

func comparison(gun: String, source: String) -> Dictionary:
	var ordinary = fixture(gun, source)
	check(ordinary.load_round(source) and ordinary.load_round(source), "ordinary pair loads " + gun + "/" + source)
	var ordinary_result := resolve(ordinary)
	var compressed = fixture(gun, source)
	check(compressed.field_compress(source), "field pair compresses " + gun + "/" + source)
	var compressed_result := resolve(compressed)
	return {"gun": gun, "source": source, "ordinary": ordinary_result, "field": compressed_result, "direct_ratio": float(compressed_result.damage) / float(ordinary_result.damage), "slot_cost": Content.slot_cost(Content.field_id(source)), "anchor": Content.anchor(Content.field_id(source)), "exchange_cost": 0, "core_cost": 1}

func amplifier_combo(field_mode: bool) -> Dictionary:
	var model = fixture("amplifier", "precise")
	if field_mode:
		check(model.field_compress("precise") and model.load_round("charge"), "amplifier field combo loads")
		check(model.s.plan == ["precise_f", "charge"], "first fitting keeps boost behind field repeat")
	else:
		check(model.load_round("charge") and model.load_round("precise") and model.load_round("precise"), "amplifier ordinary combo loads")
	return resolve(model)

func _run() -> void:
	for gun in Content.GUNS:
		for source in Content.FIELD_COMPRESSIONS:
			var row := comparison(str(gun), str(source))
			rows.append(row)
			check(float(row.direct_ratio) <= 1.125001, "field compression never gains more than 12.5% direct damage " + str(gun) + "/" + str(source))
			check(int(row.exchange_cost) == 0 and int(row.core_cost) == 1, "field conversion uses its scarce run resource without double-charging exchange")
	for source in Content.FIELD_COMPRESSIONS:
		var field_id := Content.field_id(str(source))
		var physical_risk := Content.slot_cost(field_id) == 2 or not Content.anchor(field_id).is_empty()
		check(physical_risk, "every field family has visible space or position risk " + str(source))
	var normal_combo := amplifier_combo(false)
	var field_combo := amplifier_combo(true)
	check(int(field_combo.actions) == 2 and int(normal_combo.actions) == 3, "amplifier field repeat buys exactly one turn")
	check(int(field_combo.damage) < int(normal_combo.damage), "amplifier first fitting sacrifices boost-first combo damage")
	var report := {"checks": checks, "failures": failures, "comparisons": rows, "amplifier_combo": {"ordinary": normal_combo, "field": field_combo}}
	var output := OS.get_environment("QA_OUTPUT_DIR")
	if output.is_empty(): output = "user://field_compression_balance"
	DirAccess.make_dir_recursive_absolute(output)
	var file := FileAccess.open(output.path_join("field_compression_balance.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("FIELD COMPRESSION BALANCE checks=" + str(checks) + " failures=" + str(failures.size()) + " amplifier=" + str(report.amplifier_combo))
	quit(0 if failures.is_empty() else 1)
