extends SceneTree
## Focused rendered bounds probe; the fixtures use the existing developer entry.
var screen: Control
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func settle() -> void:
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/weapons/ui/"):
		quit(1)
		return
	screen = load("res://redesign/main.tscn").instantiate()
	root.add_child(screen)
	await settle()
	screen.save_enabled = false
	screen.debug_session = true
	screen._debug_weapon("scatter")
	screen.model.s.capacity_bonus = 2
	screen.model.s.supply = 8
	screen.model.s.part = "supply"
	for i in range(5): screen.model.load_round("basic")
	for resolution in [Vector2i(1280, 800), Vector2i(1008, 630), Vector2i(1440, 630)]:
		root.size = resolution
		screen.redraw()
		await settle()
		var scroll: VScrollBar = screen.main_scroll.get_v_scroll_bar()
		print(JSON.stringify({"resolution": str(resolution), "screen": str(screen.size), "scroll_visible": scroll.visible, "scroll_max": scroll.max_value, "scroll_page": scroll.page, "body": str(screen.body.get_global_rect()), "margin": str(screen.content_margin.get_global_rect()), "minimum": str(screen.content_margin.get_combined_minimum_size())}))
		for key in ["BattleView", "QueuePanel", "AmmoGrid", "confirm", "ReserveAmmo"]:
			var control := screen.find_child(key, true, false) as Control
			if control == null or not Rect2(Vector2.ZERO, screen.size).encloses(control.get_global_rect()):
				failures += 1
				print("FAIL: bounds " + key)
		if scroll.visible:
			failures += 1
			print("FAIL: unnecessary combat scrolling")
		root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join("layout_%dx%d.png" % [resolution.x, resolution.y]))
	root.size = Vector2i(1008, 630)
	screen._developer()
	await settle()
	(screen.find_child("debug_field_compression", true, false) as Button).pressed.emit()
	await settle()
	if screen.main_scroll.get_v_scroll_bar().visible:
		failures += 1
		print("FAIL: full hand and compression controls need scrolling")
	for key in ["load_basic", "load_charge", "load_charge_2", "load_precise", "load_precise_2", "load_arc", "field_compressor_status"]:
		var control := screen.find_child(key, true, false) as Control
		if control == null or not Rect2(Vector2.ZERO, screen.size).encloses(control.get_global_rect()):
			failures += 1
			print("FAIL: full hand bounds " + key)
	root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join("layout_compression_phone.png"))
	screen.page = "menu"
	screen.redraw()
	root.size = Vector2i(1280, 800)
	await settle()
	root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join("director_title.png"))
	print("DIRECTOR LAYOUT COMPLETE failures=%d" % failures)
	quit(0 if failures == 0 else 1)
