extends RefCounted
const Data = preload("res://redesign/campaign_content.gd")
const Ammo = preload("res://redesign/content.gd")
const MapView = preload("res://redesign/city_map_view.gd")
const Card = preload("res://redesign/ammo_card_view.gd")
const PartCard = preload("res://redesign/part_card_view.gd")
const UpgradeChoice = preload("res://redesign/upgrade_choice_view.gd")
const CompressionChoice = preload("res://redesign/compression_choice_view.gd")
const Insight = preload("res://redesign/run_insight.gd")
const Lore = preload("res://scripts/core/lore_catalog.gd")
var ui
var campaign

func render(screen) -> void:
	ui = screen
	campaign = ui.campaign
	var state: Dictionary = campaign.s
	var top = ui._row(ui.body)
	ui._label(top, "%s   /   %02d · 35" % [Data.info(int(state.region)).name, campaign.absolute_floor()], 26, ui.ACCENT)
	for entry in [["덱·장비", "city_deck", deck], ["기록실", "city_archive", archive], ["설정", "settings", ui._settings], ["메뉴", "menu", ui._to_menu]]:
		var button = ui._button(top, entry[0], entry[1], entry[2])
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		button.custom_minimum_size.x = 100
	var stats := HFlowContainer.new()
	stats.name = "RunStatusBar"
	stats.add_theme_constant_override("h_separation", 8)
	stats.add_theme_constant_override("v_separation", 8)
	ui.body.add_child(stats)
	ui._stat(stats, "▥", "고도", "LV.%d" % (int(Data.info(int(state.region)).base_level) + maxi(1, int(state.floor)) - 1))
	ui._stat(stats, "●", "크레딧", "%d Cr" % int(state.credits), ui.ACCENT)
	ui._stat(stats, "◆", "압축 코어", "%d / %d" % [state.compressor_charges, campaign.MAX_COMPRESSOR_CHARGES], Color("63dce8"))
	ui._stat(stats, "⌁", "무기", "%s · %d칸" % [Ammo.GUNS[state.gun].name, ui.model.capacity()])
	ui._stat(stats, "▤", "전술 덱", "%d / 14장" % ui.model.s.deck.size())
	ui._stat(stats, "▲", "난도", "%d%s" % [state.difficulty, " · 거리−2m" if int(state.pressure) > 0 else ""], ui.DANGER if int(state.pressure) > 0 else ui.INK)
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

func ammo_card(parent: Node, id: String) -> void:
	var view := Card.new()
	view.custom_minimum_size = Vector2(230, 104)
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view.setup(id, 1, ui.model.s)
	parent.add_child(view)

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
	ui._label(panel, ("현재 적용 · " if campaign.is_equipped(id) else "장착 시 · ") + Insight.reward_impact(id, ui.model.s, []), 17, ui.ACCENT)

func equipped_grid(parent: Node) -> void:
	var grid := GridContainer.new()
	grid.name = "EquippedPartGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	var equipped: Array = campaign.equipped_parts()
	for slot in range(campaign.MAX_EQUIPPED_PARTS):
		var cell = ui._panel(grid)
		cell.get_parent().custom_minimum_size.x = 300
		var id := str(equipped[slot]) if slot < equipped.size() else "none"
		ui._label(cell, "%02d%s" % [slot + 1, " · CORE" if Ammo.is_core_part(id) else ""], 14, Color("ffd86b") if Ammo.is_core_part(id) else ui.MUTED)
		part_card(cell, id, true, id != "none")

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
	ui._screen_intro("다음 1칸", "목적지와 이동 비용을 비교하세요.")
	var map := MapView.new()
	map.name = "CityMap"
	map.setup(campaign)
	map.entered.connect(func(id): action("enter", id))
	map.inspected.connect(inspect_node)
	ui.body.add_child(map)
	var row = ui._row(ui.body)
	for item in campaign.choices():
		var panel = ui._panel(row)
		ui._button(panel, "%s / %s\n%s" % [item.name, Data.kind_name(str(item.kind)), "계단 · 무료" if item.route == "stairs" else "환기구 · 다음 전투 −2m"], "city_enter_" + str(item.id), action.bind("enter", int(item.id)))
		ui._label(panel, Data.hint(item), 17, ui.MUTED)
	ui._hint(ui.body, "밝은 방은 지금 이동할 수 있습니다. 다른 방을 누르면 이후 시설과 적 편성을 미리 볼 수 있습니다.")

func inspect_node(id: int) -> void:
	var item: Dictionary = {}
	for candidate in campaign.current_nodes():
		if int(candidate.id) == id: item = candidate
	if item.is_empty(): return
	var panel = ui._dialog(str(item.name), true)
	ui._label(panel, Data.hint(item), 22)
	ui._label(panel, "\uacc4\ub2e8 \u00b7 \ubb34\ub8cc" if item.route == "stairs" else "\ud658\uae30\uad6c \u00b7 \ub2e4\uc74c \uc804\ud22c \uc2dc\uc791 \uac70\ub9ac -2m", 18, ui.ACCENT)
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
	ui._screen_intro(str(campaign.node().name) + " 통과", "덱을 강화할지, 다음 구매를 위해 크레딧을 모을지 선택하세요.")
	ui._label(ui.body, Insight.combat_report_line(campaign.encounter_report_state()), 19, ui.MUTED)
	var row = ui._row(ui.body)
	for id in Data.rewards(campaign.node(), int(campaign.s.seed)):
		var panel = ui._panel(row)
		ammo_card(panel, id)
		ui._label(panel, "현재 %d장 → 선택 후 %d장" % [ui.model.s.deck.count(id), ui.model.s.deck.count(id) + 1], 16, ui.MUTED)
		ui._label(panel, "영향 · " + Insight.reward_impact(id, ui.model.s, []), 17, ui.ACCENT)
		ui._button(panel, "1장 가져가기", "city_reward_" + id, action.bind("reward", id), ui.model.s.deck.size() >= 14)
	var wallet = ui._panel(row)
	ui._label(wallet, "+%d Cr" % campaign.credit_reward(), 42, ui.ACCENT)
	ui._label(wallet, "전투 소모가 적을수록 배급 증가\n상점 탄환 12Cr / 파츠 30Cr", 18, ui.MUTED)
	ui._button(wallet, "크레딧 받기", "city_reward_credits", action.bind("reward", "credits"))
	ui._button(ui.body, "현재 구성을 유지하고 계속", "city_reward_skip", action.bind("reward", "skip"))

func shop() -> void:
	ui._screen_intro(str(campaign.node().name), "파츠는 최대 5개가 동시에 작동합니다. 금색 코어는 하나만 장착할 수 있습니다.")
	var top_actions = ui._row(ui.body)
	ui._button(top_actions, "새 진열 · 3Cr", "city_reroll", action.bind("reroll"), int(campaign.s.credits) < 3)
	ui._button(top_actions, "맵으로 계속", "city_leave", action.bind("leave"))
	var build_panel = ui._panel(ui.body)
	build_panel.name = "CurrentBuildStrip"
	var build_row = ui._row(build_panel)
	ui._label(build_row, "현재 빌드 · %d / %d 장착\n%s · 탄창 %d칸 · 재장전 %d턴" % [campaign.equipped_parts().size(), campaign.MAX_EQUIPPED_PARTS, Ammo.GUNS[campaign.s.gun].name, ui.model.capacity(), ui.model.reload_cost()], 18, ui.ACCENT)
	ui._label(build_row, Insight.deck_summary(ui.model.s.deck), 16, ui.MUTED)
	equipped_strip(build_panel)
	var row := GridContainer.new()
	row.name = "ShopOfferGrid"
	row.columns = 3
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	ui.body.add_child(row)
	for i in range(campaign.s.offers.size()):
		var offer: Dictionary = campaign.s.offers[i]
		var panel = ui._panel(row)
		panel.get_parent().custom_minimum_size.x = 300
		ui._label(panel, "전술 탄환" if offer.type == "ammo" else ("새 파츠" if bool(offer.get("new", false)) else "파츠 모듈"), 16, ui.ACCENT)
		if offer.type == "ammo":
			ammo_card(panel, str(offer.id))
			ui._label(panel, "보유 %d장 · %s" % [ui.model.s.deck.count(offer.id), Insight.reward_impact(str(offer.id), ui.model.s, [])], 15, ui.MUTED)
		else:
			var info = ui._button(panel, "", "city_part_info_" + str(i), part_details.bind(str(offer.id)))
			info.custom_minimum_size.y = 102
			info.tooltip_text = str(Ammo.PARTS[offer.id].text)
			part_card(info, str(offer.id), true, campaign.is_equipped(str(offer.id)))
			ui._label(panel, ("장착 가능 · " if campaign.can_equip(str(offer.id)) else "보관함 이동 · ") + Insight.reward_impact(str(offer.id), ui.model.s, []), 15, ui.MUTED)
		var title := "구매 완료" if offer.sold else "%dCr · %s" % [offer.price, "구매" if offer.type == "part" else "덱에 추가"]
		ui._button(panel, title, "city_buy_" + str(i), action.bind("buy", i), offer.sold or int(campaign.s.credits) < int(offer.price) or (offer.type == "ammo" and ui.model.s.deck.size() >= 14))
	var core_done: bool = bool(campaign.s.shop_compressor_bought)
	var core_full: bool = int(campaign.s.compressor_charges) >= campaign.MAX_COMPRESSOR_CHARGES
	var core_caption := "구매 완료" if core_done else ("최대 충전" if core_full else "동일 탄환 두 발을 전투 중 결합")
	var utility_row = ui._row(ui.body)
	var core_button = ui._button(utility_row, "", "city_buy_compressor", action.bind("buy_compressor"), core_done or core_full or int(campaign.s.credits) < campaign.COMPRESSOR_PRICE)
	core_button.custom_minimum_size.x = 430
	upgrade_card(core_button, "core", {"count": campaign.s.compressor_charges, "max": campaign.MAX_COMPRESSOR_CHARGES, "caption": core_caption, "price": "%dCr · 충전" % campaign.COMPRESSOR_PRICE})
	var shop_actions = ui._panel(utility_row)
	ui._label(shop_actions, "압축 코어는 전투 중 같은 탄환 두 발을 한 번 결합합니다.", 16, ui.MUTED)
	ui._hint(ui.body, "크레딧이 허용하면 파츠를 모두 구매할 수 있습니다. 빈 슬롯이 없거나 코어가 중복되면 보관함으로 이동합니다.")
	equipment(ui.body)

func equipment(parent: Node) -> void:
	var panel = ui._panel(parent)
	ui._label(panel, "장착 파츠 %d / %d · 코어 %d / 1" % [campaign.equipped_parts().size(), campaign.MAX_EQUIPPED_PARTS, campaign.equipped_parts().filter(func(id): return Ammo.is_core_part(str(id))).size()], 20, ui.ACCENT)
	equipped_grid(panel)
	ui._label(panel, "보관함 · 전투 사이 무료 장착/해제", 18, ui.MUTED)
	var row := GridContainer.new()
	row.columns = 2
	row.add_theme_constant_override("h_separation", 10)
	row.add_theme_constant_override("v_separation", 10)
	panel.add_child(row)
	if campaign.s.parts.is_empty():
		var empty = ui._panel(row)
		empty.get_parent().custom_minimum_size.x = 330
		empty.get_parent().size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		part_card(empty, "none", false, true)
	else:
		for id in campaign.s.parts:
			var column = ui._panel(row)
			column.get_parent().custom_minimum_size.x = 430
			var active: bool = bool(campaign.is_equipped(str(id)))
			part_card(column, id, true, active)
			var actions = ui._row(column)
			ui._button(actions, "장착 해제" if active else ("장착" if campaign.can_equip(str(id)) else "슬롯/코어 제한"), "city_equip_" + id, action.bind("equip", id), not active and not campaign.can_equip(str(id)))
			ui._button(actions, "+10Cr", "city_dismantle_" + id, action.bind("dismantle", id), active or not campaign.s.phase in ["shop", "supply"])
		ui._button(panel, "전체 장착 해제", "city_equip_none", action.bind("equip", "none"), campaign.equipped_parts().is_empty())

func service() -> void:
	var question := "공개된 탄환 한 장을 보급하세요." if campaign.s.phase == "supply" else "얻는 것과 다음 전투의 비용을 함께 확인하세요."
	ui._screen_intro(str(campaign.node().name), question)
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
	ui._screen_intro("계층 관문 통과", "다음 계층까지 유지할 성장 하나를 선택하세요.")
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
	ui._label(ui.body, "당신은 아직 인간이다." if won else "등반은 여기서 멈췄다.", 44, ui.ACCENT if won else ui.DANGER)
	ui._label(ui.body, "정점은 개조를 권한다. 당신은 거부하고, 그 자리에 선다." if won else "적이 닿기 전에 완성할 순서를 다시 설계해 보세요.", 23)
	var summary = ui._row(ui.body)
	ui._stat(summary, "▥", "도달", "%d / 35층" % campaign.absolute_floor(), ui.ACCENT)
	ui._stat(summary, "×", "전투", "%d회 통과" % int(campaign.s.clears))
	ui._stat(summary, "⌛", "행동", "%d턴" % int(ui.model.s.turns))
	ui._stat(summary, "›", "발사", "%d발" % int(ui.model.s.shots))
	ui._stat(summary, "↻", "재장전", "%d회" % int(ui.model.s.reloads))
	ui._label(ui.body, Insight.combat_report_line(ui.model.s), 19, ui.ACCENT)
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

func deck() -> void:
	var panel = ui._dialog("덱·장비")
	ui._label(panel, "덱 %d / 14장 · 탄창 %d칸 · 재장전 %d턴 · 압축 코어 %d/%d" % [ui.model.s.deck.size(), ui.model.capacity(), ui.model.reload_cost(), campaign.s.compressor_charges, campaign.MAX_COMPRESSOR_CHARGES], 24, ui.ACCENT)
	var equipment_panel = ui._panel(panel)
	var parts_editable: bool = bool(campaign.can_manage_parts())
	ui._label(equipment_panel, "현재 장착 %d / %d · %s" % [campaign.equipped_parts().size(), campaign.MAX_EQUIPPED_PARTS, "전투 사이 무료 교체" if parts_editable else "교전 종료 후 교체"], 19, ui.ACCENT)
	equipped_strip(equipment_panel)
	if not campaign.s.parts.is_empty():
		ui._label(equipment_panel, "보유 파츠 · 장착 버튼으로 5칸을 교체", 17, ui.MUTED)
		var stored_grid := GridContainer.new()
		stored_grid.columns = 2
		stored_grid.add_theme_constant_override("h_separation", 8)
		stored_grid.add_theme_constant_override("v_separation", 8)
		equipment_panel.add_child(stored_grid)
		for id in campaign.s.parts:
			var stored = ui._panel(stored_grid)
			stored.get_parent().custom_minimum_size.x = 360
			var active: bool = bool(campaign.is_equipped(str(id)))
			part_card(stored, id, true, active)
			var caption := "교전 종료 후 교체" if not parts_editable else ("장착 해제" if active else ("장착" if campaign.can_equip(str(id)) else "슬롯/코어 제한"))
			ui._button(stored, caption, "city_deck_equip_" + id, action.bind("equip", id), not parts_editable or (not active and not campaign.can_equip(str(id))))
	ui._label(panel, "전술 덱 구성", 22, ui.ACCENT)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	panel.add_child(grid)
	var seen: Array = []
	for id_value in ui.model.s.deck:
		var id := str(id_value)
		if seen.has(id): continue
		seen.append(id)
		var card_panel = ui._panel(grid)
		ammo_card(card_panel, id)
		ui._label(card_panel, "보유 %d장 · 덱의 %d%%" % [ui.model.s.deck.count(id), roundi(float(ui.model.s.deck.count(id)) / float(ui.model.s.deck.size()) * 100.0)], 16, ui.MUTED)

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
