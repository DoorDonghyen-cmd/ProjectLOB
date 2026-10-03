extends "res://redesign/part_card_view.gd"
## Shares equipment silhouettes. Lit ticks map to the next action's shot order.
var ready_slots: Array = []
var shot_count := 0
var activated := false

func _draw() -> void:
	var accent: Color = COLORS.get(part_id, INK)
	_draw_part_icon(Vector2(size.x * 0.5, 18), accent, 0.6)
	if activated:
		draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), accent, false, 2)
		draw_rect(Rect2(3, size.y - 6, size.x - 6, 3), accent)
	elif shot_count > 0:
		var width := minf(7, (size.x - 12) / float(shot_count) - 2)
		var left := (size.x - (width + 2) * shot_count + 2) * 0.5
		for i in range(shot_count):
			draw_rect(Rect2(left + i * (width + 2), size.y - 7, width, 4), accent if ready_slots.has(i + 1) else Color("3b5059"))
