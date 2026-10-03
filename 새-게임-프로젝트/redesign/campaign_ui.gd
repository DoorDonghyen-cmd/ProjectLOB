extends RefCounted
const Data = preload("res://redesign/campaign_content.gd")
const Ammo = preload("res://redesign/content.gd")
const MapView = preload("res://redesign/city_map_view.gd")
const Card = preload("res://redesign/ammo_card_view.gd")
const PartCard = preload("res://redesign/part_card_view.gd")
const BuildGuide = preload("res://redesign/build_guide.gd")
const UpgradeChoice = preload("res://redesign/upgrade_choice_view.gd")
const CompressionChoice = preload("res://redesign/compression_choice_view.gd")
const ShopWorkbench = preload("res://redesign/shop_workbench.tscn")
const DeckLoadout = preload("res://redesign/deck_loadout.tscn")
const Insight = preload("res://redesign/run_insight.gd")
const Lore = preload("res://redesign/city_story.gd")
const CompressorGlyph = preload("res://redesign/field_compressor_view.gd")
const SceneBanner = preload("res://redesign/scene_banner.gd")
var ui
var campaign
var workspace_feedback := ""
var selected_part_id := ""
var replacement_part_id := ""
var shop_selection := 0

func render(screen) -> void:
	ui = screen
	campaign = ui.campaign
	var state: Dictionary = campaign.s
	_run_shell(state)
	if ui.debug_session: ui._label(ui.body, "개발자 연습 · 실제 진행 저장 보존", 18, ui.DANGER)
	if not ui.save_error.is_empty(): ui._label(ui.body, ui.save_error, 18, ui.DANGER)
	match str(state.phase):
		"map": map_screen()
		"shop": shop()
		"reward": reward()
		"supply", "event", "bypass": service()
		"gate": gate()
		"won", "lost": ending()

func action(name: String, value: Variant = "", extra: String = "") -> void:
	ui._campaign_action(name, value, extra)

func _run_shell(state: Dictionary) -> void:
	var shell := PanelContainer.new()
	shell.name = "CampaignShellHeader"
	var shell_style: StyleBoxFlat = ui._style(Color("17242c"))
	shell_style.content_margin_top = 8
	shell_style.content_margin_bottom = 8
	shell_style.border_color = Color("38515d")
	shell_style.set_border_width_all(1)
	shell.add_theme_stylebox_override("panel", shell_style)
	ui.body.add_child(shell)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	shell.add_child(column)
	var top: HBoxContainer = ui._row(column)
	var location: Label = ui._label(top, "%s  ·  %02d / 35" % [Data.info(int(state.region)).name, campaign.absolute_floor()], 23, ui.ACCENT)
	location.name = "RunLocation"
	location.autowrap_mode = TextServer.AUTOWRAP_OFF
	for entry in [["빌드", "city_deck", deck], ["기록", "city_archive", archive], ["설정", "settings", ui._settings], ["메뉴", "menu", ui._to_menu]]:
		var button: Button = ui._button(top, entry[0], entry[1], entry[2])
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		button.custom_minimum_size = Vector2(78, 40)
		button.add_theme_font_size_override("font_size", ui._scaled(17))
	var stats := HFlowContainer.new()
	stats.name = "RunStatusBar"
	stats.add_theme_constant_override("h_separation", 20)
	stats.add_theme_constant_override("v_separation", 4)
	column.add_child(stats)
	var level := int(Data.info(int(state.region)).base_level) + maxi(1, int(state.floor)) - 1
	_shell_metric(stats, "▥ LV.%d" % level, ui.INK)
	_shell_metric(stats, "● %d Cr" % int(state.credits), ui.ACCENT)
	_shell_metric(stats, "◆ %d/%d" % [state.compressor_charges, campaign.MAX_COMPRESSOR_CHARGES], Color("63dce8"))
	_shell_metric(stats, "⌁ %s · %d칸" % [Ammo.GUNS[state.gun].name, ui.model.capacity()], ui.INK)
	_shell_metric(stats, "▤ %d/14" % ui.model.s.deck.size(), ui.INK)
	_shell_metric(stats, "▲ 난도 %d%s" % [state.difficulty, " · 거리−2m" if int(state.pressure) > 0 else ""], ui.DANGER if int(state.pressure) > 0 else ui.MUTED)

func _shell_metric(parent: Node, text: String, color: Color) -> void:
	var label: Label = ui._label(parent, text, 16, color)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.autowrap_mode = TextServer.AUTOWRAP_OFF

func _phase_intro(marker: String, title: String, question: String, color: Color, height: int = 96) -> void:
	var panel := PanelContainer.new()
	panel.name = "PhaseHeader"
	panel.custom_minimum_size.y = ui._scaled(height)
	panel.clip_contents = true
	var style: StyleBoxFlat = ui._style(Color("142129"))
	style.set_content_margin_all(0)
	style.border_color = color.darkened(0.25)
	style.border_width_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	ui.body.add_child(panel)
	var layer := Control.new()
	panel.add_child(layer)
	var backdrop := SceneBanner.new()
	backdrop.region = int(campaign.s.region)
	backdrop.show_reclaimer = height > 150
	backdrop.art_id = "workshop" if campaign.s.phase in ["shop", "supply"] else ""
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]: margin.add_theme_constant_override("margin_" + side, 20)
	for side in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + side, 12)
	layer.add_child(margin)
	var row: HBoxContainer = ui._row(margin)
	var badge: Label = ui._label(row, marker, 30, color)
	badge.custom_minimum_size.x = 44
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(copy)
	ui._label(copy, title, 36 if height > 150 else 29, color)
	if not question.is_empty(): ui._label(copy, question, 17, Color("c4cecd"))

func ammo_card(parent: Node, id: String) -> Control:
	var view := Card.new()
	view.custom_minimum_size = Vector2(230, 104)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.setup(id, 1, ui.model.s)
	parent.add_child(view)
	return view

func part_card(parent: Node, id: String, compact: bool = false, equipped: bool = false, mini: bool = false) -> Control:
	var view := PartCard.new()
	view.name = "PartCard_" + id
	view.custom_minimum_size = Vector2(144 if mini else (310 if compact else 260), 58 if mini else (82 if compact else 128))
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.setup(id, ui.model.s, equipped, compact, mini)
	parent.add_child(view)
	return view

func part_details(id: String) -> void:
	var panel = ui._dialog(str(Ammo.PARTS[id].name), true)
	panel.name = "PartDetails"
	var view := part_card(panel, id, false, campaign.is_equipped(id))
	view.custom_minimum_size.y = 132
	ui._label(panel, str(Ammo.PARTS[id].text), 19)
	ui._label(panel, BuildGuide.connection(id, ui.model.s), 18, ui.ACCENT)
	ui._label(panel, ("현재 적용 · " if campaign.is_equipped(id) else "장착 시 · ") + Insight.reward_impact(id, ui.model.s, []), 17, ui.ACCENT)

func _purchase_will_equip(id: String) -> bool:
	var proposed: Array = campaign.equipped_parts()
	if proposed.has(id): return false
	proposed.append(id)
	return Ammo.valid_part_set(str(campaign.s.gun), proposed)

func _offer_destination(id: String) -> String:
	if campaign.is_equipped(id): return "장착 중"
	if campaign.s.parts.has(id): return "보관 중"
	return "즉시 장착" if _purchase_will_equip(id) else "보관함으로 이동"

func equipped_grid(parent: Node) -> void:
	var grid := GridContainer.new()
	grid.name = "EquippedPartGrid"
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	parent.add_child(grid)
	var equipped: Array = campaign.equipped_parts()
	for slot in range(campaign.MAX_EQUIPPED_PARTS):
		var id := str(equipped[slot]) if slot < equipped.size() else "none"
		var cell: Button = ui._button(grid, "", "equipped_part_detail_" + str(slot), part_details.bind(id), id == "none")
		cell.custom_minimum_size = Vector2(190, 220)
		var card := part_card(cell, id, false, id != "none")
		card.custom_minimum_size = Vector2.ZERO
		card.portrait = true
		card.slot_number = slot + 1

func equipped_strip(parent: Node) -> void:
	var strip := HBoxContainer.new()
	strip.name = "EquippedPartStrip"
	strip.add_theme_constant_override("separation", 7)
	parent.add_child(strip)
	var equipped: Array = campaign.equipped_parts()
	for slot in range(campaign.MAX_EQUIPPED_PARTS):
		var cell := VBoxContainer.new()
		cell.custom_minimum_size.x = 144
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_constant_override("separation", 2)
		strip.add_child(cell)
		var id := str(equipped[slot]) if slot < equipped.size() else "none"
		ui._label(cell, "%02d%s" % [slot + 1, " · CORE" if Ammo.is_core_part(id) else ""], 12, Color("ffd86b") if Ammo.is_core_part(id) else ui.MUTED)
		part_card(cell, id, true, id != "none", true)

func upgrade_card(button: Button, kind: String, values: Dictionary = {}) -> void:
	button.custom_minimum_size.y = 118
	var view := UpgradeChoice.new()
	view.name = "UpgradeChoice_" + kind
	view.setup(kind, values)
	button.add_child(view)

func map_screen() -> void:
	_phase_intro("▥", "다음 목적지", "다음 방을 고르세요. 준비된 경로가 밝게 표시됩니다.", ui.ACCENT)
	var map := MapView.new()
	map.name = "CityMap"
	map.setup(campaign)
	map.inspected.connect(inspect_node)
	var workspace := HBoxContainer.new()
	workspace.name = "MapWorkspace"
	workspace.add_theme_constant_override("separation", 14)
	ui.body.add_child(workspace)
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.add_child(map)
	var route_sheet := PanelContainer.new()
	route_sheet.name = "MapRouteSheet"
	var route_style: StyleBoxFlat = ui._style(Color("17242c"))
	route_style.border_color = ui.ACCENT
	route_style.set_border_width_all(1)
	route_sheet.add_theme_stylebox_override("panel", route_style)
	route_sheet.custom_minimum_size.x = 330
	route_sheet.size_flags_horizontal = Control.SIZE_FILL
	workspace.add_child(route_sheet)
	var route_column := VBoxContainer.new()
	route_column.add_theme_constant_override("separation", 6)
	route_sheet.add_child(route_column)
	var selection_label: Label = ui._label(route_column, "목적지를 선택하세요", 22, ui.ACCENT)
	selection_label.name = "MapSelectionPrompt"
	var route_detail: Label = ui._label(route_column, "밝은 방을 누르면 시설과 이동 위험을 여기에서 확인합니다.", 17, ui.MUTED)
	route_detail.name = "MapRouteDetail"
	var row := VBoxContainer.new()
	route_column.add_child(row)
	var choice_buttons: Dictionary = {}
	var choice_items: Dictionary = {}
	for item in campaign.choices():
		var enter_button: Button = ui._button(row, "이동 확정", "city_enter_" + str(item.id), action.bind("enter", int(item.id)), true)
		enter_button.visible = false
		choice_buttons[int(item.id)] = enter_button
		choice_items[int(item.id)] = item
	map.selected.connect(func(id: int):
		var selected_item: Dictionary = choice_items.get(id, {})
		if selected_item.is_empty(): return
		selection_label.text = "%s  ·  %s" % [selected_item.name, Data.kind_name(str(selected_item.kind))]
		route_detail.text = Data.hint(selected_item)
		if selected_item.kind in ["combat", "boss"]:
			var pressure := 2 if selected_item.route == "duct" or int(campaign.s.pressure) > 0 else 0
			var pack := Data.encounter_pack(selected_item, int(campaign.s.seed), str(campaign.s.gun), int(campaign.s.difficulty), pressure)
			var threat := Insight.threat_data(pack.active + pack.reserve)
			route_detail.text += "\n\n전열 %d · 증원 %d · 장갑 최대 %d" % [pack.active.size(), pack.reserve.size(), threat.max_armor]
			if pressure > 0: route_detail.text += "\n시작 거리 −2m"
			if selected_item.route == "duct": route_detail.text += "\n크레딧 보상 +%dCr" % Data.ROUTE_REWARD_BONUS
			var lesson := Data.lesson(selected_item, ui.model.s)
			if not lesson.is_empty(): route_detail.text += "\n\n" + lesson
		elif selected_item.kind == "shop":
			route_detail.text += "\n\n보유 %dCr · 파츠 30Cr\n진열 교체 3 → 5 → 7 → 9Cr" % int(campaign.s.credits)
		if selected_item.route == "duct" and not selected_item.kind in ["combat", "boss"]: route_detail.text += "\n환기구 · 다음 전투 시작 거리 −2m"
		for button_id in choice_buttons:
			var button := choice_buttons[button_id] as Button
			button.disabled = int(button_id) != id
			button.visible = int(button_id) == id
			if int(button_id) == id:
				button.text = "%s로 이동" % selected_item.name
				ui._primary_button(button)
	)
	ui._hint(route_column, "어두운 방은 눌러서 이후 시설과 적 편성을 미리 볼 수 있습니다.")

func inspect_node(id: int) -> void:
	var item: Dictionary = {}
	for candidate in campaign.current_nodes():
		if int(candidate.id) == id: item = candidate
	if item.is_empty(): return
	var panel = ui._dialog(str(item.name), true)
	ui._label(panel, Data.hint(item), 22)
	ui._label(panel, "\uacc4\ub2e8 \u00b7 \ubb34\ub8cc" if item.route == "stairs" else "\ud658\uae30\uad6c \u00b7 \ub2e4\uc74c \uc804\ud22c \uc2dc\uc791 \uac70\ub9ac -2m", 18, ui.ACCENT)
	if item.route == "duct" and item.kind in ["combat", "boss"]: ui._label(panel, "크레딧 보상 +%dCr" % Data.ROUTE_REWARD_BONUS, 19, ui.ACCENT)
	if item.kind in ["combat", "boss"]:
		var pack := Data.encounter_pack(item, int(campaign.s.seed), str(campaign.s.gun), int(campaign.s.difficulty), 2 if item.route == "duct" or int(campaign.s.pressure) > 0 else 0)
		var all_enemies: Array = pack.active + pack.reserve
		ui._label(panel, Insight.threat_line(all_enemies), 18)
		var count_label: Label = ui._label(panel, "\uc804\uc5f4 %d  \u00b7  \uc99d\uc6d0 %d  \u00b7  \ucd1d %d" % [pack.active.size(), pack.reserve.size(), pack.total], 20, ui.ACCENT)
		count_label.name = "FormationCount"
		var front: HBoxContainer = ui._row(panel)
		for enemy_index in range(pack.active.size()):
			var enemy: Dictionary = pack.active[enemy_index]
			var chip: VBoxContainer = ui._panel(front)
			chip.get_parent().custom_minimum_size.x = 128
			ui._label(chip, "%s  %s" % [String.chr(65 + enemy_index), enemy.name], 16)
			ui._label(chip, "HP%d  \u25c6%d  %dm" % [enemy.hp, enemy.def, enemy.distance], 15, ui.MUTED)
		if not pack.reserve.is_empty():
			var reserve_names: PackedStringArray = []
			for enemy in pack.reserve: reserve_names.append(str(enemy.name))
			ui._label(panel, "\ub300\uae30  " + "  >  ".join(reserve_names), 16, Color("63dce8"))
func reward() -> void:
	_phase_intro("◆", str(campaign.node().name) + " 통과", "전투 결과를 하나의 다음 선택으로 바꾸세요.", Color("ffd86b"))
	var reward_frame: VBoxContainer = ui._panel(ui.body)
	reward_frame.get_parent().name = "RewardFrame"
	ui._encounter_debrief(reward_frame, campaign.encounter_report_state())
	var row := GridContainer.new()
	row.name = "RewardGrid"
	row.columns = 3
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 12)
	reward_frame.add_child(row)
	for id in Data.rewards(campaign.node(), int(campaign.s.seed)):
		var panel = ui._panel(row)
		panel.get_parent().custom_minimum_size.x = 285
		ammo_card(panel, id)
		ui._label(panel, "현재 %d장 → 선택 후 %d장" % [ui.model.s.deck.count(id), ui.model.s.deck.count(id) + 1], 16, ui.MUTED)
		ui._label(panel, "영향 · " + Insight.reward_impact(id, ui.model.s, []), 17, ui.ACCENT)
		var take: Button = ui._button(panel, "1장 가져가기", "city_reward_" + id, action.bind("reward", id), ui.model.s.deck.size() >= 14)
		if not take.disabled: ui._primary_button(take, Color("ffd86b"))
	var wallet = ui._panel(row)
	wallet.get_parent().custom_minimum_size.x = 285
	ui._label(wallet, "+%d Cr" % campaign.credit_reward(), 42, ui.ACCENT)
	ui._label(wallet, "전투 소모가 적을수록 배급 증가\n상점 탄환 12Cr / 파츠 30Cr", 18, ui.MUTED)
	if campaign.node().route == "duct": ui._label(wallet, "환기구 보너스 +%dCr 포함" % Data.ROUTE_REWARD_BONUS, 16, ui.ACCENT)
	ui._primary_button(ui._button(wallet, "크레딧 받기", "city_reward_credits", action.bind("reward", "credits")), Color("ffd86b"))
	var skip: Button = ui._button(reward_frame, "선택 없이 계속", "city_reward_skip", action.bind("reward", "skip"))
	skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	skip.custom_minimum_size.x = 190

func shop() -> void:
	var heading: HBoxContainer = ui._row(ui.body)
	ui._label(heading, str(campaign.node().name), 28, ui.ACCENT)
	ui._label(heading, "탄환과 파츠로 다음 전투를 준비하세요.", 17, ui.MUTED)
	var workbench := ShopWorkbench.instantiate()
	workbench.add_theme_constant_override("separation", 8)
	ui.body.add_child(workbench)
	_style_shop_workbench(workbench)
	var top_actions: HBoxContainer = workbench.get_node("%TopActions")
	ui._button(top_actions, "빌드 작업실", "city_shop_build", deck)
	var reroll: Button = ui._button(top_actions, "새 진열 · %dCr" % campaign.reroll_cost(), "city_reroll", action.bind("reroll"), int(campaign.s.credits) < campaign.reroll_cost())
	reroll.tooltip_text = "이번 상점에서 3 → 5 → 7 → 9Cr. 다음 상점에서는 3Cr로 돌아옵니다."
	ui._button(top_actions, "맵으로 계속  ›", "city_leave", action.bind("leave"))
	_shop_feedback(workbench)
	(workbench.get_node("%BuildStatus") as Label).text = "%d / %d 장착" % [campaign.equipped_parts().size(), campaign.MAX_EQUIPPED_PARTS]
	(workbench.get_node("%WeaponStatus") as Label).text = "%s · 탄창 %d · 재장전 %d턴" % [Ammo.GUNS[campaign.s.gun].name, ui.model.capacity(), ui.model.reload_cost()]
	(workbench.get_node("%DeckStatus") as Label).text = Insight.deck_summary(ui.model.s.deck)
	(workbench.get_node("%WalletStatus") as Label).text = "%d Cr" % int(campaign.s.credits)
	equipped_strip(workbench.get_node("%EquippedStripHost"))
	var row := workbench.get_node("%ShopOfferGrid") as GridContainer
	row.columns = 3
	for i in range(campaign.s.offers.size()):
		var offer: Dictionary = campaign.s.offers[i]
		var panel = ui._panel(row)
		panel.get_parent().custom_minimum_size.x = 0
		panel.get_parent().name = "ShopOffer_" + str(i)
		var category := "전술 탄환" if offer.type == "ammo" else ("새 장치" if bool(offer.get("new", false)) else "장치")
		ui._label(panel, category, 15, ui.ACCENT)
		if offer.type == "ammo":
			var info: Button = ui._button(panel, "", "city_offer_compare_" + str(i), _show_shop_offer_compare.bind(workbench, offer, i))
			info.custom_minimum_size.y = 166
			info.tooltip_text = "누르면 현재 덱과 비교합니다"
			ammo_card(info, str(offer.id)).custom_minimum_size = Vector2.ZERO
			ui._label(panel, "보유 %d장" % ui.model.s.deck.count(offer.id), 15, ui.MUTED)
		else:
			var info = ui._button(panel, "", "city_part_info_" + str(i), _show_shop_offer_compare.bind(workbench, offer, i))
			info.custom_minimum_size.y = 166
			info.tooltip_text = str(Ammo.PARTS[offer.id].text)
			var visual := part_card(info, str(offer.id), false, campaign.is_equipped(str(offer.id)))
			visual.custom_minimum_size = Vector2.ZERO
			visual.portrait = true
			var penalty := str(Ammo.PARTS[offer.id].downside)
			var destination: Label = ui._label(panel, "▼ " + penalty if not penalty.is_empty() else _offer_destination(str(offer.id)), 15, ui.DANGER if not penalty.is_empty() else ui.ACCENT)
			destination.tooltip_text = _offer_destination(str(offer.id))
		var title := "구매 완료" if offer.sold else "%d Cr" % int(offer.price)
		var price: Label = ui._label(panel, title, 22, ui.MUTED if offer.sold else ui.ACCENT)
		price.name = "ShopPrice_" + str(i)
	(workbench.get_node("%OfferComparePanel") as Control).show()
	var core_done: bool = bool(campaign.s.shop_compressor_bought)
	var core_full: bool = int(campaign.s.compressor_charges) >= campaign.MAX_COMPRESSOR_CHARGES
	var core_caption := "구매 완료" if core_done else ("최대 충전" if core_full else "동일 탄환 두 발을 전투 중 결합")
	var core_button = ui._button(top_actions, "    압축 충전 %d/%d · %dCr" % [campaign.s.compressor_charges, campaign.MAX_COMPRESSOR_CHARGES, campaign.COMPRESSOR_PRICE], "city_buy_compressor", action.bind("buy_compressor"), core_done or core_full or int(campaign.s.credits) < campaign.COMPRESSOR_PRICE)
	core_button.add_theme_font_size_override("font_size", 16)
	core_button.tooltip_text = core_caption + " · 전투 중 사용하고 남은 충전은 다음 전투에도 유지됩니다."
	var glyph := CompressorGlyph.new()
	glyph.name = "ShopCompressorGlyph"
	core_button.add_child(glyph)
	glyph.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	glyph.position = Vector2(5, 8)
	glyph.size = Vector2(50, 36)
	glyph.setup(int(campaign.s.compressor_charges), not core_button.disabled)
	if (workbench.get_node("%ShopHint") as Label).text.is_empty():
		(workbench.get_node("%ShopHint") as Label).text = "파츠는 빈 슬롯에 자동 장착됩니다. 교체는 빌드 작업실에서 할 수 있습니다."
	var current_build: Control = workbench.get_node("%CurrentBuildPanel")
	workbench.move_child(current_build, workbench.get_child_count() - 1)
	(workbench.get_node("%DeckStatus") as Label).hide()
	shop_selection = clampi(shop_selection, 0, maxi(0, campaign.s.offers.size() - 1))
	if not campaign.s.offers.is_empty():
		_show_shop_offer_compare(workbench, campaign.s.offers[shop_selection], shop_selection)


func _shop_feedback(workbench: Control) -> void:
	if campaign.s.log.is_empty(): return
	var event: Dictionary = campaign.s.log.back()
	var event_action := str(event.get("action", ""))
	var detail: Dictionary = event.get("detail", {})
	var message := ""
	match event_action:
		"purchase":
			var id := str(detail.get("id", ""))
			if Ammo.PARTS.has(id): message = str(campaign.s.message)
			elif Ammo.AMMO.has(id): message = "%s 1장 구매 · 탄환 덱에 추가했습니다." % Ammo.AMMO[id].name
		"purchase_compressor": message = str(campaign.s.message)
		"reroll": message = "새 진열 도착 · %dCr 사용 · 다음 교체 %dCr" % [int(detail.get("cost", 3)), campaign.reroll_cost()]
	if message.is_empty(): return
	var label: Label = workbench.get_node("%ShopHint")
	label.text = message
	label.add_theme_color_override("font_color", ui.ACCENT)

func _responsive_columns(wide: int, compact: int) -> int:
	return wide if ui.get_tree().root.size.x >= 1120 else compact

func _show_shop_offer_compare(workbench: Control, offer: Dictionary, offer_index: int) -> void:
	shop_selection = offer_index
	for i in range(campaign.s.offers.size()):
		var frame := workbench.find_child("ShopOffer_" + str(i), true, false) as PanelContainer
		if frame == null: continue
		var style: StyleBoxFlat = ui._style(Color("20333c") if i == offer_index else ui.PANEL)
		style.border_color = ui.ACCENT if i == offer_index else Color("354951")
		style.set_border_width_all(2 if i == offer_index else 1)
		frame.add_theme_stylebox_override("panel", style)
	(workbench.get_node("%OfferComparePanel") as Control).show()
	var title := workbench.get_node("%OfferCompareTitle") as Label
	var body := workbench.get_node("%OfferCompareBody") as Label
	var actions := workbench.get_node("%OfferCompareActions") as Control
	for child in actions.get_children():
		actions.remove_child(child)
		child.queue_free()
	var id := str(offer.id)
	if str(offer.type) == "ammo":
		var before: int = ui.model.s.deck.count(id)
		title.text = "%s · %d발 → %d발" % [Ammo.AMMO[id].name, before, before if bool(offer.sold) else before + 1]
		var ammo: Dictionary = Ammo.AMMO[id]
		var attribute_names := {"physical": "물리", "fire": "화염", "electric": "전기"}
		body.text = "덱 변화  ▲ %s\n현재 성능  피해 %d · 관통 %d · %s" % [Insight.reward_impact(id, ui.model.s, []), Ammo.damage(id, ui.model.s), Ammo.penetration(id, ui.model.s), str(attribute_names.get(str(ammo.attribute), ammo.attribute))]
		var detail: Button = ui._button(actions, "탄환 규칙 보기", "city_offer_detail_" + str(offer_index), func():
			var dialog = ui._dialog(str(Ammo.AMMO[id].name), true)
			ammo_card(dialog, id)
			ui._label(dialog, str(Ammo.AMMO[id].text), 18)
		)
		detail.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		detail.custom_minimum_size = Vector2(180, 44)
	else:
		var part: Dictionary = Ammo.PARTS[id]
		var destination := _offer_destination(id)
		title.text = "%s · %s" % [part.name, destination]
		var lines: PackedStringArray = [BuildGuide.family(id) + " · " + BuildGuide.connection(id, ui.model.s), "▲ " + str(part.upside)]
		if not str(part.downside).is_empty(): lines.append("▼ " + str(part.downside))
		if _purchase_will_equip(id):
			var proposed: Dictionary = ui.model.s.duplicate(true)
			proposed.equipped_parts = campaign.equipped_parts()
			proposed.equipped_parts.append(id)
			var old_capacity: int = ui.model.capacity()
			var new_capacity: int = Ammo.capacity(proposed)
			if old_capacity != new_capacity: lines.append("탄창 %d → %d칸" % [old_capacity, new_capacity])
		body.text = "\n".join(lines)
		var detail: Button = ui._button(actions, "전체 규칙 보기", "city_offer_detail_" + str(offer_index), part_details.bind(id))
		detail.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		detail.custom_minimum_size = Vector2(180, 44)

	var purchase: Button = ui._button(actions, "구매 완료" if bool(offer.sold) else "%dCr · 구매" % int(offer.price), "city_compare_buy_" + str(offer_index), action.bind("buy", offer_index), bool(offer.sold) or int(campaign.s.credits) < int(offer.price) or (str(offer.type) == "ammo" and ui.model.s.deck.size() >= 14))
	if not bool(offer.sold):
		purchase.text = "%dCr 부족" % (int(offer.price) - int(campaign.s.credits)) if int(campaign.s.credits) < int(offer.price) else "%dCr 구매 · 잔액 %d" % [int(offer.price), int(campaign.s.credits) - int(offer.price)]
	ui._primary_button(purchase)
	purchase.custom_minimum_size = Vector2(180, 44)


func _style_shop_workbench(workbench: Control) -> void:
	for path in ["%CurrentBuildPanel", "%OfferComparePanel"]:
		var panel := workbench.get_node(path) as PanelContainer
		panel.add_theme_stylebox_override("panel", ui._style(ui.PANEL))

func equipment(parent: Node, hosts: Dictionary = {}) -> void:
	var panel: Node
	var row: GridContainer
	var unequip_host: Node
	var editable: bool = bool(hosts.get("editable", true))
	var allow_dismantle: bool = bool(hosts.get("allow_dismantle", true))
	var equip_prefix: String = str(hosts.get("equip_prefix", "city_equip_"))
	var unequip_key: String = str(hosts.get("unequip_key", "city_equip_none"))
	var card_min_width: float = float(hosts.get("card_min_width", 430.0))
	var equip_action: Callable = hosts.get("equip_action", func(id): action("equip", id))
	if hosts.is_empty():
		panel = ui._panel(parent)
		ui._label(panel, "장착 파츠 %d / %d · 코어 %d / 1" % [campaign.equipped_parts().size(), campaign.MAX_EQUIPPED_PARTS, campaign.equipped_parts().filter(func(id): return Ammo.is_core_part(str(id))).size()], 20, ui.ACCENT)
		equipped_grid(panel)
		ui._label(panel, "보관함 · 전투 사이 무료 장착/해제", 18, ui.MUTED)
		row = GridContainer.new()
		row.columns = _responsive_columns(2, 1)
		row.add_theme_constant_override("h_separation", 10)
		row.add_theme_constant_override("v_separation", 10)
		panel.add_child(row)
		unequip_host = panel
	else:
		panel = parent
		(hosts.status as Label).text = "파츠 %d / %d · 코어 %d / 1" % [campaign.equipped_parts().size(), campaign.MAX_EQUIPPED_PARTS, campaign.equipped_parts().filter(func(id): return Ammo.is_core_part(str(id))).size()]
		if bool(hosts.get("compact_equipped", false)): equipped_strip(hosts.equipped)
		else: equipped_grid(hosts.equipped)
		row = hosts.inventory as GridContainer
		row.columns = _responsive_columns(2, 1)
		unequip_host = hosts.unequip
	if campaign.s.parts.is_empty():
		var empty = ui._panel(row)
		empty.get_parent().custom_minimum_size.x = 330
		empty.get_parent().size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		part_card(empty, "none", false, true)
	else:
		for id in campaign.s.parts:
			var column = ui._panel(row)
			column.get_parent().custom_minimum_size.x = card_min_width
			var active: bool = bool(campaign.is_equipped(str(id)))
			part_card(column, id, true, active)
			var actions = ui._row(column)
			var caption := "교전 종료 후 교체" if not editable else ("장착 해제" if active else ("장착" if campaign.can_equip(str(id)) else "슬롯/코어 제한"))
			ui._button(actions, caption, equip_prefix + id, equip_action.bind(id), not editable or (not active and not campaign.can_equip(str(id))))
			if allow_dismantle:
				ui._button(actions, "+10Cr", "city_dismantle_" + id, action.bind("dismantle", id), active or not campaign.s.phase in ["shop", "supply"])
	ui._button(unequip_host, "전체 장착 해제", unequip_key, equip_action.bind("none"), not editable or campaign.equipped_parts().is_empty())

func service() -> void:
	var question := "공개된 탄환 한 장을 보급하세요." if campaign.s.phase == "supply" else "얻는 것과 다음 전투의 비용을 함께 확인하세요."
	var service_color: Color = Color("63dce8") if campaign.s.phase == "supply" else ui.DANGER
	var service_marker := "□" if campaign.s.phase == "supply" else "!"
	_phase_intro(service_marker, str(campaign.node().name), question, service_color)
	if campaign.s.resolved:
		ui._label(ui.body, str(campaign.s.message), 24)
		if campaign.s.phase in ["supply", "bypass"]: equipment(ui.body)
		ui._button(ui.body, "맵으로 계속", "city_leave", action.bind("leave"))
		return
	ui._label(ui.body, Data.hint(campaign.node()), 22, ui.MUTED)
	if campaign.s.phase == "supply":
		var row = ui._row(ui.body)
		for id in Data.rewards(campaign.node(), int(campaign.s.seed)):
			var panel = ui._panel(row)
			ammo_card(panel, id)
			ui._button(panel, "1장 보급", "city_supply_" + id, action.bind("resolve", "ammo", id), ui.model.s.deck.size() >= 14)
	else:
		match str(campaign.node().event):
			"siphon": ui._button(ui.body, "+20Cr / 다음 전투 시작 거리 −2m", "city_event_power", action.bind("resolve", "power"))
			"archive":
				ui._button(ui.body, "도시 기록 회수 · 영구 보관", "city_event_lore", action.bind("resolve", "lore"))
				var id: String = Data.rewards(campaign.node(), int(campaign.s.seed))[0]
				var panel = ui._panel(ui.body)
				ammo_card(panel, id)
				ui._button(panel, "대신 탄환 1장 회수", "city_event_ammo", action.bind("resolve", "ammo"), ui.model.s.deck.size() >= 14)
			"salvage": remove_choices("sell", "1장 분해 · +16Cr", "city_sell_")
	ui._button(ui.body, "현재 구성을 유지하고 통과", "city_service_skip", action.bind("resolve", "skip"))

func remove_choices(choice: String, title: String, prefix: String) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	ui.body.add_child(grid)
	var seen: Array = []
	for id in ui.model.s.deck:
		if seen.has(id): continue
		seen.append(id)
		ui._button(grid, "%s\n%s" % [Ammo.AMMO[id].name, title], prefix + id, action.bind("resolve", choice, id), ui.model.s.deck.size() <= 8)
	ui._label(ui.body, "분해 뒤에도 덱 8장을 유지합니다.", 17, ui.MUTED)

func gate() -> void:
	_phase_intro("▲", "계층 관문 통과", "다음 계층까지 유지할 성장 하나를 선택하세요.", Color("ffd86b"))
	ui._label(ui.body, Data.info(int(campaign.s.region) + 1).name + " / " + Data.info(int(campaign.s.region) + 1).brief, 21, ui.MUTED)
	var row = ui._row(ui.body)
	var slot_button = ui._button(row, "", "city_gate_slot", action.bind("gate", "slot"), int(campaign.s.slots) >= 2)
	upgrade_card(slot_button, "slot", {"before": ui.model.capacity(), "after": ui.model.capacity() + 1})
	var compression_button = ui._button(row, "", "city_gate_compress", compression_dialog, campaign.compressible_ids().is_empty())
	upgrade_card(compression_button, "compress")
	var credits_button = ui._button(row, "", "city_gate_credits", action.bind("gate", "credits"))
	upgrade_card(credits_button, "credits", {"amount": 24})

func compression_dialog() -> void:
	var panel = ui._dialog("두 발을 한 발로", true)
	ui._label(panel, "발광 외곽은 압축 상태, 이어진 칸과 양 끝 결합부는 장전 위치를 보여 줍니다.", 18, ui.MUTED)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	panel.add_child(grid)
	for source in campaign.compressible_ids():
		var source_id := str(source)
		var result_id := Ammo.compressed_id(source_id)
		var button = ui._button(grid, "", "city_compress_" + source_id, func():
			panel.get_meta("dialog").hide()
			panel.get_meta("dialog").queue_free()
			action("gate", "compress", source_id)
		)
		button.custom_minimum_size = Vector2(245, 120)
		button.tooltip_text = ui.Readability.description(result_id, ui.model.s)
		var preview := CompressionChoice.new()
		preview.setup(source_id, ui.model.s)
		button.add_child(preview)

func ending() -> void:
	var won: bool = campaign.s.phase == "won"
	_phase_intro("◆" if won else "×", "마지막 승강기에 올랐다." if won else "등반은 여기서 멈췄다.", "버려진 탄환과 부품으로, 당신만의 길을 완성했습니다." if won else "적이 닿기 전에 완성할 순서를 다시 설계해 보세요.", ui.ACCENT if won else ui.DANGER, 180)
	var summary = ui._row(ui.body)
	ui._stat(summary, "▥", "도달", "%d / 35층" % campaign.absolute_floor(), ui.ACCENT)
	ui._stat(summary, "×", "전투", "%d회 통과" % int(campaign.s.clears))
	ui._stat(summary, "⌛", "행동", "%d턴" % int(ui.model.s.turns))
	ui._stat(summary, "›", "발사", "%d발" % int(ui.model.s.shots))
	ui._stat(summary, "↻", "재장전", "%d회" % int(ui.model.s.reloads))
	ui._label(ui.body, Insight.combat_report_line(ui.model.s), 19, ui.ACCENT)
	if not campaign.equipped_parts().is_empty(): equipped_strip(ui.body)
	ui._label(ui.body, str(campaign.s.message), 22)
	if not won:
		var advice = ui._panel(ui.body)
		ui._label(advice, "다음 설계", 20, ui.ACCENT)
		ui._label(advice, Insight.loss_advice(ui.model.s), 18)
	ui._label(ui.body, "최종 덱 / " + Insight.deck_summary(ui.model.s.deck), 19)
	var row = ui._row(ui.body)
	ui._button(row, "같은 경로로 다시 등반", "retry", ui._start.bind(str(campaign.s.gun), true))
	ui._button(row, "기록실", "city_archive", archive)
	ui._button(row, "새 등반 선택", "new_run", ui._to_menu)

func deck(initial_tab: String = "parts") -> void:
	var panel = ui._workspace("빌드 작업실", "파츠를 선택하면 효과와 교체 결과를 확인할 수 있습니다.")
	var view := DeckLoadout.instantiate()
	panel.add_child(view)
	view.tab_changed.connect(ui._workspace_focus_chain.call_deferred)
	for path in ["%SummaryPanel", "%EquipmentPanel", "%InventoryPanel", "%DeckPanel", "%PartInspector"]:
		(view.get_node(path) as PanelContainer).add_theme_stylebox_override("panel", ui._style(ui.PANEL))
	(view.get_node("%DeckSummary") as Label).text = "%s   ·   탄창 %d칸   ·   재장전 %d턴   ·   탄환 %d/14" % [Ammo.GUNS[campaign.s.gun].name, ui.model.capacity(), ui.model.reload_cost(), ui.model.s.deck.size()]
	var feedback: Label = view.get_node("%BuildFeedback")
	feedback.text = workspace_feedback if not workspace_feedback.is_empty() else ("전투 사이에는 무료로 교체할 수 있습니다." if campaign.can_manage_parts() else "전투 중에는 열람만 가능합니다.")
	workspace_feedback = ""
	var equipped: Array = campaign.equipped_parts()
	var cores := 0
	for id in equipped:
		if Ammo.is_core_part(str(id)): cores += 1
	(view.get_node("%LoadoutStatus") as Label).text = "장착 %d/5   ·   코어 %d/1" % [equipped.size(), cores]
	var grid: GridContainer = view.get_node("%EquippedPartGrid")
	for slot in range(campaign.MAX_EQUIPPED_PARTS):
		var id := str(equipped[slot]) if slot < equipped.size() else "none"
		var cell: Button = ui._button(grid, "", "equipped_part_detail_" + str(slot), _inspect_part.bind(view, id), id == "none")
		cell.custom_minimum_size = Vector2(0, 166)
		var card := part_card(cell, id, false, id != "none")
		card.custom_minimum_size = Vector2.ZERO
		card.portrait = true
		card.slot_number = slot + 1
	var inventory: GridContainer = view.get_node("%InventoryGrid")
	var stored := 0
	for id_value in campaign.s.parts:
		var id := str(id_value)
		if equipped.has(id): continue
		stored += 1
		var cell: Button = ui._button(inventory, "", "city_part_select_" + id, _inspect_part.bind(view, id))
		cell.custom_minimum_size = Vector2(0, 72)
		var card := part_card(cell, id, true, false, true)
		card.custom_minimum_size = Vector2.ZERO
	(view.get_node("%InventoryHint") as Label).text = "보관함 · %d개" % stored
	if stored == 0: ui._label(inventory, "상점과 보상에서 새 파츠를 모으세요.", 17, ui.MUTED)
	if selected_part_id.is_empty() or not campaign.s.parts.has(selected_part_id):
		selected_part_id = str(campaign.s.parts[0]) if not campaign.s.parts.is_empty() else "none"
	_inspect_part(view, selected_part_id)
	view.show_tab(initial_tab)
	var ammo_grid: GridContainer = view.get_node("%DeckGrid")
	var seen: Array = []
	for value in ui.model.s.deck:
		var id := str(value)
		if seen.has(id): continue
		seen.append(id)
		var cell = ui._panel(ammo_grid)
		var card := ammo_card(cell, id)
		card.custom_minimum_size = Vector2(0, 154)
		ui._label(cell, "%d장 · 덱의 %d%%" % [ui.model.s.deck.count(id), roundi(float(ui.model.s.deck.count(id)) / float(ui.model.s.deck.size()) * 100.0)], 16, ui.MUTED)

func _inspect_part(view: Control, id: String) -> void:
	if not is_instance_valid(view): return
	selected_part_id = id
	for button in view.find_children("*", "Button", true, false):
		if not str(button.name).begins_with("equipped_part_detail_") and not str(button.name).begins_with("city_part_select_"): continue
		var selected := false
		for child in button.get_children():
			if child is PartCard: selected = str(child.part_id) == id
		var frame: StyleBoxFlat = ui._style(Color("30464d") if selected else Color("17242c"))
		frame.border_color = ui.ACCENT if selected else Color("354b56")
		frame.set_border_width_all(3 if selected else 1)
		button.add_theme_stylebox_override("normal", frame)
	ui._workspace_focus_chain.call_deferred()
	var column: VBoxContainer = view.get_node("%PartDetails")
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	var data: Dictionary = Ammo.PARTS[id]
	var active: bool = campaign.is_equipped(id)
	ui._label(column, "장착 중" if active else ("코어 · 1개만 장착" if Ammo.is_core_part(id) else "보관 파츠"), 16, ui.ACCENT)
	var visual := part_card(column, id, true, active)
	visual.custom_minimum_size = Vector2(0, 96)
	if id == "none":
		ui._label(column, "파츠를 최대 5개 조합해 무기의 성능과 규칙을 바꿉니다.", 20)
		return
	if not campaign.can_manage_parts():
		ui._label(column, str(data.text), 18, ui.INK)
		ui._label(column, "교전이 끝난 뒤 교체할 수 있습니다.", 18, ui.MUTED)
		return
	var proposed: Array = campaign.equipped_parts()
	var outgoing := ""
	if active:
		proposed.erase(id)
	elif campaign.can_equip(id):
		proposed.append(id)
	else:
		var replacements: Array = []
		for candidate in proposed:
			var test := proposed.duplicate()
			test[test.find(candidate)] = id
			if Ammo.valid_part_set(str(campaign.s.gun), test): replacements.append(candidate)
		if replacements.is_empty():
			ui._label(column, "이 구성에는 장착할 수 없습니다.", 18, ui.DANGER)
			return
		if not replacements.has(replacement_part_id): replacement_part_id = str(replacements[0])
		outgoing = replacement_part_id
		ui._label(column, "교체할 장착 파츠", 16, ui.MUTED)
		var choice := OptionButton.new()
		choice.name = "PartReplacement"
		choice.custom_minimum_size.y = 48
		for candidate in replacements:
			choice.add_item(str(Ammo.PARTS[candidate].name))
			choice.set_item_metadata(choice.item_count - 1, candidate)
			if candidate == outgoing: choice.select(choice.item_count - 1)
		choice.item_selected.connect(func(index: int):
			replacement_part_id = str(choice.get_item_metadata(index))
			_inspect_part(view, id)
			var fresh := view.find_child("PartReplacement", true, false) as Control
			if fresh != null: ui._focus_control.call_deferred(fresh)
		)
		column.add_child(choice)
		proposed[proposed.find(outgoing)] = id
	var before: Dictionary = ui.model.s
	var after: Dictionary = before.duplicate(true)
	after.equipped_parts = proposed
	var effects: PackedStringArray = []
	if not active:
		effects.append("얻음  " + str(data.upside))
		if not str(data.downside).is_empty(): effects.append("대가  " + str(data.downside))
	var removed_id := id if active else outgoing
	if not removed_id.is_empty():
		var removed: Dictionary = Ammo.PARTS[removed_id]
		effects.append("잃음  " + str(removed.upside))
		if not str(removed.downside).is_empty(): effects.append("해제  " + str(removed.downside))
	var effect_changes: Label = ui._label(column, "\n".join(effects), 18, ui.INK)
	effect_changes.name = "PartEffectChanges"
	for button in view.find_children("equipped_part_detail_*", "Button", true, false):
		button.modulate = Color.WHITE
		for child in button.get_children():
			if child is PartCard and str(child.part_id) == outgoing:
				var frame: StyleBoxFlat = ui._style(Color("372d2d"))
				frame.border_color = ui.DANGER
				frame.set_border_width_all(2)
				button.add_theme_stylebox_override("normal", frame)
	var projection = ui.model.get_script().new()
	projection.s = after
	var changes: PackedStringArray = []
	if Ammo.capacity(before) != Ammo.capacity(after): changes.append("탄창  %d → %d칸" % [Ammo.capacity(before), Ammo.capacity(after)])
	if ui.model.reload_cost() != projection.reload_cost(): changes.append("재장전  %d → %d턴" % [ui.model.reload_cost(), projection.reload_cost()])
	var delta: Label = ui._label(column, "\n".join(changes) if not changes.is_empty() else "탄창 %d칸 · 재장전 %d턴 유지" % [Ammo.capacity(after), projection.reload_cost()], 19, ui.ACCENT if not changes.is_empty() else ui.MUTED)
	delta.name = "PartChangePreview"
	var command := "replace_part" if not outgoing.is_empty() else "equip"
	var title := "장착 해제" if active else ("교체 장착" if not outgoing.is_empty() else "장착")
	var action_row: HBoxContainer = ui._row(column)
	var apply: Button = ui._button(action_row, title, "city_deck_equip_" + id, _apply_part_change.bind(command, outgoing if not outgoing.is_empty() else id, id))
	ui._primary_button(apply)
	var rules: Button = ui._button(action_row, "규칙", "part_rules", part_details.bind(id))
	rules.custom_minimum_size.x = 70
	rules.size_flags_horizontal = Control.SIZE_SHRINK_END
	if not active and str(campaign.s.phase) in ["shop", "supply"]:
		ui._button(column, "분해 · +10Cr", "city_deck_dismantle_" + id, _confirm_part_dismantle.bind(id)).add_theme_font_size_override("font_size", 17)

func _confirm_part_dismantle(id: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.name = "PartDismantleConfirmation"
	dialog.title = "파츠 분해"
	dialog.dialog_text = "%s을 분해해 10Cr를 받습니다.\n분해한 파츠는 보관함에서 사라집니다." % Ammo.PARTS[id].name
	dialog.ok_button_text = "분해 · +10Cr"
	dialog.cancel_button_text = "보관"
	dialog.confirmed.connect(func():
		dialog.queue_free()
		_apply_part_change("dismantle", id, id)
	)
	dialog.canceled.connect(dialog.queue_free)
	ui.add_child(dialog)
	dialog.popup_centered(Vector2i(550, 240))

func _apply_part_change(command: String, value: String, selected: String) -> void:
	selected_part_id = selected
	ui._close_workspace()
	action(command, value, selected if command == "replace_part" else "")
	workspace_feedback = "구성을 적용했습니다." if command != "dismantle" else "%s 분해 · +10Cr" % Ammo.PARTS[selected].name
	deck.call_deferred("parts")


func archive() -> void:
	var panel = ui._dialog("기록실 · 다음 등반에 남는 것")
	var profile: Dictionary = campaign.profile
	ui._label(panel, "전술 데이터 %d · 완주%d / 등반%d · 최고 난도%d" % [profile.cores, profile.wins, profile.runs, profile.ascension], 24, ui.ACCENT)
	ui._label(panel, "시작 탄환 구성 해금 · 성향을 바꾸며 새 조합을 시도합니다", 20)
	for id in Data.LOADOUTS:
		var owned: bool = profile.unlocks.has(id)
		ui._button(panel, Data.LOADOUTS[id].name + (" · 해금됨" if owned else " · 30데이터"), "city_unlock_" + id, func():
			if campaign.unlock(id):
				ui._persist()
				panel.get_meta("dialog").hide()
				panel.get_meta("dialog").queue_free()
				archive.call_deferred()
		, owned or int(profile.cores) < 30)
	ui._label(panel, "도시 기록 %d / 20 · 발견한 기록만 열람할 수 있습니다" % profile.lore.size(), 24, ui.ACCENT)
	var lore_grid := GridContainer.new()
	lore_grid.columns = 5
	lore_grid.add_theme_constant_override("h_separation", 8)
	lore_grid.add_theme_constant_override("v_separation", 8)
	panel.add_child(lore_grid)
	for id in range(1, 21):
		if profile.lore.has(id):
			var entry := Lore.entry(id)
			ui._button(lore_grid, "%02d\n%s" % [id, entry.title], "city_lore_" + str(id), func():
				var detail = ui._dialog("도시 기록 %02d" % id, true)
				ui._label(detail, entry.title, 25, ui.ACCENT)
				ui._label(detail, entry.text, 19)
			)
		else:
			ui._button(lore_grid, "%02d\n미복원" % id, "city_lore_locked_" + str(id), func(): pass, true)
