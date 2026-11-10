extends "res://tests/campaign_magazine_ui.gd"
func run()->void:
 output=OS.get_environment("QA_OUTPUT_DIR")
 if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/campaign_magazine_20261101/"):quit(2);return
 Input.emulate_mouse_from_touch=true
 var expected_file:=output.path_join("expected.json")
 if OS.get_environment("QA_RESUME_PHASE")=="write":
  var c=Campaign.new();c.start("heavy",731042,0,"balanced",3,"carrier",true);c.enter(101)
  await mount(c);await tap("Select1");await tap("EjectToggle")
  check(c.model.ejection_remaining()==1,"writer uses one ejection")
  var file=FileAccess.open(expected_file,FileAccess.WRITE)
  file.store_string(JSON.stringify({"campaign":c.s,"combat":c.model.s,"profile":c.profile}));file.close()
 else:
  host=load("res://redesign/main.tscn").instantiate();root.add_child(host);await settle()
  await tap("resume")
  var expected: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(expected_file))
  check(canonical({"campaign":host.campaign.s,"combat":host.model.s,"profile":host.campaign.profile})==expected,"fresh process resumes exact main campaign, piles, RNG and quotas")
  hud_bounds();check(host.model.ejection_remaining()==1,"fresh process preserves used ejection allowance")
 host.free();await settle()
 print("CAMPAIGN RESTART COMPLETE phase=%s checks=%d failures=%d"%[OS.get_environment("QA_RESUME_PHASE"),checks,failures.size()])
 quit(0 if failures.is_empty() else 1)
