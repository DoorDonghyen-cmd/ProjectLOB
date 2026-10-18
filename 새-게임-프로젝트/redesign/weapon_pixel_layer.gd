@tool
extends Node2D
## Render the moving weapon as one low-resolution layer before hand occlusion.
var actor: Node2D
var pixel_step := 4.0

func _draw() -> void:
	if is_instance_valid(actor):
		actor.draw_weapon_layers(self, pixel_step)
