extends "res://tests/playtest_rework_rules.gd"
const Choices=preload("res://redesign/build_choices.gd")
func build(rounds: Array,parts: Array=[],gun: String="single",version: int=3):
	var m=modern(rounds,parts,gun);m.s.combat_roles_version=version;return m
func run()->void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/build_roles_20261103/"):quit(2);return
	var fire=build(["bore","basic_p2"],["inferno","coil"])
	targets(fire,3,30,3)
	var r:=shot(fire)
	check(r.burn_tick==4 and r.fire_zones[0].damage==6 and r.fire_zones[0].radius==3,"specialist fire core/coil has bounded area identity")
	check(fire.s.enemies[1].hp==24 and fire.s.enemies[2].hp==30,"three-meter boundary includes only adjacent target")
	check(r.part_effects.any(func(p):return p.id=="inferno") and r.part_effects.any(func(p):return p.id=="coil"),"actual ground fire parts emit readable receipts")
	check(fire.s.fire_zones[0].left==3 and fire.reload_cost()==3,"four-action zone retains extra reload cost")
	restore_check(fire)
	for compressed in [false,true]:
		var m=build(["disrupt_c" if compressed else "disrupt","basic_p2"],["momentum"])
		m.s.enemies[0].speed=4
		var hit:=shot(m)
		check(hit.slowed==(4 if compressed else 3) and m.s.enemies[0].slow_left==hit.slowed-1,"control core extends finite approach slow")
		check(hit.part_effects.any(func(p):return p.id=="momentum"),"control duration activation is visible")
		check(Roles.slow(m.s.enemies[0],4)==0,"control cannot renew per-enemy slow")
		restore_check(m)
	var combo=build(["disrupt","precise_p2","basic_p2"],["volley_drive","rammer"])
	check(shot(combo).damage==0,"control setup does not receive attack damage")
	var plain=Model.new();check(plain.restore_state(canonical(combo.s)),"same conditioned state clones")
	plain.s.equipped_parts.erase("rammer");plain.s.push_left=Content.push_budget(plain.s)
	var enhanced:=shot(combo);var ordinary:=shot(plain)
	check(enhanced.damage-ordinary.damage==2*enhanced.hits,"following multi-hit gets two per actual hit")
	check(enhanced.part_effects.any(func(p):return p.id=="rammer"),"follow-up activation has an actual receipt")
	check(combo.s.enemies[0].slow_left==0,"normal two-action setup window expires")
	check(shot(combo).damage==shot(plain).damage,"no permanent damage buff after slow")
	for primary_slow in [true,false]:
		var relay=build(["precise_p2","basic_p2"],["volley_drive","duplex","rammer"])
		targets(relay,2,1000);relay.s.enemies[0].hp=1
		var target: int=0 if primary_slow else 1
		relay.s.enemies[target].slow_left=2;relay.s.enemies[target].slow_used=true
		var baseline=Model.new();check(baseline.restore_state(canonical(relay.s)),"relay comparison state restores")
		baseline.s.equipped_parts.erase("rammer");baseline.s.push_left=Content.push_budget(baseline.s)
		var a:=shot(relay);var b:=shot(baseline)
		check(a.part_effects.any(func(p):return p.id=="rammer"),"primary or secondary conditional hit reports rammer")
		for i in range(a.secondary.size()):check(a.secondary[i].damage-b.secondary[i].damage==(0 if primary_slow else 2),"relay re-evaluates destination slow")
	var relay=build(["precise_p2","basic_p2"],["volley_drive","duplex","capacitor"])
	check(Content.valid_part_set("single",relay.s.equipped_parts),"relay expansion is a legally compatible module")
	check(not Content.valid_part_set("single",["volley_drive","arc_splitter"]),"two-core restriction retained")
	targets(relay,4,1)
	var hits:=shot(relay)
	check(relay.alive_count()==1 and hits.secondary.size()==2,"capacitor extends to exactly two extra targets")
	check(hits.part_effects.any(func(p):return p.id=="capacitor"),"expanded relay reports its module")
	var overflow=build(["basic_p3"],["siege_drive","capacitor"])
	targets(overflow,4,1)
	var carried:=shot(overflow)
	check(carried.secondary.size()==2 and carried.part_effects.any(func(p):return p.id=="capacitor"),"overflow expansion also reports its actual extra target")
	for core in ["volley_drive","siege_drive","thermal_drive","inferno","momentum","arc_splitter"]:
		var state=build(["bore","basic_p2"],[core]).s
		check(Model.Gates.options(state,true).has("conduction")==(core in ["volley_drive","siege_drive"]),"gate relay option has current compatible core")
		check(Model.Gates.options(state,true).has("growth")==(core in Model.Engines.IDS),"growth gate applies only to growing cores")
	var before_offers=load("res://../qa_runtime/build_roles_20261103/before/새-게임-프로젝트/redesign/campaign_content.gd")
	var data=Campaign.Content
	for seed_value in range(80):
		for family in ["bore","arc","precise_p2","pierce_p2","vent"]:
			var state=build(["basic_p2"],["thermal_drive"]).s
			state.deck=[family,family,"disrupt","basic_p2"]
			state.seed=str(seed_value)
			var node: Dictionary={"id":303,"region":0,"floor":3,"elite":false}
			var owned: Array=["thermal_drive","field_press","reserve"]
			var offers: Array=data.offers(node,seed_value,0,"single",owned,[],[],state.equipped_parts,3,1,state)
			check(offers[1].id==Choices.signature(state),"first regional shop exposes the chosen ammo role")
			check(Choices.role(offers[1].id)!=Choices.role(offers[2].id),"second choice provides another role")
			var seen: Array=[offers[1].id,offers[2].id]
			var rerolled: Array=data.offers(node,seed_value,1,"single",owned,seen,[],state.equipped_parts,3,1,state)
			check(not seen.has(rerolled[1].id) and not seen.has(rerolled[2].id),"unseen priority survives adaptive fitting")
			for version in [1,2]:
				state.combat_roles_version=version
				check(canonical(data.offers(node,seed_value,0,"single",owned,[],[],state.equipped_parts,3,1,state))==canonical(before_offers.offers(node,seed_value,0,"single",owned,[],[],state.equipped_parts,3,1)),"v1/v2 offer RNG and result unchanged")
	var state=build(["bore","bore","disrupt","basic_p2"],["thermal_drive"]).s
	var ammo: Array=[]
	for revision in range(3):ammo.append(Choices.shop_ammo(state,{"id":303},revision))
	check(ammo.has("bore") and ammo.has("bore_c") and ammo.any(func(id):return id in ["detonate","spread"]),"shop rotates copy, improved copy and missing support")
	var old_model=load("res://../qa_runtime/build_roles_20261103/before/새-게임-프로젝트/redesign/model.gd")
	for version in [1,2]:
		for parts in [["inferno","coil"],["momentum","rammer"],["volley_drive","capacitor"]]:
			var current=build(["disrupt","bore","precise_p2","basic_p2"],parts,"single",version)
			var prior=old_model.new();check(prior.restore_state(canonical(current.s)),"historical role state restores")
			for action in ["fire","fire","cool_magazine","fire"]:
				check(current.call(action)==prior.call(action) and canonical(current.s)==canonical(prior.s),"historical full resolver remains exact")
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("BUILD ROLES COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
