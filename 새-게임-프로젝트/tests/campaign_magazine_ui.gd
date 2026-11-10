extends SceneTree
const Campaign=preload("res://redesign/campaign.gd")
const Model=preload("res://redesign/model.gd")
var host
var checks:=0
var failures: Array=[]
var output: String
func _initialize()->void:run.call_deferred()
func check(ok: bool,label: String)->bool:
 checks+=1
 if not ok:failures.append(label);print("FAIL: "+label)
 return ok
func settle()->void:
 for i in range(6):await process_frame
func canonical(value):return JSON.parse_string(JSON.stringify(value))
func capture(label: String)->void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(label+".png"))
func tap(id: String)->void:
 var button: Control=host.find_child(id,true,false)
 if not check(button!=null and button.is_visible_in_tree(),"visible public input "+id):return
 var scroll: Node=button.get_parent()
 while scroll!=null:
  if scroll is ScrollContainer:scroll.ensure_control_visible(button)
  scroll=scroll.get_parent()
 await settle()
 var point: Vector2=button.get_global_transform_with_canvas()*(button.size*0.5)
 for pressed in [true,false]:
  var event:=InputEventScreenTouch.new();event.index=0;event.position=point;event.pressed=pressed
  root.push_input(event,true);await process_frame
 var started:=Time.get_ticks_msec()
 while host.busy and Time.get_ticks_msec()-started<20000:await process_frame
 check(not host.busy,"action finishes "+id)
 await settle()
func mount(c)->void:
 if is_instance_valid(host):host.free()
 host=load("res://redesign/main.tscn").instantiate()
 root.add_child(host)
 host.campaign=c;host.model=c.model;host.page="run";host.redraw()
 await settle()
 if is_instance_valid(host.campaign_hud):host.campaign_hud.board.speed_scale=0.01
func hud_bounds()->void:
 var hud: Control=host.campaign_hud
 check(is_instance_valid(hud),"campaign owns real HUD")
 for id in ["Battle","Menu","Fire","Cool","Reload","MagazineTitle","HeatGroup"]:
  var item: Control=hud.node(id)
  check(hud.get_global_rect().encloses(item.get_global_rect()),"HUD contains "+id)
 check(hud.node("Select0").size.y>=44,"card remains a touch target")
 check(hud.model==host.campaign.model,"HUD and campaign share resolver")

func run()->void:
 if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/campaign_magazine_20261101/"):quit(2);return
 output=OS.get_environment("QA_OUTPUT_DIR");Input.emulate_mouse_from_touch=true
 # Repeatable only inside the isolated QA directory checked above.
 if FileAccess.file_exists(Campaign.SAVE):DirAccess.remove_absolute(Campaign.SAVE)
 host=load("res://redesign/main.tscn").instantiate();root.add_child(host);await settle()
 host.preparation_seed="731042";host._open_preparation();await settle()
 await tap("start_single")
 check(host.campaign.magazine_enabled(),"production new-run button opts in")
 host._campaign_action("departure_skip");await settle()
 host._campaign_action("enter",101);await settle();hud_bounds()
 var first=canonical({"campaign":host.campaign.s,"combat":host.model.s,"profile":host.campaign.profile})
 await tap("Select1");await tap("EjectToggle")
 check(host.model.ejection_remaining()==1,"touch removes selected middle round")
 var expected=canonical(host.model.s)
 var restored=Campaign.new();check(restored.restore(),"ejection saved to main campaign")
 check(canonical(restored.model.s)==expected,"all piles RNG and ejection quota resume exactly")
 await mount(restored)
 await tap("Menu");await tap("Pressure")
 check(host.campaign_hud.node("DetailBody").text.contains("관문"),"full route help replaces five-fight study")
 await tap("CloseDetail")
 await tap("Menu");await tap("Other")
 check(host.page=="menu" and not is_instance_valid(host.campaign_hud),"menu detaches HUD and restores main scale")
 host._resume();await settle();hud_bounds()
 check(canonical(host.model.s)==expected,"title continue resumes exact mid-magazine")
 # Replay one earned complete climb: real combat touch input and production
 # campaign action handlers for route, purchases, rewards and gate departure.
 var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(output.get_base_dir().path_join("rules/balance.json")))
 var endpoint: Dictionary={}
 for row in report.endpoints:
  if row.gun=="single" and row.won:endpoint=row;break
 if not check(not endpoint.is_empty(),"earned complete single route available"):quit(1);return
 var c=Campaign.new();check(c.restore_state(first),"production opening restores")
 await mount(c)
 var regions: Dictionary={}
 for step in endpoint.commands:
  if step.action=="enter" and int(step.id)==101:continue
  var action: String=step.action
  print("UI STEP ",action," ",step.get("id","")," at ",c.s.node," phase=",c.s.phase)
  if action in ["fire","cool","reload","emergency","eject"]:
   if not check(is_instance_valid(host.campaign_hud),"combat input has active HUD"):break
   if not regions.has(int(c.s.region)):
    regions[int(c.s.region)]=true
    hud_bounds();await capture("region_%d"%(int(c.s.region)+1))
    await tap("Parts");await tap("CloseDetail")
   host.campaign_hud.board.speed_scale=0.01
   if action=="eject":
    for index in step.indices:await tap("Select%d"%int(index))
    await tap("EjectToggle")
   else:await tap({"fire":"Fire","cool":"Cool","reload":"Reload","emergency":"Reload"}[action])
  else:
   host._campaign_action(action,step.get("id",""),str(step.get("replace","")) if action in ["reward","buy"] else str(step.get("ammo","")),str(step.get("replace","")))
   await settle()
  if host.campaign.s.phase=="gate" and action=="reward":await capture("gate_%d"%(int(c.s.region)+1))
  check(not host.busy,"no stranded busy flag after "+action)
 check(c.s.phase=="won" and c.s.region==4,"public combat with real campaign handlers reaches final ending")
 check(regions.size()==5,"all five regional renderers exercised")
 await capture("ending")
 # Narrow viewport regressions reuse an earned late encounter, not a forged win.
 var late_file:=output.get_base_dir().path_join("rules/combat_single_731042_r5_n41001.json")
 if not FileAccess.file_exists(late_file):
  var folder:=DirAccess.open(output.get_base_dir().path_join("rules"))
  for file in folder.get_files():
   if file.begins_with("combat_single_731042_r5_"):late_file=folder.get_current_dir().path_join(file);break
 for extent in [Vector2i(844,390),Vector2i(1008,454),Vector2i(1280,800)]:
  var late=Campaign.new();check(late.restore_state(JSON.parse_string(FileAccess.get_file_as_string(late_file))),"earned late encounter restores")
  root.size=extent;await mount(late);hud_bounds()
  var same_hud=host.campaign_hud
  host.redraw();await settle();check(host.campaign_hud==same_hud,"resize/redraw preserves active HUD")
  await capture("late_%dx%d"%[extent.x,extent.y])
  await tap("Select1");await tap("EjectToggle")
  check(late.model.ejection_remaining()==1,"late-region ejection input")
 # Explicit capacity fixture checks a legal maximum extension independently.
 var large=Campaign.new();large.start("heavy",731042,0,"balanced",3,"carrier",true)
 large.s.slots=2;large.s.parts=["supply"];large.s.equipped_parts=["supply"]
 check(large.enter(101),"capacity fixture enters encounter")
 check(large.model.capacity()==12,"expanded weapon has twelve sockets")
 root.size=Vector2i(844,390);await mount(large);hud_bounds()
 check(host.campaign_hud.slot_count==12,"all expanded slots instantiated")
 await tap("Select11");await tap("EjectToggle")
 check(large.model.s.magazine.size()==11,"last expanded round can be removed by touch")
 await capture("expanded_twelve_slots")
 var legacy=Campaign.new();legacy.start("single",731042,0,"balanced",3,"carrier");legacy.enter(101)
 await mount(legacy)
 check(not is_instance_valid(host.campaign_hud) and host.main_scroll.visible,"legacy save keeps original combat screen")
 var result=FileAccess.open(output.path_join("result.json"),FileAccess.WRITE)
 result.store_string(JSON.stringify({"checks":checks,"failures":failures,"regions":regions.keys()},"  "));result.close()
 host.free();await settle()
 print("CAMPAIGN MAGAZINE UI COMPLETE checks=%d failures=%d"%[checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
