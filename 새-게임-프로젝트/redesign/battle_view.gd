extends Control
## Presentation consumes copies only. Combat is already resolved and saved before
## any tween starts; this control never invokes game commands or random streams.
signal shot_started(result: Dictionary)
signal enemy_inspected(index: int)
const Forecast = preload("res://redesign/forecast.gd")
const Ammo = preload("res://redesign/ammo_visual.gd")
const Readability = preload("res://redesign/readability.gd")
var display_state: Dictionary = {}
const FONT = preload("res://assets/fonts/NeoDunggeunmoPro-Regular.ttf")
var enemies: Array = []
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
var fast_forward := false
var speed_scale := 1.0
var visual_events: Array = []
var first_shot: Dictionary = {}
var hovered := -1
var inspection_enabled := true
var info_buttons: Array[Button] = []
var chain_targets: Array = []

func _ready() -> void:
	custom_minimum_size.y = 240
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_place_info_buttons)
	mouse_exited.connect(func(): hovered = -1; queue_redraw())

func sync(state: Dictionary) -> void:
	display_state = {"course": state.get("course", false), "floor": state.floor}
	enemies = state.enemies.duplicate(true)
	target = _nearest()
	caption = ""
	_rebuild_info_buttons()
	queue_redraw()

func _rebuild_info_buttons() -> void:
	for button in info_buttons:
		remove_child(button)
		button.queue_free()
	info_buttons.clear()
	for i in range(enemies.size()):
		var button := Button.new()
		button.name = "enemy_info_%d" % i
		button.flat = true
		for state in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
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
	_place_info_buttons()

func _place_info_buttons() -> void:
	for i in range(info_buttons.size()):
		info_buttons[i].position = Vector2(size.x - 247, enemy_position(i).y - 30)
		info_buttons[i].size = Vector2(241, 50)

func _enemy_at(point: Vector2) -> int:
	for i in range(enemies.size()):
		if Rect2(enemy_position(i) - Vector2(30, 27), Vector2(60, 53)).has_point(point): return i
	return -1

func _enemy_text(index: int) -> String:
	var e: Dictionary = enemies[index]
	return "%s · %s\nHP %d/%d · 장갑 %d · 화상 %d\n거리 %dm · 접근 %dm\n클릭: 상세 정보 (자동 조준 유지)" % [Forecast.tag(index), e.name, e.hp, e.max_hp, e.def, e.burn, roundi(e.distance), e.speed]

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
	var end := size.x - 280.0
	return Vector2(130.0 + clampf(float(enemies[index].distance) / 32.0, 0, 1) * (end - 130.0), 72.0 + index * 56.0)

func _draw() -> void:
	draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	var end := size.x - 280.0
	for meter in range(0, 33, 4):
		var x := 130.0 + meter / 32.0 * (end - 130.0)
		draw_line(Vector2(x, 40), Vector2(x, 217), Color("29404a"), 1)
		draw_string(FONT, Vector2(x - 12, 32), "%dm" % meter, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("849da7"))
	draw_rect(Rect2(113, 40, 16, 177), Color("793e3b"))
	draw_string(FONT, Vector2(15, 32), "접촉 = 패배", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f2a38d"))
	# Human silhouette and borrowed gun; no final artwork dependency.
	draw_circle(Vector2(49, 114), 10, Color("d6d9cc"))
	draw_colored_polygon(PackedVector2Array([Vector2(40, 127), Vector2(58, 127), Vector2(64, 158), Vector2(34, 158)]), Color("849993"))
	draw_line(Vector2(43, 157), Vector2(39, 180), Color("849993"), 7)
	draw_line(Vector2(56, 157), Vector2(61, 180), Color("849993"), 7)
	draw_line(Vector2(56, 135), Vector2(74, 132), Color("d6d9cc"), 6)
	draw_rect(Rect2(72 - flash * 5, 126, 29, 10), Color("b2bac0"))
	draw_rect(Rect2(74 - flash * 5, 134, 7, 10), Color("b2bac0"))
	if flash > 0:
		draw_colored_polygon(PackedVector2Array([Vector2(102, 126), Vector2(117, 130), Vector2(102, 137)]), Color(1, 0.9, 0.55, flash))
	for i in range(enemies.size()):
		var e: Dictionary = enemies[i]
		var pos := enemy_position(i)
		if i == hovered and inspection_enabled:
			draw_rect(Rect2(pos - Vector2(30, 28), Vector2(60, 54)), Color("d1d8d7"), false, 1)
		draw_line(Vector2(130, pos.y + 23), Vector2(end + 30, pos.y + 23), Color("39515b"), 2)
		if e.hp > 0:
			if i == target:
				draw_line(Vector2(102, 131), pos, Color("5a9d91"), 1)
				draw_arc(pos, 27, 0, TAU, 32, Color("a9dfbf"), 1.5)
			_draw_enemy(pos, str(e.kind), Color("efb088") if i == target else Color("91adba"))
			draw_rect(Rect2(pos.x - 23, pos.y - 33, 46, 4), Color("3c515b"))
			draw_rect(Rect2(pos.x - 23, pos.y - 33, 46 * float(e.hp) / float(e.max_hp), 4), Color("b3db9d"))
			var distance_x := pos.x + 34 if pos.x + 155 < end else pos.x - 130
			draw_string(FONT, Vector2(distance_x, pos.y + 24), "%s · %dm" % [Forecast.tag(i), roundi(e.distance)], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("e6e6d9"))
			if int(e.get("burn", 0)) > 0:
				var flame := pos + Vector2(30, -13)
				draw_colored_polygon(PackedVector2Array([flame + Vector2(0, -8), flame + Vector2(6, 0), flame + Vector2(3, 8), flame + Vector2(-4, 6), flame + Vector2(-6, 0)]), Ammo.ATTRIBUTE_COLORS.fire)
		else:
			draw_line(pos + Vector2(-12, -12), pos + Vector2(12, 12), Color("52716b"), 3)
			draw_line(pos + Vector2(-12, 12), pos + Vector2(12, -12), Color("52716b"), 3)
		var x := size.x - 239
		draw_string(FONT, Vector2(x, pos.y - 9), Forecast.tag(i) + " · " + str(e.name) + "  HP %d" % e.hp, HORIZONTAL_ALIGNMENT_LEFT, 233, 17, Color("a9dfbf") if i == target else Color("dce0d8"))
		draw_string(FONT, Vector2(x, pos.y + 14), Readability.enemy_stats(e, display_state), HORIZONTAL_ALIGNMENT_LEFT, 233, 16, Color("8ca8b4"))
		if int(e.get("burn", 0)) > 0:
			var status_x := 34 if pos.x + 115 < end else -110
			draw_string(FONT, pos + Vector2(status_x, -17), "화상%d" % e.burn, HORIZONTAL_ALIGNMENT_LEFT, 80, 15, Ammo.ATTRIBUTE_COLORS.fire)
	if not first_shot.is_empty() and first_shot.target >= 0:
		var p := enemy_position(first_shot.target)
		var label_x := p.x + 34 if p.x + 155 < end else p.x - 130
		draw_string(FONT, Vector2(label_x, p.y + 4), "예상 " + Forecast.outcome(first_shot), HORIZONTAL_ALIGNMENT_LEFT, 128, 18, Color("a9dfbf") if first_shot.damage > 0 else Color("f2a38d"))
	if not bullet.is_empty() and projectile_target >= 0:
		var from := Vector2(102, 131)
		var to := enemy_position(projectile_target)
		var point := from.lerp(to, bullet_progress)
		draw_line(point - (to - from).normalized() * 28, point, Ammo.COLORS[bullet], 5)
		draw_circle(point, 4, Color.WHITE)
	if float_target >= 0:
		var point := enemy_position(float_target)
		for secondary in chain_targets:
			var other_point := enemy_position(int(secondary.target))
			draw_line(point, other_point, Color(Ammo.COLORS.arc, 1.0 - pulse), 3)
			draw_string(FONT, other_point + Vector2(30, 0), "전이 −%d" % secondary.damage, HORIZONTAL_ALIGNMENT_LEFT, 130, 18, Ammo.COLORS.arc)
		draw_arc(point, 12 + pulse * 20, 0, TAU, 24, Color(float_color, 1.0 - pulse), 3)
		var text_x := point.x + 34 if point.x + 204 < end else point.x - 170
		draw_string(FONT, Vector2(text_x, point.y + 3 - pulse * 7), float_text, HORIZONTAL_ALIGNMENT_LEFT, 170, 22, float_color)
	draw_string(FONT, Vector2(18, size.y - 14), caption, HORIZONTAL_ALIGNMENT_LEFT, size.x - 35, 18, Color("b8d7cb"))

func _draw_enemy(p: Vector2, kind: String, color: Color) -> void:
	if kind == "runner":
		draw_colored_polygon(PackedVector2Array([p + Vector2(-24, -7), p + Vector2(12, -14), p + Vector2(21, 1), p + Vector2(-17, 9)]), color)
		for x in [-17, -4, 8, 18]:
			draw_line(p + Vector2(x, 2), p + Vector2(x - 7, 20), color, 4)
		draw_circle(p + Vector2(-24, 0), 6, Color("f4dbac"))
	elif kind == "wall":
		draw_rect(Rect2(p - Vector2(20, 22), Vector2(40, 42)), color)
		draw_rect(Rect2(p - Vector2(12, 15), Vector2(24, 28)), Color("263b48"))
		draw_line(p + Vector2(-20, 0), p + Vector2(20, 0), color, 5)
		draw_rect(Rect2(p + Vector2(-24, 19), Vector2(48, 5)), Color("c8d0c7"))
	else:
		var points := PackedVector2Array([p + Vector2(0, -25), p + Vector2(12, 0), p + Vector2(0, 25), p + Vector2(-12, 0), p + Vector2(0, -25)])
		draw_polyline(points, color, 3)
		draw_line(p + Vector2(-19, -12), p + Vector2(-14, 12), color, 2)
		draw_line(p + Vector2(19, -12), p + Vector2(14, 12), color, 2)
		draw_circle(p, 4, color)

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

func play_action(before: Dictionary, after: Dictionary, results: Array, advance_events: Array, reloading: bool) -> void:
	inspection_enabled = false
	first_shot = {}
	sync(before)
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
		await _animate(0.22, func(t: float): bullet_progress = t; flash = 1.0 - t)
		bullet = ""
		var enemy: Dictionary = enemies[target]
		enemy.hp = result.hp
		enemy.burn = result.get("burn", 0)
		chain_targets = result.get("secondary", []).duplicate(true)
		for secondary in chain_targets:
			enemies[secondary.target].hp = secondary.hp
			visual_events.append({"kind": "secondary", "target": secondary.target, "damage": secondary.damage, "hp": secondary.hp})
		float_target = target
		float_text = "빗나감" if not result.hit else ("도탄" if result.damage == 0 else "−%d" % result.damage)
		if result.hp == 0: float_text += " 처치"
		elif result.get("hits", 1) == 2: float_text += " 2타"
		float_color = Color("f0b495") if result.damage == 0 else Color("d7eeae")
		caption = "%s · %s" % [Ammo.SHORT[result.id], float_text]
		if not result.get("combo", []).is_empty(): caption += " · " + " / ".join(result.combo)
		var distance := float(enemy.distance)
		visual_events.append({"kind": "impact", "target": target, "hp": result.hp, "push": result.push})
		await _animate(0.32, func(t: float): pulse = t; enemy.distance = lerpf(distance, distance + float(result.push), t))
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
		float_text = "화상 −%d" % event.damage
		if int(event.hp) == 0: float_text += " 처치"
		float_color = Ammo.ATTRIBUTE_COLORS.fire
		caption = "화상 · 전진 직전 피해"
		visual_events.append({"kind": "burn", "target": burn_target, "damage": event.damage, "hp": event.hp, "burn": event.burn})
		await _animate(0.28, func(t: float): pulse = t)
		float_target = -1
		pulse = 0.0
	# Only after the complete burst do survivors advance, exactly as the model did.
	var starts: Array = enemies.duplicate(true)
	caption = "재장전 · %d턴 동안 적이 접근합니다" % (int(after.turns) - int(before.turns)) if reloading else "생존한 적이 접근합니다"
	visual_events.append({"kind": "advance"})
	await _animate(0.48, func(t: float):
		for i in range(enemies.size()):
			enemies[i].distance = lerpf(float(starts[i].distance), float(after.enemies[i].distance), t)
	)
	enemies = after.enemies.duplicate(true)
	target = _nearest()
	caption = "전진 완료" if after.phase not in ["reward", "won", "lost"] else ("통로 확보" if after.phase != "lost" else "0m · 접촉")
	queue_redraw()
