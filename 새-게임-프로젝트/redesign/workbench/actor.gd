@tool
extends "res://redesign/service_actor_layer.gd"
func image_rect() -> Rect2:
	var room := get_parent() as TextureRect
	if room == null or room.texture == null:return Rect2()
	var canvas := room.texture.get_size()
	var factor: float = maxf(size.x/canvas.x,size.y/canvas.y)
	return Rect2((size-canvas*factor)*0.5,canvas*factor)
