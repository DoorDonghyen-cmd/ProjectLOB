extends "res://tests/combat_hud_flow.gd"
func snapshot()->Dictionary:
 return canonical({"data":preview.journey.data(),"entry":preview.journey.entry,"results":preview.journey.results,"acquisitions":preview.journey.acquisitions})
func preview_choice(index: int)->Dictionary:
 var original:=snapshot()
 var saved:=FileAccess.get_file_as_string(preview.Journey.SAVE)
 await tap("RewardPick%d"%index)
 check(not preview.flow.projected.is_empty(),"Actual campaign command can preview this choice")
 check(snapshot()==original and FileAccess.get_file_as_string(preview.Journey.SAVE)==saved,"Inspecting a reward changes neither state, RNG, ownership nor save bytes")
 check(not preview.node("RewardDelta").text.is_empty(),"Selected candidate exposes its concrete change")
 return canonical(preview.flow.projected)
func run()->void:
 out=OS.get_environment("QA_OUTPUT_DIR")
 if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/combat_hud_20261031/"):quit(2);return
 Input.emulate_mouse_from_touch=true;Input.emulate_touch_from_mouse=true
 var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../qa_runtime/magazine_journey_20261031/rules/rules.json")))
 var route: Dictionary={}
 for row in report.runs:
  if row.gun=="single" and row.policy==0:route=row
 for resolution in [Vector2i(740,360),Vector2i(844,390),Vector2i(1280,800)]:
  root.size=resolution;root.content_scale_size=Vector2i(1280,800)
  preview=JourneyScene.instantiate();preview.resume_saved=false;root.add_child(preview);await settle()
  var tag: String="%dx%d"%[resolution.x,resolution.y]
  var start:=snapshot()
  await tap("Menu");await tap("Pressure")
  check(preview.panel_mode=="route" and preview.node("RouteOverview").visible,"Menu opens authored route overview")
  check(not preview.node("JourneyConfirm").visible,"Route inspection never offers movement during combat")
  preview.node("JourneyCancel").grab_focus();await key(KEY_TAB)
  check(root.gui_get_focus_owner()==preview.node("RouteStop0"),"Route keyboard focus wraps inside the overlay")
  await tap("RouteStop6")
  check(preview.flow.inspected_room==802 and snapshot()==start,"Future gate inspection cannot travel, spend or reroll")
  await capture("route_inspection_"+tag)
  await key(KEY_ESCAPE);check(not preview.node("JourneyPanel").visible,"Escape returns from route to unchanged battle")
  await create_timer(0.35).timeout
  for stage in range(30):
   var phase: String=preview.journey.phase()
   if phase=="supply":break
   if phase=="combat":
    var path: Array=[]
    for battle in route.battles:
     if int(battle.node)==int(preview.journey.campaign.s.node):path=battle.path
    check(not path.is_empty(),"Known earned path reaches the next reward")
    for action in path:await tap({"fire":"Fire","cool":"Cool","swap":"Reload","emergency":"Reload"}[action])
   elif phase=="reward":
    var core: bool=preview.journey.campaign.engine_reward()
    var first: bool=preview.journey.campaign.first_ammo_reward()
    var expected: Dictionary={}
    # All three previews use the real command without silently claiming a reward.
    for i in range(preview.reward_ids.size()):expected=await preview_choice(i)
    var choice: int=preview.reward_ids.find("siege_drive") if core else 0
    expected=await preview_choice(choice)
    preview.node("JourneyConfirm").grab_focus();await key(KEY_TAB)
    check(root.gui_get_focus_owner()==preview.node("RewardPick0"),"Reward keyboard focus cannot fall through to combat")
    if core:
     check(preview.node("RewardDelta").text.contains("7 ▶ 6"),"Core preview exposes its actual magazine cost")
     await capture("core_preview_"+tag)
    if first:await capture("ammo_preview_"+tag)
    preview.confirm_panel()
    var committed:=snapshot()
    preview.confirm_panel()
    check(snapshot()==committed,"Repeated confirm cannot consume the following reward or travel")
    await create_timer(0.35).timeout;await settle()
    check(canonical(preview.journey.data())==expected,"Confirmed reward exactly matches the displayed projection")
    if core:await reopen()
   elif phase=="map":
    check(preview.node("RouteOverview").visible,"Post-reward map shows the next real room")
    check(preview.flow.inspected_room==preview.flow.next_room(),"Entering map focuses the actual next destination")
    var next_button: Control=preview.node("RouteStop%d"%preview.flow.ROOMS.find(preview.flow.next_room()))
    check(preview.node("RouteScroll").get_global_rect().encloses(next_button.get_global_rect()),"Next destination is revealed after returning from another inspected room")
    check(preview.node("RouteState0").text in ["현재","지나옴"],"Saved numeric node IDs remain marked visited after restore")
    var before:=snapshot();var next_id: int=preview.flow.next_room()
    if preview.journey.campaign.s.node==401:await capture("next_workshop_"+tag)
    await tap("RouteStop6")
    check(snapshot()==before,"Inspecting a later room does not alter the active route")
    await tap("JourneyConfirm")
    check(int(preview.journey.campaign.s.node)==next_id,"Continue follows the actual fixed route, not the inspected future room")
   else:check(false,"Unexpected phase before workshop: "+phase);break
  check(preview.journey.phase()=="supply","Actual three fights and rewards reach free workshop")
  var old_deck: Array=preview.model.s.deck.duplicate()
  var expected:=await preview_choice(0)
  var selected: String=preview.selected_reward
  var replaced: String=preview.journey.replacement(selected)
  check(not replaced.is_empty() and preview.node("RewardDelta").text.contains(preview.Content.AMMO[replaced].name),"Workshop tells which real basic round will be replaced")
  await capture("workshop_preview_"+tag)
  await reopen()
  check(preview.selected_reward.is_empty() and preview.node("JourneyConfirm").disabled,"Restart requires a fresh explicit reward selection")
  check(preview.model.s.deck==old_deck,"Unconfirmed workshop selection cannot persist as a purchase")
  expected=await preview_choice(0)
  await tap("JourneyConfirm")
  check(canonical(preview.journey.data())==expected and preview.model.s.deck.size()==old_deck.size(),"Workshop commits exactly the displayed one-for-one replacement")
  check(preview.model.s.deck.count(replaced)==old_deck.count(replaced)-1 and preview.model.s.deck.count(selected)==old_deck.count(selected)+1,"Confirmed workshop removes and adds one actual owned round")
  await reopen();check(preview.journey.phase()=="map","Committed workshop resumes on the map")
  preview.queue_free();await settle()
 # Authoring preview has no game controller and does not require play to lay out.
 root.size=Vector2i(1280,800)
 preview=load("res://redesign/samples/hud/journey_route.tscn").instantiate();root.add_child(preview);await settle();await capture("authored_route")
 preview.queue_free();await settle()
 FileAccess.open(out.path_join("journey.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
 print("JOURNEY FLOW UI COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
