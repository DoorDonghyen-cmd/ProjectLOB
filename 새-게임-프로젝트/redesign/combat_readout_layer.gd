extends Node2D
## Draw above alpha-cutout actor children, in the same local finish camera.
var board: Control

func _draw() -> void:
	if not is_instance_valid(board): return
	draw_set_transform_matrix(board.finish_camera())
	board._draw_surface_overlay(self)
	board._draw_projectiles(self)
	board._draw_crowding(self)
	board._draw_wreckage_readouts(self)
	for index in board._alive_indices():
		board._draw_enemy_plaque(index, self)
		board._draw_enemy_marker(index, self)
	board._draw_damage_readouts(self)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_proximity_warning()

func proximity_notice_rect() -> Rect2:
	if not board.inspection_enabled or int(board.proximity_warning.get("actions", 0)) != 1: return Rect2()
	var available: float = board.size.x - 16.0
	if not board.reinforcements.is_empty(): available = board.reinforcement_strip_rect().position.x - 12.0
	if available < 130.0: return Rect2()
	var width := minf(242.0, available)
	var left := clampf((board.size.x - width) * 0.5, 8.0, maxf(8.0, available - width + 8.0))
	return Rect2(Vector2(left, board.size.y - 26.0).round(), Vector2(width, 22.0))

func _draw_proximity_warning() -> void:
	if not board.inspection_enabled or board.proximity_warning.is_empty(): return
	var immediate: bool = int(board.proximity_warning.actions) == 1
	var depth := 10 if immediate else 5
	var opacity := 0.82 if immediate else 0.40
	var color := Color("da6055")
	# Screen-space pixel bands. Their alpha stays steady until the next decision.
	for i in range(depth):
		var inset := 1.5 + i
		var weight := 1.0 - float(i) / depth
		draw_rect(Rect2(Vector2.ONE * inset, board.size - Vector2.ONE * (inset * 2.0)), Color(color, opacity * weight * weight), false, 1.0)
	if not immediate: return
	var rect := proximity_notice_rect()
	if not rect.has_area(): return
	var text := "다음 적 행동 · 압력탄 위험" if board.proximity_warning.kind == "projectile" else "다음 적 행동 · 접촉 위험"
	draw_rect(rect, Color("251a19"))
	draw_rect(rect, Color("985348"), false, 1.0)
	draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(2, rect.size.y - 2)), color)
	var font_size := 16
	while font_size > 12 and board.FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > rect.size.x - 12: font_size -= 1
	draw_string(board.FONT, rect.position + Vector2(6, 16), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 12, font_size, Color("f9c6b4"))
