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
var region := 0
const FONT = preload("res://redesign/ui_font.tres")
var display_state: Dictionary = {}
var enemies: Array = []
var projectiles: Array = []
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
var compact_ui := false
var march_phase := 0.0
var impact_attribute := "physical"
var focus_flash := -1

func _ready() -> void:
	custom_minimum_size.y = 264
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(_place_info_buttons)
	mouse_exited.connect(func(): hovered = -1; queue_redraw())

func sync(state: Dictionary, prediction: Dictionary = {}) -> void:
	display_state = {"course": state.get("course", false), "floor": state.floor, "gun": state.gun}
	enemies = state.enemies.duplicate(true)
	projectiles = state.get("projectiles", []).duplicate(true)
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
			button.position = enemy_plaque(index).position
			button.size = enemy_plaque(index).size
	for i in range(reserve_buttons.size()):
		reserve_buttons[i].position = Vector2(156 + i * 28, size.y - 44)
		reserve_buttons[i].size = Vector2(26, 28)

func _enemy_at(point: Vector2) -> int:
	for i in _alive_indices():
		if enemy_plaque(i).has_point(point) or Rect2(enemy_position(i) - Vector2(50, 55), Vector2(100, 100)).has_point(point): return i
	return -1

func _enemy_text(index: int) -> String:
	var e: Dictionary = enemies[index]
	var weakness := " · 전기 약점 +2" if str(e.get("weakness", "")) == "electric" else ""
	var focus := "\n집중 %d/3 · 3회 적중마다 추가 피해 4" % int(e.get("focus_hits", 0)) if str(display_state.get("gun", "")) == "burst" else ""
	return "%s · %s\nHP %d/%d · 장갑 %d · 화상 %d%s\n거리 %dm · 접근 %dm\n%s%s\n누르면 상세 정보를 엽니다" % [Forecast.tag(index), e.name, e.hp, e.max_hp, e.def, e.burn, weakness, roundi(e.distance), e.speed, Content.enemy_rule(e), focus]

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

func _draw_enemy_actor(index: int, foot: Vector2, lift: float, stride: float) -> void:
	Pixel.sprite(self, str(enemies[index].kind), foot - Vector2(0, lift + stride) + _actor_offset(index))

func ground_y() -> float:
	return size.y - 76.0

func enemy_feet(index: int) -> Vector2:
	# Stable formation offsets keep equal-distance actors readable. Distance still
	# drives each actor's approach; exact values and targeting live on its plaque.
	var x := 186.0 + clampf(float(enemies[index].distance) / 32.0, 0.0, 1.0) * (size.x - 556.0) + _lane(index) * 96.0
	# Lane belongs to the enemy identity, never the current alive-list index.
	return Vector2(x, ground_y() + 16.0 + _lane(index) * 12.0).round()

func enemy_position(index: int) -> Vector2:
	return enemy_feet(index) - Vector2(0, 48)

func enemy_plaque(index: int) -> Rect2:
	var width := minf(210, (size.x - 244.0) / 4.0 - 8)
	var order := _alive_indices()
	order.sort_custom(func(a, b):
		if is_equal_approx(enemy_feet(a).x, enemy_feet(b).x): return _lane(a) < _lane(b)
		return enemy_feet(a).x < enemy_feet(b).x
	)
	var lefts: Dictionary = {}
	var edge := 238.0
	for i in order:
		lefts[i] = maxf(edge, enemy_feet(i).x - width * 0.5)
		edge = float(lefts[i]) + width + 8
	edge = size.x - 8.0
	order.reverse()
	for i in order:
		lefts[i] = minf(float(lefts[i]), edge - width)
		edge = float(lefts[i]) - 8
	return Rect2(Vector2(float(lefts.get(index, 238)), 12).round(), Vector2(width, 84).floor())

func _forecast_hp(index: int) -> int:
	if forecast.is_empty() or index >= forecast.get("enemies", []).size(): return -1
	var projected: Dictionary = forecast.enemies[index]
	return int(projected.get("hp_max", projected.get("hp", -1)))

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
	_draw_backdrop()
	var muzzle := player_muzzle()
	_draw_player(player_feet())
	draw_string(FONT, Vector2(18, 31), "접근 전열", HORIZONTAL_ALIGNMENT_LEFT, 200, 20, Color("b4c7c5"))
	draw_string(FONT, Vector2(18, 55), "0m에 닿기 전에 처치", HORIZONTAL_ALIGNMENT_LEFT, 210, 15, Color("90a5af"))
	# The threshold is painted on the floor instead of a tall UI wall.
	for y in range(int(ground_y()) + 8, int(size.y) - 18, 8):
		draw_rect(Rect2(170, y, 8, 4), Color("c57a62"))
	if flash > 0:
		draw_rect(Rect2(muzzle - Vector2(2, 4), Vector2(14, 8)), Color(1, 0.83, 0.43, flash))
		draw_rect(Rect2(muzzle + Vector2(12, -2), Vector2(6, 4)), Color(1, 0.96, 0.79, flash))
	# Fixed depth order; defeated enemies do not reshuffle the surviving sprites.
	var ordered := _alive_indices()
	ordered.sort_custom(func(a, b): return _lane(a) < _lane(b))
	for i in ordered:
		var e: Dictionary = enemies[i]
		var foot := enemy_feet(i)
		var floating := str(e.kind) in ["caster", "absorber", "stance"]
		Pixel.shadow(self, foot, 76 if str(e.kind) == "wall" else 64)
		var lift := 18.0 if floating else 0.0
		var stride := roundf(sin(march_phase + i) * 2.0) if march_phase != 0.0 else 0.0
		_draw_enemy_actor(i, foot, lift, stride)
		var mark := foot + Vector2(-38, 0)
		draw_rect(Rect2(mark - Vector2(12, 18), Vector2(24, 22)), Color("edc47a") if i == target else Color("243e49"))
		draw_string(FONT, mark + Vector2(-10, 0), Forecast.tag(i), HORIZONTAL_ALIGNMENT_CENTER, 20, 17, Color("101820") if i == target else Color("ecede0"))
		if i == hovered or i == target:
			var c := Color("edc47a") if i == target else Color("f2eee3")
			for side in [-1, 1]:
				draw_rect(Rect2(foot + Vector2(side * 50 - 2, -8), Vector2(4, 12)), c)
				draw_rect(Rect2(foot + Vector2(side * 50 - (10 if side > 0 else 0), 0), Vector2(12, 4)), c)
		if new_enemy_indices.has(i) and deployment_flash > 0:
			draw_rect(Rect2(foot - Vector2(48, 116), Vector2(96, 116)), Color(0.47, 0.79, 0.93, deployment_flash * 0.32), false, 2)
		_draw_enemy_plaque(i)
	if not reinforcements.is_empty():
		draw_rect(Rect2(8, size.y - 45, 144 + reinforcements.size() * 28, 28), Color("101e27"))
		draw_string(FONT, Vector2(18, size.y - 24), "후속 %d기" % reinforcements.size(), HORIZONTAL_ALIGNMENT_LEFT, 126, 16, Color("acbbc1"))
		for i in range(reinforcements.size()):
			var art := Pixel.texture(str(reinforcements[i].kind))
			if art != null:
				var extent := art.get_size()
				var fitted := extent * minf(24.0 / extent.x, 22.0 / extent.y)
				draw_texture_rect(art, Rect2(Vector2(157 + i * 28, size.y - 43) + (Vector2(24, 24) - fitted) * 0.5, fitted), false, Color("869ea8"))
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
			var spread: bool = str(secondary.get("kind", "arc")) == "spread"
			var color := Color("87c9df") if spread else Ammo.COLORS.arc
			draw_line(muzzle if spread else point, other_point, Color(color, 1.0 - pulse), 2, false)
		_draw_impact(point)
		draw_string(FONT, _damage_position(point), float_text, HORIZONTAL_ALIGNMENT_CENTER, 160, _damage_font_size(), float_color)
	if not caption.is_empty():
		draw_string(FONT, Vector2(10, size.y - 1), caption, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 12, Color("acbbc1"))

func _draw_enemy_plaque(index: int) -> void:
	var e: Dictionary = enemies[index]
	var rect := enemy_plaque(index)
	var p := rect.position
	var selected := index == target
	var color := Color("edc47a") if selected else Color("647f8a")
	draw_rect(rect, Color("12222c"))
	draw_rect(Rect2(p, Vector2(rect.size.x, 2)), color)
	draw_rect(Rect2(p + Vector2(8, 10), Vector2(27, 27)), color if selected else Color("2c444e"))
	draw_string(FONT, p + Vector2(8, 31), Forecast.tag(index), HORIZONTAL_ALIGNMENT_CENTER, 27, 20, Color("101820") if selected else Color("ecede0"))
	var hp := str(int(e.hp))
	var predicted := _forecast_hp(index)
	if forecast.get("random", false) and index < forecast.get("enemies", []).size():
		var projected: Dictionary = forecast.enemies[index]
		if int(projected.get("hp_min", e.hp)) != int(projected.get("hp_max", e.hp)):
			hp += " → %d~%d" % [int(projected.hp_min), int(projected.hp_max)]
		elif predicted != int(e.hp): hp += " → %d" % predicted
	elif predicted >= 0 and predicted != int(e.hp): hp += " → %d" % predicted
	draw_string(FONT, p + Vector2(44, 32), hp, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 52, 18 if hp.length() > 8 else 23, Color("f2eee3"))
	var bar := Rect2(p + Vector2(44, 39), Vector2(rect.size.x - 52, 4))
	draw_rect(bar, Color("354b55"))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(e.hp) / maxf(1, e.max_hp), 4)), Color("9bbba2"))
	if str(display_state.get("gun", "")) == "burst":
		for pip in range(3):
			var lit := pip < int(e.get("focus_hits", 0)) or focus_flash == index
			draw_rect(Rect2(p + Vector2(8 + pip * 10, 39), Vector2(7, 5)), Color("edc47a") if lit else Color("3f5560"))
	if predicted >= 0 and predicted < int(e.hp):
		var ratio := float(predicted) / maxf(1, e.max_hp)
		draw_rect(Rect2(bar.position + Vector2(bar.size.x * ratio, 0), Vector2(bar.size.x * (float(e.hp) - predicted) / maxf(1, e.max_hp), 4)), Color("d99970"))
	var distance := "%dm · 접근 %d" % [roundi(e.distance), int(e.speed)]
	draw_string(FONT, p + Vector2(8, 62), distance, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 16, 16, Color("acbbc1"))
	var states: PackedStringArray = []
	if int(e.def) > 0: states.append("장갑 %d" % int(e.def))
	if int(e.get("barrier", 0)) > 0: states.append("보호 %d" % int(e.barrier))
	if str(e.get("weakness", "")) == "electric": states.append("전기 약점")
	if int(e.get("burn", 0)) > 0: states.append("화상 %d" % int(e.burn))
	if int(e.get("charge_max", 0)) > 0: states.append("충전 %d/%d" % [int(e.get("charge", 0)), int(e.charge_max)])
	if bool(e.get("stance", false)): states.append("교대")
	if str(e.kind) == "spitter": states.append(Ranged.intent(e))
	if states.is_empty(): states.append("빠른 접근" if str(e.kind) == "runner" else "장갑 없음")
	var status := " · ".join(states)
	draw_string(FONT, p + Vector2(8, 80), status, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 16, 14, Color("78c9ed") if int(e.def) > 0 else Color("acbbc1"))
	# Plaques follow the actor's horizontal position. Packed neighbours get a stem.
	var start := rect.get_center() + Vector2(0, rect.size.y * 0.5)
	var finish := enemy_position(index) - Vector2(0, 36)
	if finish.y > start.y:
		draw_line(start.round(), finish.round(), Color("718e99") if index == hovered else Color("324956"), 1, false)

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

func play_action(before: Dictionary, after: Dictionary, results: Array, advance_events: Array, reloading: bool, deployments: Array = []) -> void:
	inspection_enabled = false
	first_shot = {}
	compact_lanes = false
	sync(before)
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
		await _animate(0.19, func(t: float): bullet_progress = t; flash = 1.0 - t)
		bullet = ""
		var enemy := _visual_entity(target)
		enemy.hp = result.hp
		enemy.burn = result.get("burn", 0)
		enemy.focus_hits = result.get("focus_after", 0)
		enemy.barrier = result.get("barrier", enemy.get("barrier", 0))
		chain_targets = result.get("secondary", []).duplicate(true)
		for secondary in chain_targets:
			_visual_entity(int(secondary.target)).hp = secondary.hp
			visual_events.append({"kind": "secondary", "target": secondary.target, "damage": secondary.damage, "hp": secondary.hp})
		float_target = target
		impact_attribute = str(Content.AMMO[str(result.id)].attribute)
		float_text = "막힘" if int(result.get("blocked_hits", 0)) > 0 and result.damage == 0 else ("방어" if result.damage == 0 else "-%d" % result.damage)
		if result.get("intercept", false): float_text = "요격"
		elif result.hp == 0: float_text += "  처치"
		float_color = Color("63dce8") if int(result.get("blocked_hits", 0)) > 0 else (Color("f0b495") if result.damage == 0 else Color("d7eeae"))
		caption = "%s · %s" % [Ammo.SHORT[result.id], float_text]
		if int(result.get("focus_damage", 0)) > 0: focus_flash = target
		shot_impacted.emit(result)
		for effect in result.get("part_effects", []):
			visual_events.append({"kind": "part", "id": effect.id, "label": effect.label, "target": target, "bullet": result.id})
		visual_events.append({"kind": "impact", "target": target, "hp": result.hp, "push": result.push})
		await _hold_impact(result)
		var distance := float(enemy.distance)
		await _animate(0.27, func(t: float): pulse = t; enemy.distance = lerpf(distance, distance + float(result.push), t))
		float_target = -1
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
		enemies[burn_target].hp = event.hp
		enemies[burn_target].burn = event.burn
		float_target = burn_target
		float_text = "화상 -%d" % event.damage
		if int(event.hp) == 0: float_text += "  처치"
		impact_attribute = "fire"
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
		march_phase = t * TAU * 2
		for i in range(mini(enemies.size(), after.enemies.size())):
			enemies[i].distance = lerpf(float(starts[i].distance), float(after.enemies[i].distance), t)
	)
	march_phase = 0.0
