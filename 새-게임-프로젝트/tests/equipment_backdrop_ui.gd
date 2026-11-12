extends "res://tests/equipment_live_ui.gd"

const ORIGINAL_BACKDROP = preload("res://assets/art/equipment_20261011/workshop_v1.png")

func geometry(view: Control) -> Dictionary:
	var portrait = view.get_node("%OutfitPortrait")
	return {
		"backdrop": view.get_node("%Backdrop").get_global_rect(),
		"stage": view.get_node("%Stage").get_global_rect(),
		"body": portrait.display_rect(),
		"weapon_list": view.get_node("%WeaponScroll").get_global_rect(),
		"outfit_list": view.get_node("%OutfitScroll").get_global_rect(),
		"launch": view.launch.get_global_rect(),
		"gun": portrait.actor.gun_id,
		"outfit": portrait.actor.outfit_id,
		"scale": portrait.preview_scale,
	}

func save_pair(before: Image, after: Image, filename: String) -> void:
	var extent := before.get_size()
	check(extent == after.get_size(), "same capture resolution " + filename)
	var sheet := Image.create(extent.x * 2 + 12, extent.y, false, before.get_format())
	sheet.fill(Color("201f21"))
	var area := Rect2i(Vector2i.ZERO, extent)
	sheet.blit_rect(before, area, Vector2i.ZERO)
	sheet.blit_rect(after, area, Vector2i(extent.x + 12, 0))
	check(sheet.save_png(output.path_join(filename + ".png")) == OK, "saved comparison " + filename)

func compare_scene(candidate: Texture2D, extent: Vector2i, gun: String, outfit: String) -> void:
	root.size = extent
	await settle()
	screen._open_preparation(false)
	await settle()
	await touch("weapon_select_" + gun)
	await touch("outfit_select_" + outfit)
	var view := equipment()
	var body: ScrollContainer = view.get_node("%SelectionScroll")
	body.scroll_vertical = 0
	var backdrop: TextureRect = view.get_node("%Backdrop")
	var authored := backdrop.texture
	backdrop.texture = ORIGINAL_BACKDROP
	await settle()
	var before := geometry(view)
	check(before.gun == gun and before.outfit == outfit, "actual selected pair " + gun + "/" + outfit)
	var before_frame := root.get_texture().get_image()
	check(absf(ORIGINAL_BACKDROP.get_size().aspect() - candidate.get_size().aspect()) < 0.02, "same art aspect " + str(extent))
	backdrop.texture = candidate
	await settle()
	var after := geometry(view)
	var after_frame := root.get_texture().get_image()
	check(after == before, "same actor, layout and input regions after texture swap " + str(extent))
	check(before_frame.get_data() != after_frame.get_data(), "background difference visible " + str(extent))
	check(screen.ReadableUI.available(screen).encloses(view.launch.get_global_rect()), "start stays visible " + str(extent))
	var tag := "%dx%d" % [extent.x, extent.y]
	save_pair(before_frame, after_frame, "compare_" + tag)
	if extent == Vector2i(1280, 800):
		var stage_crop := Rect2i(440, 102, 432, 501)
		save_pair(before_frame.get_region(stage_crop), after_frame.get_region(stage_crop), "compare_detail")
	frames.append({"window": tag, "geometry": str(after), "source": str(ORIGINAL_BACKDROP.get_size()), "candidate": str(candidate.get_size())})
	backdrop.texture = authored

func run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/equipment_live_20261106/backdrop/"):
		quit(2)
		return
	var candidate := Image.load_from_file(OS.get_environment("QA_BACKDROP_CANDIDATE"))
	if candidate == null or candidate.is_empty():
		push_error("Workshop candidate could not be loaded")
		quit(2)
		return
	Input.emulate_mouse_from_touch = true
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	await settle()
	var texture := ImageTexture.create_from_image(candidate)
	await compare_scene(texture, Vector2i(1280, 800), "single", "carrier")
	await compare_scene(texture, Vector2i(1170, 540), "single", "carrier")
	await compare_scene(texture, Vector2i(1008, 454), "amplifier", "work")
	screen.free()
	FileAccess.open(output.path_join("review.json"), FileAccess.WRITE).store_string(JSON.stringify({"checks": checks, "failures": failures, "frames": frames}, "  "))
	print("EQUIPMENT BACKDROP UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
