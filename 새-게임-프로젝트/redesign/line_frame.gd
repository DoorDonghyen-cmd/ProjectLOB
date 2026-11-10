@tool
extends NinePatchRect
## Decorative only. Native Button redraws drive hover/selection/disabled artwork.
@export var kind: String="panel"
const LineSkin=preload("res://redesign/line_skin.gd")
func _ready()->void:
 if get_parent() is BaseButton:get_parent().draw.connect(sync)
 sync()
func sync()->void:
 var button:=get_parent() as BaseButton
 var face:=kind
 var tint:=Color.WHITE
 if button!=null:
  if button.disabled:face="disabled"
  elif button.toggle_mode and button.button_pressed:face="active"
  elif button.is_hovered():tint=Color(1.25,1.25,1.25,1)
 var next: Texture2D=LineSkin.texture(face)
 if texture!=next:texture=next
 if modulate!=tint:modulate=tint
