extends Button
## Compact graphical fallback for touch players who do not discover drag-to-compress.

const AmmoVisual = preload("res://redesign/ammo_visual.gd")
const Content = preload("res://redesign/content.gd")
const FONT = preload("res://redesign/ui_font.tres")

var ammo_id := "basic"

func _ready() -> void:
	text = ""
	custom_minimum_size = Vector2(174, 44)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	queue_redraw()

func setup(id: String) -> void:
	ammo_id = id
	queue_redraw()

func _draw() -> void:
	if not Content.AMMO.has(ammo_id): return
	var alpha := 0.42 if disabled else 1.0
	var color: Color = AmmoVisual.COLORS[ammo_id]
	color.a *= alpha
	AmmoVisual.round_icon(self, Vector2(22, 23), ammo_id, 0.20)
	AmmoVisual.round_icon(self, Vector2(42, 23), ammo_id, 0.20)
	draw_string(FONT, Vector2(57, 29), "→", HORIZONTAL_ALIGNMENT_CENTER, 19, 18, Color("94a9ae", alpha))
	var center := Vector2(87, 23)
	var diamond := PackedVector2Array([
		center + Vector2(0, -9), center + Vector2(9, 0),
		center + Vector2(0, 9), center + Vector2(-9, 0), center + Vector2(0, -9),
	])
	draw_colored_polygon(PackedVector2Array(diamond.slice(0, 4)), Color(0.39, 0.86, 0.91, 0.18 * alpha))
	draw_polyline(diamond, Color("63dce8", alpha), 2.0, false)
	draw_string(FONT, Vector2(104, 29), str(Content.AMMO[ammo_id].name), HORIZONTAL_ALIGNMENT_LEFT, size.x - 111, 16, color)
