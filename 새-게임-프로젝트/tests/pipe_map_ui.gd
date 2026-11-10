extends "res://tests/campaign_magazine_rules.gd"
## Replay previously earned legal commands. UI clones never alter the replay or user saves.
var host
var seen_regions: Dictionary={}
var shortcut_checked:=false
var visual_checks: Array=[]
var captured_gates: Dictionary={}

func canonical(value): return JSON.parse_string(JSON.stringify(value))

func settle_ui()->void:
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw

func tap_ui(id: String)->void:
	var button: Button=host.find_child(id,true,false)
	if not check(button!=null and button.is_visible_in_tree() and not button.disabled,"usable public input "+id): return
	var ancestor: Node=button.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
		ancestor=ancestor.get_parent()
	await settle_ui()
	var point: Vector2=button.get_global_transform_with_canvas()*(button.size*0.5)
	for down in [true,false]:
		var event:=InputEventScreenTouch.new();event.index=0;event.position=point;event.pressed=down
		root.push_input(event,true);await process_frame
	await settle_ui()

func clone_map(c):
	var copy=Campaign.new()
	check(copy.restore_state(JSON.parse_string(JSON.stringify({"campaign":c.s,"combat":c.model.s,"profile":c.profile}))),"earned map snapshot restores")
	return copy

func mount_map(c, dimensions: Vector2i)->void:
	if is_instance_valid(host):host.free()
	root.size=dimensions;root.content_scale_size=dimensions
	host=load("res://redesign/main.tscn").instantiate();host.save_enabled=false
	root.add_child(host)
	host.preferences.data.motion="instant"
	host.campaign=c;host.model=c.model;host.page="run";host.redraw()
	await settle_ui()

func geometry(label: String)->void:
	var view=host.find_child("PipeMapScreen",true,false)
	var graph=host.find_child("CityMap",true,false)
	var scroll: Control=host.find_child("MapScroll",true,false)
	var sheet: Control=host.find_child("MapRouteSheet",true,false)
	check(host.get_global_rect().encloses(sheet.get_global_rect()),"fixed actions inside viewport "+label)
	check(not sheet.get_global_rect().intersects(scroll.get_global_rect()),"map and actions do not overlap "+label)
	var bounds: Rect2=Rect2(Vector2.ZERO,graph.size)
	var places: Array=graph.get_children()
	for i in range(places.size()):
		check(places[i].size.x>=44 and places[i].size.y>=44,"touch size "+label)
		check(bounds.encloses(places[i].get_rect()),"place within graph "+label)
		for j in range(i+1,places.size()):check(not places[i].get_rect().intersects(places[j].get_rect()),"distinct touch rectangles "+label)
	var pairs: Array=[]
	for path in graph.paths:
		if path.from!=0:pairs.append([int(path.from),int(path.to)])
		var points: PackedVector2Array=path.points
		var length:=0.0
		for i in range(points.size()-1):
			length+=points[i].distance_to(points[i+1])
			check(points[i+1].y<=points[i].y,"path never reverses vertically "+label)
		check(length>0,"visible nonzero path "+label)
		if path.shortcut:
			# Its long vertical leg must not pass through any skipped place's touch target.
			for place in places:
				var id:=int(str(place.name).trim_prefix("map_node_"))
				if id in [int(path.from),int(path.to)]:continue
				var r: Rect2=place.get_rect()
				check(not (points[2].x>r.position.x and points[2].x<r.end.x and points[2].y>r.position.y and points[3].y<r.end.y),"shortcut clears intermediate targets "+label)
	for item in graph.nodes:
		for next_id in item.next:check(pairs.has([int(item.id),int(next_id)]),"drawing follows authoritative next "+label)
	var gate: Button=view.node("map_node_"+str(graph.gate_id))
	check(gate.size.y>=44 and host.get_global_rect().encloses(gate.get_global_rect()),"gate fixed and touchable "+label)
	var image:=root.get_texture().get_image()
	check(image.save_png(output.path_join(label+".png"))==OK,"capture "+label)
	visual_checks.append({"label":label,"size":[root.size.x,root.size.y],"region":graph.region_index,"nodes":places.size(),"paths":pairs.size(),"selection":graph.selection})

func review_earned_map(c)->void:
	var region:=int(c.s.region)
	if seen_regions.has(region):return
	seen_regions[region]=true
	for dimensions in [Vector2i(1280,800),Vector2i(844,390),Vector2i(740,360)]:
		var copy=clone_map(c)
		await mount_map(copy,dimensions)
		var before:=JSON.stringify({"campaign":copy.s,"combat":copy.model.s})
		var choice: int=int(copy.choices()[-1].id)
		await tap_ui("map_node_"+str(choice))
		var view=host.find_child("PipeMapScreen",true,false)
		check(view.selected_id==choice,"candidate selected in region "+str(region))
		await tap_ui("city_map_details");await tap_ui("workspace_close")
		check(view.selected_id==choice,"details return to same selection")
		var scroll: ScrollContainer=view.node("MapScroll")
		scroll.scroll_vertical=0;await settle_ui()
		await tap_ui("MapKey")
		if region==0 and dimensions.x==1280:root.get_texture().get_image().save_png(output.path_join("legend_1280x800.png"))
		await tap_ui("workspace_close")
		check(scroll.scroll_vertical==0,"legend retains manual scroll")
		await tap_ui("map_node_"+str(view.gate_id))
		check(not view.enter_button.visible,"future gate preview cannot move")
		await tap_ui("map_node_"+str(choice))
		check(JSON.stringify({"campaign":copy.s,"combat":copy.model.s})==before,"view/preview/legend preserve state and RNG")
		if region==0 and dimensions.x==1280:
			root.size=Vector2i(844,390);root.content_scale_size=root.size;await settle_ui()
			check(host.find_child("PipeMapScreen",true,false).selected_id==choice,"resize retains selected candidate")
			root.size=dimensions;root.content_scale_size=dimensions;await settle_ui()
			check(host.find_child("PipeMapScreen",true,false).selected_id==choice,"return to desktop retains selected candidate")
		geometry("region_%d_%dx%d"%[region+1,dimensions.x,dimensions.y])
		var visits: int=copy.s.visited.size()
		await tap_ui("city_enter_"+str(choice))
		check(int(copy.s.node)==choice and copy.s.visited.size()==visits+1,"one public move enters exactly once")
		check(copy.save()==OK,"save entered node")
		var loaded=Campaign.new();check(loaded.restore(),"restore entered node")
		var same: bool=canonical(loaded.s.visited)==canonical(copy.s.visited) and canonical(loaded.current_nodes())==canonical(copy.current_nodes())
		if not same:
			var mismatch:=FileAccess.open(output.path_join("restore_mismatch.json"),FileAccess.WRITE)
			mismatch.store_string(JSON.stringify({"before":{"visited":copy.s.visited,"nodes":copy.current_nodes()},"after":{"visited":loaded.s.visited,"nodes":loaded.current_nodes()}},"  "));mismatch.close()
		check(same,"restore preserves route and visits")

func review_shortcut(c)->void:
	if shortcut_checked:return
	for choice in c.choices():
		if not c.is_shortcut(int(choice.id)):continue
		var copy=clone_map(c)
		await mount_map(copy,Vector2i(844,390))
		await tap_ui("map_node_"+str(choice.id))
		var view=host.find_child("PipeMapScreen",true,false)
		check(view.enter_button.text=="전투 건너뛰기" and view.node("MapRouteDetail").text.contains("코어"),"shortcut cost is visible before confirmation")
		geometry("earned_shortcut")
		var prior: Dictionary=copy.s.duplicate(true)
		await tap_ui("city_enter_"+str(choice.id))
		check(int(copy.s.floor)==int(prior.floor)+2,"shortcut skips one depth")
		check(copy.s.visited.size()==prior.visited.size()+1 and int(copy.s.clears)==int(prior.clears),"skipped fight grants no visit or clear")
		check(copy.save()==OK,"shortcut save")
		var loaded=Campaign.new();check(loaded.restore() and canonical(loaded.s.visited)==canonical(copy.s.visited),"shortcut restores")
		shortcut_checked=true;break

func review_gate_art(c)->void:
	# Capture the real, earned gate-ready state; do not force progression to paint an open gate.
	var region:=int(c.s.region)
	if region not in [0,4] or captured_gates.has(region):return
	for choice in c.choices():
		if choice.kind!="boss":continue
		var copy=clone_map(c)
		await mount_map(copy,Vector2i(740,360))
		await tap_ui("map_node_"+str(choice.id))
		var view=host.find_child("PipeMapScreen",true,false)
		check(view.enter_button.visible,"earned gate is enterable")
		geometry("gate_ready_region_"+str(region+1))
		await tap_ui("city_map_details");await tap_ui("workspace_close")
		await tap_ui("city_enter_"+str(choice.id))
		check(int(copy.s.node)==int(choice.id),"gate decoration preserves public input")
		captured_gates[region]=true;break

func _run()->void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/maps/pipe_"):quit(2);return
	output=OS.get_environment("QA_OUTPUT_DIR");Input.emulate_mouse_from_touch=true
	var report: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_ROUTE_REPORT")))
	var route: Array=[]
	for endpoint in report.endpoints:
		if endpoint.gun=="single" and endpoint.won:route=endpoint.commands;break
	if not check(not route.is_empty(),"earned complete command route available"):quit(1);return
	var c=Campaign.new();c.start("single",731042,0,"balanced",3,"carrier",true);c.advance_departure(true)
	for step in route:
		if c.s.phase=="map":
			await review_earned_map(c)
			await review_shortcut(c)
			await review_gate_art(c)
		if not command(c,step.duplicate(true)):break
	check(c.s.phase=="won" and seen_regions.size()==5,"legal full replay crosses all five gates")
	check(shortcut_checked,"earned shortcut branch exercised")
	check(captured_gates.size()==2,"first and final earned gate states exercised")
	for version in [1,2]:
		var legacy=Campaign.new();legacy.start("single",17,0,"balanced",version);legacy.advance_departure(true)
		check(legacy.save()==OK,"legacy save v"+str(version))
		var restored=Campaign.new();check(restored.restore(),"legacy restore v"+str(version))
		check(canonical(restored.current_nodes())==canonical(legacy.current_nodes()),"legacy exact graph retained")
		await mount_map(restored,Vector2i(844,390))
		geometry("legacy_v"+str(version))
		var id: int=int(restored.choices()[-1].id)
		await tap_ui("map_node_"+str(id));await tap_ui("city_enter_"+str(id))
		check(int(restored.s.node)==id,"legacy legal move")
	var file:=FileAccess.open(output.path_join("result.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"regions":seen_regions.keys(),"shortcut":shortcut_checked,"screens":visual_checks},"  "));file.close()
	print("PIPE MAP COMPLETE checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
