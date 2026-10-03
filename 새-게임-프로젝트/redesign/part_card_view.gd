extends Control
## Icon-first part card shared by shops, rewards, and equipment summaries.
const Content = preload("res://redesign/content.gd")
const FONT = preload("res://redesign/ui_font.tres")

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
var portrait := false
var slot_number := 1

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
	if portrait:
		_draw_portrait(accent)
		return
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
	draw_rect(Rect2(icon_center - Vector2(34, 30), Vector2(68, 60)), Color("14232b"))
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

func _draw_portrait(accent: Color) -> void:
	draw_style_box(_device_frame(accent), Rect2(Vector2(2, 2), size - Vector2(4, 4)))
	draw_string(FONT, Vector2(12, 23), "%02d" % slot_number, HORIZONTAL_ALIGNMENT_LEFT, 30, 13, MUTED)
	if Content.is_core_part(part_id):
		draw_string(FONT, Vector2(size.x - 52, 23), "CORE", HORIZONTAL_ALIGNMENT_LEFT, 45, 12, accent)
	_draw_part_icon(Vector2(size.x * 0.5, 59), accent, 0.9)
	draw_string(FONT, Vector2(8, 104), str(Content.PARTS[part_id].name) if part_id != "none" else "빈 슬롯", HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 16, INK)
	if part_id == "none": return
	draw_string(FONT, Vector2(8, 129), effect_title(), HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 14, MUTED)
	draw_string(FONT, Vector2(8, 153), effect_value(), HORIZONTAL_ALIGNMENT_CENTER, size.x - 16, 18, accent)

func _device_frame(accent: Color) -> StyleBoxFlat:
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color("1b2c34")
	frame.border_color = Color(accent, 0.65)
	frame.set_border_width_all(1)
	frame.border_width_top = 3
	frame.set_corner_radius_all(0)
	return frame

func _draw_mini(accent: Color) -> void:
	if part_id == "none":
		draw_rect(Rect2(Vector2(2, 2), size - Vector2(4, 4)), Color("293d46"), false, 1)
		draw_string(FONT, Vector2(0, size.y * 0.62), "＋", HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color("60747b"))
		return
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

func _draw_part_icon(p: Vector2, accent: Color, scale_factor: float) -> void:
	# Small mechanical silhouettes share the ammunition's square pixel language.
	var patterns := {
		"none": ["............", ".....ss.....", ".....ss.....", "..ssssssss..", "..ssssssss..", ".....ss.....", ".....ss.....", "............"],
		"lens": ["..........ss", ".sssssssssss", "ssHHaaaaHHss", "ssHHaaaaHHss", ".sssssssssss", "..ss....ss..", "..ss....ss..", "............"],
		"loader": ["..ss....ss..", ".sHHssssHHs.", ".sHHaaaaHHs.", ".ssHHHHHHss.", "...ssssss...", "....HHHH....", "...ssssss...", "...aaaaaa..."],
		"supply": ["..ssssssss..", "..sHHHHHHs..", "..saaaaaas..", "..sHHHHHHs..", "..saaaaaas..", "..sHHHHHHs..", "...sHHHHs...", "...ssssss..."],
		"coil": ["..ssssssss..", "..sHHHHHHs..", ".aaHHHHHHaa.", ".ssaaaaaass.", ".aaHHHHHHaa.", ".ssaaaaaass.", "..sHHHHHHs..", "..ssssssss.."],
		"capacitor": ["..ss..ss....", ".sHHssHHs...", ".sHHaaHHs...", ".sHHssHHs...", ".sHHaaHHs...", ".sHHssHHs...", "..ssssss....", "...s..s....."],
		"rammer": ["....ssss....", "..sssHHs....", "ssHHsHHs....", "saaHsHHsssss", "saaHsHHsHHHs", "ssHHsHHsssss", "..sssHHs....", "....ssss...."],
		"sequencer": [".ssssssssss.", ".sHHHHHHHHs.", ".saaHaaHaas.", ".saaHaaHaas.", ".sHHHHHHHHs.", ".ssssssssss.", "..s..s..s...", "............"],
		"duplex": ["...ss..ss...", "..sHHssHHs..", "..sHHaaHHs..", "..sHHssHHs..", "..sHHssHHs..", "..sHHaaHHs..", "..ssssssss..", "...ss..ss..."],
		"igniter": [".....aa.....", "....aaaa....", "..sssHHsss..", "..sHHaaHHs..", "..sHHaaHHs..", "..ssssssss..", "...sHHHHs...", "....ssss...."],
		"breaker": ["....ssss....", "..ssHHHHss..", ".sHHsHHsHHs.", ".sHHaHHaHHs.", ".sHHaaaaHHs.", "..ssHHHHss..", "....ssss....", ".....ss....."],
		"executioner": ["....ssss....", "..ssHHHHss..", ".sHHHaaHHHs.", ".sHaaaaaaHs.", ".sHHHaaHHHs.", "..ssHHHHss..", "...ss..ss...", "...ss..ss..."],
		"reserve": ["..sss..sss..", "..sHs..sHs..", "..sas..sas..", "..sHs..sHs..", ".ssssssssss.", ".sHHHHHHHHs.", ".saaaaaaaa s".replace(" ", ""), ".ssssssssss."],
		"opening": [".aa.........", ".aaaa.......", ".ssHHssssss.", ".saaaHHHHHs.", ".ssHHssssss.", ".ssss.......", ".ss.........", "............"],
		"afterburner": [".........aa.", ".......aaaa.", ".ssssssHHss.", ".sHHHHHaaas.", ".ssssssHHss.", ".......ssss.", ".........ss.", "............"],
		"field_press": [".ssssssssss.", ".sHHHHHHHHs.", ".saaaaaaaa s".replace(" ", ""), ".ss..aa..ss.", ".ss..aa..ss.", ".saaaaaaaa s".replace(" ", ""), ".sHHHHHHHHs.", ".ssssssssss."],
		"overbore": ["....ssss....", "...sHHHHs...", ".sssaaaa sss".replace(" ", ""), ".sHHaaaaHHs.", ".sHHaaaaHHs.", ".sssaaaa sss".replace(" ", ""), "...sHHHHs...", "....ssss...."],
		"inferno": ["..aa....aa..", "..aaaaaa aa.".replace(" ", ""), "...aaaaaa...", "..ssaaaa ss.".replace(" ", ""), ".sHHaaaaHHs.", ".sHHHHHHHHs.", "..ssHHHHss..", "....ssss...."],
		"arc_splitter": [".ss......ss.", ".sHs....sHs.", "..sHa..aHs..", "...sHaaHs...", "...sHaaHs...", "..sHa..aHs..", ".sHs....sHs.", ".ss......ss."],
		"momentum": ["....ssss....", "..ssHHHHss..", ".sHHHaaHHHs.", ".sHHaaaHHHs.", ".sHaaaaaaHs.", "..ssHHHHss..", "....ssss....", ".....ss....."],
		"triad": ["..ss.ss.ss..", "..sH.sH.sH..", "..sa.sa.sa..", "..sH.sH.sH..", ".ssssssssss.", ".sHHHHHHHHs.", ".saaaaaaaa s".replace(" ", ""), ".ssssssssss."],
	}
	var pixels: Array = patterns.get(part_id, patterns.none)
	var unit := maxf(1, floorf(5 * scale_factor))
	var origin := (p - Vector2(12, 8) * unit * 0.5).floor()
	for y in range(pixels.size()):
		var line := str(pixels[y])
		for x in range(line.length()):
			var token := line.substr(x, 1)
			if token == ".": continue
			var color := Color("516b74")
			if token == "H": color = Color("b9c5bc")
			elif token == "a": color = accent
			draw_rect(Rect2(origin + Vector2(x, y) * unit, Vector2.ONE * unit), color)

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
