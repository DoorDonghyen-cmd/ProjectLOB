@tool
extends "res://redesign/samples/tower_battle_view.gd"
## Visual feedback only. Every approach is replayed from the model's turn events.
signal feedback_changed(event: Dictionary)
const HOT := Color("ed9167")
const BOOST := Color("edc47a")
var reduced_feedback := false
var heat_debt := 0
var heat_clock := 0.0
var charge_phase := 0.0
var shot_power := 0.0
var impact_power := 0.0
var impact_blocked := false
var boost_value := 0
var reload_tick := 0
var reload_total := 0
var reload_base := 0
var reload_progress := 0.0
var cooling := false
var feedback_stage := "idle"

func sync(state: Dictionary, prediction: Dictionary = {}) -> void:
	super.sync(state, prediction)
	heat_debt = int(state.get("reload_heat", 0))
	reload_base = maxi(1, int(Content.GUNS[state.gun].reload) + Content.reload_modifier(state))
	_update_heat_readout()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or reduced_feedback or heat_debt <= 0: return
	heat_clock = fmod(heat_clock + delta, 20.0)
	queue_redraw()

func _feedback(stage: String, detail: Dictionary = {}) -> void:
	feedback_stage = stage
	var event := detail.duplicate(true)
	event.kind = stage
	visual_events.append(event)
	feedback_changed.emit(event)
	_update_heat_readout()

func _update_heat_readout() -> void:
	var readout := get_node_or_null("HeatReadout") as Label
	if readout == null: return
	readout.visible = heat_debt > 0 or reload_tick > 0
	if reload_tick > 0:
		readout.text = "%s  %d/%d턴" % ["추가 냉각" if cooling else "재장전", reload_tick, reload_total]
	else:
		readout.text = "과열  +%d턴" % heat_debt
	readout.add_theme_color_override("font_color", HOT if heat_debt > 0 or cooling else Color("b4c7c5"))

func _recoil() -> Vector2:
	return Vector2.ZERO if reduced_feedback else Vector2(-roundf(flash * shot_power * 7.0), 0)

func player_muzzle() -> Vector2:
	return super.player_muzzle() + _recoil()

func _draw_player(foot: Vector2) -> void:
	super._draw_player(foot + _recoil())

func _actor_offset(index: int) -> Vector2:
	if reduced_feedback or index != float_target: return Vector2.ZERO
	# This is a short visual hit reaction, never the enemy's simulated distance.
	return Vector2(roundf(impact_power * 7.0 * (1.0 - pulse) * (1.0 - pulse)), 0)

func _damage_font_size() -> int:
	return 25 if impact_power <= 0 else (34 if impact_power >= 0.9 else 29)

func _damage_position(point: Vector2) -> Vector2:
	var position := super._damage_position(point)
	# Short mobile fields have no room above the actors: keep the entire number
	# below the fixed 96px plaques and the 99px heat label instead of shrinking it.
	position.y = maxf(position.y, 102.0 + FONT.get_ascent(_damage_font_size()))
	return position.round()

func _prepare_shot(result: Dictionary) -> void:
	boost_value = int(result.get("math", {}).get("boost", 0))
	shot_power = minf(1.0, float(boost_value) / 4.0)
	impact_power = 0.0
	impact_blocked = false
	var added := int(result.get("heat_added", 0))
	if added > 0:
		heat_debt += added
		shot_power = maxf(shot_power, 0.7)
		_feedback("heat_added", {"heat": heat_debt, "added": added, "base": reload_base})
		charge_phase = 1.0
		await _animate(0.18 if not reduced_feedback else 0.03, func(t: float): charge_phase = 1.0 - t)
		charge_phase = 0.0
	_feedback("powered_shot" if boost_value > 0 else "plain_shot", {"boost": boost_value, "target": int(result.target)})

func _hold_impact(result: Dictionary) -> void:
	impact_blocked = int(result.damage) == 0 and int(result.get("blocked_hits", 0)) > 0
	impact_power = minf(1.0, float(boost_value) / 4.0) if int(result.damage) > 0 else 0.0
	if impact_power > 0: float_color = HOT if boost_value >= 4 else BOOST
	var grant := int(result.get("boost_granted", 0))
	if grant > 0: _feedback("boost_link", {"value": grant, "count": 2})
	_feedback("powered_impact" if impact_power > 0 else "plain_impact", {"boost": boost_value, "damage": int(result.damage), "blocked": impact_blocked, "target": int(result.target)})
	if impact_power > 0 and not reduced_feedback:
		# Hold this visual frame only; do not pause the tree, timers or input.
		await _animate(0.065 if boost_value >= 4 else 0.035, func(_t: float): pass)

func _finish_shot() -> void:
	shot_power = 0.0
	impact_power = 0.0
	impact_blocked = false
	boost_value = 0

func _after_advance_tick(_events: Array) -> void:
	pass

func _draw() -> void:
	super._draw()
	var muzzle := player_muzzle()
	if charge_phase > 0 and not reduced_feedback:
		for i in range(4):
			var offset := Vector2.from_angle(i * PI * 0.5) * (6 + charge_phase * 22)
			draw_rect(Rect2((muzzle + offset).round(), Vector2(4, 4)), HOT)
	if flash > 0 and shot_power > 0:
		var reach := (16.0 if reduced_feedback else 38.0) * shot_power * flash
		var color := HOT if boost_value >= 4 or heat_debt > 0 else BOOST
		var p := muzzle.round()
		draw_rect(Rect2(p + Vector2(4, -4), Vector2(roundf(reach), 8)), Color(color, flash))
		if not reduced_feedback:
			draw_rect(Rect2(p + Vector2(9, -10), Vector2(roundf(reach * 0.5), 20)), Color(color, flash * 0.8))
			draw_rect(Rect2(p + Vector2(6, -2), Vector2(roundf(reach + 6), 4)), Color("fff0cd"))
	if not bullet.is_empty() and projectile_target >= 0 and shot_power > 0:
		var to := enemy_position(projectile_target)
		var point := muzzle.lerp(to, bullet_progress).round()
		var direction := (to - muzzle).normalized()
		var color := HOT if boost_value >= 4 else BOOST
		draw_line((point - direction * (28 + shot_power * 28)).round(), point, color, 6 if not reduced_feedback else 4, false)
		draw_rect(Rect2(point - Vector2(4, 2), Vector2(8, 4)), Color("fff0cd"))
	if heat_debt > 0:
		# The hot barrel remains visibly hot until the next reload resolves.
		draw_rect(Rect2(muzzle + Vector2(-16, 1), Vector2(18, 3)), HOT)
		if not reduced_feedback:
			for i in range(5):
				var age := fmod(heat_clock * (1.8 if cooling else 0.65) + i * 0.2, 1.0)
				var drift := sin(age * 5 + i) * 7
				var point := (muzzle + Vector2(-12 + drift, -4 - age * (42 if cooling else 28))).round()
				draw_rect(Rect2(point, Vector2(4 + floorf(age * 2) * 2, 4)), Color("a1b4b5", (1.0 - age) * 0.65))
	if heat_debt > 0:
		_draw_heat_symbol(Vector2(18, 79), HOT)
	elif reload_tick > 0:
		draw_rect(Rect2(19, 78, 14, 14), Color("b4c7c5"), false, 2)
		draw_polyline(PackedVector2Array([Vector2(26, 80), Vector2(26, 85), Vector2(30, 85)]), Color("b4c7c5"), 2, false)
	if reload_tick > 0:
		# Segments represent real elapsed turns, not a second heat resource.
		var width := 196.0 / maxi(1, reload_total)
		for i in range(reload_total):
			var rect := Rect2(18 + floorf(i * width), 102, maxf(1, floorf(width) - 3), 4)
			draw_rect(rect, Color("334953"))
			var progress := 1.0 if i < reload_tick - 1 else (reload_progress if i == reload_tick - 1 else 0.0)
			draw_rect(Rect2(rect.position, Vector2(floorf(rect.size.x * progress), 4)), HOT if i >= reload_base else Color("b4c7c5"))

func _draw_heat_symbol(point: Vector2, color: Color) -> void:
	for i in range(3):
		var p := point + Vector2(i * 6, 0)
		draw_polyline(PackedVector2Array([p + Vector2(0, 11), p + Vector2(0, 7), p + Vector2(2, 7), p + Vector2(2, 3), p + Vector2(4, 3), p + Vector2(4, 0)]), color, 2, false)

func _draw_impact(point: Vector2) -> void:
	if impact_power <= 0:
		if impact_blocked:
			var radius := 14 + roundf(pulse * 14)
			draw_rect(Rect2(point - Vector2(radius, radius), Vector2.ONE * radius * 2), Color("78c9ed", 1.0 - pulse), false, 3)
		else: super._draw_impact(point)
		return
	var color := HOT if boost_value >= 4 else BOOST
	color.a = 1.0 - pulse
	var radius := 8.0 + pulse * (24.0 if reduced_feedback else 42.0) * impact_power
	for i in range(8 if not reduced_feedback else 4):
		var direction := Vector2.from_angle(i * TAU / (8 if not reduced_feedback else 4))
		var p := (point + direction * radius).round()
		draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), color)
	if pulse < 0.25:
		var extent := 12.0 if reduced_feedback else 26.0
		draw_rect(Rect2(point - Vector2(extent, 3), Vector2(extent * 2, 6)), Color("fff0cd"))
		draw_rect(Rect2(point - Vector2(3, extent), Vector2(6, extent * 2)), Color("fff0cd"))

func _play_advance(before: Dictionary, after: Dictionary, events: Array, reloading: bool) -> void:
	# Unlike interpolating directly to 'after', this preserves burn/pull/move/stance
	# ordering and partial reloads that end in victory or contact.
	var elapsed := int(after.turns) - int(before.turns)
	if events.is_empty() and not reloading: elapsed = 0
	reload_total = reload_base + int(before.get("reload_heat", 0)) if reloading else 0
	for tick in range(elapsed):
		reload_tick = tick + 1 if reloading else 0
		cooling = reloading and tick >= reload_base
		reload_progress = 0.0
		_feedback("cooling_turn" if cooling else ("reload_turn" if reloading else "enemy_turn"), {"turn": tick, "total": reload_total, "heat": heat_debt})
		if reloading:
			await _animate(0.16, func(_t: float): pass)
		var tick_events: Array = events.filter(func(event): return int(event.get("turn", 0)) == tick)
		for event in tick_events:
			if event.kind != "burn": continue
			var index := int(event.target)
			enemies[index].hp = int(event.hp)
			enemies[index].burn = int(event.burn)
			float_target = index
			float_text = "화상 -%d%s" % [event.damage, "  처치" if int(event.hp) == 0 else ""]
			impact_attribute = "fire"
			float_color = Ammo.ATTRIBUTE_COLORS.fire
			visual_events.append(event.duplicate(true))
			await _animate(0.24, func(t: float): pulse = t)
			float_target = -1
			pulse = 0.0
		for event in tick_events:
			if event.kind == "charge":
				enemies[int(event.target)].charge = int(event.charge)
				visual_events.append(event.duplicate(true))
			elif event.kind == "pull":
				caption = "지원 개입 · 강제 접근"
				await _animate(0.16, func(t: float): enemies[int(event.target)].distance = lerpf(float(event.from), float(event.to), t * t * (3.0 - 2.0 * t)))
				visual_events.append(event.duplicate(true))
		# Pull and ordinary movement remain distinct; a lethal pull has no move.
		var moves: Array = tick_events.filter(func(event): return str(event.kind) == "move")
		if not moves.is_empty():
			caption = "추가 냉각 · 적이 한 번 더 접근" if cooling else ("재장전 · 적 접근" if reloading else "적 접근")
			await _animate(0.38, func(t: float):
				var eased := t * t * (3.0 - 2.0 * t)
				march_phase = t * TAU * 2 if not reduced_feedback else 0.0
				reload_progress = t
				for event in moves: enemies[int(event.target)].distance = lerpf(float(event.from), float(event.to), eased)
			)
			for event in moves: visual_events.append(event.duplicate(true))
		march_phase = 0.0
		for event in tick_events:
			if event.kind == "stance":
				enemies[int(event.target)].def = int(event.def)
				enemies[int(event.target)].stance_closed = bool(event.closed)
				visual_events.append(event.duplicate(true))
		await _after_advance_tick(tick_events)
		reload_progress = 1.0
		_feedback("turn_complete", {"turn": tick, "cooling": cooling, "shown_enemies": enemies.duplicate(true)})
		if reloading: await _animate(0.18, func(_t: float): pass)
	if reloading:
		heat_debt = 0
		reload_tick = 0
		cooling = false
		_feedback("reload_complete", {"phase": after.phase, "turns": elapsed})
	elif after.phase in ["reward", "won", "lost"]:
		heat_debt = 0
	_update_heat_readout()
