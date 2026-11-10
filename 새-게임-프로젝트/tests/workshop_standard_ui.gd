extends "res://tests/ui_readability_ui.gd"
var layout: Array=[]
func capture(label: String) -> void:
 # Offscreen windows may retain an incomplete cached canvas after modal closure.
 # Request a complete native canvas draw before collecting visual evidence.
 for item in host.find_children("*", "CanvasItem", true, false):item.queue_redraw()
 await super.capture(label)
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

func stable() -> void:
 host.preferences.data.motion="instant";host.feedback.configure(host.preferences.data)
 for i in range(24):await process_frame
func save_matches(c) -> void:
 var restored=Campaign.new()
 check(restored.restore(),"public action autosaves")
 check(canonical(restored.s)==canonical(c.s) and canonical(restored.model.s)==canonical(c.model.s),"saved campaign and model match exactly")
func view():return host.find_child("WorkbenchScreen",true,false)
func geometry(extent: Vector2i) -> void:
 var v=view()
 check(v!=null,"production mounts the approved workbench scene")
 check(host.find_child("WorkshopOperations",true,false)==null,"old operation card grid is replaced only at workshop")
 check(host.main_scroll.get_h_scroll_bar().max_value<=host.main_scroll.get_h_scroll_bar().page+2,"workbench fits native width")
 for path in ["Header/Exit","Inspector/Inset/Actions/Apply","Inspector/Inset/Actions/Cancel"]:
  var b: Button=v.get_node(path)
  check(b.size.y>=44 and b.size.x<=216,"workbench actions keep native touch size and content width")
  check(v.get_global_rect().encloses(b.get_global_rect()),"action fits the authored scene")
 check(not v.get_node("Inspector").get_global_rect().intersects(v.get_node("Inventory").get_global_rect()),"inspector and inventory never overlap")
 check(v.get_node("Room/Actor").profile==preload("res://redesign/service_actor_catalog.gd").resolve(str(host.model.s.outfit),"workshop").profile,"actual outfit owns workbench pose")
 scan("workbench_%dx%d"%[extent.x,extent.y])
func run()->void:
 output=OS.get_environment("QA_OUTPUT_DIR")
 if not output.replace("\\","/").contains("/qa_runtime/ui_standard_20261104/"):quit(2);return
 Input.emulate_mouse_from_touch=true
 var authored=load("res://redesign/workbench/screen.tscn").instantiate()
 check(authored.get_node("Tabs").get_child_count()==4,"four real operation tabs are authored before ready")
 check(authored.get_node("Inspector/Inset/BodyScroll/Content/Title").text=="탄환 강화","representative composition exists in editor")
 check(authored.get_node("Inventory/Inset/Rows/InventoryScroll/Slots").get_child_count()>0,"representative ammo exists before binding")
 authored.free()
 for extent in [Vector2i(1280,800),Vector2i(1008,630),Vector2i(844,390),Vector2i(2340,1080),Vector2i(2160,1032)]:
  var c=modern_place();await mount_at(c,extent);await stable()
  var before=canonical({"campaign":c.s,"model":c.model.s,"profile":c.profile})
  for scale in [0.9,1.0,1.1]:
   host.preferences.data.text_scale=scale;host.redraw();await stable();geometry(extent)
  for mode in [0,1,3,4]:
   await tap("Tab%d"%mode)
   check(canonical({"campaign":c.s,"model":c.model.s,"profile":c.profile})==before,"tabs and real command preview never mutate the run")
   if mode==0:
    check(view().candidates.get_child_count()==c.workshop_ammo_options().size(),"every actual incoming candidate is available")
   if extent in [Vector2i(1280,800),Vector2i(2340,1080)]:
    host.main_scroll.scroll_vertical=0;await stable();await capture("mode%d_%dx%d"%[mode,extent.x,extent.y])
  await tap("Tab1");await tap("Cancel")
  check(view().selected.is_empty() and view().get_node("Inspector/Inset/Actions/Apply").disabled,"cancel clears the proposed ammo operation")
  check(canonical({"campaign":c.s,"model":c.model.s,"profile":c.profile})==before,"cancel preserves the free work and all run state")
 # Use the public touch path for all five operations, including both tune choices.
 for mode in [0,1,3,4]:
  var c=modern_place();await mount_at(c,Vector2i(1280,800));await stable();await tap("Tab%d"%mode)
  var v=view()
  check(v.proposal.valid,"current operation has a legal proposal")
  if not v.proposal.valid:continue
  var expected=canonical(v.proposal.after)
  var expected_deck=expected.deck
  var money=c.s.credits
  await tap("Apply");await stable()
  if mode==1:await tap("Confirm");await stable()
  check(c.s.resolved,"public operation consumes the single free work")
  check(canonical(c.model.s.deck)==expected_deck,"actual operation matches sandbox preview exactly")
  check(c.s.credits==money,"free work does not charge credits")
  check(view()!=null and view().get_node("Inspector/Inset/BodyScroll/Content/Title").text=="정비 완료","receipt stays in the approved workshop scene")
  save_matches(c)
  v=view();v._apply() # Completed action exits instead of executing another operation.
  await stable()
  check(c.s.phase=="map","completed work returns to map")
  check(c.model.s.deck.size()==expected_deck.size(),"exit never reapplies the operation")
  save_matches(c)
 # Explicit unused-work exit preserves ammo and resolves the room through normal commands.
 var c=modern_place();await mount_at(c,Vector2i(844,390));await stable()
 var before=canonical(c.model.s.deck)
 await tap("Exit");await stable()
 check(c.s.phase=="map" and canonical(c.model.s.deck)==before,"skip leaves unused work without changing ammo")
 save_matches(c)
 # Minimum deck and region caps are shown from domain rules, never invented UI limits.
 c=modern_place();c.model.s.deck=c.model.s.deck.slice(0,c.minimum_deck())
 await mount_at(c,Vector2i(1280,800));await stable();await tap("Tab3")
 check(view().get_node("Inspector/Inset/Actions/Apply").disabled,"minimum deck prevents removal")
 check(view().get_node("Inspector/Inset/BodyScroll/Content/Condition").text.contains(str(c.minimum_deck())),"minimum-deck reason shows actual outfit limit")
 c.s.bag_upgrades=c.bag_growth_limit();c.model.s.bag_upgrades=c.s.bag_upgrades
 host.redraw();await stable();await tap("Tab4")
 check(view().get_node("Inspector/Inset/Actions/Apply").disabled,"region expansion cap cannot be bypassed")
 # More inventory types than fit horizontally remain selectable through the actual scroller.
 c=modern_place()
 for id in Model.Content.AMMO:
  if not Model.Content.is_temporary(id) and not c.model.s.deck.has(id) and c.model.s.deck.size()<c.model.deck_limit():c.model.s.deck.append(id)
 await mount_at(c,Vector2i(844,390));await stable();await tap("Tab3")
 var last=view().slots.get_child(view().slots.get_child_count()-1)
 await tap(str(last.name))
 check(view().selected==last.get_meta("ammo"),"horizontal inventory exposes all owned exact variants")
 # Resize an open workbench and exercise keyboard acceptance without changing run data.
 c=modern_place();await mount_at(c,Vector2i(1280,800));await stable()
 await tap("Tab0")
 var retained=str(view().slots.get_child(1).get_meta("ammo"))
 await tap("Owned_"+retained)
 var received=view().incoming
 var untouched=canonical({"campaign":c.s,"model":c.model.s})
 for extent in [Vector2i(2340,1080),Vector2i(844,390),Vector2i(1008,630)]:
  root.size=extent;await stable();geometry(extent)
  check(canonical({"campaign":c.s,"model":c.model.s})==untouched,"live resize does not mutate the run")
  check(view().mode==0 and view().selected==retained and view().incoming==received,"resize preserves both ends of the selected refit proposal")
 var tab: Button=view().get_node("Tabs/Tab3");tab.grab_focus()
 for pressed in [true,false]:
  var event=InputEventAction.new();event.action="ui_accept";event.pressed=pressed;root.push_input(event,true);await process_frame
 await stable()
 check(view().mode==3,"focused tab accepts keyboard action")
 check(canonical({"campaign":c.s,"model":c.model.s})==untouched,"keyboard tab is free")
 # Existing utility routes remain reachable without spending the workbench visit.
 await tap("Menu");await tap("Build")
 check(is_instance_valid(host.workspace_overlay),"workbench utility opens existing build inspection")
 await tap("workspace_close")
 await tap("Menu");await tap("Settings")
 check(host.find_child("SettingsDialog",true,false)!=null,"workbench utility opens existing settings modal")
 await tap("DialogClose")
 await tap("Menu");await tap("Archive")
 check(is_instance_valid(host.workspace_overlay),"workbench utility opens existing run archive")
 await tap("workspace_close")
 check(canonical({"campaign":c.s,"model":c.model.s})==untouched,"utility inspection never consumes work or changes ammo")
 await tap("Menu");await tap("ReturnTitle");check(host.page=="menu","workbench can return to title on touch")
 host.campaign=c;host.model=c.model;host.page="run";host.redraw();await stable()
 check(view()!=null and not c.s.resolved,"return from title retains unused work")
 # Older modern-place saves and resolved restores follow the new visual path with old rules.
 var old=place_fixture("workshop");await mount_at(old,Vector2i(1280,800));await stable()
 check(view()!=null,"older modern-place campaign uses the integrated screen")
 await tap("Tab4");check(view().proposal.valid==old.can_grow_bag(),"older bag rule is not replaced by a UI assumption")
 host.save_error="테스트: 저장 실패";view()._refresh()
 check(view().get_node("Inspector/Inset/BodyScroll/Content/Condition").text==host.save_error,"save errors remain visible in the new composition")
 host.save_error=""
 FileAccess.open(output.path_join("metrics.json"),FileAccess.WRITE).store_string(JSON.stringify(metrics,"  "))
 print("WORKSHOP STANDARD COMPLETE checks=%d failures=%d"%[checks,failures.size()])
 host.free();await settle();quit(0 if failures.is_empty() else 1)
