extends "res://tests/pipe_map_ui.gd"

func geometry(label: String)->void:
	super.geometry(label)
	var legend: Control=host.find_child("MapLegend",true,false)
	check(legend!=null and legend.is_visible_in_tree(),"map legend visible without opening overlay")
	if legend==null:return
	check(host.get_global_rect().encloses(legend.get_global_rect()),"legend stays in viewport "+label)
	check(legend.get_child_count()==8,"all eight place symbols explained upfront")
	for item in legend.get_children():
		check(legend.get_global_rect().encloses(item.get_global_rect()),"legend wraps inside bounds")
		var text: Label=item.get_node("Text")
		check(text.get_theme_font_size("font_size")>=16,"legend font readable")
		check(text.get_theme_font("font").get_string_size(text.text,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x<=text.size.x,"legend label uncut")

func _run()->void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/playtest_20261102/"):quit(2);return
	output=OS.get_environment("QA_OUTPUT_DIR");Input.emulate_mouse_from_touch=true
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../qa_runtime/campaign_magazine_20261101/v3_single/rules/balance.json")))
	var route: Array=report.endpoints[0].commands
	var c=Campaign.new();c.start("single",731042,0,"balanced",3,"carrier",true);c.advance_departure(true)
	var trail_captured:=false
	for step in route:
		if c.s.phase=="map":
			await review_earned_map(c)
			await review_shortcut(c)
			await review_gate_art(c)
			if not trail_captured and int(c.s.clears)>=2:
				for dimensions in [Vector2i(1280,800),Vector2i(844,390),Vector2i(740,360)]:
					await mount_map(clone_map(c),dimensions)
					var graph=host.find_child("CityMap",true,false)
					check(graph.paths.any(func(path):return path.state=="trail"),"earned visited route shown")
					check(graph.get_node("map_node_"+str(c.s.node)).state=="current","current place matches actual position")
					for i in range(1,c.s.visited.size()):
						var from: int=int(c.s.visited[i-1]);var to: int=int(c.s.visited[i])
						check(graph.paths.any(func(path):return path.from==from and path.to==to and path.state=="trail"),"each earned edge is highlighted, including restored saves")
					for id in graph.visited:
						if id==int(c.s.node):continue
						check(graph.place_state(id)=="visited","restored visited places retain their status")
					geometry("visited_%dx%d"%[dimensions.x,dimensions.y])
				trail_captured=true
		if not command(c,step.duplicate(true)):break
	check(c.s.phase=="won" and seen_regions.size()==5,"current earned replay crosses five regions")
	check(trail_captured and shortcut_checked,"visited route and actual shortcut tested")
	for version in [1,2]:
		var legacy=Campaign.new();legacy.start("single",17,0,"balanced",version);legacy.advance_departure(true)
		await mount_map(legacy,Vector2i(844,390));geometry("legacy_v"+str(version))
		var id: int=int(legacy.choices()[-1].id)
		await tap_ui("map_node_"+str(id));await tap_ui("city_enter_"+str(id))
		check(int(legacy.s.node)==id,"legacy map remains usable")
	if is_instance_valid(host):host.free()
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"screens":visual_checks,"regions":seen_regions.keys()},"  "))
	print("PRESENTATION COMPLETE checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
