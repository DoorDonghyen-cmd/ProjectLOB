extends SceneTree
var screen
var output: String
var rows: Array = []
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for frame in range(14): await process_frame
func run() -> void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").ends_with("/qa_runtime/equipment_live_20261106"): quit(2); return
	screen=load("res://redesign/main.tscn").instantiate()
	screen.save_enabled=false
	root.add_child(screen)
	await settle()
	for extent in [Vector2i(1280,800),Vector2i(1170,540),Vector2i(2340,1080),Vector2i(2340,960),Vector2i(844,390)]:
		root.size=extent
		await settle()
		screen._open_preparation(false)
		await settle()
		var view: Control=screen.find_child("EquipmentScreen",true,false)
		var actor: Control=view.find_child("OutfitPortrait",true,false)
		var scroll: ScrollContainer=view.find_child("SelectionScroll",true,false)
		var rail: Control=view.find_child("WeaponSelection",true,false)
		rows.append({"extent":str(extent),"screen_size":str(view.size),"stage_min":view.find_child("Stage",true,false).custom_minimum_size.y,"body_scroll":scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page,"launch":str(view.launch.get_global_rect()),"rail":str(rail.get_global_rect()),"body_clip":str(scroll.get_global_rect()),"actor_rect":str(actor.display_rect())})
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("%dx%d.png"%[extent.x,extent.y]))
		if extent.x==1280:
			DirAccess.make_dir_recursive_absolute("res://assets/ui/equipment_20261106")
			actor.actor_viewport.get_texture().get_image().save_png("res://assets/ui/equipment_20261106/editor_loadout.png")
	FileAccess.open(output.path_join("geometry.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	screen.free()
	await settle()
	print("EQUIPMENT LIVE CAPTURE COMPLETE")
	quit()
