extends Control
signal slot_pressed(index: int)
signal slot_hovered(index: int)
const Ammo = preload("res://redesign/ammo_visual.gd")
const FONT = preload("res://assets/fonts/NeoDunggeunmoPro-Regular.ttf")
const Forecast = preload("res://redesign/forecast.gd")
var stack: Array = []
var incoming := ""
var origin := Vector2.ZERO
var travel := 1.0
var confirmed := false
var forecast: Dictionary = {}
var capacity := 4
var interactive := false
var selected_index := 0
var changed_slots: Array = []
var highlight := 1.0

func _ready() -> void:
	custom_minimum_size.y = 154
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	if not changed_slots.is_empty():
		create_tween().tween_method(func(value: float): highlight = value; queue_redraw(), 1.0, 0.0, 0.6)

func _gui_input(event: InputEvent) -> void:
	if interactive and event is InputEventMouseMotion:
		var index := int(event.position.x / (size.x / capacity))
		if index >= 0 and index < stack.size(): slot_hovered.emit(index)
	if interactive and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var index := int(event.position.x / (size.x / capacity))
		if index >= 0 and index < stack.size(): slot_pressed.emit(index)
		accept_event()

func _draw() -> void:
	var width := size.x / float(capacity)
	for i in range(capacity):
		var x := width * i
		var rect := Rect2(x + 3, 4, width - 7, 140)
		draw_style_box(_box(Color("263f48") if i == 0 else Color("101c24")), rect)
		if not forecast.is_empty() and Forecast.is_combo_link(forecast, i):
			draw_rect(rect.grow(-2), Color("a9dfbf"), false, 2)
		if i == selected_index and i < stack.size(): draw_rect(rect, Color("a9dfbf"), false, 2)
		if changed_slots.has(i) and highlight > 0: draw_rect(rect, Color(0.66, 0.87, 0.75, highlight * 0.2))
		draw_string(FONT, Vector2(x + 9, 25), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("94acae"))
		if i > 0 and i < stack.size():
			var arrow_color := Color("a9dfbf") if Forecast.is_combo_link(forecast, i) else Color("6f8790")
			draw_rect(Rect2(x - 6, 13, 15, 19), Color("101920"))
			draw_string(FONT, Vector2(x - 5, 29), "›", HORIZONTAL_ALIGNMENT_CENTER, 13, 18, arrow_color)
		if i < stack.size():
			var id: String = stack[i]
			if i != stack.size() - 1 or incoming.is_empty():
				Ammo.round_icon(self, Vector2(x + width * 0.5, 44), id, 0.8)
			draw_string(FONT, Vector2(x + 4, 82), Ammo.SHORT[id], HORIZONTAL_ALIGNMENT_CENTER, width - 8, 19, Ammo.COLORS[id])
			if not forecast.is_empty():
				var value := "중단" if forecast.phase == "lost" else "보존"
				var color := Color("899ea6")
				if i < forecast.shots.size():
					var shot: Dictionary = forecast.shots[i]
					value = "%s %s" % [Forecast.tag(shot.target), Forecast.outcome(shot)]
					color = Color("a9dfbf") if shot.damage > 0 else Color("f2a38d")
				if width < 115 and i < forecast.shots.size():
					var lines := compact_lines(forecast, i)
					draw_string(FONT, Vector2(x + 4, 101), lines[0], HORIZONTAL_ALIGNMENT_CENTER, width - 8, 15, color)
					draw_string(FONT, Vector2(x + 4, 119), lines[1], HORIZONTAL_ALIGNMENT_CENTER, width - 8, 14, color)
				else:
					draw_string(FONT, Vector2(x + 4, 111), value, HORIZONTAL_ALIGNMENT_CENTER, width - 8, 17, color)
			if not forecast.is_empty() and i < forecast.shots.size():
				var note := Forecast.note(forecast, i)
				if width < 115 or FONT.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x > width - 8: note = compact_lines(forecast, i)[2]
				draw_string(FONT, Vector2(x + 4, 136), note, HORIZONTAL_ALIGNMENT_CENTER, width - 8, 14, Ammo.COLORS[id])
		else:
			draw_string(FONT, Vector2(x + 4, 65), "·", HORIZONTAL_ALIGNMENT_CENTER, width - 8, 32, Color("506570"))
	if not incoming.is_empty():
		Ammo.round_icon(self, origin.lerp(Vector2(width * (stack.size() - 0.5), 44), travel), incoming, 0.9)

static func compact_lines(prediction: Dictionary, index: int) -> PackedStringArray:
	var shot: Dictionary = prediction.shots[index]
	var result := PackedStringArray(["%s −%d" % [Forecast.tag(shot.target), shot.damage], "처치" if int(shot.hp) == 0 else "HP%d" % int(shot.hp), ""])
	var boosted: bool = int(shot.get("math", {}).get("boost", 0)) > 0
	var secondary: Array = shot.get("secondary", [])
	if not secondary.is_empty():
		var spread := secondary.filter(func(value): return value.get("kind", "arc") == "spread")
		if spread.size() > 0 and spread.size() < secondary.size(): result[2] = "확산·전이"
		elif spread.size() > 1: result[2] = "확산%d명" % spread.size()
		elif spread.size() == 1: result[2] = "%s 확산−%d" % [Forecast.tag(int(spread[0].target)), int(spread[0].damage)]
		else: result[2] = "→%s −%d" % [Forecast.tag(int(secondary[0].target)), int(secondary[0].damage)]
	elif int(shot.get("math", {}).get("overflow", 0)) > 0: result[2] = "관통+%d" % int(shot.math.overflow)
	elif int(shot.get("burn_added", 0)) > 0:
		var ticks := Forecast.burn_ticks_for_shot(prediction, index)
		result[2] = "화상%d회" % ticks if ticks > 0 else "화상+%d" % int(shot.burn_added)
	elif int(shot.get("push", 0)) > 0: result[2] = "+%dm" % int(shot.push)
	elif boosted: result[2] = "증폭×2" if int(shot.get("hits", 1)) > 1 else "증폭+2"
	elif int(shot.get("hits", 1)) > 1: result[2] = "×2"
	elif str(shot.id) == "charge": result[2] = "→2발+2"
	return result

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
	if not stack.is_empty(): stack.pop_front()
	forecast = {}
	queue_redraw()
