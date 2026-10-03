extends Control
## Shared environment art. Text remains native, localizable UI.
const PLATFORM = preload("res://assets/art/director_20261002/transit_platform.png")
const Art = preload("res://redesign/world_art.gd")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	resized.connect(queue_redraw)

func _draw() -> void:
	var bounds := Rect2(Vector2.ZERO, size)
	draw_texture_rect(PLATFORM, bounds, false)
	draw_rect(bounds, Color(0.035, 0.055, 0.075, 0.24))
	for i in range(24):
		var opacity := 0.65 * (1.0 - float(i) / 24.0)
		draw_rect(Rect2(size.x * i / 24.0, 0, size.x / 24.0 + 1, size.y), Color(0.035, 0.055, 0.075, opacity))
	Art.contain(self, Art.texture("reclaimer"), Rect2(size.x * 0.63, 8, size.x * 0.36, size.y - 8))
	draw_line(Vector2(0, size.y - 2), Vector2(size.x, size.y - 2), Color("cba66b"), 2)
