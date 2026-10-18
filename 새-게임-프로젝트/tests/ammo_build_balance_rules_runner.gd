extends "res://tests/heat_rules_runner.gd"
const Discovery = preload("res://redesign/ammo_discovery.gd")
var comparisons: Array = []

func probe(label: String, order: Array, rows: Array, parts: Array = [], heat: int = 0) -> Dictionary:
	var m = fixture(order, rows)
	# Equal deck size and known filler: this measures reservation, not lucky draws.
	m.s.deck=order.duplicate()
	while m.s.deck.size()<12: m.s.deck.append("basic")
	m.s.draw=m.s.deck.duplicate()
	for id in m.s.hand: m.s.draw.erase(id)
	m.s.equipped_parts=parts.duplicate();m.s.heat=heat
	for id in parts:
		if Model.Engines.IDS.has(id): m.s.engine.levels[id]=4
	for enemy in m.s.enemies:
		if enemy.kind=="spitter": enemy.ranged_left=1
	var shots := fire(m,order)
	var damage := 0
	var kills := 0
	for enemy in m.s.enemies:
		damage+=int(enemy.max_hp)-int(enemy.hp)
		if enemy.hp==0: kills+=1
	var result := {"label":label,"order":order,"parts":parts,"initial_heat":heat,"damage":damage,"kills":kills,"heat":m.s.heat,"turns":m.s.turns,"launches":m.s.projectile_serial,"reserved":m.s.prepared.duplicate(),"shots":shots.size(),"interrupted":0,"burn":0}
	for shot in shots: result.interrupted+=int(shot.get("interrupted",0))
	for enemy in m.s.enemies: result.burn+=int(enemy.get("burn",0))
	if m.s.phase not in ["reward","won","lost"]:
		check(m.reload_magazine(),"probe legal reload")
		result.next_hand=m.s.hand.duplicate()
		check(Model.new().restore_state(JSON.parse_string(JSON.stringify(m.s))),"probe reload restores owned inventory")
	comparisons.append(result)
	return result

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/ammo_build_balance/"): quit(1);return
	var blocked_rows := [["runner",4,0,2,24],["runner",4,0,2,27],["spitter",6,0,0,31]]
	var blocked := probe("차단/후열 원거리",["disrupt"],blocked_rows)
	check(blocked.interrupted==0 and blocked.launches==1,"disruption cannot reach shooter behind front enemy")
	var delayed := probe("차단/노출된 강한 원거리",["disrupt","basic"],[["spitter",100,0,0,30]])
	var attacked := probe("증폭/노출된 강한 원거리",["charge","basic"],[["spitter",100,0,0,30]])
	check(delayed.launches==0 and attacked.launches==1,"disruption has a real but narrow survival benefit")
	var held := probe("예약/연쇄",["charge","prepare","pierce"],[["wall",100,0,1,30]],["volley_drive"])
	var extra := probe("추가 공격/연쇄",["basic","charge","pierce"],[["wall",100,0,1,30]],["volley_drive"])
	check(held.reserved==["pierce"] and held.next_hand.has("pierce"),"reservation actually fixes a future draw")
	check(held.damage<extra.damage and held.heat>extra.heat,"reservation trades immediate damage and heat for future certainty")
	var hot := probe("예약/잔열5",["charge","prepare","pierce"],[["wall",100,0,1,30]],["thermal_drive"],5)
	var cooled := probe("냉각/잔열5",["cool","charge","pierce"],[["wall",100,0,1,30]],["thermal_drive"],5)
	check(hot.damage==0 and cooled.damage>0 and hot.turns>cooled.turns,"reservation can spend the shot window that cooling preserves")
	probe("차단/돌파",["disrupt","basic"],[["spitter",16,0,0,30]],["siege_drive"])
	probe("증폭/돌파",["charge","basic"],[["spitter",16,0,0,30]],["siege_drive"])
	probe("불씨/화상 지원",["bore","spread"],[["wall",100,0,1,30],["runner",100,0,1,33]],["coil","inferno"])
	probe("화상/소이만",["bore"],[["wall",100,0,1,30],["runner",100,0,1,33]],["coil","inferno"])
	probe("전격/파츠 없음",["arc"],[["runner",100,0,1,30],["runner",100,0,1,32],["runner",100,0,1,34]])
	probe("전격/전이 파츠",["arc"],[["runner",100,0,1,30],["runner",100,0,1,32],["runner",100,0,1,34]],["capacitor","arc_splitter"])
	var stripped:=probe("파쇄/장갑4 연타",["shatter","precise"],[["wall",100,4,1,30]])
	var unstripped:=probe("기본/장갑4 연타",["basic","precise"],[["wall",100,4,1,30]])
	check(stripped.damage>unstripped.damage,"zero-damage shatter increases the same armored volley's damage")
	# Every new candidate keeps stage gates; both passive roles are preserved for old data.
	var observed: Array=[]
	for region in range(5):
		for depth in [1,2,3,5,8]:
			var node := {"id":region*1000+depth*100+1,"region":region,"floor":depth,"kind":"shop","elite":false}
			check(Data.ammo_pool(node,0)==Data._legacy_ammo_pool(node),"legacy stage pool unchanged")
			check(not Data.ammo_pool(node,1).any(func(id):return Discovery.PAUSED_AMMO.has(id)),"paused cards absent from new stage pool")
			for seed_value in range(20):
				var parts: Array=["coil"] if seed_value%2==0 else ["volley_drive","capacitor"]
				var choices := Data.rewards(node,seed_value,["basic","charge"],parts,1)
				check(choices.size()==2 and Ammo.source_id(choices[0])!=Ammo.source_id(choices[1]),"new rewards distinct")
				check(not choices.any(func(id):return Discovery.PAUSED_AMMO.has(Ammo.source_id(id))),"new reward excludes paused variants")
				if depth>1: check(Discovery.fitting(Data.ammo_pool(node,1),parts).has(choices[0]),"equipped module or core contributes a reward")
				for id in choices:
					if not observed.has(Ammo.source_id(id)): observed.append(Ammo.source_id(id))
				var stock := Data.offers(node,seed_value,0,"single",parts,[],[],parts,1)
				check(not stock.any(func(o):return o.id in ["prepare","disrupt","prepare_c","disrupt_c","indexer"]),"new shop excludes paused cards and orphan module")
				check(stock==Data.offers(node,seed_value,0,"single",parts,[],[],parts,1),"new stock reproducible")
	check(observed.size()==17,"all seventeen active tactical families remain discoverable")
	check(Discovery.fitting(["arc","pierce"],["capacitor"])==["arc"],"electric module matters without a growth core")
	check(Discovery.fitting(["arc","precise"],["volley_drive","capacitor"])==["arc","precise"],"hybrid module and core both remain candidates")
	check(not Discovery.modules(Data.eligible_parts("single"),["thermal_drive"]).has("ember_core"),"incompatible second core is not a module synergy")
	# Version, pending inventory and retired owned cards survive atomic restore.
	var c=Campaign.new();c.start("single",731042)
	check(c.s.discovery_version==Discovery.VERSION,"new run selects acquisition revision")
	check(c.enter(int(c.choices()[0].id)),"enter live opening")
	var snapshot := {"campaign":c.s.duplicate(true),"combat":c.model.s.duplicate(true),"profile":c.profile.duplicate(true)}
	var restored=Campaign.new()
	check(restored.restore_state(JSON.parse_string(JSON.stringify(snapshot))) and restored.s.discovery_version==Discovery.VERSION,"new marker round trips")
	snapshot.campaign.erase("discovery_version")
	check(restored.restore_state(JSON.parse_string(JSON.stringify(snapshot))) and restored.s.discovery_version==0,"missing marker preserves old discovery rules")
	for bad in [-1,Discovery.VERSION+1,0.5,"1",true]:
		snapshot.campaign.discovery_version=bad
		check(not Campaign.new().restore_state(snapshot),"invalid discovery version rejected")
	var legacy=Campaign.new();legacy.start("burst",731042,0,"balanced",1)
	legacy.s.discovery_version=0
	legacy.s.floor=3;legacy.s.node=301;legacy.s.visited=[101,201,301]
	check(legacy.enter(401),"enter a legacy shop")
	legacy.model.s.deck=["prepare","prepare","disrupt","disrupt","basic","basic","pierce","charge"]
	legacy.s.parts=["indexer"];legacy.s.equipped_parts=["indexer"]
	legacy.model.s.equipped_parts=["indexer"]
	legacy.model.begin_encounter()
	legacy.s.offers=[{"id":"prepare_c","type":"ammo","price":24,"sold":false},{"id":"coil","type":"part","price":30,"sold":false}]
	var legacy_snapshot: Dictionary={"campaign":legacy.s.duplicate(true),"combat":legacy.model.s.duplicate(true),"profile":legacy.profile.duplicate(true)}
	legacy_snapshot.campaign.erase("discovery_version")
	check(restored.restore_state(JSON.parse_string(JSON.stringify(legacy_snapshot))),"legacy paused ownership and pending shop restore")
	check(restored.model.s.deck==legacy.model.s.deck and restored.s.equipped_parts==["indexer"],"owned cards and equipped retired module preserved")
	check(JSON.parse_string(JSON.stringify(restored.s.offers))==JSON.parse_string(JSON.stringify(legacy.s.offers)),"pending shop offers preserved across JSON numeric types")
	for family in ["prepare","disrupt"]:
		check(Ammo.COMPRESSIONS.has(family) and Ammo.AMMO.has(Ammo.compressed_id(family)),"owned paused cards still have compression definitions")
	# Captured from the untouched 2026-10-17 implementation before discovery revision 1.
	var golden: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/ammo_discovery_legacy.json"))
	check(golden.size()==30,"legacy fixture contains thirty original seeds")
	for sample in golden:
		var seed_value:=int(sample.seed)
		var node := {"id":501,"region":0,"floor":5,"kind":"shop","elite":false}
		check(Data.rewards(node,seed_value,["basic","prepare"],["volley_drive"],0)==sample.rewards,"legacy rewards exactly preserved")
		check(JSON.parse_string(JSON.stringify(Data.offers(node,seed_value,1,"single",[],[],[],["thermal_drive"],0)))==sample.offers,"legacy stock exactly preserved across JSON numeric types")
	var file=FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("comparisons.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"comparisons":comparisons,"observed":observed},"  "));file.close()
	print("AMMO BUILD BALANCE RULES COMPLETE checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
