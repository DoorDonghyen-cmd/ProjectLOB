extends "res://tests/reactor_rules_runner.gd"
## Boundary scenarios are synthetic; all transitions use production commands.
var samples: Array = []

func spent(gun: String = "single", outfit: String = "work", seed_value: int = 731042, supports: int = 0):
	var c=Campaign.new();c.start(gun,seed_value,0,"balanced",3,outfit)
	for i in range(supports): c.model.s.deck[i]="charge"
	check(c.enter(int(c.choices()[0].id)),"real combat entry")
	var m=c.model
	m.s.enemies=[Data._enemy(["wall",1000,8,1,150])];m.assign_opening_lanes()
	m.s.reinforcements=[];m.s.encounter_total=1;m.s.deployed=1
	m.s.hand=[];m.s.draw=[];m.s.discard=m.s.deck.duplicate()
	for i in range(supports):
		m.s.discard.erase("charge")
		if m.s.hand.size()<Ammo.hand_capacity(m.s):m.s.hand.append("charge")
		else:m.s.draw.append("charge")
	return c

func roundtrip(c) -> void:
	check(c.save("user://emergency.json")==OK,"atomic campaign save")
	var copy=Campaign.new()
	check(copy.restore("user://emergency.json"),"campaign restores")
	check(JSON.parse_string(JSON.stringify(copy.model.s))==JSON.parse_string(JSON.stringify(c.model.s)),"combat and generated ownership exact")
	check(JSON.parse_string(JSON.stringify(copy.s))==JSON.parse_string(JSON.stringify(c.s)),"campaign exact")

func resupply(m) -> Dictionary:
	var snapshot:=JSON.stringify(m.s)
	var prediction:=Forecast.emergency_now(m.s)
	check(JSON.stringify(m.s)==snapshot,"resupply forecast preserves state and RNG")
	var turns:int=m.s.turns
	check(m.emergency_resupply(),"legal emergency supply")
	check(prediction.phase==m.s.phase and prediction.enemies==m.s.enemies and prediction.projectiles==m.s.projectiles,"supply forecast exact outcome")
	check(prediction.turns==m.s.turns-turns and prediction.cost==m.last_reload_detail.cost and prediction.temperature_after==m.s.heat,"cost and heat exact")
	check(Model.new().restore_state(JSON.parse_string(JSON.stringify(m.s))),"post supply valid state")
	return m.last_reload_detail

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/playtest_revision_20261026/"):quit(2);return
	for gun in Ammo.GUNS:
		for outfit in Model.Reserve.CARRY_LIMITS:
			for seed_value in [731042,17]:
				var c=spent(gun,outfit,seed_value,10);var m=c.model
				var deck:Array=m.s.deck.duplicate();var rng:String=m.s.rng_state
				check(m.can_emergency_resupply(),"support-only hand and reserve eligible")
				var detail:=resupply(m)
				check(detail.cost==m.base_reload_cost()+1 and detail.granted==4,"first supply base +1 / four rounds")
				check(m.s.hand.count("basic_p2")==4 and m.s.hand.size()<=Ammo.hand_capacity(m.s),"four rounds fit every outfit")
				check((m.s.hand+m.s.draw).count("charge")==10,"uninserted supports conserved")
				check(m.s.deck==deck and m.s.rng_state==rng,"supply does not change deck or random stream")
				check(Model.Reserve.remaining(m.s)==14,"remaining count includes generated rounds")
				roundtrip(c)
				var stable:=JSON.stringify(m.s)
				check(not m.emergency_resupply() and JSON.stringify(m.s)==stable,"cannot farm supply while attack remains")
	# Repeat costs and conservation after actual shots, including high-armor damage.
	for gun in Ammo.GUNS:
		var c=spent(gun);var m=c.model;var damage:=0;var costs:Array=[]
		for use in range(3):
			var detail:=resupply(m);costs.append(detail.cost)
			check(detail.cost==m.base_reload_cost()+use+1,"escalating cost")
			var hp:int=m.s.enemies[0].hp
			for step in range(20):
				if m.can_emergency_resupply():break
				if m.s.phase=="ready" and m.s.magazine.is_empty():check(m.reload_magazine(),"refill remaining generated hand")
				if m.s.phase=="plan":
					for id in m.s.hand.duplicate():
						if m.can_load(id):check(m.load_round(id),"load generated round "+gun)
					check(m.confirm(),"confirm generated magazine "+gun)
				var prediction:=Forecast.analyze(m.s,true)
				check(m.fire(),"fire generated rounds")
				if gun!="scatter":check(prediction.phase==m.s.phase,"empty attack result matches forecast "+gun)
			damage+=hp-int(m.s.enemies[0].hp)
			check(m.can_emergency_resupply() and m.s.phase!="lost","empty attack no automatic defeat")
			roundtrip(c)
		check(damage>0 and m.s.deck==Model.Reserve.start_deck(),"armor can be damaged, inventory not enlarged")
		samples.append({"gun":gun,"scenario":"three emergency packs vs armor8 HP1000 at150m","costs":costs,"damage":damage,"turns":m.s.turns,"distance":m.s.enemies[0].distance})
		m.begin_encounter()
		check(m.s.emergency_uses==0 and m.s.hand.size()+m.s.draw.size()==20 and Model.Reserve.remaining(m.s)==20,"next combat clears generated rounds and cost")
	# Any attack in any live zone blocks supply. Spent specials never return.
	for gun in Ammo.GUNS:
		var rescue=spent(gun).model
		rescue.s.enemies[0].hp=2;rescue.s.enemies[0].def=6;rescue.s.enemies[0].distance=20
		resupply(rescue)
		for id in rescue.s.hand.duplicate():
			if rescue.can_load(id):check(rescue.load_round(id),"rescue load")
		check(rescue.confirm(),"rescue confirm")
		for i in range(4):
			if rescue.s.phase in ["reward","won","lost"]:break
			check(rescue.fire(),"rescue fire")
		check(rescue.s.phase=="reward","emergency rounds can finish armored survivor "+gun)
	for part in ["loader","afterburner"]:
		var modified=spent("heavy").model;modified.s.equipped_parts=[part]
		var price:int=modified.reload_cost()+1
		check(resupply(modified).cost==price,"part reload modifier retained "+part)
	for zone in ["hand","draw","plan","magazine"]:
		var m=spent().model
		m.s.discard.erase("basic_p2");m.s.hand.append("basic_p2")
		if zone=="draw":m.s.hand.clear();m.s.draw.append("basic_p2")
		elif zone in ["plan","magazine"]:
			check(m.load_round("basic_p2"),"attack inserted")
			if zone=="magazine":check(m.confirm(),"attack confirmed")
		var before:=JSON.stringify(m.s)
		check(not m.emergency_resupply() and before==JSON.stringify(m.s),"attack in "+zone+" prevents supply")
	# Loaded support ejection follows normal reload; unused supports are retained.
	for ready in [false,true]:
		var m=spent("heavy","work",17,6).model
		check(m.load_round("charge"),"insert support")
		if ready:check(m.confirm(),"confirm support")
		resupply(m)
		check(m.s.discard.count("charge")==1 and (m.s.hand+m.s.draw).count("charge")==5,"loaded support spent, other supports retained")
	# Burn can win on the first waiting turn. Neither ammo nor cost counter granted.
	var specials=spent().model
	specials.s.deck[-1]="bore";specials.s.deck[-2]="arc"
	specials.s.discard=specials.s.deck.duplicate()
	var spent_pile:Array=specials.s.discard.duplicate()
	resupply(specials)
	check(specials.s.discard==spent_pile and not (specials.s.hand+specials.s.draw).has("bore") and not (specials.s.hand+specials.s.draw).has("arc"),"spent specials never replenished")
	var wave=spent("heavy").model
	wave.s.enemies[0].hp=1;wave.s.enemies[0].burn=1
	wave.s.reinforcements=[Data._enemy(["runner",20,0,1,40])]
	wave.s.reinforcements[0].lane=-1;wave.s.encounter_total=2
	resupply(wave)
	check(wave.s.phase=="plan" and wave.s.deployed==2 and wave.s.hand.count("basic_p2")==4,"burn opens reinforcement during supply without early victory")
	for supply in [false,true]:
		var m=spent().model;m.s.enemies[0].hp=1;m.s.enemies[0].burn=1
		if supply:resupply(m)
		else:check(m.reload_magazine(),"normal cooling wait remains available")
		check(m.s.phase=="reward" and m.s.turns==1 and m.s.emergency_uses==0,"burn wins before supply completes")
	# Final ordinary bullet wins; exhaustion never overrides victory.
	var m=spent().model;m.s.enemies[0].hp=1
	m.s.discard.erase("basic_p2");m.s.hand=["basic_p2"]
	execute(m,["basic_p2"])
	check(m.s.phase=="reward" and not m.can_emergency_resupply(),"last bullet victory first")
	# Contact and ranged shots remain lethal during the paid turns.
	for ranged in [false,true]:
		var c=spent();m=c.model
		if ranged:
			m.s.enemies=[Data._enemy(["spitter",1000,0,0,6])]
			m.assign_opening_lanes()
		else:m.s.enemies[0].distance=1
		resupply(m)
		if ranged and m.s.phase!="lost":
			# Existing ranged shots advance through subsequent waiting turns.
			for i in range(8):
				if m.s.phase=="lost":break
				m.reload_magazine()
		check(m.s.phase=="lost","paid turns can lose to "+("projectile" if ranged else "contact"))
		c.sync_combat();roundtrip(c)
	# Forced Reactor cooling never silently supplies rounds or charges emergency fees.
	m=spent("heavy").model;m.s.heat=13
	m.s.hand=["basic_p2"];m.s.discard.erase("basic_p2")
	var detail:=execute(m,["basic_p2"])
	check(not detail.forced_reload.is_empty() and detail.forced_reload.cost==3,"normal overheat surcharge only")
	check(m.s.emergency_uses==0 and m.can_emergency_resupply(),"explicit supply required after forced reload")
	resupply(m)
	# Field compression is allowed on the new basics and conserves their originals.
	m=spent("heavy").model;resupply(m)
	check(m.field_compress("basic_p2"),"generated basics can use existing field compressor")
	check(Model.new().restore_state(m.s),"compressed generated originals restore")
	check(m.reload_magazine(),"eject compressed supply")
	check(Model.new().restore_state(m.s),"ejected generated originals restore")
	# Corrupt counters, marker mismatch, and fake generated ownership reject.
	var c=spent();resupply(c.model);roundtrip(c)
	var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://emergency.json"))
	for invalid in [-1,0.5,2,"1"]:
		var bad=data.duplicate(true);bad.campaign.emergency_version=invalid;bad.combat.emergency_version=invalid
		check(not Campaign.new().restore_state(bad),"unknown emergency policy rejects")
	for invalid in [-1,0.5,0,2,"1"]:
		var bad=data.duplicate(true);bad.combat.emergency_uses=invalid
		check(not Campaign.new().restore_state(bad),"inconsistent generated counter rejects")
	var bad=data.duplicate(true);bad.campaign.erase("emergency_version")
	check(not Campaign.new().restore_state(bad),"nested policy mismatch rejects")
	bad=data.duplicate(true);bad.combat.deck.append("basic_p2")
	check(not Campaign.new().restore_state(bad),"generated ownership cannot be claimed twice")
	# Continue real archived campaigns without changing the established policy.
	for seed_value in [731042,17]:
		var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../docs/qa/reports/assets/inventory_revision_2026-10-27/won_heavy_%d.json"%seed_value))
		var resumed=Campaign.new();check(resumed.restore_state(old),"archived campaign restores")
		check(not resumed.model.s.has("emergency_version") and JSON.parse_string(JSON.stringify(resumed.model.s))==old.combat,"archived combat unchanged")
	# Old finite reserve still loses at exhaustion; scatter cache distinguishes it.
	m=spent("scatter").model;m.s.hand=["basic_p2"];m.s.discard.erase("basic_p2")
	check(m.load_round("basic_p2"),"scatter final round")
	var new_preview:=Forecast.analyze(m.s,true)
	m.s.erase("emergency_version");m.s.erase("emergency_uses")
	var old_preview:=Forecast.analyze(m.s,true)
	check(new_preview.lost_probability==0 and old_preview.lost_probability==1,"scatter cache separates exhaustion policy")
	check(m.confirm() and m.fire() and m.s.loss_reason=="ammo","legacy exhaustion unchanged")
	var file=FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("rules.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"synthetic_samples":samples},"\t"));file.close()
	print("PLAYTEST REVISION EMERGENCY COMPLETE checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
