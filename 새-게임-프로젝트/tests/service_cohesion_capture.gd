extends SceneTree
## Art review only: render the production room layer, without campaign/save access.
const Catalog = preload("res://redesign/service_actor_catalog.gd")
const OUTFITS := ["work", "carrier", "scout", "heatworker", "hoist", "recovery", "expedition"]
const LABELS := ["WORK", "CARRIER", "SCOUT", "HEATWORKER", "HOIST", "RECOVERY", "EXPEDITION"]
const PLACES := ["shop", "supply", "workshop"]
var canvas: Control

func _initialize() -> void:
	run.call_deferred()

func room_cell(outfit: String, place: String, position: Vector2, old: bool = false) -> void:
	var source: Control = load("res://redesign/location_%s.tscn" % place).instantiate()
	var room: TextureRect = source.get_node("PlaceArt")
	source.remove_child(room)
	source.free()
	room.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	room.position = position
	room.size = Vector2(500, 167)
	var actor: Control = room.get_node("PlaceActor")
	var compare_backgrounds := OS.get_environment("QA_COMPARE_BACKGROUNDS") == "1"
	if compare_backgrounds and old:
		room.texture = load("res://assets/art/service_layers_20261011/%s_background.png" % place)
	actor.profile = load("res://redesign/service_actor_%s_%s_unified.tres" % [place, outfit]) if old and not compare_backgrounds else Catalog.resolve(outfit, place).profile
	canvas.add_child(room)

func caption(text: String, position: Vector2) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", 16)
	label.modulate = Color("c5bea3")
	canvas.add_child(label)

func save_image(path: String) -> void:
	for frame in range(5): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path) == OK)

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/service_cohesion/"):
		quit(2); return
	var output := OS.get_environment("QA_OUTPUT_DIR")
	root.size = Vector2i(1536, 1484)
	root.content_scale_size = root.size
	canvas = Control.new()
	root.add_child(canvas)
	for row in OUTFITS.size():
		for column in PLACES.size():
			var origin := Vector2(12 + column * 508, 8 + row * 210)
			caption(LABELS[row] + " / " + PLACES[column].to_upper(), origin)
			room_cell(OUTFITS[row], PLACES[column], origin + Vector2(0, 28))
	await save_image(output.path_join("all_outfits_rooms.png"))
	for child in canvas.get_children(): child.queue_free()
	await process_frame
	root.size = Vector2i(1536, 440)
	root.content_scale_size = root.size
	for row in 2:
		for column in PLACES.size():
			var origin := Vector2(12 + column * 508, 8 + row * 210)
			caption(("BEFORE" if row == 0 else "AFTER") + " / " + PLACES[column].to_upper(), origin)
			room_cell("carrier", PLACES[column], origin + Vector2(0, 28), row == 0)
	var comparison := "background_before_after.png" if OS.get_environment("QA_COMPARE_BACKGROUNDS") == "1" else "carrier_before_after.png"
	await save_image(output.path_join(comparison))
	print("SERVICE COHESION CAPTURE COMPLETE")
	quit()
