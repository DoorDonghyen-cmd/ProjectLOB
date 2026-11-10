extends "res://tests/ui_readability_ui.gd"
func load_run(path: String):
 var c=Campaign.new()
 check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string("res://../"+path))),"earned presentation state restores")
 return c
func frame(label: String,bottom: bool=false) -> void:
 await settle()
 var bar=host.main_scroll.get_v_scroll_bar()
 host.main_scroll.scroll_vertical=int(maxf(0,bar.max_value-bar.page)) if bottom else 0
 await settle()
 await capture(label)
func modern_place():
 var c=Campaign.new();c.start("burst",17,0,"balanced",Campaign.Content.RouteMap.VERSION,"carrier",true);c.advance_departure(true)
 var rooms: Array=c.current_nodes()
 var wanted: Dictionary=rooms.filter(func(room):return Campaign.Content.room_kind(room)=="workshop")[0]
 var path: Array=[wanted]
 while int(path[0].floor)>1:
  for previous in rooms:
   if previous.next.has(path[0].id):path.push_front(previous);break
 for room in path:
  check(c.enter(int(room.id)),"presentation fixture follows route")
  if int(room.id)==int(wanted.id):break
  match str(c.s.phase):
   "combat":
    for enemy in c.model.s.enemies:enemy.hp=0
    c.model.s.reinforcements=[];c.model.s.phase="reward";c.sync_combat()
    for stage in range(5):
     if c.s.phase!="reward":break
     check(c.reward("credits"),"presentation fixture completes reward")
   "supply","event":c.resolve("skip");c.leave()
   _:c.leave()
 return c
func run()->void:
 output=OS.get_environment("QA_OUTPUT_DIR")
 if not output.replace("\\","/").ends_with("/qa_runtime/ui_critique_20261104"):quit(2);return
 Input.emulate_mouse_from_touch=true
 for extent in [Vector2i(1280,800),Vector2i(2340,1080)]:
  var suffix: String="_%dx%d"%[extent.x,extent.y]
  var c=earned("shop_heavy_17_r1_n503")
  await mount_at(c,extent);await frame("shop_arrival"+suffix)
  await tap("Offer1");await frame("shop_selected_top"+suffix);await frame("shop_selected_bottom"+suffix,true)
  await mount_at(modern_place(),extent);await frame("workshop_top"+suffix);await frame("workshop_bottom"+suffix,true)
  c=load_run("qa_runtime/core_choice_20261103/climb_fresh17/won_heavy_17.json")
  await mount_at(c,extent)
  if c.restoration_pending():await tap("story_restore")
  if host.find_child("story_results",true,false)!=null:await tap("story_results")
  check(host.find_child("retry",true,false)!=null,"earned victory reaches actual results through public story actions")
  await frame("results_won_top"+suffix);await frame("results_won_bottom"+suffix,true)
  c=earned("combat_heavy_17_r1_n101")
  c.s.phase="lost";c.model.s.phase="lost";c.model.s.loss_reason="contact"
  c.s.message="" # Explicit presentation-only failure fixture; no fake earned statistics.
  await mount_at(c,extent);await frame("results_lost_top"+suffix);await frame("results_lost_bottom"+suffix,true)
 if is_instance_valid(host):host.free()
 print("UI CRITIQUE CAPTURE COMPLETE checks=%d failures=%d"%[checks,failures.size()])
 await settle();quit(0 if failures.is_empty() else 1)
