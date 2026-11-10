extends SceneTree
var output: String
var captures: Array = []
var failures: Array = []
var viewer

func _initialize() -> void:
	run.call_deferred()

func settle() -> void:
	for i in range(12): await process_frame
	await RenderingServer.frame_post_draw

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/foundry_leaders/"):
		quit(1);return
	output = OS.get_environment("QA_OUTPUT_DIR")
	viewer = load("res://redesign/foundry_concept_preview.tscn").instantiate()
	root.add_child(viewer)
	await settle()
	if not viewer.standalone: failures.append("standalone detection")
	if viewer.stage.items.size()!=3: failures.append("leaders default")
	for extent in [Vector2i(1280,800),Vector2i(1008,630),Vector2i(1440,630)]:
		root.size = extent
		for group in [0,1]:
			viewer.groups[group].pressed.emit()
			for mode in [0,1]:
				viewer.modes[mode].pressed.emit()
				await settle()
				var stage = viewer.stage
				var expected := 4 if group==0 else 3
				if stage.actors.size()!=expected: failures.append("stale actors")
				for i in range(stage.drawn_rects.size()):
					var rect: Rect2 = stage.drawn_rects[i]
					if rect.position.x<0 or rect.end.x>stage.size.x or rect.position.y<0 or rect.end.y>stage.size.y:
						failures.append("clipping "+str(extent)+"/"+str(group)+"/"+str(mode)+"/"+str(i))
					if i>0 and rect.intersects(stage.drawn_rects[i-1]): failures.append("overlapping sprites")
					var point: Vector2 = stage.feet_points[i]
					if absf(point.y-stage.feet_points[0].y)>0.1: failures.append("feet alignment")
				for button in viewer.groups+viewer.modes:
					var rect: Rect2 = button.get_global_rect()
					if rect.end.x>root.get_visible_rect().size.x: failures.append("button clipping")
				var label: String = ("ordinary" if group==0 else "leaders")+"_"+("catalogue" if mode==0 else "battle")+"_"+str(extent.x)+"x"+str(extent.y)
				root.get_texture().get_image().save_png(output.path_join(label+".png"))
				var rect_data: Array = []
				for rect in stage.drawn_rects: rect_data.append([rect.position.x,rect.position.y,rect.size.x,rect.size.y])
				captures.append({"name":label,"logical_stage":[stage.size.x,stage.size.y],"rects":rect_data})
				print("CAPTURE ",label)
	# Comparison board rendered by the same Godot stage, not an edited bitmap.
	var contact := SubViewport.new()
	contact.size = Vector2i(1600,560)
	contact.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(contact)
	var preview_code = load("res://redesign/foundry_concept_preview.gd")
	var board = preview_code.Stage.new()
	board.items = [viewer.ordinary_items[1]]+viewer.leader_items
	board.size = Vector2(1600,560)
	contact.add_child(board)
	var heading := Label.new()
	heading.text = "축열 주조장 · 일반 금형공 / 정예 / 보스"
	heading.position = Vector2(26,20)
	heading.add_theme_font_override("font",preview_code.FONT)
	heading.add_theme_font_size_override("font_size",28)
	contact.add_child(heading)
	await settle()
	contact.get_texture().get_image().save_png(output.path_join("leaders_board.png"))
	contact.queue_free();await process_frame
	viewer.queue_free();await process_frame
	# Exercise the existing entry point, then close the overlay without exiting the game.
	var screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	await settle()
	screen._developer();await settle()
	var button = screen.find_child("debug_foundry_concepts",true,false)
	if button==null: failures.append("missing developer entry")
	else:
		button.pressed.emit();await settle()
		var panel = screen.find_child("FoundryConceptPreview",true,false)
		if panel==null: failures.append("developer entry did not open")
		else:
			if panel.standalone: failures.append("overlay incorrectly standalone")
			panel.groups[0].pressed.emit();await settle()
			panel.groups[1].pressed.emit();await settle()
			if panel.stage.items.size()!=3: failures.append("overlay group switching")
			panel.close();await settle()
			if screen.find_child("FoundryConceptPreview",true,false)!=null: failures.append("overlay did not close")
	var report = FileAccess.open(output.path_join("visual_qa.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"failures":failures,"captures":captures,"note":"Static concept viewer only. No battle balance, animation, phone or user-preference validation."},"  "))
	report.close()
	print("FOUNDRY LEADERS COMPLETE failures=",failures.size())
	screen.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
