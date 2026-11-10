extends SceneTree
const Campaign=preload("res://redesign/campaign.gd")
var checks:=0
var failures: Array=[]
func _initialize()->void:run.call_deferred()
func check(ok: bool,label: String)->void:
 checks+=1
 if not ok:failures.append(label);print("FAIL "+label)
func canonical(value):return JSON.parse_string(JSON.stringify(value))
func run()->void:
 var output:=OS.get_environment("QA_OUTPUT_DIR")
 if not output.replace("\\","/").contains("/qa_runtime/playtest_rework_20261103/"):quit(2);return
 var read_mode:=OS.get_environment("QA_RESTART_PHASE")=="read"
 var c=Campaign.new()
 if not read_mode:
  var base:="res://../qa_runtime/playtest_rework_20261103/climb_incendiary/"
  var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(base+"balance.json"))
  var captured:=false
  for battle in report.battles:
   if captured:break
   var file: String=base+"combat_heavy_731042_r%d_n%d.json"%[battle.region,battle.node]
   check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(file))),"earned incendiary encounter restores")
   for action in battle.path:
    if action.action=="fire":c.model.s.fire_heat_trial.rounds=int(action.get("rounds",0));c.model.fire()
    elif action.action=="cool":c.model.cool_magazine()
    elif action.action=="reload":c.model.reload_magazine()
    elif action.action=="emergency":c.model.emergency_resupply()
    elif action.action=="eject":c.model.eject_magazine_rounds(action.indices)
    c.sync_combat()
    if c.s.phase=="combat" and not c.model.s.fire_zones.is_empty() and not c.model.s.magazine.is_empty():
     c.model.s.fire_heat_trial.rounds=1
     check(c.save("user://role_resume.json")==OK,"mid-flame combat saves atomically")
     captured=true;break
  check(captured,"legal earned commands reach persistent flames")
 else:
  check(c.restore("user://role_resume.json"),"separate process restores actual mid-flame save")
  check(not c.model.s.fire_zones.is_empty(),"flame duration and position survive process restart")
 check(c.model.fire(),"next partial shot accepted")
 c.sync_combat();check(c.save("user://after_resume.json")==OK,"next action resaves")
 var result: Dictionary=canonical({"campaign":c.s,"combat":c.model.s,"profile":c.profile})
 var path:=output.path_join("expected.json")
 if read_mode:
  var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
  check(result==expected,"separate-process continuation exactly preserves damage, zones, slow, heat, inventory, RNG and campaign")
 else:FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(result))
 FileAccess.open(output.path_join("read_result.json" if read_mode else "write_result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
 print("PLAYTEST REWORK COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
