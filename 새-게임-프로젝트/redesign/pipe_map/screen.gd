@tool
extends VBoxContainer
const Data = preload("res://redesign/campaign_content.gd")
const Place = preload("res://redesign/pipe_map/place.gd")
const MapMaterial = preload("res://redesign/pipe_map/material.gd")
var host
var director
var campaign
var memory_key := ""
var restoring := true
var selected_id := 0
var gate_id := 0
var enter_button: Button

func _feedback_transaction(event: Dictionary, effects) -> void:
	effects.pulse(node("RunStatusBar"),"complete")
	if event.before.credits!=event.after.credits: effects.pulse(node("RunCredits"),"complete")
	if event.before.deck!=event.after.deck or event.before.parts!=event.after.parts or event.before.equipped!=event.after.equipped:
		effects.pulse(node("city_deck"),"acquired")

func node(id: String): return find_child(id,true,false)

func _ready() -> void:
	resized.connect(_responsive)
	node("Spacer").resized.connect(_fit_state_key)
	_responsive()

func bind(screen, presenter) -> void:
	host=screen; director=presenter; campaign=host.campaign
	memory_key = "%d:%d:%d" % [campaign.get_instance_id(),campaign.s.region,campaign.s.node]
	node("RunLocation").text = str(campaign.region_info().name)
	node("RunCredits").text = "%d Cr" % int(campaign.s.credits)
	node("RunStatusBar").text = "탄약 %d/%d · 난도 %d" % [host.model.s.deck.size(),host.model.deck_limit(),campaign.s.difficulty]
	for entry in [["city_deck",director.deck],["city_archive",director.archive],["settings",host._settings],["menu",host._to_menu]]:
		node(entry[0]).pressed.connect(entry[1])
	node("Notice").text = host.save_error if not host.save_error.is_empty() else "개발자 연습 · 실제 진행 저장 보존" if host.debug_session else ""
	node("Notice").visible = not node("Notice").text.is_empty()
	var graph = node("CityMap")
	graph.feedback_scale = 0.0 if str(host.preferences.data.motion)=="instant" else host.preferences.motion_scale()
	graph.setup(campaign)
	gate_id=graph.gate_id
	node("Gate").name="map_node_"+str(gate_id)
	node("GateTitle").text="구역 관문" if int(campaign.s.region)<4 else "최종 관문"
	node("map_node_"+str(gate_id)).pressed.connect(_select.bind(gate_id))
	graph.selected.connect(_select)
	graph.inspected.connect(_select)
	node("city_map_details").pressed.connect(func():
		director.inspect_node(selected_id)
		MapMaterial.style_workspace(host.workspace_overlay))
	node("MapKey").pressed.connect(_open_key)
	enter_button=node("Enter")
	enter_button.pressed.connect(func():
		if campaign.choices().any(func(n):return int(n.id)==selected_id): director.action("enter",selected_id))
	var depth := 0.0
	for item in graph.nodes:
		if int(item.id)==int(campaign.s.node): depth=float(item.floor)/graph.floors
	node("RegionRail").configure(int(campaign.s.region),depth)
	node("MapScroll").get_v_scroll_bar().value_changed.connect(func(_value): _remember())
	var initial: int = int(campaign.choices()[0].id) if not campaign.choices().is_empty() else gate_id
	if director.map_memory.get("key","")==memory_key: initial=int(director.map_memory.get("selected",initial))
	_select(initial,false)
	_restore_view.call_deferred()

func _responsive() -> void:
	var compact := size.x<=900
	node("RegionRail").custom_minimum_size.x=104 if compact else 128
	node("SideColumn").custom_minimum_size.x=176 if compact else 216
	node("CityMap").viewport_height=node("MapScroll").size.y
	node("CityMap")._layout()
	_fit_state_key()
	queue_redraw()

func _fit_state_key() -> void:
	# Decorative children do not set this spacer's minimum size. A long selection
	# retains its fixed actions; the same state key remains in the legend modal.
	if node("StateKey")!=null:node("StateKey").visible=node("Spacer").size.y>=112.0

func _restore_view() -> void:
	if not is_inside_tree(): return
	var tree := get_tree()
	for i in range(4):
		await tree.process_frame
		if not is_inside_tree(): return
	_responsive()
	await tree.process_frame
	if not is_inside_tree(): return
	var scroll: ScrollContainer=node("MapScroll")
	if director.map_memory.get("key","")==memory_key: scroll.scroll_vertical=int(director.map_memory.get("scroll",0))
	_reveal(true)
	restoring=false
	_remember()

func _select(id: int, reveal: bool=true) -> void:
	var item: Dictionary={}
	for candidate in campaign.current_nodes():
		if int(candidate.id)==id: item=candidate; break
	if item.is_empty(): return
	selected_id=id
	var can_enter: bool=campaign.choices().any(func(n):return int(n.id)==id)
	var shortcut: bool=campaign.is_shortcut(id)
	var role: String=Data.room_kind(item)
	node("CityMap").select_room(id)
	node("SelectionMode").text="이동할 장소" if can_enter else "미리보기"
	node("MapSelectionPrompt").text=("샛길 → " if shortcut else "")+str(item.name)
	node("SelectionIcon").texture=Place.icon(role, true)
	node("SelectionKind").text=Data.kind_name(role)
	var brief: PackedStringArray=[]
	if not can_enter: brief.append("연결된 길로만 갈 수 있음")
	elif shortcut: brief.append("전투 1곳 생략 · 그 보상과 코어 성장 없음")
	elif item.get("elite",false): brief.append("강한 적 · 파츠 보상")
	elif item.get("workshop",false): brief.append("무료 정비 1회")
	elif item.kind=="event": brief.append("결과는 고른 뒤 공개")
	elif item.kind=="boss": brief.append("이기면 다음 구역" if int(campaign.s.region)<4 else "중앙 제어실로")
	if can_enter and item.route=="duct": brief.append("시작 거리 −2m · 추가 보상")
	elif can_enter and item.kind in ["combat","boss"] and int(campaign.s.pressure)>0: brief.append("이전 선택으로 시작 거리 −2m")
	node("MapRouteDetail").text=" · ".join(brief)
	node("MapRouteDetail").visible=not brief.is_empty()
	var enter: Button=enter_button
	# A stable owner path supports the legacy public command name without duplicate buttons.
	if can_enter: enter.name="city_enter_"+str(id)
	enter.visible=can_enter; enter.disabled=not can_enter or host.busy
	enter.text="전투 건너뛰기" if shortcut else "이동"
	var gate: Button=node("map_node_"+str(gate_id))
	gate.set_available(node("CityMap").available.has(gate_id))
	gate.add_theme_stylebox_override("normal",MapMaterial.SELECTION if id==gate_id else MapMaterial.GATE)
	gate.modulate=Color.WHITE if id==gate_id or node("CityMap").available.has(gate_id) else MapMaterial.MUTED
	if reveal: _reveal.call_deferred(false)
	_remember()

func _reveal(force: bool) -> void:
	if not is_inside_tree(): return
	var graph=node("CityMap")
	if not graph.positions.has(selected_id): return
	var scroll: ScrollContainer=node("MapScroll")
	var y: float=graph.positions[selected_id].y
	var top:=y-30; var bottom:=y+30
	if graph.positions.has(int(campaign.s.node)):
		var here: float=graph.positions[int(campaign.s.node)].y
		if maxf(bottom,here+30)-minf(top,here-30)<=scroll.size.y:
			top=minf(top,here-30);bottom=maxf(bottom,here+30)
	# Keep the last travelled edge in context when three neighboring places fit.
	var current_index: int=graph.visited.find(int(campaign.s.node))
	if current_index>0 and graph.positions.has(graph.visited[current_index-1]):
		var previous: float=graph.positions[graph.visited[current_index-1]].y
		if maxf(bottom,previous+30)-minf(top,previous-30)<=scroll.size.y:
			top=minf(top,previous-30);bottom=maxf(bottom,previous+30)
	if force or top<scroll.scroll_vertical or bottom>scroll.scroll_vertical+scroll.size.y:
		scroll.scroll_vertical=int((top+bottom-scroll.size.y)*0.5)

func _remember() -> void:
	if restoring or director==null: return
	director.map_memory={"key":memory_key,"selected":selected_id,"scroll":node("MapScroll").scroll_vertical}

func _open_key() -> void:
	var body: VBoxContainer=host._workspace("지도 범례","")
	body.add_child(preload("res://redesign/pipe_map/key.tscn").instantiate())
	MapMaterial.style_workspace(host.workspace_overlay)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),MapMaterial.BACKGROUND)
	if has_node("Header"):
		draw_line(Vector2(0,$Header.size.y),Vector2(size.x,$Header.size.y),MapMaterial.METAL,1,false)
