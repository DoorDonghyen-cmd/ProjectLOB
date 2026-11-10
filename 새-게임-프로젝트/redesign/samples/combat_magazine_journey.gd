extends "res://redesign/samples/combat_weapon_magazine.gd"
const Journey = preload("res://redesign/magazine_journey.gd")
var journey = Journey.new()
var panel_mode := "flow"
var selected_reward := ""
var reward_ids: Array = []
const CORE_SUMMARY := {
 "volley_drive":"직접 타격마다 피해 +1\n남은 타격이 다음 적에게 연결\n다회 타격탄의 열 +1\n타격을 쌓고 승리하면 성장",
 "thermal_drive":"이미 고열일 때 직접 피해 ×1.50\n고열 공격으로 승리하면 배율 성장\n열 한계에서 전열에 충격파\n발열 한계 −2",
 "siege_drive":"한 번 타격하는 공격탄 피해 ×2\n처치의 초과 피해를 다음 적에게\n강한 한 발로 승리하면 배율 성장\n탄창 −1칸"
}

func _ready() -> void:
 board.character_reference_height=300.0
 node("Fire").pressed.connect(fire); node("Reload").pressed.connect(reload_magazine); node("Cool").pressed.connect(cool)
 node("EjectToggle").pressed.connect(toggle_ejection); node("EjectApply").pressed.connect(apply_ejection)
 for i in range(9): node("Select%d"%i).pressed.connect(select_ejection.bind(i))
 node("Reset").pressed.connect(func(): open_panel("retry"))
 node("Other").pressed.connect(func(): open_panel("new"))
 node("Pressure").pressed.connect(show_route)
 node("Help").pressed.connect(func(): show_detail("탄창과 선택",weapon_hint()+"\n사격 · 적 1행동 / 냉각 · 적 1행동\n교체 · 적 %d행동 / 미사용 탄은 예비 뒤로\n과열되면 강제 냉각 중 적이 추가로 접근합니다.\n빼내기 · 탄창당2발까지, 중간 탄도 선택 가능\n빼낸 탄은 이번 전투에서 소모되고 빈자리는 채우지 않습니다.\n다음 전투에 보유 탄 전체가 복구됩니다.\n같은 전투 재도전은 진입 당시 탄 순서와 덱을 복구합니다."%model.reload_cost()))
 node("Bag").pressed.connect(show_deck); node("Parts").pressed.connect(show_parts)
 node("CloseDetail").pressed.connect(close_detail)
 node("DetailUp").pressed.connect(func(): node("DetailScroll").scroll_vertical-=160)
 node("DetailDown").pressed.connect(func(): node("DetailScroll").scroll_vertical+=160)
 for i in range(3): node("RewardPick%d"%i).pressed.connect(select_reward.bind(i))
 node("JourneyConfirm").pressed.connect(confirm_panel)
 node("JourneyCancel").pressed.connect(cancel_panel)
 for id in GUNS: node("JourneyGun").add_item(Content.GUNS[id].name)
 if resume_saved and journey.restore(): resumed=true; receipt="이전 연속 플레이를 이어갑니다"
 else:
  if not journey.start("single"): push_error("Journey start failed");return
  receipt="첫 전투 · 보유 탄20발로 출발합니다"
 model=journey.campaign.model
 gun_index=GUNS.find(model.s.gun)
 node("JourneyGun").select(gun_index)
 set_backdrop(); persist();refresh()

func set_backdrop() -> void:
 board.set_route_background(0,int(journey.campaign.s.floor),8)

func persist() -> void:
 journey.sync()
 save_ok=journey.save()==OK

func mount(_boss: bool) -> void:
 if not journey.retry(): return
 model=journey.campaign.model
 eject_mode=false;eject_selected.clear();eject_preview={}
 selected_reward="";panel_mode="flow"
 receipt="진입 당시 덱·탄 순서로 재도전합니다"
 close_detail();set_backdrop();persist();refresh()

func refresh() -> void:
 super.refresh()
 var phase:=journey.phase()
 node("Title").text="%d / 5  ·  %s"%[journey.fight_number(),journey.campaign.node().name]
 node("PreviewLabel").text="보상으로 만드는 덱"
 node("Pressure").text="여정"
 node("Other").text="새 출발"
 node("Reset").text="재도전"
 node("Reset").disabled=phase not in ["combat","lost"] or eject_mode
 node("StatusNote").text="연속 플레이 · 자동 저장" if save_ok else "저장 실패 · 현재 플레이 유지"
 node("Bag").text="덱 %d발"%model.s.deck.size()
 if phase!="combat":
  node("IntentHint").text="얻은 탄과 코어가 다음 전투까지 이어집니다"
  node("Prediction").text="보상을 선택하고 다음 구간으로"
 refresh_panel()

func open_panel(mode: String) -> void:
 if busy or eject_mode or overlay_open: return
 panel_mode=mode;selected_reward="";refresh_panel()

func refresh_panel() -> void:
 var phase:=journey.phase()
 var show_flow:=phase!="combat"
 var visible_panel:=show_flow or panel_mode!="flow"
 node("JourneyPanel").visible=visible_panel
 if not visible_panel:
  overlay_open=node("Detail").visible
  return
 overlay_open=true
 node("JourneyGun").visible=panel_mode=="new"
 node("RewardRow").visible=panel_mode=="flow" and phase in ["reward","supply"]
 node("JourneyCancel").visible=true
 node("JourneyConfirm").disabled=false
 node("JourneySummary").text="보유 %d발 · 코어 %d개 · %d / 5전 승리"%[model.s.deck.size(),journey.campaign.s.equipped_parts.size(),journey.campaign.s.clears]
 for core_id in model.s.get("engine",{}).get("gains",[]):
  node("JourneySummary").text+="\n코어 성장 · "+Model.Engines.gain_summary(model.s,core_id)
 node("JourneyEyebrow").text="첫 관문까지  /  탄창 여정"
 node("JourneyCancel").text="돌아가기"
 if panel_mode=="new":
  node("JourneyTitle").text="새 총기로 처음부터"
  node("JourneyBody").text="총기를 고르고 출발하세요. 현재 연속 플레이 기록은 새 여정으로 바뀝니다."
  node("JourneyConfirm").text="선택한 총기로 출발"
  return
 if panel_mode=="retry":
  node("JourneyTitle").text="이 전투를 다시 시작할까요?"
  node("JourneyBody").text="전투 진입 당시 덱·탄 순서·코어 성장으로 돌아갑니다.\n이전에 얻은 보상은 유지됩니다. 이번 전투의 행동만 되돌립니다."
  node("JourneyConfirm").text="같은 조건으로 재도전"
  return
 node("JourneyCancel").visible=false
 if phase in ["reward","supply"]:
  var core: bool=journey.campaign.engine_reward()
  node("JourneyTitle").text="코어로 전투 방식을 고르세요" if core else "기본탄 한 발을 개조하세요" if phase=="supply" else "다음 전투에 가져갈 탄"
  node("JourneyBody").text="코어는 즉시 장착되고, 조건을 달성하며 승리하면 성장합니다." if core else "무료 정비 · 선택한 특수탄으로 기본탄 한 발을 교체합니다." if phase=="supply" else "하나를 골라 덱에 추가합니다. 다음 전투부터 다른 탄과 함께 섞입니다."
  reward_ids=journey.options()
  for i in range(3):
   var has_item:=i<reward_ids.size()
   node("RewardPick%d"%i).visible=has_item
   if not has_item:continue
   var id: String=reward_ids[i]
   var part: bool=Content.PARTS.has(id)
   var spec: Dictionary=Content.part_spec(id,model.s) if part else Content.AMMO[id]
   node("RewardName%d"%i).text=spec.name
   node("RewardIcon%d"%i).is_part=part
   node("RewardIcon%d"%i).item_id=id
   node("RewardTag%d"%i).text="성장 코어" if part else "지원탄" if int(spec.dmg)==0 else "공격탄 · 피해 %d"%int(spec.dmg)
   node("RewardText%d"%i).text=CORE_SUMMARY.get(id,spec.text)
   node("RewardPick%d"%i).set_pressed_no_signal(id==selected_reward)
  node("JourneyConfirm").disabled=selected_reward.is_empty()
  node("JourneyConfirm").text="선택을 확정하세요" if selected_reward.is_empty() else "코어 장착" if core else "기본탄 교체" if phase=="supply" else "덱에 추가"
  node("JourneyCancel").visible=not core and not journey.campaign.first_ammo_reward()
  node("JourneyCancel").text="현재 덱 유지"
 elif phase=="map":
  node("JourneyTitle").text="다음 구간으로"
  node("JourneyBody").text=str(journey.campaign.s.message)+"\n\n"+upcoming_text()+"\n다음 전투에 사용한 탄과 빼낸 탄이 모두 복구됩니다."
  node("JourneyConfirm").text="계속 이동"
 elif phase=="lost":
  node("JourneyTitle").text="이번 전투에서 멈췄습니다"
  node("JourneyBody").text=("탄약이 소진됐습니다." if model.s.get("loss_reason","")=="ammo" else "압력탄에 맞았습니다." if model.s.get("loss_reason","")=="projectile" else "적이 도달했습니다.")+"\n같은 덱과 탄 순서로 다른 선택을 시험할 수 있습니다."
  node("JourneyConfirm").text="같은 전투 재도전"
  node("JourneyCancel").visible=true;node("JourneyCancel").text="새 출발"
 elif phase=="complete":
  node("JourneyTitle").text="첫 관문을 돌파했습니다"
  var lines: PackedStringArray=[]
  for i in range(journey.results.size()):
   var row: Dictionary=journey.results[i]
   lines.append("%d전  ·  %d행동  /  사용 %d발  /  빼내기 %d발"%[i+1,row.turns,row.used,row.ejected])
  node("JourneyBody").text="\n".join(lines)+"\n\n얻은 덱으로 다섯 전투를 마쳤습니다."
  node("JourneyConfirm").text="다른 총기로 새 출발"

func upcoming_text() -> String:
 var index: int=journey.campaign.s.visited.size()
 if index>=Journey.ROUTE.size(): return "관문 도착"
 var next_id: int=Journey.ROUTE[index]
 if next_id==302: next_id=401
 for n in journey.campaign.current_nodes():
  if int(n.id)==next_id:return "다음 · "+str(n.name)
 return "다음 구간"

func select_reward(index: int) -> void:
 if panel_mode!="flow" or index>=reward_ids.size() or busy: return
 selected_reward=str(reward_ids[index]);refresh_panel()

func confirm_panel() -> void:
 if busy or not node("JourneyPanel").visible or node("JourneyConfirm").disabled: return
 if panel_mode=="new":
  if not journey.start(GUNS[node("JourneyGun").selected]):return
  receipt="새 여정 · 보유 탄20발로 출발합니다"
 elif panel_mode=="retry" or journey.phase()=="lost":
  mount(false);return
 elif journey.phase() in ["reward","supply"]:
  if not journey.choose(selected_reward):return
  receipt=journey.campaign.s.message
 elif journey.phase()=="map":
  if not journey.advance():return
  receipt="보유 덱에서 새 탄창 장전 · "+weapon_hint()
 elif journey.phase()=="complete":
  panel_mode="new";refresh_panel();return
 else:return
 model=journey.campaign.model;gun_index=GUNS.find(model.s.gun)
 eject_mode=false;eject_selected.clear();eject_preview={}
 selected_reward="";panel_mode="flow";node("Detail").hide()
 set_backdrop();persist();refresh()

func cancel_panel() -> void:
 if panel_mode!="flow": panel_mode="flow";refresh_panel();return
 if journey.phase()=="lost":panel_mode="new";refresh_panel();return
 if journey.skip():selected_reward="";persist();refresh()

func show_route() -> void:
 show_detail("첫 관문까지 다섯 전투","순찰 → 약탈단 → 교대 방패 → 무리전 → 관문 보스\n전투 사이 두 번의 무료 정비가 있습니다.\n보상으로 고른 탄과 코어 성장은 계속 유지됩니다.\n현재 덱 %d발 · %d전 승리\n전투와 보상 선택마다 자동 저장합니다."%[model.s.deck.size(),journey.campaign.s.clears])

func show_deck() -> void:
 var counts: Dictionary={}
 for id in model.s.deck:counts[id]=int(counts.get(id,0))+1
 var lines: PackedStringArray=["탄창 %d발 · 예비 %d발 · 사용 %d발"%[model.s.magazine.size(),model.s.draw.size()+model.s.hand.size(),model.s.discard.size()]]
 for id in counts:lines.append("%s ×%d"%[Content.AMMO[id].name,counts[id]])
 lines.append("다음 전투에 보유 탄 전체 복구 · 성장한 코어 유지")
 show_detail("이번 여정의 덱","\n".join(lines))

func show_parts() -> void:
 var lines: PackedStringArray=[weapon_hint()]
 for id in Content.equipped_parts(model.s):
  lines.append(Content.PARTS[id].name+" · "+Model.Engines.value(model.s,id))
  lines.append(Model.Engines.progress(model.s,id))
  lines.append(Content.part_spec(id,model.s).text)
 if Content.equipped_parts(model.s).is_empty():lines.append("첫 승리 뒤 성장 코어를 선택합니다.")
 show_detail("총기와 성장한 코어","\n".join(lines))
