extends "res://tests/focus_build_climb.gd"
var role_build:=false
func choose_ammo(c,options: Array)->String:
 if role_build and c.first_ammo_reward() and options.has("bore"):return "bore"
 if role_build and not c.first_ammo_reward() and options.has("disrupt") and c.model.s.deck.count("disrupt")<1:return "disrupt"
 return super.choose_ammo(c,options)
func command(c,item: Dictionary)->bool:
 # keep: a subclass chose the gate option on purpose (growth_v2_climb, 2026-11-10).
 if item.action=="gate" and not item.get("keep",false):
  var preferred: String=["cadence","efficiency","conduction","cadence"][mini(3,int(c.s.region))]
  if preferred=="cadence" and c.s.gun=="amplifier":preferred="efficiency"
  if c.gate_options().has(preferred):item=item.duplicate(true);item.id=preferred
 return super.command(c,item)
func _run()->void:
 output=OS.get_environment("QA_OUTPUT_DIR")
 if not output.replace("\\","/").contains("/qa_runtime/playtest_rework_20261103/"):quit(2);return
 solver=preload("res://tests/fire_control_solver.gd").new()
 route_policy="safe";acquisition_policy="refit"
 var selected:=OS.get_environment("QA_GUNS")
 if selected.is_empty():selected="single,burst,scatter,heavy,amplifier"
 role_build=OS.get_environment("QA_ROLE_BUILD")=="fire"
 for gun in selected.split(","):
  run_gun=gun;run_seed=731042;commands=[]
  preferred_core={"single":"siege_drive","burst":"volley_drive","scatter":"volley_drive","heavy":"thermal_drive","amplifier":"siege_drive"}[gun]
  var c=Campaign.new();c.start(gun,run_seed,0,"balanced",4,"carrier",true)
  check(c.model.Roles.enabled(c.model.s) and c.s.map_version==4,"new map and role rules enabled")
  roundtrip(c)
  var won: bool=await play_run(c)
  endpoints.append({"gun":gun,"seed":run_seed,"role_build":role_build,"won":won,"region":int(c.s.region)+1,"phase":c.s.phase,"deck":c.model.s.deck,"parts":c.s.equipped_parts,"gate_mods":c.model.s.gate_mods,"commands":commands.duplicate(true)})
  check(won,"reworked full climb "+gun);write_report()
 print("PLAYTEST REWORK COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
