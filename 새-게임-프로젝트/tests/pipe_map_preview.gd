extends SceneTree
func _initialize()->void: run.call_deferred()
func run()->void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/maps/pipe_"):quit(2);return
	root.size=Vector2i(1280,800);root.content_scale_size=root.size
	var scene=load("res://redesign/pipe_map/screen.tscn").instantiate()
	var checks:=0
	for name in ["Header","MapWorkspace","RegionRail","MapBoard","MapScroll","CityMap","MapRouteSheet","Enter","MapKey","city_map_details"]:
		if scene.find_child(name,true,false)==null:push_error("Missing authored map composition "+name);quit(1);return
		checks+=1
	# These properties are serialized and present before entering the tree / _ready.
	if scene.find_child("MapSelectionPrompt",true,false).text!="순찰 구역":quit(1);return
	checks+=1
	root.add_child(scene)
	for i in range(6):await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join("authored_scene.png"))
	print("PIPE MAP COMPLETE checks=%d failures=0"%checks)
	quit()
