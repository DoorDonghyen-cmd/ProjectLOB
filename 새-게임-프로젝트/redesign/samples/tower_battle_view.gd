@tool
extends "res://redesign/battle_view.gd"
## Sample art adapter: original PNGs, shared combat presentation, one ground plane.
@export var tower_texture: Texture2D
@export var character_texture: Texture2D
@export var source_floor_y := 720.0
@export var character_anchor := Vector2(612, 1168)
@export_range(0.25, 1.5, 0.05) var character_size_multiplier := 1.0

func _ready() -> void:
	super._ready()
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
	return size.y - 40.0

func player_feet() -> Vector2:
	return Vector2(122, ground_y() + 8).round()

func enemy_feet(index: int) -> Vector2:
	var position := super.enemy_feet(index)
	position.y = ground_y() + 8
	return position.round()

func character_scale() -> float:
	return character_size_multiplier * minf(0.18, maxf(0.09, (size.y - 100.0) / 1050.0))

func player_muzzle() -> Vector2:
	return (player_feet() + (Vector2(1025, 917) - character_anchor) * character_scale() - Vector2(roundf(flash * 4), 0)).round()

func _draw_player(foot: Vector2) -> void:
	if character_texture == null: return
	var scale_value := character_scale()
	var position := (foot - character_anchor * scale_value - Vector2(roundf(flash * 4), 0)).round()
	draw_texture_rect(character_texture, Rect2(position, character_texture.get_size() * scale_value), false)

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
