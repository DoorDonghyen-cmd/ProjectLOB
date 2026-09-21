extends Control
signal slot_pressed(index: int)
signal slot_hovered(index: int)
const Ammo = preload("res://redesign/ammo_visual.gd")
const Content = preload("res://redesign/content.gd")
const FONT = preload("res://assets/fonts/NeoDunggeunmoPro-Regular.ttf")
const Forecast = preload("res://redesign/forecast.gd")
var stack: Array = []
var incoming := ""
var incoming_index := -1
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

func layout() -> Array:
	var result: Array = []
	var cursor := 0
	for i in range(stack.size()):
		var id := str(stack[i])
		var cost := Content.slot_cost(id)
		result.append({"index": i, "id": id, "start": cursor, "cost": cost})
		cursor += cost
	return result

func _entry_at_physical(physical_index: int) -> int:
	for entry in layout():
		if physical_index >= int(entry.start) and physical_index < int(entry.start) + int(entry.cost): return int(entry.index)
	return -1

func _gui_input(event: InputEvent) -> void:
	if capacity <= 0: return
	var physical_index := -1
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		physical_index = int(event.position.x / (size.x / capacity))
	var index := _entry_at_physical(physical_index)
	if interactive and event is InputEventMouseMotion and index >= 0: slot_hovered.emit(index)
	if interactive and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if index >= 0: slot_pressed.emit(index)
		accept_event()

func _draw() -> void:
	if capacity <= 0: return
	var width := size.x / float(capacity)
	for i in range(capacity):
		var x := width * i
		var rect := Rect2(x + 3, 4, width - 7, 140)
		draw_style_box(_box(Color("263f48") if i == 0 else Color("101c24")), rect)
		draw_string(FONT, Vector2(x + 9, 25), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("94acae"))
		draw_string(FONT, Vector2(x + 4, 65), "·", HORIZONTAL_ALIGNMENT_CENTER, width - 8, 32, Color("506570"))

	var entries := layout()
	for entry in entries:
		var logical := int(entry.index)
		var start := int(entry.start)
		var cost := int(entry.cost)
		var id := str(entry.id)
		var x := width * start
		var card_width := width * cost
		var rect := Rect2(x + 3, 4, card_width - 7, 140)
		draw_style_box(_box(Color("172731")), rect)
		if Content.is_compressed(id):
			draw_rect(rect.grow(-2), Color(0.66, 0.87, 0.75, 0.12), true)
			draw_rect(rect.grow(-2), Ammo.COLORS[id], false, 2.0)
			_draw_fit_edges(rect, id)
		if not forecast.is_empty() and Forecast.is_combo_link(forecast, logical): draw_rect(rect.grow(-3), Color("a9dfbf"), false, 2)
		if logical == selected_index: draw_rect(rect, Color("a9dfbf"), false, 2)
		if changed_slots.has(logical) and highlight > 0: draw_rect(rect, Color(0.66, 0.87, 0.75, highlight * 0.2))
		if logical > 0:
			var arrow_color := Color("a9dfbf") if Forecast.is_combo_link(forecast, logical) else Color("6f8790")
			draw_rect(Rect2(x - 6, 13, 15, 19), Color("101920"))
			draw_string(FONT, Vector2(x - 5, 29), "›", HORIZONTAL_ALIGNMENT_CENTER, 13, 18, arrow_color)
		if logical != incoming_index or incoming.is_empty(): Ammo.round_icon(self, Vector2(x + card_width * 0.5, 44), id, 0.8)
		draw_string(FONT, Vector2(x + 4, 82), Ammo.SHORT[id], HORIZONTAL_ALIGNMENT_CENTER, card_width - 8, 19, Ammo.COLORS[id])
		_draw_forecast(entry, x, card_width)

	if not incoming.is_empty():
		var target := Vector2(width * 0.5, 44)
		for entry in entries:
			if int(entry.index) == incoming_index:
				target = Vector2(width * int(entry.start) + width * int(entry.cost) * 0.5, 44)
				break
		Ammo.round_icon(self, origin.lerp(target, travel), incoming, 0.9)

func _draw_fit_edges(rect: Rect2, id: String) -> void:
	var color: Color = Ammo.COLORS[id]
	if Content.slot_cost(id) > 1:
		var seam_x := rect.position.x + rect.size.x * 0.5
		var seam := color
		seam.a = 0.4
		draw_line(Vector2(seam_x, rect.position.y + 8), Vector2(seam_x, rect.end.y - 8), seam, 2.0)
	match Content.anchor(id):
		"first":
			draw_colored_polygon(PackedVector2Array([rect.position + Vector2(-7, 18), rect.position + Vector2(1, 11), rect.position + Vector2(1, 25)]), color)
		"last":
			draw_line(Vector2(rect.end.x - 2, rect.position.y + 8), Vector2(rect.end.x - 2, rect.end.y - 8), color, 4.0)

func _draw_forecast(entry: Dictionary, x: float, card_width: float) -> void:
	if forecast.is_empty(): return
	var logical := int(entry.index)
	var id := str(entry.id)
	var value := "중단" if forecast.phase == "lost" else "보존"
	var color := Color("899ea6")
	if logical < forecast.shots.size():
		var shot: Dictionary = forecast.shots[logical]
		value = "%s %s" % [Forecast.tag(shot.target), Forecast.outcome(shot)]
		if shot.get("random", false): value = "무작위 " + Forecast.outcome(shot)
		color = Color("a9dfbf") if shot.damage > 0 else Color("f2a38d")
	if card_width < 115 and logical < forecast.shots.size():
		var lines := compact_lines(forecast, logical)
		draw_string(FONT, Vector2(x + 4, 101), lines[0], HORIZONTAL_ALIGNMENT_CENTER, card_width - 8, 15, color)
		draw_string(FONT, Vector2(x + 4, 119), lines[1], HORIZONTAL_ALIGNMENT_CENTER, card_width - 8, 14, color)
	else:
		draw_string(FONT, Vector2(x + 4, 111), value, HORIZONTAL_ALIGNMENT_CENTER, card_width - 8, 17, color)
	if logical < forecast.shots.size():
		var note := Forecast.note(forecast, logical)
		if card_width < 115 or FONT.get_string_size(note, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x > card_width - 8: note = compact_lines(forecast, logical)[2]
		draw_string(FONT, Vector2(x + 4, 136), note, HORIZONTAL_ALIGNMENT_CENTER, card_width - 8, 14, Ammo.COLORS[id])

static func compact_lines(prediction: Dictionary, index: int) -> PackedStringArray:
	var shot: Dictionary = prediction.shots[index]
	if shot.get("random", false): return PackedStringArray(["무작위", "%d~%d" % [shot.damage_min, shot.damage_max], "증폭" if shot.get("boosted", false) else "분산"])
	var result := PackedStringArray(["%s −%d" % [Forecast.tag(shot.target), shot.damage], "처치" if int(shot.hp) == 0 else "HP%d" % int(shot.hp), ""])
	var boosted: bool = int(shot.get("math", {}).get("boost", 0)) > 0
	var secondary: Array = shot.get("secondary", [])
	if not secondary.is_empty():
		var spread := secondary.filter(func(value): return value.get("kind", "arc") == "spread")
		if spread.size() > 0 and spread.size() < secondary.size(): result[2] = "확산·전이"
		elif spread.size() > 1: result[2] = "확산%d명" % spread.size()
		elif spread.size() == 1: result[2] = "%s 확산−%d" % [Forecast.tag(int(spread[0].target)), int(spread[0].damage)]
		elif secondary.size() > 1: result[2] = "전이%d명" % secondary.size()
		else: result[2] = "→%s −%d" % [Forecast.tag(int(secondary[0].target)), int(secondary[0].damage)]
	elif int(shot.get("math", {}).get("overflow", 0)) > 0: result[2] = "관통+%d" % int(shot.math.overflow)
	elif int(shot.get("burn_added", 0)) > 0:
		var ticks := Forecast.burn_ticks_for_shot(prediction, index)
		result[2] = "화상%d회" % ticks if ticks > 0 else "화상+%d" % int(shot.burn_added)
	elif int(shot.get("push", 0)) > 0: result[2] = "+%dm" % int(shot.push)
	elif int(shot.get("focus_damage", 0)) > 0: result[2] = "집중+%d" % shot.focus_damage
	elif boosted: result[2] = "증폭+%d" % int(shot.math.boost)
	elif int(shot.get("hits", 1)) > 1: result[2] = "×%d" % int(shot.hits)
	elif Content.AMMO.has(str(shot.id)) and str(Content.AMMO[str(shot.id)].effect) == "boost": result[2] = "→2발+%d" % int(shot.get("boost_granted", 2))
	return result

func _box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = Color("5c858d") if confirmed else Color("38505d")
	box.set_border_width_all(1)
	box.set_corner_radius_all(5)
	return box

func arrive(id: String, global_origin: Vector2, duration: float, index: int = -1) -> void:
	incoming = id
	incoming_index = stack.size() - 1 if index < 0 else index
	origin = global_origin - global_position
	travel = 0.0
	var tween := create_tween()
	tween.tween_method(func(value: float): travel = value; queue_redraw(), 0.0, 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	incoming = ""
	incoming_index = -1
	queue_redraw()

func consume() -> void:
	if not stack.is_empty(): stack.pop_front()
	forecast = {}
	queue_redraw()
