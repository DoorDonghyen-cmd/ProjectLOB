extends Control
const COLORS := {"basic": Color("d2d6d5"), "pierce": Color("dcbc73"), "precise": Color("b1df98"), "bore": Color("79b6f2"), "mark": Color("e6a178"), "charge": Color("e48bc6"), "push": Color("69deeb"), "slow": Color("838bf5"), "arc": Color("c5aff5"), "finish": Color("f28c89")}
const SHORT := {"basic": "회수", "pierce": "파쇄", "precise": "연속", "bore": "균열", "mark": "조준", "charge": "강화", "push": "충격", "slow": "점착", "arc": "도약", "finish": "마무리"}
const HINT := {"basic": "재장전 시 공급", "pierce": "균열 소비 → 폭딜", "precise": "같은 적 2회 타격", "bore": "균열 +2 → 장갑↓", "mark": "다음 2발 명중↑", "charge": "다음 2발 피해↑", "push": "2m 밀어 표적 전환", "slow": "다음 접근 −2m", "arc": "균열 → 후열 피해↑", "finish": "반피 이하 → 피해↑"}
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
	if id in ["bore", "mark", "charge"]:
		canvas.draw_line(Vector2(-4, 16), Vector2(4, 16), Color("111b22"), 2)
		canvas.draw_line(Vector2(0, 12), Vector2(0, 20), Color("111b22"), 2)
	elif id in ["push", "slow"]:
		canvas.draw_circle(Vector2(0, 16), 3, Color("111b22"))
	canvas.draw_set_transform(Vector2.ZERO)
