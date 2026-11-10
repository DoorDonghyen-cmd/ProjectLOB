@tool
extends Button
## Decorative coupling handles inside the existing gate target; no input or layout changes.
const Art = preload("res://redesign/pipe_map/art.gd")
const MapMaterial = preload("res://redesign/pipe_map/material.gd")
var available := false

func set_available(value: bool) -> void:
	available = value
	$Face/Icon.texture = Art.texture("gate_ready" if available else "gate_closed")
	queue_redraw()

func _draw() -> void:
	var ink := MapMaterial.FUTURE if not available else MapMaterial.OPEN
	var mark := Art.texture("valve_open" if available else "valve_closed")
	var y := floorf((size.y - 28) * 0.25) * 2
	for x in [16.0, size.x - 44.0]:
		draw_texture_rect(mark, Rect2(x, y, 28, 28), false, ink)
	# Short pipe couplings stop well before the centered icon/title.
	var mid_y := floorf(size.y * 0.25) * 2
	draw_line(Vector2(46, mid_y), Vector2(62, mid_y), ink, 2, false)
	draw_line(Vector2(size.x-62, mid_y), Vector2(size.x-46, mid_y), ink, 2, false)
