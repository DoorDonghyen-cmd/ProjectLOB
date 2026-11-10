extends SceneTree
var failures: Array = []
var checks := 0
var out := ""
var preview: Control

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures.append(text); push_error(text)

func settle() -> void:
	for frame in range(12): await process_frame
	await RenderingServer.frame_post_draw

func capture(name: String) -> void:
	await settle()
	check(root.get_texture().get_image().save_png(out.path_join(name+".png")) == OK, "Capture " + name)

func tap(id: String) -> void:
	var target: Control = preview.node(id)
	var pos: Vector2 = target.get_global_transform_with_canvas() * (target.size * 0.5)
	var down := InputEventScreenTouch.new(); down.index=0; down.position=pos; down.pressed=true
	root.push_input(down, true); await process_frame
	var up := InputEventScreenTouch.new(); up.index=0; up.position=pos; up.pressed=false
	root.push_input(up, true); await settle()

func geometry() -> void:
	var bounds := preview.get_global_rect()
	for id in ["Fire", "Reload", "Bag", "Parts", "Reset", "Pressure", "Other"]:
		var button: Control = preview.node(id)
		check(bounds.encloses(button.get_global_rect()), "Button fits: " + id)
		var scale_factor: float = float(root.size.y) / 800.0
		check(button.size.x*scale_factor >= 44 and button.size.y*scale_factor >= 44, "44px touch target: " + id)
	for id in ["IntentTitle", "IntentHint", "HeatLabel", "MagazineTitle", "Prediction", "StatusNote"]:
		var label: Label = preview.node(id)
		var font := label.get_theme_font("font")
		var width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
		check(width <= label.size.x+1, "Text fits: " + id)
	check(not preview.node("Fire").get_global_rect().intersects(preview.node("Reload").get_global_rect()), "Primary actions separate")

func run() -> void:
	out = OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/combat_ui_stage1_20261031/"): quit(2); return
	Input.emulate_mouse_from_touch=true
	# Capture the production screen with the identical legal fixture for a fair
	# composition comparison. This mount is isolated and saving is disabled.
	var shipped=load("res://redesign/main.tscn").instantiate()
	shipped.save_enabled=false
	root.add_child(shipped); await settle()
	var campaign=load("res://redesign/campaign.gd").new()
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://redesign/samples/combat_ui_stage1_fixture.json"))
	check(campaign.restore(str(fixture.source)), "Same earned campaign for before capture")
	campaign.model.s=fixture.state.duplicate(true)
	shipped.campaign=campaign; shipped.model=campaign.model; shipped.page="run"; shipped.debug_session=true
	shipped.redraw(); await settle()
	for size in [Vector2i(1008,630),Vector2i(1280,576),Vector2i(1280,800)]:
		root.size=size;root.content_scale_size=Vector2i(1280,800)
		await capture("before_ready_%dx%d" % [size.x,size.y])
	shipped.queue_free();await process_frame
	for variant in ["a", "b"]:
		preview=load("res://redesign/samples/combat_ui_stage1_"+variant+".tscn").instantiate()
		root.add_child(preview); await settle()
		for size in [Vector2i(1008,630), Vector2i(1280,576), Vector2i(1280,800)]:
			root.size=size; root.content_scale_size=Vector2i(1280,800); await settle()
			preview.mount(false); await settle(); geometry()
			var suffix := "%dx%d" % [size.x,size.y]
			await capture(variant+"_ready_"+suffix)
			check(preview.node("Prediction").text.contains("2명"), "Real forecast two kills")
			check(preview.node("Value1").text=="14" and preview.node("Value2").text=="5", "Cards include boost, core and overflow damage")
			await tap("Bag"); check(preview.overlay_open,"Touch opens ammo detail")
			await tap("CloseDetail"); check(not preview.overlay_open,"Touch closes ammo detail")
			await tap("Fire"); check(preview.model.s.phase in ["won","reward"],"Merged confirm/fire executes actual model")
			check(preview.node("Fire").disabled,"No repeat firing after victory")
			await capture(variant+"_win_"+suffix)
			await tap("Pressure"); check(preview.pressure,"Touch selects pressure fixture")
			check(preview.node("Reload").text.contains("접촉"),"Lethal reload announced")
			geometry(); await capture(variant+"_pressure_"+suffix)
			await tap("Reload"); check(preview.model.s.phase=="lost","Announced lethal reload matches actual outcome")
			await tap("Reset"); check(preview.model.s.phase=="plan" and not preview.pressure,"Reset restores isolated fixture")
		preview.queue_free(); await process_frame
	check(not FileAccess.file_exists("user://campaign.json"),"No campaign save created")
	FileAccess.open(out.path_join("ui.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"note":"Standalone current-rule composition studies. Pressure is intentionally reached through empty reloads; not a new balance result."},"  "))
	print("STAGE1 UI COMPLETE checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
