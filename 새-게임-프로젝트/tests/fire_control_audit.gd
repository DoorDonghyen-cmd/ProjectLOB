extends SceneTree
const Model=preload("res://redesign/model.gd")
const Content=preload("res://redesign/content.gd")
const Campaign=preload("res://redesign/campaign.gd")
var checks:=0
var failures: Array=[]
var records: Array=[]
var rewards: Array=[]
func _initialize()->void:run.call_deferred()
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func automatic(state: Dictionary,modern: bool,parts: bool=true)->Dictionary:
	var m=Model.new();check(m.restore_state(state),"earned combat restores")
	if modern:Model.FireHeatTrial.activate_campaign(m.s)
	if not parts:m.s.equipped_parts=[];m.s.part="none" # Ablation, not an earned build.
	var initial_turns: int=m.s.turns;var actions: Dictionary={};var forced:=0;var min_distance:=9999
	for step in range(160):
		if m.s.phase!="ready":break
		var action:="fire" if not m.s.magazine.is_empty() else "emergency" if m.can_emergency_resupply() else "reload"
		var ok: bool=m.fire() if action=="fire" else m.emergency_resupply() if action=="emergency" else m.reload_magazine()
		if not ok:break
		actions[action]=int(actions.get(action,0))+1
		if action=="fire":forced+=int(m.s.history.back().detail.get("forced_cooling",{}).get("elapsed",0))
		for enemy in m.s.enemies+m.s.projectiles:
			if enemy.hp>0:min_distance=mini(min_distance,int(enemy.distance))
	return {"won":m.s.phase in ["reward","won"],"phase":m.s.phase,"turns":m.s.turns-initial_turns,"actions":actions,"forced_cooling_turns":forced,"spent":m.s.discard.size(),"remaining":m.s.magazine.size()+m.s.hand.size()+m.s.draw.size(),"margin":min_distance}
func run()->void:
	var output:=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/fire_control_20261102/"):quit(2);return
	for gun in ["single","burst","scatter","heavy","amplifier"]:
		var folder:=ProjectSettings.globalize_path("res://../qa_runtime/campaign_magazine_20261101/v3_%s/rules"%gun)
		for file in DirAccess.get_files_at(folder):
			if not file.begins_with("combat_") or not file.ends_with(".json"):continue
			var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(file)))
			var state: Dictionary=data.combat
			var families: Dictionary={};var special:=0
			for id in state.deck:
				var family:=Content.source_id(str(id))
				families[family]=int(families.get(family,0))+1
				if family!="basic":special+=1
			var row:={"gun":gun,"region":int(data.campaign.region)+1,"node":data.campaign.node,"deck_count":state.deck.size(),"special":special,"families":families,"parts":state.equipped_parts,"legacy_repeat":automatic(state,false),"new_repeat":automatic(state,true),"new_without_parts":automatic(state,true,false)}
			# Draw distributions use actual shuffle, initial-special guarantee and magazine loading.
			var two_special:=0;var two_empty:=0;var observed:=0
			for seed in range(100):
				var m=Model.new();m.s=state.duplicate(true);m.s.seed=str(seed*104729+17);m.begin_encounter();m.trial_load_magazine()
				var second: Array=m.MagazineTrial.take(m.s.hand+m.s.draw,m.capacity(),Content.slot_cost,Content.anchor).selected
				var count:=second.filter(func(id):return Content.source_id(str(id))!="basic").size()
				two_special+=count;two_empty+=int(count==0);observed+=1
			row.second_special=float(two_special)/observed;row.second_empty=float(two_empty)/observed
			records.append(row)
			# Candidate composition at this earned state; not fabricated reward grants.
			var c=Campaign.new();check(c.restore_state(data),"earned whole campaign restores")
			var options: Array=Campaign.Content.rewards(c.node(),int(c.s.seed),state.deck,state.equipped_parts,int(c.s.discovery_version))
			rewards.append({"gun":gun,"node":c.s.node,"region":int(c.s.region)+1,"options":options,"owned_family_counts":options.map(func(id):return families.get(Content.source_id(str(id)),0))})
		print("AUDIT ",gun)
	FileAccess.open(output.path_join("audit.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"note":"Independent earned entry snapshots. Repeat policy only fires/reloads/emergency; no deliberate cooling, ejection or future RNG. Removed-parts condition is a synthetic ablation. Not a fresh-run human win rate.","battles":records,"reward_candidates":rewards},"  "))
	print("FIRE CONTROL COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
