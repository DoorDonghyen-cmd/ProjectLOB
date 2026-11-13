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
 board.proximity_warning_enabled=true
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
 var shield_test := str(model.s.enemies[0].get("shield_trial", "")) if not model.s.enemies.is_empty() else ""
 if not shield_test.is_empty(): node("Title").text = "수석 시종 · A 철갑 약점" if shield_test == Model.Noble.PIERCE_WEAK else "수석 시종 · B 철갑 전용"
 node("StatusNote").text="자동 저장됨" if save_ok else "저장 실패 · 지금 플레이는 계속됩니다"
 node("Pressure").text="등반 현황"
 node("Other").text="타이틀로 나가기"
 node("Reset").hide()
 # Deck-building revision: name what the auto-loaded magazine forms (boost pairs,
 # magazine-composition parts) beside the magazine count. Hidden while ejecting.
 var combo_line: String=""
 if Model.MagazineBuild.enabled(model.s) and model.s.phase=="ready" and not eject_mode:combo_line=Model.MagazineBuild.combo_line(model.s)
 if not eject_mode and not last_prediction.get("shots", []).is_empty():
  var shot: Dictionary = last_prediction.shots[0]
  if shot.has("wreckage_hit") or float(shot.get("wreckage_probability", 0.0)) > 0.0: combo_line = Forecast.note(last_prediction, 0)
  elif shot.has("shield_rule") and int(shot.get("blocked_hits", 0)) > 0: combo_line = Forecast.note(last_prediction, 0)
 # First fights (launch pass 2026-11-12): when nothing else uses the line, one sentence on the
 # next decision. 설정 → 상황 도움말 turns it off; it stops by itself after three wins.
 var coaching:=false
 if combo_line.is_empty() and coach_enabled():
  combo_line=coach_line()
  coaching=not combo_line.is_empty()
 if combo_label!=null:
  combo_label.text=combo_line
  combo_label.visible=not combo_line.is_empty()
  combo_label.tooltip_text=combo_line
  combo_label.add_theme_color_override("font_color",Color("bff3f1") if coaching else Color("f3cf73"))
 node("BudgetRow").visible=Trial.range_enabled(model.s)
 node("BudgetValue").text="한 번에 쏠 발수 · %d발"%current_budget()
 node("BudgetLess").disabled=current_budget()<=1
 node("BudgetMore").disabled=current_budget()>=maximum_budget()
 hud.cycle_focus((["MenuClose","BudgetLess","BudgetMore"] if Trial.range_enabled(model.s) else ["MenuClose"])+["Help","Pressure","Other","EffectsVolume","CombatMotion"])

## The gun's one-line rule in the build window and help. 리와인더 names its 되감기 사격 in runs
## that have it (launch_balance.gd).
func weapon_hint()->String:
 if Model.WeaponRoles.kind(model.s)=="rewinder" and Model.LaunchBalance.enabled(model.s):
  return "탄창마다 첫 냉각 때 남은 탄 순서를 뒤집고, 되감은 직후 첫 공격탄 ×%d"%Model.LaunchBalance.REWIND_FACTOR
 return super.weapon_hint()

func coach_enabled()->bool:
 var prefs: Dictionary=host.preferences.data
 if not bool(prefs.get("hints",true)) or bool(prefs.get("coached",false)):return false
 if int(host.campaign.profile.get("ascension",0))>0 or int(host.campaign.s.clears)>=3:
  # A player who has won three fights (or a whole climb) no longer needs the line.
  host.preferences.set_value("coached",true)
  return false
 return true

func coach_line()->String:
 if model.s.phase!="ready" or eject_mode or busy:return ""
 if model.s.magazine.is_empty():return "탄창이 비었습니다 · 탄창 교체를 누르세요"
 var heat: Dictionary=last_prediction.get("heat",{})
 if float(heat.get("forced_probability",0))>0:return "이대로 쏘면 과열 · 발수를 줄이거나 먼저 냉각하세요"
 if int(model.s.heat)*2>=Content.heat_limit(model.s):return "열이 절반을 넘었습니다 · 냉각은 적 1행동"
 if Trial.range_enabled(model.s):return "첫 탄에서 오른쪽으로 끌어 발수를 고르고 사격"
 return "사격을 누르면 탄창 앞쪽 탄부터 나갑니다"

## Launch pass (2026-11-12): 위로/아래로 only when the text is longer than the window.
func show_detail(title: String,body: String)->void:
 super.show_detail(title,body)
 node("DetailUp").hide();node("DetailDown").hide()
 sync_detail_scroll.call_deferred()

func sync_detail_scroll()->void:
 await get_tree().process_frame
 await get_tree().process_frame
 if not is_inside_tree() or not node("Detail").visible:return
 var bar: VScrollBar=node("DetailScroll").get_v_scroll_bar()
 var needed: bool=bar.max_value>bar.page+1.0
 node("DetailUp").visible=needed;node("DetailDown").visible=needed

func show_help()->void:
 # Launch pass (2026-11-12): what each action costs, then the rules that change a decision.
 var lines: PackedStringArray=[weapon_hint(),""]
 if Trial.range_enabled(model.s):lines.append("발수 선택 · 첫 탄에서 오른쪽으로 끌고 사격")
 lines.append("빼내기 · 탄을 눌러 고르고 빼내기(탄창당 2발, 적 행동 없음)")
 lines.append("")
 lines.append("사격 · 적 1행동")
 lines.append("냉각 · 적 1행동 · 열 0 · 남은 탄 유지")
 lines.append("탄창 교체 · 적 %d행동 · 남은 탄은 예비 뒤로 · 열 그대로"%model.reload_cost())
 lines.append("과열 · 강제 냉각 적 %d행동"%model.forced_cooling_cost())
 if Content.Sustained.enabled(model.s):lines.append("연속 사격 · 공격탄을 이어 쏘면 3번째부터 열 +1, 5번째부터 +2. 냉각하면 처음부터")
 lines.append("")
 if Model.MixCombo.enabled(model.s):lines.append("교차 사격 · 직전 공격탄과 다른 종류를 쏘면 타격당 +1, 계속 바꾸면 최대 +3")
 if Model.Salvage.enabled(model.s):lines.append("회수 · 마지막으로 쓰러뜨린 적이 자기 약점 탄을 보상에 남깁니다")
 lines.append("탄약 · 쓴 탄과 빼낸 탄은 다음 전투에 모두 돌아옵니다")
 show_detail("전투 도움말","\n".join(lines))

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
 var tags:=Model.TagBuild.enabled(model.s)
 if tags:
  lines.append("태그 시험판 · 장전된 탄창 태그 %d종"%Model.TagBuild.magazine_tags(model.s))
  # Legend for the card chips (tag_chips.gd).
  var legend: PackedStringArray=[]
  for tag in Model.TagBuild.SHORT:legend.append("%s %s"%[Model.TagBuild.SHORT[tag],tag])
  lines.append("탄 카드 위 글자 · "+" / ".join(legend))
  var read: Array=Model.TagBuild.read_tags(model.s,Content.active_parts(model.s))
  lines.append("채워진 칸 · 장착 파츠가 읽는 태그"+(" ("+"·".join(read)+")" if not read.is_empty() else " (없음)"))
 # Growth structure v2: the gun's built-in drive, its current value and what grows it.
 var drive:=str(Content.innate_engine(model.s))
 if not drive.is_empty():
  lines.append("[내장 구동] %s · %s"%[str(Content.PARTS[drive].name),Model.Engines.value(model.s,drive)])
  var drive_progress:=Model.Engines.progress(model.s,drive)
  if not drive_progress.is_empty():lines.append(drive_progress)
 for id in Content.equipped_parts(model.s):
  var value:=Model.Engines.value(model.s,id)
  lines.append("[%s] "%preload("res://redesign/part_slots.gd").name_of(id)+str(Content.PARTS[id].name)+("" if value.is_empty() else " · "+value))
  var progress:=Model.Engines.progress(model.s,id)
  if not progress.is_empty():lines.append(progress)
  # Tag growth parts: kills recorded this climb.
  if tags and Model.TagBuild.PARTS.has(id) and str(Model.TagBuild.PARTS[id].kind)=="growth":
   var spec: Dictionary=Model.TagBuild.PARTS[id]
   lines.append("기록 %d처치 · %s 탄 +%d"%[Model.TagBuild.growth(model.s,id),spec.tag,mini(int(spec.limit),Model.TagBuild.growth(model.s,id)/int(spec.step))])
  lines.append(Content.part_spec(id,model.s).text)
 if Content.equipped_parts(model.s).is_empty():lines.append("장착 파츠 없음 · 보상과 상점에서 파츠를 얻습니다." if Model.GrowthV2.enabled(model.s) else "첫 승리 뒤 성장 코어를 선택합니다.")
 show_detail("총기와 빌드","\n".join(lines))

func inspect_enemy(index: int)->void:
 if busy or overlay_open or index<0 or index>=model.s.enemies.size():return
 var e: Dictionary=model.s.enemies[index]
 var lines: PackedStringArray=["HP %d / %d · 거리 %dm"%[e.hp,e.max_hp,int(e.get("distance",0))]]
 var threat: Dictionary=preload("res://redesign/enemy_threat.gd").analyze(model.s).get(index,{})
 if not str(threat.get("detail","")).is_empty():lines.append(str(threat.get("detail","")))
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
