extends "res://tests/combat_hud_ui.gd"
func run()->void:
 out=OS.get_environment("QA_OUTPUT_DIR")
 if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/combat_hud_20261031/"):quit(2);return
 Input.emulate_mouse_from_touch=true
 Input.emulate_touch_from_mouse=true
 root.size=Vector2i(740,360)
 preview=Scene.instantiate();preview.resume_saved=false;root.add_child(preview);await settle()
 preview.gun_index=1;preview.case_index=1;preview.mount(false);await settle()
 var before: Dictionary=canonical(preview.model.s)
 var strip: ScrollContainer=preview.node("MagazineHousing")
 check(preview.node("RoundRow").size.x>strip.size.x,"Wide magazine really requires horizontal scrolling")
 var start:=strip.get_global_rect().get_center()+Vector2(150,0)
 var press:=InputEventScreenTouch.new();press.index=0;press.position=start;press.pressed=true
 press.window_id=root.get_window_id();Input.parse_input_event(press);await process_frame
 for step in range(1,16):
  var drag:=InputEventScreenDrag.new();drag.index=0;drag.position=start-Vector2(step*20,0);drag.relative=Vector2(-20,0)
  drag.window_id=root.get_window_id();drag.screen_relative=drag.relative
  Input.parse_input_event(drag);await create_timer(0.018).timeout
 var release:=InputEventScreenTouch.new();release.index=0;release.position=start-Vector2(300,0);release.pressed=false
 release.window_id=root.get_window_id();Input.parse_input_event(release);await create_timer(0.4).timeout;await settle()
 check(strip.scroll_horizontal>0,"Real touch drag scrolls the magazine")
 check(not preview.eject_mode and canonical(preview.model.s)==before,"Swiping cannot select, remove or spend a round")
 var last: int=preview.model.s.magazine.size()-1
 preview.node("Select%d"%last).grab_focus();await settle()
 check(strip.get_global_rect().encloses(preview.node("Select%d"%last).get_global_rect()),"Keyboard focus reveals the final loaded round")
 await tap("Select%d"%last)
 check(preview.eject_selected==[last],"Visible final round is touch-selectable after scrolling")
 await capture("last_round_selected")
 FileAccess.open(out.path_join("scroll.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures}))
 print("PROTOTYPE HUD SCROLL COMPLETE checks=%d failures=%d"%[checks,failures.size()])
 preview.queue_free();await settle();quit(0 if failures.is_empty() else 1)
