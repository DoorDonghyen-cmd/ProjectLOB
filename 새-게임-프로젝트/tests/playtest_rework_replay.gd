extends "res://tests/playtest_rework_climb.gd"
func _run()->void:
 output=OS.get_environment("QA_OUTPUT_DIR")
 if not output.replace("\\","/").contains("/qa_runtime/playtest_rework_20261103/"):quit(2);return
 var comparisons: Array=[]
 for label in ["climb_primary","climb_alternate","climb_incendiary","climb_amplifier_final"]:
  var path: String=ProjectSettings.globalize_path("res://../qa_runtime/playtest_rework_20261103/")+label+"/balance.json"
  var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
  for endpoint in report.endpoints:
   if label=="climb_alternate" and endpoint.gun=="amplifier":continue
   if not check(endpoint.won,"source is a completed earned route"):continue
   var c=Campaign.new();c.start(endpoint.gun,int(endpoint.seed),0,"balanced",4,"carrier",true)
   commands=[]
   var fights:=0;var emergencies:=0;var minimum_ammo:=999;var ticks:=0;var slows:=0
   for step in endpoint.commands:
    var expected_turns: int=int(step.get("turns",-1))
    var prior_phase: String=c.s.phase
    if not command(c,step.duplicate(true)):break
    if expected_turns>=0:check(c.model.s.turns==expected_turns,"replay preserves action timing")
    if prior_phase=="combat" and c.s.phase=="reward":
     fights+=1
     emergencies+=int(before_save.get("emergency_uses",0))
     minimum_ammo=mini(minimum_ammo,c.model.Reserve.remaining(before_save))
     check(c.model.Reserve.remaining(before_save)>=0,"generated emergency ammo is included in inventory conservation")
    if step.action=="fire":
     for event in c.model.s.history.back().detail.get("results",[]):slows+=1 if int(event.get("slowed",0))>0 else 0
     for event in c.model.s.history.back().detail.get("advance_events",[]):ticks+=1 if event.get("ground",false) else 0
   check(c.s.phase=="won" and c.profile.wins==1,"replay reaches ending and awards once")
   print("INVESTMENTS ",JSON.stringify(c.model.s.gate_mods)," EXPECTED ",JSON.stringify(endpoint.gate_mods))
   check(c.model.s.deck==endpoint.deck and JSON.parse_string(JSON.stringify(c.model.s.gate_mods))==endpoint.gate_mods,"copies and investments reproduce exactly")
   comparisons.append({"gun":endpoint.gun,"source":label,"won":c.s.phase=="won","turns":c.model.s.turns,"fights":fights,"emergency_uses":emergencies,"minimum_remaining_including_emergency":minimum_ammo,"ground_fire_hits_during_fire_actions":ticks,"slow_applications":slows,"final_deck":c.model.s.deck.size()})
   print("REPLAY ",JSON.stringify(comparisons.back()))
 FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"runs":comparisons},"  "))
 print("PLAYTEST REWORK COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
