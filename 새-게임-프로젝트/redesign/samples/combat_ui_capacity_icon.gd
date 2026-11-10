@tool
extends Control
@export var item_id := "basic_p3":
	set(value):item_id=value;queue_redraw()

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	preload("res://redesign/ammo_art.gd").draw(self,item_id,Rect2(Vector2.ZERO,size))
