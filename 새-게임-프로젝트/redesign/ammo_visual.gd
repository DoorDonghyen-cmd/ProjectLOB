extends Control
const ATTRIBUTE_NAMES := {"physical": "물리", "fire": "화염", "electric": "전기"}
const ATTRIBUTE_COLORS := {"physical": Color("cbd3d2"), "fire": Color("f29a5b"), "electric": Color("63dce8")}
const COLORS := {"basic": ATTRIBUTE_COLORS.physical, "pierce": ATTRIBUTE_COLORS.physical, "precise": ATTRIBUTE_COLORS.physical, "bore": ATTRIBUTE_COLORS.fire, "charge": ATTRIBUTE_COLORS.physical, "push": ATTRIBUTE_COLORS.physical, "arc": ATTRIBUTE_COLORS.electric}
const SHORT := {"basic": "회수", "pierce": "철갑", "precise": "연발", "bore": "소이", "charge": "증폭", "push": "충격", "arc": "전격"}
const HINT := {"basic": "재장전 시 공급", "pierce": "높은 관통", "precise": "같은 적 2회 타격", "bore": "화상 +3", "charge": "다음 2발 피해 +2", "push": "2m 밀어 거리 확보", "arc": "다른 적에게 2피해 전이"}
var ammo_id := "basic"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	round_icon(self, size * 0.5, ammo_id, 0.7)

static func round_icon(canvas: CanvasItem, position: Vector2, id: String, scale_factor: float = 1.0) -> void:
	var color: Color = COLORS.get(id, COLORS.basic)
	canvas.draw_set_transform(position, PI / 4.0, Vector2.ONE * scale_factor)
	canvas.draw_rect(Rect2(-9, -4, 18, 30), Color("111b22"))
	canvas.draw_rect(Rect2(-7, -3, 14, 27), Color("8d9699"))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-7, -4), Vector2(0, -19), Vector2(7, -4)]), color)
	canvas.draw_rect(Rect2(-7, 4, 14, 7), color)
	canvas.draw_rect(Rect2(-10, 23, 20, 4), color)
	if id in ["bore", "charge"]:
		canvas.draw_line(Vector2(-4, 16), Vector2(4, 16), Color("111b22"), 2)
		canvas.draw_line(Vector2(0, 12), Vector2(0, 20), Color("111b22"), 2)
	elif id == "push":
		canvas.draw_circle(Vector2(0, 16), 3, Color("111b22"))
	elif id == "precise":
		canvas.draw_line(Vector2(-4, 13), Vector2(4, 13), Color("111b22"), 2)
		canvas.draw_line(Vector2(-4, 18), Vector2(4, 18), Color("111b22"), 2)
	elif id == "pierce":
		canvas.draw_line(Vector2(-4, 19), Vector2(4, 12), Color("111b22"), 2)
	canvas.draw_set_transform(Vector2.ZERO)
