extends RefCounted
## Read-only presentation of the existing fixed journey and real reward commands.
const Content=preload("res://redesign/content.gd")
const Journey=preload("res://redesign/magazine_journey.gd")
const Model=preload("res://redesign/model.gd")
const ROOMS=[101,201,401,501,602,702,802]
const NOTES={101:"앞으로 다가오는 순찰을 상대합니다.",201:"흩어진 적을 정리하고 새 탄의 역할을 확인합니다.",401:"방패 진지를 돌파합니다. 장갑과 접근 예고를 확인하세요.",501:"기본탄 한 발을 특수탄으로 바꾸는 무료 정비입니다.",602:"여러 적을 상대하며 성장한 코어와 탄의 조합을 활용합니다.",702:"관문 전에 기본탄 한 발을 개조할 수 있습니다.",802:"문판이 열리는 때와 압력탄을 확인하세요. 적의 접근도 계속됩니다."}
var ui: Control
var inspected_room: int=-1
var observed_room: int=-1
var observed_phase: String=""
var projected: Dictionary={}
var forecast_key: String=""
var forecast_text: String=""
func _init(surface: Control)->void:ui=surface
func n(id: String)->Node:return ui.node(id)
func bind()->void:
 for i in range(ROOMS.size()):n("RouteStop%d"%i).pressed.connect(inspect_room.bind(ROOMS[i]))
func next_room()->int:
 var visited: int=ui.journey.campaign.s.visited.size()
 while visited<Journey.ROUTE.size():
  var id: int=Journey.ROUTE[visited]
  if id!=302:return id
  visited+=1
 return -1
func inspect_room(id: int)->void:
 if ui.busy or not n("RouteOverview").visible:return
 inspected_room=id;render_route()
func sync_focus_order()->void:
 if not n("JourneyPanel").visible:return
 var order: Array=[]
 for i in range(ROOMS.size()):
  if n("RouteStop%d"%i).is_visible_in_tree():order.append("RouteStop%d"%i)
 for i in range(3):
  if n("RewardPick%d"%i).is_visible_in_tree():order.append("RewardPick%d"%i)
 for id in ["JourneyGun","JourneyCancel","JourneyConfirm"]:
  if n(id).is_visible_in_tree() and not n(id).disabled:order.append(id)
 if not order.is_empty():ui.hud.cycle_focus(order)
func room(id: int)->Dictionary:
 for item in ui.journey.campaign.current_nodes():
  if int(item.id)==id:return item
 return {}
func render()->void:
 if not n("JourneyPanel").visible:return
 var phase: String=ui.journey.phase()
 var selecting: bool=ui.panel_mode=="flow" and phase in ["reward","supply"]
 var routing: bool=ui.panel_mode=="route" or (ui.panel_mode=="flow" and phase=="map")
 n("RewardWorkspace").visible=selecting
 n("RouteOverview").visible=routing
 n("JourneyConfirm").visible=ui.panel_mode!="route"
 n("JourneySummary").visible=not routing
 if ui.panel_mode=="route":
  n("JourneyTitle").text="첫 관문까지의 경로"
  n("JourneyBody").text="현재 위치와 앞으로의 전투·정비를 확인합니다."
  n("JourneyCancel").visible=true;n("JourneyCancel").text="전투로 돌아가기" if phase=="combat" else "돌아가기"
 if routing:
  render_route()
  if phase=="map" and ui.panel_mode=="flow":
   n("JourneyTitle").text="다음 구간 준비"
   n("JourneyBody").text=str(ui.journey.campaign.s.message)
   n("JourneyConfirm").text="%s로 이동"%str(room(next_room()).get("name","다음 구간"))
 if selecting:render_reward()
 else:forecast_key="";projected={}
func render_route()->void:
 var current: int=ui.journey.campaign.s.node
 var next: int=next_room()
 var context: String=ui.journey.phase()+"/"+ui.panel_mode
 var changed: bool=observed_room!=current or observed_phase!=context or inspected_room<0
 if changed:
  observed_room=current
  observed_phase=context
  inspected_room=next if ui.journey.phase()=="map" and next>=0 else current
 var visited: Array=ui.journey.campaign.s.visited.map(func(value):return int(value))
 for i in range(ROOMS.size()):
  var id: int=ROOMS[i]
  var info:=room(id)
  var status: String="지나옴" if visited.has(id) else "예정"
  if id==current:status="현재"
  elif id==next:status="다음"
  n("RouteName%d"%i).text=str(info.get("name","구간"))
  n("RouteType%d"%i).text="정비" if id in [501,702] else "관문" if id==802 else "%d전"%(Journey.FIGHTS.find(id)+1)
  n("RouteState%d"%i).text=status
  n("RouteState%d"%i).modulate=Color("d9a470") if status=="다음" else Color("c1d6d1") if status=="현재" else Color("94a6aa")
  n("RouteStop%d"%i).set_pressed_no_signal(id==inspected_room)
  n("RouteStop%d"%i).accessibility_name="%s · %s"%[info.get("name","구간"),status]
 if changed and ROOMS.has(inspected_room):
  n("RouteScroll").call_deferred("ensure_control_visible",n("RouteStop%d"%ROOMS.find(inspected_room)))
 var selected:=room(inspected_room)
 n("RoutePlace").text=str(selected.get("name","관문"))
 n("RouteDescription").text=NOTES.get(inspected_room,"")
 n("RouteHint").text="다음 이동 구간" if inspected_room==next else "현재 위치" if inspected_room==current else "지나온 구간" if visited.has(inspected_room) else "앞으로의 구간"
 var state: Dictionary=ui.model.s
 var lines: PackedStringArray=["%s · 보유 탄 %d발"%[Content.GUNS[state.gun].name,state.deck.size()],"탄창 %d칸 · 발열 한계 %d"%[ui.model.capacity(),Content.heat_limit(state)]]
 for id in Content.equipped_parts(state):lines.append(Content.PARTS[id].name+" · "+Model.Engines.value(state,id))
 if Content.equipped_parts(state).is_empty():lines.append("첫 승리 뒤 성장 코어 획득")
 lines.append("다음 전투에 사용·빼낸 탄 전체 복구")
 n("RouteBuild").text="\n".join(lines).replace("−","-")
func render_reward()->void:
 var id: String=ui.selected_reward
 for i in range(ui.reward_ids.size()):
  var chosen: bool=str(ui.reward_ids[i])==id
  if chosen:n("RewardTag%d"%i).text="선택 · "+n("RewardTag%d"%i).text
  n("RewardPick%d"%i).accessibility_name=n("RewardName%d"%i).text+" · "+n("RewardTag%d"%i).text
 n("RewardDetailIcon").visible=not id.is_empty()
 if id.is_empty():
  projected={};forecast_key=""
  n("RewardDetailName").text="어떤 변화를 가져갈까요?"
  n("RewardDelta").text="왼쪽 후보를 고르면 적용 전후를 확인합니다."
  n("RewardDescription").text="선택만으로 보상이 사용되지는 않습니다.\n아래 버튼으로 확정합니다."
  return
 var part: bool=Content.PARTS.has(id)
 var spec: Dictionary=Content.part_spec(id,ui.model.s) if part else Content.AMMO[id]
 n("RewardDetailIcon").is_part=part;n("RewardDetailIcon").item_id=id
 n("RewardDetailName").text=spec.name
 n("RewardDescription").text=str(ui.CORE_SUMMARY.get(id,spec.text)).replace("−","-")
 # This clone runs the actual command, so full bags and workshop replacements
 # have the same result as confirmation. It never saves or touches the live RNG.
 var key: String="%s/%s/%s/%s/%s"%[ui.journey.campaign.s.node,ui.journey.phase(),id,ui.journey.acquisitions.size(),ui.model.s.deck.hash()]
 if forecast_key!=key:
  forecast_key=key;projected={};forecast_text="이 후보를 적용할 수 없습니다."
  var copy=Journey.new()
  var value: Dictionary={"format":"lob_magazine_journey","version":Journey.VERSION,"current":ui.journey.data(),"entry":ui.journey.entry,"results":ui.journey.results,"acquisitions":ui.journey.acquisitions}
  if copy.restore_state(value):
   var replacing: String=copy.replacement(id)
   if copy.choose(id):
    projected=copy.data()
    var before: Dictionary=ui.model.s
    var after: Dictionary=copy.campaign.model.s
    var lines: PackedStringArray=[]
    if part:
     lines.append("코어 장착 · "+Model.Engines.value(after,id))
     lines.append("탄창 %d ▶ %d칸  /  발열 한계 %d ▶ %d"%[ui.model.capacity(),copy.campaign.model.capacity(),Content.heat_limit(before),Content.heat_limit(after)])
    else:
     lines.append("%s 1발 ▶ %s 1발"%[Content.AMMO[replacing].name,spec.name] if not replacing.is_empty() else spec.name+" 1발 추가")
     if not replacing.is_empty():lines.append("빠질 탄 · 기본 피해 %d / 열 %s"%[Content.AMMO[replacing].dmg,Content.heat_label(replacing,before)])
     lines.append("보유 탄 %d ▶ %d발"%[before.deck.size(),after.deck.size()])
     lines.append("다음 전투부터 덱에 섞입니다")
    forecast_text="\n".join(lines)
 n("RewardDelta").text=forecast_text.replace("−","-")
