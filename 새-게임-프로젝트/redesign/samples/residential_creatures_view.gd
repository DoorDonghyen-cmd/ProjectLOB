extends "res://redesign/samples/eavesback_view.gd"
## Development art family; original combat kinds and calculations stay unchanged.
const CONCEPTS := {
	"runner": {"texture": preload("res://assets/art/monster_concept_20261009/foldrunner_v1.png"), "source": Rect2(107, 226, 1041, 891), "size": Vector2(84, 72)},
	"evader": {"texture": preload("res://assets/art/monster_concept_20261009/rainpouch_v1.png"), "source": Rect2(321, 137, 720, 1013), "size": Vector2(62, 88)},
}

func concept_rect(index: int) -> Rect2:
	var kind := str(enemies[index].kind)
	if not CONCEPTS.has(kind): return super.concept_rect(index)
	var extent: Vector2 = CONCEPTS[kind].size
	var foot := enemy_feet(index) + _actor_offset(index)
	return Rect2((foot - Vector2(extent.x * 0.5, extent.y)).round(), extent)

func enemy_head_y(index: int) -> float:
	var kind := str(enemies[index].kind)
	if CONCEPTS.has(kind): return enemy_feet(index).y - CONCEPTS[kind].size.y
	return super.enemy_head_y(index)

func _draw_enemy_actor(index: int, foot: Vector2, lift: float, stride: float) -> void:
	var kind := str(enemies[index].kind)
	if not CONCEPTS.has(kind):
		super._draw_enemy_actor(index, foot, lift, stride)
		return
	var spec: Dictionary = CONCEPTS[kind]
	if not creature_sprites.has(index):
		var created := Sprite2D.new()
		created.centered = false
		created.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var cutout := ShaderMaterial.new()
		cutout.shader = CUTOUT
		created.material = cutout
		add_child(created)
		creature_sprites[index] = created
	var sprite: Sprite2D = creature_sprites[index]
	var rect := actor_rect(index, concept_rect(index))
	sprite.texture = spec.texture
	sprite.region_enabled = true
	sprite.region_rect = spec.source
	sprite.position = (finish_camera() * rect.position).round()
	sprite.scale = finish_camera().get_scale() * rect.size / spec.source.size
	sprite.z_index = actor_layer(index)
	sprite.modulate = actor_tint(index)
	ActorArtStyle.apply(sprite.material, float(spec.size.y / spec.source.size.y), cohesive_actor_art)
	sprite.show()

func actor_pick_rect(index: int) -> Rect2:
	if int(enemies[index].hp) > 0 and CONCEPTS.has(str(enemies[index].kind)): return concept_rect(index)
	return super.actor_pick_rect(index)
