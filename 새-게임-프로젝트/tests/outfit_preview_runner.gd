extends SceneTree
const Actor = preload("res://redesign/weapon_actor.gd")
var failures := 0
var checks := 0
var preview: Control
var output := ""

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)

func settle() -> void:
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw

func capture(id: String) -> void:
	await settle()
	check(root.get_texture().get_image().save_png(output.path_join(id + ".png")) == OK, "capture " + id)

func touch(node: String) -> void:
	var button := preview.get_node("%" + node) as Button
	check(not button.disabled, "enabled " + node)
	var point := root.get_final_transform() * button.get_global_rect().get_center()
	for down in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = down
		event.window_id = root.get_window_id()
		Input.parse_input_event(event)
		await process_frame
	await settle()

func visible_controls_fit() -> void:
	var bounds := preview.get_global_rect()
	for item in preview.find_children("*","Button",true,false):
		if item.is_visible_in_tree():
			check(bounds.grow(1).encloses(item.get_global_rect()), "button inside viewport " + item.name)
			check(item.size.y >= 44, "touch height " + item.name)
	var stage: Control = preview.get_node("Margin/Layout/Stage")
	check(stage.size.y >= 210, "stage retained at short aspect")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/outfit_preview/"):
		quit(1)
		return
	output = OS.get_environment("QA_OUTPUT_DIR")
	Input.emulate_mouse_from_touch = true
	var original_outfits = preload("res://redesign/content.gd").OUTFITS
	check(original_outfits.size() == 7 and original_outfits.has("expedition"), "live outfits registered")
	var baseline: Node2D = load("res://redesign/weapon_actor.gd").new()
	for gun in Actor.WEAPONS:
		for pose in Actor.POSES[Actor.family(gun)]:
			baseline.configure(gun,pose,0.7,0.3,0.8)
			check(baseline.body_texture() == Actor.BODIES[Actor.family(gun)], "live body fallback intact")
			check(baseline.registered_transform() == Actor.weapon_transform(gun,pose,0.7), "live weapon registration intact")
			check(baseline.registered_hands() == Actor.foreground_hands(gun,pose), "live hand registration intact")
	baseline.free()
	preview = load("res://redesign/outfit_preview.tscn").instantiate()
	root.add_child(preview)
	await settle()
	for resolution in [Vector2i(1280,900),Vector2i(1008,630),Vector2i(1440,630)]:
		root.size = resolution
		await settle()
		for i in range(4):
			await touch(["Heatworker","Hoist","Recovery","Expedition"][i])
			check(preview.selected == i and preview.mode == 0, "touch switches concept")
			check(not preview.get_node("%BattleButton").disabled, "all four outfit motions available")
			visible_controls_fit()
			if resolution.x == 1280: await capture("concept_" + str(i))
		await touch("BattleButton")
		check(preview.mode == 1, "touch opens combat")
		visible_controls_fit()
		var stage: Control = preview.get_node("%Battle")
		var actor: Node2D = stage.actor
		var last: PackedByteArray
		for gun in Actor.WEAPONS:
			preview.choose_gun(gun)
			for pose in Actor.POSES[Actor.family(gun)]:
				stage.choose_pose(pose)
				await settle()
				var pixels: Image = stage.viewport.get_texture().get_image()
				check(pixels.detect_alpha() != Image.ALPHA_NONE, "combat background transparent")
				var used := pixels.get_used_rect()
				check(used.position.x > 0 and used.position.y > 0 and used.end.x < 768 and used.end.y <= 512, "combat cutout inside viewport")
				check(not pixels.is_invisible(), "registered body and gun render")
				check(actor.body_texture().resource_path.contains("expedition"), "expedition body selected")
				if resolution.x == 1280 and pose == "aim":
					await capture("aim_" + gun)
				last = pixels.get_data()
		stage.choose_pose("aim")
		await settle()
		var still: PackedByteArray = stage.viewport.get_texture().get_image().get_data()
		await touch("Fire")
		await create_timer(0.07).timeout
		await settle()
		check(stage.viewport.get_texture().get_image().get_data() != still, "fire visibly changes rendered pose")
		await create_timer(0.7).timeout
		check(stage.animation.is_empty() and stage.current_pose == "aim", "fire completes")
		await touch("Reload")
		await create_timer(0.5).timeout
		check(not stage.animation.is_empty() and actor.reload_amount > 0.4, "reload opens weapon")
		await capture("reload_" + str(resolution.x))
		await create_timer(1.3).timeout
		check(stage.animation.is_empty(), "reload completes")
		await touch("Zoom")
		check(stage.magnification == 2.0, "touch zooms")
		await capture("battle_zoom_" + str(resolution.x))
		await touch("Zoom")
		for room in ["ShopButton","SupplyButton","WorkshopButton"]:
			await touch(room)
			var layer: Control = preview.get_node("%RoomActor")
			check(layer.profile.texture.get_image().detect_alpha() != Image.ALPHA_NONE, "room actor transparent")
			check(layer.image_rect().encloses(layer.actor_rect()), "room actor fits panorama")
			check(layer.profile.texture.resource_path.contains("expedition"), "room displays expedition")
			visible_controls_fit()
			await capture(room + "_" + str(resolution.x))
	preview.queue_free()
	await settle()
	# Exercise the real menu entry and close without modifying model state.
	var screen: Control = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	await settle()
	var original_model := hash(screen.model.s)
	var original_selection: String = screen.selected_outfit_id
	screen._developer()
	await settle()
	var entry: Button = screen.find_child("debug_outfits",true,false)
	check(entry != null, "developer menu entry exists")
	entry.pressed.emit()
	await settle()
	preview = screen.find_child("OutfitPreview",true,false)
	check(preview != null, "menu opens authored preview")
	preview.select_outfit(0)
	preview.select_outfit(3)
	preview.select_mode(4)
	preview.close()
	await settle()
	check(screen.find_child("OutfitPreview",true,false) == null, "close removes overlay")
	check(hash(screen.model.s) == original_model and screen.selected_outfit_id == original_selection, "preview preserves combat state and starting outfit")
	screen.queue_free()
	await settle()
	print("OUTFIT PREVIEW COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
