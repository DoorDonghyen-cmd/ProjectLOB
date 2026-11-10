@tool
extends "res://redesign/samples/tower_battle_view.gd"
## Visual feedback only. Every approach is replayed from the model's turn events.
signal feedback_changed(event: Dictionary)
const HOT := Color("ed9167")
const BOOST := Color("edc47a")
const SLOW_MARK := Color("b1a7cf")
const SLOW_SHADOW := Color("29243b")
const MAX_SALVO_HIT_STOP := 0.12
const CombatVFX = preload("res://redesign/combat_vfx.gd")
const Payoff = preload("res://redesign/combat_payoff.gd")
const ImpactStyle=preload("res://redesign/impact_style.gd")
const ImpactSprite=preload("res://redesign/impact_sprite.gd")
const Surface=preload("res://redesign/surface_feedback.gd")
var surface_profile:Dictionary={}
var effect_clock:=0.0
const FiringVFX=preload("res://redesign/firing_vfx.gd")
const EnhancedShot=preload("res://redesign/enhanced_shot_fx.gd")
var firing_profile:Dictionary={}
var launch_origin:=Vector2.ZERO
var launch_ready:=false
var impact_style:Dictionary={}
var salvo_damage := 0
var salvo_kills: Array = []
var payoff_tier := 0
var payoff_last: Dictionary = {}
var build_signature: Dictionary = {}
var salvo_receipt: Dictionary = {}
var salvo_results: Array = []
var receipt_is_previous := false
var impact_readout_bounds: Array = []
var armor_chips := false
var cooling_puff := 0.0
var reduced_feedback := false
var heat_debt := 0
var heat_clock := 0.0
var charge_phase := 0.0
var shot_power := 0.0
var impact_power := 0.0
var hit_stop_active := false
var hit_stop_used := 0.0
var stagger_target := -1
var impact_blocked := false
var boost_value := 0
var reload_tick := 0
var reload_total := 0
var reload_base := 0
var reload_progress := 0.0
var cooling := false
## Nonzero only when the controller replays cooling with the magazine retained.
var cooling_cost := 0
var feedback_stage := "idle"
var thermal_release := 0.0
var overheat_lock := 0.0

func sync(state: Dictionary, prediction: Dictionary = {}) -> void:
	super.sync(state, prediction)
	salvo_damage = 0
	salvo_kills.clear()
	payoff_tier = 0
	payoff_last = {}
	build_signature = {}
	impact_style={}
	surface_profile={}
	firing_profile={}
	launch_ready=false
	hit_stop_active = false
	hit_stop_used = 0.0
	stagger_target = -1
	salvo_results.clear()
	salvo_receipt = Payoff.last_receipt(state)
	receipt_is_previous = not salvo_receipt.is_empty()
	armor_chips = false
	cooling_puff = 0.0
	thermal_release = 0.0
	heat_debt = int(state.get("heat", 0))
	reload_base = maxi(1, int(Content.weapon_spec(state).reload) + Content.reload_modifier(state))
	_update_heat_readout()

func _process(delta: float) -> void:
	super._process(delta)
	delta*=visual_clock_scale()
	if cooling_puff > 0:
		cooling_puff = maxf(0.0, cooling_puff-delta/0.42)
		queue_redraw()
	if not Engine.is_editor_hint() and not reduced_feedback and not fast_forward:
		var active_fire:bool=not display_state.get("fire_zones",[]).is_empty() or enemies.any(func(e):return int(e.get("hp",0))>0 and int(e.get("burn",0))>0)
		if active_fire:
			var before:=floori(effect_clock*12)
			effect_clock=fmod(effect_clock+delta,120.0)
			if floori(effect_clock*12)!=before:queue_redraw()
	if Engine.is_editor_hint() or reduced_feedback or heat_debt <= 0: return
	var previous_heat_frame := int(heat_clock * 12.0)
	heat_clock = fmod(heat_clock + delta, 20.0)
	# Ambient steam uses stepped frames; active shot/reload tweens keep their
	# own updates. Residual heat must not redraw the entire battlefield at 120Hz.
	if int(heat_clock * 12.0) != previous_heat_frame: queue_redraw()

func actor_motion_enabled() -> bool:
	return not reduced_feedback

func visual_clock_scale() -> float:
	return 0.0 if hit_stop_active and not reduced_feedback and not fast_forward else super.visual_clock_scale()

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
		if cooling_cost > 0:
			readout.text = "냉각  %d/%d턴" % [reload_tick, cooling_cost]
		else:
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

func _launch_shot(_result: Dictionary) -> void:
	# Capture after the actor's release pose/recoil has been configured. Once in
	# flight, the carrier must not follow the recovering barrel back to aim.
	launch_origin=player_muzzle()
	launch_ready=true

func projectile_origin() -> Vector2:
	return launch_origin if launch_ready else player_muzzle()

func muzzle_angle() -> float:
	_update_weapon_actor()
	return weapon_viewport.get_node("Actor").registered_transform().get_rotation()

func _draw_muzzle_flash(muzzle: Vector2) -> void:
	FiringVFX.draw_flash(self,muzzle,muzzle_angle(),1.0-flash,firing_profile,reduced_feedback or fast_forward,finish_camera())

func _draw_projectile(origin: Vector2, to: Vector2, progress: float) -> void:
	FiringVFX.draw_projectile(self,origin,to,progress,firing_profile,reduced_feedback or fast_forward,finish_camera())

func _stagger_weight() -> float:
	return clampf(1.0 - pulse / 0.72, 0.0, 1.0)

func _actor_hit(index: int) -> float:
	if fast_forward: return 0.0
	var hit := super._actor_hit(index)
	return maxf(hit, 1.3 * _stagger_weight()) if index == stagger_target else hit

func _actor_offset(index: int) -> Vector2:
	if reduced_feedback or fast_forward: return Vector2.ZERO
	if index == stagger_target:
		var stagger := _stagger_weight()
		return Vector2(roundf(8.0 * stagger), roundf(2.0 * stagger))
	if not damage_popups.any(func(entry): return int(entry.target) == index and int(entry.amount) > 0): return Vector2.ZERO
	# Offset the drawn body while its distance and hit anchor follow the replay.
	var recover := 1.0 - pulse
	var kick := 4.0 + 4.0 * maxf(impact_power, actor_hit_strength)
	return Vector2(roundf(kick * recover * recover), 0)

func _draw_enemy_ground(index: int, foot: Vector2) -> void:
	if int(enemies[index].get("slow_left", 0)) <= 0: return
	var anchor := foot.round()
	# Lower than the gold targeting brackets, with stepped ends on the floor.
	for side in [-1, 1]:
		var rail := anchor + Vector2(side * 20 - 8, 8)
		draw_rect(Rect2(rail - Vector2(1, 1), Vector2(18, 5)), SLOW_SHADOW)
		draw_rect(Rect2(rail, Vector2(16, 3)), SLOW_MARK)
		var tip := anchor + Vector2(side * 30 - 2, 5)
		draw_rect(Rect2(tip - Vector2(1, 1), Vector2(6, 5)), SLOW_SHADOW)
		draw_rect(Rect2(tip, Vector2(4, 3)), SLOW_MARK)

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
	if receipt_is_previous:
		salvo_receipt = {}
		receipt_is_previous = false
	build_signature = Payoff.signature(result)
	impact_style=ImpactStyle.resolve(result)
	surface_profile=Surface.resolve(result)
	firing_profile=FiringVFX.profile(str(display_state.get("gun","single")),result)
	launch_ready=false
	hero_action = "aim"
	if result.get("overdrive", false): _feedback("reactor_overdrive", {"heat":int(result.get("heat_before", 0))})
	actor_hit_strength = 0.0
	boost_value = int(result.get("math", {}).get("boost", 0)) + int(result.get("thermal_bonus", 0)) + int(result.get("vent_bonus", 0))
	boost_value += maxi(0, int(result.get("math", {}).get("factor", 1)) - 1) * 4
	shot_power = minf(1.0, float(boost_value) / 4.0)
	if Content.is_attack(str(result.id)) and int(build_signature.rank)>0:
		shot_power = maxf(shot_power,0.65)
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
	salvo_results.append(result)
	salvo_receipt = Payoff.receipt(salvo_results)
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
	var hit_target := int(result.target)
	var staggered := int(result.get("slowed", 0)) > 0 or int(result.get("interrupted", 0)) > 0
	if staggered and not reduced_feedback and not fast_forward and int(result.hp) > 0 and hit_target >= 0 and hit_target < enemies.size():
		stagger_target = hit_target
	heat_debt = int(result.get("heat_after", heat_debt))
	if int(result.get("kill_cooled", 0)) > 0:
		_feedback("kill_cooling", {"heat": heat_debt, "removed": int(result.kill_cooled), "base": reload_base})
	impact_blocked = int(result.damage) == 0 and int(result.get("blocked_hits", 0)) > 0
	impact_power = minf(1.0, float(boost_value) / 4.0) if int(result.damage) > 0 else 0.0
	if int(payoff_last.tier)>0: impact_power = maxf(impact_power,0.9 if int(payoff_last.tier)==2 else 0.65)
	if impact_style.get("active",false):float_color=impact_style.color
	var grant := int(result.get("boost_granted", 0))
	if grant > 0 or int(result.get("boost_factor_granted", 1)) > 1: _feedback("boost_link", {"value": grant, "count": int(result.get("boost_rounds", 2))})
	_feedback("powered_impact" if impact_power > 0 else "plain_impact", {"boost": boost_value, "damage": int(result.damage), "blocked": impact_blocked, "target": int(result.target)})
	if result.get("overheated", false):
		overheat_lock = 1.0
		_feedback("reactor_armed" if result.get("overdrive_next", false) else "overheat_lock", {"heat": heat_debt})
		if not reduced_feedback:
			await _animate(0.12, func(t: float): overheat_lock = 1.0 - t)
		overheat_lock = 0.0
	await _play_hit_stop(result)

func _play_hit_stop(result: Dictionary) -> void:
	var damage := int(result.damage)
	if reduced_feedback or fast_forward or finish_active or damage <= 0 or Ranged.is_projectile(int(result.target)): return
	var duration := 0.0
	if damage >= 18 or int(impact_style.rank) >= 2 or int(payoff_last.tier) == 2:
		duration = 0.08
	elif damage >= 6 and str(impact_style.operator) in ["multiply", "add", "repeat"]:
		duration = 0.05
	duration = minf(duration, MAX_SALVO_HIT_STOP - hit_stop_used)
	if duration < 0.025: return
	hit_stop_used += duration
	# Freeze the local battle clock while the action coroutine can still advance.
	hit_stop_active = true
	await _animate(duration, func(_t: float): pass)
	hit_stop_active = false

func _finish_shot() -> void:
	build_signature = {}
	impact_style={}
	surface_profile={}
	firing_profile={}
	launch_ready=false
	armor_chips = false
	hero_action = "aim"
	actor_hit_strength = 0.0
	stagger_target = -1
	shot_power = 0.0
	impact_power = 0.0
	impact_blocked = false
	boost_value = 0

func _after_advance_tick(_events: Array) -> void:
	pass

func _before_enemy_movement(_events: Array) -> void:
	pass

func _charge_released(_event: Dictionary) -> void:
	pass

func _play_pull(event: Dictionary) -> void:
	caption = "지원 개입 · 강제 접근"
	await _animate(0.16, func(t: float): enemies[int(event.target)].distance = lerpf(float(event.from), float(event.to), t * t * (3.0 - 2.0 * t)))

func _draw() -> void:
	super._draw()
	_draw_build_receipt()
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

func _draw_fire_zones() -> void:
	for zone in display_state.get("fire_zones",[]):
		var left:=maxf(12,roundf(_distance_x(maxf(0,float(zone.center)-float(zone.radius)))))
		var right:=minf(size.x-12,roundf(_distance_x(float(zone.center)+float(zone.radius))))
		Surface.ground_fire(self,left,right,roundf(player_feet().y),effect_clock,int(zone.left),reduced_feedback or fast_forward)

func burn_anchor(index: int) -> Vector2:
	return enemy_position(index).lerp(enemy_feet(index),0.65)

func surface_contact(index: int) -> Vector2:
	# Debris stays at the captured collision while push/recoil moves the actor.
	return damage_anchors.get(index,enemy_position(index))

func _draw_surface_overlay(canvas: CanvasItem) -> void:
	canvas.draw_set_transform_matrix(finish_camera())
	for index in _alive_indices():
		var enemy:Dictionary=enemies[index]
		if int(enemy.get("burn",0))<=0:continue
		# Use the live actor anchors in every region, rather than a texture pose.
		var point:=burn_anchor(index)
		Surface.fire(canvas,point+Vector2(-10,0),effect_clock+index*0.17,0.7,0.85,reduced_feedback or fast_forward)
		if not reduced_feedback and not fast_forward:Surface.fire(canvas,point+Vector2(10,2),effect_clock+index*0.17+0.35,0.5,0.6)
	if _visual_entity(float_target).is_empty():return
	var point:=surface_contact(float_target)
	var surface_point:=enemy_feet(float_target)-Vector2(0,8) if surface_profile.get("ground",false) else point
	if not reduced_feedback and not fast_forward and surface_profile.get("contact", false) and not firing_profile.is_empty():
		EnhancedShot.draw_contact(canvas, point, pulse, firing_profile.tier, firing_profile.color, finish_camera())
	Surface.draw(canvas,surface_point,pulse,surface_profile,reduced_feedback or fast_forward,finish_camera())
	if float_target == stagger_target and not reduced_feedback and not fast_forward:
		var strength := _stagger_weight()
		if strength > 0.0:
			var edge := (point + Vector2(29 + roundf((1.0 - strength) * 7), 29)).round()
			var spark := Color(SLOW_MARK.lightened(0.28), strength)
			canvas.draw_rect(Rect2(edge, Vector2(10, 2)), spark)
			canvas.draw_rect(Rect2(edge + Vector2(7, -5), Vector2(6, 2)), spark)
			canvas.draw_rect(Rect2(edge + Vector2(13, 4), Vector2(4, 2)), spark)
	if surface_profile.get("chips",false) and not reduced_feedback and not fast_forward:CombatVFX.armor(canvas,point,pulse)
	for packet in chain_targets:
		if _visual_entity(int(packet.target)).is_empty():continue
		_draw_surface_link(canvas,point,surface_contact(int(packet.target)),packet)

func _draw_secondary_packet(from: Vector2, to: Vector2, packet: Dictionary) -> void:
	# Runtime overlay sits above all regional actor children, below numbers/cards.
	if not is_instance_valid(readout_layer):_draw_surface_link(self,from,to,packet)

func _draw_surface_link(canvas: CanvasItem, from: Vector2, to: Vector2, packet: Dictionary) -> void:
	var kind:=str(packet.get("kind","arc"))
	if kind in ["burn_transfer","spread"]:
		if int(packet.get("transferred",0))<=0:return
		# Hot spots sit below the numeric readouts; the source is the burning actor.
		var source:=burn_anchor(float_target)
		var destination:=burn_anchor(int(packet.target))
		CombatVFX.ember_link(canvas,source,destination,pulse,int(packet.transferred),reduced_feedback or fast_forward)
		if pulse>=0.55:Surface.fire(canvas,destination+Vector2(0,2),pulse,0.55,1.0-pulse,reduced_feedback or fast_forward)
	else:
		_draw_link_on(canvas,from,to,kind)
		var profile:=Surface.resolve(packet,kind)
		Surface.draw(canvas,to,pulse,profile,reduced_feedback or fast_forward,finish_camera())

func _draw_secondary_link(from: Vector2, to: Vector2, kind: String) -> void:
	_draw_link_on(self,from,to,kind)

func _draw_link_on(canvas: CanvasItem, from: Vector2, to: Vector2, kind: String) -> void:
	if kind == "arc": CombatVFX.arc(canvas,from,to,pulse,reduced_feedback or fast_forward)
	elif kind == "heat_wave":
		var reach := 8+floorf(pulse*18)
		for side in [-1,1]:
			var edge := (to+Vector2(side*reach,-8)).snapped(Vector2(2,2))
			canvas.draw_rect(Rect2(edge,Vector2(3,16)),Color(HOT,1.0-pulse))
	elif kind in ["relay","overflow"]:
		var midpoint := Vector2(roundf((from.x+to.x)*0.5),from.y)
		var points := PackedVector2Array([from.round(),midpoint,Vector2(midpoint.x,to.y).round(),to.round()])
		canvas.draw_polyline(points,Color(BOOST,1.0-pulse),4 if kind=="overflow" else 2,false)
	else:canvas.draw_line(from.round(),to.round(),Color("9bbfc4",1.0-pulse),2,false)

func _draw_heat_symbol(point: Vector2, color: Color) -> void:
	preload("res://redesign/ammo_visual.gd").heat_icon(self, point + Vector2(10, 5), 1.0, color)

func _draw_impact_mark(rect: Rect2, color: Color) -> void:
	# Bright impact strokes must not cut through the numbers or their captions.
	for bounds in impact_readout_bounds:
		if rect.intersects(bounds): return
	draw_rect(rect,color)

func _draw_impact(point: Vector2) -> void:
	impact_readout_bounds.clear()
	for item in damage_popup_layout(): impact_readout_bounds.append(item.bounds.grow(3))
	if impact_style.get("operator","")=="multiply" and impact_style.get("active",false):
		if not reduced_feedback and not fast_forward:ImpactSprite.draw(self,point,pulse,impact_style)
		return
	_draw_build_impact(point)
	if impact_power <= 0:
		return
	var color:Color=impact_style.get("color",HOT if boost_value>=4 else BOOST)
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

func _draw_build_receipt() -> void:
	if salvo_receipt.is_empty() or fast_forward: return
	var color: Color = salvo_receipt.signature.color
	var title: String = salvo_receipt.signature.title
	if title.is_empty(): title="사격 결과"
	if receipt_is_previous: title="직전 · " + title
	var width := 208.0
	draw_rect(Rect2(14,9,width+16,57),Color(0.045,0.075,0.09,0.9))
	draw_rect(Rect2(14,9,3,57),color)
	var font_size := 19
	while font_size>14 and FONT.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>width: font_size-=1
	draw_string(FONT,Vector2(24,31),title,HORIZONTAL_ALIGNMENT_LEFT,width,font_size,color)
	var detail: String = salvo_receipt.detail
	var detail_size := 18
	while detail_size>12 and FONT.get_string_size(detail,HORIZONTAL_ALIGNMENT_LEFT,-1,detail_size).x>width: detail_size-=1
	draw_string(FONT,Vector2(24,54),detail,HORIZONTAL_ALIGNMENT_LEFT,width,detail_size,Color("e7e4d9"))

func _draw_build_impact(point: Vector2) -> void:
	if reduced_feedback or fast_forward or build_signature.is_empty() or not damage_popups.any(func(entry):return int(entry.amount)>0): return
	if not impact_style.get("active",false):return
	var color := Color(build_signature.color,1.0-pulse)
	# Keep a small footprint below the number, against the struck actor's feet.
	var origin := point
	for bounds in impact_readout_bounds:
		if origin.x>=bounds.position.x and origin.x<=bounds.end.x: origin.y=maxf(origin.y,bounds.end.y+4)
	match str(build_signature.kind):
		"volley":
			for i in range(3):
				var x := -16+i*16+roundf(pulse*14)
				_draw_impact_mark(Rect2(origin+Vector2(x,pulse*5),Vector2(4,12)),color)
		"siege":
			for side in [-1,1]:
				_draw_impact_mark(Rect2(origin+Vector2(side*(18+pulse*32)-14,0),Vector2(28,4)),color)
		"thermal":
			var r := 18+roundf(pulse*28)
			_draw_impact_mark(Rect2(origin+Vector2(-r,0),Vector2(r*2,3)),color)
			for side in [-1,1]:
				_draw_impact_mark(Rect2(origin+Vector2(side*r,0),Vector2(3,10)),color)

func _play_advance(before: Dictionary, after: Dictionary, events: Array, reloading: bool) -> void:
	# Unlike interpolating directly to 'after', this preserves burn/pull/move/stance
	# ordering and partial reloads that end in victory or contact.
	var elapsed := int(after.turns) - int(before.turns)
	if events.is_empty() and not reloading: elapsed = 0
	reload_total = reload_base + (1 if int(before.get("heat", 0)) >= Content.heat_limit(before) else 0) + int(before.get("legacy_reload_penalty", 0)) if reloading else 0
	if reloading and cooling_cost > 0: reload_total = cooling_cost
	if reloading:
		hero_action = "cooling" if cooling_cost > 0 else "reload"
		hero_reload_progress = 0.0
	for tick in range(elapsed):
		reload_tick = tick + 1 if reloading else 0
		cooling = reloading and (cooling_cost > 0 or tick >= reload_base)
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
			_capture_damage_anchors()
			enemies[index].hp = int(event.hp)
			enemies[index].burn = int(event.burn)
			float_target = index
			damage_popups = [preload("res://redesign/damage_readout.gd").entry(event,"burn")]
			surface_profile=Surface.resolve(event,"burn")
			float_text = "화상 -%d%s" % [event.damage, "  처치" if int(event.hp) == 0 else ""]
			impact_attribute = "fire"
			float_color = Ammo.ATTRIBUTE_COLORS.fire
			visual_events.append(event.duplicate(true))
			await _impact_motion(0.32, func(t: float): pulse = t)
			surface_profile={}
			float_target = -1
			damage_popups.clear()
			pulse = 0.0
		for event in tick_events:
			if event.kind=="fire_zone_tick":display_state.fire_zones=event.zones.duplicate(true)
			if event.kind == "charge":
				enemies[int(event.target)].charge = int(event.charge)
				visual_events.append(event.duplicate(true))
				if bool(event.get("released",false)): await _charge_released(event)
			elif event.kind == "pull":
				await _play_pull(event)
				visual_events.append(event.duplicate(true))
		# Pull and ordinary movement remain distinct; a lethal pull has no move.
		await _before_enemy_movement(tick_events)
		var moves: Array = tick_events.filter(func(event): return str(event.kind) == "move")
		moving_indices = moves.filter(func(event): return float(event.from) != float(event.to)).map(func(event): return int(event.target))
		if not moves.is_empty() or reloading:
			caption = "냉각 · 적 접근" if cooling_cost > 0 else ("추가 냉각 · 적이 한 번 더 접근" if cooling else ("재장전 · 적 접근" if reloading else "적 접근"))
			await _animate(0.38, func(t: float):
				var eased := t * t * (3.0 - 2.0 * t)
				march_phase = t * TAU * 2 if not reduced_feedback else 0.0
				reload_progress = t
				if reloading and not cooling: hero_reload_progress = minf(1.0, float(tick + t) / maxi(1, reload_base))
				for event in moves: enemies[int(event.target)].distance = lerpf(float(event.from), float(event.to), eased)
			)
			for event in moves:
				# The event contains the remaining count after this movement.
				if event.has("slow_left"): enemies[int(event.target)].slow_left = event.slow_left
				visual_events.append(event.duplicate(true))
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
