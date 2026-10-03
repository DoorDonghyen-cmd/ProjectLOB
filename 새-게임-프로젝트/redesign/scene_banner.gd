extends Control
const Art = preload("res://redesign/world_art.gd")
var art_id := ""
var region := 0
var show_reclaimer := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _draw() -> void:
	Art.cover(self, Art.region_texture(region) if art_id.is_empty() else Art.texture(art_id), Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.045, 0.06, 0.28))
	for i in range(20):
		draw_rect(Rect2(size.x * i / 20, 0, size.x / 20 + 1, size.y), Color(0.035, 0.055, 0.065, 0.78 * (1.0 - float(i) / 20)))

	if show_reclaimer:
		Art.contain(self, Art.texture("reclaimer"), Rect2(size.x * 0.75, 4, size.x * 0.23, size.y - 8))
