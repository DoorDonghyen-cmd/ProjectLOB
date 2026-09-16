extends Control
## Compact public ammo language: fixed stat glyphs, signed effect glyph, and numbers.
const Content = preload("res://redesign/content.gd")
const AmmoVisual = preload("res://redesign/ammo_visual.gd")
const FONT = preload("res://assets/fonts/NeoDunggeunmoPro-Regular.ttf")

const INK := Color("e7e4d9")
const MUTED := Color("94a9ae")
const CHIP := Color("12212a")
const POWER := Color("e4bd72")
const PENETRATION := Color("79b6f2")
const ACCURACY := Color("a9dfbf")

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
	var power := str(int(spec.dmg) + int(Content.GUNS[state.gun].bonus))
	if str(spec.effect) == "double": power += "×2"
	var result: Array = [{"kind": "power", "value": power}]
	var axes: Dictionary = Content.axes(state)
	if axes.armor: result.append({"kind": "penetration", "value": str(spec.pen)})
	if axes.accuracy: result.append({"kind": "accuracy", "value": str(int(spec.acc) + (2 if state.part == "lens" else 0))})
	return result

func effect_data() -> Dictionary:
	if state.is_empty(): return {}
	match ammo_id:
		"basic": return {"kind": "reload", "value": "%d발" % (5 if state.get("part", "none") == "supply" else 4)}
		"bore": return {"kind": "crack", "value": "+2"}
		"pierce": return {"kind": "shatter", "value": "소비 · +2×"}
		"precise": return {"kind": "double", "value": "×2"}
		"mark": return {"kind": "accuracy_plus", "value": "+4 · 2발"}
		"charge": return {"kind": "power_plus", "value": "+2 · 2발"}
		"push": return {"kind": "push", "value": "2m"}
		"slow": return {"kind": "slow", "value": "−2m · 1회"}
		"arc": return {"kind": "arc", "value": "1 / 균열 3"}
		"finish": return {"kind": "finish", "value": "HP≤½ · +4"}
	return {}

func _draw() -> void:
	if state.is_empty() or not Content.AMMO.has(ammo_id): return
	var alpha := 0.72 if is_disabled else 1.0
	var ammo_color: Color = AmmoVisual.COLORS[ammo_id]
	ammo_color.a *= alpha
	var ink := INK
	ink.a *= alpha
	AmmoVisual.round_icon(self, Vector2(17, 19), ammo_id, 0.42)
	draw_string(FONT, Vector2(32, 25), "%s ×%d" % [Content.AMMO[ammo_id].name, count], HORIZONTAL_ALIGNMENT_CENTER, size.x - 38, 18, ammo_color)
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
		_draw_icon(str(effect.kind), Vector2(19, 83), ammo_color)
		draw_string(FONT, Vector2(34, 90), str(effect.value), HORIZONTAL_ALIGNMENT_CENTER, size.x - 41, 16, ammo_color)

func _stat_color(kind: String) -> Color:
	match kind:
		"power": return POWER
		"penetration": return PENETRATION
		"accuracy": return ACCURACY
	return MUTED

func _draw_icon(kind: String, center: Vector2, color: Color) -> void:
	var c := center.round()
	match kind:
		"power", "power_plus":
			draw_rect(Rect2(c - Vector2(2, 2), Vector2(5, 5)), color)
			for direction in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
				draw_line(c + direction * 4, c + direction * 7, color, 2.0, false)
		"penetration":
			_draw_shield(c - Vector2(2, 0), color, false)
			draw_line(c + Vector2(-5, 0), c + Vector2(7, 0), color, 2.0, false)
			draw_line(c + Vector2(4, -3), c + Vector2(7, 0), color, 2.0, false)
			draw_line(c + Vector2(4, 3), c + Vector2(7, 0), color, 2.0, false)
		"accuracy", "accuracy_plus":
			draw_arc(c, 5, 0, TAU, 12, color, 2.0, false)
			draw_line(c + Vector2(-8, 0), c + Vector2(-3, 0), color, 2.0, false)
			draw_line(c + Vector2(3, 0), c + Vector2(8, 0), color, 2.0, false)
			draw_line(c + Vector2(0, -8), c + Vector2(0, -3), color, 2.0, false)
			draw_line(c + Vector2(0, 3), c + Vector2(0, 8), color, 2.0, false)
		"crack", "shatter":
			_draw_shield(c, color, true)
			if kind == "shatter":
				draw_line(c + Vector2(6, -6), c + Vector2(9, -9), color, 2.0, false)
				draw_line(c + Vector2(7, 0), c + Vector2(10, 0), color, 2.0, false)
		"double":
			_draw_round_mark(c + Vector2(-3, 2), color)
			_draw_round_mark(c + Vector2(3, -2), color)
		"push":
			draw_line(c + Vector2(-7, 0), c + Vector2(7, 0), color, 2.0, false)
			draw_line(c + Vector2(3, -4), c + Vector2(7, 0), color, 2.0, false)
			draw_line(c + Vector2(3, 4), c + Vector2(7, 0), color, 2.0, false)
		"slow":
			draw_line(c + Vector2(0, -7), c + Vector2(0, 6), color, 2.0, false)
			draw_line(c + Vector2(-4, 2), c + Vector2(0, 6), color, 2.0, false)
			draw_line(c + Vector2(4, 2), c + Vector2(0, 6), color, 2.0, false)
		"arc":
			draw_line(c + Vector2(-7, 0), c, color, 2.0, false)
			draw_line(c, c + Vector2(7, -6), color, 2.0, false)
			draw_line(c, c + Vector2(7, 6), color, 2.0, false)
			draw_rect(Rect2(c + Vector2(5, -8), Vector2(3, 3)), color)
			draw_rect(Rect2(c + Vector2(5, 5), Vector2(3, 3)), color)
		"finish":
			draw_arc(c, 7, 0, TAU, 16, color, 2.0, false)
			draw_rect(Rect2(c + Vector2(-6, -5), Vector2(6, 10)), color)
			draw_line(c + Vector2(0, -7), c + Vector2(0, 7), color, 2.0, false)
		"reload":
			draw_arc(c, 6, -PI * 0.25, PI * 1.55, 12, color, 2.0, false)
			draw_line(c + Vector2(4, -6), c + Vector2(8, -5), color, 2.0, false)
			draw_line(c + Vector2(4, -6), c + Vector2(6, -2), color, 2.0, false)
	if kind.ends_with("_plus"):
		draw_line(c + Vector2(6, -7), c + Vector2(10, -7), color, 2.0, false)
		draw_line(c + Vector2(8, -9), c + Vector2(8, -5), color, 2.0, false)

func _draw_shield(center: Vector2, color: Color, cracked: bool) -> void:
	var points := PackedVector2Array([center + Vector2(-6, -6), center + Vector2(6, -6), center + Vector2(5, 2), center + Vector2(0, 7), center + Vector2(-5, 2), center + Vector2(-6, -6)])
	draw_polyline(points, color, 2.0, false)
	if cracked:
		draw_polyline(PackedVector2Array([center + Vector2(1, -5), center + Vector2(-2, -1), center + Vector2(2, 1), center + Vector2(-1, 6)]), color, 2.0, false)

func _draw_round_mark(center: Vector2, color: Color) -> void:
	draw_rect(Rect2(center + Vector2(-5, -2), Vector2(8, 5)), color)
	draw_colored_polygon(PackedVector2Array([center + Vector2(3, -2), center + Vector2(7, 0), center + Vector2(3, 3)]), color)
