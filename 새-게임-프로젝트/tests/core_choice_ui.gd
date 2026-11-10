extends "res://tests/campaign_magazine_ui.gd"
## RETIRED 2026-11-08 as a run target: checks old build workshop buttons (city_part_select_*). Replaced by: build_live_ui, reward_live_runner.
## Current UI suites: docs/qa/ui-test-suites.md
func run()->void:
 output=OS.get_environment("QA_OUTPUT_DIR");Input.emulate_mouse_from_touch=true
 if not output.replace("\\","/").contains("/qa_runtime/core_choice_20261103/"):quit(2);return
 var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../qa_runtime/build_roles_20261103/climb_earned/gate_heavy_17_r2.json"))
 for extent in [Vector2i(1280,800),Vector2i(844,390),Vector2i(2340,1080)]:
  if is_instance_valid(host):host.free()
  root.size=extent;root.content_scale_factor=1;root.content_scale_size=Vector2i(1280,800)
  var c=Campaign.new();check(c.restore_state(source),"earned core inventory restores")
  c.s.specialist_core_version=1;c.model.s.specialist_core_version=1
  var unchanged=canonical({"campaign":c.s,"combat":c.model.s})
  await mount(c);await tap("city_deck");await tap("city_part_select_inferno")
  var effect: Label=host.find_child("PartEffectChanges",true,false)
  var delta: Label=host.find_child("PartChangePreview",true,false)
  check(effect.text.contains("2.70") and effect.text.contains("화상 +6") and effect.text.contains("소이탄"),"preview shows current growth, specialist benefit and owned ammo")
  check(delta.text.contains("6 → 8") and delta.text.contains("기록 보존"),"preview shows burn delta and retained growth")
  check(canonical({"campaign":c.s,"combat":c.model.s})==unchanged,"inspection does not modify run state or RNG")
  var scroll: ScrollContainer=host.find_child("WorkspaceScroll",true,false)
  scroll.ensure_control_visible(delta);await settle()
  check(scroll.get_h_scroll_bar().max_value<=scroll.get_h_scroll_bar().page+2,"core comparison fits small screen width")
  await capture("core_choice_%dx%d"%[extent.x,extent.y])
  await tap("city_deck_equip_inferno")
  check(c.s.equipped_parts.has("inferno") and not c.s.equipped_parts.has("thermal_drive"),"public replacement respects single core limit")
  var restored=Campaign.new();check(restored.restore() and canonical(restored.s)==canonical(c.s) and canonical(restored.model.s)==canonical(c.model.s),"replacement autosaves exact versioned state")
  await tap("part_rules");await capture("inferno_rules_%dx%d"%[extent.x,extent.y])
  await mount(c);await tap("city_deck");await tap("city_part_select_thermal_drive");await tap("city_deck_equip_thermal_drive")
  check(c.model.s.engine.levels.thermal_drive==8 and c.is_equipped("thermal_drive"),"public swap-back preserves earned growth")
  check(c.model.Content.burn_damage(c.model.s)==6,"swap-back resumes thermal burn calculation")
 # A genuinely earned new-run specialist battle through the production HUD.
 var battle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../qa_runtime/core_choice_20261103/climb_fresh17/combat_heavy_17_r3_n20502.json"))
 for extent in [Vector2i(1280,800),Vector2i(2340,1080)]:
  root.size=extent
  var c=Campaign.new();check(c.restore_state(battle),"actual newly earned specialist encounter restores")
  check(c.model.s.specialist_core_version==1 and c.is_equipped("inferno"),"earned encounter uses new specialist without promotion")
  await mount(c);hud_bounds()
  host.campaign_hud.hud.feedback.save_setting("motion","fast")
  var unchanged: Dictionary=canonical(c.model.s)
  await capture("earned_inferno_%dx%d"%[extent.x,extent.y])
  check(canonical(c.model.s)==unchanged,"live preview and capture leave state and RNG unchanged")
  var oracle=Model.new();oracle.s=c.model.s.duplicate(true)
  check(oracle.fire(),"earned specialist oracle fires")
  await tap("Fire")
  check(canonical(c.model.s)==canonical(oracle.s),"public specialist fire exactly matches real resolver")
  check(c.model.s.history.back().detail.results[0].burn_tick==8,"earned thermal growth contributes live burn")
  var saved=Campaign.new();check(saved.restore() and canonical(saved.model.s)==canonical(c.model.s),"specialist fire autosaves exact combat")
  await capture("earned_inferno_fired_%dx%d"%[extent.x,extent.y])
 host.free();await settle()
 FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
 print("CORE CHOICE COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
