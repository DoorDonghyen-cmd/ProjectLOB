@tool
extends "res://redesign/samples/tower_battle_view.gd"
## Visual feedback only. Every approach is replayed from the model's turn events.
signal feedback_changed(event: Dictionary)
const HOT := Color("ed9167")
const BOOST := Color("edc47a")
const CombatVFX = preload("res://redesign/combat_vfx.gd")
const Payoff = preload("res://redesign/combat_payoff.gd")
var salvo_damage := 0
var salvo_kills: Array = []
var payoff_tier := 0
var payoff_last: Dictionary = {}
var armor_chips := false
var cooling_puff := 0.0
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
var thermal_release := 0.0
var overheat_lock := 0.0

func sync(state: Dictionary, prediction: Dictionary = {}) -> void:
	super.sync(state, prediction)
	salvo_damage = 0
	salvo_kills.clear()
	payoff_tier = 0
	payoff_last = {}
	armor_chips = false
	cooling_puff = 0.0
	thermal_release = 0.0
	heat_debt = int(state.get("heat", 0))
	reload_base = maxi(1, int(Content.GUNS[state.gun].reload) + Content.reload_modifier(state))
	_update_heat_readout()

func _process(delta: float) -> void:
	super._process(delta)
	delta*=visual_clock_scale()
	if cooling_puff > 0:
		cooling_puff = maxf(0.0, cooling_puff-delta/0.42)
		queue_redraw()
	if Engine.is_editor_hint() or reduced_feedback or heat_debt <= 0: return
	heat_clock = fmod(heat_clock + delta, 20.0)
	queue_redraw()

func actor_motion_enabled() -> bool:
	return not reduced_feedback

func _weapon_heat() -> float:
	if display_state.is_empty(): return 0.0
	return clampf(float(heat_debt) / maxf(1.0, Content.heat_limit(display_state)), 0.0, 1.0)

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
	readout.visible = reload_tick > 0
	if reload_tick > 0:
		readout.text = "%s  %d/%d턴" % ["추가 냉각" if cooling else "재장전", reload_tick - reload_base if cooling else reload_tick, reload_total - reload_base if cooling else reload_base]
	else:
		readout.text = "총열  %d" % heat_debt
	readout.add_theme_color_override("font_color", HOT if heat_debt > 0 or cooling else Color("b4c7c5"))

func _recoil() -> Vector2:
	return Vector2.ZERO if reduced_feedback else Vector2(-roundf(flash * (2.0 + shot_power * 5.0)), 0)

func player_muzzle() -> Vector2:
	return super.player_muzzle() + _recoil()

func _draw_player(foot: Vector2) -> void:
	super._draw_player(foot + _recoil())

func _actor_offset(index: int) -> Vector2:
	if reduced_feedback or not damage_popups.any(func(entry): return int(entry.target)==index and int(entry.amount)>0): return Vector2.ZERO
	# This is a short visual hit reaction, never the enemy's simulated distance.
	return Vector2(roundf(maxf(impact_power, actor_hit_strength) * 7.0 * (1.0 - pulse) * (1.0 - pulse)), 0)

func _damage_font_size() -> int:
	return 25 if impact_power <= 0 else (34 if impact_power >= 0.9 else 29)

func _damage_position(point: Vector2) -> Vector2:
	var position := super._damage_position(point)
	# Follow the actual overhead HUD bounds, including temporary status rows.
	position.y = maxf(position.y, 102.0 + FONT.get_ascent(_damage_font_size()))
	for index in _alive_indices():
		var hud := enemy_plaque(index)
		if position.x < hud.end.x and position.x + 160 > hud.position.x:
			position.y = maxf(position.y, hud.end.y + 4 + FONT.get_ascent(_damage_font_size()))
	return position.round()

func _prepare_shot(result: Dictionary) -> void:
	hero_action = "aim"
	actor_hit_strength = 0.0
	boost_value = int(result.get("math", {}).get("boost", 0)) + int(result.get("thermal_bonus", 0)) + int(result.get("vent_bonus", 0))
	boost_value += maxi(0, int(result.get("math", {}).get("factor", 1)) - 1) * 4
	shot_power = minf(1.0, float(boost_value) / 4.0)
	impact_power = 0.0
	impact_blocked = false
	armor_chips = false
	heat_debt = int(result.get("heat_before", heat_debt))
	# Kill/third-shot cooling resolves on impact, not before the shot is fired.
	var removed := int(result.get("cooled", 0)) - int(result.get("kill_cooled", 0)) - int(result.get("chain_cooled", 0))
	if removed > 0:
		cooling_puff = 1.0 if not reduced_feedback else 0.0
		heat_debt = maxi(0, heat_debt - removed)
		_feedback("heat_removed", {"heat": heat_debt, "removed": removed, "base": reload_base})
	var added := int(result.get("heat_added", 0))
	if added > 0:
		heat_debt += added
		if added >= 5 or result.get("overheated", false): shot_power = maxf(shot_power, 0.7)
		_feedback("heat_added", {"heat": heat_debt, "added": added, "base": reload_base})
		charge_phase = 1.0
		if added >= 5: await _animate(0.18 if not reduced_feedback else 0.03, func(t: float): charge_phase = 1.0 - t)
		charge_phase = 0.0
	_feedback("powered_shot" if boost_value > 0 else "plain_shot", {"boost": boost_value, "target": int(result.target)})
	hero_action = "fire"

func _hold_impact(result: Dictionary) -> void:
	payoff_last = Payoff.describe(result)
	salvo_damage += int(payoff_last.damage)
	for killed in payoff_last.targets:
		if not salvo_kills.has(killed): salvo_kills.append(killed)
	payoff_tier = maxi(int(payoff_last.tier),2 if salvo_kills.size()>=2 else 0)
	if payoff_tier>0: _feedback("salvo_payoff",{"damage":salvo_damage,"kills":salvo_kills.size(),"tier":payoff_tier})
	armor_chips = int(result.get("armor_removed", 0)) > 0
	if armor_chips: _feedback("armor_break", {"target": int(result.target), "removed": int(result.armor_removed)})
	if int(result.get("kill_cooled", 0)) + int(result.get("chain_cooled", 0)) > 0:
		cooling_puff = 1.0 if not reduced_feedback else 0.0
	actor_hit_strength = clampf(float(result.damage) / 15.0, 0.35, 0.8) if int(result.damage) > 0 else 0.0
	heat_debt = int(result.get("heat_after", heat_debt))
	if int(result.get("kill_cooled", 0)) > 0:
		_feedback("kill_cooling", {"heat": heat_debt, "removed": int(result.kill_cooled), "base": reload_base})
	impact_blocked = int(result.damage) == 0 and int(result.get("blocked_hits", 0)) > 0
	impact_power = minf(1.0, float(boost_value) / 4.0) if int(result.damage) > 0 else 0.0
	if int(payoff_last.tier)>0: impact_power = maxf(impact_power,0.9 if int(payoff_last.tier)==2 else 0.65)
	if impact_power > 0: float_color = HOT if boost_value >= 4 else BOOST
	var grant := int(result.get("boost_granted", 0))
	if grant > 0 or int(result.get("boost_factor_granted", 1)) > 1: _feedback("boost_link", {"value": grant, "count": int(result.get("boost_rounds", 2))})
	_feedback("powered_impact" if impact_power > 0 else "plain_impact", {"boost": boost_value, "damage": int(result.damage), "blocked": impact_blocked, "target": int(result.target)})
	if result.get("overheated", false):
		overheat_lock = 1.0
		_feedback("overheat_lock", {"heat": heat_debt})
		if not reduced_feedback:
			await _animate(0.12, func(t: float): overheat_lock = 1.0 - t)
		overheat_lock = 0.0
	if int(result.hp) == 0 and int(result.damage) > 0 and impact_power <= 0 and not reduced_feedback:
		await _animate(0.035, func(_t: float): pass)
	if impact_power > 0 and not reduced_feedback:
		# Hold this visual frame only; do not pause the tree, timers or input.
		await _animate(0.10 if int(payoff_last.tier)==2 else (0.065 if boost_value >= 4 else 0.035), func(_t: float): pass)

func _finish_shot() -> void:
	armor_chips = false
	hero_action = "aim"
	actor_hit_strength = 0.0
	shot_power = 0.0
	impact_power = 0.0
	impact_blocked = false
	boost_value = 0

func _after_advance_tick(_events: Array) -> void:
	pass

func _charge_released(_event: Dictionary) -> void:
	pass

func _draw() -> void:
	super._draw()
	if payoff_tier>0 and not fast_forward:
		var label := "%d기 처치" % salvo_kills.size() if salvo_kills.size()>=2 else "강력한 일격"
		draw_rect(Rect2(18,15,3,41),BOOST)
		draw_string_outline(FONT,Vector2(28,33),label,HORIZONTAL_ALIGNMENT_LEFT,220,24,4,Color("11222a"))
		draw_string(FONT,Vector2(28,33),label,HORIZONTAL_ALIGNMENT_LEFT,220,24,BOOST)
		draw_string_outline(FONT,Vector2(28,54),"이번 사격 %d피해" % salvo_damage,HORIZONTAL_ALIGNMENT_LEFT,220,16,3,Color("11222a"))
		draw_string(FONT,Vector2(28,54),"이번 사격 %d피해" % salvo_damage,HORIZONTAL_ALIGNMENT_LEFT,220,16,Color("e7e4d9"))
	draw_set_transform_matrix(finish_camera())
	if not reduced_feedback and not fast_forward:
		for entry in damage_popups:
			if not entry.kill or int(entry.target)>=10000: continue
			var center := enemy_position(int(entry.target))
			for i in range(6):
				var direction := Vector2.from_angle(-PI*0.9+i*PI*0.16)
				var point := (center+direction*(10+pulse*28)+Vector2(0,pulse*pulse*20)).snapped(Vector2(2,2))
				draw_rect(Rect2(point,Vector2(4,2) if i%2==0 else Vector2(2,4)),Color(BOOST,1.0-pulse))
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
		# Persistent heat lives on the weapon texture, never a floating rectangle.
		if not reduced_feedback:
			for i in range(5):
				var age := fmod(heat_clock * (1.8 if cooling else 0.65) + i * 0.2, 1.0)
				var drift := sin(age * 5 + i) * 7
				var point := (muzzle + Vector2(-12 + drift, -4 - age * (42 if cooling else 28))).round()
				draw_rect(Rect2(point, Vector2(4 + floorf(age * 2) * 2, 4)), Color("a1b4b5", (1.0 - age) * 0.65))
	draw_set_transform_matrix(Transform2D.IDENTITY)
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


	# Small ejected brass and a ground glint connect firing to the weapon.
	draw_set_transform_matrix(finish_camera())
	if flash > 0 and not reduced_feedback:
		var age := 1.0-flash
		var casing := (muzzle + Vector2(-22-age*24, -6-sin(age*PI)*16)).snapped(Vector2(2,2))
		draw_rect(Rect2(casing, Vector2(6,3)), Color("b89a60"))
		draw_rect(Rect2(player_feet()+Vector2(-20,1), Vector2(65,2)), Color(0.85,0.58,0.33,flash*0.3))
	if not reduced_feedback:
		if cooling and heat_debt > 0: CombatVFX.steam(self, muzzle, reload_progress)
		if thermal_release > 0: CombatVFX.steam(self, muzzle, 1.0-thermal_release)
		elif cooling_puff > 0: CombatVFX.steam(self, muzzle, 1.0-cooling_puff)
	draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_secondary_link(from: Vector2, to: Vector2, kind: String) -> void:
	if kind == "arc": CombatVFX.arc(self, from, to, pulse, reduced_feedback)
	elif kind == "heat_wave":
		var reach := 8+floorf(pulse*18)
		for side in [-1,1]:
			var edge := (to+Vector2(side*reach,-8)).snapped(Vector2(2,2))
			draw_rect(Rect2(edge,Vector2(3,16)),Color(HOT,1.0-pulse))
	elif kind in ["relay","overflow"]:
		var midpoint := Vector2(roundf((from.x+to.x)*0.5),from.y)
		var points := PackedVector2Array([from.round(),midpoint,Vector2(midpoint.x,to.y).round(),to.round()])
		draw_polyline(points,Color(BOOST,1.0-pulse),4 if kind=="overflow" else 2,false)
	else: super._draw_secondary_link(from, to, kind)

func _draw_heat_symbol(point: Vector2, color: Color) -> void:
	preload("res://redesign/ammo_visual.gd").heat_icon(self, point + Vector2(10, 5), 1.0, color)

func _draw_impact_mark(rect: Rect2, color: Color) -> void:
	# Bright impact strokes must not cut through the numbers or their captions.
	for item in damage_popup_layout():
		if rect.intersects(item.bounds.grow(3)): return
	draw_rect(rect,color)

func _draw_impact(point: Vector2) -> void:
	if armor_chips and not reduced_feedback: CombatVFX.armor(self, point, pulse)
	if impact_power <= 0:
		if impact_blocked:
			var radius := 14 + roundf(pulse * 14)
			draw_rect(Rect2(point - Vector2(radius, radius), Vector2.ONE * radius * 2), Color("78c9ed", 1.0 - pulse), false, 3)
		else:
			super._draw_impact(point)
			if not reduced_feedback and impact_attribute == "physical":
				for i in range(5):
					var offset := Vector2((10+i*5)*pulse, (i-2)*9*pulse + 16*pulse*pulse)
					draw_rect(Rect2((point+offset).snapped(Vector2(2,2)),Vector2(4,2)),Color(0.81,0.69,0.48,1.0-pulse))
		return
	var color := HOT if boost_value >= 4 else BOOST
	color.a = 1.0 - pulse
	var radius := 8.0 + pulse * (24.0 if reduced_feedback else 42.0) * impact_power
	for i in range(8 if not reduced_feedback else 4):
		var direction := Vector2.from_angle(i * TAU / (8 if not reduced_feedback else 4))
		var p := (point + direction * radius).round()
		_draw_impact_mark(Rect2(p - Vector2(3, 3), Vector2(6, 6)), color)
	if pulse < 0.25:
		var extent := 12.0 if reduced_feedback else 26.0
		_draw_impact_mark(Rect2(point - Vector2(extent, 3), Vector2(extent * 2, 6)), Color("fff0cd"))
		_draw_impact_mark(Rect2(point - Vector2(3, extent), Vector2(6, extent * 2)), Color("fff0cd"))

func _play_advance(before: Dictionary, after: Dictionary, events: Array, reloading: bool) -> void:
	# Unlike interpolating directly to 'after', this preserves burn/pull/move/stance
	# ordering and partial reloads that end in victory or contact.
	var elapsed := int(after.turns) - int(before.turns)
	if events.is_empty() and not reloading: elapsed = 0
	reload_total = reload_base + (1 if int(before.get("heat", 0)) >= Content.heat_limit(before) else 0) + int(before.get("legacy_reload_penalty", 0)) if reloading else 0
	if reloading:
		hero_action = "reload"
		hero_reload_progress = 0.0
	for tick in range(elapsed):
		reload_tick = tick + 1 if reloading else 0
		cooling = reloading and tick >= reload_base
		if reloading:
			hero_action = "cooling" if cooling else "reload"
			hero_reload_progress = minf(1.0, float(tick) / maxi(1, reload_base))
		reload_progress = 0.0
		_feedback("cooling_turn" if cooling else ("reload_turn" if reloading else "enemy_turn"), {"turn": tick, "total": reload_total, "heat": heat_debt})
		if reloading:
			await _animate(0.16, func(_t: float): pass)
		var tick_events: Array = events.filter(func(event): return int(event.get("turn", 0)) == tick)
		for event in tick_events:
			if event.kind != "burn": continue
			var index := int(event.target)
			_capture_damage_columns()
			enemies[index].hp = int(event.hp)
			enemies[index].burn = int(event.burn)
			float_target = index
			damage_popups = [preload("res://redesign/damage_readout.gd").entry(event,"burn")]
			float_text = "화상 -%d%s" % [event.damage, "  처치" if int(event.hp) == 0 else ""]
			impact_attribute = "fire"
			float_color = Ammo.ATTRIBUTE_COLORS.fire
			visual_events.append(event.duplicate(true))
			await _impact_motion(0.32, func(t: float): pulse = t)
			float_target = -1
			damage_popups.clear()
			pulse = 0.0
		for event in tick_events:
			if event.kind == "charge":
				enemies[int(event.target)].charge = int(event.charge)
				visual_events.append(event.duplicate(true))
				if bool(event.get("released",false)): await _charge_released(event)
			elif event.kind == "pull":
				caption = "지원 개입 · 강제 접근"
				await _animate(0.16, func(t: float): enemies[int(event.target)].distance = lerpf(float(event.from), float(event.to), t * t * (3.0 - 2.0 * t)))
				visual_events.append(event.duplicate(true))
		# Pull and ordinary movement remain distinct; a lethal pull has no move.
		var moves: Array = tick_events.filter(func(event): return str(event.kind) == "move")
		moving_indices = moves.filter(func(event): return float(event.from) != float(event.to)).map(func(event): return int(event.target))
		if not moves.is_empty() or reloading:
			caption = "추가 냉각 · 적이 한 번 더 접근" if cooling else ("재장전 · 적 접근" if reloading else "적 접근")
			await _animate(0.38, func(t: float):
				var eased := t * t * (3.0 - 2.0 * t)
				march_phase = t * TAU * 2 if not reduced_feedback else 0.0
				reload_progress = t
				if reloading and not cooling: hero_reload_progress = minf(1.0, float(tick + t) / maxi(1, reload_base))
				for event in moves: enemies[int(event.target)].distance = lerpf(float(event.from), float(event.to), eased)
			)
			for event in moves: visual_events.append(event.duplicate(true))
		march_phase = 0.0
		moving_indices.clear()
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
		hero_action = "idle"
		hero_reload_progress = 0.0
		heat_debt = int(after.get("heat", 0))
		reload_tick = 0
		cooling = false
		_feedback("reload_complete", {"phase": after.phase, "turns": elapsed, "heat": heat_debt})
		if not reduced_feedback and int(before.get("heat", 0)) > heat_debt:
			thermal_release = 1.0
			await _animate(0.32, func(t: float): thermal_release = 1.0-t)
		thermal_release = 0.0
	elif after.phase in ["reward", "won", "lost"]:
		heat_debt = 0
	_update_heat_readout()
