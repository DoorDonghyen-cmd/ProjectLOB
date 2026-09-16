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

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()

func setup(id: String, available: int, current_state: Dictionary, disabled: bool = false) -> void:
	ammo_id = id
	count = available
	state = current_state
	is_disabled = disabled
	queue_redraw()

func stat_items() -> Array:
	if state.is_empty() or not Content.AMMO.has(ammo_id): return []
	var spec: Dictionary = Content.AMMO[ammo_id]
	var damage := str(Content.damage(ammo_id, state))
	if str(spec.effect) == "double": damage += "×2"
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
	match ammo_id:
		"basic": return {"kind": "reload", "value": "%d발" % Content.capacity(state)}
		"pierce": return {"kind": "physical", "value": "장갑 대응"}
		"bore": return {"kind": "fire", "value": "%d피해 · %d턴" % [Content.burn_damage(state), Content.burn_amount(ammo_id, state)]}
		"precise": return {"kind": "double", "value": "2회 타격"}
		"charge": return {"kind": "boost", "value": "+%d · 다음 2발" % Content.effect_value(ammo_id, state)}
		"push": return {"kind": "push", "value": "%dm" % Content.effect_value(ammo_id, state)}
		"arc": return {"kind": "electric", "value": "전이 %d" % Content.effect_value(ammo_id, state)}
	return {}

func _draw() -> void:
	if state.is_empty() or not Content.AMMO.has(ammo_id): return
	var alpha := 0.72 if is_disabled else 1.0
	var ammo_color: Color = AmmoVisual.COLORS[ammo_id]
	ammo_color.a *= alpha
	var ink := INK
	ink.a *= alpha
	AmmoVisual.round_icon(self, Vector2(17, 19), ammo_id, 0.42)
	var attribute := attribute_data()
	var attribute_color: Color = attribute.color
	attribute_color.a *= alpha
	draw_string(FONT, Vector2(32, 25), "%s ×%d" % [Content.AMMO[ammo_id].name, count], HORIZONTAL_ALIGNMENT_CENTER, size.x - 105, 18, ammo_color)
	_draw_icon(str(attribute.kind), Vector2(size.x - 62, 18), attribute_color)
	draw_string(FONT, Vector2(size.x - 51, 24), str(attribute.name), HORIZONTAL_ALIGNMENT_CENTER, 48, 13, attribute_color)
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
