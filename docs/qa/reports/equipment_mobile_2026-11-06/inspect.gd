extends SceneTree

var host
var output: String
var rows: Array = []

func _initialize() -> void:
	run.call_deferred()

func settle() -> void:
	for frame in range(16): await process_frame

func rect_data(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\", "/").ends_with("/qa_runtime/equipment_mobile_20261106"):
		quit(2)
		return
	host = load("res://redesign/main.tscn").instantiate()
	host.save_enabled = false
	root.add_child(host)
	await settle()
	for extent in [Vector2i(1280,800), Vector2i(1170,540), Vector2i(2340,1080), Vector2i(2340,960)]:
		root.size = extent
		await settle()
		host._open_preparation(false)
		await settle()
		host.main_scroll.scroll_vertical = 0
		await settle()
		var view: Control = host.find_child("EquipmentScreen",true,false)
		var launch: Button = view.launch
		var scroll: ScrollContainer = host.main_scroll
		var stage: Control = view.find_child("Stage",true,false)
		var visible_rect := Rect2(Vector2.ZERO, Vector2(extent) / root.content_scale_factor)
		var controls: Dictionary = {}
		for node_name in ["Header", "Stage", "WeaponRail", "Footer"]:
			var node: Control = view.get_node("Margin/Layout/" + node_name)
			controls[node_name] = {"rect":rect_data(node.get_global_rect()),"minimum":node.get_combined_minimum_size().y}
		var row := {
			"physical_size":[extent.x,extent.y],
			"integer_scale":root.content_scale_factor,
			"logical_viewport":rect_data(visible_rect),
			"equipment_minimum_height":view.get_combined_minimum_size().y,
			"equipment_height":view.size.y,
			"layout_minimum_height":view.get_node("Margin/Layout").get_combined_minimum_size().y,
			"stage_minimum_height":stage.custom_minimum_size.y,
			"launch_rect":rect_data(launch.get_global_rect()),
			"launch_fully_visible":visible_rect.encloses(launch.get_global_rect()),
			"launch_hidden_below":maxf(0.0, launch.get_global_rect().end.y-visible_rect.end.y),
			"outer_scroll_extent":scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page,
			"sections":controls
		}
		await RenderingServer.frame_post_draw
		var image_name := "%dx%d_before.png" % [extent.x,extent.y]
		root.get_texture().get_image().save_png(output.path_join(image_name))
		row["capture"] = image_name
		rows.append(row)
		print(JSON.stringify(row))
	host.free()
	await settle()
	FileAccess.open(output.path_join("inspection.json"),FileAccess.WRITE).store_string(JSON.stringify({"scope":"Read-only native desktop reproduction at mobile landscape dimensions; no Android safe area or real touch test.","rows":rows},"  "))
	print("EQUIPMENT MOBILE INSPECTION COMPLETE")
	quit()
