@tool
extends "res://redesign/samples/shop_terminal_review/chassis.gd"

static func receiver_shift(height: float) -> float:
	return clampf(height - 416.0, -54.0, 0.0)

func _draw() -> void:
	var width := floorf(size.x)
	var height := floorf(size.y)
	if width < 580 or height < 330:
		return
	var monitor_width := width - 238.0
	var shift := receiver_shift(height)
	# The clamp ties two different enclosures together without covering the glass.
	draw_rect(Rect2(monitor_width - 4, 151 + shift, 24, 31), Color("242c27"))
	draw_rect(Rect2(monitor_width - 4, 334 + shift, 24, 31), Color("242c27"))
	_draw_monitor(monitor_width, height)
	draw_set_transform(Vector2(0, shift))
	_draw_receiver(width - 224, height - shift)
	draw_set_transform(Vector2.ZERO)

func _draw_monitor(width: float, height: float) -> void:
	_draw_plate(Rect2(8, 10, width, height), 10, Color("080b09"))
	_draw_plate(Rect2(0, 0, width, height), 12, Color("2c3530"))
	_draw_plate(Rect2(3, 3, width - 7, height - 10), 9, Color("626b60"))
	draw_rect(Rect2(15, 4, width - 31, 3), Color("899083"))
	draw_rect(Rect2(6, 15, 3, height - 33), Color("767e70"))
	draw_rect(Rect2(width - 8, 16, 4, height - 35), Color("39443b"))
	draw_rect(Rect2(14, height - 10, width - 29, 3), Color("303a32"))

	_draw_plate(Rect2(14, 9, width - 29, height - 22), 12, Color("343e35"))
	_draw_plate(Rect2(18, 12, width - 37, height - 29), 11, Color("171e19"))
	_draw_plate(Rect2(24, 16, width - 49, height - 36), 9, Color("101510"))
	draw_rect(Rect2(32, 16, width - 65, 2), Color("2a332a"))
	draw_rect(Rect2(31, height - 20, width - 63, 2), Color("6c725f"))

func _draw_receiver(x: float, height: float) -> void:
	const TOP := 74.0
	var enclosure_height := minf(408.0, height - TOP - 12.0)
	_draw_plate(Rect2(x + 6, TOP + 9, 218, enclosure_height), 8, Color("080b09"))
	_draw_plate(Rect2(x, TOP, 218, enclosure_height), 8, Color("242d26"))
	_draw_plate(Rect2(x + 4, TOP + 4, 210, enclosure_height - 10), 6, Color("3b453c"))
	draw_rect(Rect2(x + 10, TOP + 5, 196, 4), Color("626b59"))
	draw_rect(Rect2(x + 10, TOP + 12, 198, 3), Color("95663d"))
	draw_rect(Rect2(x + 210, TOP + 12, 4, enclosure_height - 26), Color("29352c"))

	_draw_plate(Rect2(x + 19, 101, 180, 83), 6, Color("3a3e30"))
	_draw_plate(Rect2(x + 23, 105, 172, 75), 4, Color("111711"))
	draw_rect(Rect2(x + 26, 178, 166, 2), Color("76705a"))
	draw_rect(Rect2(x + 16, 202, 186, 116), Color("28342a"))
	_draw_receiver_slot(Vector2(x + 23, 337))

	var vent_y := TOP + enclosure_height - 29.0
	for index in range(8):
		var vent_x := x + 62 + index * 12
		draw_rect(Rect2(vent_x, vent_y, 7, 10), Color("222d24"))
		draw_rect(Rect2(vent_x + 7, vent_y + 1, 1, 8), Color("646c56"))
	for screw_x in [x + 13, x + 197]:
		draw_rect(Rect2(screw_x, vent_y + 2, 6, 6), Color("1d271f"))
		draw_rect(Rect2(screw_x + 1, vent_y + 4, 4, 1), Color("81846c"))

func _draw_receiver_slot(origin: Vector2) -> void:
	var x := origin.x
	var y := origin.y
	_draw_plate(Rect2(x, y, 172, 39), 4, Color("252f25"))
	draw_rect(Rect2(x + 6, y + 9, 124, 20), Color("0d130e"))
	draw_rect(Rect2(x + 10, y + 24, 116, 4), Color("62684f"))
	draw_rect(Rect2(x + 36, y + 17, 62, 5), Color("8d8056") if record_active else Color("444d3a"))
	draw_rect(Rect2(x + 139, y + 11, 24, 16), Color("19251b"))
	draw_rect(Rect2(x + 145, y + 16, 12, 6), AMBER if record_active else Color("514f33"))
	if record_active:
		draw_rect(Rect2(x + 146, y + 16, 10, 2), Color("e5d5a3"))
