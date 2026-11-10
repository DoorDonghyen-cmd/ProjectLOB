@tool
extends Control
## Four native pixel samples match the actual map states. Labels live in the scene.
const Surface=preload("res://redesign/pipe_map/material.gd")
func _draw() -> void:
	draw_rect(Rect2(3,3,18,18),Surface.PICK,false,4)
	draw_line(Vector2(2,36),Vector2(24,36),Surface.TRAIL,6,false)
	draw_style_box(Surface.SELECTION,Rect2(1,49,24,22))
	for p in [Vector2(1,73),Vector2(25,73),Vector2(25,95),Vector2(1,95)]:
		var dx:=1.0 if p.x==1 else -1.0
		var dy:=1.0 if p.y==73 else -1.0
		draw_line(p,p+Vector2(dx*7,0),Surface.OPEN,2,false)
		draw_line(p,p+Vector2(0,dy*7),Surface.OPEN,2,false)
