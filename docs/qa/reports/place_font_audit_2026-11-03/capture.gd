extends "res://tests/campaign_magazine_ui.gd"
var metrics: Array=[]
func scan(label: String)->void:
 var row: Dictionary={"label":label,"window":str(root.size),"viewport":str(root.get_visible_rect()),"final":str(root.get_final_transform()),"texts":[]}
 for n in host.find_children("*","Control",true,false):
  if not (n is Label or n is Button or n is RichTextLabel) or not n.is_visible_in_tree():continue
  var text: String=n.text
  if text.is_empty():continue
  var key: String="normal_font_size" if n is RichTextLabel else "font_size"
  var font_size: int=n.get_theme_font_size(key)
  var tr: Transform2D=root.get_final_transform()*n.get_global_transform_with_canvas()
  var missing: String=""
  var font: Font=n.get_theme_font("normal_font" if n is RichTextLabel else "font")
  for ch in text:
   if ch not in ["\n","\t"] and not font.has_char(ch.unicode_at(0)) and not ch in missing:missing+=ch
  row.texts.append({"name":str(n.name),"text":text,"font_size":font_size,"screen_px":font_size*tr.get_scale().y,"scale":str(tr.get_scale()),"missing":missing,"rect":str(Rect2(tr.origin,n.size*tr.get_scale()))})
 metrics.append(row)
func place_fixture(role: String):
 var c=Campaign.new();c.start("burst",17);c.advance_departure(true)
 var rooms: Array=c.current_nodes()
 var wanted: Dictionary=rooms.filter(func(room):return Campaign.Content.room_kind(room)==role)[0]
 var path: Array=[wanted]
 while int(path[0].floor)>1:
  for previous in rooms:
   if previous.next.has(path[0].id):path.push_front(previous);break
 for room in path:
  check(c.enter(int(room.id)),"place fixture follows route")
  if int(room.id)==int(wanted.id):break
  match str(c.s.phase):
   "combat":
    for enemy in c.model.s.enemies:enemy.hp=0
    c.model.s.reinforcements=[];c.model.s.phase="reward";c.sync_combat()
    for stage in range(3):
     if c.s.phase!="reward":break
     check(c.reward("credits"),"place fixture completes reward")
   "supply","event":c.resolve("skip");c.leave()
   _:c.leave()
 return c
func run()->void:
 output=OS.get_environment("QA_OUTPUT_DIR")
 if not output.replace("\\","/").contains("/qa_runtime/place_font_audit_20261103/"):quit(2);return
 Input.emulate_mouse_from_touch=true
 for extent in [Vector2i(1600,900),Vector2i(1280,800),Vector2i(1008,630),Vector2i(1008,454),Vector2i(844,390)]:
  root.size=extent;root.content_scale_size=Vector2i(1280,800)
  var c=Campaign.new()
  check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string("res://../qa_runtime/economy_roles_20261103/climb_carrier_heavy/shop_heavy_17_r1_n503.json"))),"earned shop restores")
  var before=canonical({"campaign":c.s,"model":c.model.s})
  await mount(c);await tap("Offer1")
  var label: String="shop_%dx%d"%[extent.x,extent.y]
  scan(label);await capture(label)
  if extent==Vector2i(1280,800):
   await tap("Details");scan("shop_detail");await capture("shop_detail");await tap("CloseOverlay")
  check(canonical({"campaign":c.s,"model":c.model.s})==before,"viewing shop preserves state")
 for role in ["supply","workshop"]:
  for extent in [Vector2i(1280,800),Vector2i(1008,630)]:
   root.size=extent;root.content_scale_size=Vector2i(1280,800)
   await mount(place_fixture(role))
   var label: String="%s_%dx%d"%[role,extent.x,extent.y]
   scan(label);await capture(label)
 FileAccess.open(output.path_join("metrics.json"),FileAccess.WRITE).store_string(JSON.stringify(metrics,"  "))
 print("PLACE FONT AUDIT COMPLETE checks=%d failures=%d"%[checks,failures.size()])
 host.free();await settle();quit(0 if failures.is_empty() else 1)
