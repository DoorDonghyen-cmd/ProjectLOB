extends "res://tests/balance_review_rules.gd"
const Workers = preload("res://redesign/foundry_workers.gd")
const Patterns = preload("res://redesign/leader_patterns.gd")

func leader(gun: String = "single", id: String = Workers.BOSS, rounds: Array = ["basic_p2", "basic_p2"]):
	var m = current(rounds, [], gun)
	m.s.enemy_pattern_version = 1
	var row: Array = Workers.leader(id, 48 if id == Workers.BOSS else 28, 40)
	row = Workers.revise([row])[0]
	m.s.enemies = [Campaign.Content._enemy(row)]
	m.s.reinforcements = []; m.s.encounter_total = 1; m.s.deployed = 1
	Patterns.prepare(m.s, {"region":1})
	return m

func run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\", "/").contains("/qa_runtime/leader_patterns_20261106/"): quit(2); return
	for id in [Workers.ELITE, Workers.BOSS]:
		var m = leader("single", id)
		var e: Dictionary = m.s.enemies[0]
		var start: int = e.distance
		check(e.def == 3 and e.shell_armor == 3 and e.windup == 0, "closed opening retains authored HP/armor")
		m._advance(1, true)
		check(e.distance == start - 1 and e.windup == 1 and not e.recovering, "first action publishes windup")
		restore_check(m)
		var before: Dictionary = canonical(m.s)
		var preview: Array = m.movement_preview(1)
		check(canonical(m.s) == before, "movement preview does not spend state/RNG")
		var events: Array = m._advance(1, true)
		check(e.distance == start - 2 - e.surge and e.def == 0 and e.recovering, "second action rushes and opens armor")
		check(events.any(func(v): return v.kind == "foundry_state" and v.action == "surge" and v.armor == 0), "rush receipt carries the open armor")
		check(not preview.is_empty(), "actual movement preview exists")
		check(Workers.intent(e, false).contains("장갑 개방") and Content._enemy_rule(e).contains("다음 적 행동"), "public pattern detail explains the window")
		restore_check(m)
		var open_damage: int = shot(m).damage
		check(open_damage > 0 and e.def == 3 and not e.recovering, "one player attack fits before zero-movement reclosure")
		check(e.distance == start - 2 - e.surge, "recovery does not advance the leader")
		restore_check(m)
	for gun in ["single", "burst", "scatter", "heavy", "amplifier"]:
		var closed = leader(gun)
		var opened = leader(gun)
		opened._advance(2, true)
		var closed_hit: Dictionary = shot(closed)
		var open_hit: Dictionary = shot(opened)
		check(open_hit.damage > closed_hit.damage, "unpierced damage benefits from timing " + gun)
		var reload = leader(gun)
		reload._advance(1, true)
		var before: int = reload.s.enemies[0].distance
		var cost: int = reload.reload_cost()
		var turns: int = reload.s.turns
		check(reload.reload_magazine(), "replacement remains legal " + gun)
		check(reload.s.enemies[0].distance < before and int(reload.s.turns)-turns == cost, "replacement advances the real rush clock " + gun)
		restore_check(reload)
	for opened in [false, true]:
		var shatter = leader("single", Workers.BOSS, ["shatter", "basic_p2"])
		if opened: shatter._advance(2, true)
		var hit: Dictionary = shot(shatter)
		check(hit.armor_removed > 0 and shatter.s.enemies[0].shell_armor < 3, "shatter removes stored armor even while open")
		shatter._advance(3, true)
		check(shatter.s.enemies[0].def <= shatter.s.enemies[0].shell_armor and shatter.s.enemies[0].shell_armor == 3 - hit.armor_removed, "reclosing never regrows shredded armor")
		restore_check(shatter)
	var jam = leader("single", Workers.BOSS, ["disrupt", "basic_p2"])
	jam._advance(1, true)
	var stopped: int = jam.s.enemies[0].distance
	shot(jam)
	check(jam.s.enemies[0].windup == 1 and not jam.s.enemies[0].recovering and stopped - jam.s.enemies[0].distance <= 1, "control delays the prepared rush with the existing finite slow")
	restore_check(jam)
	var lethal = leader(); lethal.s.enemies[0].distance = 7
	lethal._advance(2, true)
	check(lethal.s.phase == "lost", "published stronger rush still resolves contact immediately")
	var safe = leader(); safe.s.enemies[0].distance = 7
	safe.s.enemies[0].hp = 1; safe.s.enemies[0].burn = 1
	safe._advance(2, true)
	check(safe.s.phase in ["reward", "won"], "burn kills before a threatened rush")
	var fresh = Campaign.new(); fresh.start("single",17,0,"balanced",4,"carrier",true)
	check(Patterns.enabled(fresh.s) and Patterns.enabled(fresh.model.s), "production new campaign opts in both halves")
	check(fresh.save() == OK, "new pattern profile saves")
	var resumed = Campaign.new(); check(resumed.restore(), "new profile resumes")
	for version in [-1, 0.5, 2, "1", true]:
		var broken: Dictionary = canonical(fresh.model.s); broken.enemy_pattern_version = version
		check(not Model.new().restore_state(broken), "invalid profile rejected " + str(version))
	var mismatch: Dictionary = canonical({"campaign":fresh.s,"combat":fresh.model.s,"profile":fresh.profile})
	mismatch.campaign.erase("enemy_pattern_version")
	check(not Campaign.new().restore_state(mismatch), "campaign/model profile mismatch rejected")
	var missing = leader(); missing.s.erase("enemy_pattern_version")
	check(not Model.new().restore_state(canonical(missing.s)), "new leader without opt-in rejected")
	for key in ["shell_armor", "def", "surge", "recovering"]:
		var bad = leader(); bad.s.enemies[0][key] = 99
		check(not Model.new().restore_state(canonical(bad.s)), "malformed new leader rejected " + key)
	for version in [1, 2]:
		var old = leader(); old.s.erase("enemy_pattern_version")
		var e: Dictionary = old.s.enemies[0]
		e.foundry_version = version; e.erase("shell_armor"); e.surge = 4
		e.windup_max = 3 if version == 1 else 2
		old._advance(int(e.windup_max), true)
		check(e.recovering and e.def == 3, "old leader retains closed armor after rush")
		restore_check(old)
		var unchanged: Dictionary = canonical(old.s)
		Patterns.prepare(old.s,{"region":1})
		check(canonical(old.s) == unchanged, "resumed unmarked campaign never acquires new leader rules")
	for region in [0,2,3,4]:
		var outside = leader(); var same: Dictionary = canonical(outside.s)
		Patterns.prepare(outside.s,{"region":region})
		check(canonical(outside.s) == same, "preparation does not change another region")
	var base = leader(); var ordinary: Dictionary = Campaign.Content._enemy(Workers.worker("mold_worker",10,20))
	base.s.enemies.append(ordinary); base.s.encounter_total = 2; base.s.deployed = 2
	var original: Dictionary = canonical(ordinary)
	Patterns.prepare(base.s,{"region":1})
	check(canonical(ordinary) == original, "ordinary workers are unchanged")
	FileAccess.open(output.path_join("rules.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("LEADER PATTERNS COMPLETE checks=%d failures=%d" % [checks,failures.size()]); quit(0 if failures.is_empty() else 1)
