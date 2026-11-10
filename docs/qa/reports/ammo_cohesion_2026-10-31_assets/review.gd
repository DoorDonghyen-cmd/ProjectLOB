extends "res://tests/ammo_collection_ui_runner.gd"
const OldArt=preload("res://../qa_runtime/ammo_cohesion_20261031/source_before/새-게임-프로젝트/redesign/ammo_art.gd")
const Families=["basic","pierce","precise","charge","cool","arc","push","bore","shatter","detonate","chase","bypass","thermal","vent","spread","charge_heat","charge_hot","sequence","prepare","disrupt"]

class Gallery extends Control:
 var before:=false
 func _draw()->void:
  var theme=preload("res://redesign/samples/hud/combat_hud_theme.tres")
  var font=preload("res://redesign/combat_pixel_font.tres")
  draw_rect(Rect2(Vector2.ZERO,size),Color("14262e"))
  draw_string(font,Vector2(36,43),"탄환 20계열 · "+("변경 전" if before else "새 금속 재질"),HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color("e1d2ac"))
  draw_string(font,Vector2(36,70),"실제 공용 표시 · 52×80 영역 · 이름과 설명은 게임 데이터",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("9cad9f"))
  for i in range(Families.size()):
   var id: String=Families[i]
   var pos:=Vector2(28+(i%5)*248,92+(i/5)*174)
   draw_style_box(theme.get_stylebox("ammo","Panel"),Rect2(pos,Vector2(232,160)))
   var name: String=Ammo.AMMO[id].name if Ammo.AMMO.has(id) else id
   draw_string(font,pos+Vector2(12,27),name,HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color("e6e8d7"))
   draw_style_box(theme.get_stylebox("well","Panel"),Rect2(pos+Vector2(12,46),Vector2(64,94)))
   if before:OldArt.draw(self,id,Rect2(pos+Vector2(18,53),Vector2(52,80)))
   else:Art.draw(self,id,Rect2(pos+Vector2(18,53),Vector2(52,80)))
   draw_string(font,pos+Vector2(90,77),str(Ammo.AMMO[id].get("type","")),HORIZONTAL_ALIGNMENT_LEFT,130,18,Color("aabdb3"))
   draw_string(font,pos+Vector2(90,108),id,HORIZONTAL_ALIGNMENT_LEFT,130,16,Color("aabdb3"))

func _run()->void:
 if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/ammo_cohesion_20261031/"):quit(2);return
 Input.emulate_mouse_from_touch=true
 for id in Ammo.AMMO:
  var family: String=Ammo.source_id(id)
  check(Art.Regions.has(family) or Art.SpecialRegions.has(family) or Art.LegacyRegions.has(family),"All ammo/grade/profile variants have authored art: "+id)
 for pair in [[Art.Sheet,Art.Regions],[Art.SpecialSheet,Art.SpecialRegions],[Art.LegacySheet,Art.LegacyRegions]]:
  var image: Image=pair[0].get_image()
  for id in pair[1]:
   var region: Rect2=pair[1][id]
   check(Rect2(Vector2.ZERO,image.get_size()).encloses(region),"Atlas region fits: "+id)
   check(image.get_region(Rect2i(region)).get_used_rect().has_area(),"Atlas selects an actual sprite: "+id)
 root.size=Vector2i(1280,800);root.content_scale_size=root.size
 var gallery:=Gallery.new();gallery.size=Vector2(1280,800);gallery.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;root.add_child(gallery)
 gallery.before=true;gallery.queue_redraw();await capture("family_before")
 gallery.before=false;gallery.queue_redraw();await capture("family_after")
 gallery.queue_free();await settle()
 screen=load("res://redesign/main.tscn").instantiate();screen.save_enabled=false;screen.presentation_speed=0.02;root.add_child(screen);await settle()
 for resolution in [Vector2i(1008,630),Vector2i(1280,800),Vector2i(1440,630)]:
  root.size=resolution;root.content_scale_size=Vector2i(1280,800)
  screen._debug_city("reward");await settle();await tap("city_reward_volley_drive")
  await capture("reward_%d"%resolution.x)
  await setup_hand(["bore","push","shatter","detonate","chase","bypass","thermal","vent","charge_heat","charge_hot"],true)
  fit();await capture("combat_family_%d"%resolution.x)
  screen.model.s.deck=Families.slice(1)
  screen.model.begin_encounter();screen.redraw();await settle()
  var before: Dictionary=screen.model.s.duplicate(true)
  await tap("ammo_bag");check(screen.find_child("AmmoBagView",true,false)!=null,"Shared deck viewer opens")
  await capture("bag_%d"%resolution.x)
  await tap("bag_details");await capture("detail_%d"%resolution.x)
  await tap("DialogClose");await tap("workspace_close")
  check(screen.model.s==before,"Reading new art leaves cards and RNG unchanged")
 screen.queue_free();await process_frame
 FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("review.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"ammo_ids":Ammo.AMMO.size(),"families":Families.size()},"  "))
 print("AMMO COHESION REVIEW COMPLETE checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
