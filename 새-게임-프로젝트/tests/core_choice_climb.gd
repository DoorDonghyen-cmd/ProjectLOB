extends "res://tests/build_roles_climb.gd"
func choose_parts(c)->bool:
 # Keep the earned starting core until the preferred replacement is actually owned.
 var desired:=preferred_core
 if preferred_core=="inferno" and not c.s.parts.has("inferno") and c.s.parts.has("thermal_drive"):preferred_core="thermal_drive"
 var ok: bool=super.choose_parts(c)
 preferred_core=desired
 return ok
func command(c,item: Dictionary)->bool:
 if item.action=="reward" and c.engine_reward() and preferred_core=="inferno":
  item=item.duplicate(true);item.id="thermal_drive"
 return super.command(c,item)
func _run()->void:
 output=OS.get_environment("QA_OUTPUT_DIR")
 if not output.replace("\\","/").contains("/qa_runtime/core_choice_20261103/"):quit(2);return
 solver=preload("res://tests/fire_control_solver.gd").new();route_policy="safe";acquisition_policy="refit";rule_version=3
 run_gun="heavy";run_seed=int(OS.get_environment("QA_SEED")) if not OS.get_environment("QA_SEED").is_empty() else 17;build_kind="fire";role_build=true
 preferred_core=OS.get_environment("QA_CORE")
 if preferred_core not in ["thermal_drive","inferno"]:quit(2);return
 var c=Campaign.new()
 if OS.get_environment("QA_FRESH")=="1":
  c.start(run_gun,run_seed,0,"balanced",4,"carrier",true)
 else:
  check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string("res://../qa_runtime/build_roles_20261103/climb_earned/gate_heavy_17_r2.json"))),"earned r2 specialist ownership restores")
  if OS.get_environment("QA_SPECIALIST")=="1":c.s.specialist_core_version=1;c.model.s.specialist_core_version=1
  if preferred_core=="inferno":check(c.replace_part("thermal_drive","inferno"),"legally equip owned specialist")
 roundtrip(c)
 var won: bool=await play_run(c)
 endpoints.append({"seed":run_seed,"core":preferred_core,"won":won,"phase":c.s.phase,"region":int(c.s.region)+1,"deck":c.model.s.deck,"parts":c.s.equipped_parts,"credits":c.s.credits,"commands":commands})
 check(won,"owned core reaches ending after three earned regions")
 for battle in battles:battle.remaining=int(battle.metrics.get("remaining",battle.remaining))
 write_report()
 print("CORE CHOICE COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
