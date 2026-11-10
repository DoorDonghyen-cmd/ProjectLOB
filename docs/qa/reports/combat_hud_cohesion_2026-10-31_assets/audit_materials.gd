extends SceneTree
func _initialize()->void:
 var report: Dictionary={"frames":[],"failures":[],"tool_note":"External Pillow stretch audit cannot read SVG. This inspects imported Godot textures and nine-slice margins directly."}
 var theme=load("res://redesign/samples/hud/combat_hud_theme.tres")
 for name in theme.get_stylebox_list("Panel"):
  var box: StyleBox=theme.get_stylebox(name,"Panel")
  if not box is StyleBoxTexture:continue
  var texture: Texture2D=box.texture
  var size: Vector2=texture.get_size()
  var horizontal: float=box.get_texture_margin(SIDE_LEFT)+box.get_texture_margin(SIDE_RIGHT)
  var vertical: float=box.get_texture_margin(SIDE_TOP)+box.get_texture_margin(SIDE_BOTTOM)
  if horizontal>=size.x or vertical>=size.y:report.failures.append(name+": nine-slice consumes source center")
  report.frames.append({"style":name,"size":str(size),"fixed_x":horizontal,"fixed_y":vertical})
 var scene: PackedScene=load("res://redesign/samples/hud/combat_hud.tscn")
 var ui: Control=scene.instantiate()
 if ui.texture_filter!=CanvasItem.TEXTURE_FILTER_NEAREST:report.failures.append("Root does not use nearest filtering")
 for id in ["Round0","Round1","Fire","EjectApply","MenuSurface","DetailSurface"]:
  var n: Control=ui.find_child(id,true,false)
  var field: String="normal" if n is Button else "panel"
  if not n.has_theme_stylebox_override(field):report.failures.append("Missing serialized representative style: "+id)
 for id in ["CoolHardware","ReloadHardware","FireHardware"]:
  var n: Control=ui.find_child(id,true,false)
  if n.mouse_filter!=Control.MOUSE_FILTER_IGNORE:report.failures.append("Decoration intercepts input: "+id)
 ui.free()
 FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("materials.json"),FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("MATERIAL AUDIT COMPLETE frames=%d failures=%d"%[report.frames.size(),report.failures.size()])
 quit(0 if report.failures.is_empty() else 1)
