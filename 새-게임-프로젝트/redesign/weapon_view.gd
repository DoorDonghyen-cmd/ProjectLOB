extends Control
## Native mechanical weapon illustrations; the silhouette is the weapon identity.
const COLORS := {"single": Color("a9dfbf"), "burst": Color("f3ba75"), "scatter": Color("87c9df"), "heavy": Color("c4ace5"), "amplifier": Color("e6c176")}
var gun_id := "single"
var display_scale := 1.0

func _ready() -> void:
	custom_minimum_size = Vector2(70, 40) * display_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func poly(points: Array, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array(points), color)

func _draw() -> void:
	var factor := minf(size.x / 160.0, size.y / 80.0)
	draw_set_transform((size - Vector2(160, 80) * factor) * 0.5, 0.0, Vector2.ONE * factor)
	var accent: Color = COLORS[gun_id]
	var steel := Color("6c8590")
	var light := Color("d4d4c6")
	var dark := Color("0d1921")
	var brass := Color("a98452")
	# Receiver, trigger guard and wrapped grip provide a shared family.
	poly([Vector2(12, 28), Vector2(31, 17), Vector2(88, 17), Vector2(104, 28), Vector2(97, 48), Vector2(38, 48), Vector2(20, 61), Vector2(9, 55)], dark)
	poly([Vector2(16, 27), Vector2(33, 20), Vector2(85, 20), Vector2(99, 29), Vector2(92, 43), Vector2(35, 43), Vector2(20, 56), Vector2(12, 53)], steel)
	poly([Vector2(30, 39), Vector2(51, 42), Vector2(38, 72), Vector2(16, 66)], Color("3e3730"))
	for y in [48, 54, 60]: draw_line(Vector2(25, y), Vector2(40, y + 3), brass.darkened(0.25), 2, true)
	draw_arc(Vector2(57, 47), 10, -0.1, PI, 16, brass, 3, true)
	draw_line(Vector2(32, 21), Vector2(82, 21), light, 2, true)
	match gun_id:
		"single":
			draw_rect(Rect2(74, 25, 64, 15), dark)
			draw_rect(Rect2(78, 27, 54, 8), steel)
			draw_rect(Rect2(129, 22, 12, 22), brass)
			draw_circle(Vector2(64, 34), 20, dark)
			draw_circle(Vector2(64, 34), 16, brass)
			for i in range(5):
				var point := Vector2(64, 34) + Vector2.from_angle(float(i) * TAU / 5) * 10
				draw_circle(point, 3.5, dark)
			draw_circle(Vector2(64, 34), 4, accent)
		"burst":
			draw_rect(Rect2(84, 22, 65, 16), dark)
			draw_rect(Rect2(85, 25, 57, 8), steel)
			draw_rect(Rect2(97, 15, 24, 6), light)
			draw_line(Vector2(58, 44), Vector2(67, 72), dark, 15, true)
			draw_line(Vector2(58, 44), Vector2(67, 72), brass, 10, true)
			for x in [49, 60, 71]: draw_rect(Rect2(x, 29, 7, 10), accent)
			for x in [102, 111, 120, 129]: draw_rect(Rect2(x, 25, 3, 10), dark)
		"scatter":
			for y in [22, 37]:
				draw_rect(Rect2(71, y, 73, 13), dark)
				draw_rect(Rect2(77, y + 2, 61, 6), steel)
				draw_rect(Rect2(131, y - 2, 15, 15), brass)
				draw_rect(Rect2(141, y + 1, 4, 9), dark)
			draw_rect(Rect2(76, 34, 47, 4), accent)
			draw_rect(Rect2(50, 23, 17, 24), brass)
		"heavy":
			draw_rect(Rect2(69, 16, 75, 37), dark)
			draw_rect(Rect2(78, 22, 62, 22), steel)
			draw_rect(Rect2(83, 27, 55, 10), accent)
			for x in [81, 94, 107, 120]:
				draw_rect(Rect2(x, 16, 5, 37), brass)
				draw_line(Vector2(x + 1, 18), Vector2(x + 1, 48), light.darkened(0.2), 1, true)
			draw_rect(Rect2(135, 13, 14, 42), steel)
			draw_rect(Rect2(144, 20, 8, 28), dark)
			draw_circle(Vector2(58, 31), 8, accent)
		"amplifier":
			poly([Vector2(70, 17), Vector2(132, 17), Vector2(149, 29), Vector2(146, 43), Vector2(74, 43)], dark)
			draw_rect(Rect2(84, 22, 61, 10), light)
			draw_rect(Rect2(111, 9, 18, 43), brass)
			draw_rect(Rect2(116, 14, 8, 30), accent)
			draw_circle(Vector2(69, 31), 16, brass)
			draw_circle(Vector2(69, 31), 10, dark)
			draw_circle(Vector2(69, 31), 5, accent)
	for point in [Vector2(35, 29), Vector2(41, 38), Vector2(87, 29)]:
		draw_circle(point, 2.5, dark)
		draw_line(point - Vector2(1, 0), point + Vector2(1, 0), light, 1, true)
	draw_set_transform(Vector2.ZERO)
