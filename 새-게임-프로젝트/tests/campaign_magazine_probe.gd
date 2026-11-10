extends "res://tests/campaign_magazine_ui.gd"
func run()->void:
 output=OS.get_environment("QA_OUTPUT_DIR")
 if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/campaign_magazine_20261101/"):quit(2);return
 Input.emulate_mouse_from_touch=true
 var evidence:=ProjectSettings.globalize_path("res://../qa_runtime/campaign_magazine_20261101/rules")
 var folder:=DirAccess.open(evidence)
 for region in range(5):
  var candidates: Array=[]
  for file in folder.get_files():
   if file.begins_with("combat_single_731042_r%d_"%(region+1)):candidates.append(file)
  candidates.sort()
  if not check(not candidates.is_empty(),"earned region snapshot available"):continue
  for extent in [Vector2i(1280,800),Vector2i(844,390)]:
   var c=Campaign.new();check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(evidence.path_join(candidates.back())))),"earned regional state restores")
   root.size=extent;await mount(c);hud_bounds()
   await capture("region_%d_%dx%d"%[region+1,extent.x,extent.y])
   var selected:=0
   for i in range(c.model.s.enemies.size()):
    if c.model.s.enemies[i].hp>0:selected=i;break
   host.campaign_hud.inspect_enemy(selected)
   check(host.campaign_hud.overlay_open,"regional details open")
   await tap("CloseDetail")
   await tap("Select1");await tap("EjectToggle")
   check(c.model.ejection_remaining()==1,"regional ejection works")
 var large=Campaign.new();large.start("heavy",731042,0,"balanced",3,"carrier",true)
 large.s.slots=2;large.s.parts=["supply"];large.s.equipped_parts=["supply"]
 large.enter(101);root.size=Vector2i(844,390);await mount(large);hud_bounds()
 check(large.model.capacity()==12 and host.campaign_hud.slot_count==12,"twelve sockets bound")
 await tap("Select11");await tap("EjectToggle")
 check(large.model.s.magazine.size()==11,"expanded final round removed")
 await capture("expanded")
 var earned:=output.get_base_dir().path_join("rules")
 var thermal=Campaign.new()
 check(thermal.restore_state(JSON.parse_string(FileAccess.get_file_as_string(earned.path_join("combat_heavy_731042_r1_n201.json")))),"earned heat core restores")
 root.size=Vector2i(1280,800);await mount(thermal)
 host.campaign_hud.hud.feedback.show_heat(5)
 check(host.campaign_hud.node("HeatCells").limit==Model.Content.heat_limit(thermal.model.s),"animated heat uses equipped core limit")
 var won=Campaign.new()
 check(won.restore_state(JSON.parse_string(FileAccess.get_file_as_string(earned.path_join("won_single_731042.json")))),"earned ending restores")
 await mount(won);await tap("story_restore");await tap("story_results")
 check(not won.restoration_pending() and won.profile.wins==1,"ending interaction completes without duplicate win")
 await capture("results")
 var loss=Campaign.new();loss.start("single",731042,0,"balanced",3,"carrier",true);loss.enter(101)
 await mount(loss)
 for i in range(20):
  if loss.s.phase!="combat":break
  host.campaign_hud.board.speed_scale=0.01
  await tap("Reload")
 check(loss.s.phase=="lost" and not is_instance_valid(host.campaign_hud),"actual enemy contact opens main defeat screen")
 await capture("defeat")
 host.free();await settle()
 print("CAMPAIGN PROBE COMPLETE checks=%d failures=%d"%[checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
