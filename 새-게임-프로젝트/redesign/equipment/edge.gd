@tool
extends Control
## Decorative edge catches only. No hit area, minimum size or movement.
var surface: Button
@export var primary_variation: StringName = &"EquipmentPrimary"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface = get_parent() as Button
	if surface == null: return
	surface.resized.connect(queue_redraw)
	surface.draw.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(surface): return
	var extent := surface.size
	if extent.x < 16 or extent.y < 16: return
	var choice := surface.theme_type_variation in [&"EquipmentChoice", &"EquipmentSelected"]
	var primary := surface.theme_type_variation == primary_variation
	var light := Color("bca571") if surface.button_pressed else Color("606557")
	var shadow := Color("0c110d")
	if surface.disabled:
		light = Color("61645a")
	elif primary:
		light = Color("dfc996")
		shadow = Color("72613f")
	draw_line(Vector2(6,2),Vector2(extent.x-6,2),Color(light,0.6),2,false)
	draw_line(Vector2(6,extent.y-3),Vector2(extent.x-6,extent.y-3),Color(shadow,0.85),2,false)
	if choice and surface.disabled:
		var mark := Vector2(extent.x - 18, 7)
		draw_rect(Rect2(mark + Vector2(2, 0), Vector2(5, 5)), light, false, 1.0)
		draw_rect(Rect2(mark + Vector2(0, 4), Vector2(9, 6)), light)
	elif choice and surface.button_pressed:
		draw_rect(Rect2(extent.x-11,6,5,2),light)
		draw_rect(Rect2(extent.x-8,8,2,4),light)
	elif not choice:
		for x in [4,extent.x-6]:
			draw_rect(Rect2(x,extent.y*0.5-1,2,2),Color(light,0.55))
