extends SceneTree
## Render review only, with the live body/weapon layer compositor.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var output := OS.get_environment("QA_OUTPUT_DIR")
	if output.is_empty():
		quit(1)
		return
	root.size = Vector2i(1280,820)
	var preview = load("res://redesign/weapon_concept_preview.tscn").instantiate()
	root.add_child(preview)
	await _capture(output,"concept_aim_1280")
	preview.toggle_before()
	await _capture(output,"existing_aim_1280")
	preview.toggle_before()
	for action in ["idle","recoil","reload_open","reload_seat","cooling"]:
		preview.set_pose(action)
		await _capture(output,"concept_"+action+"_1280")
	preview.set_pose("aim")
	for index in range(4): preview.cycle_outfit()
	await _capture(output,"recovery_aim_1280")
	root.size = Vector2i(1008,646)
	await _capture(output,"recovery_aim_1008")
	print("WEAPON CONCEPT RENDER: 9 captures; art-only scene, no campaign save access")
	quit()

func _capture(output: String, stem: String) -> void:
	for frame in range(12): await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(output.path_join(stem+".png"))
	if result != OK:
		push_error("Could not save: "+stem)
		quit(1)
