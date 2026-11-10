extends "res://tests/foundry_campaign_runner.gd"
## Feasibility probe using legitimately earned second-gate decks, not free powerful rounds.
func roundtrip(c) -> bool:
	# Later-depth fixtures deliberately skip route traversal, so validate combat saves.
	# Actual campaign entry/restore is checked separately below.
	before_save=c.model.s.duplicate(true)
	var restored=preload("res://redesign/model.gd").new()
	return check(restored.restore_state(JSON.parse_string(JSON.stringify(c.model.s))),"garden combat snapshot restores")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/garden_live/"):quit(1);return
	output=OS.get_environment("QA_OUTPUT_DIR")
	solver.candidate_limit=1000
	for gun in ["single","burst","scatter","heavy","amplifier"]:
		var source: String="res://tests/fixtures/garden_arrivals_20261024/"+gun+".json"
		var saved=JSON.parse_string(FileAccess.get_file_as_string(source))
		if not check(saved is Dictionary,"earned second-gate fixture "+gun):continue
		var entry=Campaign.new()
		check(entry.restore_state(saved),"actual second gate restore")
		entry.s.roster_version=9
		check(entry.gate("bag" if entry.can_grow_bag() else "credits"),"actual third region gate reward")
		check(entry.enter(entry.choices()[0].id),"actual third region first node")
		var entry_copy=Campaign.new()
		check(entry_copy.restore_state({"campaign":entry.s,"combat":entry.model.s,"profile":entry.profile}),"actual third-region campaign saves")
		for kind in ["elite","boss"]:
			var c=Campaign.new()
			if not check(c.restore_state(saved),"earned state restore"):continue
			c.s.roster_version=9
			check(c.gate("bag" if c.can_grow_bag() else "credits"),"real garden entry")
			var candidates: Array=c.current_nodes().filter(func(n):
				if kind=="boss":return n.kind=="boss"
				if kind=="elite":return bool(n.get("elite",false))
				return n.kind=="combat" and not n.get("elite",false) and (int(n.floor)<4 if kind=="early" else int(n.floor)>=5)
			)
			if not check(not candidates.is_empty(),"real garden node for "+kind):continue
			var node: Dictionary=candidates[0]
			c.s.node=node.id;c.s.floor=node.floor
			c._begin_combat(node)
			var initial: Dictionary=c.model.s.duplicate(true)
			var path: Array=solver.solve(c.model,6,18)
			if path.is_empty():path=solver.solve(c.model,12,22)
			for step in path:
				if not command(c,step):break
			var row: Dictionary={"path":path,"turns":int(before_save.get("turns",0))-int(initial.turns),"gun":gun,"kind":kind,"solved":not path.is_empty() and c.s.phase=="reward","deck":initial.deck,"parts":initial.equipped_parts,"used":before_save.get("discard",[]).size(),"total":initial.encounter_total}
			battles.append(row);print("GARDEN ",gun," ",kind," solved=",row.solved," turns=",row.turns," used=",row.used)
			check(row.solved,"earned garden feasibility "+gun+"/"+kind)
			await process_frame
	var file=FileAccess.open(output.path_join("balance.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"battles":battles},"  "));file.close()
	print("GARDEN LIVE BALANCE COMPLETE checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
