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
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/foundry_concepts/"):quit(1);return
	output=OS.get_environment("QA_OUTPUT_DIR")
	viewer=load("res://redesign/foundry_concept_preview.tscn").instantiate()
	root.add_child(viewer)
	for extent in [Vector2i(1280,800),Vector2i(1008,630),Vector2i(1440,630)]:
		root.size=extent
		for mode in [0,1]:
			viewer.select_mode(mode)
			await settle()
			var stage=viewer.stage
			for i in range(stage.drawn_rects.size()):
				var rect: Rect2=stage.drawn_rects[i]
				if rect.position.x<0 or rect.end.x>stage.size.x or rect.position.y<0 or rect.end.y>stage.size.y:
					failures.append("clipping "+str(extent)+"/"+str(mode)+"/"+str(i))
				var point: Vector2=stage.feet_points[i]
				if absf(point.y-stage.feet_points[0].y)>0.1:failures.append("feet alignment")
			var label: String=("catalogue" if mode==0 else "battle")+"_"+str(extent.x)+"x"+str(extent.y)
			root.get_texture().get_image().save_png(output.path_join(label+".png"))
			var rect_data: Array=[]
			for rect in stage.drawn_rects:rect_data.append([rect.position.x,rect.position.y,rect.size.x,rect.size.y])
			captures.append({"name":label,"logical_stage":[stage.size.x,stage.size.y],"rects":rect_data})
	var contact := SubViewport.new()
	contact.size=Vector2i(1600,560)
	contact.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(contact)
	var preview_code=load("res://redesign/foundry_concept_preview.gd")
	var board=preview_code.Stage.new()
	board.items=viewer.stage.items
	board.size=Vector2(1600,560)
	contact.add_child(board)
	var heading:=Label.new()
	heading.text="축열 주조장 · 일반 몬스터 4종 시안"
	heading.position=Vector2(26,20)
	heading.add_theme_font_override("font",preview_code.FONT)
	heading.add_theme_font_size_override("font_size",28)
	contact.add_child(heading)
	await settle()
	contact.get_texture().get_image().save_png(output.path_join("concept_board.png"))
	contact.queue_free();await process_frame
	viewer.queue_free();await process_frame
	# Verify entry through the real developer menu, without user saves.
	var screen=load("res://redesign/main.tscn").instantiate()
	screen.save_enabled=false
	root.add_child(screen)
	await settle()
	screen._developer()
	await settle()
	var button=screen.find_child("debug_foundry_concepts",true,false)
	if button==null:failures.append("missing developer entry")
	else:
		button.pressed.emit();await settle()
		var panel=screen.find_child("FoundryConceptPreview",true,false)
		if panel==null:failures.append("developer entry did not open")
		else:
			if panel.standalone:failures.append("overlay incorrectly standalone")
			panel.close();await settle()
			if screen.find_child("FoundryConceptPreview",true,false)!=null:failures.append("overlay did not close")
	var report=FileAccess.open(output.path_join("visual_qa.json"),FileAccess.WRITE)
	report.store_string(JSON.stringify({"failures":failures,"captures":captures,"note":"Concept display only; no combat or balance validation."},"  "));report.close()
	print("FOUNDRY CONCEPTS COMPLETE failures=",failures.size())
	screen.queue_free();await process_frame
	quit(0 if failures.is_empty() else 1)
