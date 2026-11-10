extends "res://tests/central_live_balance_runner.gd"
const Forecast = preload("res://redesign/forecast.gd")
var version := 12
var outfit := "carrier"
var traces: Array = []
var acquisitions: Array = []
var comparisons: Array = []

func command(c, item: Dictionary) -> bool:
	var prediction: Dictionary = {}
	if item.action == "fire":
		var original := JSON.stringify(c.model.s)
		prediction = Forecast.analyze(c.model.s,true,true)
		check(JSON.stringify(c.model.s)==original,"forecast preserves live state and RNG")
	var ok := super.command(c,item)
	if not ok: return false
	if item.action == "fire":
		if c.s.gun != "scatter":
			check(prediction.enemies==before_save.enemies,"shot prediction matches enemies")
			check(prediction.projectiles==before_save.projectiles,"shot prediction matches projectiles")
			check(prediction.phase==before_save.phase,"shot prediction matches phase")
		traces.append(before_save.history.back().duplicate(true))
	elif item.action in ["reload","emergency"]: traces.append(before_save.history.back().duplicate(true))
	elif item.action in ["reward","buy","resolve"]:
		acquisitions.append({"node":c.s.node,"command":item.duplicate(true),"deck":c.model.s.deck.duplicate(),"parts":c.s.equipped_parts.duplicate()})
	return true

func write_report() -> void:
	FileAccess.open(output.path_join("results.json"),FileAccess.WRITE).store_string(JSON.stringify({"note":"Actual commands and earned equipment; bounded search sees draw/RNG. Reachability and action traces, not human fun or optimality.","checks":checks,"failures":failures,"battles":battles,"endpoints":endpoints,"acquisitions":acquisitions,"comparisons":comparisons},"  "))

func probes() -> void:
	solver=preload("res://tests/central_combat_solver.gd").new();solver.candidate_limit=1000
	for gun in Ammo.GUNS:
		for policy in ["immediate","reload_first","short_first"]:
			var c=Campaign.new()
			check(c.restore(ProjectSettings.globalize_path("res://../qa_runtime/combat_rhythm_20261030/matrix_final/combat_%s_731042_v12_carrier_n401.json" % gun)),"probe uses actual earned checkpoint")
			var start: int=c.model.s.turns
			commands=[];traces=[]
			if policy=="reload_first": command(c,{"action":"reload"})
			elif policy=="short_first":
				check(c.model.s.hand.has("basic_p1"),"short shot is actually held")
				command(c,{"action":"load","id":"basic_p1"});command(c,{"action":"confirm"});command(c,{"action":"fire"})
			var path: Array=solver.solve(c.model,8,20)
			for step in path: command(c,step)
			var solved: bool=c.s.phase=="reward"
			check(solved,"timing policy can finish "+gun+"/"+policy)
			comparisons.append({"gun":gun,"policy":policy,"won":solved,"turns":int(before_save.turns)-start,"used":before_save.discard.size(),"commands":commands.duplicate(true),"traces":traces.duplicate(true)})
	# Same real hand, same target and RNG: reverse a support/attack pair only.
	for prefix in ["closed","open"]:
		for order in [["charge","basic_p3"],["basic_p3","charge"]]:
			var c=Campaign.new();check(c.restore(ProjectSettings.globalize_path("res://../qa_runtime/combat_rhythm_20261030/matrix_final/combat_single_731042_v12_carrier_n401.json")),"order probe earned hand")
			if prefix=="open": command(c,{"action":"reload"})
			for id in Ammo.loading_order(order): check(c.model.load_round(id),"pair load is legal")
			check(c.model.confirm(),"pair confirms");command(c,{"action":"fire"})
			comparisons.append({"gun":"single","policy":prefix,"firing_order":order,"remaining_hp":c.model.s.enemies[0].hp,"detail":before_save.history.back().detail})

func rules() -> void:
	var baseline = load(ProjectSettings.globalize_path("res://../qa_runtime/combat_rhythm_20261030/source_before/새-게임-프로젝트/redesign/campaign_content.gd"))
	check(baseline != null,"pre-change content source available")
	for seed_value in [17,731042,931104]:
		for region in range(5):
			for node in Data.nodes(region,seed_value,3):
				if node.kind not in ["combat","boss"]: continue
				var old: Dictionary = Data.encounter_pack(node,seed_value,"single",0,0,11,2)
				check(old==baseline.encounter_pack(node,seed_value,"single",0,0,11,2),"legacy formation matches source snapshot")
				var fresh: Dictionary = Data.encounter_pack(node,seed_value,"single",0,0,12,2)
				var role: String = Data.Rhythm.role(node)
				if role.is_empty(): check(old==fresh,"unaffected opening elite boss and later region identical")
				else:
					check(fresh.reserve.is_empty() and fresh.total<=4,"ordinary first-region fights have no repeated reserve wave")
					var m=Campaign.Model.new();m.start("single",seed_value);m.s.enemies=fresh.active;m.s.reinforcements=fresh.reserve
					m.s.encounter_total=fresh.total;m.s.deployed=fresh.total;m.assign_opening_lanes()
					check(Campaign.Model.new().restore_state(JSON.parse_string(JSON.stringify(m.s))),"authored pack remains a valid combat save")
	for family in ["precise_p2","pierce_p2","bore","push","arc","charge"]:
		var choices: Array = Data.Rhythm.rewards({"region":0,"floor":2,"kind":"combat"},["basic_p1",family],["charge","pierce_p2"])
		check(choices.size()==2 and choices[0]!=choices[1],"two distinct earned partner choices")
		for id in choices: check(Ammo.AMMO.has(id),"partner exists in live content")
	check(Data.Rhythm.rewards({"region":0,"floor":2,"kind":"combat"},["basic_p1","bore"],["bore","cool"])==["bore","push"],"burn keeps damage acquisition with optional push partner")
	var c=Campaign.new();c.start("single",17);check(c.s.roster_version==12,"new run selects rhythm rules")
	c.s.roster_version=11;check(roundtrip(c),"existing run keeps old rule marker")
	check(c.current_nodes().all(func(n):return not n.has("rhythm_role")),"legacy map names and descriptions retained")
	var bad: Dictionary={"campaign":c.s.duplicate(true),"combat":c.model.s.duplicate(true),"profile":c.profile.duplicate(true)}
	bad.campaign.roster_version=13;check(not Campaign.new().restore_state(bad),"future roster marker rejected")

func slice(c) -> bool:
	for iteration in range(130):
		match str(c.s.phase):
			"map":
				var choices: Array=c.choices()
				if not check(not choices.is_empty(),"route stays connected"): return false
				var selected: Dictionary=choices[0]
				# Prefer ordinary combat for pacing, then a reachable shop/workshop.
				for option in choices:
					if option.kind=="shop" or option.get("workshop",false): selected=option
				for option in choices:
					if option.kind=="combat" and not option.get("elite",false): selected=option;break
				if not command(c,{"action":"enter","id":selected.id}): return false
			"combat":
				traces=[]
				var initial: Dictionary=c.model.s.duplicate(true)
				var label := "%s_%d_v%d_%s_n%d" % [run_gun,run_seed,version,outfit,c.s.node]
				snapshot(c,"combat_"+label)
				var path: Array=solver.solve(c.model,4,18)
				if path.is_empty():
					solver.candidate_limit=1500;path=solver.solve(c.model,10,24);solver.candidate_limit=700
				for step in path:
					if not command(c,step): return false
				var solved: bool = not path.is_empty() and c.s.phase=="reward"
				var row := {"gun":run_gun,"seed":run_seed,"version":version,"outfit":outfit,"node":c.s.node,"floor":c.s.floor,"role":Data.Rhythm.role(c.node()) if version>=12 else "legacy","boss":c.node().kind=="boss","solved":solved,"total":initial.encounter_total,"deck":initial.deck,"parts":initial.equipped_parts,"turns":int(before_save.get("turns",0))-int(initial.turns) if solved else 0,"used":before_save.get("discard",[]).size() if solved else 0,"path":path,"traces":traces.duplicate(true)}
				battles.append(row);write_report()
				print("RHYTHM ",label," role=",row.role," total=",row.total," turns=",row.turns," used=",row.used," solved=",solved)
				if not check(solved,"earned first-region combat "+label): return false
			"reward":
				var choice := "credits"
				var parts: Array=c.part_rewards();var ammo: Array=c.reward_options()
				if not parts.is_empty(): choice=preferred_core if parts.has(preferred_core) else str(parts[0])
				elif not ammo.is_empty(): choice=str(ammo[0])
				if not command(c,{"action":"reward","id":choice,"replace":replacement(c,choice)}): return false
			"shop":
				for i in range(c.s.offers.size()):
					var offer: Dictionary=c.s.offers[i]
					if not offer.sold and c.s.credits>=offer.price and (offer.type=="part" or i==0):
						if not command(c,{"action":"buy","id":i,"replace":replacement(c,str(offer.id))}): return false
				if not command(c,{"action":"leave"}): return false
			"supply":
				var ammo: Array=c.reward_options()
				if c.node().get("workshop",false):
					var found: Array=c.workshop_ammo_options();var sources: Array=c.replaceable_basics()
					if not found.is_empty() and not sources.is_empty():
						if not command(c,{"action":"resolve","id":"refit","ammo":found[0],"replace":sources[0]}): return false
					elif not command(c,{"action":"resolve","id":"skip"}): return false
				elif not ammo.is_empty():
					if not command(c,{"action":"resolve","id":"ammo","ammo":ammo[0],"replace":replacement(c,str(ammo[0]))}): return false
				elif not command(c,{"action":"resolve","id":"skip"}): return false
				if not command(c,{"action":"leave"}): return false
			"event":
				if not command(c,{"action":"resolve","id":"skip"}) or not command(c,{"action":"leave"}): return false
			"gate":
				snapshot(c,"gate_"+run_gun+"_v"+str(version)+"_"+str(run_seed)+"_"+outfit)
				if not command(c,{"action":"gate","id":c.gate_options()[0]}) or not command(c,{"action":"gate_depart"}): return false
				return check(c.s.region==1,"first gate connects to unchanged next region")
			_: return false
		await process_frame
	return false

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/combat_rhythm_20261030/"): quit(2);return
	output=OS.get_environment("QA_OUTPUT_DIR")
	if OS.get_environment("QA_RHYTHM_MODE")=="rules": rules()
	elif OS.get_environment("QA_RHYTHM_MODE")=="probe": probes()
	elif OS.get_environment("QA_RHYTHM_MODE")=="continuation":
		solver=preload("res://tests/central_combat_solver.gd").new();solver.candidate_limit=700
		load_previous_paths();acquisition_policy="refit"
		version=int(OS.get_environment("QA_VERSIONS").split(",")[0])
		for gun in OS.get_environment("QA_GUNS").split(","):
			run_gun=gun;run_seed=731042;commands=[]
			preferred_core={"single":"siege_drive","burst":"volley_drive","scatter":"volley_drive","heavy":"thermal_drive","amplifier":"siege_drive"}[gun]
			var c=Campaign.new()
			check(c.restore(ProjectSettings.globalize_path("res://../qa_runtime/combat_rhythm_20261030/matrix_final/gate_%s_v%d_731042_carrier.json" % [gun,version])),"continue earned first gate")
			check(c.s.roster_version==version and c.s.region==0 and c.s.phase=="gate","first gate provenance")
			var won: bool=await play_run(c)
			check(won,"earned equipment reaches ending "+gun)
			endpoints.append({"gun":gun,"seed":run_seed,"version":version,"won":won,"region":c.s.region,"source":"matrix_final/gate_%s_v%d_731042_carrier.json"%[gun,version],"commands":commands.duplicate(true)})
	else:
		solver=preload("res://tests/central_combat_solver.gd").new();solver.candidate_limit=700
		for version_text in OS.get_environment("QA_VERSIONS").split(","):
			version=int(version_text)
			for outfit_id in OS.get_environment("QA_OUTFITS").split(","):
				outfit=outfit_id
				for seed_text in OS.get_environment("QA_SEEDS").split(","):
					for gun in OS.get_environment("QA_GUNS").split(","):
						run_gun=gun;run_seed=int(seed_text);commands=[]
						preferred_core={"single":"siege_drive","burst":"volley_drive","scatter":"volley_drive","heavy":"thermal_drive","amplifier":"siege_drive"}[gun]
						var c=Campaign.new();c.start(gun,run_seed,0,"balanced",3,outfit);c.s.roster_version=version
						var won: bool=await slice(c)
						endpoints.append({"gun":gun,"seed":run_seed,"version":version,"outfit":outfit,"won":won,"region":c.s.region,"commands":commands.duplicate(true)})
	write_report()
	print("COMBAT RHYTHM COMPLETE checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
