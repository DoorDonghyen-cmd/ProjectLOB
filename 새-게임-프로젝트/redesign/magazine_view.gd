extends Control
const Ammo = preload("res://redesign/ammo_visual.gd")
const FONT = preload("res://assets/fonts/NeoDunggeunmoPro-Regular.ttf")
var stack: Array = []
var incoming := ""
var origin := Vector2.ZERO
var travel := 1.0
var confirmed := false

func _ready() -> void:
	custom_minimum_size.y = 112
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var width := size.x / 4.0
	for i in range(4):
		var x := width * i
		var rect := Rect2(x + 3, 4, width - 7, 91)
		draw_style_box(_box(Color("263f48") if i == 0 else Color("101c24")), rect)
		draw_string(FONT, Vector2(x + 9, 25), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("94acae"))
		if i < stack.size():
			var id: String = stack[stack.size() - 1 - i]
			if i != 0 or incoming.is_empty():
				Ammo.round_icon(self, Vector2(x + width * 0.5, 44), id, 0.8)
			draw_string(FONT, Vector2(x + 4, 82), Ammo.SHORT[id], HORIZONTAL_ALIGNMENT_CENTER, width - 8, 19, Ammo.COLORS[id])
			if id in ["bore", "mark", "charge"] and i + 1 < stack.size():
				var from := Vector2(x + width * 0.5, 106)
				var to := from + Vector2(width, 0)
				draw_line(from, to, Ammo.COLORS[id], 3)
				draw_line(to, to + Vector2(-7, -5), Ammo.COLORS[id], 3)
				draw_line(to, to + Vector2(-7, 5), Ammo.COLORS[id], 3)
		else:
			draw_string(FONT, Vector2(x + 4, 65), "·", HORIZONTAL_ALIGNMENT_CENTER, width - 8, 32, Color("506570"))
	if not incoming.is_empty():
		Ammo.round_icon(self, origin.lerp(Vector2(width * 0.5, 44), travel), incoming, 0.9)

func _box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = Color("5c858d") if confirmed else Color("38505d")
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	return box

func arrive(id: String, global_origin: Vector2, duration: float) -> void:
	incoming = id
	origin = global_origin - global_position
	travel = 0.0
	var tween := create_tween()
	tween.tween_method(func(value: float): travel = value; queue_redraw(), 0.0, 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	incoming = ""
	queue_redraw()

func consume() -> void:
	if not stack.is_empty(): stack.pop_back()
	queue_redraw()
