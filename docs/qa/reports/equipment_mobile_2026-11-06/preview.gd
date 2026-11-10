extends SceneTree

var host
var output: String
var checks: Array = []
var rows: Array = []

func _initialize() -> void:
	run.call_deferred()

func settle() -> void:
	for frame in range(12): await process_frame

func verify(ok: bool, label: String) -> void:
	checks.append({"pass":ok,"label":label})
	if not ok: print("FAIL ", label)

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
	for extent in [Vector2i(1280,800),Vector2i(1170,540),Vector2i(2340,1080),Vector2i(2340,960)]:
		root.size = extent
		await settle()
		host.main_scroll.offset_bottom = 0
		host._open_preparation(false)
		await settle()
		var view: Control = host.find_child("EquipmentScreen",true,false)
		var styling = load(output.get_base_dir().path_join("equipment_visual_20261106/proposal/material.gd")).new()
		root.add_child(styling)
		styling.bind(view,host)
		await settle()
		host.main_scroll.scroll_vertical = 0
		await settle()
		var visible_rect := Rect2(Vector2.ZERO, Vector2(extent)/root.content_scale_factor)
		var initial_launch: Rect2 = view.launch.get_global_rect()
		var fixed := not visible_rect.encloses(initial_launch)
		var sizes: Dictionary = {}
		for button in view.find_children("*","Button",true,false):
			sizes[str(button.name)] = button.size
		if fixed:
			# Composition study only: this canvas keeps the existing footer in the
			# same owner tree. Production should author a footer outside its scroller.
			var layer := CanvasLayer.new()
			view.add_child(layer)
			var viewport_frame := Control.new()
			viewport_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			layer.add_child(viewport_frame)
			viewport_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			var edge := MarginContainer.new()
			viewport_frame.add_child(edge)
			edge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			edge.offset_left = 28
			edge.offset_right = -28
			edge.offset_top = -72
			edge.offset_bottom = -18
			var panel := StyleBoxFlat.new()
			panel.bg_color = Color("101613f5")
			panel.border_color = Color("5f614d")
			panel.border_width_top = 1
			var backdrop := Panel.new()
			viewport_frame.add_child(backdrop)
			viewport_frame.move_child(backdrop,0)
			backdrop.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			backdrop.offset_top = -82
			backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
			backdrop.add_theme_stylebox_override("panel",panel)
			var footer := view.get_node("Margin/Layout/Footer")
			footer.reparent(edge)
			host.main_scroll.offset_bottom = -82
			view._fit_layout()
			await settle()
		var stable: Rect2 = view.launch.get_global_rect()
		verify(visible_rect.encloses(stable),str(extent)+" start visible without scrolling")
		for button in view.find_children("*","Button",true,false):
			verify(button.size==sizes[str(button.name)],str(extent)+" preserves button size "+str(button.name))
		if not fixed: verify(stable==initial_launch,"desktop footer unchanged")
		await RenderingServer.frame_post_draw
		var image_name := "%dx%d_proposal.png" % [extent.x,extent.y]
		root.get_texture().get_image().save_png(output.path_join(image_name))
		host.main_scroll.scroll_vertical = 10000
		await settle()
		verify(view.launch.get_global_rect()==stable,str(extent)+" footer stays in place when body scrolls")
		var rail: Control = view.get_node("Margin/Layout/WeaponRail")
		verify(rail.get_global_rect().end.y <= host.main_scroll.get_global_rect().end.y,str(extent)+" bottom weapon rail can be revealed above footer")
		if fixed:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("%dx%d_scrolled.png" % [extent.x,extent.y]))
		rows.append({"physical_size":[extent.x,extent.y],"fixed_footer":fixed,"launch_rect":rect_data(stable),"body_viewport":rect_data(host.main_scroll.get_global_rect()),"body_scroll_extent":host.main_scroll.get_v_scroll_bar().max_value-host.main_scroll.get_v_scroll_bar().page,"capture":image_name})
		styling.free()
	host.free()
	await settle()
	var failures := checks.filter(func(row): return not row["pass"])
	FileAccess.open(output.path_join("preview.json"),FileAccess.WRITE).store_string(JSON.stringify({"scope":"Composition study only, production unchanged. Fixed footer is a QA canvas overlay, not production implementation or real mobile touch QA.","checks":checks,"failures":failures,"rows":rows},"  "))
	print("EQUIPMENT MOBILE PREVIEW COMPLETE checks=%d failures=%d" % [checks.size(),failures.size()])
	quit(0 if failures.is_empty() else 1)
