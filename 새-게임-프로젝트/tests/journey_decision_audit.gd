extends SceneTree
## Diagnostic replay of earned checkpoints. This is not a human play/win-rate test.
const Journey=preload("res://redesign/magazine_journey.gd")
const Model=Journey.Model
const Forecast=preload("res://redesign/forecast.gd")
const Solver=preload("res://tests/weapon_magazine_solver.gd")
var rows: Array=[]
var failures: Array=[]
func _initialize()->void:call_deferred("run")
func public_result(state: Dictionary)->Dictionary:
 var f: Dictionary=Forecast.analyze(state,true) if not state.magazine.is_empty() else {}
 var hp:=0
 for e in f.get("enemies",[]):hp+=maxi(0,int(e.get("hp_max",e.hp)))
 return {"loss":f.get("lost_probability",1.0 if f.get("phase","")=="lost" else 0.0),"hp_max":hp,"overheat":f.get("heat",{}).get("forced_probability",0),"turns_max":f.get("heat",{}).get("turns_max",0),"shots":f.get("shots",[]).size(),"random":f.get("random",false)}
func run()->void:
 var out:=OS.get_environment("QA_OUTPUT_DIR")
 if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/journey_review_20261101/"):quit(2);return
 var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../qa_runtime/magazine_journey_20261031/rules/rules.json"))
 for run_data in source.runs:
  if int(run_data.policy)!=0:continue
  var j=Journey.new()
  if not j.start(run_data.gun):failures.append("start");continue
  for step in range(40):
   if j.phase()=="complete":break
   if j.phase()=="map":
    if not j.advance():failures.append("advance")
   elif j.phase() in ["reward","supply"]:
    var id: String=""
    for a in run_data.acquisitions:
     if int(a.node)==int(j.campaign.s.node) and a.source==j.phase() and j.options().has(a.id):id=a.id;break
    if not j.choose(id):failures.append("choose "+id);break
   elif j.phase()=="combat":
    var m=j.campaign.model
    var path: Array=[]
    for b in run_data.battles:
     if int(b.node)==int(j.campaign.s.node):path=b.path;break
    var row: Dictionary={"gun":run_data.gun,"node":j.campaign.s.node,"deck":m.s.deck.duplicate(),"core_before":m.s.get("engine",{}).duplicate(true),"actions":[]}
    for action in path:
     var base:=public_result(m.s)
     var record: Dictionary={"action":action,"magazine":m.s.magazine.duplicate(),"heat":m.s.heat,"fire":base,"ejection_alternatives":[]}
     for choice in ["cool","swap"]:
      var copy=Model.new();copy.s=Model.simulation_state(m.s)
      var ok:=Solver.command(copy,choice)
      record[choice]={"legal":ok,"loss":copy.s.phase=="lost","cost":int(copy.s.turns)-int(m.s.turns)}
     # Inspect all single-round ejections in the naturally earned order. A
     # different result is a choice opportunity, not proof of a better run.
     for index in range(m.s.magazine.size()):
      var copy=Model.new();copy.s=Model.simulation_state(m.s)
      if not copy.eject_magazine_rounds([index]) or copy.s.magazine.is_empty():continue
      var other:=public_result(copy.s)
      if other!=base:record.ejection_alternatives.append({"index":index,"ammo":m.s.magazine[index],"fire":other})
     if not Solver.command(m,action):failures.append("illegal replay");break
     var results: Array=m.s.history.back().detail.get("results",[])
     record["actual_shots"]=results.map(func(s):return {"id":s.id,"damage":s.damage,"engine_percent":s.get("engine_percent",100),"overheated":s.get("overheated",false)})
     row.actions.append(record);j.sync()
    if j.phase()!="reward":failures.append("route no longer wins")
    row["result"]=j.results.back();rows.append(row)
   else:failures.append("phase "+j.phase());break
  if j.phase()!="complete":failures.append("incomplete "+run_data.gun)
 FileAccess.open(out.path_join("decisions.json"),FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"failures":failures,"scope":"Five representative cores/reward paths, fixed seed 731042. Paths originated from hidden-RNG feasibility search; alternatives use public one-action forecasts. Neither a player strategy nor win rate."},"  "))
 print("JOURNEY DECISION AUDIT COMPLETE battles=%d failures=%d"%[rows.size(),failures.size()]);quit(0 if failures.is_empty() else 1)
