extends Control
## A compact, readable combat board. The model resolves every action first; this
## view only presents copied state and never consumes RNG or invokes commands.
signal shot_started(result: Dictionary)
signal enemy_inspected(index: int)
signal reinforcement_inspected(index: int)
const Forecast = preload("res://redesign/forecast.gd")
const Ammo = preload("res://redesign/ammo_visual.gd")
const Content = preload("res://redesign/content.gd")
const FONT = preload("res://assets/fonts/NeoDunggeunmoPro-Regular.ttf")
var display_state: Dictionary = {}
var enemies: Array = []
var reinforcements: Array = []
var forecast: Dictionary = {}
var target := -1
var caption := ""
var bullet := ""
var bullet_progress := 0.0
var projectile_target := -1
var flash := 0.0
var float_text := ""
var float_color := Color.WHITE
var float_target := -1
var pulse := 0.0
var deployment_flash := 0.0
var new_enemy_indices: Array = []
var fast_forward := false
var speed_scale := 1.0
var visual_events: Array = []
var first_shot: Dictionary = {}
var hovered := -1
var inspection_enabled := true
var info_buttons: Array[Button] = []
var reserve_buttons: Array[Button] = []
var chain_targets: Array = []
var compact_lanes := true

func _ready() -> void:
	custom_minimum_size.y = 220
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_place_info_buttons)
	mouse_exited.connect(func(): hovered = -1; queue_redraw())

func sync(state: Dictionary, prediction: Dictionary = {}) -> void:
	display_state = {"course": state.get("course", false), "floor": state.floor, "gun": state.gun}
	enemies = state.enemies.duplicate(true)
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
		for button_state in ["normal", "hover", "pressed", "disabled"]:
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
			button.position = enemy_position(index) - Vector2(45, 34)
			button.size = Vector2(90, 68)
	for i in range(reserve_buttons.size()):
		reserve_buttons[i].position = Vector2(size.x - 160 + i * 32, 7)
		reserve_buttons[i].size = Vector2(28, 30)

func _enemy_at(point: Vector2) -> int:
	for i in _alive_indices():
		if Rect2(enemy_position(i) - Vector2(30, 27), Vector2(60, 54)).has_point(point): return i
	return -1

func _enemy_text(index: int) -> String:
	var e: Dictionary = enemies[index]
	var weakness := " · 전기 약점 +2" if str(e.get("weakness", "")) == "electric" else ""
	return "%s · %s\nHP %d/%d · 장갑 %d · 화상 %d%s\n거리 %dm · 접근 %dm\n%s\n누르면 상세 정보를 엽니다" % [Forecast.tag(index), e.name, e.hp, e.max_hp, e.def, e.burn, weakness, roundi(e.distance), e.speed, Content.enemy_rule(e)]

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
	return index

func enemy_position(index: int) -> Vector2:
	var track_end := size.x - 46.0
	var lane := _lane(index)
	return Vector2(124.0 + clampf(float(enemies[index].distance) / 32.0, 0.0, 1.0) * (track_end - 124.0), 67.0 + lane * 39.0)

func _forecast_hp(index: int) -> int:
	if forecast.is_empty() or index >= forecast.get("enemies", []).size(): return -1
	var projected: Dictionary = forecast.enemies[index]
	return int(projected.get("hp_max", projected.get("hp", -1)))

func _draw() -> void:
	draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	var track_end := size.x - 46.0
	for meter in range(0, 33, 4):
		var x := 124.0 + meter / 32.0 * (track_end - 124.0)
		draw_line(Vector2(x, 44), Vector2(x, 201), Color("29404a"), 1)
		draw_string(FONT, Vector2(x - 10, 34), "%d" % meter, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("78929d"))
	draw_string(FONT, Vector2(126, 34), "거리 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("78929d"))
	draw_rect(Rect2(108, 44, 14, 157), Color("793e3b"))
	draw_string(FONT, Vector2(14, 28), "0m = 충돌", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f2a38d"))
	# Temporary player silhouette; the layout does not depend on final art.
	draw_circle(Vector2(47, 105), 9, Color("d6d9cc"))
	draw_colored_polygon(PackedVector2Array([Vector2(39, 117), Vector2(55, 117), Vector2(61, 146), Vector2(33, 146)]), Color("849993"))
	draw_line(Vector2(40, 145), Vector2(37, 166), Color("849993"), 6)
	draw_line(Vector2(54, 145), Vector2(58, 166), Color("849993"), 6)
	draw_line(Vector2(54, 125), Vector2(72, 122), Color("d6d9cc"), 5)
	draw_rect(Rect2(70 - flash * 5, 117, 29, 9), Color("b2bac0"))
	if flash > 0:
		draw_colored_polygon(PackedVector2Array([Vector2(100, 117), Vector2(114, 121), Vector2(100, 128)]), Color(1, 0.9, 0.55, flash))
	# The full reserve composition is public. Small silhouettes communicate volume
	# without turning the battlefield into a second text list.
	if not reinforcements.is_empty():
		draw_string(FONT, Vector2(size.x - 232, 27), "증원", HORIZONTAL_ALIGNMENT_LEFT, 62, 14, Color("91adba"))
		for i in range(reinforcements.size()):
			var rp := Vector2(size.x - 146 + i * 32, 21)
			draw_circle(rp, 10, Color("263b48"))
			_draw_enemy(rp, str(reinforcements[i].kind), Color("66828e"), 0.42)
	for i in range(enemies.size()):
		var e: Dictionary = enemies[i]
		var pos := enemy_position(i)
		if int(e.hp) <= 0 and compact_lanes: continue
		draw_line(Vector2(124, pos.y + 19), Vector2(track_end, pos.y + 19), Color("334b55"), 1)
		if i == hovered and inspection_enabled and int(e.hp) > 0:
			draw_rect(Rect2(pos - Vector2(31, 29), Vector2(62, 58)), Color("d1d8d7"), false, 1)
		if int(e.hp) > 0:
			if i == target:
				draw_line(Vector2(100, 121), pos, Color("5a9d91"), 1)
				draw_arc(pos, 26, 0, TAU, 32, Color("a9dfbf"), 1.5)
			if new_enemy_indices.has(i) and deployment_flash > 0:
				draw_arc(pos, 31 + deployment_flash * 8, 0, TAU, 28, Color(0.52, 0.82, 0.72, deployment_flash), 3)
			_draw_enemy(pos, str(e.kind), Color("efb088") if i == target else Color("91adba"))
			var hp_width := 48.0
			draw_rect(Rect2(pos.x - 24, pos.y - 31, hp_width, 5), Color("3c515b"))
			draw_rect(Rect2(pos.x - 24, pos.y - 31, hp_width * float(e.hp) / maxf(1.0, float(e.max_hp)), 5), Color("b3db9d"))
			var predicted_hp := _forecast_hp(i)
			if predicted_hp >= 0 and predicted_hp < int(e.hp):
				draw_rect(Rect2(pos.x - 24 + hp_width * float(predicted_hp) / maxf(1.0, float(e.max_hp)), pos.y - 31, hp_width * float(int(e.hp) - predicted_hp) / maxf(1.0, float(e.max_hp)), 5), Color("e4a57e"))
			var label_width := 112.0
			var label_x := pos.x + 30.0 if pos.x + label_width + 4.0 < track_end else pos.x - label_width
			var hp_text := "%s  ♥%d" % [Forecast.tag(i), e.hp]
			if predicted_hp >= 0 and predicted_hp != int(e.hp): hp_text += "→%d" % predicted_hp
			hp_text += "  ◆%d" % int(e.def)
			var tactical: PackedStringArray = []
			if int(e.get("barrier", 0)) > 0: tactical.append("▣%d" % int(e.barrier))
			if str(e.get("weakness", "")) == "electric": tactical.append("⚡+2")
			if int(e.get("burn", 0)) > 0: tactical.append("♨%d" % int(e.burn))
			if int(e.get("charge_max", 0)) > 0: tactical.append("◷%d/%d" % [int(e.get("charge", 0)), int(e.charge_max)])
			if bool(e.get("stance", false)): tactical.append("↕")
			draw_string(FONT, Vector2(label_x, pos.y - 3), hp_text, HORIZONTAL_ALIGNMENT_LEFT, label_width, 14, Color("e6e6d9"))
			var movement_text := "%dm  ↓%d" % [roundi(e.distance), int(e.speed)]
			if not tactical.is_empty(): movement_text += "  " + " ".join(tactical)
			draw_string(FONT, Vector2(label_x, pos.y + 14), movement_text, HORIZONTAL_ALIGNMENT_LEFT, label_width, 13, Color("8ca8b4"))
			_draw_statuses(pos, e)
		else:
			draw_line(pos + Vector2(-11, -11), pos + Vector2(11, 11), Color("52716b"), 3)
			draw_line(pos + Vector2(-11, 11), pos + Vector2(11, -11), Color("52716b"), 3)
	if not bullet.is_empty() and projectile_target >= 0 and projectile_target < enemies.size():
		var from := Vector2(100, 121)
		var to := enemy_position(projectile_target)
		var point := from.lerp(to, bullet_progress)
		draw_line(point - (to - from).normalized() * 28, point, Ammo.COLORS[bullet], 5)
		draw_circle(point, 4, Color.WHITE)
	if float_target >= 0 and float_target < enemies.size():
		var point := enemy_position(float_target)
		for secondary in chain_targets:
			if int(secondary.target) >= enemies.size(): continue
			var other_point := enemy_position(int(secondary.target))
			var spread: bool = str(secondary.get("kind", "arc")) == "spread"
			var color := Color("87c9df") if spread else Ammo.COLORS.arc
			draw_line(Vector2(100, 121) if spread else point, other_point, Color(color, 1.0 - pulse), 2 if spread else 3)
		draw_arc(point, 12 + pulse * 20, 0, TAU, 24, Color(float_color, 1.0 - pulse), 3)
		draw_string(FONT, point + Vector2(30, 2 - pulse * 7), float_text, HORIZONTAL_ALIGNMENT_LEFT, 125, 19, float_color)
	draw_string(FONT, Vector2(14, size.y - 10), caption, HORIZONTAL_ALIGNMENT_LEFT, size.x - 28, 15, Color("b8d7cb"))

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

func _draw_enemy(p: Vector2, kind: String, color: Color, scale_value: float = 1.0) -> void:
	var s := scale_value
	if kind == "runner":
		draw_colored_polygon(PackedVector2Array([p + Vector2(-24, -7) * s, p + Vector2(12, -14) * s, p + Vector2(21, 1) * s, p + Vector2(-17, 9) * s]), color)
		for x in [-17, -4, 8, 18]: draw_line(p + Vector2(x, 2) * s, p + Vector2(x - 7, 20) * s, color, maxf(1.0, 4 * s))
	elif kind == "wall":
		draw_rect(Rect2(p - Vector2(20, 22) * s, Vector2(40, 42) * s), color)
		draw_rect(Rect2(p - Vector2(12, 15) * s, Vector2(24, 28) * s), Color("263b48"))
	elif kind == "caster":
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -24) * s, p + Vector2(18, -2) * s, p + Vector2(9, 17) * s, p + Vector2(-9, 17) * s, p + Vector2(-18, -2) * s]), color)
		draw_circle(p + Vector2(0, -3) * s, 7 * s, Color("263b48"))
	elif kind == "absorber":
		draw_circle(p, 23 * s, color)
		draw_circle(p, 15 * s, Color("263b48"))
	elif kind == "stance":
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -25) * s, p + Vector2(23, 14) * s, p + Vector2(0, 6) * s, p + Vector2(-23, 14) * s]), color)
		draw_circle(p + Vector2(0, -2) * s, 6 * s, Color("263b48"))
	else:
		draw_arc(p, 18 * s, 0, TAU, 16, color, maxf(1.0, 3 * s))

func _background() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("14252e")
	box.set_corner_radius_all(6)
	return box

func _animate(duration: float, callback: Callable) -> void:
	var elapsed := 0.0
	while elapsed < duration:
		await get_tree().process_frame
		elapsed += get_process_delta_time() / maxf(speed_scale, 0.01) * (20.0 if fast_forward else 1.0)
		callback.call(minf(1.0, elapsed / duration))
		queue_redraw()

func play_action(before: Dictionary, after: Dictionary, results: Array, advance_events: Array, reloading: bool, deployments: Array = []) -> void:
	inspection_enabled = false
	first_shot = {}
	compact_lanes = false
	sync(before)
	compact_lanes = false
	visual_events.clear()
	for result in results:
		projectile_target = int(result.target)
		target = projectile_target
		bullet = str(result.id)
		bullet_progress = 0.0
		caption = "%s 발사" % Ammo.SHORT[bullet]
		shot_started.emit(result)
		visual_events.append({"kind": "shot", "id": bullet, "target": target})
		flash = 1.0
		await _animate(0.19, func(t: float): bullet_progress = t; flash = 1.0 - t)
		bullet = ""
		var enemy: Dictionary = enemies[target]
		enemy.hp = result.hp
		enemy.burn = result.get("burn", 0)
		enemy.focus_hits = result.get("focus_after", 0)
		enemy.barrier = result.get("barrier", enemy.get("barrier", 0))
		chain_targets = result.get("secondary", []).duplicate(true)
		for secondary in chain_targets:
			enemies[secondary.target].hp = secondary.hp
			visual_events.append({"kind": "secondary", "target": secondary.target, "damage": secondary.damage, "hp": secondary.hp})
		float_target = target
		float_text = "막힘" if int(result.get("blocked_hits", 0)) > 0 and result.damage == 0 else ("방어" if result.damage == 0 else "-%d" % result.damage)
		if result.hp == 0: float_text += "  처치"
		float_color = Color("63dce8") if int(result.get("blocked_hits", 0)) > 0 else (Color("f0b495") if result.damage == 0 else Color("d7eeae"))
		caption = "%s · %s" % [Ammo.SHORT[result.id], float_text]
		visual_events.append({"kind": "impact", "target": target, "hp": result.hp, "push": result.push})
		var distance := float(enemy.distance)
		await _animate(0.27, func(t: float): pulse = t; enemy.distance = lerpf(distance, distance + float(result.push), t))
		float_target = -1
		chain_targets.clear()
		pulse = 0.0
	for event in advance_events:
		if str(event.kind) != "burn": continue
		var burn_target := int(event.target)
		if burn_target < 0 or burn_target >= enemies.size(): continue
		enemies[burn_target].hp = event.hp
		enemies[burn_target].burn = event.burn
		float_target = burn_target
		float_text = "화상 -%d" % event.damage
		if int(event.hp) == 0: float_text += "  처치"
		float_color = Ammo.ATTRIBUTE_COLORS.fire
		caption = "화상 피해"
		visual_events.append({"kind": "burn", "target": burn_target, "damage": event.damage, "hp": event.hp, "burn": event.burn})
		await _animate(0.24, func(t: float): pulse = t)
		float_target = -1
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
	caption = "재장전 · 적 접근" if reloading else "적 접근"
	visual_events.append({"kind": "advance"})
	await _animate(0.42, func(t: float):
		for i in range(mini(enemies.size(), after.enemies.size())):
			enemies[i].distance = lerpf(float(starts[i].distance), float(after.enemies[i].distance), t)
	)
	enemies = after.enemies.duplicate(true)
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
