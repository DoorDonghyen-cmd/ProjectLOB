extends "res://tests/central_live_balance_runner.gd"
## Actual campaign transactions; no injected wins, credits, parts or late states.
func command(c,item: Dictionary)->bool:
 if item.action=="eject":
  if not check(c.model.eject_magazine_rounds(item.indices),"legal selected ejection"):return false
  c.sync_combat();commands.append(item.duplicate(true))
  return roundtrip(c)
 if item.action=="cool":
  if not check(c.model.cool_magazine(),"legal magazine cooling"):return false
  c.sync_combat()
  commands.append(item.duplicate(true))
  return roundtrip(c)
 return super.command(c,item)

func roundtrip(c)->bool:
 if c.magazine_enabled() and c.s.phase=="combat":
  check(c.model.s.phase=="ready","automatic full magazine at every combat entry")
  check(c.model.MagazineTrial.weapons_enabled(c.model.s),"campaign magazine flags retained")
 if c.magazine_enabled() and c.s.phase=="shop":
  check(not c.s.offers.any(func(o):return o.id in ["field_press","reserve"]),"no unusable field compressor offer")
  check(not c.buy_compressor_charge(),"inactive field compression cannot charge credits")
 return super.roundtrip(c)

func _run()->void:
 if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/campaign_magazine_20261101/"):quit(2);return
 output=OS.get_environment("QA_OUTPUT_DIR")
 solver=preload("res://tests/campaign_magazine_solver.gd").new()
 route_policy="safe";acquisition_policy="refit"
 var legacy=Campaign.new();legacy.start("single",731042,0,"balanced",3,"carrier")
 check(not legacy.magazine_enabled(),"legacy fixture retains original rules")
 check(legacy.enter(int(legacy.choices()[0].id)),"legacy first encounter")
 check(legacy.model.s.phase=="plan" and not legacy.model.MagazineTrial.enabled(legacy.model.s),"legacy manual loading retained")
 roundtrip(legacy)
 var guns:=OS.get_environment("QA_GUNS").split(",") if not OS.get_environment("QA_GUNS").is_empty() else PackedStringArray(["single","burst","scatter","heavy","amplifier"])
 for gun in guns:
  run_gun=gun;run_seed=731042;commands=[]
  preferred_core={"single":"siege_drive","burst":"volley_drive","scatter":"volley_drive","heavy":"thermal_drive","amplifier":"siege_drive"}[gun]
  var c=Campaign.new();c.start(gun,run_seed,0,"balanced",3,"carrier",true)
  check(c.magazine_enabled(),"new full climb explicitly opts in")
  roundtrip(c)
  print("MAGAZINE CAMPAIGN START ",gun)
  var won: bool=await play_run(c)
  endpoints.append({"gun":gun,"seed":run_seed,"won":won,"region":int(c.s.region)+1,"phase":c.s.phase,"commands":commands.duplicate(true)})
  check(won,"whole campaign reaches ending "+gun)
  write_report()
 print("CAMPAIGN MAGAZINE COMPLETE checks=%d failures=%d"%[checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
