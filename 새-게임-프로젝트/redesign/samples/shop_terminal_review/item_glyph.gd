@tool
extends Control

const AmmoArt = preload("res://redesign/ammo_art.gd")
const PartArt = preload("res://redesign/part_icon_art.gd")

@export var showcase := false
@export var item_id := "bore_c":
	set(value):
		item_id = value
		queue_redraw()
@export var is_part := false:
	set(value):
		is_part = value
		queue_redraw()

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	var center := (size * 0.5).floor()
	if is_part:
		PartArt.draw(self, item_id, center, Color("c4aa87"), 1.0 if showcase else 0.70)
	else:
		var extent := Vector2(62, minf(72, size.y)) if showcase else Vector2(36, 42)
		AmmoArt.draw(self, item_id, Rect2(center - extent * 0.5, extent))
