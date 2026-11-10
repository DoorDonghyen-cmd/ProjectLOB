extends "res://tests/weapon_magazine_ui.gd"
func run() -> void:
	out=OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/weapon_magazine_20261031/"): quit(2); return
	preview=load("res://redesign/samples/combat_weapon_magazine.tscn").instantiate();preview.resume_saved=false;root.add_child(preview);Input.emulate_mouse_from_touch=true;await settle()
	preview.gun_index=2;preview.case_index=1;preview.mount(false);await settle()
	var rows: Array=JSON.parse_string(FileAccess.get_file_as_string(out.get_base_dir().path_join("rules/rules.json"))).audit
	for row in rows:
		if row.gun!="scatter" or row.role!="boss" or row.seed!=0: continue
		for action in row.alternate: await tap({"fire":"Fire","cool":"Cool","swap":"Reload","emergency":"Reload"}[action])
	await settle();check(preview.model.s.phase in ["won","reward"] and not preview.model.has_remaining_enemies(),"Actual final victory clears all enemies")
	check(preview.board.enemies == preview.model.s.enemies and preview.board._alive_indices().is_empty(),"Terminal displayed enemies match model")
	await capture("terminal_model")
	var children: Array=[]
	for child in preview.board.get_children(): children.append({"name":child.name,"class":child.get_class(),"script":child.get_script().resource_path if child.get_script() else ""})
	FileAccess.open(out.path_join("terminal.json"),FileAccess.WRITE).store_string(JSON.stringify({"model":preview.model.s.enemies,"board":preview.board.enemies,"alive":preview.board._alive_indices(),"children":children,"checks":checks,"failures":failures},"  "))
	print("TERMINAL COMPLETE checks=%d failures=%d" % [checks,failures.size()]);preview.queue_free();await settle();quit(0 if failures.is_empty() else 1)
