extends SceneTree
const Case=preload("res://redesign/samples/hud/combat_hud.tscn")
const JourneyCase=preload("res://redesign/samples/hud/combat_journey_hud.tscn")
const Content=preload("res://redesign/content.gd")
var out: String
var states: Dictionary={}
func _initialize()->void:call_deferred("run")
func settle()->void:
 for i in range(12):await process_frame
func record(id:String,p:Control)->void:
 await settle()
 var rounds:Array=[]
 for i in range(p.model.s.magazine.size()):
  rounds.append({"id":p.model.s.magazine[i],"name":p.node("Name%d"%i).text,"value":p.node("Value%d"%i).text,"role":p.node("Role%d"%i).text,"active":p.node("Value%d"%i).visible,"removed":p.eject_selected.has(i)})
 var buttons:Dictionary={}
 for key in ["Fire","Reload","Cool","EjectApply"]:
  buttons[key]={"name":p.node(key+"Name").text,"cost":p.node(key+"Cost").text,"disabled":p.node(key).disabled}
 states[id]={"rounds":rounds,"capacity":p.model.capacity(),"heat":p.model.s.heat,"limit":Content.heat_limit(p.model.s),"forecast":p.last_prediction.get("heat",{}).duplicate(true),"gun":p.model.s.gun,"weapon":p.node("Weapon").text,"title":p.node("Title").text if p.node("Title")!=null else "첫 관문 · 보스","bag":p.node("Bag").text,"parts":p.node("Parts").text,"eject_mode":p.eject_mode,"selected":p.eject_selected.duplicate(),"ejection_remaining":p.model.ejection_remaining(),"buttons":buttons,"source":"Actual campaign/model commands; separate QA save"}
 await RenderingServer.frame_post_draw
 var err=root.get_texture().get_image().save_png(out.path_join(id+"_source.png"))
 if err!=OK:push_error("Capture failed");quit(2)
func run()->void:
 out=OS.get_environment("QA_OUTPUT_DIR")
 if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/combat_hud_20261031/"):quit(3);return
 root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
 var p=JourneyCase.instantiate();p.resume_saved=false;root.add_child(p);await settle()
 await record("loaded",p)
 if not p.model.fire():push_error("Journey fire failed");quit(2);return
 p.refresh();await record("partial",p)
 p.queue_free();await settle()
 p=Case.instantiate();p.resume_saved=false;root.add_child(p);await settle()
 p.gun_index=0;p.case_index=1;p.mount(false);await settle()
 p.toggle_ejection();p.select_ejection(1);await record("ejection",p)
 p.gun_index=3;p.case_index=1;p.mount(false);await record("nine",p)
 var found:=false
 for gun in range(5):
  if found:break
  for battle in range(4):
   if found:break
   p.gun_index=gun;p.case_index=battle;p.mount(false)
   for action in range(5):
    if p.model.s.phase!="ready" or p.model.s.magazine.is_empty():break
    p.refresh()
    if float(p.last_prediction.get("heat",{}).get("forced_probability",0))>0:
     await record("danger",p);found=true;break
    if not p.model.fire():break
 if not found:push_error("No natural overheat preview found");quit(4);return
 FileAccess.open(out.path_join("states.json"),FileAccess.WRITE).store_string(JSON.stringify(states,"  "))
 print("PIXEL STUDY SOURCE COMPLETE states=%d"%states.size())
 p.queue_free();await settle();quit()
