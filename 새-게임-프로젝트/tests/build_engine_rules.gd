extends SceneTree
## Build engine trial rules (2026-11-08): 연타 공명기·타격 기록기, calculation line,
## offers, saves. Shots run on the real Model against an earned region-3 combat state
## (QA_BUILD_DIR) with its enemies made into plain dummies, so numbers are controlled.
const Campaign = preload("res://redesign/campaign.gd")
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const Data = preload("res://redesign/campaign_content.gd")
const BuildEngine = preload("res://redesign/build_engine.gd")
const Readout = preload("res://redesign/damage_readout.gd")
const Engines = preload("res://redesign/damage_engines.gd")
var checks := 0
var failures: Array = []
var rows: Array = []
var base_state: Dictionary

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label); print("FAIL: " + label)
	return ok

func dummy_model(parts: Array, growth: int = 0) -> Model:
	var m := Model.new()
	m.s = Model.simulation_state(base_state)
	m.s.build_engine_version = BuildEngine.VERSION
	m.s.equipped_parts = parts.duplicate()
	m.s.engine = Engines.fresh()
	m.s.heat = 0
	m.s.buff = {}
	m.s.erase("part_growth")
	if growth > 0: m.s.part_growth = {"tally": growth}
	for e in m.s.enemies:
		e.hp = 9999; e.max_hp = 9999; e.def = 0; e.barrier = 0
	return m

## One 연타 shot, optionally after a 증폭 round, optionally as the third shot.
func volley(parts: Array, boosted: bool, third: bool, growth: int = 0) -> Dictionary:
	var m := dummy_model(parts, growth)
	if boosted: m._shot("charge", -1, {"fired_count": 1})
	return m._shot("precise", -1, {"fired_count": 2 if third else 0})

func row(label: String, parts: Array, boosted: bool, third: bool, growth: int = 0) -> int:
	var result := volley(parts, boosted, third, growth)
	var damage := int(result.get("damage", 0))
	rows.append({"label": label, "damage": damage, "hits": int(result.get("hits", 0)), "ledger": Readout.ledger_text(result)})
	print("ROW %-34s %4d  %s" % [label, damage, Readout.ledger_text(result)])
	return damage

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	var c = Campaign.new()
	check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_BUILD_DIR").path_join("combat_single_17_r3_n20101.json")))), "earned combat restores")
	base_state = c.model.s
	# Multiples on a plain dummy (no armor). Rivet adds +1 to attack rounds.
	var plain := row("연타 · 파츠 없음", [], false, false)
	var core := row("연쇄 구동핵", ["volley_drive"], false, false)
	var duplex := row("구동핵+복열", ["volley_drive", "duplex"], false, false)
	var resonant := row("구동핵+복열+공명기", ["volley_drive", "duplex", "resonator"], false, false)
	check(plain > 0 and core > plain and duplex > core, "existing parts still add damage")
	# Hit n is ×n, so h hits deal h(h+1)/2 hit-units instead of h.
	var hits := int(volley(["volley_drive", "duplex"], false, false).hits)
	check(hits >= 3 and resonant * hits == duplex * hits * (hits + 1) / 2, "공명기 turns %d hits into ×1..×%d: %d vs %d" % [hits, hits, resonant, duplex])
	var boosted := row("구동핵+복열+증폭", ["volley_drive", "duplex"], true, false)
	var boosted_res := row("구동핵+복열+공명기+증폭", ["volley_drive", "duplex", "resonator"], true, false)
	check(boosted_res * 2 == boosted * (hits + 1), "공명기 multiplies boosted hits too")
	var third := row("…+제3 격발기(3번째 발)", ["volley_drive", "duplex", "third_striker"], true, true)
	var third_res := row("…+공명기+제3 격발기(3번째 발)", ["volley_drive", "duplex", "resonator", "third_striker"], true, true)
	check(third == boosted * 3 and third_res == boosted_res * 3, "제3 격발기 still ×3 on top")
	var tally0 := row("…+기록기 +0", ["volley_drive", "duplex", "resonator", "third_striker", "tally"], true, true, 0)
	var tally3 := row("…+기록기 +3(9처치)", ["volley_drive", "duplex", "resonator", "third_striker", "tally"], true, true, 9)
	var tally6 := row("…+기록기 +6(18처치)", ["volley_drive", "duplex", "resonator", "third_striker", "tally"], true, true, 18)
	check(tally0 == third_res and tally3 > tally0 and tally6 > tally3, "기록기 grows with the record")
	check(row("기록 18처치 · 기록기 미장착", ["volley_drive", "duplex", "resonator", "third_striker"], true, true, 18) == third_res, "the record does nothing while unequipped")
	# Only volley rounds resonate.
	var pierce_plain: int = dummy_model(["volley_drive"])._shot("pierce", -1, {}).damage
	var pierce_res: int = dummy_model(["volley_drive", "resonator"])._shot("pierce", -1, {}).damage
	check(pierce_plain == pierce_res, "공명기 leaves single-hit rounds alone")
	# Heat cost +1 for volley rounds with the resonator.
	var cool := dummy_model(["duplex"])
	var hot := dummy_model(["duplex", "resonator"])
	check(Content.part_heat_bonus("precise", hot.s) == Content.part_heat_bonus("precise", cool.s) + 1, "공명기 adds 1 heat to 연타")
	# Old runs (no build_engine_version) ignore the parts.
	var old := dummy_model(["volley_drive", "duplex", "resonator", "tally"], 18)
	old.s.erase("build_engine_version"); old.s.erase("part_growth")
	check(int(old._shot("precise", -1, {}).damage) == duplex, "old runs ignore 공명기·기록기")
	# Calculation line.
	var shot := volley(["volley_drive", "duplex", "resonator", "third_striker"], true, true)
	var text := Readout.ledger_text(shot)
	check(text.contains("×3") and text.contains("공명×1~%d" % hits) and text.contains("+"), "calculation line shows additions, ×3 and 공명: " + text)
	check(Readout.entry(shot).ledger == text, "damage readout carries the calculation line")
	check(text.ends_with("= %d" % int(shot.damage)), "with no armor the line's total equals the damage dealt: " + text)
	check(Readout.ledger_text(dummy_model([])._shot("charge", -1, {})).is_empty(), "no calculation line for a support round")
	# Kill record: only 연타 kills while the 기록기 is equipped.
	var killer := dummy_model(["tally"])
	for i in range(3):
		killer.s.enemies[0].hp = 1
		killer._shot("precise", 0, {})
	check(BuildEngine.tally_kills(killer.s) == 3 and BuildEngine.tally_bonus(killer.s) == 1, "three 연타 kills give +1")
	killer.s.enemies[0].hp = 1
	killer._shot("pierce", 0, {})
	check(BuildEngine.tally_kills(killer.s) == 3, "a 철갑 kill does not count")
	var idle := dummy_model([])
	idle.s.enemies[0].hp = 1
	idle._shot("precise", 0, {})
	check(BuildEngine.tally_kills(idle.s) == 0, "no record without the 기록기")
	# Saves.
	# Save checks use the unmodified earned state (the dummies above are not save-valid).
	var saved := Model.new()
	saved.s = Model.simulation_state(base_state)
	saved.s.build_engine_version = BuildEngine.VERSION
	saved.s.part_growth = {"tally": 3}
	var round_trip := Model.new()
	check(round_trip.restore_state(JSON.parse_string(saved.serialized_state())) and BuildEngine.tally_kills(round_trip.s) == 3, "record survives save and load")
	var broken: Dictionary = JSON.parse_string(saved.serialized_state())
	broken.part_growth = {"tally": 999}
	check(not Model.new().restore_state(broken), "out-of-range record rejected")
	broken.part_growth = {"lens": 1}
	check(not Model.new().restore_state(broken), "unknown growth part rejected")
	broken.part_growth = {"tally": 3}; broken.build_engine_version = 0
	check(not Model.new().restore_state(broken), "growth without the trial flag rejected")
	# Campaign: new runs get the flag; dismantle forgets the record.
	var fresh = Campaign.new()
	fresh.start("single", 251107, 0, "balanced", Campaign.Content.RouteMap.VERSION, "work", true)
	check(BuildEngine.enabled(fresh.model.s), "new magazine runs use the build engine")
	var legacy = Campaign.new()
	legacy.start("single", 251107)
	check(not BuildEngine.enabled(legacy.model.s), "older run kinds do not")
	fresh.s.phase = "shop"; fresh.s.parts.append("tally"); fresh.model.s.part_growth = {"tally": 6}
	check(fresh.dismantle("tally") and BuildEngine.tally_kills(fresh.model.s) == 0, "dismantling the 기록기 loses its record")
	# Offers: 연타 runs see the new parts; runs without the flag never do.
	var deck_state: Dictionary = Model.simulation_state(c.model.s)
	deck_state.build_engine_version = BuildEngine.VERSION
	deck_state.deck = ["precise_p2", "precise_p2", "precise_p2", "precise", "charge", "charge", "basic", "basic"]
	deck_state.equipped_parts = ["volley_drive"]
	var seen_new := 0
	var seen_old := 0
	var old_state := deck_state.duplicate(true)
	old_state.erase("build_engine_version")
	for region in range(1, 5):
		for k in range(12):
			var node := {"id": region * 10000 + 400 + k, "region": region, "floor": 4, "elite": k % 3 == 0, "kind": "shop"}
			for offer in Data.offers(node, 731042 + k, 0, "single", ["volley_drive"], [], [], ["volley_drive"], 3, 1, deck_state):
				if offer.type == "part" and BuildEngine.NEW_PARTS.has(offer.id): seen_new += 1
			for offer in Data.offers(node, 731042 + k, 0, "single", ["volley_drive"], [], [], ["volley_drive"], 3, 1, old_state):
				if offer.type == "part" and BuildEngine.NEW_PARTS.has(offer.id): seen_old += 1
	print("OFFERS new-part appearances in 48 연타 offers: %d (old runs: %d)" % [seen_new, seen_old])
	check(seen_new > 0 and seen_old == 0, "new parts are offered only to build-engine runs")
	var report := FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("build_engine_rows.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"rows": rows, "offers_new": seen_new, "checks": checks, "failures": failures}, "\t"))
	report.close()
	print("BUILD ENGINE RULES checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
