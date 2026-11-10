extends "res://tests/combat_hud_ui.gd"
const Journey=preload("res://redesign/magazine_journey.gd")
func panel_layout()->void:
 for id in ["JourneyTitle","JourneyEyebrow","JourneyConfirm","JourneyCancel"]:fits(id)
 var flow: Control=preview.node("FlowScroll")
 check(preview.get_global_rect().encloses(flow.get_global_rect()),"Flow scroll stays on screen")
 if preview.node("RewardRow").visible:
  for i in range(preview.reward_ids.size()):
   var card: Control=preview.node("RewardPick%d"%i)
   for prefix in ["RewardIcon","RewardName","RewardTag"]:
    check(card.get_global_rect().encloses(preview.node(prefix+str(i)).get_global_rect()),"Reward fields stay in card")
func tap(id: String)->void:
 if OS.get_environment("QA_FAST_HUD")=="1":preview.board.speed_scale=0.02
 var target: Control=preview.node(id)
 # Public focus navigation scrolls the chosen control into view before touch.
 target.grab_focus()
 for ancestor in [preview.node("FlowScroll"),preview.node("MenuScroll"),preview.node("RouteScroll")]:
  if ancestor!=null and ancestor.is_ancestor_of(target):ancestor.ensure_control_visible(target)
 await settle()
 await super.tap(id)
func reopen()->void:
 var expected: Dictionary=JSON.parse_string(JSON.stringify(preview.journey.data()))
 preview.queue_free();await settle()
 preview=load("res://redesign/samples/hud/combat_journey_hud.tscn").instantiate();root.add_child(preview);await settle()
 check(preview.resumed and JSON.parse_string(JSON.stringify(preview.journey.data()))==expected,"Scene reopens exact saved phase and model")
func run()->void:
 out=OS.get_environment("QA_OUTPUT_DIR")
 if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/combat_hud_20261031/"):quit(2);return
 Input.emulate_mouse_from_touch=true
 var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../qa_runtime/magazine_journey_20261031/rules/rules.json")))
 var path_run: Dictionary={}
 for row in report.runs:
  if row.gun=="single" and row.policy==0:path_run=row
 for size in [Vector2i(844,390),Vector2i(1008,454),Vector2i(1280,800)]:
  root.size=size;root.content_scale_size=Vector2i(1280,800)
  preview=load("res://redesign/samples/hud/combat_journey_hud.tscn").instantiate();preview.resume_saved=false;root.add_child(preview);await settle()
  var suffix: String="%dx%d"%[size.x,size.y]
  hud_layout();await capture("opening_"+suffix)
  var opening: Dictionary=JSON.parse_string(JSON.stringify(preview.model.s))
  await tap("Select1");await tap("EjectToggle")
  check(preview.model.ejection_remaining()==1,"Journey ejection uses real quota")
  await reopen();check(preview.model.ejection_remaining()==1,"Journey resumes used ejection quota")
  await tap("Menu");await tap("Reset");panel_layout();await tap("JourneyCancel")
  check(preview.model.ejection_remaining()==1,"Cancel retry preserves paid decision")
  await tap("Menu");await tap("Reset");await tap("JourneyConfirm")
  check(JSON.parse_string(JSON.stringify(preview.model.s))==opening,"Public retry restores exact entry")
  await tap("Menu");await tap("Other");panel_layout();await tap("JourneyCancel")
  check(JSON.parse_string(JSON.stringify(preview.model.s))==opening,"Cancel fresh run preserves current journey")
  for stage in range(40):
   var phase: String=preview.journey.phase()
   if phase=="complete":break
   if phase=="combat":
    var path: Array=[]
    for battle in path_run.battles:
     if int(battle.node)==int(preview.journey.campaign.s.node):path=battle.path
    check(not path.is_empty(),"Earned public route exists")
    hud_layout()
    if preview.journey.campaign.s.node in [401,802]:await capture("battle_%d_%s"%[preview.journey.campaign.s.node,suffix])
    for action in path:await tap({"fire":"Fire","cool":"Cool","swap":"Reload","emergency":"Reload"}[action])
    check(preview.journey.phase()=="reward","Public combat opens reward after animation")
   elif phase in ["reward","supply"]:
    panel_layout()
    var core: bool=preview.journey.campaign.engine_reward()
    if core or preview.journey.campaign.first_ammo_reward() or phase=="supply":await capture(("core_" if core else "service_" if phase=="supply" else "ammo_")+suffix)
    var before:=JSON.stringify(preview.journey.data())
    await preview.fire();preview.apply_ejection()
    check(JSON.stringify(preview.journey.data())==before,"Reward overlay blocks combat commands")
    var index: int=preview.reward_ids.find("siege_drive") if core else 0
    await tap("RewardPick%d"%index)
    check(not preview.selected_reward.is_empty() and not preview.node("JourneyConfirm").disabled,"Touch selects reward explicitly")
    check(JSON.stringify(preview.journey.data())==before,"Selection alone cannot spend reward")
    if core:await capture("core_selected_"+suffix)
    await tap("JourneyConfirm")
    if core:
     check(preview.journey.campaign.first_ammo_reward() and preview.selected_reward.is_empty() and preview.node("JourneyConfirm").disabled,"Core and ammo require separate confirmations")
     await reopen()
   elif phase=="map":
    panel_layout()
    if preview.journey.campaign.s.node==401:await capture("growth_"+suffix)
    await tap("JourneyConfirm")
   else:check(false,"Unexpected public flow "+phase);break
  check(preview.journey.phase()=="complete" and preview.journey.results.size()==5,"All five fights connected through real touch and rewards")
  panel_layout();await capture("complete_"+suffix);await reopen()
  await tap("JourneyConfirm");check(preview.panel_mode=="new","Completion offers explicit new departure")
  await tap("JourneyCancel");check(preview.journey.phase()=="complete","Cancel new run retains completion")
  preview.queue_free();await settle()
 # Weapon picker starts each supported weapon; full combat paths are covered in rules.
 preview=load("res://redesign/samples/hud/combat_journey_hud.tscn").instantiate();preview.resume_saved=false;root.add_child(preview);await settle()
 for index in range(5):
  await tap("Menu");await tap("Other");preview.node("JourneyGun").select(index);await tap("JourneyConfirm")
  check(preview.model.s.gun==preview.GUNS[index] and preview.journey.campaign.s.clears==0,"New gun is committed only at departure")
  hud_layout();await tap("Fire")
  await tap("Parts");check(preview.node("DetailBody").text.contains("첫 승리"),"Starter explains first core acquisition");await tap("CloseDetail")
 check(not FileAccess.file_exists(Journey.Campaign.SAVE),"Journey never touches regular campaign save")
 # Reach a defeat through legal waiting, then retry through the actual overlay.
 for step in range(20):
  if preview.journey.phase()!="combat":break
  await tap("Reload")
 check(preview.journey.phase()=="lost","Actual waiting reaches defeat overlay")
 await capture("defeat_retry")
 await tap("JourneyConfirm")
 check(preview.journey.phase()=="combat" and preview.journey.results.is_empty(),"Defeat retry restores the current encounter")
 FileAccess.open(out.path_join("flow.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"action_animation_ms":action_times},"  "))
 print("COMBAT HUD FLOW COMPLETE checks=%d failures=%d"%[checks,failures.size()]);preview.queue_free();await settle();quit(0 if failures.is_empty() else 1)
