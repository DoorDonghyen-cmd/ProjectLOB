extends Button
## Common, independently placed facilities. The atlas contains no navigation or text.
const ATLAS = preload("res://assets/art/map_residential_20261009/facilities_v2.png")
const REGIONS := {
	"combat": Rect2(44, 164, 374, 277), "elite": Rect2(448, 73, 453, 369),
	"workshop": Rect2(924, 151, 368, 291), "boss": Rect2(1318, 68, 421, 374),
	"shop": Rect2(44, 512, 390, 325), "supply": Rect2(481, 605, 394, 232),
	"event": Rect2(924, 472, 363, 365), "bypass": Rect2(1333, 562, 401, 276)
}
var can_enter := false
var is_current := false
var was_visited := false
var chart_mode := false
var on_route := true
var feedback_scale := 1.0
var selection_feedback: Tween

func _ready() -> void:
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

static func role_texture(role: String) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = ATLAS
	atlas.region = REGIONS[role]
	atlas.filter_clip = true
	return atlas

func configure(role: String, caption: String, available: bool, current: bool, visited: bool) -> void:
	can_enter = available
	is_current = current
	was_visited = visited
	$Picture.texture = role_texture(role)
	$Risk.visible = caption.ends_with(" +")
	$Status.text = "●" if current else ("✓" if visited else "")
	refresh(false)

func refresh(selected: bool) -> void:
	var newly_selected := selected and not button_pressed
	if selection_feedback != null and selection_feedback.is_valid(): selection_feedback.kill()
	set_pressed_no_signal(selected)
	$Picture.modulate = Color.WHITE if selected or can_enter or is_current else Color(0.73, 0.79, 0.82, 1.0)
	if chart_mode:
		$Picture.modulate = Color("edc47a") if selected else (Color.WHITE if can_enter or is_current else (Color("a8b7b3") if on_route else Color("465c64")))
		$Risk.modulate.a = 1.0 if selected or can_enter else 0.65
	$Status.add_theme_color_override("font_color", Color("edc47a") if is_current else Color("a4b6b7"))
	if newly_selected and chart_mode and is_inside_tree() and feedback_scale > 0.0:
		var resting: Color = $Picture.modulate
		$Picture.modulate = Color("fff1c9")
		selection_feedback = create_tween()
		selection_feedback.tween_property($Picture, "modulate", resting, 0.14 * feedback_scale).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	queue_redraw()

func _draw() -> void:
	if not button_pressed and not has_focus(): return
	# The full transparent button remains touchable. Only the picture gets
	# short corner marks; facility names live in the shared map legend.
	var color := Color("edc47a") if button_pressed else Color("a4b6b7")
	var left := floorf((size.x - 82.0) * 0.5)
	for point in [Vector2(left, 12), Vector2(left + 82, 12), Vector2(left, 64), Vector2(left + 82, 64)]:
		var horizontal := 6.0 if point.x == left else -6.0
		var vertical := 6.0 if point.y == 12 else -6.0
		draw_line(point, point + Vector2(horizontal, 0), color, 2, false)
		draw_line(point, point + Vector2(0, vertical), color, 2, false)
