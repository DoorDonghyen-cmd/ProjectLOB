extends Control
## Procedural icons for simple non-combat choices: capacity, compression, and credits.
const AmmoVisual = preload("res://redesign/ammo_visual.gd")
const FONT = preload("res://assets/fonts/NeoDunggeunmoPro-Regular.ttf")
const INK := Color("e7e4d9")
const MUTED := Color("94a9ae")
const ACCENT := Color("a9dfbf")
const CYAN := Color("63dce8")
const GOLD := Color("e4bd72")

var kind := "slot"
var data: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()

func setup(choice_kind: String, values: Dictionary = {}) -> void:
	kind = choice_kind
	data = values
	queue_redraw()

func _draw() -> void:
	var accent := GOLD if kind == "credits" else (CYAN if kind in ["compress", "core"] else ACCENT)
	draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color(accent, 0.06), true)
	match kind:
		"slot": _draw_slots(Vector2(54, size.y * 0.5), accent)
		"compress": _draw_compress(Vector2(56, size.y * 0.5), accent)
		"credits": _draw_credits(Vector2(53, size.y * 0.5), accent)
		"core": _draw_core(Vector2(57, size.y * 0.5), accent)
	var title: String = str({"slot": "탄창 확장", "compress": "탄환 압축", "credits": "크레딧", "core": "압축 코어"}.get(kind, "선택"))
	var value := ""
	var caption := ""
	match kind:
		"slot":
			value = "%d → %d칸" % [int(data.get("before", 4)), int(data.get("after", 5))]
			caption = "영구 용량 +1"
		"compress":
			value = "2발 → 1발"
			caption = "위치·공간 제약 추가"
		"credits":
			value = "+%d Cr" % int(data.get("amount", 24))
			caption = "다음 무기고 자금"
		"core":
			value = "%d / %d" % [int(data.get("count", 0)), int(data.get("max", 2))]
			caption = str(data.get("caption", "전투 중 임시 압축 1회"))
	var x := 112.0
	draw_string(FONT, Vector2(x, 31), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - x - 10, 20, accent)
	draw_string(FONT, Vector2(x, 67), value, HORIZONTAL_ALIGNMENT_LEFT, size.x - x - 10, 26, INK)
	draw_string(FONT, Vector2(x, 94), caption, HORIZONTAL_ALIGNMENT_LEFT, size.x - x - 10, 15, MUTED)
	if data.has("price"):
		var price := str(data.price)
		draw_string(FONT, Vector2(size.x - 125, 31), price, HORIZONTAL_ALIGNMENT_RIGHT, 110, 17, GOLD)

func _draw_slots(center: Vector2, color: Color) -> void:
	var after := int(data.get("after", 5))
	var before := int(data.get("before", after - 1))
	var cell_h := 11.0
	var total := after * cell_h
	for i in range(after):
		var rect := Rect2(center.x - 19, center.y - total * 0.5 + i * cell_h, 38, 9)
		draw_rect(rect, Color(color, 0.2 if i < before else 0.45), true)
		draw_rect(rect, color if i >= before else MUTED, false, 2.0 if i >= before else 1.0)
	draw_line(center + Vector2(27, -7), center + Vector2(27, 7), color, 3.0)
	draw_line(center + Vector2(20, 0), center + Vector2(34, 0), color, 3.0)

func _draw_compress(center: Vector2, color: Color) -> void:
	AmmoVisual.round_icon(self, center + Vector2(-27, -15), "pierce", 0.27)
	AmmoVisual.round_icon(self, center + Vector2(-27, 16), "pierce", 0.27)
	draw_line(center + Vector2(-13, -11), center + Vector2(2, -3), color, 2.0)
	draw_line(center + Vector2(-13, 12), center + Vector2(2, 3), color, 2.0)
	draw_colored_polygon(PackedVector2Array([center + Vector2(1, -6), center + Vector2(11, 0), center + Vector2(1, 6)]), color)
	AmmoVisual.round_icon(self, center + Vector2(28, 0), "pierce_c", 0.45)

func _draw_credits(center: Vector2, color: Color) -> void:
	for i in range(3):
		var offset := Vector2(i * 8 - 12, i * -8 + 8)
		draw_circle(center + offset, 15, Color("172731"))
		draw_arc(center + offset, 15, 0, TAU, 24, color, 3.0)
		draw_circle(center + offset, 4, color)

func _draw_core(center: Vector2, color: Color) -> void:
	AmmoVisual.round_icon(self, center + Vector2(-30, -16), "basic", 0.24)
	AmmoVisual.round_icon(self, center + Vector2(-30, 16), "basic", 0.24)
	draw_line(center + Vector2(-17, -12), center + Vector2(-4, -3), color, 2.0)
	draw_line(center + Vector2(-17, 12), center + Vector2(-4, 3), color, 2.0)
	var diamond := PackedVector2Array([center + Vector2(14, -17), center + Vector2(31, 0), center + Vector2(14, 17), center + Vector2(-3, 0), center + Vector2(14, -17)])
	draw_colored_polygon(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3]]), Color(color, 0.2))
	draw_polyline(diamond, color, 3.0)
	var count := int(data.get("count", 0))
	for i in range(2): draw_circle(center + Vector2(43, -7 + i * 14), 4, ACCENT if i < count else Color("3d4f57"))
