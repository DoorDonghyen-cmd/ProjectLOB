extends SceneTree
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const Data = preload("res://redesign/campaign_content.gd")
const Forecast = preload("res://redesign/forecast.gd")
const Experiment = preload("res://experiment.gd")
const MODES := ["baseline", "heat_plus1", "limit_minus2", "sustained", "sustained_rebalanced", "fault8", "fault2", "weapon_fault"]
const BUILDS := ["plain", "volley", "siege", "thermal"]
var checks := 0
var failures := 0
var original := false

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)

func recipe(gun: String, build: String) -> Dictionary:
	var cap := int(Content.GUNS[gun].capacity)
	if build == "siege": cap -= 1
	var order: Array = []
	var parts: Array = []
	match build:
		"plain":
			for unused in range(cap): order.append("basic_p2")
		"volley":
			parts = ["volley_drive", "duplex", "sequencer"]
			order = ["charge"]
			for unused in range(cap - 1): order.append("precise_p3")
		"siege":
			parts = ["siege_drive", "sequencer", "afterburner"]
			order = ["charge"]
			for unused in range(cap - 1): order.append("pierce_p3")
		"thermal":
			parts = ["thermal_drive", "sequencer", "reclaimer"]
			order = ["charge_heat"]
			for unused in range(cap - 2): order.append("pierce_p3")
			order.append("cool")
	return {"order": order, "parts": parts}

func fixture(gun: String, build: String, scenario: int, warm: bool, mode: String, seed_value: int, order_override: Array = []):
	var r := recipe(gun, build)
	var order: Array = r.order if order_override.is_empty() else order_override
	var m = Model.new()
	m.start(gun, seed_value, false, "carrier")
	m.s.combat_revision = 2
	m.s.reserve_version = 1
	m.s.inventory_version = 1
	m.s.emergency_version = 1
	m.s.equipped_parts = r.parts.duplicate()
	m.s.deck = order.duplicate()
	while m.s.deck.size() < 20: m.s.deck.append("basic_p2")
	m.begin_encounter()
	for core in ["volley_drive", "siege_drive", "thermal_drive"]:
		if r.parts.has(core): m.s.engine.levels[core] = scenario * 4
	var region: int = [0, 1, 4][scenario]
	var floor_number: int = [3, 7, 10][scenario]
	var node := {"id": region * 10000 + floor_number * 10, "region": region, "floor": floor_number, "kind": "combat" if scenario == 0 else "boss", "elite": false, "name": "QA"}
	var pack := Data.encounter_pack(node, seed_value, gun, 0, 0, 11, 2)
	m.s.enemies = pack.active.duplicate(true)
	m.s.reinforcements = pack.reserve.duplicate(true)
	m.s.encounter_total = pack.total
	m.s.deployed = pack.active.size()
	m.assign_opening_lanes()
	m.s.hand = order.duplicate()
	m.s.draw = m.s.deck.duplicate()
	for id in order: m.s.draw.erase(id)
	# Equal starting temperature, calculated BEFORE the lower-limit candidate.
	m.s.heat = Content.hot_threshold(m.s) - 1 if warm else 0
	m.s.qa_mode = mode
	m.s.qa_chain = 0
	return m

func load_order(m, order: Array) -> void:
	for id in Content.loading_order(order): check(m.load_round(str(id)), "legal loading " + str(id))
	check(m.confirm(), "legal confirmation")

func total_hp(m) -> int:
	var hp := 0
	for enemy in m.s.enemies + m.s.reinforcements: hp += int(enemy.hp)
	return hp

func run_magazine(m, include_trace: bool = false) -> Dictionary:
	var hp := total_hp(m)
	var turns := int(m.s.turns)
	var spent: int = m.s.discard.size()
	var shots := int(m.s.shots)
	var faults := int(m.s.get("qa_failures", 0))
	var peak := int(m.s.heat)
	var forced := 0
	var heat_events := 0
	var trace: Array = []
	for attempt in range(12):
		if m.s.phase != "ready" or m.s.magazine.is_empty(): break
		check(m.fire(), "real fire")
		var detail: Dictionary = m.s.history.back().detail
		peak = maxi(peak, int(detail.heat_peak))
		forced += int(detail.forced_reload.get("cost", 0))
		heat_events += int(not detail.forced_reload.is_empty())
		if include_trace:
			trace.append({"shots": detail.results.map(func(r): return {"id":r.id, "heat_before":r.heat_before, "heat_added":r.heat_added, "heat_after":r.heat_after, "damage":r.damage}), "forced_cost":detail.forced_reload.get("cost",0), "fault":detail.get("qa_fault",false), "turns":m.s.turns})
	check(m.s.phase != "ready" or m.s.magazine.is_empty(), "bounded magazine execution")
	var distance := 999
	for enemy in m.s.enemies:
		if int(enemy.hp) > 0: distance = mini(distance, int(enemy.distance))
	var result := {"damage": hp-total_hp(m), "turns": int(m.s.turns)-turns, "shots": int(m.s.shots)-shots, "spent": m.s.discard.size()-spent, "failures": int(m.s.get("qa_failures",0))-faults, "peak":peak, "heat_end":m.s.heat, "forced_cost":forced, "overheat_events":heat_events, "phase":m.s.phase, "min_distance":distance, "kills":m.s.enemies.filter(func(e): return int(e.hp)<=0).size()}
	# Equal endpoint: an empty cool magazine still owes a normal reload. Measure
	# that on a detached real model so immediate action forecasts remain testable.
	var cycle = Model.new(); cycle.s = m.s.duplicate(true)
	if cycle.s.phase == "ready": check(cycle.reload_magazine(), "complete normal cycle reload")
	result.cycle_turns = int(cycle.s.turns)-turns
	result.cycle_damage = hp-total_hp(cycle)
	result.cycle_phase = cycle.s.phase
	result.cycle_min_distance = 999
	for enemy in cycle.s.enemies:
		if int(enemy.hp)>0: result.cycle_min_distance = mini(result.cycle_min_distance,int(enemy.distance))
	if include_trace: result.trace = trace
	return result

func forecast_checks() -> void:
	for mode in ["baseline"] if original else MODES.slice(0, 5):
		for gun in Content.GUNS:
			var order := ["basic_p2", "cool", "basic_p2"]
			var m = fixture(gun, "plain", 1, true, mode, 731042, order)
			for id in Content.loading_order(order): check(m.load_round(id), "forecast loading")
			var saved := JSON.stringify(m.s)
			var prediction := Forecast.analyze(m.s, false, true)
			check(JSON.stringify(m.s) == saved, "forecast does not consume live state/RNG")
			check(m.confirm(), "confirm forecast case")
			run_magazine(m)
			if gun != "scatter":
				check(prediction.enemies == m.s.enemies and prediction.projectiles == m.s.projectiles, "deterministic forecast matches real outcomes " + mode + gun)
				check(prediction.remaining == m.s.magazine and int(prediction.heat.end_max) == int(m.s.heat), "forecast remaining/temperature matches")
			else:
				check(int(m.s.heat) >= int(prediction.heat.end_min) and int(m.s.heat) <= int(prediction.heat.end_max), "scatter heat is inside exact range")
				for i in range(m.s.enemies.size()): check(int(m.s.enemies[i].hp)>=int(prediction.enemies[i].hp_min) and int(m.s.enemies[i].hp)<=int(prediction.enemies[i].hp_max), "scatter actual HP within forecast distribution")

func protocol_checks() -> Array:
	var evidence: Array = []
	if original: return evidence
	# Button boundaries do not reset consecutive attack count, including amplifier.
	var m = fixture("amplifier", "plain", 2, false, "sustained", 17)
	m.s.enemies = [Data._enemy(["wall", 500, 0, 0, 80])]
	m.s.reinforcements = []
	m.s.encounter_total = 1; m.s.deployed = 1; m.assign_opening_lanes()
	load_order(m, ["basic_p2", "basic_p2", "basic_p2"])
	for expected in [1, 2, 3]:
		check(m.fire(), "separate amplifier trigger")
		check(int(m.s.qa_chain) == expected, "trigger split cannot reset sustained load")
	check(m.s.heat == 7, "three 2-heat attacks add 0,0,1")
	check(m.reload_magazine() and m.s.qa_chain == 0, "paid reload clears sustained count")
	var state := {"qa_mode":"sustained", "qa_chain":4}
	check(Experiment.extra_heat(state,"charge") == 0 and state.qa_chain == 4, "support cannot silently reset counter")
	check(Experiment.extra_heat(state,"cool") == 0 and state.qa_chain == 0, "explicit cooling clears counter")
	check(Experiment.extra_heat(state,"precise_p3") == 0 and state.qa_chain == 1, "multihit counts as one fired card")
	# Serialization retains counter/RNG in this experiment; this is NOT a product migration.
	m = fixture("heavy", "plain", 1, false, "sustained", 17)
	load_order(m, recipe("heavy","plain").order)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(m.s))
	var restored = Model.new()
	check(restored.restore_state(saved), "experimental deterministic checkpoint restores")
	check(run_magazine(m) == run_magazine(restored), "restored sustained checkpoint has same outcome")
	# Find an actual misfire; preserve other loaded rounds and spend only the faulty round.
	for seed_value in range(1, 501):
		m = fixture("heavy", "plain", 1, false, "fault8", seed_value)
		load_order(m, ["basic_p2", "basic_p2", "basic_p2"])
		var copy = Model.new(); copy.s = m.s.duplicate(true)
		check(m.fire() and copy.fire(), "fault replay executes")
		check(m.s == copy.s, "fault RNG checkpoint replay identical")
		if int(m.s.get("qa_failures", 0)) == 0: continue
		var detail: Dictionary = m.s.history.back().detail
		check(m.s.discard.size() == int(m.s.shots)+1, "only failed card is lost in addition to successful shots")
		check(m.s.magazine.size() == 3-int(m.s.shots)-1, "unfired magazine survives fault reload")
		check(detail.fault_reload.cost == m.base_reload_cost(), "fault pays one normal reload, not arbitrary extra turns")
		check(m.s.hand.size()+m.s.draw.size()+m.s.magazine.size()+m.s.discard.size()==m.s.deck.size(), "fault recovery conserves owned ammo")
		evidence.append({"fault_seed":seed_value,"shots":m.s.shots,"spent":m.s.discard.size(),"preserved":m.s.magazine.size(),"turns":m.s.turns})
		break
	check(not evidence.is_empty(), "misfire recovery exercised")
	return evidence

func tactics() -> Array:
	var rows: Array = []
	for mode in ["baseline"] if original else MODES.slice(0,5):
		for gun in ["single", "burst", "scatter", "heavy"]:
			for style in ["full", "cool_early", "cool_late", "two_batches"]:
				var order: Array = []
				for unused in range(int(Content.GUNS[gun].capacity)): order.append("basic_p2")
				if style == "cool_early": order[1] = "cool"
				if style == "cool_late": order[-1] = "cool"
				var m = fixture(gun, "plain", 1, false, mode, 731042, order)
				m.s.enemies = [Data._enemy(["wall",200,0,1,30])]
				m.s.reinforcements = []; m.s.encounter_total=1; m.s.deployed=1; m.assign_opening_lanes()
				var initial_hp := total_hp(m)
				var result: Dictionary
				if style == "two_batches":
					load_order(m,order.slice(0,2)); result=run_magazine(m,true)
					check(m.reload_magazine(),"pay to split magazine")
					load_order(m,order.slice(2)); var second:=run_magazine(m,true)
					result.trace.append_array(second.trace)
					result.damage=initial_hp-total_hp(m);result.turns=m.s.turns;result.peak=maxi(result.peak,second.peak)
					result.heat_end=m.s.heat;result.forced_cost+=second.forced_cost;result.overheat_events+=second.overheat_events
					result.shots=m.s.shots;result.spent=m.s.discard.size()
					result.phase=second.phase;result.min_distance=second.min_distance;result.kills=second.kills
					result.cycle_turns=m.s.turns+second.cycle_turns-second.turns
					result.cycle_damage=result.damage+second.cycle_damage-second.damage
					result.cycle_phase=second.cycle_phase;result.cycle_min_distance=second.cycle_min_distance
				else:
					load_order(m,order); result=run_magazine(m,true)
				result.merge({"mode":mode,"gun":gun,"style":style})
				rows.append(result)
	return rows

func fault_sensitivity() -> Array:
	var rows: Array = []
	if original: return rows
	var seeds := RandomNumberGenerator.new()
	seeds.seed = 29102026
	for sample in range(256):
		var seed_value := seeds.randi_range(1, 2000000000)
		for mode in ["baseline", "fault8", "fault2", "weapon_fault"]:
			for gun in ["single", "heavy", "amplifier"]:
				for build in ["plain", "siege"]:
					var m = fixture(gun,build,2,false,mode,seed_value)
					load_order(m,recipe(gun,build).order)
					var result := run_magazine(m)
					result.merge({"mode":mode,"gun":gun,"build":build,"seed":seed_value})
					rows.append(result)
	return rows

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/heat_comparison/"): quit(2); return
	original = OS.get_environment("QA_ORIGINAL") == "1"
	var rows: Array = []
	forecast_checks()
	var protocols := protocol_checks()
	var tactic_rows := tactics()
	for mode in ["baseline"] if original else MODES:
		for gun in Content.GUNS:
			for build in BUILDS:
				for scenario in range(3):
					for warm in [false,true]:
						for sample in range(16):
							var seed_value := 731042 + sample * 101
							var m = fixture(gun,build,scenario,warm,mode,seed_value)
							load_order(m,recipe(gun,build).order)
							var result := run_magazine(m)
							result.merge({"mode":mode,"gun":gun,"build":build,"scenario":scenario,"warm":warm,"seed":seed_value})
							rows.append(result)
		print("MEASURED " + mode + " rows=" + str(rows.size()))
	var sensitivity := fault_sensitivity()
	var report := {"original":original,"checks":checks,"failures":failures,"rows":rows,"tactics":tactic_rows,"protocols":protocols,"fault_sensitivity":sensitivity,"method":"Matched initial magazines and heat, 5 weapons, 4 builds, 3 current encounter packs, 16 paired seeds. Only the loaded magazine is executed, including obligatory reload or fault recovery. Not campaign completion or player win rates. Fault variants add disruption to current heat rules; full heat replacement is not modeled. Independent 256-seed cold final-boss sensitivity uses 3 weapons and 2 builds."}
	FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("HEAT COMPARISON COMPLETE rows=%d checks=%d failures=%d" % [rows.size(),checks,failures])
	quit(1 if failures else 0)
