extends "res://redesign/samples/ranged_battle_view.gd"
## Development concept only; keeps the existing wall combat role and timing.
const EAVESBACK = preload("res://assets/art/monster_concept_20261009/eavesback_v1.png")
const SOURCE := Rect2(54, 134, 1416, 757)
const DISPLAY_SIZE := Vector2(108, 58)
const MonsterAnimation = preload("res://redesign/monster_animation.gd")
const CUTOUT = preload("res://redesign/monster_alpha_cutout.gdshader")
var creature_sprites: Dictionary = {}
var attacking_indices: Array = []
var attack_time := 0.0

func sync(state: Dictionary, prediction: Dictionary = {}) -> void:
	attacking_indices.clear()
	attack_time = 0.0
	super.sync(state,prediction)
	for index in creature_sprites:
		creature_sprites[index].hide()

func monster_tag(index: int) -> String:
	if not actor_motion_enabled() or fast_forward: return "idle"
	if attacking_indices.has(index): return "attack"
	if index == float_target and (actor_hit_strength > 0.0 or int(enemies[index].hp) <= 0): return "hit"
	if moving_indices.has(index): return "walk"
	return "idle"

func monster_frame(index: int) -> AtlasTexture:
	var tag := monster_tag(index)
	var time := actor_clock
	if tag == "walk": time = march_phase / (TAU * 2.0) * 0.38
	elif tag == "hit": time = pulse * 0.36
	elif tag == "attack": time = attack_time
	return MonsterAnimation.frame(tag,time)

func _draw() -> void:
	for sprite in creature_sprites.values(): sprite.hide()
	super._draw()

func _contact_kind(kind: String) -> bool:
	return kind == "wall"

func _after_advance_tick(events: Array) -> void:
	await super._after_advance_tick(events)
	attacking_indices.clear()
	for event in events:
		if str(event.kind) not in ["move", "pull"] or float(event.to) > 0: continue
		var index := int(event.target)
		if index < enemies.size() and _contact_kind(str(enemies[index].kind)) and int(enemies[index].hp) > 0:
			if not attacking_indices.has(index): attacking_indices.append(index)
	if not attacking_indices.is_empty():
		visual_events.append({"kind":"monster_contact", "targets":attacking_indices.duplicate()})
		await _animate(0.16,func(t: float): attack_time = t * 0.16)
	attacking_indices.clear()
	attack_time = 0.0

func enemy_head_y(index: int) -> float:
	if str(enemies[index].kind) == "wall": return enemy_feet(index).y - 64.0
	return super.enemy_head_y(index)

func concept_rect(index: int) -> Rect2:
	var foot := enemy_feet(index) + _actor_offset(index)
	return MonsterAnimation.visible_rect(monster_frame(index),foot)

func _draw_enemy_actor(index: int, foot: Vector2, lift: float, stride: float) -> void:
	if str(enemies[index].kind) != "wall":
		super._draw_enemy_actor(index, foot, lift, stride)
		return
	if not creature_sprites.has(index):
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var shader_material := ShaderMaterial.new()
		shader_material.shader = CUTOUT
		sprite.material = shader_material
		add_child(sprite)
		creature_sprites[index] = sprite
	var sprite: Sprite2D = creature_sprites[index]
	var texture := monster_frame(index)
	sprite.texture = texture
	var camera:=finish_camera()
	sprite.position = (camera*MonsterAnimation.position(texture,foot + _actor_offset(index))).round()
	sprite.scale = camera.get_scale() * MonsterAnimation.Data.SCALE
	sprite.modulate = actor_tint(index)
	sprite.show()

func _enemy_at(point: Vector2) -> int:
	for i in range(enemies.size()):
		if int(enemies[i].hp) > 0 and str(enemies[i].kind) == "wall" and concept_rect(i).has_point(point): return i
	return super._enemy_at(point)
