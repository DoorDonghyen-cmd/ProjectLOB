extends "res://tests/ammo_expansion_rules_runner.gd"

func reactor(ids: Array, heat: int = 13) -> RefCounted:
	var model = fixture(ids, [["runner",200,0,1,80]], "heavy")
	model.s.heat = heat
	return model

func execute(model: RefCounted, ids: Array) -> Dictionary:
	for id in Ammo.loading_order(ids): check(model.load_round(id), "load " + str(id))
	var snapshot := JSON.stringify(model.s)
	var prediction := Forecast.analyze(model.s, true, true)
	check(JSON.stringify(model.s)==snapshot,"prediction preserves state and random stream")
	check(model.confirm() and model.fire(), "confirm and fire")
	var detail: Dictionary = model.s.history.back().detail
	check(prediction.enemies==model.s.enemies and prediction.projectiles==model.s.projectiles,"actual targets match forecast")
	check(prediction.remaining==model.s.magazine and prediction.phase==model.s.phase,"remaining cards and phase match forecast")
	check(int(prediction.heat.end_max)==int(model.s.heat),"final heat matches forecast")
	check(int(prediction.heat.forced_cost_max)==int(detail.forced_reload.get("cost",0)),"forced cost matches forecast")
	check(prediction.shots==detail.results.map(func(shot):var copy:Dictionary=shot.duplicate(true);copy.action=0;return copy),"shot receipts match forecast")
	var restored = Model.new()
	check(restored.restore_state(JSON.parse_string(JSON.stringify(model.s))),"post-action state restores")
	return detail

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/art_cohesion/"): quit(1); return
	var model=reactor(["basic","basic","basic"])
	check(model.capacity()==6 and Ammo.heat_limit(model.s)==14 and Ammo.reload_cooling(model.s)==8 and model.base_reload_cost()==2,"new Reactor stats")
	var detail:=execute(model,["basic","basic","basic"])
	check(detail.results.size()==2 and detail.results[0].get("overdrive_next",false) and detail.results[1].overdrive,"one extra card after threshold")
	check(detail.forced_reload.cost==4 and model.s.turns==5 and model.s.heat==0,"forced reload: base2 + heat1 + overdrive1, plus firing turn")
	model=reactor(["basic","cool","basic"])
	detail=execute(model,["basic","cool","basic"])
	check(detail.results.size()==2 and detail.results[1].cooled==3,"cooling card uses exactly one extra slot")
	check(detail.forced_reload.is_empty() and model.s.magazine==["basic"] and model.s.heat==11,"cooling saves remaining card without automatic reload")
	check(model.fire() and model.s.history.back().detail.results.size()==1,"remaining card fires on a new input")
	model=reactor(["basic"])
	detail=execute(model,["basic"])
	check(not detail.overdrive and detail.forced_reload.cost==3,"no available card means no extra surcharge")
	model=reactor(["basic","basic"])
	model.s.enemies[0].hp=1
	detail=execute(model,["basic","basic"])
	check(detail.results.size()==1 and detail.forced_reload.is_empty() and model.s.phase=="reward","last kill has no redundant overdrive or reload")
	model=reactor(["basic","basic","basic"],11)
	model.s.weapon_version=0
	check(model.capacity()==4 and Ammo.heat_limit(model.s)==13 and Ammo.reload_cooling(model.s)==6 and model.base_reload_cost()==1,"legacy heavy stats retained")
	check(Ammo.burn_damage(model.s)==4,"legacy elemental specialization retained")
	var old:Dictionary=model.s.duplicate(true);old.erase("weapon_version")
	var restore=Model.new()
	check(restore.restore_state(old) and not Ammo.reactor_enabled(restore.s),"missing weapon version remains legacy")
	detail=execute(model,["basic","basic","basic"])
	check(detail.results.size()==2 and not detail.overdrive and detail.forced_reload.cost==2,"legacy heat stops immediately")
	model=reactor(["basic","basic","basic"])
	model.s.equipped_parts=["loader"]
	detail=execute(model,["basic","basic","basic"])
	check(detail.forced_reload.cost==model.base_reload_cost()+2,"reload modifiers preserve overdrive surcharge")
	model=reactor(["basic","basic","basic"],0)
	detail=execute(model,["basic","basic","basic"])
	check(detail.results.size()==3 and not detail.overdrive and detail.forced_reload.is_empty(),"normal chain unchanged below threshold")
	model=reactor(["basic","precise","basic"])
	detail=execute(model,["basic","precise","basic"])
	check(detail.results.size()==2 and detail.results[1].overdrive and detail.results[1].hits==2,"overdrive grants one whole multihit card, not one hit")
	model=reactor(["basic","charge","basic"])
	detail=execute(model,["basic","charge","basic"])
	check(detail.results.size()==2 and detail.results[1].overdrive and detail.results[1].damage==0,"support card consumes overdrive without invented damage")
	model=reactor(["basic","basic","basic"])
	model.s.enemies[0].hp=1
	model.s.reinforcements=[Data._enemy(["runner",200,0,1,80])]
	model.s.encounter_total=2
	detail=execute(model,["basic","basic","basic"])
	check(detail.results.size()==1 and not detail.overdrive and detail.forced_reload.cost==3,"kill with waiting reinforcement still pays ordinary overheat cost")
	check(model.alive_count()>0 and model.s.phase=="plan","reinforcement prevents false victory")
	model=reactor(["basic","basic","basic"])
	model.s.equipped_parts=["reclaimer"]
	model.s.enemies=[Data._enemy(["runner",1,0,1,75]),Data._enemy(["runner",200,0,1,80])]
	model.s.encounter_total=2;model.s.deployed=2;model.assign_opening_lanes()
	detail=execute(model,["basic","basic","basic"])
	check(detail.results[0].kill_cooled>0 and not detail.results[0].get("overdrive_next",false),"kill cooling resolves before deciding overdrive")
	model=reactor(["basic","basic","basic"])
	model.s.enemies[0].kind="absorber";model.s.enemies[0].barrier=3;model.s.enemies[0].barrier_max=3
	detail=execute(model,["basic","basic","basic"])
	check(detail.results.size()==2 and detail.results[1].overdrive,"barrier does not cancel overdrive or heat")
	var current=Campaign.new();current.start("heavy",918264)
	check(current.save("user://reactor_current.json")==OK,"isolated campaign saves")
	var loaded=Campaign.new()
	check(loaded.restore("user://reactor_current.json") and Ammo.reactor_enabled(loaded.model.s) and loaded.model.capacity()==6,"new weapon version persists across campaign restore")
	var invalid:Dictionary=loaded.model.s.duplicate(true);invalid.weapon_version=2
	check(not Model.new().restore_state(invalid),"unknown weapon rules are rejected without reinterpretation")
	print("REACTOR RULES COMPLETE checks=",checks," failures=",failures)
	quit(1 if failures else 0)
