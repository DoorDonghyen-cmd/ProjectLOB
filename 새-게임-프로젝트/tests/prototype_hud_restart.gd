extends "res://tests/combat_hud_ui.gd"
func run()->void:
 out=OS.get_environment("QA_OUTPUT_DIR")
 if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/combat_hud_20261031/"):quit(2);return
 Input.emulate_mouse_from_touch=true
 root.size=Vector2i(844,390)
 var writing:=OS.get_environment("QA_RESUME_PHASE")=="write"
 preview=JourneyScene.instantiate();preview.resume_saved=not writing
 root.add_child(preview);await settle()
 var checkpoint:=out.path_join("expected.json")
 if writing:
  await tap("Select1");await tap("EjectToggle");await tap("Fire")
  check(preview.model.ejection_remaining()==1 and preview.model.s.shots==2,"Public actions produce a partial magazine and spent quota")
  FileAccess.open(checkpoint,FileAccess.WRITE).store_string(JSON.stringify(preview.journey.data()))
 else:
  check(preview.resumed,"Fresh engine process loads the saved journey")
  check(canonical(preview.journey.data())==JSON.parse_string(FileAccess.get_file_as_string(checkpoint)),"Fresh process preserves full campaign, RNG, deck order and combat state")
  var before: int=preview.model.s.shots
  await capture("resumed")
  await tap("Fire")
  check(preview.model.s.shots>before,"Resumed combat accepts the next real input")
 check(not FileAccess.file_exists(preview.Journey.Campaign.SAVE),"Restart never writes the main campaign save")
 FileAccess.open(out.path_join("write.json" if writing else "read.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures}))
 print("PROTOTYPE HUD RESTART COMPLETE phase=%s checks=%d failures=%d"%["write" if writing else "read",checks,failures.size()])
 preview.queue_free();await settle();quit(0 if failures.is_empty() else 1)
