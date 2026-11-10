extends "res://tests/combat_hud_ui.gd"
## Regression: real actions used to permanently hide intent and discard HP forecasts.
func flow_tap(id: String)->void:
 while preview.flow_input_locked:await process_frame
 await tap(id)
 while preview.flow_input_locked:await process_frame
func readouts(context: String)->void:
 check(preview.board.inspection_enabled,"Enemy intent returns while idle: "+context)
 check(canonical(preview.board.forecast)==canonical(preview.last_prediction),"Battlefield receives the same public forecast as fire/heat: "+context)
 for i in range(preview.model.s.enemies.size()):
  var e: Dictionary=preview.model.s.enemies[i]
  if int(e.hp)<=0:continue
  check(not preview.board.threat_readouts.get(i,{}).get("text","").is_empty(),"Living enemy has next-action intent: "+context)
  if not preview.last_prediction.is_empty():
   var projected: Dictionary=preview.last_prediction.enemies[i]
   check(preview.board._line_remaining_hp(i)==clampi(int(projected.get("hp_max",projected.hp)),0,int(e.hp)),"Gold HP cells represent guaranteed forecast: "+context)
func run()->void:
 out=OS.get_environment("QA_OUTPUT_DIR")
 if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/combat_hud_20261031/"):quit(2);return
 Input.emulate_mouse_from_touch=true
 for size in [Vector2i(844,390),Vector2i(1280,800)]:
  root.size=size;root.content_scale_size=Vector2i(1280,800)
  preview=JourneyScene.instantiate();preview.resume_saved=false;root.add_child(preview);await settle()
  var suffix: String="%dx%d"%[size.x,size.y]
  readouts("opening");await capture("opening_"+suffix)
  await tap("Fire");readouts("after fire");await capture("after_fire_"+suffix)
  await tap("Cool");readouts("after cooling")
  await tap("Reload");readouts("after swap")
  var before: Dictionary=canonical(preview.model.s)
  await tap("Select1");readouts("ejection preview")
  check(canonical(preview.model.s)==before,"Preview does not alter owned ammo, time, growth or RNG")
  await tap("EjectToggle");readouts("after ejection")
  hud_layout();preview.queue_free();await settle()
 # Random targeting must keep a range, including after its first action.
 preview=Scene.instantiate();preview.resume_saved=false;root.add_child(preview);await settle()
 preview.gun_index=2;preview.case_index=1;preview.mount(false);await settle()
 check(preview.last_prediction.get("random",false),"Scatter keeps public probability forecast")
 readouts("scatter before");await tap("Fire");readouts("scatter after")
 await capture("scatter_after")
 preview.queue_free();await settle()
 # Earn the same second-fight opportunity observed through native UI. No
 # injected reward, reordered deck, or hidden-RNG solver drives these inputs.
 preview=JourneyScene.instantiate();preview.resume_saved=false;root.add_child(preview);await settle()
 for i in range(3):await tap("Fire")
 await flow_tap("RewardPick2");await flow_tap("JourneyConfirm")
 await flow_tap("RewardPick0");await flow_tap("JourneyConfirm")
 await flow_tap("JourneyConfirm")
 check(preview.journey.phase()=="combat" and int(preview.journey.campaign.s.node)==201,"Real core/ammo reward leads to the second battle")
 readouts("earned reward");await capture("earned_before_ejection")
 var unchanged=preview.Model.new();unchanged.s=preview.Model.simulation_state(preview.model.s)
 var unchanged_inputs:=0
 while unchanged.s.phase=="ready" and unchanged_inputs<3:
  check(unchanged.fire(),"As-is alternative remains legal");unchanged_inputs+=1
 check(unchanged_inputs==2 and unchanged.s.phase in ["won","reward"],"Firing as-is wins with two inputs")
 await tap("Select1");readouts("earned ejection preview");await capture("earned_ejection_preview")
 await tap("EjectToggle");await tap("Fire")
 check(preview.journey.phase()=="reward","One fire after ejection actually wins")
 var outcome: Dictionary=preview.journey.results.back()
 check(outcome.ejected==1 and outcome.shots==2 and outcome.turns==1 and outcome.used==3,"Ejection trades one round for one fewer enemy action")
 check(unchanged.s.discard.size()==outcome.used,"Both alternatives consume three total rounds")
 FileAccess.open(out.path_join("readout.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
 print("JOURNEY READOUT COMPLETE checks=%d failures=%d"%[checks,failures.size()])
 preview.queue_free();await settle();quit(0 if failures.is_empty() else 1)
