@tool
extends Node2D
const Motion = preload("res://redesign/monster_animation.gd")

func _ready() -> void:
	$Creature.frame_changed.connect(_register_frame)
	$Creature.animation_changed.connect(_register_frame)
	_register_frame()

func _register_frame() -> void:
	var sprite: AnimatedSprite2D = $Creature
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation,sprite.frame) as AtlasTexture
	sprite.position = Vector2(220,232) - Motion.Data.ANCHORS[Motion.index_of(texture)] * sprite.scale
