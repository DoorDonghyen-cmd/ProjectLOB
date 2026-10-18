extends Control
## A compact, readable combat board. The model resolves every action first; this
## view only presents copied state and never consumes RNG or invokes commands.
signal shot_started(result: Dictionary)
signal shot_impacted(result: Dictionary)
signal enemy_inspected(index: int)
signal reinforcement_inspected(index: int)
const Forecast = preload("res://redesign/forecast.gd")
const Ammo = preload("res://redesign/ammo_visual.gd")
const Content = preload("res://redesign/content.gd")
const Ranged = preload("res://redesign/ranged.gd")
const Art = preload("res://redesign/world_art.gd")
const Pixel = preload("res://redesign/pixel_art.gd")
const ActorMotion = preload("res://redesign/actor_motion.gd")
const EnemyStatusIcons = preload("res://redesign/enemy_status_icons.gd")
const FINISH_MAX_ZOOM := 1.25
const FINISH_DURATION := 2.5
const FINISH_IMPACT_HOLD := 0.065
const FINISH_APPROACH := 0.20
const FINISH_RELEASE := 0.72
const BOTTOM_STATUS_HEIGHT := 30.0
var region := 0
const FONT = preload("res://redesign/combat_pixel_font.tres")
var display_state: Dictionary = {}
var enemies: Array = []
var projectiles: Array = []
var reinforcements: Array = []
var forecast: Dictionary = {}
var target := -1
var caption := ""
# Routine event captions duplicate the HUD. Only training/art previews opt in.
var show_caption := false
var bullet := ""
var bullet_progress := 0.0
var projectile_target := -1
var flash := 0.0
var float_text := ""
var float_color := Color.WHITE
var float_target := -1
var damage_popups: Array = []
var hit_hp_before: Dictionary = {}
var damage_columns: Dictionary = {}
var pulse := 0.0
var deployment_flash := 0.0
var new_enemy_indices: Array = []
var fast_forward := false
var speed_scale := 1.0
var visual_events: Array = []
var first_shot: Dictionary = {}
var hovered := -1
var preview_targets: Array = []
var inspection_enabled := true
var info_buttons: Array[Button] = []
var reserve_buttons: Array[Button] = []
var chain_targets: Array = []
var compact_lanes := true
var compact_ui := false
var march_phase := 0.0
var impact_attribute := "physical"
var focus_flash := -1
# Retain a defeated threat's last anchor for its impact text until sync finishes.
var _last_threat_x: Dictionary = {}
var actor_clock := 0.0
var moving_indices: Array = []
var actor_hit_strength := 0.0
var finish_allowed := false
var finish_consumed := false
var finish_active := false
var finish_progress := 0.0
var finish_focus := Vector2.ZERO
var finish_frame := Rect2()

func finish_camera() -> Transform2D:
	if not finish_active or fast_forward or not actor_motion_enabled() or finish_frame.size==Vector2.ZERO: return Transform2D.IDENTITY
	var weight:=smoothstep(0.0,FINISH_APPROACH,finish_progress)*(1.0-smoothstep(FINISH_RELEASE,1.0,finish_progress))
	var ceiling:=minf(FINISH_MAX_ZOOM,minf((size.x-16.0)/maxf(1,finish_frame.size.x),(size.y-16.0)/maxf(1,finish_frame.size.y)))
	var zoom:=lerpf(1.0,maxf(1.0,ceiling),weight)
	var center:=size*0.5
	var offset:=center-center.lerp(finish_focus,weight*0.45)*zoom
	# Keep the drawn world covering the viewport and the entire defeated group in shot.
	var lower:Vector2=(size*(1.0-zoom)).max(Vector2(8,8)-finish_frame.position*zoom)
	var upper:Vector2=Vector2.ZERO.min(size-Vector2(8,8)-finish_frame.end*zoom)
	if lower.x<=upper.x: offset.x=clampf(offset.x,lower.x,upper.x)
	else: offset.x=clampf(offset.x,size.x*(1.0-zoom),0)
	if lower.y<=upper.y: offset.y=clampf(offset.y,lower.y,upper.y)
	else: offset.y=clampf(offset.y,size.y*(1.0-zoom),0)
	return Transform2D(Vector2(zoom,0),Vector2(0,zoom),offset.round())

func _frame_finish_targets(entries: Array = []) -> void:
	var points: Array[Vector2]=[]
	var defeated: Array = entries.filter(func(entry): return entry.kill).map(func(entry): return entry.target)
	for item in damage_popup_layout(entries, defeated):
		if not item.entry.kill: continue
		var index:=int(item.entry.target)
		points.append(enemy_position(index))
		var foot:=enemy_feet(index)
		var head:=enemy_head_y(index)
		var area:=Rect2(foot.x-64,head-6,128,foot.y-head+12).merge(item.bounds)
		finish_frame=area if finish_frame.size==Vector2.ZERO else finish_frame.merge(area)
	finish_focus=Vector2.ZERO
	for point in points: finish_focus+=point
	if not points.is_empty(): finish_focus/=points.size()

func visual_clock_scale() -> float:
	return lerpf(0.18,1.0,clampf((finish_progress-FINISH_RELEASE)/(1.0-FINISH_RELEASE),0,1)) if finish_active and not fast_forward else 1.0

func actor_motion_enabled() -> bool:
	return true

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not actor_motion_enabled(): return
	var previous_frame := int(actor_clock * 8.0)
	actor_clock = fmod(actor_clock + delta*visual_clock_scale(), 120.0)
	if int(actor_clock * 8.0) != previous_frame: queue_redraw()

func _ready() -> void:
	custom_minimum_size.y = 264
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_place_info_buttons)
	mouse_exited.connect(func(): hovered = -1; queue_redraw())

func sync(state: Dictionary, prediction: Dictionary = {}) -> void:
	finish_allowed=false
	finish_consumed=false
	finish_active=false
	finish_progress=0.0
	finish_focus=Vector2.ZERO
	finish_frame=Rect2()
	damage_popups.clear()
	hit_hp_before.clear()
	damage_columns.clear()
	display_state = {"course": state.get("course", false), "floor": state.floor, "gun": state.gun, "outfit": state.get("outfit", "work")}
	enemies = state.enemies.duplicate(true)
	projectiles = state.get("projectiles", []).duplicate(true)
	_last_threat_x.clear()
	moving_indices.clear()
	actor_hit_strength = 0.0
	reinforcements = state.get("reinforcements", []).duplicate(true)
	forecast = prediction.duplicate(true)
	target = -1 if state.gun == "scatter" else _nearest()
	caption = ""
	compact_lanes = true
	_rebuild_info_buttons()
	queue_redraw()

func _alive_indices() -> Array:
	var result: Array = []
	for i in range(enemies.size()):
		if int(enemies[i].hp) > 0: result.append(i)
	return result

func _lane(index: int) -> int:
	if index < 0 or index >= enemies.size(): return 0
	return clampi(int(enemies[index].get("lane", index % 4)), 0, 3)

func _rebuild_info_buttons() -> void:
	for button in info_buttons + reserve_buttons:
		remove_child(button)
		button.queue_free()
	info_buttons.clear()
	reserve_buttons.clear()
	for i in _alive_indices():
		var button := Button.new()
		button.name = "enemy_info_%d" % i
		button.flat = true
		for button_state in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(button_state, StyleBoxEmpty.new())
		button.tooltip_text = _enemy_text(i)
		button.disabled = not inspection_enabled
		button.pressed.connect(func():
			if inspection_enabled: enemy_inspected.emit(i)
		)
		button.mouse_entered.connect(func(): hovered = i; queue_redraw())
		button.mouse_exited.connect(func(): hovered = -1; queue_redraw())
		button.focus_entered.connect(func(): hovered = i; queue_redraw())
		button.focus_exited.connect(func(): hovered = -1; queue_redraw())
		add_child(button)
		info_buttons.append(button)
	for i in range(reinforcements.size()):
		var button := Button.new()
		button.name = "reserve_info_%d" % i
		button.flat = true
		for button_state in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(button_state, StyleBoxEmpty.new())
		button.tooltip_text = "증원 %d · %s\nHP %d · 장갑 %d · 진입 거리 %dm\n%s" % [i + 1, reinforcements[i].name, reinforcements[i].hp, reinforcements[i].def, reinforcements[i].distance, Content.enemy_rule(reinforcements[i])]
		button.disabled = not inspection_enabled
		button.pressed.connect(func():
			if inspection_enabled: reinforcement_inspected.emit(i)
		)
		add_child(button)
		reserve_buttons.append(button)
	_place_info_buttons()

func _place_info_buttons() -> void:
	for button in info_buttons:
		var index := int(button.name.trim_prefix("enemy_info_"))
		if index >= 0 and index < enemies.size():
			button.position = enemy_plaque(index).position
			button.size = enemy_plaque(index).size
	for i in range(reserve_buttons.size()):
		reserve_buttons[i].position = reinforcement_strip_rect().position + Vector2(144 + i * 28, 0)
		reserve_buttons[i].size = Vector2(26, 28)

func reinforcement_strip_rect() -> Rect2:
	# The bottom status row stays reserved even after the last arrival, so
	# actors and distance labels do not jump when the reserve count changes.
	var width := 148.0 + reinforcements.size() * 28.0
	return Rect2(Vector2(size.x - width - 8, size.y - BOTTOM_STATUS_HEIGHT).round(), Vector2(width, 28))

func _enemy_at(point: Vector2) -> int:
	for i in _alive_indices():
		if enemy_plaque(i).has_point(point) or distance_label_rect(i).has_point(point) or Rect2(enemy_position(i) - Vector2(50, 55), Vector2(100, 100)).has_point(point): return i
	return -1

func _enemy_text(index: int) -> String:
	var e: Dictionary = enemies[index]
	var weakness := " · 전기 약점 +2" if str(e.get("weakness", "")) == "electric" else ""
	var focus := "\n집중 %d/3 · 3회 적중마다 추가 피해 4" % int(e.get("focus_hits", 0)) if str(display_state.get("gun", "")) == "burst" else ""
	return "%s\nHP %d/%d · 장갑 %d · 화상 %d%s\n거리 %dm · 접근 %dm\n%s%s\n누르면 상세 정보를 엽니다" % [e.name, e.hp, e.max_hp, e.def, e.burn, weakness, roundi(e.distance), e.speed, Content.enemy_rule(e), focus]

func _get_tooltip(at_position: Vector2) -> String:
	var index := _enemy_at(at_position)
	return _enemy_text(index) if index >= 0 and inspection_enabled else ""

func _gui_input(event: InputEvent) -> void:
	if not inspection_enabled: return
	if event is InputEventMouseMotion:
		hovered = _enemy_at(event.position)
		queue_redraw()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var index := _enemy_at(event.position)
		if index >= 0:
			enemy_inspected.emit(index)
			accept_event()

func _nearest() -> int:
	var index := -1
	var distance := INF
	for i in range(enemies.size()):
		if enemies[i].hp > 0 and enemies[i].distance < distance:
			index = i
			distance = enemies[i].distance
	for projectile in projectiles:
		if int(projectile.hp) > 0 and float(projectile.distance) <= distance:
			index = Ranged.target_id(projectile)
			distance = float(projectile.distance)
	return index

func _visual_entity(index: int) -> Dictionary:
	return Ranged.entity({"enemies": enemies, "projectiles": projectiles}, index)

func actor_rect(index: int, rect: Rect2) -> Rect2:
	if not actor_motion_enabled(): return rect
	var hit := actor_hit_strength * (1.0 - pulse) if index == float_target else 0.0
	var death := pulse if int(enemies[index].hp) <= 0 else 0.0
	return ActorMotion.enemy_rect(rect, str(enemies[index].kind), actor_clock + index * 0.7, march_phase if moving_indices.has(index) else 0.0, hit, death)

func actor_tint(index: int) -> Color:
	var hit := actor_hit_strength * (1.0 - pulse) if index == float_target and actor_motion_enabled() else 0.0
	return Color(1.0 + hit * 0.3, 1.0 + hit * 0.2, 1.0 + hit * 0.1, 1.0 - pulse if int(enemies[index].hp) <= 0 else 1.0)

func _draw_enemy_actor(index: int, foot: Vector2, lift: float, _stride: float) -> void:
	var kind := str(enemies[index].kind)
	var texture := Pixel.texture(kind)
	if texture == null: return
	var rect := Pixel.sprite_rect(kind, foot - Vector2(0, lift) + _actor_offset(index))
	draw_texture_rect(texture, actor_rect(index, rect), false, actor_tint(index))

func ground_y() -> float:
	return size.y - 76.0 - BOTTOM_STATUS_HEIGHT

func _threat_order() -> Array:
	var order := _alive_indices()
	for projectile in projectiles:
		if int(projectile.hp) > 0: order.append(Ranged.target_id(projectile))
	order.sort_custom(func(a: int, b: int):
		var a_distance := float(_visual_entity(a).distance)
		var b_distance := float(_visual_entity(b).distance)
		if a_distance != b_distance: return a_distance < b_distance
		# Match model.target_index(): projectiles win ties, then enemy identity.
		if Ranged.is_projectile(a) != Ranged.is_projectile(b): return Ranged.is_projectile(a)
		return a > b if Ranged.is_projectile(a) else a < b
	)
	return order

func _distance_x(distance: float) -> float:
	return 186.0 + clampf(distance / 32.0, 0.0, 1.0) * maxf(0.0, size.x - 266.0)

func _threat_radius(index: int) -> float:
	return 28.0 if Ranged.is_projectile(index) else 75.0

func _threat_x(index: int) -> float:
	# Project every threat onto one distance axis, then separate overlapping bodies
	# in that same order. Persistent lane IDs must never override actual distance.
	var order := _threat_order()
	var positions: Dictionary = {}
	var previous := -1
	for id in order:
		var x := _distance_x(float(_visual_entity(id).distance))
		if previous >= 0:
			x = maxf(x, float(positions[previous]) + _threat_radius(previous) + _threat_radius(id) + 16.0)
		positions[id] = x
		previous = id
	# Fit crowded/equal-distance groups back from the far edge without swapping.
	var edge := size.x - 5.0
	order.reverse()
	for id in order:
		positions[id] = minf(float(positions[id]), edge - _threat_radius(id))
		edge = float(positions[id]) - _threat_radius(id) - 16.0
		_last_threat_x[id] = roundf(float(positions[id]))
	return float(_last_threat_x.get(index, _distance_x(float(_visual_entity(index).get("distance", 0)))))

func enemy_feet(index: int) -> Vector2:
	# Lane belongs to the enemy identity, never the current alive-list index.
	return Vector2(_threat_x(index), ground_y() + 16.0 + _lane(index) * 12.0).round()

func enemy_position(index: int) -> Vector2:
	return enemy_feet(index) - Vector2(0, 48)

func distance_label_rect(index: int) -> Rect2:
	# One ground-aligned baseline: never follows idle bob, recoil or sprite height.
	var height := ceilf(FONT.get_height(20)) + 4.0
	return Rect2(Vector2(clampf(enemy_feet(index).x - 40, 4, size.x - 84), size.y - height - 2 - BOTTOM_STATUS_HEIGHT).round(), Vector2(80, height))

func enemy_head_y(index: int) -> float:
	var kind := str(enemies[index].kind)
	var lift := 18.0 if kind in ["caster", "absorber", "stance"] else 0.0
	return Pixel.sprite_rect(kind, enemy_feet(index) - Vector2(0, lift)).position.y

func enemy_hud_width(_index: int) -> float:
	return minf(160, (size.x - 244.0) / 4.0 - 8)

func enemy_status_layout(index: int) -> Dictionary:
	var width := enemy_hud_width(index)
	var hp_right := 31.0 + FONT.get_string_size(str(int(enemies[index].hp)), HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 10.0
	var right := width - 7.0
	var row := 0
	var cells: Array = []
	for entry in EnemyStatusIcons.entries(enemies[index]):
		var cell_width := 25.0 + ceilf(FONT.get_string_size(str(entry.value), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x)
		if right - cell_width < (hp_right if row == 0 else 7.0):
			row += 1
			right = width - 7.0
		cells.append({"entry": entry, "x": right - cell_width, "row": row, "width": cell_width})
		right -= cell_width + 8.0
	return {"extra": row * 28.0, "cells": cells}

func enemy_plaque(index: int) -> Rect2:
	var width := enemy_hud_width(index)
	var order := _alive_indices()
	order.sort_custom(func(a, b):
		if is_equal_approx(enemy_feet(a).x, enemy_feet(b).x): return _lane(a) < _lane(b)
		return enemy_feet(a).x < enemy_feet(b).x
	)
	var lefts: Dictionary = {}
	var edge := 238.0
	for i in order:
		var current_width := enemy_hud_width(i)
		lefts[i] = maxf(edge, enemy_feet(i).x - current_width * 0.5)
		edge = float(lefts[i]) + current_width + 8
	edge = size.x - 8.0
	order.reverse()
	for i in order:
		lefts[i] = minf(float(lefts[i]), edge - enemy_hud_width(i))
		edge = float(lefts[i]) - 8
	var height := 50.0 + float(enemy_status_layout(index).extra)
	return Rect2(Vector2(float(lefts.get(index, 238)), maxf(12, enemy_head_y(index) - height - 12)).round(), Vector2(width, height).floor())

func _draw_backdrop() -> void:
	Pixel.backdrop(self, Rect2(Vector2.ZERO, size), ground_y())

func player_feet() -> Vector2:
	return Vector2(76, ground_y() + 36)

func player_muzzle() -> Vector2:
	return player_feet() + Vector2(68 - roundf(flash * 4), -76)

func _draw_player(player_foot: Vector2) -> void:
	Pixel.shadow(self, player_foot, 64)
	Pixel.sprite(self, "reclaimer", player_foot - Vector2(roundf(flash * 4), 0))

func _draw() -> void:
	draw_set_transform_matrix(finish_camera())
	_draw_backdrop()
	_draw_finish_shade()
	var muzzle := player_muzzle()
	_draw_player(player_feet())
	# The threshold is painted on the floor instead of a tall UI wall.
	for y in range(int(ground_y()) + 8, int(size.y - BOTTOM_STATUS_HEIGHT) - 18, 8):
		draw_rect(Rect2(170, y, 8, 4), Color("c57a62"))
	if flash > 0:
		draw_rect(Rect2(muzzle - Vector2(2, 4), Vector2(14, 8)), Color(1, 0.83, 0.43, flash))
		draw_rect(Rect2(muzzle + Vector2(12, -2), Vector2(6, 4)), Color(1, 0.96, 0.79, flash))
	# Fixed depth order; defeated enemies do not reshuffle the surviving sprites.
	var ordered := _alive_indices()
	if float_target >= 0 and float_target < enemies.size() and int(enemies[float_target].hp) <= 0:
		ordered.append(float_target)
	for entry in damage_popups:
		var index:=int(entry.target)
		if entry.kill and index>=0 and index<enemies.size() and not ordered.has(index): ordered.append(index)
	ordered.sort_custom(func(a, b): return _lane(a) < _lane(b))
	for i in ordered:
		var e: Dictionary = enemies[i]
		var foot := enemy_feet(i)
		var floating := str(e.kind) in ["caster", "absorber", "stance"]
		var defeated := int(e.hp) <= 0
		Pixel.shadow(self, foot, maxf(12.0, (76 if str(e.kind) == "wall" else 64) * (1.0 - pulse if defeated else 1.0)))
		var lift := 18.0 if floating else 0.0
		var stride := roundf(sin(march_phase + i) * 2.0) if march_phase != 0.0 else 0.0
		_draw_enemy_actor(i, foot, lift, stride)
		if defeated: continue
		if i == hovered or i == target or preview_targets.has(i):
			var c := Color("f2eee3") if preview_targets.has(i) or i == hovered else Color("edc47a")
			for side in [-1, 1]:
				draw_rect(Rect2(foot + Vector2(side * 50 - 2, -8), Vector2(4, 12)), c)
				draw_rect(Rect2(foot + Vector2(side * 50 - (10 if side > 0 else 0), 0), Vector2(12, 4)), c)
		if new_enemy_indices.has(i) and deployment_flash > 0:
			draw_rect(Rect2(foot - Vector2(48, 116), Vector2(96, 116)), Color(0.47, 0.79, 0.93, deployment_flash * 0.32), false, 2)
		_draw_enemy_plaque(i)
		var distance_rect := distance_label_rect(i)
		_draw_hud_text(distance_rect.position + Vector2(0, 2 + FONT.get_ascent(20)), "%dm" % roundi(e.distance), HORIZONTAL_ALIGNMENT_CENTER, distance_rect.size.x, 20, Color("d7ddd1"))
	if not reinforcements.is_empty():
		var reserve_rect := reinforcement_strip_rect()
		draw_rect(reserve_rect, Color("101e27"))
		draw_string(FONT, reserve_rect.position + Vector2(10, 21), "후속 %d기" % reinforcements.size(), HORIZONTAL_ALIGNMENT_LEFT, 126, 16, Color("acbbc1"))
		for i in range(reinforcements.size()):
			var art := Pixel.texture(str(reinforcements[i].kind))
			if art != null:
				var extent := art.get_size()
				var fitted := extent * minf(24.0 / extent.x, 22.0 / extent.y)
				draw_texture_rect(art, Rect2(reserve_rect.position + Vector2(145 + i * 28, 2) + (Vector2(24, 24) - fitted) * 0.5, fitted), false, Color("869ea8"))
	if not bullet.is_empty() and not _visual_entity(projectile_target).is_empty():
		var to := enemy_position(projectile_target)
		var point := muzzle.lerp(to, bullet_progress).round()
		draw_line((point - (to - muzzle).normalized() * 28).round(), point, Ammo.COLORS[bullet], 4, false)
		draw_rect(Rect2(point - Vector2(3, 2), Vector2(6, 4)), Color.WHITE)
	if not _visual_entity(float_target).is_empty():
		var point := enemy_position(float_target)
		for secondary in chain_targets:
			if _visual_entity(int(secondary.target)).is_empty(): continue
			var other_point := enemy_position(int(secondary.target))
			var spread: bool = str(secondary.get("kind", "arc")) in ["spread", "burn_transfer"]
			_draw_secondary_link(muzzle if spread else point, other_point, str(secondary.get("kind", "arc")))
		_draw_impact(point)
		_draw_damage_readouts()
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if show_caption and not caption.is_empty():
		var caption_width := 210.0
		for index in _alive_indices(): caption_width = minf(caption_width, distance_label_rect(index).position.x - 18)
		draw_string(FONT, Vector2(10, size.y - 1), caption, HORIZONTAL_ALIGNMENT_LEFT, maxf(0, caption_width), 12, Color("acbbc1"))

func _draw_secondary_link(from: Vector2, to: Vector2, kind: String) -> void:
	var color: Color = Color("dfb674") if kind in ["relay","overflow"] else Ammo.COLORS.arc if kind == "arc" else Color("87c9df")
	draw_line(from, to, Color(color, 1.0-pulse), 2, false)

func _capture_damage_columns() -> void:
	damage_columns.clear()
	for index in _alive_indices(): damage_columns[index] = enemy_plaque(index)

func _set_damage_popups(result: Dictionary) -> void:
	damage_popups = _damage_entries(result)

func _damage_entries(result: Dictionary) -> Array:
	var entries: Array = [preload("res://redesign/damage_readout.gd").entry(result)]
	var grouped: Dictionary = {}
	for secondary in result.get("secondary",[]):
		var key := int(secondary.target)
		if not grouped.has(key): grouped[key] = secondary.duplicate(true)
		else:
			var previous: Dictionary = grouped[key]
			var total := int(previous.damage)+int(secondary.damage)
			var blocks := int(previous.get("blocked_hits",0))+int(secondary.get("blocked_hits",0))
			var kind := str(previous.get("kind","arc")) if previous.get("kind","arc")==secondary.get("kind","arc") else "followup"
			grouped[key] = secondary.duplicate(true)
			grouped[key].damage = total
			grouped[key].blocked_hits = blocks
			grouped[key].kind = kind
	for secondary in grouped.values():
		entries.append(preload("res://redesign/damage_readout.gd").entry(secondary,str(secondary.get("kind","arc"))))
	return entries

func damage_popup_layout(entries: Array = [], defeated: Array = []) -> Array:
	var output: Array = []
	for entry in (damage_popups if entries.is_empty() else entries):
		var index := int(entry.target)
		if _visual_entity(index).is_empty(): continue
		var width := 144.0
		var left := clampf(enemy_position(index).x-width*0.5,4,size.x-width-4)
		if index >= 0 and index < enemies.size():
			var plaque: Rect2 = damage_columns.get(index,enemy_plaque(index))
			width = plaque.size.x-8
			left = plaque.position.x+4
		var top := 4.0
		for other in _alive_indices():
			if defeated.has(other): continue
			var hud := enemy_plaque(other)
			if left < hud.end.x and left+width > hud.position.x: top = maxf(top,hud.end.y+4)
		# Larger kill/heavy numbers reserve space upward, staying clear of head stats.
		var emphasis:=int(entry.get("emphasis",0))
		top = maxf(top,enemy_position(index).y-(76 if emphasis>=2 else 54))
		var available := size.y-34-top
		var font_size := int([36,44,56,64][emphasis])
		if finish_active and entry.kill: font_size=72
		var pop := 0 if not actor_motion_enabled() else int((8 if emphasis>=2 else 4)*(1.0-clampf(pulse/0.25,0,1)))
		font_size += pop
		while font_size > 24 and FONT.get_height(font_size)+22 > available: font_size -= 2
		while font_size > 24 and FONT.get_string_size(entry.number,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x > width: font_size -= 2
		var rise := 0.0 if not actor_motion_enabled() else roundf(4.0*(1.0-pulse)*(1.0-pulse))
		var baseline := Vector2(left,top+rise+FONT.get_ascent(font_size))
		var bounds := Rect2(left,top, width, FONT.get_height(font_size)+rise+18)
		output.append({"entry":entry,"baseline":baseline.round(),"font_size":font_size,"bounds":bounds})
	return output

func _draw_damage_readouts(canvas: CanvasItem = null) -> void:
	if canvas == null: canvas = self
	for item in damage_popup_layout():
		var entry: Dictionary = item.entry
		var alpha := 1.0 if not actor_motion_enabled() else clampf((1.0-pulse)/0.24,0,1)
		var color := Color(entry.color,alpha)
		var at: Vector2 = item.baseline
		var width := float(item.bounds.size.x)
		var font_size := int(item.font_size)
		canvas.draw_string_outline(FONT,at,entry.number,HORIZONTAL_ALIGNMENT_CENTER,width,font_size,5,Color("11222a",alpha))
		canvas.draw_string(FONT,at+Vector2(2,3),entry.number,HORIZONTAL_ALIGNMENT_CENTER,width,font_size,Color("11222a",alpha))
		canvas.draw_string(FONT,at,entry.number,HORIZONTAL_ALIGNMENT_CENTER,width,font_size,color)
		if not str(entry.label).is_empty():
			var label_at := at+Vector2(0,18)
			var label: String = entry.label
			if FONT.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x>width: label = label.replace(" · 처치","")
			var label_size := 16
			while label_size>12 and FONT.get_string_size(label,HORIZONTAL_ALIGNMENT_LEFT,-1,label_size).x>width: label_size-=1
			canvas.draw_string_outline(FONT,label_at,label,HORIZONTAL_ALIGNMENT_CENTER,width,label_size,3,Color("11222a",alpha))
			canvas.draw_string(FONT,label_at,label,HORIZONTAL_ALIGNMENT_CENTER,width,label_size,color)
		if entry.kill and pulse < 0.45 and actor_motion_enabled():
			var center := Vector2(at.x+width*0.5,at.y-12)
			var spread := 26+roundf(pulse*18)
			for sign_x in [-1,1]:
				canvas.draw_rect(Rect2(center+Vector2(sign_x*spread,-8),Vector2(4,4)),color)
				canvas.draw_rect(Rect2(center+Vector2(sign_x*(spread+4),0),Vector2(6,2)),color)

func _draw_enemy_plaque(index: int) -> void:
	var e: Dictionary = enemies[index]
	var rect := enemy_plaque(index)
	var p := rect.position
	var status_layout := enemy_status_layout(index)
	var baseline := p + Vector2(0, float(status_layout.extra))
	var ink := Color("e5e4d5")
	var accent := Color("dfbd7e")
	# The hit area stays generous, but has no visible panel or enclosing frame.
	_draw_hud_text(baseline + Vector2(7, 24), "HP", HORIZONTAL_ALIGNMENT_LEFT, 23, 13, Color("b3c1b8"))
	_draw_hud_text(baseline + Vector2(31, 25), str(int(e.hp)), HORIZONTAL_ALIGNMENT_LEFT, 64, 26, ink)
	var bar := Rect2(baseline + Vector2(7, 33), Vector2(rect.size.x - 14, 8))
	draw_rect(bar.grow(1), Color("15242b"))
	draw_rect(bar, Color("354b50"))
	if hit_hp_before.has(index) and int(hit_hp_before[index]) > int(e.hp):
		var old_ratio := clampf(float(hit_hp_before[index])/maxf(1,e.max_hp),0,1)
		draw_rect(Rect2(bar.position,Vector2(floorf(bar.size.x*old_ratio),8)),Color("edc47a",1.0-pulse))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(e.hp) / maxf(1, e.max_hp), 0, 1), 8)), Color("a0b79b"))
	if str(display_state.get("gun", "")) == "burst":
		for pip in range(3):
			var lit := pip < int(e.get("focus_hits", 0)) or focus_flash == index
			draw_rect(Rect2(baseline + Vector2(rect.size.x - 30 + pip * 8, 43), Vector2(5, 5)), accent if lit else Color("3b5055"))
	for placement in status_layout.cells:
		var entry: Dictionary = placement.entry
		var cell := baseline + Vector2(float(placement.x), 4.0 - int(placement.row) * 28.0)
		EnemyStatusIcons.draw_icon(self, cell, str(entry.icon), 3, true)
		_draw_hud_text(cell + Vector2(25, 18), str(entry.value), HORIZONTAL_ALIGNMENT_LEFT, 42, 18, EnemyStatusIcons.COLORS[entry.icon])
	# Only packed neighbours need a short connector; the repeated floor tag is gone.
	if absf(rect.get_center().x - enemy_feet(index).x) > 12:
		draw_line(Vector2(rect.get_center().x, rect.end.y).round(), Vector2(enemy_feet(index).x, enemy_head_y(index) - 3).round(), Color("718e99") if index == hovered else Color("425a62"), 1, false)

func _draw_hud_text(position: Vector2, text: String, alignment: int, width: float, font_size: int, color: Color) -> void:
	# A narrow dark contour protects glyphs on bright architecture without a box.
	draw_string(FONT, position + Vector2(1, 2), text, alignment, width, font_size, Color("102028"))
	draw_string_outline(FONT, position, text, alignment, width, font_size, 2, Color("102028"))
	draw_string(FONT, position, text, alignment, width, font_size, color)

func _draw_impact(point: Vector2) -> void:
	# Fixed geometry keeps visual effects independent from targeting RNG.
	var color: Color = Ammo.ATTRIBUTE_COLORS.get(impact_attribute, Color("e4bd72"))
	color.a = (1.0 - pulse) * 0.9
	for i in range(7):
		var direction := Vector2.from_angle(float(i) * TAU / 7.0 + 0.25)
		var start := point + direction * (10 + pulse * 24)
		var finish := start + direction * (5 + (1.0 - pulse) * 8)
		if impact_attribute == "electric":
			var middle := start.lerp(finish, 0.5) + direction.orthogonal() * 4
			draw_polyline(PackedVector2Array([start, middle, finish]), color, 2, true)
		elif impact_attribute == "fire":
			draw_colored_polygon(PackedVector2Array([start - direction.orthogonal() * 2, start + direction.orthogonal() * 2, finish]), color)
		else:
			draw_line(start, finish, color, 2, true)

# Presentation adapters can add feedback without resolving a second combat model.
func _actor_offset(_index: int) -> Vector2:
	return Vector2.ZERO

func _damage_font_size() -> int:
	return 25

func _damage_position(point: Vector2) -> Vector2:
	return point + Vector2(-40, -46 - roundf(pulse * 12))

func _prepare_shot(_result: Dictionary) -> void:
	pass

func _hold_impact(_result: Dictionary) -> void:
	pass

func _finish_shot() -> void:
	pass

func _draw_statuses(pos: Vector2, e: Dictionary) -> void:
	var x := pos.x + 28.0
	if int(e.get("barrier_max", 0)) > 0:
		for barrier_index in range(int(e.barrier_max)):
			var c := Color("63dce8") if barrier_index < int(e.get("barrier", 0)) else Color("38515d")
			draw_rect(Rect2(x + barrier_index * 6, pos.y - 26, 4, 8), c)
	if int(e.get("burn", 0)) > 0:
		var flame := Vector2(x + 3, pos.y - 8)
		draw_colored_polygon(PackedVector2Array([flame + Vector2(0, -7), flame + Vector2(5, 0), flame + Vector2(1, 7), flame + Vector2(-4, 3)]), Ammo.ATTRIBUTE_COLORS.fire)
		draw_string(FONT, flame + Vector2(7, 5), str(e.burn), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Ammo.ATTRIBUTE_COLORS.fire)

func _animate(duration: float, callback: Callable) -> void:
	var elapsed := 0.0
	while elapsed < duration:
		await get_tree().process_frame
		elapsed += get_process_delta_time() / maxf(speed_scale, 0.01) * (20.0 if fast_forward else 1.0)
		callback.call(minf(1.0, elapsed / duration))
		queue_redraw()

func _shot_ends_encounter(result: Dictionary) -> bool:
	if not finish_allowed or finish_consumed or not reinforcements.is_empty() or not actor_motion_enabled() or fast_forward: return false
	# Read the already resolved shot, including chained kills. Never reroll or
	# apply damage early: living actors and their HP remain visible until impact.
	var remaining: Dictionary = {int(result.target): int(result.hp)}
	for secondary in result.get("secondary", []): remaining[int(secondary.target)] = int(secondary.hp)
	if not _damage_entries(result).any(func(entry): return entry.kill): return false
	for index in _alive_indices():
		if int(remaining.get(index, enemies[index].hp)) > 0: return false
	# Projectiles are separate threats; don't announce victory while one remains.
	for projectile in projectiles:
		if int(remaining.get(Ranged.target_id(projectile), projectile.hp)) > 0: return false
	return true

func _begin_finish(entries: Array) -> void:
	finish_consumed=true
	finish_active=true
	finish_progress=0.0
	_frame_finish_targets(entries)
	visual_events.append({"kind":"finisher","targets":entries.filter(func(entry): return entry.kill).map(func(entry): return entry.target)})

func _fly_shot(result: Dictionary) -> void:
	if not _shot_ends_encounter(result):
		await _animate(0.19, func(t: float): bullet_progress = t; flash = 1.0 - t)
		return
	# The last fifth of the flight slows down while the camera approaches the
	# lethal target. Damage text/HP/death are still committed only by the impact.
	await _animate(0.19 * 0.8, func(t: float): bullet_progress = t * 0.8; flash = 1.0 - bullet_progress)
	if fast_forward:
		await _animate(0.19 * 0.2, func(t: float): bullet_progress = lerpf(0.8, 1.0, t); flash = 1.0 - bullet_progress)
		return
	_capture_damage_columns()
	_begin_finish(_damage_entries(result))
	visual_events.append({"kind":"finish_approach","target":int(result.target)})
	await _animate(FINISH_DURATION * FINISH_APPROACH, func(t: float):
		finish_progress = t * FINISH_APPROACH
		bullet_progress = lerpf(0.8, 1.0, t)
		flash = 1.0 - bullet_progress
	)

func _impact_motion(duration: float, callback: Callable) -> void:
	var last_kill:=finish_allowed and not finish_consumed and reinforcements.is_empty() and _alive_indices().is_empty() and not projectiles.any(func(projectile): return int(projectile.hp)>0) and damage_popups.any(func(entry): return entry.kill)
	if not finish_active and (not last_kill or not actor_motion_enabled() or fast_forward):
		await _animate(duration,callback)
		return
	# Damage over time has no bullet flight; retain its on-impact entrance.
	if not finish_active: _begin_finish(damage_popups)
	var start_progress := finish_progress
	# Local presentation time only: simulation, UI input and Engine.time_scale stay intact.
	await _animate(FINISH_IMPACT_HOLD,func(_t:float): callback.call(0.0))
	await _animate(FINISH_DURATION*(1.0-start_progress)-FINISH_IMPACT_HOLD,func(t:float):
		finish_progress=lerpf(start_progress,1.0,t)
		# Read the number, complete death, then pull back. Death no longer waits
		# until the zoom-out to finish fading the target.
		var progress:=lerpf(0.0,0.2,clampf((finish_progress-start_progress)/(0.5-start_progress),0,1)) if finish_progress<0.5 else lerpf(0.2,1.0,clampf((finish_progress-0.5)/(FINISH_RELEASE-0.5),0,1))
		callback.call(progress)
	)
	finish_active=false
	finish_progress=0.0
	finish_focus=Vector2.ZERO
	finish_frame=Rect2()
	queue_redraw()

func _draw_finish_shade() -> void:
	if not finish_active or fast_forward: return
	var strength:=1.0-smoothstep(0.55,1.0,finish_progress)
	draw_rect(Rect2(Vector2.ZERO,size),Color(0.025,0.04,0.05,0.23*strength))
	# Pixel-aligned edges belong to the battlefield; no HUD movement or white flash.
	for edge in [0.0,size.y-6]: draw_rect(Rect2(0,edge,size.x,6),Color(0.02,0.03,0.04,0.6*strength))

func play_action(before: Dictionary, after: Dictionary, results: Array, advance_events: Array, reloading: bool, deployments: Array = []) -> void:
	inspection_enabled = false
	first_shot = {}
	compact_lanes = false
	sync(before)
	finish_allowed=str(after.phase) in ["reward","won"] and after.get("reinforcements",[]).is_empty() and after.enemies.all(func(enemy): return int(enemy.hp)<=0)
	compact_lanes = false
	visual_events.clear()
	for result in results:
		focus_flash = -1
		projectile_target = int(result.target)
		target = projectile_target
		bullet = str(result.id)
		bullet_progress = 0.0
		caption = "%s 발사" % Ammo.SHORT[bullet]
		shot_started.emit(result)
		visual_events.append({"kind": "shot", "id": bullet, "target": target})
		await _prepare_shot(result)
		flash = 1.0
		await _fly_shot(result)
		bullet = ""
		_capture_damage_columns()
		var enemy := _visual_entity(target)
		hit_hp_before[target] = int(enemy.hp)
		enemy.hp = result.hp
		enemy.burn = result.get("burn", 0)
		enemy.def = int(result.get("armor", enemy.get("def", 0)))
		if result.has("guard_armor"): enemy.guard_armor = int(result.guard_armor)
		if bool(enemy.get("stance", false)): enemy.stance_def = int(result.get("stance_def", enemy.stance_def))
		enemy.focus_hits = result.get("focus_after", 0)
		enemy.barrier = result.get("barrier", enemy.get("barrier", 0))
		if int(result.get("interrupted", 0)) > 0:
			enemy.jammed = int(result.interrupted)
			enemy.disrupted = true
		chain_targets = result.get("secondary", []).duplicate(true)
		for secondary in chain_targets:
			if not hit_hp_before.has(int(secondary.target)): hit_hp_before[int(secondary.target)] = int(_visual_entity(int(secondary.target)).hp)
			_visual_entity(int(secondary.target)).hp = secondary.hp
			if secondary.has("barrier"): _visual_entity(int(secondary.target)).barrier = secondary.barrier
			if secondary.has("focus_hits"): _visual_entity(int(secondary.target)).focus_hits = secondary.focus_hits
			if secondary.has("burn"): _visual_entity(int(secondary.target)).burn = secondary.burn
			visual_events.append({"kind": "secondary", "target": secondary.target, "damage": secondary.damage, "hp": secondary.hp})
		float_target = target
		impact_attribute = str(Content.AMMO[str(result.id)].attribute)
		float_text = "막힘" if int(result.get("blocked_hits", 0)) > 0 and result.damage == 0 else ("방어" if result.damage == 0 else "-%d" % result.damage)
		if result.get("intercept", false): float_text = "요격"
		elif result.hp == 0: float_text += "  처치"
		elif not result.get("prepared_rounds", []).is_empty(): float_text = "다음 패 %d장 예약" % result.prepared_rounds.size()
		elif int(result.get("interrupted", 0)) > 0: float_text += " · 차단"
		elif int(result.get("transferred", 0)) > 0: float_text += " · 화상 이동"
		float_color = Color("63dce8") if int(result.get("blocked_hits", 0)) > 0 else (Color("f0b495") if result.damage == 0 else Color("d7eeae"))
		caption = "%s · %s" % [Ammo.SHORT[result.id], float_text]
		if int(result.get("focus_damage", 0)) > 0: focus_flash = target
		_set_damage_popups(result)
		shot_impacted.emit(result)
		for effect in result.get("part_effects", []):
			visual_events.append({"kind": "part", "id": effect.id, "label": effect.label, "target": target, "bullet": result.id})
		visual_events.append({"kind": "impact", "target": target, "hp": result.hp, "push": result.push})
		await _hold_impact(result)
		var distance := float(enemy.distance)
		await _impact_motion(0.36, func(t: float): pulse = t; enemy.distance = lerpf(distance, distance + float(result.push), t))
		float_target = -1
		damage_popups.clear()
		hit_hp_before.clear()
		chain_targets.clear()
		pulse = 0.0
		focus_flash = -1
		_finish_shot()
	await _play_advance(before, after, advance_events, reloading)
	enemies = after.enemies.duplicate(true)
	projectiles = after.get("projectiles", []).duplicate(true)
	reinforcements = after.get("reinforcements", []).duplicate(true)
	compact_lanes = true
	if not deployments.is_empty():
		new_enemy_indices.clear()
		for deployment in deployments: new_enemy_indices.append(int(deployment.target))
		caption = "후속 개체 %d기 투입" % deployments.size()
		visual_events.append({"kind": "deployment", "count": deployments.size(), "targets": new_enemy_indices.duplicate()})
		_rebuild_info_buttons()
		await _animate(0.34, func(t: float): deployment_flash = 1.0 - t)
		new_enemy_indices.clear()
	target = -1 if after.gun == "scatter" else _nearest()
	caption = "행동 완료" if after.phase not in ["reward", "won", "lost"] else ("구역 확보" if after.phase != "lost" else "0m · 충돌")
	queue_redraw()

func _play_advance(_before: Dictionary, after: Dictionary, advance_events: Array, reloading: bool) -> void:
	for event in advance_events:
		if str(event.kind) != "burn": continue
		var burn_target := int(event.target)
		if burn_target < 0 or burn_target >= enemies.size(): continue
		_capture_damage_columns()
		enemies[burn_target].hp = event.hp
		enemies[burn_target].burn = event.burn
		float_target = burn_target
		damage_popups = [preload("res://redesign/damage_readout.gd").entry(event, "burn")]
		float_text = "화상 -%d" % event.damage
		if int(event.hp) == 0: float_text += "  처치"
		impact_attribute = "fire"
		float_color = Ammo.ATTRIBUTE_COLORS.fire
		caption = "화상 피해"
		visual_events.append({"kind": "burn", "target": burn_target, "damage": event.damage, "hp": event.hp, "burn": event.burn})
		await _impact_motion(0.32, func(t: float): pulse = t)
		float_target = -1
		damage_popups.clear()
		pulse = 0.0
	for event in advance_events:
		var kind := str(event.kind)
		if kind == "charge":
			var charge_target := int(event.target)
			if charge_target >= 0 and charge_target < enemies.size(): enemies[charge_target].charge = int(event.charge)
			visual_events.append(event.duplicate(true))
		elif kind in ["pull", "stance"]:
			visual_events.append(event.duplicate(true))
	var starts: Array = enemies.duplicate(true)
	moving_indices.clear()
	for i in range(mini(enemies.size(), after.enemies.size())):
		if float(starts[i].distance) != float(after.enemies[i].distance): moving_indices.append(i)
	caption = "재장전 · 적 접근" if reloading else "적 접근"
	visual_events.append({"kind": "advance"})
	await _animate(0.42, func(t: float):
		march_phase = t * TAU * 2
		for i in range(mini(enemies.size(), after.enemies.size())):
			enemies[i].distance = lerpf(float(starts[i].distance), float(after.enemies[i].distance), t)
	)
	march_phase = 0.0
	moving_indices.clear()
