extends "res://tests/weapon_magazine_ui.gd"
const Journey=preload("res://redesign/magazine_journey.gd")
func panel_layout()->void:
 var bounds:=preview.get_global_rect()
 for id in ["JourneyTitle","JourneyEyebrow","JourneySummary","JourneyConfirm","JourneyCancel","JourneyGun"]:
  var n: Control=preview.node(id)
  if not n.is_visible_in_tree():continue
  check(bounds.encloses(n.get_global_rect()),"Journey element fits "+id)
  if n is Button:
   check(n.size.y*float(root.size.y)/800>=44,"Journey touch target "+id)
   var w:=n.get_theme_font("font").get_string_size(n.text,HORIZONTAL_ALIGNMENT_LEFT,-1,n.get_theme_font_size("font_size")).x
   check(w+32<=n.size.x,"Journey button text fits "+id)
 if preview.node("RewardRow").visible:
  for i in range(preview.reward_ids.size()):
   var card: Control=preview.node("RewardPick%d"%i)
   check(bounds.encloses(card.get_global_rect()),"Reward card fits")
   for prefix in ["RewardIcon","RewardName","RewardTag","RewardScroll"]:
    check(card.get_global_rect().encloses(preview.node(prefix+str(i)).get_global_rect()),"Reward element contained "+prefix)
   for prefix in ["RewardName","RewardTag"]:
    var n: Label=preview.node(prefix+str(i))
    var w:=n.get_theme_font("font").get_string_size(n.text,HORIZONTAL_ALIGNMENT_LEFT,-1,n.get_theme_font_size("font_size")).x
    check(w<=n.size.x,"Reward heading fits "+n.text)
func reopen()->void:
 var expected: Dictionary=JSON.parse_string(JSON.stringify(preview.journey.data()))
 preview.queue_free();await settle()
 preview=load("res://redesign/samples/combat_magazine_journey.tscn").instantiate();root.add_child(preview);await settle()
 check(preview.resumed and JSON.parse_string(JSON.stringify(preview.journey.data()))==expected,"Scene reopens exact saved phase and model")
func run()->void:
 out=OS.get_environment("QA_OUTPUT_DIR")
 if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/magazine_journey_20261031/"):quit(2);return
 Input.emulate_mouse_from_touch=true
 var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(out.get_base_dir().path_join("rules/rules.json")))
 var path_run: Dictionary={}
 for row in report.runs:
  if row.gun=="single" and row.policy==0:path_run=row
 for size in [Vector2i(1008,630),Vector2i(1280,576),Vector2i(1280,800)]:
  root.size=size;root.content_scale_size=Vector2i(1280,800)
  preview=load("res://redesign/samples/combat_magazine_journey.tscn").instantiate();preview.resume_saved=false;root.add_child(preview);await settle()
  var suffix: String="%dx%d"%[size.x,size.y]
  weapon_layout();await capture("opening_"+suffix)
  var opening: Dictionary=JSON.parse_string(JSON.stringify(preview.model.s))
  await tap("EjectToggle");await tap("Select1");await tap("EjectApply")
  check(preview.model.ejection_remaining()==1,"Journey ejection uses real quota")
  await reopen();check(preview.model.ejection_remaining()==1,"Journey resumes used ejection quota")
  await tap("Reset");panel_layout();await tap("JourneyCancel")
  check(preview.model.ejection_remaining()==1,"Cancel retry preserves paid decision")
  await tap("Reset");await tap("JourneyConfirm")
  check(JSON.parse_string(JSON.stringify(preview.model.s))==opening,"Public retry restores exact entry")
  await tap("Other");panel_layout();await tap("JourneyCancel")
  check(JSON.parse_string(JSON.stringify(preview.model.s))==opening,"Cancel fresh run preserves current journey")
  for stage in range(40):
   var phase: String=preview.journey.phase()
   if phase=="complete":break
   if phase=="combat":
    var path: Array=[]
    for battle in path_run.battles:
     if int(battle.node)==int(preview.journey.campaign.s.node):path=battle.path
    check(not path.is_empty(),"Earned public route exists")
    weapon_layout()
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
 preview=load("res://redesign/samples/combat_magazine_journey.tscn").instantiate();preview.resume_saved=false;root.add_child(preview);await settle()
 for index in range(5):
  await tap("Other");preview.node("JourneyGun").select(index);await tap("JourneyConfirm")
  check(preview.model.s.gun==preview.GUNS[index] and preview.journey.campaign.s.clears==0,"New gun is committed only at departure")
  weapon_layout();await tap("Fire")
  await tap("Parts");check(preview.node("DetailBody").text.contains("첫 승리"),"Starter explains first core acquisition");await tap("CloseDetail")
 check(not FileAccess.file_exists(Journey.Campaign.SAVE),"Journey never touches regular campaign save")
 FileAccess.open(out.path_join("ui.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"action_animation_ms":action_times},"  "))
 print("JOURNEY UI COMPLETE checks=%d failures=%d"%[checks,failures.size()]);preview.queue_free();await settle();quit(0 if failures.is_empty() else 1)
