extends VBoxContainer
## Read-only inventory: deck ownership is distinct from the current combat zones.
const Content = preload("res://redesign/content.gd")
const Card = preload("res://redesign/ammo_card_view.gd")
const Readability = preload("res://redesign/readability.gd")
const TABS := {"all": "전체 보유", "hand": "손패", "loaded": "장전", "draw": "뽑을 탄", "discard": "사용한 탄"}
const HINTS := {
	"all": "이번 등반에서 보유한 탄환 · 같은 탄은 수량으로 표시합니다.",
	"hand": "지금 장전에 사용할 수 있는 탄환입니다.",
	"loaded": "왼쪽부터 발사 순서 · 장전한 탄은 손패 수에서 제외합니다.",
	"draw": "재장전할 때 이 더미부터 뽑습니다. 목록은 발사·추첨 순서가 아닙니다.",
	"discard": "발사·교환하거나 재장전 때 남긴 탄 · 뽑을 더미가 비면 다시 섞습니다.",
}
var ui: Control
var state: Dictionary
var inventory: Dictionary
var active_tab := "all"
var tabs: Dictionary = {}
var content: VBoxContainer
var details: Label
var grid: GridContainer
var cards: Dictionary = {}

static func snapshot(source: Dictionary) -> Dictionary:
	var hand: Array = source.get("hand", []).duplicate()
	var loaded: Array = source.get("plan", []).duplicate() if source.get("phase", "") == "plan" else source.get("magazine", []).duplicate()
	if source.get("phase", "") == "plan":
		for id in loaded:
			if not Content.is_temporary(str(id)): hand.erase(id)
	return {"all": source.get("deck", []).duplicate(), "hand": hand, "loaded": loaded, "draw": source.get("draw", []).duplicate(), "discard": source.get("discard", []).duplicate()}

func setup(screen: Control) -> void:
	ui=screen
	state=ui.model.s.duplicate(true)
	inventory=snapshot(state)
	grid=get_node("BagScroll/Content/BagCards")
	content=get_node("BagScroll/Content")
	details=get_node("Inspection/BagCardDetails")
	for key in TABS:
		var button: Button=get_node("Tabs/bag_tab_"+key)
		button.text="%s  %d"%[TABS[key],inventory[key].size()]
		button.toggle_mode=true
		button.add_theme_font_size_override("font_size",18)
		button.pressed.connect(select_tab.bind(key))
		tabs[key]=button
	get_node("Inspection/bag_details").pressed.connect(_details)
	get_viewport().size_changed.connect(_fit)
	_fit()
	select_tab("all")

func _fit() -> void:
	if ui==null: return
	# The bag owns its scroll; tabs, selected detail and workspace close stay fixed.
	custom_minimum_size.y=maxf(390,ui.size.y-190)
	grid.columns=6 if ui.size.x>=1200 else 4

func select_tab(key: String) -> void:
	active_tab=key
	for id in tabs:
		var button: Button=tabs[id]
		button.set_pressed_no_signal(id==key)
		preload("res://redesign/combat_treatment.gd").finish_button(button)
		if id==key:
			var selected: StyleBoxFlat=button.get_theme_stylebox("normal").duplicate()
			selected.bg_color=Color("354a46")
			selected.border_color=Color("b8c7ad")
			button.add_theme_stylebox_override("normal",selected)
			button.add_theme_stylebox_override("pressed",selected)
			button.add_theme_color_override("font_pressed_color",Color("cfdec5"))
	for child in grid.get_children(): grid.remove_child(child);child.queue_free()
	cards.clear()
	var ids: Array=inventory[key]
	get_node("Hint").text=HINTS[key]
	details.text="탄환을 누르면 효과를 확인합니다."
	get_node("Inspection/bag_details").disabled=true
	var next_row: HBoxContainer=get_node("NextDraw")
	for child in next_row.get_children(): next_row.remove_child(child);child.queue_free()
	next_row.visible=key=="draw" and not ids.is_empty()
	if next_row.visible:
		ui._label(next_row,"다음 추첨 · 순서 공개",17,ui.MUTED)
		for i in range(mini(2,ids.size())): ui._reserve_chip(next_row,str(ids[i]),str(i+1),1,true,"bag_next_%d"%i,false)
	var status: Label=get_node("StateHint")
	status.text=""
	if not state.get("field_compression",{}).is_empty(): status.text="임시 압축 · 원본 2장은 장전한 압축탄에 포함되며 사용 후 돌아옵니다."
	if not Content.uses_ammo_cards(state): status.text+=" 이전 등반 · 기본탄 %d발 별도 보급"%int(state.get("supply",0))
	status.visible=not status.text.is_empty()
	var empty: Label=get_node("BagScroll/Content/bag_empty")
	empty.visible=ids.is_empty()
	empty.text="뽑을 더미가 비었습니다. 다음 추첨은 사용한 탄을 섞어서 이어갑니다." if key=="draw" else "이곳에는 아직 탄환이 없습니다."
	grid.visible=not ids.is_empty()
	var order: Array=[]
	if key=="loaded": order=ids.duplicate()
	else:
		for id in Content.AMMO:
			if ids.has(id): order.append(id)
	for index in range(order.size()):
		var id: String=order[index]
		var token:="%s_%d"%[id,index]
		var button: Button=preload("res://redesign/ammo_offer.tscn").instantiate()
		button.name="bag_card_"+token
		button.custom_minimum_size=Vector2(180,164)
		button.pressed.connect(inspect_card.bind(id,token))
		button.tooltip_text=Readability.description(id,state)
		grid.add_child(button)
		var card: Control=button.get_node("CardInfo")
		card.showcase_ui=false
		card.offer_action=false
		card.setup(id,1 if key=="loaded" else ids.count(id),state,false,false,"발사 %d"%(index+1) if key=="loaded" else "")
		cards[token]=button
	get_node("BagScroll").scroll_vertical=0
	if not cards.is_empty():
		var first: String=cards.keys()[0]
		inspect_card(str(order[0]),first)
	ui._workspace_focus_chain.call_deferred()

var inspected_id := ""
func inspect_card(id: String, token: String) -> void:
	inspected_id=id
	for key in cards:
		var card: Control=cards[key].get_node("CardInfo")
		card.selected_visual=key==token
		card.queue_redraw()
	details.text=Content.AMMO[id].name+" · "+Readability.description(id,state)
	details.add_theme_color_override("font_color",ui.INK)
	get_node("Inspection/bag_details").disabled=false

func _details() -> void:
	if inspected_id.is_empty(): return
	var panel: VBoxContainer=ui._dialog(Content.AMMO[inspected_id].name,true)
	var face:=Card.new()
	face.custom_minimum_size=Vector2(230,180)
	face.setup(inspected_id,1,state)
	panel.add_child(face)
	ui._label(panel,Readability.description(inspected_id,state),20)
