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
	draw_texture_rect_region(spec.texture, actor_rect(index, concept_rect(index)), spec.source, actor_tint(index))

func _enemy_at(point: Vector2) -> int:
	for i in range(enemies.size()):
		if int(enemies[i].hp) > 0 and CONCEPTS.has(str(enemies[i].kind)) and concept_rect(i).has_point(point): return i
	return super._enemy_at(point)
