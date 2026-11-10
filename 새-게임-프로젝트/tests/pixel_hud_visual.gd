extends "res://tests/combat_hud_ui.gd"
const Cells=preload("res://redesign/samples/hud/pixel_heat_cells.gd")
var samples: Array=[]
func pixel_state()->void:
 var cells=preview.node("HeatCells")
 check(cells.limit==preview.Content.heat_limit(preview.model.s),"Cell count uses actual modified heat limit")
 check(cells.current==preview.model.s.heat,"Filled cells use current heat")
 check(cells.peak==int(preview.node("HeatPreview").value),"Segment forecast equals real shot/ejection forecast")
 var ordinal:=0
 for i in range(preview.model.capacity()):
  var occupied: bool=i<preview.model.s.magazine.size()
  var selected: bool=preview.eject_mode and preview.eject_selected.has(i)
  check(preview.node("RoundArt%d"%i).visible,"Capacity sockets survive depletion")
  check((preview.node("RoundArt%d"%i).modulate.r<0.5)==not occupied,"Empty socket is dimmed without hiding capacity")
  check(preview.node("Face%d"%i).position.y==0,"Selection keeps the authored card position")
  if selected:check(preview.node("Index%d"%i).text=="제외","Selected round has a text cue")
  elif preview.node("Index%d"%i).visible:
   ordinal+=1;check(preview.node("Index%d"%i).text==str(ordinal),"Fire numbering skips the excluded round")
 samples.append({"gun":preview.model.s.gun,"size":str(root.size),"capacity":preview.model.capacity(),"heat_limit":cells.limit,"heat":cells.current,"peak":cells.peak,"ordinals":ordinal})
func fonts_in(control: Node)->void:
 if control is Label and control.is_visible_in_tree():
  var font: Font=control.get_theme_font("font")
  for character in control.text:
   if character in ["\n","\r","\t"]:continue
   check(font.has_char(character.unicode_at(0)),"UI font contains U+%04X in %s"%[character.unicode_at(0),control.name])
 for child in control.get_children():fonts_in(child)

func run()->void:
 out=OS.get_environment("QA_OUTPUT_DIR")
 if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/combat_hud_20261031/"):quit(2);return
 Input.emulate_mouse_from_touch=true
 root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800)
 # The authored UI must be visible without the gameplay controller's _ready().
 preview=Scene.instantiate();preview.set_script(null);root.add_child(preview);await settle()
 var row: Control=preview.find_child("RoundRow",true,false)
 check(row!=null and row.is_visible_in_tree() and row.size.y>=96,"Serialized editor composition is visible without runtime layout")
 fonts_in(preview);await capture("authored_scene")
 preview.queue_free();await settle()
 for scene in ["combat_menu","combat_detail","journey_flow"]:
  preview=load("res://redesign/samples/hud/%s.tscn"%scene).instantiate()
  root.add_child(preview);await settle()
  check(preview.visible and preview.size.x>700,"Standalone overlay has an authored visible composition: "+scene)
  fonts_in(preview);await capture("authored_"+scene)
  preview.queue_free();await settle()
 preview=Scene.instantiate();preview.resume_saved=false;root.add_child(preview);await settle()
 for index in range(5):
  preview.gun_index=index;preview.case_index=1;preview.mount(false);await settle()
  pixel_state();fonts_in(preview)
 # A public shot and cooldown retain actual ammunition ownership.
 preview.gun_index=0;preview.case_index=1;preview.mount(false);await settle()
 await tap("Fire")
 var kept: Array=preview.model.s.magazine.duplicate()
 var before_heat: int=preview.model.s.heat
 check(not preview.node("Cool").disabled,"A fired magazine exposes cooldown")
 await tap("Cool")
 check(preview.model.s.magazine==kept and preview.model.s.heat<before_heat,"Public cooldown lowers heat without consuming rounds")
 await tap("Reload");pixel_state()
 check(preview.model.s.magazine.size()==preview.model.capacity(),"Public reload refills sockets from the shuffled deck")
 # Variable limits are component cases, not proposed game balance values.
 var gauge=Cells.new();gauge.size=Vector2(568,18);root.add_child(gauge)
 for maximum in [6,8,10,12,14,20]:
  gauge.display(maximum-2,maximum,maximum,true);await settle()
  check(gauge.limit==maximum and gauge.current==maximum-2 and gauge.danger,"Variable-capacity gauge state")
 gauge.queue_free()
 # Real overheat/contact case, reached by legal shots.
 preview.gun_index=0;preview.case_index=0;preview.mount(false);await settle()
 for attempt in range(5):
  if float(preview.last_prediction.get("heat",{}).get("forced_probability",0))>0:break
  if not preview.model.fire():break
  preview.refresh();await settle()
 check(preview.node("HeatCells").danger,"Real forced-overheat forecast has danger segmentation")
 check(preview.node("FireCost").text.contains("패배"),"Contact risk survives visual replacement")
 pixel_state();hud_layout();fonts_in(preview);await capture("danger")
 preview.queue_free();await settle()
 # Matching journey state for review, including partial sockets and real ejection.
 preview=JourneyScene.instantiate();preview.resume_saved=false;root.add_child(preview);await settle()
 await tap("Fire");pixel_state();fonts_in(preview);await capture("journey_partial")
 await tap("Select1");pixel_state();fonts_in(preview);await capture("journey_selected")
 await key(KEY_ESCAPE)
 for size in [Vector2i(1008,630),Vector2i(1280,576)]:
  root.size=size;await settle();hud_layout();pixel_state();fonts_in(preview);await capture("journey_partial_%dx%d"%[size.x,size.y])
 FileAccess.open(out.path_join("visual.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples},"  "))
 print("PIXEL HUD VISUAL COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
