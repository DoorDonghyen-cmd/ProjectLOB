extends Control
const Content = preload("res://redesign/content.gd")
const ATTRIBUTE_NAMES := {"physical": "물리", "fire": "화염", "electric": "전기"}
const ATTRIBUTE_COLORS := {"physical": Color("cbd3d2"), "fire": Color("f29a5b"), "electric": Color("63dce8")}
const COLORS := {"basic": ATTRIBUTE_COLORS.physical, "pierce": ATTRIBUTE_COLORS.physical, "precise": ATTRIBUTE_COLORS.physical, "bore": ATTRIBUTE_COLORS.fire, "charge": ATTRIBUTE_COLORS.physical, "push": ATTRIBUTE_COLORS.physical, "arc": ATTRIBUTE_COLORS.electric, "pierce_c": ATTRIBUTE_COLORS.physical, "precise_c": ATTRIBUTE_COLORS.physical, "bore_c": ATTRIBUTE_COLORS.fire, "charge_c": ATTRIBUTE_COLORS.physical, "push_c": ATTRIBUTE_COLORS.physical, "arc_c": ATTRIBUTE_COLORS.electric, "pierce_f": ATTRIBUTE_COLORS.physical, "precise_f": ATTRIBUTE_COLORS.physical, "bore_f": ATTRIBUTE_COLORS.fire, "charge_f": ATTRIBUTE_COLORS.physical, "push_f": ATTRIBUTE_COLORS.physical, "arc_f": ATTRIBUTE_COLORS.electric}
const SHORT := {"basic": "회수", "pierce": "철갑", "precise": "연발", "bore": "소이", "charge": "증폭", "push": "충격", "arc": "전격", "pierce_c": "철갑", "precise_c": "연발", "bore_c": "소이", "charge_c": "증폭", "push_c": "충격", "arc_c": "전격", "pierce_f": "철갑", "precise_f": "연발", "bore_f": "소이", "charge_f": "증폭", "push_f": "충격", "arc_f": "전격"}
const HINT := {"basic": "재장전 시 공급", "pierce": "높은 관통", "precise": "같은 적 2회 타격", "bore": "화상 +3", "charge": "다음 2발 피해 +2", "push": "2m 밀어 거리 확보", "arc": "다른 적에게 2피해 전이", "pierce_c": "두 칸에 관통 집중", "precise_c": "첫 발 · 같은 적 3회", "bore_c": "두 칸에 화상 집중", "charge_c": "마지막 발 · 다음 탄창 증폭", "push_c": "마지막 발 · 강한 넉백", "arc_c": "첫 발 · 모든 다른 적 전이", "pierce_f": "두 칸에 관통 집중", "precise_f": "첫 발 · 같은 적 3회", "bore_f": "두 칸에 화상 집중", "charge_f": "마지막 발 · 다음 탄창 증폭", "push_f": "마지막 발 · 강한 넉백", "arc_f": "첫 발 · 모든 다른 적 전이"}
var ammo_id := "basic"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	round_icon(self, size * 0.5, ammo_id, 0.7)

static func round_icon(canvas: CanvasItem, position: Vector2, id: String, scale_factor: float = 1.0) -> void:
	var color: Color = COLORS.get(id, COLORS.basic)
	var base_id := Content.source_id(id)
	var compressed := Content.is_compressed(id)
	canvas.draw_set_transform(position, PI / 4.0, Vector2.ONE * scale_factor)
	if compressed:
		canvas.draw_rect(Rect2(-12, -7, 24, 37), Color("a9dfbf"), false, 2.0)
		canvas.draw_rect(Rect2(-10, -5, 20, 33), Color(0.66, 0.87, 0.75, 0.13), true)
	canvas.draw_rect(Rect2(-9, -4, 18, 30), Color("111b22"))
	canvas.draw_rect(Rect2(-7, -3, 14, 27), Color("8d9699"))
	canvas.draw_colored_polygon(PackedVector2Array([Vector2(-7, -4), Vector2(0, -19), Vector2(7, -4)]), color)
	canvas.draw_rect(Rect2(-7, 4, 14, 7), color)
	canvas.draw_rect(Rect2(-10, 23, 20, 4), color)
	if base_id in ["bore", "charge"]:
		canvas.draw_line(Vector2(-4, 16), Vector2(4, 16), Color("111b22"), 2)
		canvas.draw_line(Vector2(0, 12), Vector2(0, 20), Color("111b22"), 2)
	elif base_id == "push":
		canvas.draw_circle(Vector2(0, 16), 3, Color("111b22"))
	elif base_id == "precise":
		canvas.draw_line(Vector2(-4, 13), Vector2(4, 13), Color("111b22"), 2)
		canvas.draw_line(Vector2(-4, 18), Vector2(4, 18), Color("111b22"), 2)
	elif base_id == "pierce":
		canvas.draw_line(Vector2(-4, 19), Vector2(4, 12), Color("111b22"), 2)
	if compressed:
		canvas.draw_colored_polygon(PackedVector2Array([Vector2(0, 7), Vector2(4, 11), Vector2(0, 15), Vector2(-4, 11)]), Color("e7e4d9"))
		canvas.draw_circle(Vector2(0, 11), 1.5, color)
	if Content.is_temporary(id):
		canvas.draw_arc(Vector2.ZERO, 25, -PI * 0.15, PI * 0.35, 8, Color("63dce8"), 2.0)
		canvas.draw_arc(Vector2.ZERO, 25, PI * 0.85, PI * 1.35, 8, Color("63dce8"), 2.0)
	canvas.draw_set_transform(Vector2.ZERO)
