extends Control
## Compact public ammo language: fixed stat glyphs, signed effect glyph, and numbers.
const Content = preload("res://redesign/content.gd")
const AmmoVisual = preload("res://redesign/ammo_visual.gd")
const FONT = preload("res://assets/fonts/NeoDunggeunmoPro-Regular.ttf")

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

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()

func setup(id: String, available: int, current_state: Dictionary, disabled: bool = false, can_compress: bool = false) -> void:
	ammo_id = id
	count = available
	state = current_state
	is_disabled = disabled
	compression_ready = can_compress
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

func _draw() -> void:
	if state.is_empty() or not Content.AMMO.has(ammo_id): return
	var alpha := 0.72 if is_disabled else 1.0
	var ammo_color: Color = AmmoVisual.COLORS[ammo_id]
	ammo_color.a *= alpha
	var ink := INK
	ink.a *= alpha
	AmmoVisual.round_icon(self, Vector2(17, 19), ammo_id, 0.42)
	if Content.is_compressed(ammo_id): _draw_fit(ammo_color)
	if compression_ready: _draw_compression_link()
	var attribute := attribute_data()
	var attribute_color: Color = attribute.color
	attribute_color.a *= alpha
	var title := str(Content.AMMO[ammo_id].name)
	if count > 1: title += " ×%d" % count
	draw_string(FONT, Vector2(32, 25), title, HORIZONTAL_ALIGNMENT_CENTER, size.x - 105, 18, ammo_color)
	_draw_icon(str(attribute.kind), Vector2(size.x - 62, 18), attribute_color)
	var stats := stat_items()
	if not stats.is_empty():
		var slot_width := size.x / float(stats.size())
		for i in range(stats.size()):
			var item: Dictionary = stats[i]
			var center := Vector2(slot_width * (i + 0.5), 51)
			var color := _stat_color(str(item.kind))
			color.a *= alpha
			_draw_icon(str(item.kind), center - Vector2(13, 0), color)
			draw_string(FONT, center + Vector2(-3, 6), str(item.value), HORIZONTAL_ALIGNMENT_LEFT, slot_width * 0.48, 17, color)
	var effect := effect_data()
	if not effect.is_empty():
		var chip_color := CHIP
		chip_color.a *= 0.84 if is_disabled else 1.0
		draw_rect(Rect2(5, 69, size.x - 10, 29), chip_color)
		_draw_icon(str(effect.kind), Vector2(19, 83), attribute_color)
		draw_string(FONT, Vector2(34, 90), str(effect.value), HORIZONTAL_ALIGNMENT_CENTER, size.x - 41, 16, attribute_color)

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
	var rule := Content.anchor(ammo_id)
	var cost := Content.slot_cost(ammo_id)
	var origin := Vector2(size.x - 48, 32)
	var fill := color
	fill.a = 0.18
	for i in range(2): draw_rect(Rect2(origin + Vector2(i * 18, 0), Vector2(16, 10)), MUTED, false, 1.0)
	if cost == 2:
		draw_rect(Rect2(origin, Vector2(34, 10)), fill, true)
		draw_rect(Rect2(origin, Vector2(34, 10)), color, false, 2.0)
	elif rule == "first":
		draw_rect(Rect2(origin, Vector2(16, 10)), fill, true)
		draw_colored_polygon(PackedVector2Array([origin + Vector2(-5, 5), origin + Vector2(0, 1), origin + Vector2(0, 9)]), color)
	elif rule == "last":
		draw_rect(Rect2(origin + Vector2(18, 0), Vector2(16, 10)), fill, true)
		draw_line(origin + Vector2(35, 0), origin + Vector2(35, 10), color, 3.0)

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
