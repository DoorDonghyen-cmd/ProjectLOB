extends "res://tests/foundry_campaign_runner.gd"
## Fresh campaigns, earned acquisitions, real commands; search sees future RNG.
var run_seed := 0
var run_gun := ""
var route_policy := "elite"
var acquisition_policy := "first"
var cached_paths: Dictionary = {}

func load_previous_paths() -> void:
	# Recheck old command sequences on the CURRENT model before reuse. A cache
	# miss or rejected command falls back to search; no campaign state is imported.
	for tag in ["first","matrix_731042","matrix_17","matrix_931104","revised_builds_fit_heavy","pressure_fit_heavy","pressure_first","pressure_fit_double","pressure_build","inventory_refit","inventory_four"]:
		var file:String=ProjectSettings.globalize_path("res://../qa_runtime/central_live/balance/")+str(tag)+"/balance.json"
		if not FileAccess.file_exists(file):continue
		var report=JSON.parse_string(FileAccess.get_file_as_string(file))
		if not report is Dictionary:continue
		for battle in report.get("battles",[]):
			if battle.get("solved",false):cached_paths["%s/%d/%d/%s"%[battle.gun,int(battle.seed),int(battle.node),battle.get("acquisition","first")]]=battle.path

func checked_previous_path(c) -> Array:
	if route_policy!="elite":return []
	var sequence:Array=cached_paths.get("%s/%d/%d/%s"%[run_gun,run_seed,c.s.node,acquisition_policy],[])
	if sequence.is_empty() and acquisition_policy=="build":sequence=cached_paths.get("%s/%d/%d/fit"%[run_gun,run_seed,c.s.node],[])
	if sequence.is_empty() and acquisition_policy=="refit":sequence=cached_paths.get("%s/%d/%d/fit"%[run_gun,run_seed,c.s.node],[])
	var trial=solver.clone(c.model)
	var accepted:Array=[]
	for step in sequence:
		var ok:=false
		match str(step.action):
			"load":ok=trial.load_round(str(step.id))
			"confirm":ok=trial.confirm()
			"fire":ok=trial.fire()
			"reload":ok=trial.reload_magazine()
			"emergency":ok=trial.emergency_resupply()
		if not ok:return []
		accepted.append(step.duplicate(true))
		if trial.s.phase in ["reward","won"]:return accepted
		if trial.s.phase=="lost":return []
	return []

func choose_ammo(c, options: Array) -> String:
	if options.is_empty():return ""
	if acquisition_policy=="first":return str(options[0])
	# A public-information choice: avoid filling a heat build with duplicate
	# cooling/transfer utilities. No future draw or future rewards are consulted.
	var allowed:Array=[]
	for id in options:
		var family:String=Data.Ammo.source_id(str(id))
		var count:int=c.model.s.deck.filter(func(held):return Data.Ammo.source_id(str(held))==family).size()
		var limit:=1 if family in ["cool","spread","shatter","disrupt"] else 2
		if count<limit:allowed.append(id)
	for preferred in ["charge_hot","charge_heat","bore","vent","charge","precise","pierce","arc","chase","detonate","bypass","push","cool"]:
		for id in allowed:
			if Data.Ammo.source_id(str(id))==preferred:return str(id)
	return str(allowed[0]) if not allowed.is_empty() else ""

func write_report() -> void:
	var file=FileAccess.open(output.path_join("balance.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"note":"Bounded search sees future draw/RNG. Reachability and resource margins, not human win rate.","checks":checks,"failures":failures,"battles":battles,"endpoints":endpoints},"  "));file.close()

func choose_parts(c) -> bool:
	if acquisition_policy!="build" or run_gun!="heavy":return true
	# Uses owned parts and visible weapon/deck roles only, before room entry.
	# Earlier fit runs chose ammo but kept the first automatically equipped parts.
	var chosen:Array=[]
	for id in ["thermal_drive","sequencer","afterburner","breaker","loader","supply","triad","capacitor","chain_sink","radiator","compression_sink","momentum"]:
		if c.s.parts.has(id) and Data.Ammo.valid_part_set(run_gun,chosen+[id]):chosen.append(id)
		if chosen.size()==5:break
	if chosen==c.s.equipped_parts:return true
	if not c.s.equipped_parts.is_empty() and not command(c,{"action":"equip","id":"none"}):return false
	for id in chosen:
		if not command(c,{"action":"equip","id":id}):return false
	return true

func command(c, item: Dictionary) -> bool:
	if item.action=="enter":
		var accepted:bool=c.enter(int(item.id))
		c.sync_combat()
		if not check(accepted,"legal map entry") or not roundtrip(c):return false
		commands.append(item.duplicate(true));return true
	return super.command(c,item)

func play_run(c) -> bool:
	for iteration in range(500):
		match str(c.s.phase):
			"map":
				if not choose_parts(c):return false
				var choices:Array=c.choices()
				if not check(not choices.is_empty(),"connected map"):return false
				var selected:Dictionary=choices[0]
				for option in choices:
					if option.kind=="shop" or option.get("workshop",false):selected=option
				if route_policy=="elite":
					for option in choices:
						if option.get("elite",false):selected=option
				if not command(c,{"action":"enter","id":selected.id}):return false
			"combat":
				var initial:Dictionary=c.model.s.duplicate(true)
				var region:int=c.s.region
				var label="%s_%d_r%d_n%d"%[run_gun,run_seed,region+1,c.s.node]
				snapshot(c,"combat_"+label)
				var started:=Time.get_ticks_msec()
				var path:Array=checked_previous_path(c)
				var reused:=not path.is_empty()
				if path.is_empty():path=solver.solve(c.model,4,18)
				var wide:=path.is_empty()
				if wide:
					solver.candidate_limit=1800
					path=solver.solve(c.model,12,26)
					solver.candidate_limit=700
				if path.is_empty():
					var extended=preload("res://tests/central_combat_solver.gd").new()
					extended.candidate_limit=1800;path=extended.solve(c.model,12,30)
				var nearest:=1000000
				for step in path:
					if not command(c,step):return false
					for enemy in c.model.s.enemies+c.model.Ranged.active(c.model.s):
						if int(enemy.hp)>0:nearest=mini(nearest,int(enemy.distance))
				var row={"gun":run_gun,"seed":run_seed,"route":route_policy,"region":region+1,"node":c.s.node,"floor":c.s.floor,"elite":c.node().get("elite",false),"boss":c.node().kind=="boss","deck":initial.deck,"parts":initial.equipped_parts,"engine":initial.engine,"gate_mods":initial.get("gate_mods",{}),"total":initial.encounter_total,"solved":not path.is_empty() and c.s.phase=="reward","turns":int(before_save.get("turns",0))-int(initial.turns),"used":before_save.get("discard",[]).size(),"remaining":initial.deck.size()-before_save.get("discard",[]).size(),"margin":nearest if nearest<1000000 else -1,"wider_search":wide,"search_ms":Time.get_ticks_msec()-started,"path":path}
				row.replayed=reused
				row.acquisition=acquisition_policy
				battles.append(row);write_report()
				print("CENTRAL ROUTE ",run_gun," seed=",run_seed," region=",region+1," floor=",c.s.floor," solved=",row.solved," turns=",row.turns," ammo=",row.remaining," margin=",row.margin)
				if not check(row.solved,"fresh earned route "+label):return false
			"reward":
				var choice:="credits"
				var parts:Array=c.part_rewards()
				var ammo:Array=c.reward_options()
				if not parts.is_empty():choice=preferred_core if parts.has(preferred_core) else str(parts[0])
				elif not ammo.is_empty() and (c.first_ammo_reward() or c.boss_loot() or int(c.s.clears)<=3 or int(c.s.clears)%2==0):
					choice=choose_ammo(c,ammo)
					if choice.is_empty():choice="skip" if c.boss_loot() else "credits"
				if choice!="credits" and parts.is_empty() and not c.can_acquire_ammo(choice,replacement(c,choice)):choice="skip"
				if not command(c,{"action":"reward","id":choice,"replace":replacement(c,choice)}):return false
			"gate":
				snapshot(c,"gate_%s_%d_r%d"%[run_gun,run_seed,int(c.s.region)+1])
				var choices:Array=c.gate_options()
				var preferred:="thermal" if run_gun=="heavy" else "chain"
				var selected:=preferred if choices.has(preferred) else "thermal" if choices.has("thermal") else "chain" if choices.has("chain") else "skip"
				if not command(c,{"action":"gate","id":selected}):return false
				if not command(c,{"action":"gate_depart"}):return false
				snapshot(c,"entry_%s_%d_r%d"%[run_gun,run_seed,int(c.s.region)+1])
			"shop":
				for i in range(c.s.offers.size()):
					var offer:Dictionary=c.s.offers[i]
					if offer.sold or int(c.s.credits)<int(offer.price):continue
					if offer.type=="part" or (offer.type=="ammo" and i==0 and not choose_ammo(c,[offer.id]).is_empty() and c.can_acquire_ammo(str(offer.id),replacement(c,str(offer.id)))):
						if not command(c,{"action":"buy","id":i,"replace":replacement(c,str(offer.id))}):return false
				if not command(c,{"action":"leave"}):return false
			"supply":
				if acquisition_policy=="refit" and c.node().get("workshop",false):
					var candidate:=choose_ammo(c,c.workshop_ammo_options())
					var sources:Array=c.replaceable_basics()
					if not candidate.is_empty() and not sources.is_empty() and c.can_acquire_ammo(candidate,sources[0]):
						if not command(c,{"action":"resolve","id":"refit","ammo":candidate,"replace":sources[0]}):return false
					elif not command(c,{"action":"resolve","id":"skip"}):return false
					if not command(c,{"action":"leave"}):return false
					continue
				var options:Array=c.reward_options()
				var ammo:=choose_ammo(c,options)
				if not c.node().get("workshop",false) and not ammo.is_empty() and c.can_acquire_ammo(ammo,replacement(c,ammo)):
					if not command(c,{"action":"resolve","id":"ammo","ammo":ammo,"replace":replacement(c,ammo)}):return false
				elif not command(c,{"action":"resolve","id":"skip"}):return false
				if not command(c,{"action":"leave"}):return false
			"event":
				if not command(c,{"action":"resolve","id":"skip"}) or not command(c,{"action":"leave"}):return false
			"bypass":
				if not command(c,{"action":"leave"}):return false
			"won":
				snapshot(c,"won_%s_%d"%[run_gun,run_seed])
				return check(c.s.region==4 and c.s.settled and c.profile.wins==1,"ending and win awarded exactly once")
			_:return false
		await process_frame
	return false

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/central_live/"):quit(1);return
	output=OS.get_environment("QA_OUTPUT_DIR");solver.candidate_limit=700
	load_previous_paths()
	var guns:=OS.get_environment("QA_GUNS").split(",") if not OS.get_environment("QA_GUNS").is_empty() else PackedStringArray(["single","burst","scatter","heavy","amplifier"])
	var seeds:=OS.get_environment("QA_SEEDS").split(",") if not OS.get_environment("QA_SEEDS").is_empty() else PackedStringArray(["731042","17","931104"])
	if not OS.get_environment("QA_ROUTE").is_empty():route_policy=OS.get_environment("QA_ROUTE")
	if not OS.get_environment("QA_ACQUISITION").is_empty():acquisition_policy=OS.get_environment("QA_ACQUISITION")
	for seed_text in seeds:
		for gun in guns:
			run_seed=int(seed_text);run_gun=gun;commands=[]
			preferred_core={"single":"siege_drive","burst":"volley_drive","scatter":"volley_drive","heavy":"thermal_drive","amplifier":"siege_drive"}[gun]
			var c=Campaign.new();c.start(gun,run_seed,0,"balanced",3,"carrier")
			if not OS.get_environment("QA_COMBAT_REVISION").is_empty():
				c.s.combat_revision=int(OS.get_environment("QA_COMBAT_REVISION"));c.model.s.combat_revision=c.s.combat_revision
			check(c.s.roster_version==11 and c.model.s.weapon_version==1,"fresh current rule versions")
			print("CENTRAL FRESH START ",gun," seed=",run_seed)
			var won:bool=await play_run(c)
			endpoints.append({"gun":gun,"seed":run_seed,"acquisition":acquisition_policy,"won":won,"region":int(c.s.region)+1,"phase":c.s.phase,"deck":c.model.s.deck,"parts":c.s.equipped_parts,"credits":c.s.credits,"commands":commands.duplicate(true)})
			check(won,"full five-region route "+gun+"/"+seed_text);write_report()
	write_report()
	print("CENTRAL LIVE BALANCE COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
