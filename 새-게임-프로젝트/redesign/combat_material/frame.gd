@tool
extends NinePatchRect
## Paint inside the existing decorative node. No minimum size or input changes.
const HudSkin=preload("res://redesign/combat_material/skin.gd")
@export var kind: String="panel"
@export var face: String="normal":
	set(value):
		face=value;queue_redraw()

func _ready() -> void:
	if get_parent() is BaseButton:get_parent().draw.connect(sync)
	resized.connect(queue_redraw)
	sync()

func sync() -> void:
	queue_redraw()

func _draw() -> void:
	var button:=get_parent() as BaseButton
	var state:=face
	if button!=null:
		if button.disabled:state="disabled"
		elif button.toggle_mode and button.button_pressed:state="active"
		elif button.is_pressed():state="pressed"
	var style:=HudSkin.box(kind,state)
	draw_style_box(style,Rect2(Vector2.ZERO,size))
	var light:=Color("606557")
	var shadow:=Color("0c110d")
	if state in ["firing","active"]:light=HudSkin.SELECT
	elif state=="removed":light=HudSkin.DANGER
	elif state=="disabled" or state=="empty":light=Color("424b39")
	elif kind=="fire":light=Color("dfad84");shadow=Color("784a34")
	elif kind=="reload":light=Color("a28c59")
	elif kind=="cool":light=Color("7e9b93")
	if size.x>16 and size.y>10:
		draw_line(Vector2(6,2),Vector2(size.x-6,2),Color(light,0.6),2,false)
		draw_line(Vector2(6,size.y-3),Vector2(size.x-6,size.y-3),Color(shadow,0.85),2,false)
	# Focus and hover are restrained edge signals, independent of semantic fill.
	if button!=null and not button.disabled:
		if button.is_hovered():draw_line(Vector2(6,4),Vector2(size.x-6,4),Color(HudSkin.INK,0.35),1,false)
		if button.has_focus():
			for x in [2.0,size.x-6.0]:draw_rect(Rect2(x,6,4,2),HudSkin.INK)

