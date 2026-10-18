@tool
extends "res://redesign/battle_view.gd"
## Sample art adapter: original PNGs, shared combat presentation, one ground plane.
@export var tower_texture: Texture2D
@export var character_texture: Texture2D
@export var source_floor_y := 720.0
@export var character_anchor := Vector2(612, 1168)
@export_range(0.25, 1.5, 0.05) var character_size_multiplier := 1.0
var hero_action := "idle"
var hero_reload_progress := 0.0
# A larger UI stage reveals more environment without enlarging the approved hero.
# Zero keeps standalone art samples tied to their own viewport as before.
var character_reference_height := 0.0
const WeaponActor = preload("res://redesign/weapon_actor.gd")
const AscentBackground = preload("res://redesign/ascent_background.gd")
var background_profile: Dictionary = {}
var weapon_viewport: SubViewport

func set_route_background(route_region: int, depth: int, length: int) -> void:
	background_profile = AscentBackground.profile(route_region, depth, length)
	tower_texture = AscentBackground.texture(background_profile)
	source_floor_y = float(background_profile.floor_y)
	queue_redraw()

func _process(delta: float) -> void:
	super._process(delta)
	_update_weapon_actor()

func _update_weapon_actor() -> void:
	if not is_instance_valid(weapon_viewport): return
	var action := "cooling" if hero_action == "cooling" else hero_pose()
	var actor := weapon_viewport.get_node("Actor")
	var outfit_changed: bool = actor.set_outfit(str(display_state.get("outfit", "work")))
	if actor.configure(str(display_state.get("gun", "single")), action, _weapon_kick(), hero_reload_progress if hero_action == "reload" else -1.0, _weapon_heat()) or outfit_changed:
		weapon_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _weapon_kick() -> float:
	return clampf(flash, 0.0, 1.0) if hero_action == "fire" and actor_motion_enabled() else 0.0

func _weapon_heat() -> float:
	return 0.0

func sync(state: Dictionary, prediction: Dictionary = {}) -> void:
	super.sync(state, prediction)
	hero_action = "aim" if str(state.phase) == "ready" and not state.get("magazine", []).is_empty() else "idle"
	hero_reload_progress = 0.0

func hero_pose() -> String:
	if hero_action == "fire": return "recoil" if flash > 0.2 and actor_motion_enabled() else "aim"
	if hero_action == "reload":
		if hero_reload_progress > 0.88: return "aim"
		return "reload_open" if hero_reload_progress < 0.5 else "reload_seat"
	if hero_action == "cooling": return "reload_open"
	return hero_action

func _ready() -> void:
	super._ready()
	weapon_viewport = preload("res://redesign/weapon_actor.tscn").instantiate()
	add_child(weapon_viewport)
	_update_weapon_actor()
	clip_contents = true
	if Engine.is_editor_hint():
		enemies = [
			{"kind": "runner", "name": "돌진체", "hp": 8, "max_hp": 8, "def": 0, "speed": 2, "distance": 12, "burn": 0, "lane": 0},
			{"kind": "wall", "name": "장갑체", "hp": 16, "max_hp": 16, "def": 3, "speed": 1, "distance": 18, "burn": 0, "lane": 1},
			{"kind": "evader", "name": "기동체", "hp": 12, "max_hp": 12, "def": 0, "speed": 2, "distance": 25, "burn": 0, "lane": 2, "weakness": "electric"},
		]
		target = 0
		queue_redraw()

func ground_y() -> float:
	# Distances sit below the feet; the final 30px is a fixed arrival/status row.
	return size.y - 48.0 - BOTTOM_STATUS_HEIGHT

func player_feet() -> Vector2:
	return Vector2(122, ground_y() + 8).round()

func enemy_feet(index: int) -> Vector2:
	var position := super.enemy_feet(index)
	position.y = ground_y() + 8
	return position.round()

func character_scale() -> float:
	var reference_height := character_reference_height if character_reference_height > 0.0 else size.y
	return character_size_multiplier * minf(0.18, maxf(0.09, (reference_height - 100.0) / 1050.0))

func player_muzzle() -> Vector2:
	_update_weapon_actor()
	if is_instance_valid(weapon_viewport): return weapon_viewport.get_node("Actor").registered_muzzle(player_feet(), character_scale())
	var action := "cooling" if hero_action == "cooling" else hero_pose()
	return WeaponActor.muzzle(str(display_state.get("gun", "single")), action, player_feet(), character_scale(), _weapon_kick())

func _draw_player(foot: Vector2) -> void:
	if not is_instance_valid(weapon_viewport): return
	# Contact shadow is fixed to the boots, including recoil/reload key poses.
	Pixel.shadow(self, foot + Vector2(0, 1), 42)
	var factor := character_scale() * WeaponActor.BODY_SCALE
	draw_texture_rect(weapon_viewport.get_texture(), Rect2((foot - WeaponActor.FOOT * factor).round(), (Vector2(weapon_viewport.size) * factor).round()), false)

func background_source_rect() -> Rect2:
	if tower_texture == null: return Rect2()
	var factor := maxf(size.x / tower_texture.get_width(), player_feet().y / source_floor_y)
	var source_size := size / factor
	return Rect2(Vector2(0, source_floor_y - player_feet().y / factor), source_size)

func _draw_backdrop() -> void:
	if tower_texture == null: return
	# The camera crops vertically; it never stretches the portrait architecture.
	draw_texture_rect_region(tower_texture, Rect2(Vector2.ZERO, size), background_source_rect())
	# Match the existing enemy art to the illustrated steel platform without adding
	# a second raised floor in front of it. Background and actors share the feet line.
	draw_rect(Rect2(0, player_feet().y + 2, size.x, 2), Color("587079"))

	# Sparse air motes belong to the environment; no RNG or actor movement.
	if actor_motion_enabled() and not Engine.is_editor_hint():
		for i in range(9):
			var x := fmod(float(i * 173 + 47) + actor_clock * (2.0 + i % 3), maxf(1, size.x))
			var y := 26.0 + fmod(float(i * 37) + sin(actor_clock * 0.45 + i) * 5.0, maxf(1, ground_y()-40))
			draw_rect(Rect2(Vector2(x,y).snapped(Vector2(2,2)), Vector2(2,2)), Color(0.57,0.69,0.68,0.17))
	# The dark sill visually connects the battlefield to the instrument panel.
	var sill_height := 18.0 + BOTTOM_STATUS_HEIGHT
	draw_rect(Rect2(0,size.y-sill_height,size.x,sill_height), Color("101e25"))
	draw_line(Vector2(0,size.y-sill_height), Vector2(size.x,size.y-sill_height), Color("3d555c"), 1)
