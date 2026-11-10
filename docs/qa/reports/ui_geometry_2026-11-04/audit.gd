extends "res://tests/ui_readability_ui.gd"
var geometry: Array = []
func pair(v: Vector2) -> Array:
 return [v.x,v.y]
func box(r: Rect2) -> Array:
 return [r.position.x,r.position.y,r.size.x,r.size.y]
func scan(label: String) -> void:
 super.scan(label)
 var row: Dictionary = {"label":label,"window":pair(Vector2(root.size)),"viewport":box(root.get_visible_rect()),"factor":root.content_scale_factor,"mode":root.content_scale_mode,"content_scale_size":pair(Vector2(root.content_scale_size)),"final_scale":pair(root.get_final_transform().get_scale()),"safe":box(Readable.available(host)),"host_size":pair(host.size),"nodes":[]}
 for n in host.find_children("*","Control",true,false):
  if not n.is_visible_in_tree():continue
  var info: Dictionary = {"path":str(host.get_path_to(n)),"name":str(n.name),"class":n.get_class(),"rect":box(n.get_global_rect()),"minimum":pair(n.get_combined_minimum_size()),"custom_minimum":pair(n.custom_minimum_size),"scale":pair(n.scale)}
  if n is ScrollContainer:
   var bar=n.get_v_scroll_bar()
   info["scroll"]={"y":n.scroll_vertical,"max":bar.max_value,"page":bar.page,"overflow":maxf(0,bar.max_value-bar.page),"horizontal":maxf(0,n.get_h_scroll_bar().max_value-n.get_h_scroll_bar().page)}
  if n is MarginContainer:
   info["margin"]={}
   for side in ["left","right","top","bottom"]:info.margin[side]=n.get_theme_constant("margin_"+side)
  if n is BoxContainer:info["gap"]=n.get_theme_constant("separation")
  if n is GridContainer:info["gap"]=[n.get_theme_constant("h_separation"),n.get_theme_constant("v_separation")]
  if n is Label or n is Button:info["text"]=n.text;info["font_size"]=n.get_theme_font_size("font_size")
  row.nodes.append(info)
 geometry.append(row)
 FileAccess.open(output.path_join("geometry.json"),FileAccess.WRITE).store_string(JSON.stringify(geometry,"  "))
