extends "res://tests/city_campaign_runner.gd"
const CentralSolver = preload("res://tests/central_combat_solver.gd")
var battles: Array = []
var runs: Array = []

func probe(gun: String, seed_value: int) -> void:
	var c = Campaign.new();c.start(gun,seed_value,0,"balanced",3,"carrier")
	var search = CentralSolver.new();search.candidate_limit = 700
	var core: String = {"single":"siege_drive","burst":"volley_drive","scatter":"volley_drive","heavy":"thermal_drive","amplifier":"siege_drive"}[gun]
	var cleared := 0
	commands = []
	for iteration in range(160):
		if cleared >= 5 or c.s.phase in ["lost","won","gate"]:break
		match str(c.s.phase):
			"map":
				var choices: Array = c.choices()
				if not check(not choices.is_empty(), "early route available"):break
				if not command(c,{"action":"enter","id":choices[0].id}):break
			"combat":
				check(c.model.s.sustained_version == 1 and c.model.s.sustained_attacks == 0, "real encounter begins with fresh B1 count")
				check(not c.model.s.deck.has("cool"), "control has not acquired cooling")
				var before: Dictionary = c.model.s.duplicate(true)
				var path: Array = search.solve(c.model,4,16)
				var wider := path.is_empty()
				if wider:
					search.candidate_limit = 1500;path = search.solve(c.model,10,20);search.candidate_limit = 700
				var trace: Array = []
				for item in path:
					if not command(c,item.duplicate(true)):break
					if item.action in ["fire","reload","emergency"]:
						trace.append({"action":item.action,"phase":c.model.s.phase,"heat":c.model.s.heat,"streak":c.model.s.sustained_attacks,"turns":c.model.s.turns,"detail":c.model.s.history.back().detail})
				var solved: bool = c.s.phase == "reward"
				battles.append({"gun":gun,"seed":seed_value,"node":c.s.node,"core":core,"solved":solved,"wider_search":wider,"start":before,"end":c.model.s.duplicate(true),"trace":trace,"path":path})
				print("EARLY B1 ",gun," seed=",seed_value," combat=",cleared+1," solved=",solved," turns=",int(c.model.s.turns)-int(before.turns))
				if not solved:break
				cleared += 1
			"reward":
				var options: Array = c.part_rewards()
				var selected := core if options.has(core) else "skip" if c.boss_loot() else "credits"
				if not command(c,{"action":"reward","id":selected}):break
			"shop","supply","event","bypass":
				if c.s.phase in ["supply","event"] and not c.s.resolved:
					if not command(c,{"action":"resolve","id":"skip"}):break
				if not command(c,{"action":"leave"}):break
			_:break
		await process_frame
	runs.append({"gun":gun,"seed":seed_value,"core":core,"cleared":cleared,"phase":c.s.phase,"commands":commands.duplicate(true)})
	# A bounded search miss is recorded as unresolved reachability, never impossibility.
	check(cleared == 5 or c.s.phase == "gate", "first gate or five early combats reached " + gun + "/" + str(seed_value))
	FileAccess.open(output.path_join("early_campaigns.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"runs":runs,"battles":battles,"note":"Real fresh campaigns; first route option; legal core rewards only, other rewards credits, services skipped; no cooling acquired. Bounded search reads hidden draws/RNG, so these are reachability checks, not player win rates."},"  "))

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/playtest_revision_20261026/"):quit(2);return
	output = OS.get_environment("QA_OUTPUT_DIR")
	for seed_value in [731042,17]:
		for gun in Ammo.GUNS:await probe(gun,seed_value)
	print("PLAYTEST REVISION SUSTAINED PROBE COMPLETE checks=%d failures=%d combats=%d" % [checks,failures.size(),battles.size()])
	quit(0 if failures.is_empty() else 1)
