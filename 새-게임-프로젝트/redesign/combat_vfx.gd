extends RefCounted
## Local, deterministic pixel geometry. Never consumes the model's random stream.
const GRID := Vector2(2, 2)

static func armor(canvas: CanvasItem, origin: Vector2, progress: float) -> void:
	var t := clampf(progress, 0.0, 1.0)
	for i in range(6):
		var side := -1.0 if i % 2 == 0 else 1.0
		var travel := Vector2(side * (14 + i * 5) * t, -(22 + i * 3) * t + 48 * t * t)
		var p := (origin + travel).snapped(GRID)
		var extent := Vector2(8 if i % 3 == 0 else 6, 4)
		canvas.draw_rect(Rect2(p, extent + Vector2(2, 2)), Color("24343e", 1.0 - t))
		canvas.draw_rect(Rect2(p, extent), Color("a0aaa5", 1.0 - t))
		canvas.draw_rect(Rect2(p, Vector2(extent.x, 2)), Color("d4c4a0", 1.0 - t))
	if t < 0.28:
		canvas.draw_polyline(PackedVector2Array([origin+Vector2(-12,-10), origin+Vector2(-4,-10), origin+Vector2(-4,0), origin+Vector2(4,0), origin+Vector2(4,10), origin+Vector2(12,10)]), Color("e0d5b5"), 2, false)

static func arc(canvas: CanvasItem, start: Vector2, finish: Vector2, progress: float, reduced: bool) -> void:
	if reduced:
		canvas.draw_line(start.round(), finish.round(), Color("9bbfc4", 1.0-progress), 2, false)
		return
	var points := PackedVector2Array([start.snapped(GRID)])
	var bends := [0.0, -10.0, 8.0, -6.0, 10.0, -4.0, 0.0]
	for i in range(1, bends.size()):
		var point := start.lerp(finish, float(i) / (bends.size()-1))
		point.y += bends[i] * (1.0 if progress < 0.38 else -0.6)
		# Stair-step joints share the UI's square pixel language.
		point = point.snapped(GRID)
		points.append(Vector2(point.x, points[-1].y))
		points.append(point)
	canvas.draw_polyline(points, Color("324e63", (1.0-progress)*0.8), 6, false)
	canvas.draw_polyline(points, Color("a9d0d2", 1.0-progress), 2, false)
	if progress < 0.3:
		canvas.draw_rect(Rect2(finish.snapped(GRID)-Vector2(4,4), Vector2(8,8)), Color("dce7d5"))

static func steam(canvas: CanvasItem, muzzle: Vector2, progress: float) -> void:
	for i in range(5):
		var age := clampf((progress-float(i)*0.065)/0.74, 0.0, 1.0)
		if age <= 0 or age >= 1: continue
		var p := (muzzle + Vector2(-18 + i*5 + age*(i-2)*5, -8-age*36)).snapped(GRID)
		var width := 6.0 + floorf(age*3)*2
		var color := Color("a8bbbd", (1.0-age)*0.65)
		canvas.draw_rect(Rect2(p, Vector2(width,4)), color)
		canvas.draw_rect(Rect2(p+Vector2(2,-2), Vector2(width-4,8)), color)
