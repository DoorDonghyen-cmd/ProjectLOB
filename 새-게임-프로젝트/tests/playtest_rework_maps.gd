extends SceneTree
const Data=preload("res://redesign/campaign_content.gd")
const Campaign=preload("res://redesign/campaign.gd")
var checks:=0
var failures: Array=[]
func _initialize()->void:run.call_deferred()
func check(ok: bool,label: String)->void:
 checks+=1
 if not ok:failures.append(label);print("FAIL "+label)
func bounds(rooms: Array,shortcuts: bool)->Dictionary:
 var states: Dictionary={}
 var max_rest:=0
 for room in rooms:
  var cost:=1 if room.kind=="combat" else 0
  var minimum:=cost if room.floor==1 else 999
  var rest:=0
  for previous in rooms:
   if not previous.next.has(room.id) or (not shortcuts and previous.shortcuts.has(room.id)):continue
   check(states.has(previous.id),"forward graph")
   minimum=mini(minimum,states[previous.id].minimum+cost)
   if room.kind not in ["combat","boss"]:rest=maxi(rest,states[previous.id].rest+1)
  check(minimum<999,"every room reachable")
  max_rest=maxi(rest,max_rest);states[room.id]={"minimum":minimum,"rest":rest}
 return {"minimum":states[rooms.back().id].minimum,"rest":max_rest}
func run()->void:
 var output:=OS.get_environment("QA_OUTPUT_DIR")
 if not output.replace("\\","/").contains("/qa_runtime/playtest_rework_20261103/"):quit(2);return
 var old=load("res://../qa_runtime/playtest_rework_20261103/before/새-게임-프로젝트/redesign/route_map.gd")
 var probe: Array=Data.RouteMap.generate(0,731042,4)
 var expected: Array=probe.duplicate(true)
 probe[0].next.clear();probe[0].kind="event"
 check(Data.RouteMap.generate(0,731042,4)==expected,"callers cannot mutate cached route generation")
 var summaries: Array=[]
 for region in range(5):
  var modified:=0
  var least:=99
  for seed_value in range(1000):
   var prior: Array=old.generate(region,seed_value,3)
   check(prior==Data.RouteMap.generate(region,seed_value,3),"frozen v3 graph "+str(region)+"/"+str(seed_value))
   if seed_value<20:check(old.generate(region,seed_value,2)==Data.RouteMap.generate(region,seed_value,2),"frozen v2")
   var current: Array=Data.RouteMap.generate(region,seed_value,4)
   for i in range(prior.size()):
    check(current[i].id==prior[i].id and current[i].next==prior[i].next and current[i].shortcuts==prior[i].shortcuts,"edges and shortcut preserved")
    if prior[i].kind in ["shop","supply","boss"] or prior[i].workshop:check(current[i].kind==prior[i].kind and current[i].workshop==prior[i].workshop,"facilities and gate preserved")
    if current[i].kind!=prior[i].kind:modified+=1
   for shortcuts in [false,true]:
    var result:=bounds(current,shortcuts)
    check(result.minimum>=(3 if shortcuts else 4),"minimum combat density "+str(region)+"/"+str(seed_value))
    check(result.rest<=2,"maximum two consecutive noncombat rooms")
    least=mini(least,result.minimum)
  summaries.append({"region":region,"minimum":least,"converted_optional_rooms":modified})
  print("REGION ",region," ",summaries.back())
 FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"regions":summaries},"  "))
 print("PLAYTEST REWORK COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
