extends "res://tests/weapon_magazine_ui.gd"
const Scene=preload("res://redesign/samples/hud/combat_hud.tscn")
const JourneyScene=preload("res://redesign/samples/hud/combat_journey_hud.tscn")
var states: Array=[]
func tap(id: String)->void:
 if OS.get_environment("QA_FAST_HUD")=="1":preview.board.speed_scale=0.02
 await super.tap(id)
func canonical(value):return JSON.parse_string(JSON.stringify(value))
func readable_ink(id: String,background: Color)->void:
 var label: Label=preview.node(id)
 if not label.is_visible_in_tree():return
 var fg: Color=(label.get_theme_color("font_color")*label.modulate).srgb_to_linear()
 var bg:=background.srgb_to_linear()
 var a:=fg.r*0.2126+fg.g*0.7152+fg.b*0.0722
 var b:=bg.r*0.2126+bg.g*0.7152+bg.b*0.0722
 check((maxf(a,b)+0.05)/(minf(a,b)+0.05)>=4.5,"Small label ink remains readable: "+id)
func sprite_color(art: NinePatchRect)->Color:
 var image: Image=art.texture.get_image()
 return image.get_pixel(image.get_width()/2,image.get_height()/2)*art.modulate
func art_fits(id: String)->void:
 var art: NinePatchRect=preview.node(id)
 if not art.is_visible_in_tree():return
 check(preview.get_global_rect().encloses(art.get_global_rect().abs()),"Drawn sprite stays in the viewport: "+id)
 check(art.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Decorative sprite never intercepts input: "+id)
func key(code: Key)->void:
 var e:=InputEventKey.new();e.keycode=code;e.pressed=true;root.push_input(e,true);await process_frame
 e=InputEventKey.new();e.keycode=code;e.pressed=false;root.push_input(e,true);await settle()
func fits(id: String)->void:
 var control: Control=preview.node(id)
 if not control.is_visible_in_tree():return
 check(preview.get_global_rect().encloses(control.get_global_rect()),"Viewport contains "+id)
 if control is Label and control.text_overrun_behavior==TextServer.OVERRUN_NO_TRIMMING and control.autowrap_mode==TextServer.AUTOWRAP_OFF:
  var width:=control.get_theme_font("font").get_string_size(control.text,HORIZONTAL_ALIGNMENT_LEFT,-1,control.get_theme_font_size("font_size")).x
  check(width<=control.size.x+1,"Text fits "+id+" / "+control.text)
 if control is Button:
  var scale: Vector2=control.get_global_transform_with_canvas().get_scale()
  check(control.size.y*scale.y>=43.9 and control.size.x*scale.x>=43.9,"44px touch area "+id)
func hud_layout()->void:
 for id in ["IntentTitle","Prediction","SequenceHint","HeatProjected"]:
  check(not preview.node(id).is_visible_in_tree(),"Removed explanatory cards remain hidden")
 for id in ["Title","Weapon","Bag","Parts","Menu","MagazineTitle","SelectedDetail","EjectToggle","CancelSelection","HeatLabel","Fire","Reload","Cool"]:fits(id)
 var boxes: Array=[]
 for id in ["Header","Battle","MagazineHeader","MagazineHousing","Actions"]:
  var rect: Rect2=preview.node(id).get_global_rect()
  check(preview.get_global_rect().encloses(rect),"Primary group fits "+id)
  for previous in boxes:check(not previous.intersects(rect),"Primary groups remain separate: "+id)
  boxes.append(rect)
 check(preview.board.size.y>=80,"Battlefield remains visible at short landscape sizes")
 var row: Control=preview.node("RoundRow")
 for i in range(9):
  var card: Control=preview.node("Round%d"%i)
  check(card.visible==(i<preview.model.capacity()),"Slot count matches weapon")
  if not card.visible:continue
  check(row.get_global_rect().encloses(card.get_global_rect()),"Scroll content contains card")
  check(card.size.x>=76 and card.size.y>=92,"Card preserves native minimum size")
  if i>0:check(not card.get_global_rect().intersects(preview.node("Round%d"%(i-1)).get_global_rect()),"Cards do not overlap")
  for prefix in ["Name","Value","Cost"]:
   var label: Control=preview.node(prefix+str(i))
   if not label.is_visible_in_tree():continue
   check(card.get_global_rect().encloses(label.get_global_rect()),"Card contains "+prefix)
   check(label.get_theme_font_size("font_size")>=16,"Card names, heat and values are at least 16px")
  check(not preview.node("Role%d"%i).visible and not preview.node("Gain%d"%i).visible,"Redundant metadata hidden")
  check(preview.node("Cost%d"%i).visible==(i<preview.model.s.magazine.size()),"Heat is shown for each occupied round")
 for id in ["Fire","Reload","Cool"]:
  fits(id+"Name");fits(id+"Cost")
  art_fits(id+"Art")
  check(preview.node(id).get_global_rect().encloses(preview.node(id+"Art").get_global_rect()),"Action art stays within its own hit area")
func reload_alert()->void:
 preview=Scene.instantiate();preview.resume_saved=false;root.add_child(preview);await settle()
 preview.gun_index=0;preview.case_index=1;preview.mount(false);await settle()
 # A durable stationary target lets the real fire commands empty a magazine.
 # The owned deck/draw, weapon, heat and reload rules remain production data.
 preview.model.s.enemies=[{"kind":"runner","name":"QA target","hp":1000,"max_hp":1000,"def":0,"speed":0,"distance":100,"burn":0}]
 preview.model.s.reinforcements=[];preview.model.s.projectiles=[]
 preview.refresh();await settle()
 check(not preview.node("ReloadLight").visible,"Loaded magazine has no reload alert")
 var attempts:=0
 while preview.model.s.phase=="ready" and not preview.model.s.magazine.is_empty() and attempts<10:
  await tap("Fire");attempts+=1
 check(preview.model.s.phase=="ready" and preview.model.s.magazine.is_empty(),"Actual fire empties the magazine with reserve ammunition remaining")
 for extent in [Vector2i(1280,800),Vector2i(1008,454),Vector2i(2340,1080)]:
  root.size=extent;preview.refresh();await settle()
  check(preview.node("ReloadLight").visible and preview.node("ReloadName").text.contains("필요"),"Empty magazine lights and labels the available reload")
  check(preview.node("ReloadArt").self_modulate.r>1.4,"Reload face is illuminated")
  check(preview.node("Reload").get_global_rect().encloses(preview.node("ReloadLight").get_global_rect()),"Reload lamp stays inside the existing hit target")
  await capture("reload_needed_%dx%d"%[extent.x,extent.y])
 preview.busy=true;preview.hud.lock()
 check(not preview.node("ReloadLight").visible,"Busy presentation extinguishes the reload alert")
 preview.busy=false;preview.refresh();await settle()
 await tap("Reload")
 check(not preview.model.s.magazine.is_empty() and not preview.node("ReloadLight").visible,"Real replacement fills magazine and extinguishes alert")
 preview.model.s.phase="reward";preview.refresh();await settle()
 check(not preview.node("ReloadLight").visible,"Resolved combat has no reload prompt")
 preview.queue_free();await settle()

func run()->void:
 out=OS.get_environment("QA_OUTPUT_DIR")
 if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/combat_hud_20261031/"):quit(2);return
 Input.emulate_mouse_from_touch=true
 await reload_alert()
 for size in [Vector2i(740,360),Vector2i(844,390),Vector2i(1008,454),Vector2i(1280,800)]:
  root.size=size;root.content_scale_size=Vector2i(1280,800)
  # Same earned checkpoint before/after, rendered with both real interfaces.
  preview=load("res://redesign/samples/combat_weapon_magazine.tscn").instantiate();preview.resume_saved=false;root.add_child(preview);await settle()
  preview.gun_index=0;preview.case_index=1;preview.mount(false);await settle()
  var before: Dictionary=canonical(preview.model.s)
  await capture("before_%dx%d"%[size.x,size.y]);preview.queue_free();await settle()
  preview=Scene.instantiate();preview.resume_saved=false;root.add_child(preview);await settle()
  for gun_index in range(5):
   preview.gun_index=gun_index;preview.case_index=1;preview.mount(false);await settle()
   var gun: String=preview.model.s.gun
   var suffix: String="%s_%dx%d"%[gun,size.x,size.y]
   if gun_index==0:check(canonical(preview.model.s)==before,"Same combat state as before screenshot")
   var pristine: Dictionary=canonical(preview.model.s)
   preview.refresh();await settle()
   check(canonical(preview.model.s)==pristine,"HUD refresh preserves complete state and RNG")
   hud_layout();await capture("ready_"+suffix)
   if gun=="single":
    preview.save_ok=false;preview.refresh();await settle()
    check(preview.node("SaveWarning").visible,"Save failure remains visible without opening menu");fits("SaveWarning")
    check(canonical(preview.model.s)==pristine,"Save warning cannot change battle")
    preview.save_ok=true;preview.refresh()
   var copy=preview.Model.new();copy.s=preview.Model.simulation_state(preview.model.s)
   var before_turns: int=copy.s.turns
   check(copy.fire(),"Next action used to verify visible time cost")
   var cost: int=int(copy.s.turns)-before_turns
   var shown: String=preview.node("FireCost").text
   if gun!="scatter" and not shown.contains("패배"):
    check(shown.contains(str(cost)) or (cost==0 and shown.contains("마무리")),"Displayed action cost matches actual time advance")
   await tap("Select1");await tap("SelectedDetail");check(preview.overlay_open and preview.node("DetailBody").text.contains("번째 탄"),"Selected card details open without spending it")
   await preview.fire();check(canonical(preview.model.s)==pristine,"Detail blocks combat")
   if gun_index==0:await capture("detail_"+suffix)
   await key(KEY_ESCAPE);check(not preview.overlay_open,"Escape returns from detail")
   await key(KEY_ESCAPE);check(not preview.eject_mode,"Second Escape clears selected round")
   await tap("Menu");check(preview.overlay_open and preview.node("MenuLayer").visible,"Menu opens over unchanged combat")
   await preview.fire();await preview.cool();await preview.reload_magazine();check(canonical(preview.model.s)==pristine,"Menu blocks every live action")
   if gun_index==0:await capture("menu_"+suffix)
   await tap("Help");check(not preview.node("MenuLayer").visible and preview.node("Detail").visible,"Menu action hands input to rules")
   await tap("CloseDetail");check(not preview.overlay_open,"Rules return to combat")
   await tap("Select1");check(preview.eject_mode and preview.eject_selected==[1],"Middle ejection selection by touch")
   check(canonical(preview.model.s)==pristine,"Selection does not spend card or RNG")
   hud_layout();if gun_index in [0,2,3]:await capture("selected_"+suffix)
   await key(KEY_ESCAPE);check(not preview.eject_mode and canonical(preview.model.s)==pristine,"Escape cancels planned ejection")
   await tap("Select1");await tap("EjectToggle")
   check(preview.model.ejection_remaining()==1 and preview.model.s.magazine==pristine.magazine.slice(0,1)+pristine.magazine.slice(2),"Confirm ejects exactly the selected owned card")
   hud_layout();await tap("Fire");check(preview.model.s.shots>pristine.shots,"Real shot still resolves and animates")
   hud_layout();if gun_index in [0,3]:await capture("fired_"+suffix)
   states.append({"gun":gun,"size":str(size),"phase":preview.model.s.phase,"heat":preview.model.s.heat,"peak":preview.last_prediction.get("heat",{}).get("peak_max",0)})
  # Reopen actual spent-ejection state using the same save namespace.
  var expected: Dictionary=canonical(preview.model.s)
  preview.queue_free();await settle();preview=Scene.instantiate();root.add_child(preview);await settle()
  check(preview.resumed and canonical(preview.model.s)==expected,"New HUD resumes previous comparison state exactly")
  # Keyboard focus is trapped in the menu, and Escape closes it.
  preview.node("Menu").grab_focus();await key(KEY_ENTER)
  check(preview.node("MenuLayer").visible,"Keyboard opens menu")
  preview.node("CombatMotion").grab_focus();await key(KEY_TAB)
  check(root.gui_get_focus_owner()==preview.node("MenuClose"),"Tab wraps within menu")
  await key(KEY_ESCAPE);check(not preview.overlay_open,"Escape closes menu")
  preview.queue_free();await settle()
 FileAccess.open(out.path_join("ui.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"states":states,"action_animation_ms":action_times},"  "))
 print("COMBAT HUD UI COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
