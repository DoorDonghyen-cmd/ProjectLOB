extends Control
## Icon-first part card shared by shops, rewards, and equipment summaries.
const Content = preload("res://redesign/content.gd")
const FONT = preload("res://assets/fonts/NeoDunggeunmoPro-Regular.ttf")

const INK := Color("e7e4d9")
const MUTED := Color("94a9ae")
const CHIP := Color("12212a")
const COLORS := {
	"none": Color("667982"),
	"lens": Color("79b6f2"),
	"loader": Color("a9dfbf"),
	"supply": Color("e4bd72"),
	"coil": Color("f29a5b"),
	"capacitor": Color("63dce8"),
	"rammer": Color("c5a3e8"),
	"sequencer": Color("f0cf68"),
	"duplex": Color("e887b7"),
	"igniter": Color("ff8b52"),
	"breaker": Color("87a9ff"),
	"executioner": Color("ef6f75"),
	"reserve": Color("95d5a4"),
	"opening": Color("71d4ff"),
	"afterburner": Color("ffb357"),
	"field_press": Color("ffd86b"),
	"overbore": Color("ffd86b"),
	"inferno": Color("ffd86b"),
	"arc_splitter": Color("ffd86b"),
	"momentum": Color("ffd86b"),
	"triad": Color("ffd86b"),
}

var part_id := "none"
var state: Dictionary = {}
var equipped := false
var compact := false
var mini := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()

func setup(id: String, current_state: Dictionary, is_equipped: bool = false, is_compact: bool = false, is_mini: bool = false) -> void:
	part_id = id if Content.PARTS.has(id) else "none"
	state = current_state
	equipped = is_equipped
	compact = is_compact
	mini = is_mini
	tooltip_text = str(Content.PARTS[part_id].text)
	queue_redraw()

func effect_title() -> String:
	return str(Content.PARTS[part_id].get("effect", "장착 슬롯"))

func effect_value() -> String:
	return str(Content.PARTS[part_id].get("value", "비어 있음"))

func role_text() -> String:
	return str(Content.PARTS[part_id].get("role", "전투 사이 무료 교체"))

func _draw() -> void:
	if not Content.PARTS.has(part_id): return
	var accent: Color = COLORS.get(part_id, Color("94a9ae"))
	if mini:
		_draw_mini(accent)
		return
	var icon_center := Vector2(45 if compact else 51, size.y * 0.5)
	var icon_scale := 0.82 if compact else 1.0
	var fill := accent
	fill.a = 0.07 if not equipped else 0.13
	draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), fill, true)
	if equipped:
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), accent, false, 2.0)
	if Content.is_core_part(part_id):
		draw_rect(Rect2(Vector2(5, 5), size - Vector2(10, 10)), Color("ffd86b"), false, 2.0)
	_draw_part_icon(icon_center, accent, icon_scale)
	var text_x := 88.0 if compact else 102.0
	var title_y := 28.0 if compact else 31.0
	draw_string(FONT, Vector2(text_x, title_y), str(Content.PARTS[part_id].name), HORIZONTAL_ALIGNMENT_LEFT, size.x - text_x - 12, 19 if compact else 21, accent)
	_draw_effect_icon(Vector2(text_x + 10, 53 if compact else 59), accent, 0.82 if compact else 1.0)
	draw_string(FONT, Vector2(text_x + 29, 60 if compact else 66), "▲ " + effect_value(), HORIZONTAL_ALIGNMENT_LEFT, size.x - text_x - 38, 16 if compact else 19, INK)
	var downside := str(Content.PARTS[part_id].get("downside", ""))
	if not downside.is_empty():
		draw_string(FONT, Vector2(text_x, 79 if compact else 88), "▼ " + downside, HORIZONTAL_ALIGNMENT_LEFT, size.x - text_x - 12, 14 if compact else 16, Color("ef7777"))
	elif not compact:
		draw_string(FONT, Vector2(text_x, 88), effect_title() + " · " + role_text(), HORIZONTAL_ALIGNMENT_LEFT, size.x - text_x - 12, 15, MUTED)
	if not compact and not downside.is_empty():
		draw_string(FONT, Vector2(text_x, 108), role_text(), HORIZONTAL_ALIGNMENT_LEFT, size.x - text_x - 12, 14, MUTED)
	if equipped:
		var label := "장착"
		var width := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 14
		draw_rect(Rect2(size.x - width - 5, 5, width, 22), CHIP, true)
		draw_string(FONT, Vector2(size.x - width + 2, 21), label, HORIZONTAL_ALIGNMENT_LEFT, width - 8, 14, accent)
	elif Content.is_core_part(part_id):
		draw_rect(Rect2(size.x - 55, 5, 50, 22), CHIP, true)
		draw_string(FONT, Vector2(size.x - 49, 21), "CORE", HORIZONTAL_ALIGNMENT_LEFT, 42, 13, Color("ffd86b"))

func _draw_mini(accent: Color) -> void:
	var fill := accent
	fill.a = 0.08 if part_id == "none" else 0.16
	draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), fill, true)
	draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), accent, false, 2.0 if equipped else 1.0)
	if Content.is_core_part(part_id):
		draw_rect(Rect2(Vector2(4, 4), size - Vector2(8, 8)), Color("ffd86b"), false, 2.0)
	_draw_part_icon(Vector2(31, size.y * 0.5), accent, 0.58)
	draw_string(FONT, Vector2(61, 27), str(Content.PARTS[part_id].name), HORIZONTAL_ALIGNMENT_LEFT, size.x - 67, 15, accent)
	var value_color := Color("ef7777") if part_id == "none" else INK
	draw_string(FONT, Vector2(61, 49), effect_value(), HORIZONTAL_ALIGNMENT_LEFT, size.x - 67, 13, value_color)
	if Content.is_core_part(part_id):
		draw_rect(Rect2(size.x - 39, 4, 34, 17), CHIP, true)
		draw_string(FONT, Vector2(size.x - 35, 17), "CORE", HORIZONTAL_ALIGNMENT_LEFT, 29, 10, Color("ffd86b"))

func _draw_part_icon(center: Vector2, color: Color, scale_factor: float) -> void:
	draw_set_transform(center, 0.0, Vector2.ONE * scale_factor)
	var dark := Color("13212a")
	match part_id:
		"lens":
			draw_rect(Rect2(-29, -7, 39, 14), Color(color, 0.22), true)
			draw_rect(Rect2(-29, -7, 39, 14), color, false, 3.0)
			draw_line(Vector2(-35, 0), Vector2(-29, 0), color, 5.0)
			draw_circle(Vector2(15, 0), 14, dark)
			draw_arc(Vector2(15, 0), 14, 0, TAU, 24, color, 3.0)
			draw_arc(Vector2(15, 0), 6, 0, TAU, 16, color, 2.0)
			draw_line(Vector2(18, -18), Vector2(18, 18), Color(color, 0.5), 2.0)
		"loader":
			draw_circle(Vector2.ZERO, 15, dark)
			draw_arc(Vector2.ZERO, 25, -PI * 0.15, PI * 0.72, 20, color, 4.0)
			draw_arc(Vector2.ZERO, 25, PI * 0.85, PI * 1.72, 20, color, 4.0)
			draw_colored_polygon(PackedVector2Array([Vector2(20, -18), Vector2(31, -18), Vector2(25, -8)]), color)
			draw_colored_polygon(PackedVector2Array([Vector2(-20, 18), Vector2(-31, 18), Vector2(-25, 8)]), color)
			for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
				draw_circle(Vector2(cos(angle), sin(angle)) * 9, 3, color)
		"supply":
			draw_colored_polygon(PackedVector2Array([Vector2(-22, -25), Vector2(15, -25), Vector2(22, 24), Vector2(-16, 24)]), Color(color, 0.16))
			draw_polyline(PackedVector2Array([Vector2(-22, -25), Vector2(15, -25), Vector2(22, 24), Vector2(-16, 24), Vector2(-22, -25)]), color, 3.0)
			for y in [-14.0, -2.0, 10.0]:
				draw_rect(Rect2(-11, y - 3, 21, 6), color, true)
			draw_line(Vector2(30, 3), Vector2(30, 21), color, 4.0)
			draw_line(Vector2(21, 12), Vector2(39, 12), color, 4.0)
		"coil":
			draw_rect(Rect2(-21, -25, 30, 50), Color(color, 0.12), true)
			draw_rect(Rect2(-21, -25, 30, 50), color, false, 3.0)
			for y in [-16.0, -6.0, 4.0, 14.0]:
				draw_line(Vector2(-26, y), Vector2(14, y + 7), color, 3.0)
			draw_colored_polygon(PackedVector2Array([Vector2(25, -25), Vector2(36, -7), Vector2(31, 7), Vector2(23, 17), Vector2(16, 5), Vector2(18, -8)]), color)
			draw_colored_polygon(PackedVector2Array([Vector2(25, -12), Vector2(30, -3), Vector2(25, 8), Vector2(21, 1)]), dark)
		"capacitor":
			for x in [-13.0, 13.0]:
				draw_rect(Rect2(x - 8, -22, 16, 44), Color(color, 0.14), true)
				draw_rect(Rect2(x - 8, -22, 16, 44), color, false, 3.0)
			draw_line(Vector2(-5, 0), Vector2(5, 0), color, 5.0)
			draw_colored_polygon(PackedVector2Array([Vector2(2, -19), Vector2(13, -4), Vector2(6, -3), Vector2(13, 16), Vector2(-3, 1), Vector2(5, 0)]), color)
		"rammer":
			draw_rect(Rect2(-31, -12, 45, 24), Color(color, 0.16), true)
			draw_rect(Rect2(-31, -12, 45, 24), color, false, 3.0)
			draw_colored_polygon(PackedVector2Array([Vector2(14, -22), Vector2(34, 0), Vector2(14, 22)]), color)
			draw_line(Vector2(-37, 0), Vector2(-25, 0), color, 5.0)
		"sequencer":
			for x in [-22.0, 0.0, 22.0]:
				draw_circle(Vector2(x, 0), 9, Color(color, 0.18))
				draw_arc(Vector2(x, 0), 9, 0, TAU, 16, color, 3.0)
			draw_line(Vector2(-13, 0), Vector2(-9, 0), color, 3.0)
			draw_line(Vector2(9, 0), Vector2(13, 0), color, 3.0)
		"duplex":
			for y in [-10.0, 10.0]:
				draw_rect(Rect2(-29, y - 6, 48, 12), Color(color, 0.17), true)
				draw_rect(Rect2(-29, y - 6, 48, 12), color, false, 3.0)
			draw_line(Vector2(19, -10), Vector2(33, -10), color, 5.0)
			draw_line(Vector2(19, 10), Vector2(33, 10), color, 5.0)
		"igniter":
			draw_circle(Vector2(-11, 5), 17, Color(color, 0.16))
			draw_arc(Vector2(-11, 5), 17, 0, TAU, 24, color, 3.0)
			draw_colored_polygon(PackedVector2Array([Vector2(15, 24), Vector2(8, 5), Vector2(22, -22), Vector2(34, 5)]), color)
		"breaker":
			var shield := PackedVector2Array([Vector2(-24, -24), Vector2(24, -24), Vector2(20, 9), Vector2(0, 28), Vector2(-20, 9), Vector2(-24, -24)])
			draw_polyline(shield, color, 3.0)
			draw_line(Vector2(-16, 17), Vector2(18, -17), color, 5.0)
			draw_line(Vector2(-2, 4), Vector2(14, 20), color, 4.0)
		"executioner":
			for radius in [26.0, 15.0, 5.0]: draw_arc(Vector2.ZERO, radius, 0, TAU, 24, color, 3.0)
			draw_line(Vector2(-34, 0), Vector2(34, 0), color, 2.0)
			draw_line(Vector2(0, -34), Vector2(0, 34), color, 2.0)
		"reserve":
			for x in [-18.0, 0.0, 18.0]:
				draw_rect(Rect2(x - 6, -21, 12, 42), Color(color, 0.16), true)
				draw_rect(Rect2(x - 6, -21, 12, 42), color, false, 2.0)
			draw_line(Vector2(27, 7), Vector2(27, 25), color, 4.0)
			draw_line(Vector2(18, 16), Vector2(36, 16), color, 4.0)
		"opening":
			draw_colored_polygon(PackedVector2Array([Vector2(-31, -21), Vector2(18, 0), Vector2(-31, 21)]), Color(color, 0.18))
			draw_polyline(PackedVector2Array([Vector2(-31, -21), Vector2(18, 0), Vector2(-31, 21), Vector2(-31, -21)]), color, 3.0)
			draw_line(Vector2(18, 0), Vector2(34, 0), color, 5.0)
		"afterburner":
			draw_line(Vector2(-32, 0), Vector2(14, 0), color, 7.0)
			draw_colored_polygon(PackedVector2Array([Vector2(14, -12), Vector2(34, 0), Vector2(14, 12)]), color)
			draw_colored_polygon(PackedVector2Array([Vector2(-32, -13), Vector2(-18, 0), Vector2(-32, 13)]), Color("ef7777"))
		"field_press":
			draw_rect(Rect2(-27, -25, 54, 50), Color(color, 0.12), true)
			draw_rect(Rect2(-27, -25, 54, 50), color, false, 3.0)
			draw_line(Vector2(-18, -13), Vector2(18, -13), color, 5.0)
			draw_line(Vector2(-18, 13), Vector2(18, 13), color, 5.0)
			draw_line(Vector2(0, -13), Vector2(0, 13), color, 3.0)
		"overbore":
			draw_rect(Rect2(-33, -13, 54, 26), Color(color, 0.16), true)
			draw_rect(Rect2(-33, -13, 54, 26), color, false, 4.0)
			draw_circle(Vector2(23, 0), 15, dark)
			draw_arc(Vector2(23, 0), 15, 0, TAU, 20, color, 4.0)
		"inferno":
			draw_colored_polygon(PackedVector2Array([Vector2(0, -31), Vector2(20, -6), Vector2(14, 25), Vector2(0, 32), Vector2(-17, 21), Vector2(-21, -4)]), color)
			draw_colored_polygon(PackedVector2Array([Vector2(0, -12), Vector2(9, 2), Vector2(5, 18), Vector2(-7, 14), Vector2(-10, 1)]), dark)
		"arc_splitter":
			draw_colored_polygon(PackedVector2Array([Vector2(-7, -31), Vector2(8, -8), Vector2(-1, -5), Vector2(11, 9), Vector2(2, 11), Vector2(11, 31), Vector2(-18, 5), Vector2(-8, 2)]), color)
			draw_line(Vector2(8, -8), Vector2(31, -22), color, 4.0)
			draw_line(Vector2(11, 9), Vector2(32, 23), color, 4.0)
		"momentum":
			for x in [-24.0, -10.0, 4.0]: draw_line(Vector2(x, -15), Vector2(x + 18, 0), color, 4.0)
			draw_colored_polygon(PackedVector2Array([Vector2(8, -24), Vector2(35, 0), Vector2(8, 24)]), color)
		"triad":
			for i in range(3):
				var pip_center := Vector2(-24 + i * 24, 0)
				draw_circle(pip_center, 10, Color(color, 0.16))
				draw_arc(pip_center, 10, 0, TAU, 18, color, 3.0)
				draw_string(FONT, pip_center + Vector2(-4, 5), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, 10, 12, color)
		_:
			for offset in [-22.0, 0.0, 22.0]:
				draw_line(Vector2(offset - 8, -20), Vector2(offset + 8, -20), color, 2.0)
				draw_line(Vector2(offset - 8, 20), Vector2(offset + 8, 20), color, 2.0)
			draw_line(Vector2(-30, -20), Vector2(-30, 20), color, 2.0)
			draw_line(Vector2(30, -20), Vector2(30, 20), color, 2.0)
	draw_set_transform(Vector2.ZERO)

func _draw_effect_icon(center: Vector2, color: Color, scale_factor: float) -> void:
	draw_set_transform(center, 0.0, Vector2.ONE * scale_factor)
	match part_id:
		"lens":
			var shield := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(7, 2), Vector2(0, 10), Vector2(-7, 2), Vector2(-8, -8)])
			draw_polyline(shield, color, 2.5)
			draw_line(Vector2(-12, 0), Vector2(13, 0), color, 2.5)
			draw_line(Vector2(8, -4), Vector2(13, 0), color, 2.5)
			draw_line(Vector2(8, 4), Vector2(13, 0), color, 2.5)
		"loader":
			draw_arc(Vector2.ZERO, 9, -PI * 0.2, PI * 1.45, 16, color, 2.5)
			draw_colored_polygon(PackedVector2Array([Vector2(5, -9), Vector2(13, -9), Vector2(10, -2)]), color)
		"supply":
			for x in [-8.0, 0.0, 8.0]:
				var rect := Rect2(x - 3, -7, 6, 14)
				if x < 8.0: draw_rect(rect, color, true)
				else: draw_rect(rect, color, false, 2.0)
		"coil":
			draw_colored_polygon(PackedVector2Array([Vector2(0, -11), Vector2(8, 0), Vector2(4, 10), Vector2(-5, 8), Vector2(-8, 0)]), color)
		"capacitor":
			draw_colored_polygon(PackedVector2Array([Vector2(-2, -11), Vector2(8, -2), Vector2(2, 0), Vector2(8, 10), Vector2(-8, 1), Vector2(-2, -1)]), color)
		"rammer":
			draw_line(Vector2(-11, 0), Vector2(9, 0), color, 3.0)
			draw_colored_polygon(PackedVector2Array([Vector2(5, -7), Vector2(13, 0), Vector2(5, 7)]), color)
		"sequencer":
			for x in [-8.0, 0.0, 8.0]: draw_circle(Vector2(x, 0), 3, color)
		"duplex":
			draw_line(Vector2(-10, -5), Vector2(10, -5), color, 3.0)
			draw_line(Vector2(-10, 5), Vector2(10, 5), color, 3.0)
		"igniter", "inferno":
			draw_colored_polygon(PackedVector2Array([Vector2(0, -11), Vector2(8, 0), Vector2(4, 10), Vector2(-5, 8), Vector2(-8, 0)]), color)
		"breaker":
			draw_rect(Rect2(-9, -9, 18, 18), color, false, 2.0)
			draw_line(Vector2(-8, 8), Vector2(8, -8), color, 3.0)
		"executioner":
			draw_arc(Vector2.ZERO, 9, 0, TAU, 18, color, 2.0)
			draw_circle(Vector2.ZERO, 3, color)
		"reserve":
			for x in [-6.0, 2.0, 10.0]: draw_rect(Rect2(x - 2, -7, 4, 14), color, true)
		"opening":
			draw_colored_polygon(PackedVector2Array([Vector2(-10, -8), Vector2(11, 0), Vector2(-10, 8)]), color)
		"afterburner":
			draw_line(Vector2(-11, 0), Vector2(7, 0), color, 3.0)
			draw_colored_polygon(PackedVector2Array([Vector2(5, -6), Vector2(12, 0), Vector2(5, 6)]), color)
		"field_press":
			draw_rect(Rect2(-10, -8, 20, 16), color, false, 2.0)
			draw_line(Vector2(-7, 0), Vector2(7, 0), color, 3.0)
		"overbore":
			draw_circle(Vector2.ZERO, 9, Color(color, 0.2))
			draw_arc(Vector2.ZERO, 9, 0, TAU, 18, color, 3.0)
		"arc_splitter":
			draw_line(Vector2(-10, 0), Vector2(0, 0), color, 3.0)
			draw_line(Vector2(0, 0), Vector2(10, -7), color, 3.0)
			draw_line(Vector2(0, 0), Vector2(10, 7), color, 3.0)
		"momentum":
			draw_line(Vector2(-11, 0), Vector2(8, 0), color, 3.0)
			draw_colored_polygon(PackedVector2Array([Vector2(5, -7), Vector2(13, 0), Vector2(5, 7)]), color)
		"triad":
			for x in [-8.0, 0.0, 8.0]: draw_circle(Vector2(x, 0), 3, color)
		_:
			draw_rect(Rect2(-10, -7, 20, 14), color, false, 2.0)
	draw_set_transform(Vector2.ZERO)
