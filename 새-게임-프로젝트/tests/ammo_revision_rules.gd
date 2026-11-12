extends SceneTree
## Round naming and rework (2026-11-12, docs/direction/ammo-naming.md 1~4): compressed + mark,
## 연계 wording, 연계탄 raises the 교차 step, 예약탄 holds a round for the next magazine front.
const Campaign = preload("res://redesign/campaign.gd")
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const Mix = preload("res://redesign/mix_combo.gd")
const Revision = preload("res://redesign/ammo_revision.gd")
const Readout = preload("res://redesign/damage_readout.gd")
var checks := 0
var failures: Array = []
var base_state: Dictionary

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label); print("FAIL: " + label)
	return ok

func rig(rounds: Array, revised := true) -> Model:
	var m := Model.new()
	m.s = Model.simulation_state(base_state)
	m.s.mix_combo_version = Mix.VERSION
	if revised: m.s.ammo_revision_version = Revision.VERSION
	else: m.s.erase("ammo_revision_version")
	m.s.equipped_parts = []; m.s.heat = 0; m.s.buff = {}
	for e in m.s.enemies:
		e.hp = 999; e.max_hp = 999; e.def = 0; e.barrier = 0
	m.s.magazine = rounds.duplicate()
	m.s.history.append({"action": "load", "floor": m.s.floor, "turn": m.s.turns, "detail": {}})
	return m

func fire_one(m: Model) -> Array:
	m.s.heat = 0
	if m.FireHeatTrial.enabled(m.s): m.s.fire_heat_trial.rounds = 1
	m.fire()
	return m.s.history.back().detail.get("results", [])

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	var c = Campaign.new()
	check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_BUILD_DIR").path_join("combat_heavy_17_r3_n20101.json")))), "earned combat restores")
	base_state = c.model.s
	# 1. Compressed mark.
	check(str(Content.AMMO.precise.name) == "연타탄" and str(Content.AMMO.precise_c.name) == "연타탄+" and str(Content.AMMO.pierce_p2_power_c.name) == "철갑탄+", "compressed rounds read 연타탄+ / 철갑탄+")
	check(Content.AMMO.keys().all(func(id): return bool(Content.AMMO[id].get("compressed", false)) == str(Content.AMMO[id].name).ends_with("+")), "every compressed round, and only those, has the + mark")
	check(preload("res://redesign/samples/shop_counter_review/offer.gd").item_name("precise_c", {}) == "연타탄+", "shop no longer adds 압축 in front")
	# 2. 연계 wording.
	var label := preload("res://redesign/focus_build.gd").offer_label(base_state, "charge")
	check(not label.contains("연계"), "support label no longer says 연계: " + label)
	# 3. 연계탄 raises the step.
	var revised := {"ammo_revision_version": Revision.VERSION}
	check(Mix.level(["precise", "sequence", "pierce"], revised) == 3 and Mix.level(["precise", "sequence", "pierce"]) == 2, "연계탄 adds +2 to the step (3 vs 2 before)")
	var m := rig(["precise_p2", "sequence", "pierce"])
	var crosses: Array = []
	var sequence_bonus := 0
	for i in range(3):
		var shot: Array = fire_one(m)
		crosses.append(int(shot[0].get("math", {}).get("cross", 0)))
		if str(shot[0].id) == "sequence": sequence_bonus = int(shot[0].get("math", {}).get("sequence", 0))
	print("SEQUENCE crosses ", crosses)
	check(crosses == [0, 0, 3] and sequence_bonus == 0, "연타 → 연계 → 철갑: +0 +0 +3, no own +2 per kind")
	var old := rig(["precise_p2", "sequence", "pierce"], false)
	var old_crosses: Array = []
	for i in range(3): old_crosses.append(int(fire_one(old)[0].get("math", {}).get("cross", 0)))
	check(old_crosses == [0, 1, 2], "older saves: 연계탄 counts as one switch")
	# 4. 예약탄 holds the round behind it for the next magazine front.
	var p := rig(["prepare", "pierce", "basic_p2", "basic_p2"])
	var shot := fire_one(p)
	check(p.s.held_front == ["pierce"] and not p.s.magazine.has("pierce"), "예약탄 takes 철갑탄 out and holds it")
	check(str(Readout.entry(shot[0]).label).begins_with("다음 탄창 맨 앞 1발"), "readout: 다음 탄창 맨 앞 1발")
	check(not preload("res://redesign/ammo_reserve.gd").exhausted(p.s), "held rounds count as ammo")
	while not p.s.magazine.is_empty() and p.s.phase == "ready": fire_one(p)
	if p.s.phase == "ready" and p.s.magazine.is_empty(): p.reload_magazine()
	if p.s.phase == "plan": p.trial_load_magazine()
	check(p.s.phase == "ready" and str(p.s.magazine[0]) == "pierce" and p.s.get("held_front", []).is_empty(), "the next magazine starts with the held 철갑탄 (%s)" % [p.s.magazine.slice(0, 3)])
	var q := rig(["prepare", "pierce", "basic_p2"], false)
	fire_one(q)
	check(q.s.magazine.has("pierce") and q.s.get("held_front", []).is_empty(), "older saves: 예약탄 keeps the old rule")
	# Pools, new runs, saves.
	check(preload("res://redesign/ammo_discovery.gd").ammo(["prepare", "pierce"], 5).has("prepare") and not preload("res://redesign/ammo_discovery.gd").ammo(["prepare", "pierce"], 4).has("prepare"), "예약탄 back in v5 pools only")
	var fresh = Campaign.new(); fresh.start("burst", 731042, 0, "balanced", Campaign.Content.RouteMap.VERSION, "carrier", true)
	check(Revision.enabled(fresh.model.s) and int(fresh.s.discovery_version) == 5, "new runs: revision on, discovery v5")
	check(Revision.text("sequence", fresh.model.s).contains("교차") and preload("res://redesign/readability.gd").description("prepare", fresh.model.s).contains("다음 탄창 맨 앞"), "round texts follow the rework")
	var saved: Dictionary = JSON.parse_string(fresh.model.serialized_state())
	saved.held_front = ["pierce"]
	check(Model.new().restore_state(saved.duplicate(true)), "held rounds survive save")
	saved.held_front = ["pierce", "pierce", "pierce", "pierce"]
	check(not Model.new().restore_state(saved.duplicate(true)), "at most 3 held rounds")
	saved.held_front = ["pierce"]; saved.ammo_revision_version = 0
	check(not Model.new().restore_state(saved), "held rounds need the revision flag")
	print("AMMO REVISION RULES checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
