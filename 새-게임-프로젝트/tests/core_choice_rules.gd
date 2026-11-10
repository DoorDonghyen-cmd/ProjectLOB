extends "res://tests/build_roles_rules.gd"
const Choice=preload("res://redesign/part_choice.gd")
const Insight=preload("res://redesign/run_insight.gd")
func run()->void:
 output=OS.get_environment("QA_OUTPUT_DIR")
 if not output.replace("\\","/").contains("/qa_runtime/core_choice_20261103/"):quit(2);return
 for level in [0,4,8,14]:
  for new_rule in [false,true]:
   var m=build(["bore","basic_p2"],["inferno","coil"])
   m.s.growth_version=1;m.s.gate_mods.growth=3;m.s.engine.levels.thermal_drive=level
   if new_rule:m.s.specialist_core_version=1
   targets(m,3,1000,3)
   var inherited: int=level/2 if new_rule else 0
   var original_levels: Dictionary=m.s.engine.levels.duplicate()
   var r:=shot(m)
   check(r.burn_tick==4+inherited,"new specialist inherits only earned thermal burn; legacy is fixed")
   check(r.fire_zones[0].damage==6+inherited and r.fire_zones[0].radius==3,"ground fire/coil reuse inherited burn exactly once")
   check(r.engine_percent==100 if r.has("engine_percent") else Choice.Engines.percent(m.s,["inferno"],1,true)==100,"no thermal direct multiplier transfers")
   check(m.reload_cost()==3,"inferno retains real extra reload action")
   for e in m.s.enemies:e.hp=0
   m.s.phase="reward";Choice.Engines.settle(m.s,["inferno"])
   check(m.s.engine.levels==original_levels,"specialist does not earn thermal growth")
 # Alternate old/new/old scatter forecasts in the same cache, then compare real targets.
 var scatter=build(["bore"],["inferno"],"scatter")
 scatter.s.engine.levels.thermal_drive=8
 targets(scatter,3,1000,3)
 for enemy in scatter.s.enemies:enemy.speed=0
 var legacy_forecast: Dictionary={}
 for version in [0,1,0]:
  if version==1:scatter.s.specialist_core_version=1
  else:scatter.s.erase("specialist_core_version")
  var original: Dictionary=canonical(scatter.s)
  var prediction: Dictionary=Forecast.analyze(scatter.s,true)
  check(canonical(scatter.s)==original,"scatter forecast preserves source state and RNG")
  check(prediction.shots[0].burn_tick==(8 if version==1 else 4),"scatter cache follows specialist rule")
  if legacy_forecast.is_empty():legacy_forecast=prediction
  elif version==0:check(canonical(prediction)==canonical(legacy_forecast),"returning to legacy reuses only legacy results")
  else:check(canonical(prediction.enemies)!=canonical(legacy_forecast.enemies),"specialist burn changes predicted enemy HP ranges")
  for seed_value in range(1,13):
   var actual=Model.new();actual.s=original.duplicate(true);actual.s.rng=seed_value
   check(actual.fire(),"scatter candidate fires real command")
   if seed_value==1:FileAccess.open(output.path_join("scatter_%d.json"%version),FileAccess.WRITE).store_string(JSON.stringify({"prediction":prediction,"actual":actual.s,"before":original},"  "))
   for i in range(actual.s.enemies.size()):
    var hp: int=actual.s.enemies[i].hp
    check(hp>=prediction.enemies[i].hp_min and hp<=prediction.enemies[i].hp_max,"actual scatter HP remains inside correct rule forecast")
 # Burn/control/multiple rounds exercise branch merging, including pre-existing zones.
 for rounds in [["bore","bore"],["disrupt","bore"],["bore","disrupt"]]:
  var multi=build(rounds,["inferno"],"scatter")
  multi.s.specialist_core_version=1;multi.s.engine.levels.thermal_drive=8
  multi.s.fire_heat_trial.rounds=2
  targets(multi,3,50,3)
  multi.s.fire_zones=[{"center":1000,"radius":3,"left":2,"damage":2}]
  var original: Dictionary=canonical(multi.s)
  var prediction: Dictionary=Forecast.analyze(multi.s,true)
  check(canonical(multi.s)==original,"multi-round forecast preserves existing zones and RNG")
  for seed_value in range(1,25):
   var actual=Model.new();actual.s=original.duplicate(true);actual.s.rng=seed_value
   check(actual.fire(),"mixed scatter sequence fires")
   for i in range(actual.s.enemies.size()):
    var e: Dictionary=actual.s.enemies[i];var p: Dictionary=prediction.enemies[i]
    check(e.hp>=p.hp_min and e.hp<=p.hp_max,"mixed actual HP lies in branch range")
    check(e.distance>=p.distance_min and e.distance<=p.distance_max,"mixed actual movement lies in branch range")
 for id in ["thermal_drive","volley_drive","siege_drive","momentum","arc_splitter"]:
  var m=build(["bore","precise_p2","arc"],[id])
  targets(m,3,1000,3)
  var legacy=Model.new();check(legacy.restore_state(canonical(m.s)),"unaffected core legacy fixture restores")
  m.s.specialist_core_version=1
  var a:=shot(m);var b:=shot(legacy)
  FileAccess.open(output.path_join("unaffected_"+id+".json"),FileAccess.WRITE).store_string(JSON.stringify({"a":a,"b":b,"enemies_a":m.s.enemies,"enemies_b":legacy.s.enemies},"  "))
  check(canonical(a)==canonical(b) and canonical(m.s.enemies)==canonical(legacy.s.enemies),"other core results unchanged: "+id)
 var c=Campaign.new();c.start("heavy",17,0,"balanced",4,"carrier",true)
 check(c.s.specialist_core_version==1 and c.model.s.specialist_core_version==1,"new production campaign activates versioned specialist rule")
 check(c.save()==OK,"new campaign saves")
 var restored=Campaign.new();check(restored.restore() and canonical(c.s)==canonical(restored.s) and canonical(c.model.s)==canonical(restored.model.s),"new rule is saved and restored exactly")
 var earned: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../qa_runtime/build_roles_20261103/climb_earned/gate_heavy_17_r2.json"))
 check(c.restore_state(earned) and not c.model.s.has("specialist_core_version"),"existing save retains absent specialist rule")
 var prior: Dictionary=canonical(c.model.s)
 check(c.replace_part("thermal_drive","inferno"),"owned specialist replaces one core")
 check(Choice.Engines.level(c.model.s,"thermal_drive")==8 and Content.burn_damage(c.model.s)==4,"legacy swap preserves growth record but keeps old burn damage")
 check(c.replace_part("inferno","thermal_drive"),"original core can be restored")
 check(c.model.s.engine==prior.engine and Choice.effect("thermal_drive",c.model.s).contains("2.70"),"returning restores actual grown multiplier")
 var bad=earned.duplicate(true);bad.campaign.specialist_core_version=1
 check(not restored.restore_state(bad),"mismatched campaign/combat flag rejected")
 for value in [-1,0.5,2,"1",true]:
  var state: Dictionary=prior.duplicate(true);state.specialist_core_version=value
  var model_check=Model.new();check(not model_check.restore_state(state),"malformed specialist flag rejected")
 var before: Dictionary=prior.duplicate(true);var after: Dictionary=prior.duplicate(true)
 after.equipped_parts=["inferno"];after.specialist_core_version=1
 var unchanged:=JSON.stringify(before)+JSON.stringify(after)
 check(Choice.effect("thermal_drive",before).contains("화상 +4"),"choice shows earned burn being removed")
 check(Choice.effect("inferno",after).contains("화상 +6"),"choice shows inherited specialist effect")
 check("\n".join(Choice.deltas(before,after)).contains("6 → 8"),"comparison explains real total burn delta")
 check("\n".join(Choice.deltas(before,after)).contains("기록 보존"),"comparison does not imply stored growth was deleted")
 check(JSON.stringify(before)+JSON.stringify(after)==unchanged,"choice descriptions do not consume state or RNG")
 check(Insight.reward_impact("duplex",before,[]).contains("+2"),"detail uses actual revised extra hits")
 check(Insight.reward_impact("opening",before,[]).contains("×2"),"detail uses current first-shot multiplier")
 check(Insight.reward_impact("afterburner",before,[]).contains("×3"),"detail uses current last-shot multiplier")
 FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"  "))
 print("CORE CHOICE COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)

