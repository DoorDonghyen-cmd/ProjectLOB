extends Control
## Temporary vector silhouettes: readable weapon identities before final art.
const COLORS := {"single": Color("a9dfbf"), "burst": Color("f3ba75"), "scatter": Color("87c9df"), "heavy": Color("c4ace5")}
var gun_id := "single"

func _ready() -> void:
	custom_minimum_size = Vector2(70, 40)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var color: Color = COLORS[gun_id]
	draw_rect(Rect2(6, 11, 32, 12), color)
	draw_colored_polygon(PackedVector2Array([Vector2(9, 21), Vector2(23, 21), Vector2(18, 36), Vector2(6, 36)]), color)
	match gun_id:
		"single":
			draw_circle(Vector2(28, 17), 9, color)
			draw_circle(Vector2(28, 17), 4, Color("1b2a34"))
			draw_rect(Rect2(35, 12, 22, 6), color)
		"burst":
			draw_rect(Rect2(36, 12, 23, 6), color)
			draw_rect(Rect2(27, 23, 8, 13), color)
			for x in [46, 53, 60]: draw_line(Vector2(x, 24), Vector2(x + 4, 24), color, 2)
		"scatter":
			for y in [11, 20]: draw_rect(Rect2(33, y, 18, 5), color)
			for y in [5, 17, 29]: draw_line(Vector2(56, 17), Vector2(68, y), color, 2)
		"heavy":
			draw_rect(Rect2(29, 7, 28, 20), color)
			draw_rect(Rect2(40, 12, 24, 10), color)
			draw_line(Vector2(46, 17), Vector2(68, 17), Color("e7e4d9"), 2)
