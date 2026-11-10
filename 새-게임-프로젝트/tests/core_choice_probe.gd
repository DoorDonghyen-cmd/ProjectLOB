extends "res://tests/build_roles_rules.gd"
const Search=preload("res://tests/fire_control_solver.gd")
const CASES=[
 ["fire_r2","build_roles_20261103/climb_earned/gate_heavy_17_r2.json","thermal_drive","inferno"],
 ["fire_r3","build_roles_20261103/climb_earned/gate_heavy_17_r3.json","thermal_drive","inferno"],
 ["fire_r4","build_roles_20261103/climb_earned/gate_heavy_17_r4.json","thermal_drive","inferno"],
 ["control_mismatch","build_roles_20261103/climb_earned/gate_heavy_17_r4.json","thermal_drive","momentum"],
 ["fire_mismatch","build_roles_20261103/climb_earned/gate_burst_17_r2.json","volley_drive","inferno"],
 ["coil_value","economy_roles_20261103/climb_carrier_heavy/gate_heavy_17_r3.json","coil",""],
 ["duplex_value","economy_roles_20261103/climb_scout_burst/gate_burst_731042_r4.json","duplex",""],
 ["third_value","economy_roles_20261103/climb_scout_burst/gate_burst_731042_r4.json","third_striker",""],
 ["rammer_value","economy_roles_20261103/climb_scout_burst/gate_burst_731042_r4.json","rammer",""],
 ["position_swap","economy_roles_20261103/climb_expedition_copy/gate_single_931104_r3.json","afterburner","sequencer"]]
func run()->void:
 output=OS.get_environment("QA_OUTPUT_DIR")
 if not output.replace("\\","/").contains("/qa_runtime/core_choice_20261103/"):quit(2);return
 for item in CASES:
  for swap in [false,true]:
   var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../qa_runtime/"+item[1]))
   var c=Campaign.new();check(c.restore_state(source),"restore actual earned gate")
   if OS.get_environment("QA_SPECIALIST")=="1":
    c.s.specialist_core_version=1;c.model.s.specialist_core_version=1
   if swap:
    check(c.equip(item[2]) if item[3].is_empty() else c.replace_part(item[2],item[3]),"legal owned part change")
   var loadout: Array=c.s.equipped_parts.duplicate()
   check(c.gate("skip") and c.depart_gate(),"same gate departure without extra upgrade")
   check(c.enter(int(c.choices()[0].id)),"same first linked next battle")
   var initial: Dictionary=c.model.s.duplicate(true)
   var search=Search.new();var start:=Time.get_ticks_msec()
   var path: Array=search.solve(c.model)
   var row: Dictionary={"case":item[0],"source":item[1],"swap":swap,"from":item[2],"to":item[3],"node":c.s.node,"parts":loadout,"deck":initial.deck,"levels":initial.engine.levels,"solved":not path.is_empty(),"fire":0,"cool":0,"reload":0,"eject":0,"emergency":0,"turns":0,"forced_turns":0,"burn_damage":0,"remaining":0,"margin":1000000,"max_direct_hit":0,"path":path,"search_ms":Time.get_ticks_msec()-start}
   for step in path:
    if step.action=="fire":c.model.s.fire_heat_trial.rounds=int(step.get("rounds",0))
    var ok: bool
    match step.action:
     "fire":ok=c.model.fire()
     "cool":ok=c.model.cool_magazine()
     "reload":ok=c.model.reload_magazine()
     "emergency":ok=c.model.emergency_resupply()
     "eject":ok=c.model.eject_magazine_rounds(step.indices)
    check(ok,"accepted battle command")
    row[step.action]+=1
    var state: Dictionary=c.model.s
    row.turns=int(state.turns)-int(initial.turns)
    row.remaining=c.model.Reserve.remaining(state)
    for enemy in state.enemies+c.model.Ranged.active(state):
     if int(enemy.hp)>0:row.margin=mini(row.margin,int(enemy.distance))
    var detail: Dictionary=state.history.back().detail
    row.forced_turns+=int(detail.get("forced_cooling",{}).get("elapsed",0))
    for event in detail.get("advance_events",[])+detail.get("forced_cooling",{}).get("advance_events",[]):
     if event.kind=="burn":row.burn_damage+=int(event.damage)
    for shot_result in detail.get("results",[]):row.max_direct_hit=maxi(row.max_direct_hit,int(shot_result.damage))
    c.sync_combat();check(c.save()==OK,"comparison saves")
    var resumed=Campaign.new();check(resumed.restore() and canonical(resumed.model.s)==canonical(c.model.s),"comparison resumes same combat")
   if not path.is_empty():check(c.s.phase=="reward","path reaches reward")
   row.phase=c.s.phase
   records.append(row)
   FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"note":"Actual owned-part branches; bounded search sees future draws and RNG. Not optimality or human win rate.","comparisons":records},"  "))
   print("CORE CHOICE ",item[0]," swap=",swap," solved=",row.solved," turns=",row.turns," remain=",row.remaining," margin=",row.margin)
   await process_frame
 print("CORE CHOICE COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
