extends "res://tests/pipe_map_ui.gd"
func _run()->void:
 if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/maps/crossed_guns_20261101/"):quit(2);return
 output=OS.get_environment("QA_OUTPUT_DIR");Input.emulate_mouse_from_touch=true
 var c=Campaign.new();c.start("single",731042,0,"balanced",3,"carrier",true);c.advance_departure(true)
 await review_earned_map(c)
 var file:=FileAccess.open(output.path_join("result.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":failures,"screens":visual_checks},"  "));file.close()
 print("CROSSED GUNS COMPLETE checks=%d failures=%d"%[checks,failures.size()])
 quit(0 if failures.is_empty() else 1)

