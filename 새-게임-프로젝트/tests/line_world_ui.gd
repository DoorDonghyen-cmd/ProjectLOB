extends "res://tests/route_map_ui_runner.gd"
## Current route + place UI; the historical suite still expects retired services.
func fixture_for(role: String):
 var campaign=Campaign.new()
 campaign.start("burst",17)
 campaign.advance_departure(true)
 var rooms: Array=campaign.current_nodes()
 var wanted: Dictionary=rooms.filter(func(room):return Data.room_kind(room)==role)[0]
 var path: Array=[wanted]
 while int(path[0].floor)>1:
  for previous in rooms:
   if previous.next.has(path[0].id):path.push_front(previous);break
 for room in path:
  check(campaign.enter(int(room.id)),"fixture follows current route")
  if int(room.id)==int(wanted.id):break
  match str(campaign.s.phase):
   "combat":
    for enemy in campaign.model.s.enemies:enemy.hp=0
    campaign.model.s.reinforcements=[];campaign.model.s.phase="reward";campaign.sync_combat()
    for stage in range(3):
     if campaign.s.phase!="reward":break
     check(campaign.reward("credits"),"fixture completes current opening reward steps")
   "supply","event":campaign.resolve("skip");campaign.leave()
   _:campaign.leave()
 return campaign
func show_campaign(campaign)->void:
 await super.show_campaign(campaign)
 screen.debug_session=false;screen.redraw();await settle()
func run()->void:
 if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/maps/"):quit(2);return
 output=OS.get_environment("QA_OUTPUT_DIR")
 Input.emulate_mouse_from_touch=true
 screen=load("res://redesign/main.tscn").instantiate();screen.save_enabled=false
 root.add_child(screen);await settle()
 screen.preferences.data.motion="instant"
 for resolution in [Vector2i(1008,630),Vector2i(1280,800),Vector2i(1440,630)]:
  root.size=resolution;root.content_scale_size=resolution
  for region in range(5):
   var campaign=Campaign.new();campaign.start("single",17);campaign.advance_departure(true);campaign.s.region=region
   await show_campaign(campaign)
   check_map_fill()
   var map=screen.find_child("CityMap",true,false)
   check(map.get_script()==load("res://redesign/pipe_map/graph.gd"),"normal game uses actual map")
   for node in map.get_children():
    check(node.size.x>=48 and node.size.y>=44,"map touch targets preserved")
   var id: int=campaign.choices()[0].id
   var before:=JSON.stringify(campaign.s)
   await tap("map_node_"+str(id));await tap("city_map_details")
   check(JSON.stringify(campaign.s)==before,"selection and detail do not move or spend")
   await tap("workspace_close")
   var future: Dictionary=campaign.current_nodes().filter(func(n):return n.kind=="boss")[0]
   await tap("map_node_"+str(future.id))
   var move_button := screen.find_child("city_enter_"+str(id),true,false) as Button
   check(not move_button.visible and move_button.disabled,"future preview has no illegal move")
   await tap("map_node_"+str(id))
   check(move_button.visible and not move_button.disabled and move_button.theme == preload("res://redesign/ui/dark_primary.tres"),"available move uses the shared action theme")
   if region==0:await capture("map_%dx%d"%[resolution.x,resolution.y])
   var visits: int=campaign.s.visited.size()
   await tap("city_enter_"+str(id))
   check(int(campaign.s.node)==id and campaign.s.visited.size()==visits+1,"one touch enters once")
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 for role in ["supply","workshop"]:
  var campaign=fixture_for(role);await show_campaign(campaign)
  # The depot scene replaced ServiceLocation for supply rooms on 2026-11-08.
  var depot: bool=role!="workshop" and screen.find_child("DepotScreen",true,false)!=null
  check(screen.find_child("WorkbenchScreen" if role=="workshop" else "ServiceLocation",true,false)!=null or depot,"current location is shown")
  await capture(role+"_1280x800")
  await tap("Exit" if role=="workshop" else "Leave" if depot else "city_service_skip")
  if depot:await tap("Primary")
  if screen.find_child("city_leave",true,false)!=null:await tap("city_leave")
  check(campaign.s.phase=="map","current place leaves through existing command")
  roundtrip(campaign)
 print("LINE WORLD UI COMPLETE checks=%d failures=%d"%[checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
