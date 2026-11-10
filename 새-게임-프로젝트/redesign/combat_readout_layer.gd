extends Node2D
## Draw above alpha-cutout actor children, in the same local finish camera.
var board: Control
func _draw() -> void:
	if not is_instance_valid(board): return
	draw_set_transform_matrix(board.finish_camera())
	board._draw_surface_overlay(self)
	board._draw_projectiles(self)
	board._draw_crowding(self)
	for index in board._alive_indices():
		board._draw_enemy_plaque(index, self)
		board._draw_enemy_marker(index, self)
	board._draw_damage_readouts(self)
