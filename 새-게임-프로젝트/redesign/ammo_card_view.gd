extends Control
## Compact public ammo language: fixed stat glyphs, signed effect glyph, and numbers.
const Content = preload("res://redesign/content.gd")
const AmmoVisual = preload("res://redesign/ammo_visual.gd")
const FONT = preload("res://redesign/ui_font.tres")

const INK := Color("e7e4d9")
const MUTED := Color("94a9ae")
const CHIP := Color("12212a")
const DAMAGE := Color("e4bd72")
const PENETRATION := Color("79b6f2")

var ammo_id := "basic"
var count := 0
var state: Dictionary = {}
var is_disabled := false
var compression_ready := false
var context_text := ""
var context_positive := false
var compact_ui := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()

func setup(id: String, available: int, current_state: Dictionary, disabled: bool = false, can_compress: bool = false, current_context: String = "", positive_context: bool = false) -> void:
	ammo_id = id
	count = available
	state = current_state
	is_disabled = disabled
	compression_ready = can_compress
	context_text = current_context
	context_positive = positive_context
	queue_redraw()

func stat_items() -> Array:
	if state.is_empty() or not Content.AMMO.has(ammo_id): return []
	var spec: Dictionary = Content.AMMO[ammo_id]
	var damage := str(Content.damage(ammo_id, state))
	if str(spec.effect) == "double": damage += "×%d" % Content.hit_count(ammo_id, state)
	var result: Array = [{"kind": "damage", "value": damage}]
	var axes: Dictionary = Content.axes(state)
	if axes.armor: result.append({"kind": "penetration", "value": str(Content.penetration(ammo_id, state))})
	return result

func attribute_data() -> Dictionary:
	if not Content.AMMO.has(ammo_id): return {}
	var attribute := str(Content.AMMO[ammo_id].attribute)
	return {"kind": attribute, "name": AmmoVisual.ATTRIBUTE_NAMES[attribute], "color": AmmoVisual.ATTRIBUTE_COLORS[attribute]}

func effect_data() -> Dictionary:
	if state.is_empty(): return {}
	if ammo_id == "basic": return {"kind": "reload", "value": str(Content.capacity(state))}
	var spec: Dictionary = Content.AMMO[ammo_id]
	match str(spec.effect):
		"burn": return {"kind": "fire", "value": "%d×%d" % [Content.burn_damage(state), Content.burn_amount(ammo_id, state)]}
		"double": return {"kind": "double", "value": "×%d" % Content.hit_count(ammo_id, state)}
		"boost": return {"kind": "boost", "value": "+%d×2" % Content.effect_value(ammo_id, state)}
		"push": return {"kind": "push", "value": "+%dm" % Content.effect_value(ammo_id, state)}
		"arc": return {"kind": "electric", "value": "%d%s" % [Content.effect_value(ammo_id, state), "↗↗" if int(spec.get("arc_targets", 1)) > 1 else "↗"]}
	return {}

func effect_text() -> String:
	var spec: Dictionary = Content.AMMO[ammo_id]
	match str(spec.effect):
		"burn": return "매 턴 %d · %d턴" % [Content.burn_damage(state), Content.burn_amount(ammo_id, state)]
		"boost": return "다음 2발 +%d" % Content.effect_value(ammo_id, state)
		"push": return "%dm 밀치기" % Content.effect_value(ammo_id, state)
		"arc":
			var targets := int(spec.get("arc_targets", 1)) + Content.arc_target_bonus(state)
			return "%s 전이 %d" % ["전체" if targets >= 99 else ("옆 적" if targets == 1 else "%d명" % targets), Content.effect_value(ammo_id, state)]
		"double": return "같은 적 연타"
	if ammo_id == "basic": return "재장전 시 보급"
	return "장갑을 뚫는 탄"

func _draw() -> void:
	if state.is_empty() or not Content.AMMO.has(ammo_id): return
	var alpha := 0.62 if is_disabled else 1.0
	var ink := Color(INK, alpha)
	var ammo_color: Color = AmmoVisual.COLORS[ammo_id]
	var base := Content.source_id(ammo_id)
	if base == "charge" and Content.heat_cost(ammo_id) == 0: ammo_color = Color("edc47a")
	ammo_color.a = alpha
	# One family silhouette and one effect strip. Forecasts belong on the rail.
	draw_rect(Rect2(4, 4, size.x - 8, 3), ammo_color.darkened(0.3))
	var title_width := size.x - 24 - (36 if count > 1 else 0)
	draw_string(FONT, Vector2(12, 29), str(Content.AMMO[ammo_id].name), HORIZONTAL_ALIGNMENT_LEFT, title_width, 20, ink)
	if count > 1: draw_string(FONT, Vector2(size.x - 43, 29), "×%d" % count, HORIZONTAL_ALIGNMENT_RIGHT, 30, 17, MUTED)
	if Content.heat_cost(ammo_id) > 0:
		AmmoVisual.heat_icon(self, Vector2(size.x - 45, 42), 0.7)
		draw_string(FONT, Vector2(size.x - 32, 48), "+%d" % Content.heat_cost(ammo_id), HORIZONTAL_ALIGNMENT_LEFT, 30, 15, Color("ed9167"))
	if size.y < 144:
		AmmoVisual.round_icon(self, Vector2(30, 52), ammo_id, 0.5)
		var short_damage := str(Content.damage(ammo_id, state))
		if str(Content.AMMO[ammo_id].effect) == "double": short_damage += "×%d" % Content.hit_count(ammo_id, state)
		draw_string(FONT, Vector2(57, 60), "피해 " + short_damage, HORIZONTAL_ALIGNMENT_LEFT, 120, 21, Color(DAMAGE, alpha))
		if Content.axes(state).armor and Content.penetration(ammo_id, state) > 0:
			draw_string(FONT, Vector2(174, 60), "관통 %d" % Content.penetration(ammo_id, state), HORIZONTAL_ALIGNMENT_LEFT, size.x - 180, 17, Color(PENETRATION, alpha))
		if Content.is_compressed(ammo_id): _draw_fit(ammo_color)
		draw_rect(Rect2(4, size.y - 30, size.x - 8, 26), CHIP)
		draw_string(FONT, Vector2(10, size.y - 10), effect_text(), HORIZONTAL_ALIGNMENT_CENTER, size.x - 20, 17, ammo_color)
		return
	var art_center := Vector2(40, 78)
	AmmoVisual.round_icon(self, art_center, ammo_id, 1.0)
	if is_disabled: draw_rect(Rect2(14, 36, 56, 78), Color(0.06, 0.09, 0.12, 0.38))
	var damage := str(Content.damage(ammo_id, state))
	if str(Content.AMMO[ammo_id].effect) == "double": damage += "×%d" % Content.hit_count(ammo_id, state)
	draw_string(FONT, Vector2(77, 52), "피해", HORIZONTAL_ALIGNMENT_LEFT, size.x - 86, 14, MUTED)
	draw_string(FONT, Vector2(76, 80), damage, HORIZONTAL_ALIGNMENT_LEFT, size.x - 86, 29, Color(DAMAGE, alpha))
	var penetration := Content.penetration(ammo_id, state)
	if Content.axes(state).armor and penetration > 0:
		draw_string(FONT, Vector2(77, 104), "관통 %d" % penetration, HORIZONTAL_ALIGNMENT_LEFT, size.x - 86, 17, Color(PENETRATION, alpha))
	if Content.is_compressed(ammo_id): _draw_fit(ammo_color)
	if compression_ready: _draw_compression_link()
	var y := size.y - 33
	draw_rect(Rect2(4, y, size.x - 8, 29), CHIP)
	var show_context := not context_text.is_empty() and Content.heat_cost(ammo_id) == 0
	draw_string(FONT, Vector2(10, y + 21), context_text if show_context else effect_text(), HORIZONTAL_ALIGNMENT_CENTER, size.x - 20, 17, MUTED if show_context else ammo_color)

func _draw_compression_link() -> void:
	var cyan := Color("63dce8")
	var faint := cyan
	faint.a = 0.32
	# Cyan corner rails make the whole card read as draggable without adding a
	# badge word. Two linked diamonds are the pair/combine instruction.
	for corner in [
		[Vector2(3, 17), Vector2(3, 4), Vector2(16, 4)],
		[Vector2(size.x - 17, 4), Vector2(size.x - 4, 4), Vector2(size.x - 4, 17)],
		[Vector2(3, size.y - 17), Vector2(3, size.y - 4), Vector2(16, size.y - 4)],
		[Vector2(size.x - 17, size.y - 4), Vector2(size.x - 4, size.y - 4), Vector2(size.x - 4, size.y - 17)],
	]:
		draw_polyline(PackedVector2Array(corner), faint, 2.0, false)
	var left := Vector2(size.x - 20, 18)
	var right := Vector2(size.x - 12, 24)
	_draw_diamond(left, cyan)
	_draw_diamond(right, cyan)
	draw_line(left + Vector2(3, 3), right - Vector2(3, 3), cyan, 2.0, false)

func _draw_diamond(center: Vector2, color: Color) -> void:
	var points := PackedVector2Array([
		center + Vector2(0, -4), center + Vector2(4, 0),
		center + Vector2(0, 4), center + Vector2(-4, 0),
		center + Vector2(0, -4),
	])
	draw_polyline(points, color, 1.5, false)

func _draw_fit(color: Color) -> void:
	var origin := Vector2(size.x - 44, 35)
	for i in range(2):
		var filled := Content.slot_cost(ammo_id) == 2 or (i == 0 and Content.anchor(ammo_id) == "first") or (i == 1 and Content.anchor(ammo_id) == "last")
		draw_rect(Rect2(origin + Vector2(i * 16, 0), Vector2(12, 6)), color if filled else MUTED.darkened(0.65))

func _stat_color(kind: String) -> Color:
	match kind:
		"damage": return DAMAGE
		"penetration": return PENETRATION
	return MUTED

func _draw_icon(kind: String, center: Vector2, color: Color) -> void:
	var c := center.round()
	match kind:
		"damage", "boost":
			draw_rect(Rect2(c - Vector2(2, 2), Vector2(5, 5)), color)
			for direction in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
				draw_line(c + direction * 4, c + direction * 7, color, 2.0, false)
		"penetration":
			_draw_shield(c - Vector2(2, 0), color, false)
			draw_line(c + Vector2(-5, 0), c + Vector2(7, 0), color, 2.0, false)
			draw_line(c + Vector2(4, -3), c + Vector2(7, 0), color, 2.0, false)
			draw_line(c + Vector2(4, 3), c + Vector2(7, 0), color, 2.0, false)
		"double":
			_draw_round_mark(c + Vector2(-3, 2), color)
			_draw_round_mark(c + Vector2(3, -2), color)
		"push":
			draw_line(c + Vector2(-7, 0), c + Vector2(7, 0), color, 2.0, false)
			draw_line(c + Vector2(3, -4), c + Vector2(7, 0), color, 2.0, false)
			draw_line(c + Vector2(3, 4), c + Vector2(7, 0), color, 2.0, false)
		"fire":
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8), c + Vector2(6, 0), c + Vector2(3, 7), c + Vector2(-4, 6), c + Vector2(-6, 0)]), color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -3), c + Vector2(3, 2), c + Vector2(0, 5), c + Vector2(-2, 2)]), CHIP)
		"electric":
			draw_colored_polygon(PackedVector2Array([c + Vector2(1, -9), c + Vector2(-5, 1), c, c + Vector2(-2, 9), c + Vector2(6, -2), c + Vector2(1, -2)]), color)
		"physical":
			draw_rect(Rect2(c + Vector2(-6, -3), Vector2(9, 7)), color)
			draw_colored_polygon(PackedVector2Array([c + Vector2(3, -3), c + Vector2(8, 0), c + Vector2(3, 4)]), color)
		"reload":
			draw_arc(c, 6, -PI * 0.25, PI * 1.55, 12, color, 2.0, false)
			draw_line(c + Vector2(4, -6), c + Vector2(8, -5), color, 2.0, false)
			draw_line(c + Vector2(4, -6), c + Vector2(6, -2), color, 2.0, false)

func _draw_shield(center: Vector2, color: Color, cracked: bool) -> void:
	var points := PackedVector2Array([center + Vector2(-6, -6), center + Vector2(6, -6), center + Vector2(5, 2), center + Vector2(0, 7), center + Vector2(-5, 2), center + Vector2(-6, -6)])
	draw_polyline(points, color, 2.0, false)
	if cracked:
		draw_polyline(PackedVector2Array([center + Vector2(1, -5), center + Vector2(-2, -1), center + Vector2(2, 1), center + Vector2(-1, 6)]), color, 2.0, false)

func _draw_round_mark(center: Vector2, color: Color) -> void:
	draw_rect(Rect2(center + Vector2(-5, -2), Vector2(8, 5)), color)
	draw_colored_polygon(PackedVector2Array([center + Vector2(3, -2), center + Vector2(7, 0), center + Vector2(3, 3)]), color)
