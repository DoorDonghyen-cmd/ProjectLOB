extends SceneTree
const Campaign=preload("res://redesign/campaign.gd")
var host
var output:String
var phase:String
var frames:Array=[]
func _initialize():run.call_deferred()
func settle():
	for frame in range(12):await process_frame
func run():
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").ends_with("/qa_runtime/map_ui_20261106"):quit(2);return
	phase=OS.get_environment("QA_MAP_PHASE")
	if phase not in ["before","after"]:quit(2);return
	var folder=output.path_join(phase)
	DirAccess.make_dir_recursive_absolute(folder)
	host=load("res://redesign/main.tscn").instantiate();host.save_enabled=false;root.add_child(host);await settle()
	var c=Campaign.new();c.start("single",731042,0,"balanced",4,"carrier",true);c.advance_departure(true)
	host.preferences.data.motion="instant";host.campaign=c;host.model=c.model;host.page="run";host.redraw();await settle()
	for extent in [Vector2i(1280,800),Vector2i(1170,540),Vector2i(2340,1080),Vector2i(844,390)]:
		root.size=extent;await settle()
		var map:Control=host.find_child("PipeMapScreen",true,false)
		if map==null:push_error("Actual map entry missing");quit(1);return
		var data:Dictionary={}
		for name in ["Header","MapWorkspace","MapLegend","RegionRail","MapBoard","MapScroll","SideColumn","MapRouteSheet","RunStatusBar","MapSelectionPrompt"]:
			var node:Control=map.find_child(name,true,false)
			data[name]=[node.get_global_rect().position.x,node.get_global_rect().position.y,node.size.x,node.size.y]
		data["Enter"]=[map.enter_button.global_position.x,map.enter_button.global_position.y,map.enter_button.size.x,map.enter_button.size.y]
		frames.append({"window":[extent.x,extent.y],"geometry":data})
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(folder.path_join("%dx%d.png"%[extent.x,extent.y]))
	FileAccess.open(folder.path_join("geometry.json"),FileAccess.WRITE).store_string(JSON.stringify(frames,"  "))
	host.free();await settle();print("MAP UI CAPTURE COMPLETE ",phase);quit()
