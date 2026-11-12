extends RefCounted
## Presentation only: use the existing forecast and command controls; never roll RNG.
const Content=preload("res://redesign/content.gd")
const Model=preload("res://redesign/model.gd")
const HudTheme=preload("res://redesign/samples/hud/combat_hud_theme.tres")
const SmallFont=preload("res://assets/fonts/NeoDunggeunmoPro-Regular.ttf")
const LargeFont=preload("res://assets/fonts/NeoDunggeunmoPro-Regular.ttf")
const HudMaterial=preload("res://redesign/combat_material/skin.gd")
const Tags=preload("res://redesign/tag_build.gd")
const TagChips=preload("res://redesign/tag_chips.gd")
const TEXT=HudMaterial.INK
const MUTED=HudMaterial.MUTED
const GOLD=Color("f3cf73")
const WARNING=Color("ff6f61")
var ui: Control
var previous_focus: Control
var focused_round: int=-1
var observed_model
var observed_stack: Array=[]
var observed_remaining:=0
var observed_turns: int=-1
var previous_scale_mode: int=0
var previous_scale_factor: float=1.0
var previous_scale_size:=Vector2i.ZERO
var scaling_active:=false
var feedback

func _init(surface: Control)->void:ui=surface
func n(id: String)->Node:return ui.node(id)

func bind()->void:
 feedback=preload("res://redesign/samples/hud/combat_hud_feedback.gd").new()
 ui.add_child(feedback);feedback.bind(ui)
 previous_scale_mode=ui.get_window().content_scale_mode
 previous_scale_factor=ui.get_window().content_scale_factor
 previous_scale_size=ui.get_window().content_scale_size
 scaling_active=true
 ui.get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
 ui.get_window().content_scale_size=Vector2i.ZERO
 ui.tree_exiting.connect(restore_scale)
 n("CancelSelection").pressed.connect(clear_selection)
 n("Menu").pressed.connect(open_menu)
 n("MenuClose").pressed.connect(close_menu)
 n("SelectedDetail").pressed.connect(func():inspect_round(maxi(0,focused_round)))
 # Connect before the source controller: dismiss the menu before its guarded action.
 for id in ["Help","Reset","Pressure","Other"]:n(id).pressed.connect(close_menu)
 for i in range(ui.slot_count):
  n("Inspect%d"%i).pressed.connect(inspect_round.bind(i))
  for prefix in ["Inspect","Select"]:
   var control: Button=n(prefix+str(i))
   for state in ["normal","pressed","disabled"]:control.add_theme_stylebox_override(state,HudTheme.get_stylebox("clear","Panel"))
   control.add_theme_stylebox_override("hover",HudTheme.get_stylebox("focus","Button"))
 n("MenuSurface").add_theme_stylebox_override("panel",HudTheme.get_stylebox("clear","Panel"))
 n("DetailSurface").add_theme_stylebox_override("panel",HudTheme.get_stylebox("clear","Panel"))
 for id in ["Cool","Reload","Fire","EjectApply"]:
  var button: Button=n(id)
  for state in ["normal","hover","pressed","disabled"]:
   button.add_theme_stylebox_override(state,HudTheme.get_stylebox("clear","Panel"))
  for event in ["mouse_entered","mouse_exited","button_down","button_up","focus_entered","focus_exited"]:
   button.connect(event,pixel_key.bind(id))
 var menu_order: Array=["MenuClose","Help","Reset","Pressure","Other","EffectsVolume","CombatMotion"]
 cycle_focus(menu_order)
 cycle_focus(["DetailUp","DetailDown","CloseDetail"])
 ui.resized.connect(apply_safe_area)
 apply_safe_area()

func pixel_key(id: String)->void:
 var button: Button=n(id)
 var art: NinePatchRect=n(id+"Art")
 var down: bool=id=="Fire" and button.is_pressed() and not button.disabled
 art.queue_redraw()
 var required: bool=id=="Reload" and reload_required()
 art.modulate=Color(1.25,1.25,1.25,1) if button.is_hovered() and not button.disabled else Color.WHITE
 # The shared line frame owns modulate on redraw; the lamp tint is independent.
 art.self_modulate=Color(1.65,1.42,1.08,1) if required else Color.WHITE
 if id=="Reload":n("ReloadLight").visible=required
 # Reset offsets rather than position: an early minimum size must not leave a
 # stale right offset when the parent container finishes laying out the key.
 art.offset_left=0;art.offset_right=0
 art.offset_top=0;art.offset_bottom=0
 # Only the primary action's contents depress; hit areas and silhouettes stay put.
 if id=="Fire":
  n("FireName").position.y=2 if down else 0
  n("FireCost").position.y=30 if down else 28

func reload_required()->bool:
 return not ui.busy and ui.model.s.phase=="ready" and ui.model.s.magazine.is_empty() and not n("Reload").disabled and not ui.model.can_emergency_resupply()

func cycle_focus(names: Array)->void:
 for i in range(names.size()):
  var button: Control=n(names[i])
  button.focus_next=button.get_path_to(n(names[(i+1)%names.size()]))
  button.focus_previous=button.get_path_to(n(names[(i+names.size()-1)%names.size()]))

func restore_scale()->void:
 if not is_instance_valid(ui):return
 # Restoring the Window synchronously resizes this still-attached Control.
 # Stop its resize callback first or it reapplies the combat multiplier to menus.
 scaling_active=false
 if ui.resized.is_connected(apply_safe_area):ui.resized.disconnect(apply_safe_area)
 ui.get_window().content_scale_mode=previous_scale_mode
 ui.get_window().content_scale_factor=previous_scale_factor
 ui.get_window().content_scale_size=previous_scale_size

func apply_safe_area()->void:
 if not scaling_active or not ui.is_inside_tree():return
 var window: Vector2i=DisplayServer.window_get_size()
 # Local to this HUD: retain readable units at small windows, enlarge on dense displays.
 var factor: float=maxf(1.0,floorf(minf(float(window.x)/1008.0,float(window.y)/454.0)))
 if not is_equal_approx(ui.get_window().content_scale_factor,factor):ui.get_window().content_scale_factor=factor
 if not OS.has_feature("android") or window.x<=0 or window.y<=0:return
 var safe: Rect2i=DisplayServer.get_display_safe_area()
 if safe.size.x<=0 or safe.size.y<=0:return
 var scale:=Vector2(ui.size.x/window.x,ui.size.y/window.y)
 var margins: Dictionary={"left":8+ceili(safe.position.x*scale.x),"right":8+ceili(maxi(0,window.x-safe.end.x)*scale.x),"top":8+ceili(safe.position.y*scale.y),"bottom":8+ceili(maxi(0,window.y-safe.end.y)*scale.y)}
 for edge in margins:
  n("Safe").add_theme_constant_override("margin_"+edge,margins[edge])
  if n("FlowSafe")!=null:n("FlowSafe").add_theme_constant_override("margin_"+edge,margins[edge])

func open_menu()->void:
 if ui.busy or ui.overlay_open or ui.eject_mode:return
 previous_focus=ui.get_viewport().gui_get_focus_owner()
 n("MenuLayer").show();ui.overlay_open=true;n("MenuClose").grab_focus()
func close_menu()->void:
 if not n("MenuLayer").visible:return
 n("MenuLayer").hide()
 ui.overlay_open=n("Detail").visible or (n("JourneyPanel")!=null and n("JourneyPanel").visible)
 if not ui.overlay_open:n("Menu").grab_focus()

func back()->bool:
 if ui.busy:return false
 if n("MenuLayer").visible:close_menu();return true
 if n("Detail").visible:ui.close_detail();return true
 if n("JourneyPanel")!=null and n("JourneyPanel").visible:
  if ui.panel_mode!="flow":ui.cancel_panel();return true
  return false
 if ui.eject_mode or focused_round>=0:clear_selection();return true
 open_menu();return n("MenuLayer").visible

func choose_round(index: int)->void:
 if ui.busy or ui.overlay_open or index<0 or index>=ui.model.s.magazine.size():return
 if index==Model.WeaponRoles.mark(ui.model.s):inspect_round(index);return
 var remaining: int=ui.model.ejection_remaining()
 if ui.model.s.phase=="ready" and remaining>0:
  if ui.eject_selected.has(index):
   ui.eject_selected.erase(index)
   focused_round=-1 if ui.eject_selected.is_empty() else int(ui.eject_selected.back())
  elif ui.eject_selected.size()<remaining:
   ui.eject_selected.append(index);focused_round=index
  ui.eject_mode=not ui.eject_selected.is_empty()
 else:
  # Details remain available after spending this magazine's removal allowance.
  inspect_round(index)
  return
 ui.refresh()

func clear_selection()->void:
 if ui.busy or ui.overlay_open:return
 focused_round=-1;ui.eject_mode=false;ui.eject_selected.clear();ui.refresh()

func remove_selected()->void:
 if ui.busy or ui.overlay_open or not ui.eject_mode or ui.eject_selected.is_empty():return
 focused_round=-1
 ui.apply_ejection()

func pointer_input(event: InputEvent)->void:
 if ui.busy or ui.overlay_open or (not ui.eject_mode and focused_round<0):return
 var point: Vector2
 if event is InputEventScreenTouch and event.pressed:point=event.position
 elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:point=event.position
 else:return
 # Include disabled buttons: a tap on disabled Fire must not clear selection
 # during _input and then reach a newly enabled Fire in the same input event.
 for button in ui.find_children("*","BaseButton",true,false):
  if not button.is_visible_in_tree():continue
  var local: Vector2=button.get_global_transform_with_canvas().affine_inverse()*point
  if Rect2(Vector2.ZERO,button.size).has_point(local):return
 clear_selection()

func inspect_round(index: int)->void:
 if ui.busy or ui.overlay_open or index<0 or index>=ui.model.s.magazine.size():return
 var id: String=ui.model.s.magazine[index]
 var spec: Dictionary=Content.AMMO[id]
 var amount:=str(spec.dmg)+(" ×%d회"%int(spec.get("hits",2)) if str(spec.effect)=="double" else "")
 if index==Model.WeaponRoles.mark(ui.model.s):
  ui.show_detail(spec.name+" · 봉인탄 ×3","이번 탄창의 이 한 발만 직접 피해 ×3.\n빼내기 불가 · 발사하면 탄창 교체 잠금 해제.\n냉각은 사용할 수 있습니다.\n화상·전격 전이·기폭 효과는 강화하지 않습니다.")
  return
 ui.show_detail(spec.name,"%d번째 탄 · %d칸 사용 · 발열 %s\n기본 피해 %s · 장갑 관통 %d\n\n%s\n\n위로 올라온 청록 테두리의 탄이 다음 발사 대상입니다. 카드의 기본 피해는 표적·총기·코어·연계 적용 전 위력입니다.\n사용한 탄은 이번 전투에 돌아오지 않으며 다음 전투에 복구됩니다."%[index+1,Content.slot_cost(id),Content.heat_label(id,ui.model.s),amount,int(spec.pen),preload("res://redesign/readability.gd").description(id,ui.model.s)])

func help_body(title: String,body: String)->String:
 body=body.replace("−","-")
 if title not in ["총기별 탄창 운용","탄창과 선택"]:return body
 return "탄환 선택 → 위쪽의 빼내기 버튼\n같은 탄·빈 곳을 누르면 선택 취소\n탄환 정보는 선택 후 상세에서 확인\n\n"+body.replace("상단 버튼으로 총기와 전투를 바꿔 비교합니다.","메뉴에서 총기와 전투를 바꿔 비교합니다.")

func action(id: String,title: String,cost: String,danger: bool=false)->void:
 var button: Button=n(id)
 button.text=""
 button.tooltip_text=title+" · "+cost
 # Godot 4.7 has native accessibility names even when labels are child nodes.
 button.accessibility_name=button.tooltip_text
 n(id+"Name").text=title;n(id+"Cost").text=cost
 if n(id+"Hardware")!=null:n(id+"Hardware").modulate=Color("647570") if button.disabled else Color.WHITE
 n(id+"Name").modulate=Color.WHITE;n(id+"Cost").modulate=Color.WHITE
 n(id+"Name").add_theme_color_override("font_color",Color("1c0903") if id=="Fire" else Color("f2dcaa") if id=="Reload" else Color("bff3f1") if id=="Cool" else TEXT)
 n(id+"Cost").add_theme_color_override("font_color",Color("1c0903") if id=="Fire" else WARNING if danger else MUTED)
 button.modulate=Color.WHITE
 if button.disabled:
  n(id+"Name").add_theme_color_override("font_color",HudMaterial.DIM);n(id+"Cost").add_theme_color_override("font_color",HudMaterial.DIM)
 pixel_key(id)

func render()->void:
 var model=ui.model
 var state: Dictionary=model.s
 var active: bool=state.phase=="ready"
 var stack: Array=state.magazine
 if observed_model!=model or observed_stack!=stack or observed_turns!=int(state.turns):focused_round=-1
 observed_model=model;observed_stack=stack.duplicate();observed_turns=int(state.turns)
 observed_remaining=Model.Reserve.remaining(state)
 var prediction: Dictionary=ui.last_prediction
 var shots: Array=prediction.get("shots",[])
 var heat: Dictionary=prediction.get("heat",{})
 var fire_text: String=n("Fire").text
 var reload_text: String=n("Reload").text
 var cool_text: String=n("Cool").text
 var lost_chance: float=float(prediction.get("lost_probability",1.0 if prediction.get("phase","")=="lost" else 0.0))
 var overheats: bool=float(heat.get("forced_probability",0))>0
 var random: bool=bool(prediction.get("random",false))
 var peak:=int(heat.get("peak_max",state.heat))
 var limit:=Content.heat_limit(state)
 n("SaveWarning").visible=not ui.save_ok
 n("Weapon").text=Content.weapon_spec(state).name
 n("Weapon").tooltip_text=ui.weapon_hint()
 n("MagazineTitle").text="선택 %d / %d"%[ui.eject_selected.size(),model.ejection_remaining()] if ui.eject_mode else "탄창 %d / %d"%[stack.size(),model.capacity()]
 var selected: int=ui.eject_selected.size()
 var eject_loss: bool=ui.eject_preview.get("phase","")=="lost"
 n("EjectToggle").text="빼내면 패배" if eject_loss else "%d발 빼내기"%selected if selected>0 else "빼내기 · %d"%model.ejection_remaining()
 n("EjectToggle").disabled=ui.busy or not active or selected==0
 n("EjectToggle").tooltip_text="%d발 빼내기 · 탄약 소진으로 패배"%selected if eject_loss else "선택한 탄은 이번 전투에서 소모됩니다" if selected>0 else "탄환을 먼저 선택하세요 · 탄창당 2발까지" if model.ejection_remaining()>0 else "이 탄창의 빼내기를 모두 사용했습니다"
 n("EjectToggle").add_theme_color_override("font_color",WARNING if eject_loss else TEXT)
 n("EjectToggle").accessibility_name=n("EjectToggle").text+" · "+n("EjectToggle").tooltip_text
 n("SelectedDetail").visible=not stack.is_empty()
 n("SelectedDetail").text="%d번 상세"%(maxi(0,focused_round)+1)
 n("CancelSelection").visible=selected>0
 n("CancelSelection").disabled=ui.busy
 n("SelectedDetail").disabled=ui.busy
 n("SelectedDetail").tooltip_text=Content.AMMO[stack[maxi(0,focused_round)]].name if n("SelectedDetail").visible else ""
 n("SelectedDetail").accessibility_name=n("SelectedDetail").text+" · "+n("SelectedDetail").tooltip_text
 n("Fire").visible=true
 n("EjectApply").visible=false
 n("Parts").text="빌드"
 n("Bag").text="남은 %d발"%Model.Reserve.remaining(state)
 n("HeatLabel").text="%d / %d"%[state.heat,limit]
 n("HeatPreview").max_value=limit
 n("HeatPreview").value=peak if active and not shots.is_empty() else state.heat
 n("HeatPreview").modulate=WARNING if overheats else Color.WHITE
 n("HeatWarning").visible=overheats or int(state.heat)>=limit
 n("HeatCells").display(int(state.heat),limit,peak if active and not shots.is_empty() else int(state.heat),overheats or int(state.heat)>=limit)
 n("HeatBar").modulate=WARNING if int(state.heat)*2>=limit else Color.WHITE
 n("HeatGroup").tooltip_text="발열 %d / %d\n채운 칸: 현재 열 · 점선 칸: 이번 사격 도중 최고 %d"%[state.heat,limit,peak]
 var shot_title: String="연쇄 사격" if state.gun=="amplifier" else "%d발 사격"%mini(Model.MagazineTrial.pulse(state),stack.size())
 if prediction.get("phase","") in ["won","reward"] and not random:shot_title="%d발로 마무리"%shots.size()
 if fire_text.contains("강행"):shot_title="강행 사격"
 if ui.Trial.range_enabled(state):
  var selected_count: int=ui.current_budget()
  shot_title=("최대 %d발 사격" if random or shots.size()!=selected_count else "%d발 사격")%selected_count
 if stack.is_empty():shot_title="빈 탄창"
 var turns_max:=int(heat.get("turns_max",prediction.get("turns",1)))
 var turns_min:=int(heat.get("turns_min",turns_max))
 var shot_cost: String="전투 마무리" if turns_max==0 and not shots.is_empty() else "적 %d행동"%turns_max if turns_min==turns_max else "적 최대 %d행동"%turns_max
 if overheats:shot_cost+=" · 과열"
 if lost_chance>0:shot_cost="도달 위험 · 패배 "+ui.chance_text(lost_chance)
 if not active:shot_title="전투 종료";shot_cost="메뉴에서 다음 선택"
 action("Fire",shot_title,shot_cost,lost_chance>0 or overheats)
 var emergency: bool=model.can_emergency_resupply()
 var swap_danger:=reload_text.contains("위험")
 action("Reload","비상 보급" if emergency else "재장전 필요" if reload_required() else "탄창 교체",("피격 위험" if reload_text.contains("피격") else "접촉 위험") if swap_danger else "적 %d행동"%(model.emergency_cost() if emergency else model.reload_cost()),swap_danger)
 if Model.WeaponRoles.locked(state):
  n("Reload").disabled=true
  action("Reload","교체 잠김","봉인탄 먼저")
 var cool_danger:=cool_text.contains("위험")
 action("Cool","냉각",("피격 위험" if cool_text.contains("피격") else "접촉 위험") if cool_danger else "적 1행동" if not n("Cool").disabled else "",cool_danger)
 if Model.WeaponRoles.can_reverse(state,Content.anchor):
  action("Cool","냉각·역전",("피격 위험" if cool_text.contains("피격") else "접촉 위험") if cool_danger else "적 1행동" if not n("Cool").disabled else "열 필요",cool_danger)
 action("EjectApply","%d발 빼내기"%ui.eject_selected.size(),"탄약 소진으로 패배" if ui.eject_preview.get("phase","")=="lost" else "이번 전투에서 소모",true)
 for i in range(ui.slot_count):
  var occupied:=i<stack.size()
  var removed: bool=ui.eject_mode and ui.eject_selected.has(i)
  var at: int=i-ui.eject_selected.filter(func(index):return index<i).size() if ui.eject_mode else i
  var firing: bool=occupied and not removed and at<shots.size() and float(shots[at].get("used_probability",1))>0
  if ui.Trial.range_enabled(state):firing=active and occupied and not removed and at<ui.current_budget()
  var slot: Control=n("Round%d"%i)
  slot.modulate=Color.WHITE
  slot.add_theme_stylebox_override("panel",HudTheme.get_stylebox("clear","Panel"))
  var carrier: NinePatchRect=n("RoundArt%d"%i)
  carrier.set("face","empty" if not occupied else "removed" if removed else "firing" if firing else "normal")
  for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:carrier.set_patch_margin(side,12 if occupied else 8)
  carrier.modulate=Color(0.4,0.4,0.4,1) if not occupied else Color.WHITE
  # The scene reserves 8px above resting cards; the hit target stays fixed.
  n("Face%d"%i).offset_top=0 if firing or removed else 8
  n("Face%d"%i).offset_bottom=-8 if firing or removed else 0
  n("RoundOutline%d"%i).add_theme_stylebox_override("panel",HudTheme.get_stylebox("clear","Panel"))
  n("EmptyMark%d"%i).visible=false;n("EmptyRail%d"%i).visible=false
  n("Inspect%d"%i).visible=false
  n("Select%d"%i).visible=occupied
  n("Select%d"%i).disabled=ui.busy or (ui.eject_mode and not removed and selected>=model.ejection_remaining())
  n("Select%d"%i).set_pressed_no_signal(removed)
  n("Name%d"%i).visible=occupied
  n("Name%d"%i).modulate=Color.WHITE
  n("Name%d"%i).add_theme_color_override("font_color",TEXT)
  n("Role%d"%i).visible=false;n("Gain%d"%i).visible=false
  n("Value%d"%i).visible=occupied;n("Cost%d"%i).visible=occupied
  if occupied:
   var base: Dictionary=Content.primary_stat(stack[i],state)
   n("Value%d"%i).text=str(base.value).replace("−","-")
   n("Cost%d"%i).text="열 "+Content.heat_label(stack[i],state).replace("−","-")
  n("Value%d"%i).modulate=Color.WHITE
  n("Value%d"%i).add_theme_font_override("font",LargeFont)
  n("Value%d"%i).add_theme_font_size_override("font_size",24)
  n("Value%d"%i).add_theme_color_override("font_color",GOLD)
  n("Index%d"%i).visible=removed or firing
  n("Index%d"%i).text="제외" if removed else str(at+1)
  n("Index%d"%i).add_theme_color_override("font_color",Color("021015"))
  n("Icon%d"%i).modulate=Color.WHITE
  n("Select%d"%i).tooltip_text=Content.AMMO[stack[i]].name if occupied else "빈칸"
  n("Select%d"%i).accessibility_name="%d번째 탄 · %s%s"%[i+1,n("Select%d"%i).tooltip_text," · 빼내기 선택됨" if removed else ""]
  n("Seal%d"%i).visible=occupied and i==Model.WeaponRoles.mark(state)
  if n("Seal%d"%i).visible:
   n("Select%d"%i).tooltip_text+=" · 봉인탄 ×3 · 빼내기 불가"
   n("Select%d"%i).accessibility_name+=" · 봉인탄 ×3 · 빼내기 불가"
  # Tag build runs (2026-11-11): chips and the boosted number (sync_tag_card), tags in the tooltip.
  var tagged: bool=sync_tag_card(i,str(stack[i]) if occupied else "")
  if tagged:
   var own: Array=Tags.tags(state,str(stack[i]))
   n("Select%d"%i).tooltip_text+=" · 태그 "+"·".join(own)
   n("Select%d"%i).accessibility_name+=" · 태그 "+"·".join(own)
 for button in ui.find_children("*","Button",true,false):
  var frame=button.get_node_or_null(str(button.name)+"Frame")
  if frame!=null and frame.has_method("sync"):frame.sync()
 n("Menu").disabled=ui.busy or ui.eject_mode
 feedback.sync_phase()
 sync_focus()

## Tag chips in the card's top strip (filled when a part reads the tag) and the card number
## raised by unconditional tag parts, in green. Also called while the magazine animates
## (combat_hud_feedback.gd show_round). Returns whether the round shows tags.
func sync_tag_card(i: int,id: String)->bool:
 var state: Dictionary=ui.model.s
 var face: Control=n("Face%d"%i)
 var chips: Control=face.get_node_or_null("Tags")
 if chips==null and Tags.enabled(state):
  chips=TagChips.new();chips.name="Tags";chips.position=Vector2(6,2);face.add_child(chips)
 if chips==null:return false
 var own: Array=Tags.tags(state,id) if not id.is_empty() else []
 chips.visible=Tags.enabled(state) and not own.is_empty()
 if not chips.visible:return false
 chips.set_tags(own,Tags.read_tags(state,Content.active_parts(state)))
 var boost: Dictionary=Tags.card_bonus(state,id,Content.active_parts(state))
 if int(boost.add)!=0 or int(boost.percent)!=100:
  if str(Content.primary_stat(id,state).label)=="피해":
   var per_hit:=(Content.damage(id,state)+int(boost.add))*int(boost.percent)/100
   n("Value%d"%i).text=str(per_hit)+("×%d"%Content.hit_count(id,state) if str(Content.AMMO[id].effect)=="double" else "")
  n("Value%d"%i).add_theme_color_override("font_color",Tags.BOOSTED)
 return true

func lock()->void:
 feedback.begin_action()
 focused_round=-1;n("SelectedDetail").hide()
 n("Menu").disabled=true
 for i in range(ui.slot_count):n("Inspect%d"%i).disabled=true
 for id in ["Fire","Reload","Cool","EjectApply"]:
  if n(id+"Hardware")!=null:n(id+"Hardware").modulate=Color("647570")
  # Child Labels do not inherit Button's disabled font. Fire's dark active ink
  # disappears when its orange key switches to the disabled dark face.
  for suffix in ["Name","Cost"]:
   n(id+suffix).modulate=Color.WHITE
   n(id+suffix).add_theme_color_override("font_color",HudMaterial.DIM)
  pixel_key(id)

func sync_focus()->void:
 if n("MenuLayer").visible:ui.overlay_open=true;return
 var focus: Control=ui.get_viewport().gui_get_focus_owner()
 var flow: Control=n("JourneyPanel")
 if flow!=null and flow.visible:
  ui.overlay_open=true
  if focus==null or not flow.is_ancestor_of(focus) or not focus.is_visible_in_tree():
   if n("RewardRow").visible:n("RewardPick0").grab_focus()
   elif n("JourneyConfirm").visible and not n("JourneyConfirm").disabled:n("JourneyConfirm").grab_focus()
   elif n("JourneyCancel").visible and not n("JourneyCancel").disabled:n("JourneyCancel").grab_focus()
 elif n("Detail").visible:
  if focus==null or not n("Detail").is_ancestor_of(focus):n("CloseDetail").grab_focus()
 elif focus==null or not focus.is_visible_in_tree():
  if n("SelectedDetail").visible:n("SelectedDetail").grab_focus()
  elif ui.eject_mode:n("EjectToggle").grab_focus()
  elif not n("Fire").disabled:n("Fire").grab_focus()
  else:n("Menu").grab_focus()
