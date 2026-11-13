extends RefCounted
const Gates = preload("res://redesign/gate_upgrades.gd")
const Ammo = preload("res://redesign/content.gd")
const Offer = preload("res://redesign/ammo_offer.tscn")
const Engines = preload("res://redesign/damage_engines.gd")

static func growth_projection(state: Dictionary) -> String:
	for id in Ammo.equipped_parts(state):
		if not Engines.IDS.has(id): continue
		var copy := state.duplicate(false)
		copy.engine = state.engine.duplicate(true)
		copy.engine.levels[id] = mini(Gates.Growth.BASE_LIMIT+Gates.Growth.STEP*Gates.Growth.MAX_UPGRADES,Gates.Growth.limit(state)+Gates.Growth.STEP)
		return "성장 완료 시 "+Engines.value(copy,id)
	return "성장 코어 장착 후 조건 달성"

class Glyph extends Control:
	var kind := "thermal"
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	func _draw() -> void:
		var p := size*0.5
		if kind=="production":
			for i in range(3): preload("res://redesign/ammo_visual.gd").round_icon(self,p+Vector2((i-1)*32,0),"pierce",0.38)
		else:
			preload("res://redesign/part_icon_art.gd").draw(self,"siege_drive" if kind=="growth" else "cooling_breech" if kind in ["thermal","efficiency"] else "supply" if kind=="cadence" else "arc_splitter" if kind=="conduction" else "ordinary_chain",p,Color("c9b47a"),1.25)

static func render(host) -> void:
	var ui = host.ui
	var campaign = host.campaign
	if campaign.gate_ready():
		reorganization(host)
		return
	host._phase_intro("▲","관문 개조","1 개조 선택 → 2 재정비 → 3 출발 · 이번 등반에 유지",Color("d6b676"))
	var workspace: VBoxContainer = host._collection_workspace(ui.body,minf(930,ui.get_viewport_rect().size.x-64))
	workspace.name = "GateUpgradeWorkspace"
	workspace.add_theme_constant_override("separation",14)
	var current := Gates.active_summary(ui.model.s)
	if not current.is_empty(): ui._label(workspace,current,17,ui.MUTED)
	var offers: Array = campaign.gate_options()
	var row: Container = GridContainer.new() if offers.size()>3 or ui.get_viewport_rect().size.x<1000 else HBoxContainer.new()
	row.name = "GateUpgradeGrid"
	if row is GridContainer:
		row.columns = 2 if ui.get_viewport_rect().size.x>=680 else 1
		row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		row.add_theme_constant_override("h_separation",12)
		row.add_theme_constant_override("v_separation",12)
	else:
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation",12)
	workspace.add_child(row)
	var selection := {"id":""}
	var buttons: Array = []
	var detail: Label = ui._label(workspace,"개조를 선택하면 아래에서 적용할 수 있습니다.",19,ui.MUTED)
	detail.name = "GateSelectionSummary"
	detail.custom_minimum_size.y = 52
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation",12)
	workspace.add_child(actions)
	var skip: Button = ui._button(actions,"개조 건너뛰기","city_gate_skip",func(): confirm_skip(host))
	skip.custom_minimum_size = Vector2(180,52)
	skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	var apply: Button = ui._button(actions,"개조 선택","city_gate_apply",func():
		if selection.id=="production": specimens(host)
		elif not str(selection.id).is_empty(): host.action("gate",selection.id)
	,true)
	apply.custom_minimum_size = Vector2(260,52)
	apply.size_flags_horizontal = Control.SIZE_SHRINK_END
	ui._primary_button(apply)
	for id in offers:
		var button: Button = ui._button(row,"","city_gate_"+id,func(): pass)
		button.toggle_mode = true
		var card_height := 220.0 if offers.size()>3 else 300.0
		var card_width:=minf(434,(ui.get_viewport_rect().size.x-80)/row.columns) if row is GridContainer else 284.0
		button.custom_minimum_size = Vector2(card_width,card_height)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.add_theme_stylebox_override("normal",ui._console_style("panel"))
		button.add_theme_stylebox_override("pressed",ui._console_style("panel","selected"))
		button.tooltip_text = Gates.description(id)+"\n"+Gates.caution(id)
		var margin := MarginContainer.new()
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,16)
		button.add_child(margin)
		margin.minimum_size_changed.connect(func(): button.custom_minimum_size.y = maxf(card_height,margin.get_combined_minimum_size().y))
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_theme_constant_override("separation",6 if offers.size()>3 else 10)
		margin.add_child(box)
		ui._label(box,"신규 개조" if Gates.level(ui.model.s,id)==0 else "개조 강화 · "+["I","II","III"][mini(2,Gates.level(ui.model.s,id))],15,ui.MUTED)
		var glyph := Glyph.new()
		glyph.kind = id
		glyph.custom_minimum_size = Vector2(0,32 if offers.size()>3 else 60)
		box.add_child(glyph)
		ui._label(box,Gates.NAMES[id],24,ui.INK)
		ui._label(box,Gates.summary(id,ui.model.s,true),22,Color("d6b676"))
		ui._label(box,growth_projection(ui.model.s) if id=="growth" else {"thermal":"냉각한 열을 첫 발의 피해로", "chain":"처치할수록 남은 탄이 강하게", "production":"선택한 특수탄을 덱의 주력으로", "cadence":"한 번에 더 많은 탄을 선택", "efficiency":"같은 열로 더 오래 사격", "conduction":"처치 전이의 대상 수를 확장"}[id],18,ui.INK)
		var spacer := Control.new()
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(spacer)
		ui._label(box,"즉시 피해 증가 없음" if id=="growth" else "현재 "+Gates.summary(id,ui.model.s) if Gates.level(ui.model.s,id)>0 else ("덱 "+str(ui.model.s.deck.size())+"장 유지" if id=="production" else "현재 미보유"),16,ui.MUTED)
		buttons.append(button)
		button.pressed.connect(func():
			selection.id = id
			for other in buttons: other.set_pressed_no_signal(other==button)
			detail.text = Gates.description(id)+"\n"+Gates.caution(id)
			if id=="growth": detail.text += "\n"+growth_projection(ui.model.s)
			apply.text = "견본과 교체할 탄 선택" if id=="production" else Gates.NAMES[id]+" 적용"
			apply.disabled = false
		)
	if offers.is_empty(): detail.text = "적용 가능한 개조가 없습니다. 건너뛰기를 눌러 재정비로 이동하세요."
	elif offers.size()<3:
		ui._label(workspace,"최대 강화 또는 생산 재료가 없는 개조는 제외됩니다.",16,ui.MUTED)
	if offers.size()>3: _focus_depart.call_deferred(buttons[0])
	ui._label(workspace,"다음 목적지 · "+str(campaign.region_info(int(campaign.s.region)+1).name),18,ui.MUTED)

static func reorganization(host) -> void:
	var ui = host.ui
	var campaign = host.campaign
	host._phase_intro("▲","관문 재정비","개조 선택 완료 · 보유 파츠와 탄약을 확인한 뒤 출발하세요.",Color("d6b676"))
	var workspace: VBoxContainer = host._collection_workspace(ui.body,minf(930,ui.get_viewport_rect().size.x-64))
	workspace.name = "GateReorganizationWorkspace"
	workspace.add_theme_constant_override("separation",12)
	var destination: Dictionary = campaign.region_info(int(campaign.s.region)+1)
	ui._label(workspace,"다음 구역 · "+str(destination.name),26,ui.INK)
	ui._label(workspace,str(destination.brief),18,ui.MUTED)
	var receipt: Label = ui._label(workspace,str(campaign.s.message),19,ui.ACCENT)
	receipt.name = "GateReorganizationReceipt"
	var current := Gates.active_summary(ui.model.s)
	if not current.is_empty(): ui._label(workspace,current,18,ui.MUTED)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",12)
	workspace.add_child(actions)
	for entry in [["보유 파츠 관리","city_gate_parts","parts"],["탄약 구성 확인","city_gate_ammo","ammo"]]:
		var button: Button = ui._button(actions,entry[0],entry[1],host.deck.bind(entry[2]))
		button.custom_minimum_size = Vector2(0,56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var depart: Button = ui._button(actions,"다음 구역으로 출발","city_gate_depart",host.action.bind("gate_depart"))
	depart.custom_minimum_size = Vector2(0,56)
	depart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui._primary_button(depart)
	ui._label(workspace,"%s · %s · 탄창 %d칸 · 재장전 %d턴" % [Ammo.GUNS[campaign.s.gun].name,Ammo.outfit_name(ui.model.s),ui.model.capacity(),ui.model.reload_cost()],19,ui.INK)
	if campaign.magazine_enabled(): ui._label(workspace,"보유 탄약 %d/%d발" % [ui.model.s.deck.size(),ui.model.deck_limit()],19,ui.INK)
	else: ui._label(workspace,"휴대 탄약 %d/%d장 · 손패 %d장 · 교환 %d회" % [ui.model.s.deck.size(),ui.model.deck_limit(),Ammo.hand_capacity(ui.model.s),Ammo.exchange_capacity(ui.model.s)],19,ui.INK)
	if campaign.Economy.enabled(campaign.s):
		var service:=VBoxContainer.new()
		service.name="GateBagService"
		service.add_theme_constant_override("separation",8)
		workspace.add_child(service)
		var hint: String="관문당 유료 정비 1회 · 가방 확장 또는 보유 탄 복제"
		var title: String="탄약 상한 %d → %d발 · %dCr"%[ui.model.deck_limit(),ui.model.deck_limit()+2,campaign.Economy.BAG_PRICE]
		if campaign.s.gate_bag_used or campaign.s.get("gate_ammo_used",false):title="이번 관문 유료 정비 완료"
		elif not campaign.can_grow_bag():title="가방 확장 한도 도달"
		elif int(campaign.s.credits)<campaign.Economy.BAG_PRICE:title+=" · %dCr 부족"%(campaign.Economy.BAG_PRICE-int(campaign.s.credits))
		ui._label(service,"유료 정비 · 보유 %dCr"%campaign.s.credits,19,ui.INK)
		ui._label(service,hint,17,ui.MUTED)
		var expand: Button=ui._button(service,title,"city_gate_bag_service",host.action.bind("gate_bag"),not campaign.can_buy_gate_bag())
		expand.custom_minimum_size.y=52
		ui._label(service,"가방 확장은 공방과 합쳐 3회까지",17,ui.MUTED)
		var copy_ready: bool=campaign.gate_copy_options().any(func(id):return campaign.can_buy_gate_copy(id))
		var copy: Button=ui._button(service,"보유 탄 1장 복제 · 12 / 24Cr","city_gate_copy_service",copies.bind(host),not copy_ready)
		copy.custom_minimum_size.y=52
	host.equipped_strip(workspace)
	ui._label(workspace,"파츠 교체는 무료 · 탄약은 다음 전투에서 보유 구성으로 복구됩니다.",17,ui.MUTED)
	_focus_depart.call_deferred(depart)

static func _focus_depart(button: Button) -> void:
	if is_instance_valid(button) and button.is_inside_tree(): button.grab_focus()

static func confirm_skip(host) -> void:
	var column: VBoxContainer = host.ui._dialog("관문 개조 건너뛰기",true)
	var dialog = column.get_meta("dialog")
	host.ui._label(column,"이번 관문의 개조를 포기하고 재정비로 이동합니다. 선택은 되돌릴 수 없습니다.",20)
	host.ui._button(column,"건너뛰고 재정비","gate_skip_confirm",func():
		dialog.close()
		host.action("gate","skip")
	)

static func specimens(host) -> void:
	var ui = host.ui
	var column: VBoxContainer = ui._dialog("생산할 특수탄 선택",false)
	column.name = "GateProductionSpecimens"
	var dialog = column.get_meta("dialog")
	dialog.set_meta("preferred_size",Vector2(850,560))
	dialog._fit()
	ui._label(column,"1 / 2 · 보유한 일반 특수탄을 견본으로 선택",21,ui.INK)
	ui._label(column,"위력·개조를 그대로 복제합니다. 다음 단계에서 기본탄 3장을 고릅니다.",17,ui.MUTED)
	var grid := GridContainer.new()
	grid.columns = 3 if ui.get_viewport_rect().size.x>=1000 else 2 if ui.get_viewport_rect().size.x>=640 else 1
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	column.add_child(grid)
	for id in Gates.specimens(ui.model.s.deck):
		var button: Button = Offer.instantiate()
		button.name = "gate_specimen_"+id
		button.custom_minimum_size = Vector2(230,180)
		grid.add_child(button)
		button.get_node("CardInfo").setup(id,1,ui.model.s,false,false,"동일 성능 %d → %d장" % [ui.model.s.deck.count(id),ui.model.s.deck.count(id)+3])
		button.pressed.connect(func():
			dialog.close()
			sources(host,id)
		)

static func sources(host, specimen: String) -> void:
	var ui = host.ui
	var column: VBoxContainer = ui._dialog("교체할 기본탄 3장 선택",false)
	column.name = "GateProductionSources"
	var dialog = column.get_meta("dialog")
	dialog.set_meta("preferred_size",Vector2(800,620))
	dialog._fit()
	ui._label(column,"2 / 2 · "+str(Ammo.AMMO[specimen].name)+" 3장 생산",23,ui.INK)
	ui._label(column,"선택한 기본탄을 교체 · 총 %d장 유지 · 확정 전에는 변경되지 않습니다." % ui.model.s.deck.size(),17,ui.MUTED)
	var selected: Array = []
	var basics := Gates.basics(ui.model.s.deck)
	var unique: Array = []
	var controls: Array = []
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation",8)
	column.add_child(rows)
	var receipt: Label = ui._label(column,"기본탄 0 / 3장 선택",20,ui.ACCENT)
	receipt.name = "GateProductionReceipt"
	var apply: Button = ui._button(column,"3장을 선택하세요","gate_production_apply",func():
		if not Gates.can_produce(ui.model.s,specimen,selected): return
		dialog.close()
		host.action("gate_production",selected.duplicate(),specimen)
	,true)
	ui._primary_button(apply)
	var refresh := func():
		receipt.text = "기본탄 %d / 3장 · %s %d → %d장" % [selected.size(),Ammo.AMMO[specimen].name,ui.model.s.deck.count(specimen),ui.model.s.deck.count(specimen)+3]
		apply.disabled = selected.size()!=3
		apply.text = "기본탄 3장 교체 · 생산 확정" if selected.size()==3 else "3장을 선택하세요"
		for item in controls:
			item.count.text = "%d / %d장" % [selected.count(item.id),basics.count(item.id)]
			item.minus.disabled = selected.count(item.id)==0
			item.plus.disabled = selected.size()>=3 or selected.count(item.id)>=basics.count(item.id)
	for id in basics:
		if unique.has(id): continue
		unique.append(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation",10)
		rows.add_child(row)
		ui._label(row,"기본탄 · 피해 %d · 열 %s" % [Ammo.damage(id,ui.model.s),Ammo.heat_label(id,ui.model.s)],20,ui.INK)
		var minus: Button = ui._button(row,"−","gate_source_minus_"+id,func():
			selected.erase(id)
			refresh.call()
		)
		minus.custom_minimum_size = Vector2(52,52)
		minus.size_flags_horizontal = Control.SIZE_SHRINK_END
		var count: Label = ui._label(row,"",19)
		count.custom_minimum_size.x = 85
		count.size_flags_horizontal = Control.SIZE_SHRINK_END
		var plus: Button = ui._button(row,"+","gate_source_plus_"+id,func():
			if selected.size()<3 and selected.count(id)<basics.count(id): selected.append(id)
			refresh.call()
		)
		plus.custom_minimum_size = Vector2(52,52)
		plus.size_flags_horizontal = Control.SIZE_SHRINK_END
		controls.append({"id":id,"count":count,"plus":plus,"minus":minus})
	refresh.call()

static func copies(host) -> void:
	var ui=host.ui
	var campaign=host.campaign
	var column: VBoxContainer=ui._dialog("보유 탄 1장 복제",false)
	column.name="GateCopyOptions"
	var dialog=column.get_meta("dialog")
	ui._label(column,"현재 성능 그대로 1장 추가 · 관문 유료 정비 1회 사용",20,ui.INK)
	ui._label(column,"보유 %dCr · 탄약 %d/%d발"%[campaign.s.credits,ui.model.s.deck.size(),ui.model.deck_limit()],18,ui.MUTED)
	var grid:=GridContainer.new()
	grid.columns=3 if ui.get_viewport_rect().size.x>=1000 else 2 if ui.get_viewport_rect().size.x>=640 else 1
	grid.add_theme_constant_override("h_separation",12);grid.add_theme_constant_override("v_separation",12)
	column.add_child(grid)
	for id in campaign.gate_copy_options():
		var button: Button=Offer.instantiate()
		button.name="gate_copy_"+id;button.custom_minimum_size=Vector2(230,180)
		button.disabled=not campaign.can_buy_gate_copy(id)
		grid.add_child(button)
		button.get_node("CardInfo").setup(id,1,ui.model.s,button.disabled,false,"%dCr · %d → %d장"%[campaign.gate_copy_price(id),ui.model.s.deck.count(id),ui.model.s.deck.count(id)+1])
		button.pressed.connect(func():dialog.close();host.action("gate_copy",id))
