@tool
extends "res://redesign/samples/risk_battle_view.gd"
signal projectile_inspected(target_id: int)
const PRESSURE := Color("f2cb77")

func sync(state: Dictionary, prediction: Dictionary = {}) -> void:
	super.sync(state, prediction)
	if Ranged.is_projectile(_nearest()): target = _nearest()

func enemy_position(index: int) -> Vector2:
	if not Ranged.is_projectile(index): return super.enemy_position(index)
	var projectile := _visual_entity(index)
	if projectile.is_empty(): return player_muzzle()
	var source := int(projectile.source)
	var distance := float(projectile.distance)
	var at_distance := 186.0 + clampf(distance / 32.0, 0, 1) * (size.x - 556.0) + _lane(source) * 96.0
	var x := lerpf(player_muzzle().x, at_distance, clampf(distance / 18.0, 0, 1))
	return Vector2(x, ground_y() - (68.0 if size.y >= 240 else 30.0)).round()

func projectile_label_rect(projectile: Dictionary) -> Rect2:
	var point := enemy_position(Ranged.target_id(projectile))
	var baseline := point.y - 22 if point.y >= 142 else point.y + 34
	return Rect2(Vector2(clampf(point.x - 74, 8, size.x - 156), baseline - 21), Vector2(148, 28))

func projectile_caption(projectile: Dictionary) -> String:
	return ("요격 · 도달 %d턴" if _nearest() == Ranged.target_id(projectile) else "압력탄 · %d턴") % Ranged.arrival(projectile)

func _draw_enemy_actor(index: int, foot: Vector2, lift: float, stride: float) -> void:
	if str(enemies[index].kind) != "spitter":
		super._draw_enemy_actor(index, foot, lift, stride)
		return
	# Readable provisional silhouette: low body, broad feet, inflating throat.
	# Final species artwork is deliberately a later pass.
	var e: Dictionary = enemies[index]
	var p := (foot + _actor_offset(index)).round()
	var filling := 2 - int(e.get("ranged_left", 2)) if str(e.get("ranged_phase", "prepare")) == "prepare" else 0
	draw_rect(Rect2(p + Vector2(-39, -22), Vector2(74, 18)), Color("132b30"))
	draw_rect(Rect2(p + Vector2(-33, -34), Vector2(62, 26)), Color("44696b"))
	draw_rect(Rect2(p + Vector2(-26, -39), Vector2(39, 6)), Color("769593"))
	draw_rect(Rect2(p + Vector2(-44, -24), Vector2(26, 19 + filling * 5)), Color("b98c4f"))
	draw_rect(Rect2(p + Vector2(-40, -20), Vector2(18, 12 + filling * 5)), Color("edc47a"))
	draw_rect(Rect2(p + Vector2(-39, -34), Vector2(6, 5)), Color("101e27"))
	draw_rect(Rect2(p + Vector2(-37, -34), Vector2(3, 3)), Color("f3e2b4"))
	draw_rect(Rect2(p + Vector2(-44, -10), Vector2(38, 10)), Color("274c53"))
	draw_rect(Rect2(p + Vector2(9, -10), Vector2(34, 10)), Color("274c53"))
	draw_rect(Rect2(p + Vector2(-46, -3), Vector2(25, 4)), Color("769593"))
	draw_rect(Rect2(p + Vector2(25, -3), Vector2(22, 4)), Color("769593"))
	for i in range(2):
		draw_rect(Rect2(p + Vector2(-6 + i * 11, -33), Vector2(7, 5)), PRESSURE if i < filling else Color("243d44"))

func _draw() -> void:
	super._draw()
	for projectile in projectiles:
		if int(projectile.hp) <= 0: continue
		var index := Ranged.target_id(projectile)
		var point := enemy_position(index)
		Pixel.shadow(self, Vector2(point.x, player_feet().y), 30)
		for i in range(3):
			draw_rect(Rect2(point + Vector2(15 + i * 8, -2), Vector2(5, 4)), Color(PRESSURE, 0.5 - i * 0.12))
		draw_rect(Rect2(point - Vector2(12, 6), Vector2(24, 12)), Color("916444"))
		draw_rect(Rect2(point - Vector2(7, 11), Vector2(14, 22)), Color("c89856"))
		draw_rect(Rect2(point - Vector2(7, 6), Vector2(15, 12)), PRESSURE)
		draw_rect(Rect2(point - Vector2(7, 4), Vector2(5, 5)), Color("fff0ce"))
		if index == target:
			for side in [-1, 1]:
				draw_rect(Rect2(point + Vector2(side * 17 - 1, -13), Vector2(2, 26)), Color("fff0ce"))
		var rect := projectile_label_rect(projectile)
		draw_rect(rect, Color("101e27", 0.9))
		draw_string(FONT, rect.position + Vector2(4, 21), projectile_caption(projectile), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 8, 18, PRESSURE)

func _get_tooltip(at_position: Vector2) -> String:
	for projectile in projectiles:
		if int(projectile.hp) > 0 and (enemy_position(Ranged.target_id(projectile)).distance_to(at_position) <= 24 or projectile_label_rect(projectile).has_point(at_position)):
			return "압력탄 · %dm · 도달 %d턴\n가장 가까워지면 다음 탄으로 요격합니다. 산개도 확정 요격.\n증폭·전이는 요격해도 발동합니다. 0m에 닿으면 패배합니다." % [projectile.distance, Ranged.arrival(projectile)]
	return super._get_tooltip(at_position)

func _gui_input(event: InputEvent) -> void:
	if inspection_enabled and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for projectile in projectiles:
			if int(projectile.hp) > 0 and (enemy_position(Ranged.target_id(projectile)).distance_to(event.position) <= 24 or projectile_label_rect(projectile).has_point(event.position)):
				projectile_inspected.emit(Ranged.target_id(projectile))
				accept_event()
				return
	super._gui_input(event)

func _after_advance_tick(events: Array) -> void:
	for event in events:
		match str(event.kind):
			"projectile_move":
				var projectile := _visual_entity(int(event.target))
				caption = "압력탄 접근" if int(event.to) > 0 else "압력탄 도달"
				await _animate(0.28, func(t: float): projectile.distance = lerpf(float(event.from), float(event.to), t * t * (3.0 - 2.0 * t)))
				visual_events.append(event.duplicate(true))
			"projectile_launch":
				projectiles = [event.projectile.duplicate(true)]
				enemies[int(event.source)].ranged_phase = "waiting"
				enemies[int(event.source)].ranged_left = 0
				caption = "압력탄 발사 · 도달 %d턴" % Ranged.arrival(event.projectile)
				_feedback("projectile_launch", event)
				await _animate(0.24, func(_t: float): pass)
			"ranged_prepare", "ranged_recover":
				enemies[int(event.target)].ranged_phase = str(event.phase)
				enemies[int(event.target)].ranged_left = int(event.left)
				visual_events.append(event.duplicate(true))
	_feedback("projectiles_updated", {"projectiles": projectiles.duplicate(true)})
