extends Control
signal slot_pressed(index: int)
signal slot_hovered(index: int)
signal slot_moved(from: int, to: int)
const Ammo = preload("res://redesign/ammo_visual.gd")
const Content = preload("res://redesign/content.gd")
const FONT = preload("res://redesign/ui_font.tres")
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
var compact_ui := false
var fired_count := 0
var impact_active := false
var live_boost_slots: Array = []
var live_boost_value := 0
var next_shot_count := -1
var pressed_slot := -1
var pressed_position := Vector2.ZERO
var drag_target := -1
var dragging := false

func _ready() -> void:
	custom_minimum_size.y = 82
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	if capacity <= 0 or not interactive: return
	var physical_index := -1
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		physical_index = int(event.position.x / (size.x / capacity))
	var index := _entry_at_physical(physical_index)
	if event is InputEventMouseMotion:
		if index >= 0: slot_hovered.emit(index)
		if pressed_slot >= 0 and not confirmed:
			dragging = dragging or event.position.distance_to(pressed_position) >= 12.0
			drag_target = index if dragging and _can_move(pressed_slot, index) else -1
			queue_redraw()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pressed_slot = index
			pressed_position = event.position
			dragging = false
			if index >= 0: slot_pressed.emit(index)
		else:
			var from := pressed_slot
			var move := dragging and not confirmed and Rect2(Vector2.ZERO, size).has_point(event.position) and _can_move(from, index)
			pressed_slot = -1
			drag_target = -1
			dragging = false
			if move: slot_moved.emit(from, index)
			queue_redraw()
		accept_event()

func _draw() -> void:
	if capacity <= 0: return
	var width := size.x / float(capacity)
	for i in range(capacity):
		var rect := Rect2(roundf(width * i) + 3, 3, floorf(width) - 7, size.y - 6)
		draw_style_box(_box(Color("15242d")), rect)
		draw_string(FONT, rect.position + Vector2(9, 23), "%02d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, 32, 17, Color("718790"))
		draw_rect(Rect2(rect.get_center() - Vector2(9, 1), Vector2(18, 2)), Color("3c5360"))
		if i < capacity - 1:
			draw_string(FONT, Vector2(width * (i + 1) - 4, 48), "›", HORIZONTAL_ALIGNMENT_CENTER, 10, 18, Color("647d89"))
	for entry in layout():
		var logical := int(entry.index)
		var id := str(entry.id)
		var x := width * int(entry.start)
		var card_width := width * int(entry.cost)
		var rect := Rect2(x + 3, 3, card_width - 7, size.y - 6)
		draw_style_box(_box(Color("1b303a")), rect)
		if Content.is_compressed(id): _draw_fit_edges(rect, id)
		if not forecast.is_empty() and Forecast.is_combo_link(forecast, logical):
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), Color("edc47a"))
		if logical == selected_index: draw_rect(rect.grow(-1), Color("edc47a"), false, 2)
		if logical == drag_target: draw_rect(rect.grow(-3), Color("c0d5ce"), false, 3)
		if changed_slots.has(logical) and highlight > 0: draw_rect(rect, Color(0.93, 0.77, 0.48, highlight * 0.12))
		if logical != incoming_index or incoming.is_empty(): Ammo.round_icon(self, Vector2(x + 25, 40), id, 0.5)
		draw_string(FONT, Vector2(x + 48, 28), Ammo.SHORT[id], HORIZONTAL_ALIGNMENT_LEFT, card_width - 55, 18, Ammo.COLORS[id])
		_draw_forecast(entry, x, card_width)
		if next_shot_count >= 0 and logical >= next_shot_count:
			draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(rect.size.x - 2, 3)), Color("718790"))
		if logical < fired_count:
			draw_rect(rect, Color(0.025, 0.045, 0.055, 0.80))
			draw_string(FONT, Vector2(x + 4, 48), "발사", HORIZONTAL_ALIGNMENT_CENTER, card_width - 8, 18, Color("799187"))
		if impact_active and logical == fired_count - 1:
			draw_rect(rect.grow(-1), Color("edc47a"), false, 3)
		if live_boost_slots.has(logical) and logical >= fired_count:
			var color := Color("ed9167") if live_boost_value >= 4 else Color("edc47a")
			draw_rect(rect.grow(-2), color, false, 3)
			draw_string(FONT, Vector2(x + 8, 70), "+%d" % live_boost_value, HORIZONTAL_ALIGNMENT_CENTER, card_width - 16, 22, color)
	if not incoming.is_empty():
		var destination := Vector2(width * 0.5, 40)
		for entry in layout():
			if int(entry.index) == incoming_index:
				destination = Vector2(width * int(entry.start) + 25, 40)
				break
		Ammo.round_icon(self, origin.lerp(destination, travel), incoming, 0.6)

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
	var value := "중단" if forecast.phase == "lost" else "보존"
	var note := ""
	var color := Color("899ea6")
	if logical < forecast.shots.size():
		var shot: Dictionary = forecast.shots[logical]
		value = "무작위" if shot.get("random", false) else "%s −%d" % [Forecast.tag(shot.target), shot.damage]
		if shot.get("intercept", false): value = "요격"
		elif float(shot.get("intercept_probability", 0)) >= 0.999999: value = "확정 요격"
		elif not shot.get("random", false) and int(shot.hp) == 0: value += " 처치"
		if next_shot_count >= 0 and logical >= next_shot_count:
			value = "%d회째 · %s" % [int(shot.get("action", 0)) + 1, value]
		note = compact_lines(forecast, logical)[2]
		if shot.get("random", false): note = "%d~%d 피해" % [shot.damage_min, shot.damage_max]
		color = Color("edc47a") if bool(shot.get("boosted", false)) else Color("c0d5ce")
	draw_string(FONT, Vector2(x + 48, 50), value, HORIZONTAL_ALIGNMENT_LEFT, card_width - 55, 15, color)
	if not note.is_empty(): draw_string(FONT, Vector2(x + 8, 72), note, HORIZONTAL_ALIGNMENT_CENTER, card_width - 16, 14, Color("edc47a"))

func _can_move(from: int, to: int) -> bool:
	if from < 0 or from >= stack.size() or to < 0 or to >= stack.size() or from == to: return false
	var proposed := stack.duplicate()
	var id: String = str(proposed.pop_at(from))
	proposed.insert(to, id)
	return Content.valid_stack(proposed, capacity)

static func compact_lines(prediction: Dictionary, index: int) -> PackedStringArray:
	var shot: Dictionary = prediction.shots[index]
	if float(shot.get("intercept_probability", 0)) >= 0.999999: return PackedStringArray(["확정 요격", "압력탄 제거", "증폭" if shot.get("boosted", false) else ""])
	if shot.get("random", false): return PackedStringArray(["무작위", "%d~%d" % [shot.damage_min, shot.damage_max], "증폭" if shot.get("boosted", false) else "분산"])
	var result := PackedStringArray(["%s −%d" % [Forecast.tag(shot.target), shot.damage], "처치" if int(shot.hp) == 0 else "HP%d" % int(shot.hp), ""])
	if shot.get("intercept", false):
		result[0] = "요격"
		result[1] = "압력탄 제거"
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
	box.set_corner_radius_all(0)
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
	impact_active = false
	fired_count = mini(stack.size(), fired_count + 1)
	forecast = {}
	queue_redraw()
