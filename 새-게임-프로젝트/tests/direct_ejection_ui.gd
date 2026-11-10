extends "res://tests/combat_hud_ui.gd"

func saved_bytes(journey: bool)->String:
 return FileAccess.get_file_as_string(preview.Journey.SAVE if journey else preview.COMPARISON_SAVE)

func mouse_click(id: String)->void:
 var target: Control=preview.node(id)
 var pos: Vector2=target.get_global_transform_with_canvas()*(target.size*0.5)
 for down in [true,false]:
  var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=pos;e.pressed=down
  root.push_input(e,true);await process_frame
 await settle()

func run()->void:
 out=OS.get_environment("QA_OUTPUT_DIR")
 if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/combat_hud_20261031/"):quit(2);return
 Input.emulate_mouse_from_touch=true
 for journey in [false,true]:
  for size in [Vector2i(844,390),Vector2i(1008,454),Vector2i(1280,800)]:
   root.size=size;root.content_scale_size=Vector2i(1280,800)
   var scene: PackedScene=JourneyScene if journey else Scene
   var suffix: String=("journey" if journey else "comparison")+"_%dx%d"%[size.x,size.y]
   preview=scene.instantiate();preview.resume_saved=false;root.add_child(preview);await settle()
   var pristine: Dictionary=canonical(preview.model.s)
   var save: String=saved_bytes(journey)
   check(preview.node("EjectToggle").disabled,"Empty selection cannot enter or execute removal")
   await tap("Select1")
   check(preview.eject_mode and preview.eject_selected==[1],"First card tap selects a middle round without entering a mode first")
   check(preview.node("EjectToggle").text=="1발 빼내기" and not preview.node("EjectToggle").disabled,"Header becomes the immediate one-round action")
   check(not preview.node("EjectApply").visible and preview.node("Fire").visible and preview.node("Fire").disabled,"Selection keeps actions in place and blocks mismatched firing")
   check(preview.last_prediction==preview.Forecast.analyze(preview.eject_preview,true),"Selection forecasts exactly the surviving magazine")
   check(canonical(preview.model.s)==pristine and saved_bytes(journey)==save,"Selection changes neither state, RNG nor saved bytes")
   hud_layout();await capture("one_selected_"+suffix)
   await tap("Fire")
   check(preview.eject_selected==[1] and canonical(preview.model.s)==pristine,"Disabled fire tap cannot cancel selection and fall through to firing")
   await tap("SelectedDetail")
   check(preview.node("Detail").visible and preview.node("DetailBody").text.begins_with("2번째 탄"),"Context details refer to the selected round")
   await tap("MagazineTitle");preview.toggle_ejection()
   check(preview.eject_selected==[1] and canonical(preview.model.s)==pristine,"Modal blocks blank cancellation and removal")
   await key(KEY_ESCAPE)
   check(not preview.overlay_open and preview.eject_selected==[1],"Closing details preserves planned selection")
   await tap("Select1")
   check(not preview.eject_mode and preview.hud.focused_round==-1,"Tapping the same round clears the selected context")
   await tap("Select1");await tap("MagazineTitle")
   check(not preview.eject_mode and canonical(preview.model.s)==pristine,"Blank-area touch cancels without spending anything")
   await mouse_click("Select1");await mouse_click("MagazineTitle")
   check(not preview.eject_mode and canonical(preview.model.s)==pristine,"Mouse uses the same selection and blank cancellation")
   preview.node("Select1").grab_focus();await key(KEY_ENTER)
   check(preview.eject_selected==[1],"Keyboard can select a round")
   await key(KEY_ESCAPE)
   check(not preview.eject_mode and saved_bytes(journey)==save,"Keyboard cancel restores the live forecast without saving")
   await tap("Menu");await tap("Help")
   check(preview.node("DetailBody").text.begins_with("탄환 선택 →") and preview.node("DetailBody").text.contains("선택 취소"),"Help explains the new selection, cancellation and details controls")
   await tap("CloseDetail");await tap("Select1")
   var predicted: Dictionary=canonical(preview.eject_preview)
   await tap("EjectToggle")
   check(canonical(preview.Model.simulation_state(preview.model.s))==predicted,"Second tap on the header immediately commits the previewed one-round removal")
   check(preview.model.s.magazine==pristine.magazine.slice(0,1)+pristine.magazine.slice(2),"Only selected middle round is removed; relative order survives")
   check(preview.model.s.turns==pristine.turns and preview.model.s.heat==pristine.heat and canonical(preview.model.s.enemies)==pristine.enemies,"Removal consumes no time or heat and does not move enemies")
   check(not preview.eject_mode and preview.eject_selected.is_empty() and preview.hud.focused_round==-1,"Shifted rounds are never automatically selected")
   check(preview.model.ejection_remaining()==1 and preview.node("EjectToggle").disabled,"Quota spent once and removal button immediately disables")
   var committed: Dictionary=canonical(preview.model.s)
   await tap("EjectToggle")
   check(canonical(preview.model.s)==committed,"A second press cannot remove a shifted round")
   await tap("Select0");await tap("Round%d"%(preview.model.capacity()-1))
   check(not preview.eject_mode,"An empty magazine socket is also a cancellation area")
   await capture("removed_"+suffix)
   await tap("Select0")
   preview.queue_free();await settle();preview=scene.instantiate();root.add_child(preview);await settle()
   check(preview.resumed and canonical(preview.model.s)==committed and not preview.eject_mode,"Reopening restores removal and quota but never an uncommitted selection")
   preview.mount(false);await settle()
   pristine=canonical(preview.model.s)
   await tap("Select3");await tap("Select1")
   check(preview.eject_selected==[3,1] and preview.node("EjectToggle").text=="2발 빼내기","Two nonadjacent rounds can be selected in reverse order")
   await tap("Select0")
   check(preview.eject_selected==[3,1],"Third pick cannot exceed the per-magazine allowance")
   await tap("Select1");check(preview.eject_selected==[3],"Selected round remains deselectable at limit")
   await tap("Select1");hud_layout();await capture("two_selected_"+suffix)
   preview.node("EjectToggle").grab_focus();await key(KEY_ENTER)
   check(preview.model.s.magazine==pristine.magazine.slice(0,1)+pristine.magazine.slice(2,3)+pristine.magazine.slice(4),"Keyboard confirms exactly both selected positions")
   check(preview.model.ejection_remaining()==0 and not preview.eject_mode,"Two removals exhaust the magazine allowance")
   committed=canonical(preview.model.s)
   await tap("Select0")
   check(not preview.eject_mode and preview.node("EjectToggle").disabled and preview.node("SelectedDetail").visible,"After quota is spent, card selection still exposes details")
   check(preview.overlay_open and preview.node("Detail").visible,"After quota is spent a card tap opens its details directly")
   await capture("quota_details_"+suffix);await tap("CloseDetail")
   check(canonical(preview.model.s)==committed,"Details never spend an extra removal")
   await tap("Fire")
   check(preview.model.s.shots>committed.shots and preview.model.ejection_remaining()==0,"Public firing after quota depletion preserves the exhausted allowance")
   check(preview.hud.focused_round==-1,"Firing clears stale detail context")
   if preview.model.s.phase=="ready" and not preview.node("Reload").disabled:
    await tap("Reload")
    if preview.model.s.phase=="ready":check(preview.model.ejection_remaining()==2,"Paid magazine exchange restores allowance")
   preview.queue_free();await settle()
 # Owned-ammo boundary fixture, not a claim about a naturally played route.
 root.size=Vector2i(1280,800)
 preview=Scene.instantiate();preview.resume_saved=false;root.add_child(preview);await settle()
 var pool: Array=preview.model.s.magazine+preview.model.s.hand+preview.model.s.draw
 var attack: String=""
 for id in pool:
  if preview.Content.is_attack(id):attack=id;break
 pool.erase(attack)
 preview.model.s.magazine=[attack];preview.model.s.hand=[];preview.model.s.draw=[]
 preview.model.s.discard.append_array(pool);preview.model.s.emergency_version=0
 preview.refresh();await settle();await tap("Select0")
 check(preview.node("EjectToggle").text=="빼내면 패배","Complete exhaustion warning remains visible on the immediate removal button")
 hud_layout();await capture("exhaustion_boundary")
 await tap("EjectToggle")
 check(preview.model.s.phase=="lost" and preview.node("EjectToggle").disabled,"Removing the final available attack follows existing exhaustion rules")
 preview.queue_free();await settle()
 FileAccess.open(out.path_join("direct.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"action_animation_ms":action_times,"note":"Real touch, mouse and keyboard input; isolated comparison/journey saves; three viewport sizes. Final exhaustion is an explicitly constructed owned-ammo boundary fixture."},"  "))
 print("DIRECT EJECTION COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
