extends SceneTree
## Read-only role evidence with current production Model. No candidate mechanics.
const Campaign=preload("res://redesign/campaign.gd")
const Content=preload("res://redesign/content.gd")
const Data=preload("res://redesign/campaign_content.gd")
var output: String
var rows: Array=[]
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func total_hp(enemies: Array) -> int:
	var result:=0
	for enemy in enemies:result+=maxi(0,int(enemy.hp))
	return result
func run() -> void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").ends_with("/qa_runtime/weapon_roles_20261106"):quit(2);return
	var reference=Campaign.new();reference.start("single",17,0,"balanced",4,"carrier",true)
	var parts: Array=[]
	for id in Content.PARTS:
		var spec: Dictionary=Content.part_spec(id,reference.model.s)
		parts.append({"id":id,"name":spec.name,"text":spec.get("text",""),"kind":spec.get("kind","")})
	var ammo: Array=[]
	for id in Content.TACTICAL_AMMO+["basic_p2","pierce_p2","precise_p2"]:
		if Content.AMMO.has(id):ammo.append({"id":id,"spec":Content.AMMO[id]})
	var guns: Array=[]
	for gun in Content.GUNS:
		var c=Campaign.new();c.start(gun,17,0,"balanced",4,"carrier",true)
		var m=c.model
		guns.append({"id":gun,"spec":Content.weapon_spec(m.s),"capacity":m.capacity(),"heat_limit":Content.heat_limit(m.s),"reload":m.reload_cost(),"base_cards":m.MagazineTrial.pulse(m.s),"start_deck":m.s.deck,"state_versions":{ "combat_roles_version":m.s.get("combat_roles_version",0),"specialist_core_version":m.s.get("specialist_core_version",0),"balance_version":m.s.get("balance_version",0)}})
	var orders:={"basic":["basic_p2","basic_p2","basic_p2","basic_p2","basic_p2","basic_p2","basic_p2","basic_p2","basic_p2"],"support_first":["charge","precise_p2","basic_p2","basic_p2","basic_p2","basic_p2","basic_p2","basic_p2","basic_p2"],"support_last":["precise_p2","basic_p2","basic_p2","basic_p2","basic_p2","charge","basic_p2","basic_p2","basic_p2"],"control":["disrupt","bore","basic_p2","basic_p2","basic_p2","basic_p2","basic_p2","basic_p2","basic_p2"]}
	for gun in Content.GUNS:
		for scene in ["single","pair","crowd"]:
			for order in orders:
				for modules in [[],["opening","third_striker"],["thermal_drive"]]:
					for hot in [false,true]:
						var c=Campaign.new();c.start(gun,17,0,"balanced",4,"carrier",true);c.advance_departure(true);c.enter(101)
						var m=c.model
						m.s.part="none";m.s.equipped_parts=modules.duplicate()
						m.s.deck=orders[order].duplicate()
						while m.s.deck.size()<14:m.s.deck.append("basic_p2")
						m.begin_encounter()
						m.s.magazine=m.s.deck.slice(0,m.capacity());m.s.magazine_loaded=m.s.magazine.duplicate();m.s.draw=m.s.deck.slice(m.capacity());m.s.hand=[]
						m.s.phase="ready";m.s.magazine_ejected=0;m.s.fire_heat_trial.rounds=0
						m.s.enemies=[]
						var count:=1 if scene=="single" else 2 if scene=="pair" else 4
						for i in range(count):m.s.enemies.append(Data._enemy(["runner",100 if scene=="single" else 30 if i==0 and scene=="pair" else 8 if scene=="pair" else 6,3 if scene!="crowd" and i==0 else 0,1,30+i*4]))
						m.s.reinforcements=[];m.s.projectiles=[];m.s.encounter_total=count;m.s.deployed=count;m.assign_opening_lanes()
						m.s.heat=ceili(Content.heat_limit(m.s)*0.75) if hot else 0
						m._record("load",{"load_order":m.s.magazine.duplicate(),"whole_magazine":true})
						var before: Dictionary=m.s.duplicate(true)
						var preview=m.preview()
						if m.s!=before:failures.append("preview mutation")
						var accepted: bool=m.fire()
						if not accepted:failures.append("rejected legal fire")
						var record: Dictionary=m.s.history.back()
						rows.append({"gun":gun,"scene":scene,"order":order,"parts":modules,"hot":hot,"before_heat":before.heat,"damage_including_turn_effects":total_hp(before.enemies)-total_hp(m.s.enemies),"hp_before":before.enemies.map(func(e):return e.hp),"hp_after":m.s.enemies.map(func(e):return e.hp),"cards":int(m.s.shots)-int(before.shots),"enemy_actions":int(m.s.turns)-int(before.turns),"heat":m.s.heat,"phase":m.s.phase,"remaining":m.s.magazine,"results":record.get("detail",{}).get("results",[]),"preview":preview})
	FileAccess.open(output.path_join("roles.json"),FileAccess.WRITE).store_string(JSON.stringify({"guns":guns,"parts":parts,"ammo":ammo,"rows":rows,"failures":failures,"scope":"Current five-gun one-action controlled comparisons, not new-weapon simulation or natural acquisition/player outcomes."},"  "))
	print("WEAPON ROLE PROBE COMPLETE cases=%d failures=%d"%[rows.size(),failures.size()]);quit(0 if failures.is_empty() else 1)
