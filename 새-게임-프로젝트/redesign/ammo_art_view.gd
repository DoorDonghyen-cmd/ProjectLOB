@tool
extends Control
@export var ammo_id := "basic_p2"
func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	preload("res://redesign/ammo_art.gd").draw(self,ammo_id,Rect2(Vector2.ZERO,size))
