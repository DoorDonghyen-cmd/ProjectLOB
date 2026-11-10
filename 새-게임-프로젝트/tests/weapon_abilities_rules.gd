extends SceneTree
## Controlled, save-valid states + actual current-rule native encounter openings.
const Cases=preload("res://redesign/samples/weapon_roles/cases.gd")
const Model=preload("res://redesign/model.gd")
const Content=preload("res://redesign/content.gd")
const Data=preload("res://redesign/campaign_content.gd")
const Forecast=preload("res://redesign/forecast.gd")
var checks:=0
var failures: Array=[]
var audit: Array=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label);print("FAIL: "+label)
func normalized(value: Variant) -> Variant: return JSON.parse_string(JSON.stringify(value))
func fork(m):
	var copy=Model.new();copy.s=m.s.duplicate(true);return copy
func roundtrip(m,label: String) -> void:
	var restored=Model.new()
	check(restored.restore_state(JSON.parse_string(m.serialized_state())),"restore: "+label)
	check(normalized(restored.s)==normalized(m.s),"roundtrip exact: "+label)
	var owned: Array=m.s.magazine+m.s.hand+m.s.draw+m.s.discard
	var expected: Array=m.s.deck.duplicate()
	for unused in range(Model.Reserve.generated_count(m.s)): expected.append(Model.Reserve.EMERGENCY_ROUND)
	owned.sort();expected.sort();check(owned==expected,"ownership: "+label)
func fixture(role: String,stack: Array,parts: Array=[],desired: int=-2):
	var c=Cases.Campaign.new();c.start("burst",17,0,"balanced",4,"carrier",true)
	var m=c.model
	m.s.part="none";m.s.equipped_parts=parts.duplicate()
	m.s.deck=stack.duplicate()
	while m.s.deck.size()<20: m.s.deck.append("basic_p2")
	m.begin_encounter()
	if role!="control": check(Model.WeaponRoles.activate(m.s,role),"opt in only at empty plan")
	m.s.enemies=[Data._enemy(["runner",2000,0,0,100])]
	m.s.reinforcements=[];m.s.projectiles=[];m.s.encounter_total=1;m.s.deployed=1;m.s.wave=1;m.assign_opening_lanes()
	# Put the unneeded owned cards in spent reserve for this explicit short fixture.
	# Load still runs the real anchor/capacity/mark command.
	m.s.hand=[];m.s.draw=stack.duplicate();m.s.discard=m.s.deck.slice(stack.size())
	var initial: Dictionary=m.s.duplicate(true)
	for seed_value in range(512):
		m.s=initial.duplicate(true)
		var rng:=RandomNumberGenerator.new();rng.seed=seed_value;m.s.rng_state=str(rng.state)
		if not m.trial_load_magazine(): check(false,"fixture load");return m
		if desired==-2 or Model.WeaponRoles.mark(m.s)==desired: return m
	check(false,"reachable mark index %d"%desired);return m
func reserve_for_reload(m) -> void:
	# Move untouched fixture cards to reserve; deck and occurrence counts stay fixed.
	m.s.draw.append_array(m.s.discard);m.s.discard=[]
func forecast_matches(m,label: String) -> void:
	var before: Dictionary=m.s.duplicate(true)
	var predicted:=Forecast.analyze(m.s,true,true)
	Forecast.analyze(m.s,true,true);m.preview()
	check(m.s==before,"forecast/preview never mutate state or RNG: "+label)
	var actual=fork(m)
	check(actual.fire(),"fire accepted: "+label)
	var detail: Dictionary=actual.s.history.back().detail
	check(predicted.remaining==actual.s.magazine and predicted.enemies==actual.s.enemies and predicted.phase==actual.s.phase,"forecast endpoint: "+label)
	check(int(predicted.turns)==int(actual.s.turns)-int(m.s.turns),"forecast action cost: "+label)
	check(predicted.shots.size()==detail.results.size(),"forecast card count: "+label)
	for i in range(mini(predicted.shots.size(),detail.results.size())):
		var predicted_shot: Dictionary=predicted.shots[i].duplicate(true);predicted_shot.erase("action")
		check(normalized(predicted_shot)==normalized(detail.results[i]),"full resolved shot matches forecast: "+label)
	roundtrip(actual,label+" after fire")
	audit.append({"label":label,"profile":m.s.get("weapon_role_trial",{}),"stack":m.s.magazine,"parts":Content.equipped_parts(m.s),"results":detail.results,"phase":actual.s.phase,"turns":int(actual.s.turns)-int(m.s.turns)})

func deadbolt() -> void:
	for position in [0,3,6]:
		var m=fixture("deadbolt",["basic_p2","basic_p2","basic_p2","basic_p2","basic_p2","basic_p2","basic_p2"],[],position)
		roundtrip(m,"deadbolt index %d"%position)
		var before: Dictionary=m.s.duplicate(true)
		check(not m.reload_magazine() and m.s==before,"locked reload is atomic")
		check(not m.eject_magazine_rounds([position]) and m.s==before,"sealed occurrence cannot eject")
		check(not m.eject_magazine_rounds([position,(position+1)%7]) and m.s==before,"mixed invalid selection is atomic")
		check(not Forecast.reload_now(m.s).required,"reload forecast respects seal")
		forecast_matches(m,"deadbolt duplicate occurrence %d"%position)
		m.s.fire_heat_trial.rounds=1
		while Model.WeaponRoles.locked(m.s) and m.s.phase=="ready":
			var was_marked: bool=Model.WeaponRoles.mark(m.s)==0
			check(m.fire(),"advance through sealed magazine")
			var shot: Dictionary=m.s.history.back().detail.results[0]
			check(int(shot.weapon_factor)==(3 if was_marked else 1),"only chosen occurrence receives multiplier")
			roundtrip(m,"deadbolt partial sequence")
		reserve_for_reload(m)
		check(m.reload_magazine(),"manual reload unlocks after cartridge spent")
		check(Model.WeaponRoles.locked(m.s),"new actual load selects a new seal")
		roundtrip(m,"deadbolt reloaded")
	var m=fixture("deadbolt",["charge","basic_p2","cool","basic_p2","basic_p2"],[],3)
	var rng: String=m.s.rng_state
	check(m.eject_magazine_rounds([0,4]) and Model.WeaponRoles.mark(m.s)==2,"ejection tracks physical occurrence across earlier/later removal")
	check(m.s.rng_state==rng and m.ejection_remaining()==0,"ejection consumes no RNG, retains normal quota")
	m.s.heat=5
	var mark:=Model.WeaponRoles.mark(m.s)
	check(m.cool_magazine() and m.s.heat==0 and Model.WeaponRoles.mark(m.s)==mark and m.s.rng_state==rng,"manual cooling preserves chosen seal without reroll")
	roundtrip(m,"deadbolt cooled/ejected")
	check(not m.can_field_compress("basic_p2"),"field transformation cannot bypass loaded seal")
	m=fixture("deadbolt",["charge","cool","charge","cool"])
	check(not Model.WeaponRoles.locked(m.s),"no attack candidates means no seal")
	reserve_for_reload(m);check(m.reload_magazine(),"no attack candidates does not deadlock reload")
	m=fixture("deadbolt",["cool_c","pierce_c","vent"])
	check(Content.valid_stack(m.s.magazine,m.capacity()),"anchored compressed loaded stack stays valid")
	forecast_matches(m,"deadbolt anchors and compression")
	# The ×3 composes once with position/support/core direct damage, never Ratchet.
	for parts in [[],["opening"],["third_striker"],["afterburner"],["siege_drive"],["volley_drive"],["thermal_drive"]]:
		for id in ["basic_p2","precise","bore","arc"]:
			var stack: Array=["charge","charge_hot",id]
			m=fixture("deadbolt",stack,parts,2)
			m.s.heat=5 if parts.has("thermal_drive") else 0
			forecast_matches(m,"deadbolt direct/support/core "+id+" "+str(parts))
			var plain=fork(m);plain.s.weapon_role_trial.mark=-1
			var boosted=fork(m)
			check(boosted.fire() and plain.fire(),"support/core comparison fires")
			var boosted_results: Array=boosted.s.history.back().detail.results
			var plain_results: Array=plain.s.history.back().detail.results
			if boosted_results.size()==3 and plain_results.size()==3:
				# Compare the exact armor-free pre-defense value already exposed by Model.
				check(int(boosted_results[2].math.raw)==int(plain_results[2].math.raw)*3,"support/core direct multiplier applied exactly once")
				check(boosted_results[2].burn_added==plain_results[2].burn_added and boosted_results[2].burn_tick==plain_results[2].burn_tick,"seal never triples burn stacks/tick")
	# Marked single-card shot against equal plain role, with armor/barrier defenses.
	for armor in [0,3]:
		for barrier in [0,1]:
			m=fixture("deadbolt",["basic_p2"],[],0)
			m.s.enemies[0].def=armor;m.s.enemies[0].barrier=barrier
			var ordinary=fork(m);ordinary.s.weapon_role_trial.mark=-1
			check(m.fire() and ordinary.fire(),"marked/plain defense comparison fires")
			var boosted: Dictionary=m.s.history.back().detail.results[0]
			var plain: Dictionary=ordinary.s.history.back().detail.results[0]
			check(int(boosted.math.raw)==int(plain.math.raw)*3,"exact direct triple before armor")
			check(int(boosted.focus_damage)==0,"comparison does not inherit Ratchet bonus")
			check(not Model.WeaponRoles.locked(m.s),"barrier-absorbed cartridge still unlocks")
			if barrier>0: check(boosted.damage==0,"barrier remains effective against marked shot")
			forecast_matches(fixture("deadbolt",["basic_p2"],[],0),"single attack candidate")
	# Battle terminal paths clear a still-unspent mark.
	m=fixture("deadbolt",["cool","basic_p2"],[],1)
	m.s.enemies[0].distance=1;m.s.enemies[0].speed=1;m.s.heat=1
	check(m.cool_magazine() and m.s.phase=="lost" and not Model.WeaponRoles.locked(m.s),"loss during cooling clears seal")
	roundtrip(m,"deadbolt terminal loss")
	m=fixture("deadbolt",["basic_p2","basic_p2"],[],1)
	m.s.enemies[0].hp=1;m.s.fire_heat_trial.rounds=1
	check(m.fire() and m.s.phase in ["won","reward"] and not Model.WeaponRoles.locked(m.s),"early victory clears unspent seal")
	roundtrip(m,"deadbolt terminal victory")
	m=fixture("deadbolt",["basic_p2","basic_p2"],[],1)
	m.s.heat=Content.heat_limit(m.s)-1;m.s.fire_heat_trial.rounds=1;rng=m.s.rng_state
	check(m.fire() and m.s.heat==0 and Model.WeaponRoles.mark(m.s)==0 and m.s.rng_state==rng,"forced cooling preserves unspent seal without reroll")
	roundtrip(m,"deadbolt forced cooling")
	# Secondary/status behavior is compared on two targets with equal HP and no cap.
	for id in ["arc","bore"]:
		m=fixture("deadbolt",[id],[],0)
		m.s.enemies.append(Data._enemy(["runner",2000,0,0,120]));m.s.encounter_total=2;m.s.deployed=2;m.assign_opening_lanes()
		var plain=fork(m);plain.s.weapon_role_trial.mark=-1
		check(m.fire() and plain.fire(),"secondary comparison fires")
		var sealed: Dictionary=m.s.history.back().detail.results[0]
		var ordinary: Dictionary=plain.s.history.back().detail.results[0]
		check(sealed.secondary==ordinary.secondary and sealed.fire_zones==ordinary.fire_zones,"fixed arc/zone effect does not inherit ×3")
		check(sealed.burn_added==ordinary.burn_added and sealed.burn_tick==ordinary.burn_tick,"burn status unchanged")
	m=fixture("deadbolt",["bore","detonate"],[],0);m.s.fire_heat_trial.rounds=1
	var plain=fork(m);plain.s.weapon_role_trial.mark=-1
	check(m.fire() and plain.fire() and m.fire() and plain.fire(),"burn then detonation resolves")
	check(m.s.history.back().detail.results[0].damage==plain.s.history.back().detail.results[0].damage,"detonation remains independent of sealed direct damage")
	for core in ["thermal_drive","siege_drive","volley_drive"]:
		m=fixture("deadbolt",["precise" if core=="volley_drive" else "basic_p2"],[core],0)
		m.s.enemies[0].hp=1 if core!="thermal_drive" else 2000
		m.s.enemies.append(Data._enemy(["runner",2000,0,0,120]));m.s.encounter_total=2;m.s.deployed=2;m.assign_opening_lanes()
		if core=="thermal_drive": m.s.heat=Content.heat_limit(m.s)-1
		plain=fork(m);plain.s.weapon_role_trial.mark=-1
		check(m.fire() and plain.fire(),"core followup comparison fires")
		var sealed: Dictionary=m.s.history.back().detail.results[0]
		var ordinary: Dictionary=plain.s.history.back().detail.results[0]
		if core=="thermal_drive":
			check(sealed.shock_damage==ordinary.shock_damage and sealed.shock_damage>0,"thermal wave excludes seal multiplier")
		elif core=="siege_drive":
			check(sealed.secondary.size()==1 and int(sealed.secondary[0].damage)==int(sealed.math.first_hit)-1,"overflow transfers already boosted excess once")
		else:
			check(not sealed.secondary.is_empty() and int(sealed.secondary[0].damage)==int(sealed.math.per_hit),"remaining direct multi-hit keeps exactly one multiplier")
	m=fixture("deadbolt",["basic_p2","basic_p2","basic_p2","basic_p2","basic_p2","basic_p2","basic_p2"])
	var selected: Dictionary={}
	for seed_value in range(128):
		m.s.seed=str(seed_value);m.begin_encounter()
		check(m.trial_load_magazine(),"seeded actual magazine load")
		selected[Model.WeaponRoles.mark(m.s)]=true
		var again=fork(m);again.s.seed=str(seed_value);again.begin_encounter();again.trial_load_magazine()
		check(again.s.weapon_role_trial==m.s.weapon_role_trial and again.s.rng_state==m.s.rng_state,"same seed/load reproduces seal and RNG")
	check(selected.size()==7,"multiple seeds can select every attack occurrence")

func rewinder() -> void:
	var m=fixture("rewinder",["charge","precise_p2","cool","basic_p2","vent"],["third_striker"])
	var before: Dictionary=m.s.duplicate(true)
	check(not m.cool_magazine() and m.s==before,"zero heat cannot reverse for free")
	m.s.heat=3
	before=m.s.duplicate(true)
	check(m.cool_magazine(),"first manual cooling")
	check(m.s.magazine==["basic_p2","cool","precise_p2","charge","vent"],"reverse only movable positions; last anchor stays")
	check(m.s.weapon_role_trial.rewound and int(m.s.turns)==int(before.turns)+1 and m.s.heat==0,"reversal retains cooling cost")
	for key in ["draw","hand","discard","deck","shots","magazine_ejected","rng_state","target_rng_state"]:
		check(m.s.get(key)==before.get(key),"reversal preserves "+key)
	roundtrip(m,"rewinder after reversal")
	forecast_matches(m,"rewinder reordered magazine")
	var reversed: Array=m.s.magazine.duplicate()
	m.s.heat=2;check(m.cool_magazine() and m.s.magazine==reversed,"second manual cooling does not reverse again")
	reserve_for_reload(m);check(m.reload_magazine() and not m.s.weapon_role_trial.rewound,"new load resets reversal use")
	roundtrip(m,"rewinder reloaded")
	for stack in [["cool_c","basic_p2","precise_p2","vent"],["cool_c","pierce_c","vent"],["basic_p2"],["charge","basic_p2","cool"]]:
		m=fixture("rewinder",stack)
		m.s.heat=3;check(m.cool_magazine(),"cool anchored/short fixture")
		check(Content.valid_stack(m.s.magazine,m.capacity()),"reordered large/anchored stack remains save-valid")
		roundtrip(m,"rewinder anchored/short")
	m=fixture("rewinder",["basic_p2","charge","precise_p2"])
	before=m.s.duplicate(true);m.s.heat=Content.heat_limit(m.s)-1;m.s.fire_heat_trial.rounds=1
	check(m.fire() and not m.s.weapon_role_trial.rewound,"forced overheat cooling does not spend reversal")
	check(m.s.magazine==before.magazine.slice(1),"forced cooling preserves remaining order")
	roundtrip(m,"rewinder forced cooling")
	m=fixture("rewinder",["cool","basic_p2","charge"]);m.s.heat=1;m.s.fire_heat_trial.rounds=1
	check(m.fire() and not m.s.weapon_role_trial.rewound,"cooling ammunition does not reverse")
	m=fixture("rewinder",["basic_p2","charge","precise_p2"],["third_striker"])
	m.s.fire_heat_trial.rounds=1;check(m.fire(),"one shot before ejection/reverse")
	check(m.eject_magazine_rounds([0]),"normal ejection before reversal")
	var recent: Array=m._recent_part_rounds();var quota: int=m.ejection_remaining()
	check(m.cool_magazine() and m._recent_part_rounds()==recent and m.ejection_remaining()==quota,"cooling never resets position history or ejection quota")
	m=fixture("rewinder",["charge","precise_p2","basic_p2"]);m.s.heat=1;m.s.enemies[0].distance=1;m.s.enemies[0].speed=1
	before=m.s.duplicate(true)
	check(m.cool_magazine() and m.s.phase=="lost" and m.s.magazine==before.magazine and not m.s.weapon_role_trial.rewound,"lethal cooling never reorders")
	roundtrip(m,"rewinder lethal cooling")
	m=fixture("rewinder",["charge","precise_p2","basic_p2"]);m.s.heat=1;m.s.enemies[0].hp=1;m.s.enemies[0].burn=1
	before=m.s.duplicate(true)
	check(m.cool_magazine() and m.s.phase in ["reward","won"] and m.s.magazine==before.magazine and not m.s.weapon_role_trial.rewound,"burn victory during cooling never reorders")
	roundtrip(m,"rewinder terminal victory")
	# Two legal decisions from the same partially spent magazine. No hidden draw/RNG.
	m=fixture("rewinder",["basic_p2","basic_p2","basic_p2","charge","precise_p2"],["third_striker"])
	m.s.fire_heat_trial.rounds=2;check(m.fire(),"prepare two real shots for position decision")
	m.s.fire_heat_trial.rounds=1
	var immediate=fork(m);var cooled=fork(m)
	check(immediate.fire() and cooled.cool_magazine() and cooled.fire(),"immediate vs cooling-reverse are legal choices")
	var immediate_damage: int=immediate.s.history.back().detail.results[0].damage
	var reversed_damage: int=cooled.s.history.back().detail.results[0].damage
	check(reversed_damage>immediate_damage,"reversal moves multi-hit attack into actual third-shot part")
	check(int(cooled.s.turns)==int(immediate.s.turns)+1,"extra damage costs one enemy action")
	audit.append({"label":"rewinder legal position choice","immediate_damage":immediate_damage,"cooled_damage":reversed_damage,"immediate_turns":int(immediate.s.turns)-int(m.s.turns),"cooled_turns":int(cooled.s.turns)-int(m.s.turns),"scope":"controlled fixture, not acquisition balance or human fun"})
	# At contact range, firing removes the front threat while cooling loses first.
	m.s.enemies=[Data._enemy(["runner",immediate_damage,0,1,1]),Data._enemy(["runner",2000,0,0,100])];m.s.encounter_total=2;m.s.deployed=2;m.assign_opening_lanes()
	immediate=fork(m);cooled=fork(m)
	check(immediate.fire() and immediate.s.phase=="ready" and cooled.cool_magazine() and cooled.s.phase=="lost","near contact makes the higher-damage cooling choice lethal")
	roundtrip(immediate,"rewinder immediate near contact")
	roundtrip(cooled,"rewinder lethal alternative")

func save_rejection() -> void:
	var m=fixture("deadbolt",["charge","basic_p2"],[],1)
	var corruptions: Array=[{"version":2,"kind":"deadbolt","mark":1,"rewound":false},{"version":true,"kind":"deadbolt","mark":1,"rewound":false},{"version":1,"kind":"unknown","mark":1,"rewound":false},{"version":1,"kind":"deadbolt","mark":0,"rewound":false},{"version":1,"kind":"deadbolt","mark":1.5,"rewound":false},{"version":1,"kind":"deadbolt","mark":50,"rewound":false},{"version":1,"kind":"deadbolt","mark":1,"rewound":true},{"version":1,"kind":"rewinder","mark":1,"rewound":false},null,[]]
	for value in corruptions:
		var broken: Dictionary=m.s.duplicate(true);broken.weapon_role_trial=value
		var restored=fork(m);var before: Dictionary=restored.s.duplicate(true)
		check(not restored.restore_state(broken) and restored.s==before,"invalid profile rejected atomically: "+str(value))
	var broken: Dictionary=m.s.duplicate(true);broken.gun="single"
	check(not Model.new().restore_state(broken),"wrong base weapon rejects trial state")
	broken=m.s.duplicate(true);broken.erase("fire_control_version")
	check(not Model.new().restore_state(broken),"profile requires current cooling contract")

func run() -> void:
	var output:=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").ends_with("/qa_runtime/weapon_abilities_20261106"): quit(2);return
	for profile in Cases.PROFILES:
		for index in range(3):
			var m=Cases.build(profile,index)
			check(m!=null,"native comparison case builds")
			if m==null: continue
			roundtrip(m,profile+" native case "+str(index))
			check(m.capacity()==7 and Content.heat_limit(m.s)==14 and m.reload_cost()==2,"same comparison platform")
			forecast_matches(m,profile+" native case "+str(index))
	deadbolt();rewinder();save_rejection()
	FileAccess.open(output.path_join("rules.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"audit":audit},"  "))
	print("WEAPON ABILITIES RULES COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
