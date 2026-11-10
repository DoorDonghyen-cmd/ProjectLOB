@tool
extends Control
## A tight badge behind the existing dynamic ordinal label; does not size it.
func _ready()->void:
 get_parent().draw.connect(queue_redraw)
 resized.connect(queue_redraw)
func _draw()->void:
 var label:=get_parent() as Label
 if label==null:return
 var width:=ceilf(label.get_theme_font("font").get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x)+4
 var rect:=Rect2(size.x-width-2,2,width+2,14)
 var danger:=label.text=="제외"
 draw_rect(Rect2(rect.position+Vector2(0,2),rect.size),Color("8a2d24") if danger else Color("0b5a5c"))
 draw_rect(rect,Color("ff6f61") if danger else Color("5cdddc"))
