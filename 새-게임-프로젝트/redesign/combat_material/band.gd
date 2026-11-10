@tool
extends PanelContainer
## Same authored console/header bounds; quiet iron seam replaces the dotted rail.
@export var bottom: bool=true
func _ready() -> void:resized.connect(queue_redraw)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("0e150e") if bottom else Color("11180f"))
	var y:=size.y-2 if bottom else 0.0
	draw_rect(Rect2(0,y,size.x,1),Color("555c4c"))
	draw_rect(Rect2(0,y+1,size.x,1),Color("080c07"))
