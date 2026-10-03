extends Control
## A word-light gate preview: two ordinary silhouettes converge into one
## compressed core, while the miniature magazine shows its physical fit.
const Content = preload("res://redesign/content.gd")
const Ammo = preload("res://redesign/ammo_visual.gd")
const FONT = preload("res://redesign/ui_font.tres")
const INK := Color("e7e4d9")
const MUTED := Color("6f8790")
const ACCENT := Color("a9dfbf")
var source_id := "pierce"
var result_id := "pierce_c"
var state: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()

func setup(source: String, current_state: Dictionary) -> void:
	source_id = source
	result_id = Content.compressed_id(source)
	state = current_state
	queue_redraw()

func _draw() -> void:
	if state.is_empty() or not Content.AMMO.has(result_id): return
	var middle := size.x * 0.5
	Ammo.round_icon(self, Vector2(middle - 72, 34), source_id, 0.34)
	Ammo.round_icon(self, Vector2(middle - 45, 34), source_id, 0.34)
	draw_line(Vector2(middle - 25, 34), Vector2(middle - 8, 34), MUTED, 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(middle - 8, 29), Vector2(middle, 34), Vector2(middle - 8, 39)]), ACCENT)
	Ammo.round_icon(self, Vector2(middle + 39, 34), result_id, 0.52)
	draw_string(FONT, Vector2(8, 76), Content.AMMO[source_id].name, HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 18, Ammo.COLORS[result_id])
	_draw_damage(Vector2(24, 94), Color("e4bd72"))
	draw_string(FONT, Vector2(35, 100), str(Content.damage(result_id, state)), HORIZONTAL_ALIGNMENT_LEFT, 35, 17, Color("e4bd72"))
	_draw_penetration(Vector2(82, 94), Color("79b6f2"))
	draw_string(FONT, Vector2(94, 100), str(Content.penetration(result_id, state)), HORIZONTAL_ALIGNMENT_LEFT, 35, 17, Color("79b6f2"))
	_draw_fit(Vector2(size.x - 86, 85), result_id)

func _draw_fit(origin: Vector2, id: String) -> void:
	var cell := Vector2(18, 17)
	for i in range(4):
		var rect := Rect2(origin + Vector2(i * 19, 0), cell)
		draw_rect(rect, Color("172731"), true)
		draw_rect(rect, MUTED, false, 1.0)
	var rule := Content.anchor(id)
	var cost := Content.slot_cost(id)
	var start := 0 if rule != "last" else 4 - cost
	var joined := Rect2(origin + Vector2(start * 19, 0), Vector2(cell.x + (cost - 1) * 19, cell.y))
	draw_rect(joined, Color(0.66, 0.87, 0.75, 0.22), true)
	draw_rect(joined, ACCENT, false, 2.0)
	if rule == "first":
		draw_colored_polygon(PackedVector2Array([origin + Vector2(-6, 8), origin + Vector2(0, 3), origin + Vector2(0, 13)]), ACCENT)
	elif rule == "last":
		var end := origin + Vector2(4 * 19 - 1, 0)
		draw_line(end, end + Vector2(0, 17), ACCENT, 3.0)

func _draw_damage(center: Vector2, color: Color) -> void:
	draw_rect(Rect2(center - Vector2(2, 2), Vector2(5, 5)), color)
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(center + direction * 4, center + direction * 7, color, 2.0)

func _draw_penetration(center: Vector2, color: Color) -> void:
	draw_polyline(PackedVector2Array([center + Vector2(-6, -6), center + Vector2(6, -6), center + Vector2(5, 2), center + Vector2(0, 7), center + Vector2(-5, 2), center + Vector2(-6, -6)]), color, 2.0)
	draw_line(center + Vector2(-5, 0), center + Vector2(7, 0), color, 2.0)
