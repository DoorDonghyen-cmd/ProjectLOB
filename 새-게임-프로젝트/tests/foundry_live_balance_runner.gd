extends "res://tests/foundry_campaign_runner.gd"
## Bounded reachability audit: real earned decks, no grants or edits to their piles.
func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/foundry_live/"):quit(1);return
	output=OS.get_environment("QA_OUTPUT_DIR")
	solver.candidate_limit=700
	var rows: Array=[]
	for gun in ["single","burst","scatter","heavy","amplifier"]:
		for kind in ["elite","boss"]:
			var c=Campaign.new()
			var source:="res://tests/fixtures/foundry_arrivals_20261023/%s_%s.json"%[gun,kind]
			if not check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(source))),"earned arrival restores "+gun):continue
			c.s.roster_version=8;c._begin_combat(c.node())
			var before: Dictionary=c.model.s.duplicate(true)
			before_save=before.duplicate(true)
			var path: Array=solver.solve(c.model,12 if gun=="heavy" else 4,14)
			if path.is_empty():
				solver.candidate_limit=1500;path=solver.solve(c.model,12,18);solver.candidate_limit=700
			if path.is_empty() and gun=="heavy":
				print("WIDER SEARCH ",gun," ",kind)
				solver.candidate_limit=3000;path=solver.solve(c.model,40,20);solver.candidate_limit=700
			for step in path:
				if not command(c,step):break
			var row={"gun":gun,"kind":kind,"source":source,"deck":before.deck,"parts":before.equipped_parts,"solved":not path.is_empty() and c.s.phase=="reward","path":path,"turns":int(before_save.get("turns",0))-int(before.turns),"used":before_save.get("discard",[]).size()}
			rows.append(row)
			print("REACHABILITY ",gun," ",kind," solved=",row.solved," turns=",row.turns," used=",row.used)
			check(row.solved,"earned deck winning path "+gun+"/"+kind)
			var file=FileAccess.open(output.path_join("balance.json"),FileAccess.WRITE)
			file.store_string(JSON.stringify({"checks":checks,"failures":failures,"encounters":rows},"  "));file.close()
			await process_frame
	print("FOUNDRY LIVE BALANCE COMPLETE checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
