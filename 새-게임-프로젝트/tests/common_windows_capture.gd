extends SceneTree
## Captures the common windows (settings, guide, rules, archive) from the title and,
## for settings, over the map. Used before/after the common-window rework (2026-11-08).
var host
var output: String

func _initialize() -> void: run.call_deferred()

func settle() -> void:
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw

func capture(label: String) -> void:
	await settle()
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))

func clear_overlays() -> void:
	host._close_workspace()
	for child in host.get_children():
		if child.has_method("setup") or str(child.name).begins_with("ConsoleDialog") or child.get_class() == "Control" and child.z_index >= 200: child.queue_free()
	await settle()

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	output = OS.get_environment("QA_OUTPUT_DIR")
	for extent in [Vector2i(1280, 800), Vector2i(844, 390)]:
		root.size = extent
		var suffix := "%dx%d" % [extent.x, extent.y]
		if is_instance_valid(host): host.free()
		host = load("res://redesign/main.tscn").instantiate()
		root.add_child(host)
		await settle()
		for entry in [["settings", "_settings"], ["guide", "_guide"], ["rules", "_rules"], ["archive", "_city_archive"]]:
			host.call(entry[1])
			await capture(entry[0] + "_" + suffix)
			await clear_overlays()
	print("COMMON WINDOWS CAPTURED")
	quit(0)
