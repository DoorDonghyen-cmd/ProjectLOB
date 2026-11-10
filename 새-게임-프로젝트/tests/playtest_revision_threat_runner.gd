extends "res://tests/ammo_expansion_rules_runner.gd"
const Threat = preload("res://redesign/enemy_threat.gd")
const Hunters = preload("res://redesign/garden_hunters.gd")
const Workers = preload("res://redesign/foundry_workers.gd")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/playtest_revision_20261026/"): quit(2); return
	var m = fixture(["basic"], [["runner", 20, 0, 3, 3]])
	check(Threat.analyze(m.s)[0].tone == "danger", "contact exactly on next action")
	m.s.enemies[0].burn = 1; m.s.enemies[0].hp = 1
	check(Threat.analyze(m.s)[0].text.contains("화상 처치"), "lethal burn cancels contact")
	m = fixture(["basic"], [["caster", 20, 0, 0, 20], ["runner", 20, 0, 1, 3]])
	m.s.enemies[0].charge_max = 2; m.s.enemies[0].charge = 1; m.s.enemies[0].charge_pull = 2
	check(Threat.analyze(m.s)[1].tone == "danger", "pull plus ordinary movement causes contact")
	m.s.enemies[0].jammed = 1
	check(Threat.analyze(m.s)[1].tone == "quiet", "interrupt cancels pull but keeps ordinary movement")
	m = fixture(["basic"], [Hunters.leader(Hunters.BOSS)])
	m.s.enemies[0].leap_left = 1
	check(Threat.analyze(m.s)[0].text.contains("돌진") and Threat.analyze(m.s)[0].step == 7, "zero base speed still predicts leap")
	m.s.enemies[0].recovering = true
	check(Threat.analyze(m.s)[0].step == 0, "recovery has no invented arrival countdown")
	m = fixture(["basic"], Workers.revise([Workers.leader(Workers.BOSS, 56, 20)]))
	m.s.enemies[0].windup = 1
	check(Threat.analyze(m.s)[0].text.contains("돌진"), "modern two-action windup")
	m = fixture(["basic"], [["spitter", 20, 0, 0, 20]])
	m.s.enemies[0].ranged_left = 1
	check(Threat.analyze(m.s)[0].text.contains("발사"), "actual launch warning")
	m.s.enemies[0].jammed = 1
	check(not Threat.analyze(m.s)[0].text.contains("발사"), "interrupted shot not advertised")
	m.s.enemies[0].jammed = 0
	m.s.projectiles = [{"uid":1,"source":0,"kind":"pressure","hp":1,"speed":6,"distance":12}]
	check(not Threat.analyze(m.s)[0].text.contains("발사"), "existing projectile prevents a second launch")
	# Same public resolver across all current regions, states and saved revisions.
	for revision in [0, 1, 2]:
		for region in range(5):
			for kind in ["combat", "elite", "boss"]:
				var node := {"id":20601,"region":region,"floor":6,"kind":"boss" if kind == "boss" else "combat","elite":kind == "elite","name":"QA"}
				var pack := Data.encounter_pack(node, 731042, "burst", 0, 0, 11, revision)
				m = fixture(["basic"]); m.s.combat_revision = revision
				m.s.enemies = pack.active.duplicate(true); m.s.reinforcements = pack.reserve.duplicate(true)
				m.s.encounter_total = pack.total; m.s.deployed = m.s.enemies.size()
				for tick in range(5):
					if not m.s.phase in ["plan", "ready"]: break
					var before := JSON.stringify(m.s)
					var readout := Threat.analyze(m.s)
					check(JSON.stringify(m.s) == before, "intent leaves save and random state untouched")
					var distances: Array = m.s.enemies.map(func(e): return e.distance)
					m._advance(1)
					for id in readout:
						check(readout[id].step == int(distances[id]) - int(m.s.enemies[id].distance), "actual approach equals displayed step")
						check((readout[id].tone == "danger") == (int(m.s.enemies[id].hp) > 0 and int(m.s.enemies[id].distance) <= 0), "contact warning agrees with actual outcome")
	FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("threat.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures}, "  "))
	print("PLAYTEST REVISION THREAT COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
