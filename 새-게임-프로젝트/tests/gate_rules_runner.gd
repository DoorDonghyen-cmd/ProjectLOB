extends "res://tests/heat_rules_runner.gd"
const Gates = preload("res://redesign/gate_upgrades.gd")
var evidence: Array = []

func upgraded(ids: Array, mods: Dictionary, rows: Array = [], gun: String = "single"):
	var m = fixture(ids,rows,gun)
	m.s.reserve_version = 1
	m.s.gate_mods = mods
	Gates.begin(m.s)
	return m

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/gate/"):
		quit(1); return
	for gun in Ammo.GUNS:
		for id in ["pierce","precise"]:
			var normal = upgraded([id],{},[["runner",100,0,1,30]],gun)
			var normal_shots := fire(normal,[id])
			var enhanced = upgraded([id],{"thermal":1},[["runner",100,0,1,30]],gun)
			enhanced.s.gate_charge=6
			var shots := fire(enhanced,[id])
			check(shots[0].damage==normal_shots[0].damage+6,"charge once per bullet "+gun+"/"+id)
			check(enhanced.s.gate_charge==0,"charge consumed "+gun)
			evidence.append({"gun":gun,"ammo":id,"normal":normal_shots[0].damage,"charged":shots[0].damage})
	var cooled = upgraded(["pierce"],{"thermal":1})
	cooled.s.heat=7
	check(cooled.reload_magazine() and cooled.s.gate_charge==6,"normal reload caps charge")
	check(cooled.reload_magazine() and cooled.s.gate_charge==0,"empty reload does not stack or keep spent heat")
	var shield = upgraded(["precise"],{"thermal":1},[["absorber",100,0,1,30]])
	shield.s.gate_charge=6
	var shield_base = upgraded(["precise"],{},[["absorber",100,0,1,30]])
	check(fire(shield,["precise"])[0].damage==fire(shield_base,["precise"])[0].damage,"first hit blocked consumes charge without moving it to next hit")
	var support = upgraded(["charge","pierce"],{"thermal":1},[["runner",100,0,1,30]])
	support.s.gate_charge=6
	var support_shots := fire(support,["charge","pierce"])
	check(support_shots[0].gate_charge==0 and support_shots[1].gate_charge==6,"support preserves charged attack")
	var forced = upgraded(["pierce"],{"thermal":1})
	forced.s.heat=Ammo.heat_limit(forced.s)-1
	fire(forced,["pierce"])
	check(forced.s.reloads==1 and forced.s.gate_charge==0,"forced cooling never banks heat")
	var chain = upgraded(["basic_p3","basic_p3","basic_p3"],{"chain":1},[["runner",1,0,1,25],["runner",1,0,1,28],["runner",100,0,1,32]])
	var chain_shots := fire(chain,["basic_p3","basic_p3","basic_p3"])
	check(chain_shots.size()==3 and chain_shots[0].gate_percent==100 and chain_shots[1].gate_percent==125 and chain_shots[2].gate_percent==150,"kills improve following bullets only")
	check(chain.reload_magazine() and Gates.chain_percent(chain.s)==100,"reload resets kill chain")
	var arc = upgraded(["arc"],{"chain":1},[["runner",100,0,1,25],["runner",1,0,1,28]])
	fire(arc,["arc"])
	check(arc.s.gate_chain==0,"secondary arc kill does not raise chain")
	var relay = upgraded(["basic_p5"],{"chain":1},[["runner",1,0,1,25],["runner",1,0,1,28],["runner",100,0,1,32]])
	relay.s.equipped_parts=["siege_drive"]
	fire(relay,["basic_p5"])
	check(relay.s.gate_chain==1,"multi kill relay earns exactly one step")
	var ended = upgraded(["basic_p5"],{"chain":1},[["runner",1,0,1,25]])
	fire(ended,["basic_p5"])
	check(ended.s.gate_chain==0 and ended.s.gate_charge==0,"combat end resets transient bonuses")
	for level in [1,2]:
		var s := {"gate_mods":{"chain":level},"gate_chain":4}
		check(Gates.chain_percent(s)==(175 if level==1 else 200),"chain cap "+str(level))
	# Forecast cache must include charge and chain even with identical cards/heat.
	var scatter = upgraded(["precise"],{"thermal":1,"chain":1},[["runner",40,1,1,25],["runner",60,2,1,28]],"scatter")
	scatter.load_round("precise")
	var cold := Forecast.analyze(scatter.s,true)
	scatter.s.gate_charge=6
	scatter.s.gate_chain=2
	var before := JSON.stringify(scatter.s)
	var warm := Forecast.analyze(scatter.s,true)
	check(JSON.stringify(scatter.s)==before,"scatter branches preserve live runtime state")
	check(warm.shots[0].expected_damage>cold.shots[0].expected_damage,"scatter cache includes gate effects")
	var m = upgraded(["pierce"],{"thermal":1,"chain":1})
	m.s.gate_charge=4
	m.s.gate_chain=2
	var saved=Model.new()
	check(saved.restore_state(JSON.parse_string(JSON.stringify(m.s))),"charged and chained combat restores")
	for key in ["gate_charge","gate_chain"]:
		var invalid=m.s.duplicate(true);invalid[key]=99
		var holder=Model.new();holder.start("single",731042)
		var untouched=JSON.stringify(holder.s)
		check(not holder.restore_state(invalid) and JSON.stringify(holder.s)==untouched,"reject invalid "+key+" atomically")
	# Earned old gate fixture: test legacy preservation, then opt in explicitly for new-rule transaction QA.
	for gun in Ammo.GUNS:
		var c=Campaign.new()
		var path="res://tests/fixtures/foundry_entry_"+gun+".json"
		check(c.restore(path),"earned campaign fixture "+gun)
		check(not c.modern_gates(),"legacy rewards keep their version")
		c.s.gate_version=1;c.s.boss_loot_paid=false;c.model.s.gate_mods={}
		Gates.begin(c.model.s)
		# This fixture is the next map after a legitimately cleared first boss.
		c.s.region=0
		var bosses: Array=c.current_nodes().filter(func(n):return n.kind=="boss")
		c.s.node=bosses[0].id;c.s.floor=bosses[0].floor;c.s.phase="gate";c.s.resolved=false;c.s.boss_loot_paid=true
		check(not c.depart_gate(),"pending choice cannot depart "+gun)
		check(c.save("user://gate_pending.json")==OK,"pending gate saves")
		var pending=Campaign.new()
		check(pending.restore("user://gate_pending.json") and not pending.gate_ready() and pending.gate_options().size()>0,"pending gate resumes choice")
		var immediate=Campaign.new()
		check(immediate.restore("user://gate_pending.json"),"immediate-flow comparison restores")
		check(immediate.gate("thermal"),"immediate-flow upgrade")
		# Original flow advanced before its single save. Compare it with rest + resume.
		immediate._advance_region()
		check(immediate.save("user://gate_immediate.json")==OK,"immediate-flow saves once")
		for choice in ["thermal","chain","production","skip"]:
			var copy=Campaign.new()
			copy.s=c.s.duplicate(true);copy.model.s=c.model.s.duplicate(true);copy.profile=c.profile.duplicate(true)
			if choice=="production":
				var specimens:=Gates.specimens(copy.model.s.deck)
				var basics:=Gates.basics(copy.model.s.deck)
				check(not specimens.is_empty() and basics.size()>=3,"earned deck can produce "+gun)
				if specimens.is_empty() or basics.size()<3: continue
				var id: String=specimens[0]
				var count: int=copy.model.s.deck.count(id)
				var size: int=copy.model.s.deck.size()
				var original=JSON.stringify(copy.model.s)
				check(not copy.gate(choice,id,[basics[0]]) and JSON.stringify(copy.model.s)==original,"invalid production atomic")
				check(copy.gate(choice,id,basics.slice(0,3)),"production applied "+gun)
				check(copy.model.s.deck.size()==size and copy.model.s.deck.count(id)==count+3,"production conserves total and profile")
			elif choice != "skip":
				check(copy.gate(choice),"gate upgrade applied "+gun+"/"+choice)
				check(Gates.level(copy.model.s,choice)==1,"gate changes only selected upgrade")
			else:
				check(copy.gate("skip") and copy.model.s.gate_mods.is_empty(),"skip consumes choice without upgrade")
			check(copy.s.region==0 and copy.gate_ready() and copy.gate_options().is_empty(),"gate waits for explicit departure")
			check(not copy.gate(choice),"cannot repeat claimed reward")
			var deck_before: Array=copy.model.s.deck.duplicate()
			var credits_before: int=copy.s.credits
			check(not copy.reward("skip") and not copy.restore_supply() and not copy.shop_refine("pierce"),"rest does not grant reward or workshop service")
			if not copy.equipped_parts().is_empty():
				var part: String=copy.equipped_parts()[0]
				check(copy.equip(part) and not copy.is_equipped(part),"unequip at gate")
				check(copy.equip(part) and copy.is_equipped(part),"reequip at gate")
			check(copy.s.credits==credits_before and copy.model.s.deck==deck_before,"free part management preserves credits and ammo")
			check(copy.save("user://gate_roundtrip.json")==OK,"campaign saves")
			var restored=Campaign.new()
			check(restored.restore("user://gate_roundtrip.json"),"campaign upgrade restores "+gun+"/"+choice)
			check(restored.gate_ready() and not restored.gate(choice) and not restored.reward("skip"),"restored gate cannot repeat reward")
			check(restored.model.s.deck==deck_before and restored.s.equipped_parts==copy.s.equipped_parts,"restored loadout preserved")
			check(restored.depart_gate() and restored.s.region==1 and restored.s.phase=="map" and not restored.choices().is_empty(),"departure opens next map")
			check(not restored.depart_gate() and not restored.gate(choice),"departure cannot repeat")
			check(restored.save("user://gate_departed.json")==OK,"departure saves")
			var departed=Campaign.new()
			check(departed.restore("user://gate_departed.json") and departed.s.region==1 and departed.s.phase=="map","departure restores next map")
			if choice=="thermal":
				check(departed.enter(departed.choices()[0].id) and immediate.enter(immediate.choices()[0].id),"both gate flows enter same encounter")
				var comparison=FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("flow_"+gun+".json"),FileAccess.WRITE)
				comparison.store_string(JSON.stringify({"rest":departed.model.s,"immediate":immediate.model.s,"rest_profile":departed.profile,"immediate_profile":immediate.profile}));comparison.close()
				check(JSON.parse_string(JSON.stringify(departed.model.s))==JSON.parse_string(JSON.stringify(immediate.model.s)) and JSON.parse_string(JSON.stringify(departed.profile))==JSON.parse_string(JSON.stringify(immediate.profile)),"rest and original immediate flow begin identical combat and profile")
		# Atomic core replacement remains possible while retaining the outgoing part.
		var rest=Campaign.new()
		check(rest.restore("user://gate_pending.json") and rest.gate("skip"),"replacement fixture at rest")
		var outgoing: String=rest.equipped_parts()[0]
		for incoming in Ammo.PARTS:
			if not Ammo.is_core_part(incoming) or rest.s.parts.has(incoming) or not Ammo.accepts_part(gun,incoming): continue
			rest.s.parts.append(incoming)
			check(rest.replace_part(outgoing,incoming) and rest.s.parts.has(outgoing) and rest.is_equipped(incoming),"core replacement retains ownership at gate")
			check(rest.save("user://gate_replaced.json")==OK,"replacement at rest saves")
			var replaced=Campaign.new()
			check(replaced.restore("user://gate_replaced.json") and replaced.gate_ready() and replaced.is_equipped(incoming),"replacement resumes at rest")
			break
		var legacy=Campaign.new()
		check(legacy.restore(path),"legacy fixture restored for gate")
		legacy.s.region=0;legacy.s.node=bosses[0].id;legacy.s.floor=bosses[0].floor;legacy.s.phase="gate";legacy.s.resolved=false
		check(legacy.gate("credits") and legacy.s.region==1 and legacy.s.phase=="map" and not legacy.depart_gate(),"unversioned legacy gate keeps immediate reward flow")
	# Boss credits are automatic and idempotent, independent of card selection.
	var c=Campaign.new();c.start("single",731042)
	c.s.departure_step=3
	var boss: Dictionary=c.current_nodes().filter(func(n):return n.kind=="boss")[0]
	c.s.floor=boss.floor;c.s.node=boss.id;c.s.clears=3;c.s.phase="combat"
	for e in c.model.s.enemies:e.hp=0
	c.model.s.phase="reward"
	var credits: int=c.s.credits
	c.sync_combat()
	check(c.boss_loot() and c.s.credits==credits+30,"boss automatic loot")
	c.sync_combat()
	check(c.s.credits==credits+30 and not c.reward("credits"),"boss credits cannot be claimed twice")
	check(c.reward_options().size()==3 and c.reward_options().any(func(id):return Ammo.grade(id)==1),"boss offers three including advanced")
	check(c.reward("skip") and c.s.phase=="gate" and c.s.credits==credits+30,"skipping card keeps credits and opens gate")
	var first=Campaign.new();first.start("single",731042)
	first.s.phase="reward";first.s.clears=1
	check(first.engine_reward() and first.part_rewards().size()==3,"opening core unchanged")
	# Every boss offers a real advanced card, with distinct deterministic choices.
	for region in range(5):
		for seed_value in range(731042,731052):
			var boss_run=Campaign.new();boss_run.start("burst",seed_value)
			boss_run.s.region=region;boss_run.s.clears=5;boss_run.s.phase="reward"
			var room: Dictionary=boss_run.current_nodes().filter(func(n):return n.kind=="boss")[0]
			boss_run.s.node=room.id;boss_run.s.floor=room.floor
			var offers: Array=boss_run.reward_options()
			check(offers.size()==3 and offers.any(func(id):return Ammo.grade(id)==1),"boss offer quality "+str(region)+"/"+str(seed_value))
			check(offers==boss_run.reward_options() and offers[0]!=offers[1] and offers[1]!=offers[2] and offers[0]!=offers[2],"boss offers stable and distinct")
			if region==4:check(boss_run.reward("skip") and boss_run.s.phase=="won","final boss ends without extra gate")
	var capped: Dictionary={"gate_mods":{"thermal":2,"chain":2},"deck":["basic_p1","basic_p1","basic_p1","pierce"]}
	check(Gates.options(capped)==["production"],"capped passives leave only usable production")
	capped.deck=["pierce"]
	check(Gates.options(capped).is_empty(),"no materials gives no dead offer")
	var materials: Dictionary={"deck":["basic_p1","basic_p2","basic_p3","pierce"]}
	check(not Gates.can_produce(materials,"pierce",["basic_p1","basic_p1","basic_p1"]),"duplicate selection cannot consume missing copies")
	check(not Gates.can_produce(materials,"arc",["basic_p1","basic_p2","basic_p3"]),"unowned specimen rejected")
	var explanation=upgraded(["precise"],{"thermal":1,"chain":1},[["runner",100,1,1,30]])
	explanation.s.gate_charge=6;explanation.s.gate_chain=1
	var explained: String=preload("res://redesign/readability.gd").explain(fire(explanation,["precise"])[0])
	check(explained.contains("축열 6") and explained.contains("1.25(연쇄)") and explained.contains("첫 타격"),"damage explanation separates one hit charge and chain")
	var file=FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("rules.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"comparisons":evidence},"  "));file.close()
	print("GATE RULES COMPLETE checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
