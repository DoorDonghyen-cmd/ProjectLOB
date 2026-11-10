@tool
extends Control

const AmmoArt = preload("res://redesign/ammo_art.gd")
const PartArt = preload("res://redesign/part_icon_art.gd")

@export var item_id := "bore":
	set(value):
		item_id = value
		queue_redraw()
@export var is_part := false

func _draw() -> void:
	var center := Vector2(roundf(size.x * 0.5), size.y - 17.0)
	if is_part:
		PartArt.draw(self, item_id, center, Color("c4aa87"), 1.0)
	else:
		AmmoArt.draw(self, item_id, Rect2(center.x - 26.0, size.y - 59.0, 52.0, 59.0))

