extends Control
## A readable supply diagram over the approved residential scene, not new world art.
const Art = preload("res://redesign/world_art.gd")
const BACKGROUND = preload("res://assets/art/tower_sample_20261003/residential_tower.png")
var supplied := false
var released := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	resized.connect(queue_redraw)

func _draw() -> void:
	Art.cover(self, BACKGROUND, Rect2(Vector2.ZERO, size))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.045, 0.06, 0.45))
	var warm := Color("e4bd72")
	var cold := Color("607787")
	var feed := warm if supplied else cold
	var y := roundf(size.y * 0.64)
	var valve := Vector2(roundf(size.x * 0.5), y)
	# Source tower, hand valve, and inhabited windows share one visible pipe.
	draw_rect(Rect2(48, 28, 64, y - 10), Color("162a34"))
	for floor_index in range(4):
		draw_rect(Rect2(58, 40 + floor_index * 24, 44, 6), warm)
	draw_line(Vector2(80, y), Vector2(size.x - 92, y), Color("142630"), 18)
	draw_line(Vector2(80, y), valve, warm, 6)
	draw_line(valve, Vector2(size.x - 92, y), feed, 6)
	draw_rect(Rect2(valve - Vector2(27, 27), Vector2(54, 54)), Color("12232c"))
	draw_rect(Rect2(valve - Vector2(22, 22), Vector2(44, 44)), feed, false, 4)
	var arm := Vector2(31, 0) if supplied else Vector2(0, 31)
	draw_line(valve - arm, valve + arm, feed, 6)
	for house in range(3):
		var x := size.x - 200 + house * 52
		draw_rect(Rect2(x, y - 74, 44, 62), Color("182a33"))
		for window in range(2):
			draw_rect(Rect2(x + 8 + window * 18, y - 61, 10, 14), feed)
		draw_line(Vector2(x + 22, y - 12), Vector2(x + 22, y), feed, 4)
	# A red central command closes the valve; restored control clears this path.
	if not released:
		var command := Color("f2a38d") if not supplied else cold
		for step in range(12):
			var x := lerpf(112, valve.x, float(step) / 12.0)
			draw_rect(Rect2(x, 48, 12, 3), command)
		draw_line(Vector2(valve.x, 48), valve - Vector2(0, 34), command, 3)
