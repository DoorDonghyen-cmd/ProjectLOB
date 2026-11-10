extends "res://tests/campaign_magazine_ui.gd"
## Reuse earned campaign states; presentation must not mutate combat or RNG.
func verify_stack(b)->void:
 var order: Array=b._alive_indices()
 var saved: Dictionary={}
 for index in order:
  var rect: Rect2=b.enemy_plaque(index)
  saved[index]=rect
  var button: Control=b.get_node("enemy_info_%d"%index)
  check(button.get_rect()==rect,"drawn card and touch rectangle agree")
  check(b._enemy_at(rect.get_center())==index,"card center selects its own monster")
  if not b.line_readout.row_layout:
   var centered:=clampf(b.enemy_feet(index).x-rect.size.x*0.5,4.0,b.size.x-rect.size.x-4.0)
   check(absf(rect.position.x-centered)<=0.5,"stack preserves horizontal attachment to monster")
   check(rect.end.y<=b.enemy_head_y(index)-9.5,"card stays above its own head")
   if b.enemy_head_y(index)-rect.end.y>20:
    var line: PackedVector2Array=b.line_readout.connector(index)
    check(line.size()==2 and absf(line[1].x-b.enemy_feet(index).x)<=0.5,"raised card connects back to its monster")
  if b.line_readout.has_intent(index):
   var header: Rect2=b.intent_rect(index)
   for other in order:
    check(not header.intersects(b.enemy_plaque(other)),"boss or exposure intent is clear of every HP card")
    if other!=index and b.line_readout.has_intent(other):check(not header.intersects(b.intent_rect(other)),"intent captions do not overlap")
 order.reverse()
 for index in order:check(saved[index]==b.enemy_plaque(index),"query order cannot rearrange tiers")

func touch_card(b,index: int)->void:
 var point: Vector2=b.get_global_transform_with_canvas()*b.enemy_plaque(index).get_center()
 for pressed in [true,false]:
  var event:=InputEventScreenTouch.new();event.index=0;event.position=point;event.pressed=pressed;root.push_input(event,true);await process_frame
 await settle()
 check(host.campaign_hud.overlay_open,"HP tag touch opens enemy details")
 check(host.campaign_hud.node("DetailTitle").text==host.model.s.enemies[index].name,"touch opens the corresponding monster, including raised cards")
 await tap("CloseDetail")

func stacked_fixture(evidence: String)->void:
 # Presentation stress fixture only: never changes the campaign or resolver.
 var c=Campaign.new()
 check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(evidence.path_join("combat_single_731042_r1_n802.json")))),"four-enemy geometry fixture restores")
 root.size=Vector2i(1280,800);await mount(c)
 var before=canonical(c.model.s)
 var b=host.campaign_hud.board
 for enemy in b.enemies:enemy.distance=16
 verify_stack(b)
 check(not b.line_readout.row_layout,"four coincident monsters stack on a tall battlefield")
 var levels: Dictionary={}
 for index in b._alive_indices():levels[index]=b.enemy_plaque(index).position.y
 b.inspection_enabled=false
 for index in b._alive_indices():check(b.enemy_plaque(index).position.y==levels[index],"starting an animation cannot collapse card height or shift tiers")
 b.inspection_enabled=true
 check(levels.values().size()==4,"four-monster fixture is populated")
 for i in b._alive_indices():
  for j in b._alive_indices():
   if i<j:check(not b.enemy_plaque(i).intersects(b.enemy_plaque(j)),"coincident cards occupy distinct vertical tiers")
 # Overtaking and subpixel movement must not change tier priority.
 for step in [0.01,-0.01,0.1,-0.1]:
  b.enemies[0].distance=16+step
  verify_stack(b)
  for index in b._alive_indices():check(b.enemy_plaque(index).position.y==levels[index],"small movement cannot swap vertical tiers")
 b.queue_redraw();await settle();await capture("fixture_four_overlapping")
 b.enemies[0].hp=0
 verify_stack(b)
 b.queue_redraw();await settle();await capture("fixture_after_death")
 for extent in [Vector2i(844,390),Vector2i(1280,800)]:
  root.size=extent;await settle()
  b=host.campaign_hud.board
  verify_stack(b)
  check(b.line_readout.row_layout==(extent.y<400),"resizing switches between stacked cards and the low-height row")
 check(canonical(c.model.s)==before,"presentation fixture never mutates combat or RNG")

func run()->void:
 output=OS.get_environment("QA_OUTPUT_DIR")
 if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/campaign_magazine_20261101/"):quit(2);return
 Input.emulate_mouse_from_touch=true
 var evidence:=ProjectSettings.globalize_path("res://../qa_runtime/campaign_magazine_20261101/integrated/rules")
 var names: Array=["r1_n101","r1_n401","r1_n802","r2_n10902","r3_n20902","r4_n30902","r5_n41002"]
 var metrics: Array=[]
 for name in names:
  for extent in [Vector2i(1280,800),Vector2i(1008,454),Vector2i(844,390),Vector2i(740,360)]:
   var c=Campaign.new()
   check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(evidence.path_join("combat_single_731042_%s.json"%name)))),"earned state restores")
   var before=canonical(c.model.s)
   root.size=extent;await mount(c);hud_bounds()
   var b=host.campaign_hud.board
   check(b.character_scale()<=0.09,"hero remains at reference scale on a tall battlefield")
   check(Rect2(Vector2.ZERO,b.size).has_point(b.player_muzzle()),"registered muzzle stays on the battlefield")
   var row: Dictionary={"state":name,"size":str(extent),"board":str(b.size),"scale":b.character_scale(),"multiplier":b.character_size_multiplier,"reference":b.character_reference_height,"plaques":[]}
   for index in b._alive_indices():
    var rect: Rect2=b.enemy_plaque(index)
    row.plaques.append({"index":index,"rect":str(rect)})
    check(Rect2(Vector2.ZERO,b.size).encloses(rect),"HP tag stays on battlefield")
    check(rect.size.y>=44,"HP detail target preserves 44px touch height")
    var layout: Dictionary=b.line_readout.layout(index)
    for cell in layout.cells:
     check(cell.x+cell.width<=rect.size.x-7 and cell.y+14<=layout.bar_y,"status cells stay above the HP bar inside their tag")
    for other in b._alive_indices():
     if other>index:check(not rect.intersects(b.enemy_plaque(other)),"HP tags do not overlap")
   metrics.append(row)
   verify_stack(b)
   row["row_layout"]=b.line_readout.row_layout
   if extent==Vector2i(1280,800):check(not b.line_readout.row_layout,"earned tall battlefield uses head-anchored stacking")
   if extent==Vector2i(844,390):check(b.line_readout.row_layout,"low landscape battlefield uses row fallback")
   check(canonical(c.model.s)==before,"rendering preserves all combat state and RNG")
   await capture("%s_%dx%d"%[name,extent.x,extent.y])
   if extent in [Vector2i(1280,800),Vector2i(844,390)]:
    for index in b._alive_indices():await touch_card(b,index)
    await tap("Select1");await tap("EjectToggle")
    check(c.model.ejection_remaining()==1,"ejection still works")
    await tap("Fire")
    check(not host.busy,"shot animation completes with registered muzzle")
    if is_instance_valid(host.campaign_hud):
     verify_stack(host.campaign_hud.board)
     await capture("%s_%dx%d_after_fire"%[name,extent.x,extent.y])
 await stacked_fixture(evidence)
 var file:=FileAccess.open(output.path_join("geometry.json"),FileAccess.WRITE);file.store_string(JSON.stringify(metrics,"  "));file.close()
 host.free();await settle()
 print("CAMPAIGN VISUAL COMPLETE checks=%d failures=%d"%[checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
