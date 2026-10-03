extends SceneTree
var screen: Control
var failures := 0
var checks := 0

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
	check(root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join(id + ".png")) == OK, "capture " + id)

func tap(key: String) -> void:
	var button := screen.find_child(key, true, false) as Button
	check(button != null and not button.disabled, "input " + key)
	if button == null or button.disabled: return
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = button.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	while screen.busy: await process_frame
	await settle()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/art_sample/"):
		quit(1)
		return
	screen = load("res://redesign/samples/tower_battle.tscn").instantiate()
	root.add_child(screen)
	await settle()
	check(not screen.save_enabled and screen.debug_session, "isolated sample state")
	check(screen.model.s.plan == ["charge", "precise", "pierce"], "real initial firing order")
	for resolution in [Vector2i(1280, 900), Vector2i(1280, 800), Vector2i(1008, 630), Vector2i(1440, 630)]:
		root.size = resolution
		screen.redraw()
		await settle()
		check(not screen.main_scroll.get_v_scroll_bar().visible, "no vertical overflow " + str(resolution))
		for key in ["BattleView", "AmmoGrid", "QueuePanel", "confirm"]:
			var node := screen.find_child(key, true, false) as Control
			check(node != null and Rect2(Vector2.ZERO, screen.size).encloses(node.get_global_rect()), "screen bounds " + key)
		check(screen.find_child("AmmoGrid", true, false).get_child_count() == 6, "six original ammo cards")
		for i in range(3):
			check(is_equal_approx(screen.battle_view.enemy_feet(i).y, screen.battle_view.player_feet().y), "shared platform " + str(i))
			for j in range(i): check(not screen.battle_view.enemy_plaque(i).intersects(screen.battle_view.enemy_plaque(j)), "separated enemy labels")
		var source: Rect2 = screen.battle_view.background_source_rect()
		check(source.position.y >= 0 and source.end.y <= 941, "background source remains in image")
		await capture("tower_battle_%dx%d" % [resolution.x, resolution.y])
	root.size = Vector2i(1280, 800)
	screen.redraw()
	await settle()
	await tap("enemy_info_1")
	check(screen.find_child("EnemyDetails", true, false) != null, "enemy touch details")
	for child in screen.get_children():
		if child is AcceptDialog:
			child.hide()
			child.queue_free()
	await settle()
	await tap("confirm")
	check(screen.model.s.phase == "ready", "actual magazine confirmed")
	await capture("tower_battle_ready")
	var turns_before := int(screen.model.s.turns)
	screen.presentation_speed = 0.1
	await tap("fire")
	check(int(screen.model.s.turns) == turns_before + 1, "real firing consumes a turn")
	check(not screen.last_presentation.is_empty(), "actual shot presentation")
	await capture("tower_battle_after_fire")
	screen.reset_sample()
	await settle()
	check(screen.model.s.plan == ["charge", "precise", "pierce"] and screen.model.s.turns == 0, "sample restarts")
	print("TOWER ART SAMPLE COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
