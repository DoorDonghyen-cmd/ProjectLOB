extends RefCounted
## Role-shaped mechanical enemies with layered armour, lenses and moving joints.
static func draw(canvas: CanvasItem, p: Vector2, kind: String, accent: Color, scale_factor: float, phase: float = 0.0) -> void:
	var dark := Color("11202a")
	var steel := Color("687f87")
	var edge := Color("c4d0cb")
	canvas.draw_set_transform(p, 0.0, Vector2.ONE * scale_factor)
	canvas.draw_line(Vector2(-22, 21), Vector2(22, 21), Color(0.02, 0.035, 0.05, 0.65), 7, true)
	match kind:
		"runner":
			for i in range(4):
				var x := -19.0 + i * 12
				var foot := Vector2(x - 8 + sin(phase + i * PI) * 3, 22)
				canvas.draw_polyline(PackedVector2Array([Vector2(x, 1), Vector2(x + 5, 10), foot]), dark, 7, true)
				canvas.draw_polyline(PackedVector2Array([Vector2(x, 1), Vector2(x + 5, 10), foot]), steel, 3, true)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-28, -8), Vector2(-10, -19), Vector2(20, -13), Vector2(27, 1), Vector2(9, 9), Vector2(-24, 6)]), dark)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-23, -9), Vector2(-9, -15), Vector2(17, -10), Vector2(21, -1), Vector2(-19, 2)]), steel)
			canvas.draw_line(Vector2(-19, -10), Vector2(10, -12), edge, 2, true)
			canvas.draw_rect(Rect2(-28, -5, 12, 5), accent)
		"wall":
			for x in [-15, 15]:
				canvas.draw_rect(Rect2(x - 7, 7, 14, 19), dark)
				canvas.draw_rect(Rect2(x - 5, 9, 10, 13), steel)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-28, -22), Vector2(23, -22), Vector2(30, -10), Vector2(25, 17), Vector2(-25, 17)]), dark)
			canvas.draw_rect(Rect2(-23, -18, 44, 29), steel)
			canvas.draw_rect(Rect2(-17, -13, 32, 19), accent.darkened(0.15))
			canvas.draw_line(Vector2(-24, -18), Vector2(19, -18), edge, 3, true)
			canvas.draw_rect(Rect2(-8, -9, 13, 5), dark)
			for x in [-19, 17]: canvas.draw_circle(Vector2(x, 9), 2, edge)
		"caster":
			var y := sin(phase) * 2
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(0, -26 + y), Vector2(22, -5 + y), Vector2(13, 15 + y), Vector2(-13, 15 + y), Vector2(-22, -5 + y)]), dark)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(0, -21 + y), Vector2(17, -4 + y), Vector2(10, 10 + y), Vector2(-10, 10 + y), Vector2(-17, -4 + y)]), steel)
			canvas.draw_circle(Vector2(0, -4 + y), 10, dark)
			canvas.draw_circle(Vector2(0, -4 + y), 6, accent)
			for x in [-13, 0, 13]: canvas.draw_line(Vector2(x, 13 + y), Vector2(x - 3, 24 + y), accent, 2, true)
		"absorber":
			canvas.draw_circle(Vector2.ZERO, 25, dark)
			canvas.draw_arc(Vector2.ZERO, 21, 0, TAU, 32, steel, 8, true)
			for i in range(3):
				var angle := i * TAU / 3 + phase * 0.07
				canvas.draw_arc(Vector2.ZERO, 24, angle, angle + 1.25, 12, accent, 3, true)
			canvas.draw_circle(Vector2.ZERO, 10, accent.darkened(0.45))
			canvas.draw_circle(Vector2(-2, -3), 5, edge)
		"stance":
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(0, -27), Vector2(30, 19), Vector2(9, 12), Vector2(0, 20), Vector2(-9, 12), Vector2(-30, 19)]), dark)
			for direction in [-1, 1]:
				canvas.draw_colored_polygon(PackedVector2Array([Vector2(direction * 2, -21), Vector2(direction * 24, 15), Vector2(direction * 9, 8), Vector2(direction * 4, -2)]), steel)
				canvas.draw_line(Vector2(direction * 4, -12), Vector2(direction * 20, 12), edge, 2, true)
			canvas.draw_circle(Vector2(0, 1), 6, accent)
		_:
			canvas.draw_arc(Vector2.ZERO, 23, -0.3, TAU - 0.8, 28, dark, 9, true)
			canvas.draw_arc(Vector2.ZERO, 23, -0.3, TAU - 0.8, 28, steel, 4, true)
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-17, -7), Vector2(2, -16), Vector2(17, -1), Vector2(4, 16), Vector2(-12, 11)]), dark)
			canvas.draw_circle(Vector2(0, 0), 11, steel)
			canvas.draw_polyline(PackedVector2Array([Vector2(1, -12), Vector2(-5, 0), Vector2(4, -1), Vector2(-1, 13)]), accent, 3, true)
	canvas.draw_set_transform(Vector2.ZERO)
