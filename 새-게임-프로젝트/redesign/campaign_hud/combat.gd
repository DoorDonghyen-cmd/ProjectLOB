extends "res://redesign/samples/hud/combat_weapon_hud.gd"
## Bind the shared HUD to the live campaign. No fixture or comparison save.
const RegionalLayouts = [
 preload("res://redesign/samples/hud/prototype_battle_view.gd"),
 preload("res://redesign/campaign_hud/foundry_view.gd"),
 preload("res://redesign/campaign_hud/garden_view.gd"),
 preload("res://redesign/campaign_hud/noble_view.gd"),
 preload("res://redesign/campaign_hud/central_view.gd")
]
var host: Control
var combo_label: Label

func _ready()->void:
 drag=preload("res://redesign/samples/fire_heat/drag.gd").new(self)
 var parent: Node=board.get_parent()
 var at: int=board.get_index()
 parent.remove_child(board);board.free()
 board=host._new_battle_view()
 board.projectile_inspected.disconnect(host._combat_projectile_details)
 board.set_script(RegionalLayouts[int(host.campaign.s.region)])
 board.name="Battle"
 board.minimum_battle_height=80.0
 board.custom_minimum_size=Vector2(0,80)
 board.size_flags_vertical=Control.SIZE_EXPAND_FILL
 board.character_reference_height=300.0
 parent.add_child(board);parent.move_child(board,at)
 board.enemy_inspected.connect(inspect_enemy)
 board.reinforcement_inspected.connect(inspect_reinforcement)
 board.projectile_inspected.connect(inspect_projectile)
 slot_count=maxi(9,model.capacity())
 for i in range(9,slot_count):
  var slot: Node=node("Round8").duplicate()
  rename_slot(slot,i)
  node("Round8").get_parent().add_child(slot)
 combo_label=Label.new();combo_label.name="ComboLine";combo_label.mouse_filter=Control.MOUSE_FILTER_IGNORE
 combo_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL;combo_label.clip_text=true
 combo_label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;combo_label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 combo_label.add_theme_font_size_override("font_size",16);combo_label.add_theme_color_override("font_color",Color("f3cf73"))
 combo_label.visible=false
 node("MagazineTitle").get_parent().add_child(combo_label)
 hud=Hud.new(self);hud.bind()
 node("Fire").pressed.connect(fire)
 node("Reload").pressed.connect(reload_magazine)
 node("Cool").pressed.connect(cool)
 node("EjectToggle").pressed.connect(toggle_ejection)
 node("EjectApply").pressed.connect(apply_ejection)
 for i in range(slot_count):node("Select%d"%i).pressed.connect(select_ejection.bind(i))
 node("Help").pressed.connect(show_help)
 node("BudgetLess").pressed.connect(func():select_budget(current_budget()-1))
 node("BudgetMore").pressed.connect(func():select_budget(current_budget()+1))
 node("Reset").pressed.connect(show_help)
 node("Pressure").pressed.connect(show_route)
 node("Other").pressed.connect(func():host._to_menu.call_deferred())
 node("Bag").pressed.connect(show_deck)
 node("Parts").pressed.connect(show_parts)
 node("CloseDetail").pressed.connect(close_detail)
 node("DetailUp").pressed.connect(func():node("DetailScroll").scroll_vertical-=160)
 node("DetailDown").pressed.connect(func():node("DetailScroll").scroll_vertical+=160)
 board.set_route_background(int(host.campaign.s.region),int(host.campaign.s.floor),int(host.campaign.region_info().floors))
 save_ok=host.save_error.is_empty()
 refresh()

func rename_slot(item: Node,index: int)->void:
 if str(item.name).ends_with("8"):item.name=str(item.name).trim_suffix("8")+str(index)
 for child in item.get_children():rename_slot(child,index)

func persist()->void:
 # Campaign.save normalizes out-of-combat storage. Keep the resolved combat
 # snapshot alive until shots/cooling finish, while saving the terminal result now.
 var resolved: Dictionary=model.s.duplicate(true)
 host._persist()
 model.s=resolved
 save_ok=host.save_error.is_empty()

func lock_actions()->void:
 host.busy=true
 super.lock_actions()

func refresh()->void:
 if not busy:host.busy=false
 if host.campaign.s.phase!="combat":
  host.redraw.call_deferred()
  return
 super.refresh()
 node("Title").text="%s · %s"%[host.campaign.region_info().name,host.campaign.node().name]
 node("StatusNote").text="전체 등반 · 자동 저장" if save_ok else "저장 실패 · 현재 플레이 유지"
 node("Pressure").text="등반 현황"
 node("Other").text="시작 화면"
 node("Reset").hide()
 # Deck-building revision: name what the auto-loaded magazine forms (boost pairs,
 # magazine-composition parts) beside the magazine count. Hidden while ejecting.
 var combo_line: String=""
 if Model.MagazineBuild.enabled(model.s) and model.s.phase=="ready" and not eject_mode:combo_line=Model.MagazineBuild.combo_line(model.s)
 if combo_label!=null:
  combo_label.text=combo_line
  combo_label.visible=not combo_line.is_empty()
  combo_label.tooltip_text=combo_line
 node("BudgetRow").visible=Trial.range_enabled(model.s)
 node("BudgetValue").text="이번 사격 최대 %d발"%current_budget()
 node("BudgetLess").disabled=current_budget()<=1
 node("BudgetMore").disabled=current_budget()>=maximum_budget()
 hud.cycle_focus((["MenuClose","BudgetLess","BudgetMore"] if Trial.range_enabled(model.s) else ["MenuClose"])+["Help","Pressure","Other","EffectsVolume","CombatMotion"])

func show_help()->void:
 var controls: String=""
 if Trial.range_enabled(model.s):controls="\n첫 탄부터 오른쪽으로 끌기 → 발수 선택 → 사격 버튼으로 확정\n짧게 누르기 → 빼내기 선택 · 메뉴 −/+로도 발수 조절\n탄창 밖에 놓기·Esc·포커스 이탈은 범위 선택 취소\n짧게 쏴도 적 1행동 · 리액터 강행/스파이크 연속 조건 유지\n탄창 교체는 열·연속 발열 유지(냉각 약실 +4는 적용)\n냉각은 적 1행동·잔탄 보존·열 0·연속 발열 초기화"
 show_detail("탄창과 선택",weapon_hint()+controls+"\n사격 · 적 1행동 / 냉각 · 적 1행동\n탄창 교체 · 적 %d행동 / 미사용 탄은 예비 뒤로\n과열되면 강제 냉각 중 적이 추가로 접근합니다.\n빼내기 · 탄창당 2발까지, 중간 탄도 선택 가능\n빼낸 탄은 이번 전투에서 소모되고 빈자리는 채우지 않습니다.\n다음 전투에 보유 탄 전체가 복구됩니다.\n전투·보상·정비마다 자동 저장합니다."%model.reload_cost())

func show_route()->void:
 show_detail("등반 현황","%s · %d / %d층\n현재 · %s\n승리 %d회 · %d Cr\n\n전투가 끝나면 보상을 고르고 지도에서 다음 목적지를 선택합니다. 관문에서는 개조와 재정비를 마친 뒤 다음 구역으로 출발합니다."%[host.campaign.region_info().name,host.campaign.s.floor,host.campaign.region_info().floors,host.campaign.node().name,host.campaign.s.clears,host.campaign.s.credits])

func show_deck()->void:
 var counts: Dictionary={}
 for id in model.s.deck:counts[id]=int(counts.get(id,0))+1
 var lines: PackedStringArray=["탄창 %d발 · 예비 %d발 · 사용 %d발"%[model.s.magazine.size(),model.s.draw.size()+model.s.hand.size(),model.s.discard.size()]]
 for id in counts:lines.append("%s ×%d"%[Content.AMMO[id].name,counts[id]])
 lines.append("다음 전투에 사용·빼낸 탄 전체 복구 · 획득한 덱과 코어 성장 유지")
 show_detail("보유 탄약","\n".join(lines))

func show_parts()->void:
 var lines: PackedStringArray=[weapon_hint()]
 for id in Content.equipped_parts(model.s):
  lines.append(Content.PARTS[id].name+" · "+Model.Engines.value(model.s,id))
  lines.append(Model.Engines.progress(model.s,id))
  lines.append(Content.part_spec(id,model.s).text)
 if Content.equipped_parts(model.s).is_empty():lines.append("첫 승리 뒤 성장 코어를 선택합니다.")
 show_detail("총기와 빌드","\n".join(lines))

func inspect_enemy(index: int)->void:
 if busy or overlay_open or index<0 or index>=model.s.enemies.size():return
 var e: Dictionary=model.s.enemies[index]
 var lines: PackedStringArray=["HP %d / %d"%[e.hp,e.max_hp]]
 var threat: Dictionary=preload("res://redesign/enemy_threat.gd").analyze(model.s).get(index,{})
 lines.append(str(threat.get("detail","")))
 for entry in preload("res://redesign/enemy_status_icons.gd").entries(e):lines.append(entry.text)
 lines.append(Content.enemy_rule(e,model.s))
 show_detail(e.name,"\n".join(lines))

func inspect_reinforcement(index: int)->void:
 if busy or overlay_open or index<0 or index>=model.s.reinforcements.size():return
 var e: Dictionary=model.s.reinforcements[index]
 show_detail("증원 · "+e.name,"HP %d · 장갑 %d\n전열이 2기 이하가 되면 빈 자리에 투입됩니다.\n%s"%[e.hp,e.def,Content.enemy_rule(e,model.s)])

func inspect_projectile(index: int)->void:
 if busy or overlay_open:return
 var p: Dictionary=model.target_entity(index)
 if p.is_empty():return
 show_detail("압력탄","HP %d · 도달 %d행동\n가장 가까워지면 다음 공격탄으로 자동 요격합니다.\n본체를 처치해도 이미 발사된 탄은 남습니다. 도달하면 패배합니다."%[p.hp,preload("res://redesign/ranged.gd").arrival(p)])
