extends "res://tests/supply_live_ui.gd"
## Growth structure v2 prototype rules (2026-11-10): special-first magazine, no forced
## first core, cores without the one-core limit, ammo mastery at gates.
## Uses fresh runs (walked with real combats) and the earned 래칫 region-1 gate state.
const GrowthV2 = preload("res://redesign/growth_structure.gd")
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")

func earned(file: String):
	var c = Campaign.new()
	check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_BUILD_DIR").path_join(file)))), "earned state restores " + file)
	return c

func first_win(c) -> bool:
	while c.departure_pending(): c.advance_departure(true)
	for step in range(20):
		if c.s.phase == "reward": return true
		match str(c.s.phase):
			"map":
				var combat: Array = c.choices().filter(func(n): return n.kind in ["combat", "elite"])
				if combat.is_empty() or not c.enter(int(combat[0].id)): return false
			"combat":
				var path: Array = solver.solve(c.model, 4, 18)
				if path.is_empty(): return false
				for item in path:
					if item.action == "eject": c.model.eject_magazine_rounds(item.indices)
					else: preload("res://tests/weapon_magazine_solver.gd").command(c.model, "swap" if item.action == "reload" else str(item.action))
				c.sync_combat()
			_: return false
	return c.s.phase == "reward"

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	# New runs carry the flag; the first win offers the main-round package, not a core.
	var c = Campaign.new()
	c.start("burst", SEED, 0, "balanced", Campaign.Content.RouteMap.VERSION, "work", true)
	check(GrowthV2.enabled(c.model.s), "new runs use growth structure v2")
	if check(first_win(c), "first fight won"):
		check(not c.engine_reward() and c.first_ammo_reward() and not c.reward_options().is_empty(), "first win skips the core and offers the main-round package")
	# Older runs keep the core pick.
	var legacy = Campaign.new()
	legacy.start("burst", SEED, 0, "balanced", Campaign.Content.RouteMap.VERSION, "work", true)
	legacy.model.s.erase("growth_structure_version")
	if check(first_win(legacy), "legacy first fight won"):
		check(legacy.engine_reward(), "runs without v2 still pick a growth core first")
	# Core limit lifted only for v2.
	var two_cores := ["volley_drive", "siege_drive"]
	check(Content.valid_part_set("burst", two_cores, {"growth_structure_version": 1}), "v2 equips two cores")
	check(not Content.valid_part_set("burst", two_cores) and not Content.valid_part_set("burst", two_cores, {}), "without v2 one core only")
	# Special-first magazine at the start of a fight and after a reload.
	var fight = earned("combat_burst_17_r2_n10101.json")
	var m: Model = fight.model
	m.s.growth_structure_version = GrowthV2.VERSION
	var specials: int = m.s.deck.filter(func(id): return not GrowthV2.is_basic(str(id))).size()
	m.begin_encounter(1)
	var front: Array = m.s.hand.slice(0, mini(specials, m.s.hand.size()))
	check(specials > 0 and front.all(func(id): return not GrowthV2.is_basic(str(id))), "opening hand takes specials first (%d owned)" % specials)
	var mixed := true
	var seen_basic := false
	for id in m.s.hand + m.s.draw:
		if GrowthV2.is_basic(str(id)): seen_basic = true
		elif seen_basic: mixed = false
	check(mixed, "no special waits behind a basic")
	var old = earned("combat_burst_17_r2_n10101.json")
	old.model.begin_encounter(1)
	var old_front_basics: int = old.model.s.hand.slice(0, specials).filter(func(id): return GrowthV2.is_basic(str(id))).size()
	print("OPENING old run: %d of the first %d rounds are basic" % [old_front_basics, specials])
	# Reload: unfired specials go back ahead of the basics.
	m.s.draw = ["basic_p2", "basic_p2"]
	m.s.magazine = ["precise", "basic_p2"]
	m.s.phase = "ready"
	m._reload_magazine(0, false)
	var order: Array = m.s.magazine + m.s.hand + m.s.draw
	print("RELOAD ORDER ", order)
	var precise_at: int = order.find("precise")
	var first_basic: int = -1
	for i in range(order.size()):
		if GrowthV2.is_basic(str(order[i])): first_basic = i; break
	check(precise_at >= 0 and (first_basic < 0 or precise_at < first_basic), "reload returns the unfired special ahead of basics")
	# Mastery at a gate.
	var gate = earned("gate_burst_17_r1.json")
	gate.model.s.growth_structure_version = GrowthV2.VERSION
	var family := GrowthV2.mastery_family(gate.model.s)
	check(family == "precise" and gate.gate_options().has("mastery"), "gate offers mastery of the main family (%s)" % family)
	check(gate.model.Gates.summary("mastery", gate.model.s, true).contains("Lv0 → Lv1"), "gate summary names the next level")
	check(gate.gate("mastery") and GrowthV2.mastery(gate.model.s, "precise") == 1, "taking mastery raises the family")
	check(not gate.gate("mastery"), "one gate choice per gate")
	# +1 damage per hit for that family.
	var base_fight = earned("combat_burst_17_r2_n10101.json")
	var plain := Model.new(); plain.s = Model.simulation_state(base_fight.model.s)
	var mastered := Model.new(); mastered.s = Model.simulation_state(base_fight.model.s)
	mastered.s.growth_structure_version = GrowthV2.VERSION
	mastered.s.mastery = {"precise": 1}
	for probe in [plain, mastered]:
		probe.s.buff = {}; probe.s.heat = 0
		for e in probe.s.enemies:
			e.hp = 999; e.max_hp = 999; e.def = 0; e.barrier = 0
	var a: Dictionary = plain._shot("precise", 0, {})
	var b: Dictionary = mastered._shot("precise", 0, {})
	check(int(b.damage) - int(a.damage) == int(b.hits), "mastery adds +1 per hit: %d → %d over %d hits" % [int(a.damage), int(b.damage), int(b.hits)])
	check(int(mastered._shot("pierce", 0, {}).damage) == int(plain._shot("pierce", 0, {}).damage), "other families unchanged")
	# Built-in drives: v2 guns carry their drive without using a part slot.
	var drive_state: Dictionary = {"gun": "single", "growth_structure_version": 1, "equipped_parts": ["lens"]}
	check(Content.active_parts(drive_state).has("siege_drive") and Content.equipped_parts(drive_state) == ["lens"], "리벳 carries 돌파 outside the five slots")
	check(Content.active_parts({"gun": "single", "equipped_parts": ["lens"]}) == ["lens"], "no built-in drive without v2")
	check(Content.innate_engine({"gun": "burst", "growth_structure_version": 1}) == "volley_drive" and Content.innate_engine({"gun": "heavy", "growth_structure_version": 1}) == "thermal_drive", "래칫 연쇄, 리액터 열압")
	var single_fight = earned("combat_single_17_r3_n20101.json")
	var without := Model.new(); without.s = Model.simulation_state(single_fight.model.s)
	without.s.equipped_parts = []
	var with_drive := Model.new(); with_drive.s = Model.simulation_state(without.s)
	with_drive.s.growth_structure_version = GrowthV2.VERSION
	for probe in [without, with_drive]:
		probe.s.buff = {}; probe.s.heat = 0
		for e in probe.s.enemies:
			e.hp = 999; e.max_hp = 999; e.def = 0; e.barrier = 0
	var plain_pierce: int = int(without._shot("pierce", 0, {}).damage)
	var drive_pierce: int = int(with_drive._shot("pierce", 0, {}).damage)
	check(drive_pierce >= plain_pierce * 2, "built-in 돌파 doubles a single hit: %d → %d" % [plain_pierce, drive_pierce])
	check(Content.GUN_ENGINES.size() == Content.GUNS.size(), "every gun has a drive")
	# Mastery: +2 per level for single-hit rounds.
	var master_single := Model.new(); master_single.s = Model.simulation_state(with_drive.s)
	master_single.s.mastery = {"pierce": 1}
	check(GrowthV2.mastery_bonus(master_single.s, "pierce") == 2 and GrowthV2.mastery_bonus(mastered.s, "precise") == 1, "single-hit +2, multi-hit +1 per level")
	# Support mastery (ammo overhaul): effect values grow; a second gate option.
	var support_gate = earned("gate_burst_17_r1.json")
	support_gate.model.s.growth_structure_version = GrowthV2.VERSION
	check(GrowthV2.support_family(support_gate.model.s) == "charge" and support_gate.gate_options().has("mastery_support"), "gate offers support mastery for the most-owned support family")
	var boost_before: int = Content.effect_value("charge", support_gate.model.s)
	check(support_gate.gate("mastery_support") and GrowthV2.mastery(support_gate.model.s, "charge") == 1, "taking support mastery raises 증폭")
	check(Content.effect_value("charge", support_gate.model.s) == boost_before + 1, "증폭 +1 per level: %d → %d" % [boost_before, Content.effect_value("charge", support_gate.model.s)])
	var cool_state: Dictionary = {"growth_structure_version": 1, "mastery": {"cool": 2, "shatter": 1}, "gun": "burst"}
	check(Content.effect_value("cool", cool_state) == Content.effect_value("cool", {"gun": "burst"}) + 2 and Content.effect_value("shatter", cool_state) == Content.effect_value("shatter", {"gun": "burst"}) + 1, "냉각·파쇄 grow with support mastery")
	check(Content.effect_value("charge", {"gun": "burst", "mastery": {"charge": 3}}) == Content.effect_value("charge", {"gun": "burst"}), "no support mastery without v2")
	# 예비 급탄기: one more pull-out per magazine in v2 (its hand exchange has no button there).
	check(Content.eject_limit({"growth_structure_version": 1, "equipped_parts": ["reserve"]}) == 3 and Content.eject_limit({"equipped_parts": ["reserve"]}) == 2 and Content.eject_limit({"growth_structure_version": 1}) == 2, "예비 급탄기 adds a pull-out only in v2")
	check(str(Content.part_spec("reserve", {"growth_structure_version": 1}).upside).contains("빼내기"), "예비 급탄기 text describes the pull-out in v2")
	# Overhaul 2: drives grow only at gates; 삼중 시퀀서 needs 4 kinds; 연계탄 is back; 리벳 moves pulled rounds.
	var drive_gate = earned("gate_single_17_r1.json")
	drive_gate.model.s.growth_structure_version = GrowthV2.VERSION
	drive_gate.model.s.engine.levels = {"siege_drive": 0}
	check(drive_gate.gate_options().has("drive") and not drive_gate.gate_options().has("growth"), "gate offers 구동 강화, not the old cap growth")
	check(drive_gate.gate("drive") and int(drive_gate.model.s.engine.levels.siege_drive) == 4, "구동 강화 +4 levels")
	var settled := Model.new(); settled.s = Model.simulation_state(drive_gate.model.s)
	settled.s.phase = "reward"; settled.s.engine.settled = false; settled.s.engine.siege = true
	settled.Engines.settle(settled.s, Content.active_parts(settled.s))
	check(int(settled.s.engine.levels.siege_drive) == 5, "a win meeting the drive condition still grows it (+1)")
	var capped := Model.new(); capped.s = Model.simulation_state(settled.s)
	capped.s.engine.levels.siege_drive = 8; capped.s.engine.settled = false; capped.s.engine.siege = true
	capped.Engines.settle(capped.s, Content.active_parts(capped.s))
	check(int(capped.s.engine.levels.siege_drive) == 8, "earned growth stops at 8 in v2; beyond needs a choice")
	var limit_state: Dictionary = Model.simulation_state(drive_gate.model.s); limit_state.engine.levels.siege_drive = 12
	check(settled.Engines.valid(limit_state.engine, settled.Engines.Growth.limit(limit_state)), "level 12 is save-valid in v2")
	var triad_state := {"growth_structure_version": 1, "magazine_loaded": ["precise", "pierce", "charge"], "equipped_parts": ["triad"], "magazine_build_version": 1}
	check(preload("res://redesign/magazine_build.gd").triad_bonus(triad_state, "precise") == 0, "삼중 시퀀서 needs four kinds in v2")
	triad_state.magazine_loaded = ["precise", "pierce", "charge", "arc"]
	check(preload("res://redesign/magazine_build.gd").triad_bonus(triad_state, "precise") == 3, "four kinds pay +3")
	check(preload("res://redesign/ammo_discovery.gd").ammo(["sequence", "pierce"], 4).has("sequence") and not preload("res://redesign/ammo_discovery.gd").ammo(["sequence", "pierce"], 3).has("sequence"), "연계탄 back in v4 pools only")
	var rivet = earned("combat_single_17_r3_n20101.json")
	rivet.model.s.growth_structure_version = GrowthV2.VERSION
	rivet.model.s.phase = "ready"; rivet.model.s.magazine = ["basic_p2", "pierce", "charge"]; rivet.model.s.magazine_ejected = 0
	var deck_before: int = rivet.model.s.deck.size()
	check(rivet.model.eject_magazine_rounds([0]) and rivet.model.s.magazine == ["pierce", "charge", "basic_p2"], "리벳 moves the pulled round to the back: %s" % [rivet.model.s.magazine])
	check(rivet.model.ejection_remaining() == 1 and rivet.model.s.deck.size() == deck_before, "the move counts toward the limit and spends nothing")
	# Saves.
	var restored := Model.new()
	check(restored.restore_state(JSON.parse_string(gate.model.serialized_state())) and GrowthV2.mastery(restored.s, "precise") == 1, "mastery survives save and load")
	var broken: Dictionary = JSON.parse_string(gate.model.serialized_state())
	broken.mastery = {"precise": 9}
	check(not Model.new().restore_state(broken), "out-of-range mastery rejected")
	broken.mastery = {"precise": 1}; broken.growth_structure_version = 0
	check(not Model.new().restore_state(broken), "mastery without the flag rejected")
	print("GROWTH STRUCTURE RULES checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
