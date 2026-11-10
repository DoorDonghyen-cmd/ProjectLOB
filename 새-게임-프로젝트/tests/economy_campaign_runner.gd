extends "res://tests/central_live_balance_runner.gd"
## Instrument the actual five-region campaign. Search sees future draws/RNG.
var outfit := "carrier"
var heat_rule := 1
var acquisition_events: Array = []
var encounter_metrics: Dictionary = {}
var unresolved: Array = []
var initial_state: Dictionary = {}

func check(condition: bool, label: String) -> bool:
	if label.begins_with("fresh earned route ") and not condition:
		unresolved.append(label)
		return false
	return super.check(condition,label)

func command(c, item: Dictionary) -> bool:
	var kind := str(item.action)
	var before: Dictionary = {}
	if kind in ["reward","buy","resolve","gate","equip"]:
		before = {"credits":c.s.credits,"deck":c.model.s.deck.duplicate(),"parts":c.s.equipped_parts.duplicate(),"owned_parts":c.s.parts.duplicate(),"gate_mods":c.model.s.get("gate_mods",{}).duplicate()}
	var accepted := super.command(c,item)
	if not accepted:return false
	if kind == "enter" and c.s.phase == "combat":
		initial_state = c.model.s.duplicate(true)
		encounter_metrics = {"forced_reloads":0,"forced_turns":0,"normal_reloads":0,"emergency_packs":0,"emergency_turns":0,"heat_peak":0,"sustained_heat":0,"fired":0,"discarded_unfired":0,"traces":[]}
	if kind in ["fire","reload","emergency"]:
		# before_save is captured by the inherited roundtrip BEFORE reward saves
		# reconcile piles, so spent/generated/remaining ammunition stays meaningful.
		var detail: Dictionary = before_save.history.back().detail
		if kind == "fire":
			var forced: Dictionary = detail.get("forced_reload",{})
			encounter_metrics.forced_reloads += 0 if forced.is_empty() else 1
			encounter_metrics.forced_turns += int(forced.get("cost",0))
			encounter_metrics.heat_peak = maxi(encounter_metrics.heat_peak,int(detail.get("heat_peak",0)))
			for shot in detail.get("results",[]):
				encounter_metrics.fired += 1
				encounter_metrics.sustained_heat += int(shot.get("sustained_heat",0))
		elif kind == "reload":encounter_metrics.normal_reloads += 1
		else:
			encounter_metrics.emergency_packs += 1
			encounter_metrics.emergency_turns += int(detail.get("cost",0))
		encounter_metrics.traces.append({"action":kind,"turn":before_save.turns,"heat":before_save.heat,"phase":before_save.phase,"shots":before_save.shots,"discarded":before_save.discard.size(),"generated":c.model.Reserve.generated_count(before_save),"remaining":c.model.Reserve.remaining(before_save),"detail":detail.duplicate(true)})
	if not before.is_empty():
		acquisition_events.append({"gun":run_gun,"seed":run_seed,"outfit":outfit,"region":int(c.s.region)+1,"node":c.s.node,"command":item.duplicate(true),"before":before,"after":{"credits":c.s.credits,"deck":c.model.s.deck.duplicate(),"parts":c.s.equipped_parts.duplicate(),"owned_parts":c.s.parts.duplicate(),"gate_mods":c.model.s.get("gate_mods",{}).duplicate()}})
	return true

func write_report() -> void:
	if not battles.is_empty() and not battles.back().has("outfit"):
		var row: Dictionary = battles.back()
		row.outfit = outfit;row.heat_rule = heat_rule
		row.metrics = encounter_metrics.duplicate(true)
		row.hand_capacity = Ammo.hand_capacity(initial_state)
		row.carry_limit = Campaign.Model.Reserve.limit(initial_state)
		row.start_ammo = initial_state.deck.size()
		row.bag_upgrades = initial_state.get("bag_upgrades",0)
		if row.solved:
			row.generated = Campaign.Model.Reserve.generated_count(before_save)
			row.remaining = Campaign.Model.Reserve.remaining(before_save)
			row.used = before_save.discard.size()
			row.metrics.discarded_unfired = row.used - row.metrics.fired
			row.end_engine = before_save.engine.duplicate(true)
			check(row.start_ammo + row.generated == row.used + row.remaining,"earned encounter ammo conservation")
		else:
			row.turns = 0;row.used = 0;row.remaining = row.start_ammo;row.generated = 0
			row.note = "No winning path within bounded search; combat was not played. This is not proof of impossibility."
	var file = FileAccess.open(output.path_join("balance.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"note":"Actual earned campaigns and atomic restore after every accepted command. Endpoints identify fresh runs or earned-checkpoint continuations; recorded commands identify preparation. Search sees future draws/RNG. Reachability, not human win rate or optimality.","checks":checks,"failures":failures,"unresolved":unresolved,"battles":battles,"endpoints":endpoints,"acquisitions":acquisition_events},"  "));file.close()

func _run() -> void:
	var user_path := ProjectSettings.globalize_path("user://").replace("\\","/")
	if not user_path.contains("/qa_runtime/economy_20261029/") and not user_path.contains("/qa_runtime/late_growth_20261030/"):quit(2);return
	output = OS.get_environment("QA_OUTPUT_DIR")
	solver = preload("res://tests/central_combat_solver.gd").new();solver.candidate_limit = 700
	load_previous_paths()
	route_policy = OS.get_environment("QA_ROUTE");acquisition_policy = OS.get_environment("QA_ACQUISITION")
	heat_rule = int(OS.get_environment("QA_HEAT_RULE"))
	for outfit_id in OS.get_environment("QA_OUTFITS").split(","):
		outfit = outfit_id
		for seed_text in OS.get_environment("QA_SEEDS").split(","):
			for gun in OS.get_environment("QA_GUNS").split(","):
				run_gun = gun;run_seed = int(seed_text);commands = []
				preferred_core = {"single":"siege_drive","burst":"volley_drive","scatter":"volley_drive","heavy":"thermal_drive","amplifier":"siege_drive"}[gun]
				var c = Campaign.new();c.start(gun,run_seed,0,"balanced",3,outfit)
				if heat_rule == 0:c.s.sustained_version = 0;c.model.s.sustained_version = 0
				check(c.model.s.sustained_version == heat_rule and c.s.inventory_version == 1 and c.s.emergency_version == 1,"requested live rule versions")
				print("ECONOMY START ",gun," seed=",run_seed," outfit=",outfit," policy=",acquisition_policy," route=",route_policy," heat=",heat_rule)
				var won: bool = await play_run(c)
				endpoints.append({"gun":gun,"seed":run_seed,"outfit":outfit,"acquisition":acquisition_policy,"route":route_policy,"heat_rule":heat_rule,"won":won,"region":int(c.s.region)+1,"phase":c.s.phase,"deck":c.model.s.deck,"parts":c.s.equipped_parts,"credits":c.s.credits,"commands":commands.duplicate(true)})
				print("ECONOMY END ",gun," seed=",run_seed," outfit=",outfit," won=",won," region=",int(c.s.region)+1)
				write_report()
	print("ECONOMY CAMPAIGN COMPLETE checks=%d failures=%d unresolved=%d" % [checks,failures.size(),unresolved.size()])
	quit(0 if failures.is_empty() else 1)
