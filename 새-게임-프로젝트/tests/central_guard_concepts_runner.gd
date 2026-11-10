extends SceneTree
## Actual GPU capture and public input checks in an isolated user directory.
var screen
var checks := 0
var failures := 0
var output := ""
var snapshots: Array = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)
func settle() -> void:
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
func viewer(): return screen.get_node_or_null("CentralGuardConceptPreview")
func tap(control: Control) -> void:
	check(control != null and control.is_visible_in_tree(),"touch target visible")
	if control == null: return
	var parent := control.get_parent()
	while parent != null:
		if parent is ScrollContainer: parent.ensure_control_visible(control)
		parent = parent.get_parent()
	await settle()
	var point := control.get_global_rect().get_center()
	for pressed in [true,false]:
		var event := InputEventScreenTouch.new()
		event.position = point
		event.index = 0
		event.pressed = pressed
		root.push_input(event,true)
		await process_frame
	await settle()
func capture(label: String) -> void:
	await settle()
	check(root.get_texture().get_image().save_png(output.path_join(label+".png")) == OK,"capture "+label)
	snapshots.append(label+".png")
func layout() -> void:
	var view = viewer()
	var area := Rect2(Vector2.ZERO,root.get_visible_rect().size)
	check(area.grow(1).encloses(view.get_global_rect()),"viewer within viewport")
	for key in ["GuardCatalogue","GuardBattle","GuardBackground0","GuardBackground1","GuardBackground2","CloseCentralGuards","GuardVariantA","GuardVariantB","GuardCompare"]:
		var button: Button = view.find_child(key,true,false)
		check(area.encloses(button.get_global_rect()),"button within viewport "+key)
		check(button.size.y >= 48,"touch height "+key)
	var stage = view.stage
	check(stage.drawn_rects.size() == (8 if stage.comparison else 4),"all selected registered sprites drawn")
	for i in range(stage.actors.size()):
		var expected := "central_guard_alt_20261025" if stage.items[i].get("variant","A") == "B" else "central_guard_concepts_20261025"
		check(stage.actors[i].texture.resource_path.contains(expected),"correct variant texture "+str(i))
	for i in range(stage.drawn_rects.size()):
		var rect: Rect2 = stage.drawn_rects[i]
		check(Rect2(Vector2.ZERO,stage.size).encloses(rect),"whole sprite visible "+str(i))
		check(absf(rect.end.y-stage.feet_points[i].y) <= 1.1,"boot baseline "+str(i))
		for j in range(i):
			check(not rect.intersects(stage.drawn_rects[j]),"sprites separated %d %d"%[i,j])
		if not stage.catalogue:
			check(absf(rect.size.y-float(stage.items[i].height)) <= 1.1,"actual combat height "+str(i))
			check(rect.position.x > stage.player_feet().x+55,"guard does not cover hero")
	if not stage.catalogue:
		check(stage.background_profile.region == 4,"central background selected")
		check(stage.weapon_viewport.get_node("Actor").get_script().resource_path.ends_with("weapon_actor.gd"),"live hero renderer used")
	if stage.comparison:
		for i in range(4):
			check(absf(stage.drawn_rects[i].size.y-stage.drawn_rects[i+4].size.y) < 1.0,"A and B share display scale "+str(i))

func saved_state() -> Dictionary:
	var state := {}
	for path in ["user://city_campaign_v1.json","user://chain_run_v2.json","user://redesign_preferences_v1.json"]:
		state[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else null
	return state

func run() -> void:
	var user_path := ProjectSettings.globalize_path("user://").replace("\\","/")
	if not user_path.contains("/qa_runtime/central_guard_concepts/"):
		push_error("QA isolation required")
		quit(1)
		return
	output = OS.get_environment("QA_OUTPUT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	await settle()
	var before := saved_state()
	var model_before := JSON.stringify(screen.model.s)
	screen._developer()
	await settle()
	await tap(screen.find_child("debug_central_guard_concepts",true,false))
	check(viewer() != null,"development entry opens guard viewer")
	if viewer() == null: quit(1); return
	check(not viewer().standalone,"embedded viewer closes without quitting game")
	for resolution in [Vector2i(1280,800),Vector2i(1008,630),Vector2i(1440,630)]:
		root.size = resolution
		root.content_scale_size = resolution
		await settle()
		for variant_name in ["A","B"]:
			await tap(viewer().find_child("GuardVariant"+variant_name,true,false))
			check(viewer().stage.items.all(func(item): return item.get("variant","A") == variant_name),"variant touch switches all four sprites")
			await tap(viewer().find_child("GuardCatalogue",true,false))
			check(viewer().stage.catalogue,"catalogue touch selects enlargement")
			check(viewer().backgrounds.all(func(b): return b.disabled),"background tabs inactive in catalogue")
			layout()
			await capture("variant_%s_catalogue_%dx%d"%[variant_name,resolution.x,resolution.y])
			await tap(viewer().find_child("GuardBattle",true,false))
			check(not viewer().stage.catalogue,"battle touch selects actual scale")
			for stage_index in range(3):
				await tap(viewer().find_child("GuardBackground%d"%stage_index,true,false))
				check(int(viewer().stage.background_profile.stage) == stage_index,"background touch switches band")
				layout()
				await capture("variant_%s_battle_%d_%dx%d"%[variant_name,stage_index,resolution.x,resolution.y])
		await tap(viewer().find_child("GuardCompare",true,false))
		check(viewer().stage.comparison and viewer().stage.catalogue,"comparison shows two catalogue rows")
		check(viewer().modes[1].disabled,"comparison does not imply eight-enemy battle")
		layout()
		await capture("compare_%dx%d"%[resolution.x,resolution.y])
	await tap(viewer().find_child("CloseCentralGuards",true,false))
	check(viewer() == null and screen.page == "menu","close returns to main")
	check(saved_state() == before,"viewer preserves isolated save files")
	check(JSON.stringify(screen.model.s) == model_before and screen.campaign == null,"viewer does not change model or start campaign")
	screen._developer()
	await settle()
	await tap(screen.find_child("debug_central_guard_concepts",true,false))
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event,true)
	await settle()
	check(viewer() == null,"Escape closes art viewer")
	check(saved_state() == before,"reopen and Escape preserve saves")
	var report := {"checks":checks,"failures":failures,"captures":snapshots,"user_path":user_path,"human_preference":"not_verified","galaxy":"not_verified"}
	var file := FileAccess.open(output.path_join("visual_qa.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	file.close()
	print("CENTRAL GUARD CONCEPTS COMPLETE checks=%d failures=%d"%[checks,failures])
	screen.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
