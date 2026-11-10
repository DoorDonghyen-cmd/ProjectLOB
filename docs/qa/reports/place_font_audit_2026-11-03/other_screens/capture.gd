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
  row.texts.append({"name":str(n.name),"text":text,"font_size":font_size,"screen_px":font_size*tr.get_scale().y,"scale":str(tr.get_scale()),"missing":missing,"rect":str(Rect2(tr.origin,n.size*tr.get_scale())),"onscreen":Rect2(Vector2.ZERO,Vector2(root.size)).intersects(Rect2(tr.origin,n.size*tr.get_scale()))})
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
func earned(name: String):
 var c=Campaign.new()
 check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string("res://../qa_runtime/economy_roles_20261103/climb_carrier_heavy/"+name+".json"))),"earned state restores "+name)
 return c
func mount_at(c,extent: Vector2i)->void:
 if is_instance_valid(host):host.free()
 root.size=extent;root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS;root.content_scale_size=Vector2i(1280,800);root.content_scale_factor=1.0
 await mount(c)
func record(label: String,extent: Vector2i)->void:
 await settle()
 var key: String="%s_%dx%d"%[label,extent.x,extent.y]
 scan(key);await capture(key)
func run()->void:
 output=OS.get_environment("QA_OUTPUT_DIR")
 if not output.replace("\\","/").contains("/qa_runtime/place_font_audit_20261103/"):quit(2);return
 Input.emulate_mouse_from_touch=true
 for extent in [Vector2i(1280,800),Vector2i(1008,630)]:
  var c=earned("shop_heavy_17_r1_n503");check(c.leave(),"shop fixture can leave")
  await mount_at(c,extent);await record("map",extent)
  await tap("city_map_details");await record("map_detail",extent);await tap("workspace_close")
  await tap("city_deck");await record("parts",extent)
  await tap("AmmoTab");await record("ammo",extent);await tap("workspace_close")
  await tap("settings");await record("settings",extent)
  await mount_at(c,extent)
  await tap("menu");await record("title",extent)
  host._open_preparation();await settle();await record("preparation",extent)
  for role in ["event"]:
   await mount_at(place_fixture(role),extent);await record(role,extent)
  c=earned("combat_heavy_17_r1_n101")
  await mount_at(c,extent);await record("combat",extent)
  await tap("Parts");await record("combat_parts",extent);await tap("CloseDetail")
  await tap("Select0");await tap("SelectedDetail");await record("combat_ammo",extent);await tap("CloseDetail")
  await tap("Menu");await record("combat_menu",extent)
  # Presentation fixture: force resolved enemy state without claiming a played win.
  for e in c.model.s.enemies:e.hp=0
  c.model.s.reinforcements=[];c.model.s.phase="reward";c.sync_combat()
  await mount_at(c,extent);await record("reward_core",extent)
  check(c.reward("siege_drive"),"core reward fixture advances")
  host.redraw();await settle();await record("reward_ammo",extent)
  c=earned("gate_heavy_17_r1")
  await mount_at(c,extent);await record("gate",extent)
  await tap("city_gate_cadence");await tap("city_gate_apply");await record("gate_service",extent)
 FileAccess.open(output.path_join("metrics.json"),FileAccess.WRITE).store_string(JSON.stringify(metrics,"  "))
 print("PLACE FONT AUDIT COMPLETE checks=%d failures=%d"%[checks,failures.size()])
 host.free();await settle();quit(0 if failures.is_empty() else 1)
