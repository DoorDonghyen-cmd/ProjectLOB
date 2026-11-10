extends "res://tests/foundry_campaign_runner.gd"
## Replay the final encounter adjustment from actual earned campaign arrival states.
func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/foundry/"):quit(1);return
	output=OS.get_environment("QA_OUTPUT_DIR")
	solver.candidate_limit=700
	var seed_value:=int(OS.get_environment("QA_SEED"))
	var source:=OS.get_environment("QA_FOUNDRY_CAMPAIGN")
	for gun in ["single","burst","scatter","heavy","amplifier"]:
		search_width=12 if gun=="heavy" else 4
		var c=Campaign.new()
		var path:=source.path_join("combat_%s_10902.json"%gun)
		var payload=JSON.parse_string(FileAccess.get_file_as_string(path))
		if not check(payload is Dictionary and c.restore_state(payload),"earned boss arrival restores "+gun):continue
		check(c.node().kind=="boss" and int(c.s.region)==1,"real second-region boss arrival")
		commands=[]
		c._begin_combat(c.node())
		await second_region(c,gun,seed_value)
	var file=FileAccess.open(output.path_join("boss.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"source":source,"checks":checks,"failures":failures,"battles":battles,"runs":endpoints},"  "));file.close()
	print("FOUNDRY BOSS COMPLETE checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
