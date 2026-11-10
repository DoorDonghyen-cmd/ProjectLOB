extends "res://tests/fire_control_ui.gd"
## RETIRED 2026-11-08 as a run target: checks old gate buttons and first-reward layout. Replaced by: gate_live_ui, reward_live_runner.
## Current UI suites: docs/qa/ui-test-suites.md
func finish()->void:
 host.free();await settle()
 FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
 print("PLAYTEST REWORK COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
func run()->void:
 output=OS.get_environment("QA_OUTPUT_DIR")
 if not output.replace("\\","/").contains("/qa_runtime/playtest_rework_20261103/"):quit(2);return
 Input.emulate_mouse_from_touch=true
 for extent in [Vector2i(740,360),Vector2i(844,390),Vector2i(1280,800)]:
  root.size=extent
  var c=Campaign.new();c.start("burst",731042,0,"balanced",3,"carrier",true);c.enter(101);await mount(c)
  var ui=host.campaign_hud
  ui.select_budget(1);await settle()
  var from:=point("Select0");var second:=point("Select1");var third:=point("Select2")
  # OS may coalesce the last move: release must still commit the endpoint.
  await touch(from,true);await motion(second,second-from);await touch(third,false);await settle()
  check(ui.current_budget()==3,"release endpoint selects third card "+str(extent))
  # A gap belongs to the nearest card, without sticky previous selection.
  var gap: Vector2=(point("Select1")+point("Select2"))*0.5+Vector2(1,0)
  await touch(from,true);await motion(second,second-from);await motion(gap,gap-second);await touch(gap,false);await settle()
  check(ui.current_budget()==3,"card gap selects nearest third "+str(extent))
  # Slight initial vertical thumb motion must not permanently abandon the drag.
  await touch(from,true);await motion(from+Vector2(6,14),Vector2(6,14));await motion(third,third-from);await touch(third,false);await settle()
  check(ui.current_budget()==3,"diagonal thumb gesture reaches third "+str(extent))
  var before: Dictionary=canonical(c.model.s)
  await touch(from,true);await motion(second,second-from);await touch(Vector2.ZERO,false);await settle()
  check(canonical(c.model.s)==before,"outside release cancels selection without consuming")
  # Controlled early-kill fixture: selected maximum and highlighted prefix agree.
  c.model.s.magazine=["basic_p2","basic_p2","basic_p2"];c.model.s.reinforcements=[]
  for e in c.model.s.enemies:e.hp=0
  c.model.s.enemies[0].hp=1;c.model.s.enemies[0].distance=8
  ui.select_budget(3);await settle()
  check(ui.last_prediction.shots.size()==1,"fixture predicts early stop after one card")
  var highlighted:=0
  for i in range(3):
   if ui.node("Face%d"%i).offset_top==0:highlighted+=1
  check(highlighted==3 and ui.node("FireName").text.contains("3"),"selected three shown by both cards and button")
  var board=ui.board
  board._capture_damage_anchors();board._set_damage_popups({"id":"basic_p2","target":0,"damage":2,"hp":0})
  var item: Dictionary=board.damage_popup_layout()[0]
  var hit: Vector2=board.enemy_position(0)
  check(absf(item.bounds.get_center().x-hit.x)<20,"damage readout anchored horizontally to actual target")
  check(absf(item.bounds.get_center().y-hit.y)<55,"damage readout remains near impact")
  board.queue_redraw();if is_instance_valid(board.readout_layer):board.readout_layer.queue_redraw()
  await capture("hit_and_prefix_%dx%d"%[extent.x,extent.y])
 await production_flow()
 await gate_flow()
 await finish()

func production_flow()->void:
 if is_instance_valid(host):host.free()
 root.size=Vector2i(844,390)
 host=load("res://redesign/main.tscn").instantiate();root.add_child(host);await settle()
 host.preparation_seed="731042";host._open_preparation();await settle();await capture("equipment_growth")
 await tap("start_single")
 check(host.campaign.s.map_version==4 and Model.Roles.enabled(host.model.s),"public start enables v4 route and roles")
 host._campaign_action("departure_skip");await settle();host._campaign_action("enter",101);await settle()
 host.campaign_hud.hud.feedback.save_setting("motion","fast")
 var solver=preload("res://tests/fire_control_solver.gd").new()
 var path: Array=solver.solve(host.model,4,18)
 for step in path:
  if step.action=="fire":host.campaign_hud.select_budget(int(step.get("rounds",0)) if int(step.get("rounds",0))>0 else host.campaign_hud.maximum_budget())
  if step.action=="eject":
   for i in step.indices:await tap("Select%d"%i)
   await tap("EjectToggle")
  else:await tap({"fire":"Fire","cool":"Cool","reload":"Reload","emergency":"Reload"}[step.action])
 await tap("city_reward_thermal_drive")
 for extent in [Vector2i(740,360),Vector2i(844,390),Vector2i(1280,800)]:
  root.size=extent;host.redraw();await settle()
  var bore: Control=host.find_child("city_reward_bore",true,false)
  check(bore!=null and host.find_child("city_reward_arc",true,false)!=null,"first reward offers area builds")
  host.main_scroll.ensure_control_visible(bore.get_parent());await settle();await capture("role_packages_%dx%d"%[extent.x,extent.y])
 root.size=Vector2i(844,390);host.redraw();await settle()
 await tap("city_reward_bore")
 check(host.model.s.deck.count("bore")==2 and host.model.s.deck.count("disrupt")==1,"public reward grants fire/control package")
 var saved=Campaign.new();check(saved.restore() and canonical(saved.model.s)==canonical(host.model.s),"new build saves exactly through package flow")
 var next: Dictionary=host.campaign.choices()[0]
 host._campaign_action("enter",next.id);await settle()
 # Legal owned cards, arranged solely to isolate visual contracts.
 var m=host.model;m.s.magazine=["bore","disrupt","basic_p2"];m.s.magazine_loaded=m.s.magazine.duplicate();m.s.hand=[];m.s.discard=[];m.s.draw=m.s.deck.duplicate()
 for id in m.s.magazine:m.s.draw.erase(id)
 host.campaign_hud.refresh();host.campaign_hud.select_budget(1);await tap("Fire")
 check(not m.s.fire_zones.is_empty(),"live shot leaves persistent fire")
 await capture("live_ground_fire")
 var again=Campaign.new();check(again.restore() and canonical(again.model.s)==canonical(m.s),"live fire zones automatically save and restore")
 if m.s.phase=="ready":
  await tap("Fire");await capture("live_slow")
  check(m.s.enemies.any(func(e):return bool(e.get("slow_used",false))),"live next shot applies slow")

func gate_flow()->void:
 var file:="res://../qa_runtime/playtest_rework_20261103/climb_primary/gate_single_731042_r1.json"
 var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(file))
 for extent in [Vector2i(844,390),Vector2i(1280,800)]:
  root.size=extent
  var c=Campaign.new();check(c.restore_state(source),"earned new-run gate restores for UI")
  await mount(c);await tap("city_gate_cadence")
  if extent.x<1120:check(root.content_scale_mode==Window.CONTENT_SCALE_MODE_DISABLED,"small gate uses readable native pixels")
  var grid: Control=host.find_child("GateUpgradeGrid",true,false)
  for item in grid.get_children():
   if item is Control:
    var bounds: Rect2=item.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,item.size)
    check(bounds.position.x>=0 and bounds.end.x<=extent.x,"gate choices fit horizontally at native size")
  await capture("gate_growth_%dx%d"%[extent.x,extent.y])
  await tap("city_gate_apply")
  check(c.model.s.gate_mods.cadence==1 and c.gate_ready(),"public gate choice applies firing growth once")
  var restored=Campaign.new();check(restored.restore() and restored.model.s.gate_mods.cadence==1,"growth choice persists")
