extends Control
## Wordless combat status: two rounds enter one compression core. The lamp
## shows the run-persistent core count; the cyan circuit shows a pair is available now.
const Ammo = preload("res://redesign/ammo_visual.gd")

var charges := 1
var can_compress_now := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()

func setup(core_count: int, can_use: bool) -> void:
	charges = clampi(core_count, 0, 2)
	can_compress_now = can_use
	queue_redraw()

func _draw() -> void:
	var alpha := 1.0 if charges > 0 else 0.42
	var wire := Color("63dce8") if can_compress_now else Color("728a92")
	wire.a = alpha
	var center := Vector2(size.x * 0.58, size.y * 0.52)
	Ammo.round_icon(self, Vector2(17, size.y * 0.35), "basic", 0.25)
	Ammo.round_icon(self, Vector2(17, size.y * 0.68), "basic", 0.25)
	draw_line(Vector2(28, size.y * 0.35), center - Vector2(11, 4), wire, 2.0)
	draw_line(Vector2(28, size.y * 0.68), center - Vector2(11, -4), wire, 2.0)
	var core := PackedVector2Array([center + Vector2(0, -12), center + Vector2(12, 0), center + Vector2(0, 12), center + Vector2(-12, 0)])
	draw_colored_polygon(core, Color(0.39, 0.86, 0.91, 0.22 if can_compress_now else (0.1 if charges > 0 else 0.04)))
	draw_polyline(PackedVector2Array([core[0], core[1], core[2], core[3], core[0]]), wire, 2.0)
	for i in range(2):
		draw_circle(Vector2(size.x - 11, 9 + i * 13), 4, Color("a9dfbf") if i < charges else Color("3d4f57"))
	if can_compress_now:
		draw_arc(center, 17, 0, TAU, 18, Color("a9dfbf"), 2.0)
