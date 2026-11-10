extends "res://tests/combat_ui_stage1_ui.gd"

func run() -> void:
	out=OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/combat_ui_stage1_20261031/"):quit(2);return
	Input.emulate_mouse_from_touch=true
	var initial_children: Array=root.get_children().map(func(n):return n.get_instance_id())
	preview=load("res://redesign/samples/combat_ui_stage1_a.tscn").instantiate()
	root.add_child(preview);current_scene=preview;await settle()
	await tap("Other");preview=current_scene
	check(preview.composition=="B","A to B through real touch")
	await tap("Pressure");check(preview.pressure,"B pressure toggle after entry")
	await tap("Other");preview=current_scene
	check(preview.composition=="A" and not preview.pressure,"B to A reopens documented default fixture")
	preview.queue_free();await settle()
	check(root.get_children().map(func(n):return n.get_instance_id())==initial_children,"Preview exits without leftover scenes")
	FileAccess.open(out.path_join("navigation.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("STAGE1 NAVIGATION COMPLETE checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
