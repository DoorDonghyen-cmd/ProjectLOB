@tool
extends Control
## A brass lock, separate from cyan firing order and red ejection selection.
func _draw() -> void:
	var brass:=Color("c0a36c")
	draw_rect(Rect2(2,7,12,8),Color("181811"))
	draw_rect(Rect2(2,7,12,8),brass,false,2)
	draw_line(Vector2(4,6),Vector2(4,2),brass,2,false)
	draw_line(Vector2(4,2),Vector2(12,2),brass,2,false)
	draw_line(Vector2(12,2),Vector2(12,6),brass,2,false)
	draw_rect(Rect2(7,10,2,3),brass)
