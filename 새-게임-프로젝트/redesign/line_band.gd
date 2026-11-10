@tool
extends PanelContainer
@export var bottom: bool=true
func _ready()->void:resized.connect(queue_redraw)
func _draw()->void:
 draw_rect(Rect2(Vector2.ZERO,size),Color("04191f") if bottom else Color("03151b"))
 var y:=size.y-2 if bottom else 0.0
 for x in range(0,int(size.x),8):draw_rect(Rect2(x,y,mini(4,int(size.x)-x),2),Color("2c7a80"))
