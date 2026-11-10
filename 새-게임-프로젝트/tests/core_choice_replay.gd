extends "res://tests/core_choice_climb.gd"
func _run()->void:
 output=OS.get_environment("QA_OUTPUT_DIR")
 if not output.replace("\\","/").contains("/qa_runtime/core_choice_20261103/"):quit(2);return
 var rows: Array=[]
 var labels:=OS.get_environment("QA_REPLAY_LABELS")
 if labels.is_empty():labels="thermal,inferno,inherited,fresh17,fresh731042"
 for label in labels.split(","):
  var source:=JSON.parse_string(FileAccess.get_file_as_string("res://../qa_runtime/core_choice_20261103/climb_"+label+"/balance.json")) as Dictionary
  if source.endpoints.is_empty():check(false,"completed branch exists "+label);continue
  var endpoint: Dictionary=source.endpoints[0]
  var c=Campaign.new();run_gun="heavy";run_seed=int(endpoint.get("seed",731042 if label.begins_with("fresh731042") else 17));preferred_core=endpoint.core
  if label.begins_with("fresh"):
   c.start(run_gun,run_seed,0,"balanced",4,"carrier",true)
  else:
   check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string("res://../qa_runtime/build_roles_20261103/climb_earned/gate_heavy_17_r2.json"))),"original earned branch restores")
   if label=="inherited":c.s.specialist_core_version=1;c.model.s.specialist_core_version=1
   if preferred_core=="inferno":check(c.replace_part("thermal_drive","inferno"),"initial replay swap uses owned core")
  commands=[];metrics={};var fights:=0
  for step in endpoint.commands:
   var phase: String=c.s.phase
   if not command(c,step.duplicate(true)):break
   if step.has("turns"):check(c.model.s.turns==int(step.turns),"recorded command timing agrees")
   if phase=="combat" and c.s.phase=="reward":fights+=1
  check(c.s.phase=="won" and c.profile.wins==1,"single ending after replay "+label)
  check(c.model.s.deck==endpoint.deck and c.s.equipped_parts==endpoint.parts and c.s.credits==endpoint.credits,"same final deck parts and wallet "+label)
  rows.append({"label":label,"fights":fights,"won":c.s.phase=="won"})
  print("CORE REPLAY ",JSON.stringify(rows.back()))
  FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"runs":rows},"  "))
 print("CORE CHOICE COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
