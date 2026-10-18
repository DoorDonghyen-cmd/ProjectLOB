extends Control
signal slot_pressed(index: int)
signal slot_hovered(index: int)
signal slot_moved(from: int, to: int)
const Ammo = preload("res://redesign/ammo_visual.gd")
const Content = preload("res://redesign/content.gd")
const Hardware = preload("res://redesign/instrument_skin.gd")
const FONT = preload("res://redesign/combat_pixel_font.tres")
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
var shot_response := 0.0
var reduced_motion := false
var response_tween: Tween
var live_boost_slots: Array = []
var live_boost_value := 0
var live_boost_factor := 1
var live_boost_labels: Dictionary = {}
var next_shot_count := -1
var pressed_slot := -1
var pressed_position := Vector2.ZERO
var drag_target := -1
var dragging := false
var candidate_id := ""

func show_pending_boost(pending: Dictionary) -> void:
	live_boost_slots = []
	live_boost_labels = {}
	var buff := pending.duplicate(true)
	for i in range(fired_count, stack.size()):
		if buff.is_empty(): break
		if not Content.is_attack(str(stack[i])): continue
		live_boost_slots.append(i)
		var amount := int(buff.get("dmg", 0))
		var factor := int(buff.get("factor", 1))
		var conditional: bool = preload("res://redesign/attack_boosts.gd").layers(buff).any(func(v): return bool(v.get("hot",false)))
		live_boost_labels[i] = ("+%d%s " % [amount,"?" if conditional else ""] if amount > 0 else "") + ("×%d" % factor if factor > 1 else "")
		buff = preload("res://redesign/attack_boosts.gd").consume(buff)
	queue_redraw()

func preview_insertion(id: String) -> void:
	candidate_id = id if interactive and not confirmed and not id.is_empty() and Content.can_insert(stack, id, capacity) else ""
	queue_redraw()

func insertion_preview_rect() -> Rect2:
	if candidate_id.is_empty(): return Rect2()
	var physical := 0
	for i in range(Content.insertion_index(stack, candidate_id)):
		physical += Content.slot_cost(str(stack[i]))
	var width := size.x / float(maxi(1, capacity))
	return Rect2(roundf(width * physical) + 3, 3, floorf(width * Content.slot_cost(candidate_id)) - 7, size.y - 6)

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
	# One mechanical bed ties every chamber to the same feed rail.
	draw_rect(Rect2(0,0,size.x,size.y),Color("1b2c32"))
	draw_rect(Rect2(0,size.y-4,size.x,3),Color("475b57"))
	for i in range(capacity):
		var rect := Rect2(roundf(width * i) + 3, 3, floorf(width) - 7, size.y - 6)
		Hardware.plate(self,rect,Color("25373d"),Color("526a66"))
		draw_rect(rect.grow(-6),Color("15262d"))
		draw_rect(Rect2(rect.position+Vector2(7,7),Vector2(3,rect.size.y-17)),Color("0c1a21"))
		draw_string(FONT,rect.position+Vector2(10,24),"%02d" % (i+1),HORIZONTAL_ALIGNMENT_LEFT,32,17,Color("738b89"))
		var socket:=Rect2(rect.get_center()-Vector2(14,10),Vector2(28,24))
		draw_rect(socket,Color("1c3038"))
		draw_rect(Rect2(socket.position+Vector2(5,10),Vector2(18,3)),Color("435a5e"))
		for side in [rect.position.x+9,rect.end.x-15]:
			draw_rect(Rect2(side,rect.end.y-9,6,3),Color("53675e"))
		if i<capacity-1: Hardware.arrow(self,Vector2(roundf(width*(i+1))-3,36),Color("788c7a"))
	for entry in layout():
		var logical := int(entry.index)
		var id := str(entry.id)
		var x := width * int(entry.start)
		var card_width := width * int(entry.cost)
		var rect := Rect2(x + 3, 3, card_width - 7, size.y - 6)
		Hardware.plate(self,rect,Color("3b4a43") if logical==selected_index else Color("2e3e41"),Color("adbaa0") if logical==selected_index else Color("6b8074"))
		draw_rect(Rect2(x+10,14,29,51),Color("182a2e"))
		draw_rect(Rect2(x+10,14,3,51),Color("101e24"))
		draw_rect(Rect2(x+13,65,23,2),Color("61776c"))
		var planned_shots: Array=forecast.get("shots",[])
		var hot_slot: bool=logical<planned_shots.size() and (planned_shots[logical].get("overheated",false) or float(planned_shots[logical].get("overheat_probability",0))>0)
		if not hot_slot: draw_string(FONT,Vector2(rect.end.x-25,22),"%02d"%(int(entry.start)+1),HORIZONTAL_ALIGNMENT_RIGHT,18,13,Color("91a38e"))
		if logical==selected_index:
			for edge_x in [rect.position.x+3,rect.end.x-6]:
				draw_rect(Rect2(edge_x,rect.position.y+9,3,18),Color("adbaa0"))
		if logical==fired_count:
			draw_rect(Rect2(rect.position.x+8,rect.end.y-5,22,3),Color("bcaa7f"))
		if Content.is_compressed(id): _draw_fit_edges(rect, id)
		if not forecast.is_empty() and Forecast.is_combo_link(forecast, logical):
			draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), Color("edc47a"))
		if logical == selected_index: draw_rect(Rect2(rect.position + Vector2(8,0),Vector2(24,3)), Color("b8d4bf"))
		if logical == drag_target: draw_rect(rect.grow(-3), Color("c0d5ce"), false, 3)
		if changed_slots.has(logical) and highlight > 0: draw_rect(rect, Color(0.93, 0.77, 0.48, highlight * 0.12))
		if logical != incoming_index or incoming.is_empty(): preload("res://redesign/ammo_art.gd").draw(self,id,Rect2(x+14,15,22,50))
		draw_string(FONT, Vector2(x + 48, 28), Ammo.SHORT[id], HORIZONTAL_ALIGNMENT_LEFT, card_width - 83, 20, Color("d3d5be"))
		Ammo.grade_mark(self, Vector2(x + 48, 8), id)
		_draw_forecast(entry, x, card_width)
		if next_shot_count >= 0 and logical >= next_shot_count:
			draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(rect.size.x - 2, 3)), Color("718790"))
		if not forecast.is_empty():
			var predictions: Array = forecast.get("shots", [])
			var fired_probability := 1.0
			if logical >= predictions.size(): fired_probability = 0.0
			elif predictions[logical].get("random", false): fired_probability = float(predictions[logical].get("used_probability", 0))
			if fired_probability <= 0 and float(forecast.get("heat", {}).get("overheat_probability", 0)) > 0:
				draw_rect(rect, Color(0.04, 0.07, 0.08, 0.82))
				draw_line(rect.position + Vector2(5, 5), rect.end - Vector2(5, 5), Color("8d7671"), 2)
				draw_string(FONT, Vector2(x + 4, 48), "미발사", HORIZONTAL_ALIGNMENT_CENTER, card_width - 8, 17, Color("c9aaa1"))
			elif logical < predictions.size() and (predictions[logical].get("overheated", false) or float(predictions[logical].get("overheat_probability", 0)) > 0):
				draw_rect(rect.grow(-1), Color("ed9167"), false, 3)
				draw_string(FONT, Vector2(x + card_width - 24, 28), "!", HORIZONTAL_ALIGNMENT_LEFT, 18, 22, Color("ed9167"))
		if logical == fired_count-1 and shot_response > 0:
			draw_rect(Rect2(rect.position+Vector2(4,0),Vector2(rect.size.x-8,3)),Color("edc47a",shot_response))
			for edge_x in [rect.position.x+4,rect.end.x-8]: draw_rect(Rect2(edge_x,rect.position.y+4,4,roundf(shot_response*18)),Color("b8d4bf",shot_response))
		if logical < fired_count:
			draw_rect(rect, Color(0.025, 0.045, 0.055, 0.80))
			draw_string(FONT, Vector2(x + 4, 48), "발사", HORIZONTAL_ALIGNMENT_CENTER, card_width - 8, 18, Color("799187"))
		if impact_active and logical == fired_count - 1:
			draw_rect(rect.grow(-1), Color("edc47a"), false, 3)
		if live_boost_slots.has(logical) and logical >= fired_count:
			var color := Color("ed9167") if live_boost_value >= 4 else Color("edc47a")
			draw_rect(rect.grow(-2), color, false, 3)
			draw_string(FONT, Vector2(x + 8, 70), str(live_boost_labels.get(logical, "+%d" % live_boost_value)), HORIZONTAL_ALIGNMENT_CENTER, card_width - 16, 22, color)
	if not incoming.is_empty():
		var destination := Vector2(width * 0.5, 40)
		for entry in layout():
			if int(entry.index) == incoming_index:
				destination = Vector2(width * int(entry.start) + 25, 40)
				break
		preload("res://redesign/ammo_art.gd").draw(self,incoming,Rect2(origin.lerp(destination,travel).round()-Vector2(11,25),Vector2(22,50)))
		if travel > 0.75 and not reduced_motion:
			var glow := (1.0-travel)*4.0
			draw_rect(Rect2(destination+Vector2(-12,28),Vector2(24,3)),Color("b8d4bf",glow))
	# Only corners mark the prospective insertion; current rounds remain readable.
	var insert_rect := insertion_preview_rect()
	if insert_rect.has_area():
		for x in [insert_rect.position.x, insert_rect.end.x-2]:
			draw_rect(Rect2(x,insert_rect.position.y,2,10),Color("b8d4bf"))
			draw_rect(Rect2(x,insert_rect.end.y-10,2,10),Color("b8d4bf"))
		for y in [insert_rect.position.y,insert_rect.end.y-2]:
			draw_rect(Rect2(insert_rect.position.x,y,12,2),Color("b8d4bf"))
			draw_rect(Rect2(insert_rect.end.x-12,y,12,2),Color("b8d4bf"))

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
		value = "무작위" if shot.get("random", false) else "피해 %d" % int(shot.damage)
		if shot.get("intercept", false): value = "요격"
		elif float(shot.get("intercept_probability", 0)) >= 0.999999: value = "확정 요격"
		elif not shot.get("random", false) and int(shot.hp) == 0: value += " 처치"
		if next_shot_count >= 0 and logical >= next_shot_count:
			value = "%d회째 · %s" % [int(shot.get("action", 0)) + 1, value]
		note = compact_lines(forecast, logical)[2]
		if shot.get("random", false): note = "%d~%d 피해" % [shot.damage_min, shot.damage_max]
		color = Color("edc47a") if bool(shot.get("boosted", false)) else Color("c0d5ce")
		if not shot.get("random", false) and not Content.is_attack(str(shot.id)):
			var effect := preload("res://redesign/damage_readout.gd").entry(shot)
			value = str(effect.number)
			note = str(effect.label)
			if int(shot.get("boost_granted",0)) > 0: value = "공격 +%d" % int(shot.boost_granted); note = ("고열일 때" if shot.get("boost_hot",false) else "다음 공격 %d발" % int(shot.boost_rounds))
			elif int(shot.get("boost_factor_granted",1)) > 1: value = "공격 ×%d" % int(shot.boost_factor_granted); note = "강화 공격 열 +%d" % int(shot.get("boost_heat",0))

			if shot.get("boost_replaced",false): note = "기존 강화 교체"

	draw_string(FONT, Vector2(x + 48, 50), value, HORIZONTAL_ALIGNMENT_LEFT, card_width - 55, 18, color)
	if not note.is_empty(): draw_string(FONT, Vector2(x + 8, 72), note, HORIZONTAL_ALIGNMENT_CENTER, card_width - 16, 16, Color("edc47a"))

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
	if Content.AMMO.has(str(shot.get("id", ""))) and not Content.is_attack(str(shot.id)):
		var label := preload("res://redesign/damage_readout.gd").entry(shot)
		return PackedStringArray([str(label.number), str(label.label), "강화 보존" if not shot.get("pending_boost", {}).is_empty() else ""])
	var result := PackedStringArray(["피해 %d" % int(shot.damage), "처치" if int(shot.hp) == 0 else "HP%d" % int(shot.hp), ""])
	if shot.get("intercept", false):
		result[0] = "요격"
		result[1] = "압력탄 제거"
	var boosted: bool = int(shot.get("math", {}).get("boost", 0)) > 0 or int(shot.get("math", {}).get("factor", 1)) > 1
	var secondary: Array = shot.get("secondary", [])
	if not secondary.is_empty():
		var spread := secondary.filter(func(value): return value.get("kind", "arc") == "spread")
		if spread.size() > 0 and spread.size() < secondary.size(): result[2] = "확산·전이"
		elif spread.size() > 1: result[2] = "확산%d명" % spread.size()
		elif spread.size() == 1: result[2] = "확산 −%d" % int(spread[0].damage)
		elif secondary.size() > 1: result[2] = "전이%d명" % secondary.size()
		else: result[2] = "전이 −%d" % int(secondary[0].damage)
	elif int(shot.get("math", {}).get("overflow", 0)) > 0: result[2] = "관통+%d" % int(shot.math.overflow)
	elif int(shot.get("burn_added", 0)) > 0:
		var ticks := Forecast.burn_ticks_for_shot(prediction, index)
		result[2] = "화상%d회" % ticks if ticks > 0 else "화상+%d" % int(shot.burn_added)
	elif int(shot.get("push", 0)) > 0: result[2] = "+%dm" % int(shot.push)
	elif int(shot.get("focus_damage", 0)) > 0: result[2] = "집중+%d" % shot.focus_damage
	elif int(shot.get("relay_damage",0))>0: result[2] = "후속 전달 +%d" % int(shot.relay_damage)
	elif int(shot.get("engine_percent",100))>100: result[2] = "코어 ×%.2f" % (int(shot.engine_percent)/100.0)
	elif boosted: result[2] = "%d회 강화 적용" % int(shot.hits) if int(shot.hits) > 1 else "강화 +%d ×%d" % [int(shot.math.boost), int(shot.math.get("factor", 1))]
	elif int(shot.get("hits", 1)) > 1: result[2] = "×%d" % int(shot.hits)
	elif Content.AMMO.has(str(shot.id)) and str(Content.AMMO[str(shot.id)].effect) == "boost": result[2] = "→공격%d %s" % [int(shot.get("boost_rounds", 2)), "×%d" % int(shot.boost_factor_granted) if int(shot.get("boost_factor_granted", 1)) > 1 else "+%d" % int(shot.get("boost_granted", 2))]
	for entry in [["armor_removed", "장갑−%d"], ["detonation", "기폭 %d"], ["chase_bonus", "추격+%d"], ["cooled", "냉각−%d"]]:
		if int(shot.get(entry[0], 0)) > 0: result[2] = str(entry[1]) % int(shot[entry[0]])
	if int(shot.get("thermal_bonus", 0)) > 0: result[2] = "고열+%d" % shot.thermal_bonus
	if int(shot.get("vent_bonus", 0)) > 0: result[2] = "열→피해+%d" % shot.vent_bonus
	if shot.get("boost_hot_failed",false): result[2] = "잔열 부족"
	elif int(shot.get("boost_heat_paid",0)) > 0: result[2] = "배율 ×%d · 열 +%d" % [int(shot.math.factor),int(shot.boost_heat_paid)]
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

func show_impact() -> void:
	if is_instance_valid(response_tween): response_tween.kill()
	shot_response = 0.0 if reduced_motion else 1.0
	queue_redraw()
	if reduced_motion: return
	response_tween = create_tween()
	response_tween.tween_method(func(value: float): shot_response = value; queue_redraw(),1.0,0.0,0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func consume() -> void:
	show_impact()
	impact_active = false
	fired_count = mini(stack.size(), fired_count + 1)
	forecast = {}
	queue_redraw()
