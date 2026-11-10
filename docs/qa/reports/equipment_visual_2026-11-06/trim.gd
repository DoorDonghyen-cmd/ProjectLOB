extends Node2D
## Pixel edge catches light; no panel movement, hit area or layout participation.
var surface:Button
func _ready() -> void:
	surface=get_parent() as Button
	surface.resized.connect(queue_redraw)
	surface.draw.connect(queue_redraw)
func _draw() -> void:
	if not is_instance_valid(surface):return
	var extent:=surface.size
	if extent.x<16 or extent.y<16:return
	var chosen:bool=surface.button_pressed
	var choice:bool=surface.name.begins_with("weapon_select_") or surface.name.begins_with("outfit_select_")
	var primary:bool=surface.name.begins_with("start_")
	var light:=Color("bca571") if chosen else Color("606557")
	var shadow:=Color("0c110d")
	if primary:light=Color("dfc996");shadow=Color("72613f")
	draw_line(Vector2(6,2),Vector2(extent.x-6,2),Color(light,0.6),2,false)
	draw_line(Vector2(6,extent.y-3),Vector2(extent.x-6,extent.y-3),Color(shadow,0.85),2,false)
	if chosen and choice:
		draw_rect(Rect2(extent.x-11,6,5,2),light)
		draw_rect(Rect2(extent.x-8,8,2,4),light)
	elif not choice:
		for x in [4,extent.x-6]:draw_rect(Rect2(x,extent.y*0.5-1,2,2),Color(light,0.55))
