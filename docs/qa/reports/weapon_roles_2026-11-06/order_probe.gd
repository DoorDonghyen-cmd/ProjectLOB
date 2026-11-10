extends SceneTree
## A controlled order intervention after real cooling, not a new-weapon resolver.
const Campaign=preload("res://redesign/campaign.gd")
const Model=preload("res://redesign/model.gd")
const Data=preload("res://redesign/campaign_content.gd")
const Content=preload("res://redesign/content.gd")
var rows: Array=[]
var failures: Array=[]
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var output:=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").ends_with("/qa_runtime/weapon_roles_20261106"):quit(2);return
	for near in [false,true]:
		for part in ["none","third_striker"]:
			var c=Campaign.new();c.start("single",17,0,"balanced",4,"carrier",true);c.advance_departure(true);c.enter(101)
			var m=c.model
			m.s.equipped_parts=[] if part=="none" else [part];m.s.part="none"
			m.s.deck=["basic_p2","basic_p2","charge","basic_p2","basic_p2","basic_p2","pierce_p2"]
			while m.s.deck.size()<14:m.s.deck.append("basic_p2")
			m.begin_encounter()
			m.s.magazine=m.s.deck.slice(0,7);m.s.magazine_loaded=m.s.magazine.duplicate();m.s.draw=m.s.deck.slice(7);m.s.hand=[]
			m.s.phase="ready";m.s.fire_heat_trial.rounds=2;m.s.enemies=[Data._enemy(["runner",200,3,1,3 if near else 30])]
			m.s.reinforcements=[];m.s.projectiles=[];m.s.encounter_total=1;m.s.deployed=1;m.assign_opening_lanes()
			m._record("load",{"load_order":m.s.magazine.duplicate(),"whole_magazine":true})
			if not m.fire():failures.append("priming fire rejected")
			var before: Dictionary=m.s.duplicate(true)
			for branch in ["fire_now","cool_keep","cool_reverse_intervention"]:
				var copy=Model.new();copy.s=before.duplicate(true)
				var cooled:=false;var fired:=false
				if branch!="fire_now":cooled=copy.cool_magazine()
				if branch=="cool_reverse_intervention" and cooled and copy.s.phase=="ready":copy.s.magazine.reverse()
				var fire_order: Array=copy.s.magazine.duplicate()
				if copy.s.phase=="ready":fired=copy.fire()
				rows.append({"near":near,"part":part,"branch":branch,"cooled":cooled,"fired":fired,"order_before":before.magazine,"fire_order":fire_order,"damage":int(before.enemies[0].hp)-int(copy.s.enemies[0].hp),"enemy_actions":int(copy.s.turns)-int(before.turns),"cards":int(copy.s.shots)-int(before.shots),"phase":copy.s.phase,"distance":copy.s.enemies[0].distance,"heat":copy.s.heat,"history":copy.s.history})
			var cold=Model.new();cold.s=before.duplicate(true);cold.s.heat=0
			var cold_before: Dictionary=cold.s.duplicate(true)
			if cold.cool_magazine() or cold.s!=cold_before:failures.append("zero heat cooling should remain rejected without mutation")
	var anchor_cases: Array=[]
	var first:=""
	for id in Content.AMMO:
		if Content.anchor(id)=="first":first=id;break
	for original in [["charge","basic_p2","vent"],[first,"charge","basic_p2","vent"]]:
		if original.has(""):continue
		var space:=Content.slots_used(original)
		var naive: Array=original.duplicate();naive.reverse()
		var movable: Array=original.filter(func(id):return Content.anchor(id).is_empty());movable.reverse()
		var anchored: Array=original.duplicate();var next:=0
		for i in range(anchored.size()):
			if Content.anchor(anchored[i]).is_empty():anchored[i]=movable[next];next+=1
		var valid:=Content.valid_stack(anchored,space)
		if not valid or Content.valid_stack(naive,space):failures.append("fixed-position reversal premise mismatch")
		anchor_cases.append({"original":original,"naive":naive,"naive_valid":Content.valid_stack(naive,space),"anchored":anchored,"anchored_valid":valid,"slots":space})
	FileAccess.open(output.path_join("order_probe.json"),FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"anchor_cases":anchor_cases,"failures":failures,"scope":"Rivet is a common test bench. Branch three manually reverses the remaining unanchored array after the actual cooling command; no weapon hook, stats, forecast or persistence is implemented. Fixed-position examples separately use production Content.valid_stack."},"  "))
	print("ORDER ROLE PROBE COMPLETE cases=%d failures=%d"%[rows.size(),failures.size()]);quit(0 if failures.is_empty() else 1)
