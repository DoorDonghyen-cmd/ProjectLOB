extends Control
## Presentation consumes copies only. Combat is already resolved and saved before
## any tween starts; this control never invokes game commands or random streams.
signal shot_started(result: Dictionary)
const Ammo = preload("res://redesign/ammo_visual.gd")
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

func _ready() -> void:
	custom_minimum_size.y = 260
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func sync(state: Dictionary) -> void:
	enemies = state.enemies.duplicate(true)
	target = _nearest()
	caption = "가까운 적을 자동 조준 · 사격 후 생존한 적이 전진"
	queue_redraw()

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
		draw_line(Vector2(130, pos.y + 23), Vector2(end + 30, pos.y + 23), Color("39515b"), 2)
		if e.hp > 0:
			if i == target:
				draw_line(Vector2(102, 131), pos, Color("5a9d91"), 1)
				draw_arc(pos, 27, 0, TAU, 32, Color("a9dfbf"), 1.5)
			_draw_enemy(pos, str(e.kind), Color("efb088") if i == target else Color("91adba"))
			draw_rect(Rect2(pos.x - 23, pos.y - 33, 46, 4), Color("3c515b"))
			draw_rect(Rect2(pos.x - 23, pos.y - 33, 46 * float(e.hp) / float(e.max_hp), 4), Color("b3db9d"))
			draw_string(FONT, pos + Vector2(-18, 42), "%dm" % roundi(e.distance), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("e6e6d9"))
			if e.slow > 0:
				draw_arc(pos, 22, 0, TAU, 20, Ammo.COLORS.slow, 3)
		else:
			draw_line(pos + Vector2(-12, -12), pos + Vector2(12, 12), Color("52716b"), 3)
			draw_line(pos + Vector2(-12, 12), pos + Vector2(12, -12), Color("52716b"), 3)
		var x := size.x - 239
		draw_string(FONT, Vector2(x, pos.y - 16), ("▶ " if i == target else "") + str(e.name), HORIZONTAL_ALIGNMENT_LEFT, 230, 19, Color("a9dfbf") if i == target else Color("dce0d8"))
		draw_string(FONT, Vector2(x, pos.y + 3), "HP %d/%d   장갑 %d   회피 %d" % [e.hp, e.max_hp, e.def, e.eva], HORIZONTAL_ALIGNMENT_LEFT, 233, 16, Color("c2cdd1"))
		draw_string(FONT, Vector2(x, pos.y + 20), "속도 %d · 다음 전진 %dm" % [e.speed, maxi(0, int(e.speed) - int(e.slow))], HORIZONTAL_ALIGNMENT_LEFT, 233, 15, Color("8ca8b4"))
	if not bullet.is_empty() and projectile_target >= 0:
		var from := Vector2(102, 131)
		var to := enemy_position(projectile_target)
		var point := from.lerp(to, bullet_progress)
		draw_line(point - (to - from).normalized() * 28, point, Ammo.COLORS[bullet], 5)
		draw_circle(point, 4, Color.WHITE)
	if float_target >= 0:
		var point := enemy_position(float_target)
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

func play_action(before: Dictionary, after: Dictionary, results: Array, reloading: bool) -> void:
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
		enemy.slow = maxi(int(enemy.slow), int(result.slow))
		float_target = target
		float_text = "빗나감" if not result.hit else ("도탄" if result.damage == 0 else "−%d" % result.damage)
		if result.hp == 0: float_text += " 처치"
		float_color = Color("f0b495") if result.damage == 0 else Color("d7eeae")
		caption = str(result.text)
		var distance := float(enemy.distance)
		visual_events.append({"kind": "impact", "target": target, "hp": result.hp, "push": result.push})
		await _animate(0.32, func(t: float): pulse = t; enemy.distance = lerpf(distance, distance + float(result.push), t))
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
