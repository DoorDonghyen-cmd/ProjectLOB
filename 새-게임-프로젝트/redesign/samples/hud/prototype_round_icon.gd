@tool
extends Control
const Content=preload("res://redesign/content.gd")
@export var item_id: String="basic_p3":
 set(value):
  item_id=value
  queue_redraw()
var textures: Dictionary={}
func _ready()->void:resized.connect(queue_redraw)
func _draw()->void:
 var source: String=Content.source_id(item_id)
 if not textures.has(source):
  var path: String="res://assets/ui/prototype_20261101/round_%s.png"%source
  textures[source]=load(path if ResourceLoader.exists(path) else "res://assets/ui/prototype_20261101/round_basic.png")
 var texture: Texture2D=textures[source]
 var extent: Vector2=texture.get_size()*minf(size.x/texture.get_width(),size.y/texture.get_height())
 draw_texture_rect(texture,Rect2((size-extent)*0.5,extent),false)
