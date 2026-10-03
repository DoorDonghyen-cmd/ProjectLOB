extends Control
const Content = preload("res://redesign/content.gd")
const ATTRIBUTE_NAMES := {"physical": "물리", "fire": "화염", "electric": "전기"}
const ATTRIBUTE_COLORS := {"physical": Color("cbd3d2"), "fire": Color("f29a5b"), "electric": Color("63dce8")}
const COLORS := {"basic": ATTRIBUTE_COLORS.physical, "pierce": ATTRIBUTE_COLORS.physical, "precise": ATTRIBUTE_COLORS.physical, "bore": ATTRIBUTE_COLORS.fire, "charge": ATTRIBUTE_COLORS.physical, "charge_hot": Color("ed9167"), "push": ATTRIBUTE_COLORS.physical, "arc": ATTRIBUTE_COLORS.electric, "pierce_c": ATTRIBUTE_COLORS.physical, "precise_c": ATTRIBUTE_COLORS.physical, "bore_c": ATTRIBUTE_COLORS.fire, "charge_c": ATTRIBUTE_COLORS.physical, "push_c": ATTRIBUTE_COLORS.physical, "arc_c": ATTRIBUTE_COLORS.electric, "pierce_f": ATTRIBUTE_COLORS.physical, "precise_f": ATTRIBUTE_COLORS.physical, "bore_f": ATTRIBUTE_COLORS.fire, "charge_f": ATTRIBUTE_COLORS.physical, "push_f": ATTRIBUTE_COLORS.physical, "arc_f": ATTRIBUTE_COLORS.electric}
const SHORT := {"basic": "회수", "pierce": "철갑", "precise": "연발", "bore": "소이", "charge": "증폭", "charge_hot": "증폭", "push": "충격", "arc": "전격", "pierce_c": "철갑", "precise_c": "연발", "bore_c": "소이", "charge_c": "증폭", "push_c": "충격", "arc_c": "전격", "pierce_f": "철갑", "precise_f": "연발", "bore_f": "소이", "charge_f": "증폭", "push_f": "충격", "arc_f": "전격"}
const HINT := {"basic": "재장전 시 공급", "pierce": "높은 관통", "precise": "같은 적 2회 타격", "bore": "화상 +3", "charge": "다음 2발 피해 +2", "charge_hot": "고출력 +4 · 다음 재장전 +1턴", "push": "2m 밀어 거리 확보", "arc": "다른 적에게 2피해 전이", "pierce_c": "두 칸에 관통 집중", "precise_c": "첫 발 · 같은 적 3회", "bore_c": "두 칸에 화상 집중", "charge_c": "마지막 발 · 다음 탄창 증폭", "push_c": "마지막 발 · 강한 넉백", "arc_c": "첫 발 · 모든 다른 적 전이", "pierce_f": "두 칸에 관통 집중", "precise_f": "첫 발 · 같은 적 3회", "bore_f": "두 칸에 화상 집중", "charge_f": "마지막 발 · 다음 탄창 증폭", "push_f": "마지막 발 · 강한 넉백", "arc_f": "첫 발 · 모든 다른 적 전이"}
var ammo_id := "basic"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	round_icon(self, size * 0.5, ammo_id, 0.7)

static func round_icon(canvas: CanvasItem, position: Vector2, id: String, scale_factor: float = 1.0) -> void:
	preload("res://redesign/pixel_art.gd").round_icon(canvas, position, Content.source_id(id), COLORS.get(id, COLORS.basic), scale_factor, Content.is_compressed(id), Content.is_temporary(id))
	if Content.heat_cost(id) > 0:
		heat_icon(canvas, position + Vector2(12, -23) * scale_factor, scale_factor)

static func heat_icon(canvas: CanvasItem, position: Vector2, scale_factor: float = 1.0) -> void:
	var color := Color("ed9167")
	for x in [-5, 0, 5]:
		var points := PackedVector2Array()
		for point in [Vector2(x, 5), Vector2(x, 1), Vector2(x + 2, -1), Vector2(x + 2, -5)]:
			points.append((position + point * scale_factor).round())
		canvas.draw_polyline(points, color, maxf(1, 2 * scale_factor), false)
