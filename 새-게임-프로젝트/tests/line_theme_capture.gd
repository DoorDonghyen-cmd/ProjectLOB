extends "res://tests/line_world_ui.gd"
## RETIRED 2026-11-08 as a run target: checks capture tool that needs LOB_UI_DATA, not a check suite. Replaced by: line_world_ui.
## Current UI suites: docs/qa/ui-test-suites.md
## Captures actual scenes at the reference sizes. No production save is read.
const CombatModel=preload("res://redesign/model.gd")
var bounds: Array=[]
func shot(name: String)->void:
 await settle()
 check(root.get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"capture "+name)
func run()->void:
 if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/line_theme_20261101/"):quit(2);return
 output=OS.get_environment("QA_OUTPUT_DIR")
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("LOB_UI_DATA")))
 var fixture=CombatModel.new()
 fixture.start("single",731042)
 fixture.s.merge({"reserve_version":1,"inventory_version":1,"emergency_version":1,"magazine_trial_version":1,"weapon_magazine_version":1,"deck":data.combat.deck.duplicate(),"equipped_parts":["volley_drive","radiator"]},true)
 fixture.begin_encounter(0)
 fixture.s.enemies=data.combat.enemies.duplicate(true)
 fixture.s.reinforcements=data.combat.reinforcements.duplicate(true)
 fixture.assign_opening_lanes()
 fixture.s.encounter_total=fixture.s.enemies.size()+fixture.s.reinforcements.size()
 fixture.s.deployed=fixture.s.enemies.size()
 check(fixture.trial_load_magazine(),"real model loads reference elite fixture")
 for resolution in [Vector2i(740,360),Vector2i(844,390),Vector2i(1008,454),Vector2i(1280,800)]:
  root.size=resolution;root.content_scale_size=resolution
  var hud=load("res://redesign/samples/hud/combat_hud.tscn").instantiate()
  hud.resume_saved=false
  root.add_child(hud)
  hud.model.s=fixture.s.duplicate(true)
  hud.board.set_route_background(0,3,8)
  hud.refresh()
  hud.node("Title").text="정예 · 약탈단 두목"
  var tag: String="%dx%d"%[resolution.x,resolution.y]
  await shot("elite_"+tag)
  var row: Dictionary={"viewport":tag,"regions":{}}
  for id in ["Header","Battle","Console","MagazineHeader","MagazineHousing","Actions","Round0","Fire","Cool","Reload"]:
   var r: Rect2=hud.node(id).get_global_rect()
   row.regions[id]=[r.position.x,r.position.y,r.size.x,r.size.y]
  bounds.append(row)
  if resolution==Vector2i(1280,800):
   hud.select_ejection(1);await shot("selected_"+tag)
   hud.hud.clear_selection();hud.hud.open_menu();await shot("menu_"+tag)
   hud.hud.close_menu();hud.hud.inspect_round(1);await shot("detail_"+tag)
  hud.queue_free();await settle()
 var manifest:=FileAccess.open(output.path_join("bounds.json"),FileAccess.WRITE)
 manifest.store_string(JSON.stringify(bounds,"  "));manifest.close()
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 screen=load("res://redesign/main.tscn").instantiate();screen.save_enabled=false
 root.add_child(screen);await settle()
 screen.preferences.data.motion="instant"
 for role in ["supply","workshop"]:
  var campaign=fixture_for(role)
  await show_campaign(campaign)
  await shot(role+"_1280x800")
  check(screen.find_child("WorkbenchScreen" if role=="workshop" else "ServiceLocation",true,false)!=null,"production location rendered: "+role)
  var before: int=campaign.s.node
  await tap("Exit" if role=="workshop" else "city_service_skip")
  if screen.find_child("city_leave",true,false)!=null:await tap("city_leave")
  check(campaign.s.phase=="map" and int(campaign.s.node)==before,"location exit retains room and returns to map")
 print("LINE THEME CAPTURE COMPLETE checks=%d failures=%d"%[checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
