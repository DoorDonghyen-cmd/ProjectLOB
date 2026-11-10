extends "res://tests/magazine_journey_ui.gd"
func mount_saved(node_id: int)->void:
 var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(out.get_base_dir().path_join("rules/checkpoint_single_%d.json"%node_id)))
 check(preview.journey.restore_state(saved.journey),"Visual scene uses verified earned checkpoint")
 preview.model=preview.journey.campaign.model;preview.panel_mode="flow";preview.selected_reward=""
 preview.persist();preview.set_backdrop();preview.refresh();await settle()
func run()->void:
 out=OS.get_environment("QA_OUTPUT_DIR")
 if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/magazine_journey_20261031/"):quit(2);return
 Input.emulate_mouse_from_touch=true
 preview=load("res://redesign/samples/combat_magazine_journey.tscn").instantiate();preview.resume_saved=false;root.add_child(preview);await settle()
 for size in [Vector2i(1008,630),Vector2i(1280,576),Vector2i(1280,800)]:
  root.size=size;root.content_scale_size=Vector2i(1280,800)
  var suffix: String="%dx%d"%[size.x,size.y]
  await mount_saved(101);panel_layout();await tap("RewardPick2");await capture("core_selected_"+suffix)
  await tap("JourneyConfirm");panel_layout();await capture("ammo_"+suffix)
  for i in range(3):
   var icon: Control=preview.node("RewardIcon%d"%i)
   check(icon.global_position.y+icon.size.y*0.5-47>=preview.node("RewardPick%d"%i).global_position.y,"Actual artwork stays below card top")
   var artwork_bottom: float=icon.global_position.y+icon.size.y*0.5+50
   check(artwork_bottom<preview.node("RewardTag%d"%i).global_position.y,"Actual cartridge artwork and shadow clear the role label")
  await tap("RewardPick0");await tap("JourneyConfirm");await tap("JourneyConfirm")
  weapon_layout();await capture("earned_second_fight_"+suffix)
  await mount_saved(401);await tap("RewardPick0");await tap("JourneyConfirm");await capture("growth_"+suffix)
  await tap("JourneyConfirm");panel_layout();await capture("service_"+suffix)
  await tap("JourneyCancel");check(preview.journey.phase()=="map","Public service skip retains deck");await tap("JourneyConfirm")
  check(preview.journey.phase()=="combat","Skipped refit still proceeds")
  await mount_saved(201);var old_deck: Array=preview.model.s.deck.duplicate();await tap("JourneyCancel")
  check(preview.journey.phase()=="map" and preview.model.s.deck==old_deck,"Public optional reward skip retains deck")
  await mount_saved(802);await tap("RewardPick0");await tap("JourneyConfirm");panel_layout();await capture("complete_"+suffix)
 FileAccess.open(out.path_join("visual.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
 print("JOURNEY VISUAL COMPLETE checks=%d failures=%d"%[checks,failures.size()]);preview.queue_free();await settle();quit(0 if failures.is_empty() else 1)
