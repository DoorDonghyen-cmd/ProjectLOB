extends RefCounted
const Data = preload("res://redesign/campaign_content.gd")
const Ammo = preload("res://redesign/content.gd")
const ChartView = preload("res://redesign/city_map_chart_view.gd")
const ChartSymbols = preload("res://redesign/map_chart_symbols.gd")
const PipeMapScreen = preload("res://redesign/pipe_map/screen.tscn")
const Card = preload("res://redesign/ammo_card_view.gd")
const COLLECTION_CARD_SIZE := Vector2(230, 164)
const OFFER_CARD_SIZE := Vector2(230, 196)
const AmmoOffer = preload("res://redesign/ammo_offer.tscn")
const FocusOffer = preload("res://redesign/focus_ammo_offer.tscn")
const AcquisitionView = preload("res://redesign/ammo_acquisition_view.tscn")
const PartCard = preload("res://redesign/part_card_view.gd")
const BuildGuide = preload("res://redesign/build_guide.gd")
const UpgradeChoice = preload("res://redesign/upgrade_choice_view.gd")
const CompressionChoice = preload("res://redesign/compression_choice_view.gd")
const ShopOffer = preload("res://redesign/shop_offer.tscn")
const PartChoice=preload("res://redesign/part_choice.gd")
const PartInspection = preload("res://redesign/part_inspector.tscn")
const ShopWorkbench = preload("res://redesign/shop_workbench.tscn")
const ShopScreen = preload("res://redesign/shop_screen.tscn")
const TerminalShopScreen = preload("res://redesign/shop_terminal_live.tscn")
const DeckLoadout = preload("res://redesign/deck_loadout.tscn")
const GateScreen = preload("res://redesign/samples/gate_review/threshold_preview.tscn")
const DepotScreen = preload("res://redesign/samples/supply_review/preview.tscn")
const EventScreen = preload("res://redesign/samples/event_review/preview.tscn")
const BuildWorkshop = preload("res://redesign/build/workshop.gd")
const Insight = preload("res://redesign/run_insight.gd")
const Lore = preload("res://redesign/city_story.gd")
const ArchiveRoom = preload("res://redesign/common/archive.gd")
const CompressorGlyph = preload("res://redesign/field_compressor_view.gd")
const ServicePlaces := {
	"shop": preload("res://redesign/location_shop.tscn"),
	"supply": preload("res://redesign/location_supply.tscn"),
	"workshop": preload("res://redesign/location_workshop.tscn")
}
const SceneBanner = preload("res://redesign/scene_banner.gd")
const ResultsScreen = preload("res://redesign/results/screen.tscn")
const RewardScreen = preload("res://redesign/rewards/campaign_screen.tscn")
const StoryUI = preload("res://redesign/story_ui.gd")
var ui
var campaign
var workspace_feedback := ""
var selected_part_id := ""
var replacement_part_id := ""
var shop_selection := 0
var results_for_campaign = null
var results_details_open := false
var place_body: VBoxContainer
var map_memory: Dictionary = {}
var workbench_memory: Dictionary = {}

func render(screen) -> void:
	ui = screen
	place_body = null
	campaign = ui.campaign
	var state: Dictionary = campaign.s
	if campaign.departure_pending():
		StoryUI.departure(ui)
		return
	if campaign.restoration_pending():
		StoryUI.restoration(ui)
		return
	if state.phase == "won" and results_for_campaign != campaign:
		StoryUI.homecoming(ui, _show_results)
		return
	if state.phase in ["won", "lost"]:
		ending()
		return
	if state.phase == "shop":
		shop()
		return
	if state.phase == "map":
		map_screen()
		return
	if state.phase == "reward" and campaign.modern_places():
		var screen_view := RewardScreen.instantiate()
		screen_view.configure(ui)
		ui.body.add_child(screen_view)
		return
	if state.phase == "supply" and campaign.modern_places() and campaign.node().get("workshop", false):
		modern_workshop()
		return
	if state.phase == "gate" and campaign.modern_gates():
		modern_gate()
		return
	if state.phase == "supply" and campaign.modern_places() and not campaign.node().get("workshop", false):
		modern_depot()
		return
	if state.phase == "event" and campaign.modern_places():
		modern_event()
		return
	_run_shell(state)
	if ui.debug_session: ui._label(ui.body, "개발자 연습 · 실제 진행 저장 보존", 18, ui.DANGER)
	if not ui.save_error.is_empty(): ui._label(ui.body, ui.save_error, 18, ui.DANGER)
	match str(state.phase):
		"map": map_screen()
		"shop": shop()
		"reward": reward()
		"supply", "event", "bypass": service()
		"gate": gate()

func action(name: String, value: Variant = "", extra: String = "", replacement: String = "") -> void:
	ui._campaign_action(name, value, extra, replacement)

func _show_results() -> void:
	results_details_open = false
	results_for_campaign = campaign
	ui.redraw()

func shows_results(run) -> bool:
	return run.s.phase == "lost" or (run.s.phase == "won" and results_for_campaign == run and not run.restoration_pending())

func close_results_details() -> bool:
	if not results_details_open:
		return false
	var view = ui.body.get_node_or_null("CampaignResults")
	if view == null:
		return false
	view.set_details(false)
	return true

func _run_shell(state: Dictionary) -> void:
	var shell := PanelContainer.new()
	shell.name = "CampaignShellHeader"
	var shell_style: StyleBoxTexture = ui._console_style("panel")
	shell_style.content_margin_top = 8
	shell_style.content_margin_bottom = 8
	shell.add_theme_stylebox_override("panel", shell_style)
	ui.body.add_child(shell)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	shell.add_child(column)
	var top: HBoxContainer = ui._row(column)
	var location: Label = ui._label(top, str(campaign.region_info().name), 23, ui.ACCENT)
	location.name = "RunLocation"
	location.autowrap_mode = TextServer.AUTOWRAP_OFF
	for entry in [["빌드", "city_deck", deck], ["기록", "city_archive", archive], ["설정", "settings", ui._settings], ["메뉴", "menu", ui._to_menu]]:
		var button: Button = ui._button(top, entry[0], entry[1], entry[2])
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		button.custom_minimum_size = Vector2(78, 40)
		button.autowrap_mode = TextServer.AUTOWRAP_OFF
		button.add_theme_font_size_override("font_size", ui._font_scaled(17))
	var stats := HFlowContainer.new()
	stats.name = "RunStatusBar"
	stats.add_theme_constant_override("h_separation", 20)
	stats.add_theme_constant_override("v_separation", 4)
	column.add_child(stats)
	_shell_metric(stats, "● %d Cr" % int(state.credits), ui.ACCENT)
	if not campaign.magazine_enabled(): _shell_metric(stats, "◆ %d/%d" % [state.compressor_charges, campaign.MAX_COMPRESSOR_CHARGES], Color("5cdddc"))
	_shell_metric(stats, "⌁ %s · %d칸" % [Ammo.GUNS[state.gun].name, ui.model.capacity()], ui.INK)
	_shell_metric(stats, "▤ %d/%d" % [ui.model.s.deck.size(), ui.model.deck_limit()], ui.INK)
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
	var style: StyleBoxFlat = ui._style(Color("04181e"))
	style.set_content_margin_all(0)
	style.border_color = color.darkened(0.25)
	style.border_width_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	ui.body.add_child(panel)
	var layer := Control.new()
	panel.add_child(layer)
	# The map already has a continuous environment; another cropped picture in
	# its heading competes with the shaft and breaks the sense of one space.
	if campaign.s.phase != "map":
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
	view.custom_minimum_size = COLLECTION_CARD_SIZE
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	view.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
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

## Part details (2026-11-08): common window, opened from the build workshop, rewards and
## the shop terminal. Same content as before.
func part_details(id: String) -> void:
	var panel: VBoxContainer = ui.CommonWindows.open(ui, str(Ammo.PARTS[id].name), Ammo.part_grade_summary(id), Vector2(780, 600))
	panel.name = "PartDetails"
	panel.get_meta("dialog").get_node("%Subtitle").add_theme_color_override("font_color", Ammo.part_grade_color(id))
	# The part's pixel icon (as on the mount) beside its effect, instead of the old teal card.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	panel.add_child(top)
	var plate := PanelContainer.new()
	plate.theme_type_variation = &"Inspector"
	top.add_child(plate)
	var icon := preload("res://redesign/results/core_icon.gd").new()
	icon.name = "PartDetailIcon"
	icon.part_id = id
	icon.custom_minimum_size = Vector2(96, 72)
	plate.add_child(icon)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(copy)
	ui.CommonWindows.text(copy, ("장착 중" if campaign.is_equipped(id) else "보관 중") if campaign.s.parts.has(id) else "미보유", &"Caption")
	ui.CommonWindows.text(copy, "장착 효과 · " + Insight.reward_impact(id, ui.model.s, []), &"", ui.CommonWindows.IVORY)
	ui.CommonWindows.text(copy, BuildGuide.connection(id, ui.model.s), &"", ui.CommonWindows.GOLD)
	ui.CommonWindows.text(panel, str(Ammo.part_spec(id,ui.model.s).text), &"", ui.CommonWindows.MUTED)
	ui.CommonWindows.text(panel, "등급 막대 1 / 2 / 3개: 일반 / 고급 / 희귀 · 코어는 별도 장착 제한", &"Caption")

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
		ui._label(cell, "%02d%s" % [slot + 1, " · CORE" if Ammo.is_core_part(id) else ""], 12, Color("f3cf73") if Ammo.is_core_part(id) else ui.MUTED)
		part_card(cell, id, true, id != "none", true)

func upgrade_card(button: Button, kind: String, values: Dictionary = {}) -> void:
	button.custom_minimum_size.y = 118
	var view := UpgradeChoice.new()
	view.name = "UpgradeChoice_" + kind
	view.setup(kind, values)
	button.add_child(view)

func map_screen() -> void:
	var map := PipeMapScreen.instantiate()
	ui.body.add_child(map)
	map.bind(ui, self)

func inspect_node(id: int) -> void:
	var item: Dictionary = {}
	for candidate in campaign.current_nodes():
		if int(candidate.id) == id: item = candidate
	if item.is_empty(): return
	var panel = ui._workspace(str(item.name), "경로 상세 · 닫으면 지도로 돌아갑니다.")
	ui._label(panel, Data.hint(item), 22)
	if campaign.is_shortcut(id): ui._label(panel, "일반 전투 한 곳을 건너뜁니다. 그 전투의 보상과 코어 성장은 얻지 않습니다.", 18, ui.MUTED)
	ui._label(panel, "\uacc4\ub2e8 \u00b7 \ubb34\ub8cc" if item.route == "stairs" else "\ud658\uae30\uad6c \u00b7 \ub2e4\uc74c \uc804\ud22c \uc2dc\uc791 \uac70\ub9ac -2m", 18, ui.ACCENT)
	if item.route == "duct" and item.kind in ["combat", "boss"]: ui._label(panel, "크레딧 보상 +%dCr" % Data.ROUTE_REWARD_BONUS, 19, ui.ACCENT)
	if item.kind in ["combat", "boss"]:
		var pack := Data.encounter_pack(item, int(campaign.s.seed), str(campaign.s.gun), int(campaign.s.difficulty), 2 if item.route == "duct" or (campaign.choices().any(func(n): return int(n.id) == id) and int(campaign.s.pressure) > 0) else 0, int(campaign.s.get("roster_version", 1)), int(campaign.s.get("combat_revision",0)))
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
			ui._label(panel, "\ub300\uae30  " + "  >  ".join(reserve_names), 16, Color("5cdddc"))
		var lesson := Data.lesson(item, ui.model.s)
		if not lesson.is_empty(): ui._label(panel, lesson, 18, ui.MUTED)
	elif item.kind == "shop":
		ui._label(panel, "일반 12Cr · 고급 24Cr · 파츠 30Cr", 19)
		ui._label(panel, "진열 교체 3 → 5 → 7 → 9Cr", 17, ui.MUTED)
	ui._label(panel, campaign.route_outlook(id), 18, ui.MUTED)
func reward() -> void:
	var first_ammo: bool = campaign.first_ammo_reward()
	var focus: bool = campaign.Model.FocusBuild.enabled(campaign.s)
	var package_choice: bool = focus and first_ammo
	var boss_loot: bool = campaign.boss_loot()
	var opening: bool = int(campaign.s.get("discovery_version",0)) >= 3 and campaign.engine_reward()
	_phase_intro("◆", "주력 탄 선택 · 2/2" if package_choice else "첫 특수탄 선택 · 2/2" if first_ammo else ("성장 코어 선택 · 1/2" if opening else str(campaign.node().name) + " 통과"), "키울 주력 탄과 함께 쓸 지원 탄을 고르세요." if package_choice else "원하는 한 장을 골라 기본탄과 교체하거나 추가하세요." if first_ammo else ("코어를 고른 다음 첫 특수탄을 선택합니다." if opening else ("이번 등반의 화력 성장 방식을 고르세요." if campaign.engine_reward() else "전투 결과를 하나의 다음 선택으로 바꾸세요.")), Color("f3cf73"))
	if package_choice:
		ui._label(ui.body, "주력 2장 + 지원 1장 · 위력이 낮은 기본탄 3장과 교체 · 총 탄약 유지", 18, ui.ACCENT)
	var reward_frame := VBoxContainer.new()
	reward_frame.name = "RewardFrame"
	reward_frame.add_theme_constant_override("separation",14)
	ui.body.add_child(reward_frame)
	if boss_loot:
		var loot_header := HBoxContainer.new()
		loot_header.add_theme_constant_override("separation",12)
		reward_frame.add_child(loot_header)
		var receipt: Label = ui._label(loot_header,"보스 전리품 · +%d Cr 수령 완료" % campaign.boss_credits(),24,ui.ACCENT)
		receipt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var continue_button: Button = ui._button(loot_header,"탄환 없이 관문 개조로" if int(campaign.s.region)<4 else "정상으로 이동","city_reward_skip",action.bind("reward","skip"))
		continue_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		continue_button.custom_minimum_size.x = 260
		ui._label(reward_frame,"고급탄 포함 · 탄환 하나를 선택한 뒤 관문 개조로 이동합니다." if int(campaign.s.region)<4 else "마지막 전리품 · 선택 후 정상으로 이동합니다.",18,ui.MUTED)
	if campaign.s.get("encounter", {}).get("stage", "") == "cleared":
		ui._label(reward_frame, str(campaign.s.message) + " · 별도 보상 수령 완료", 20, ui.ACCENT)
	if not first_ammo: ui._encounter_debrief(reward_frame, campaign.encounter_report_state(),boss_loot)
	var row := GridContainer.new()
	row.name = "RewardGrid"
	row.columns = 3
	if focus and ui.get_tree().root.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED:
		row.columns = clampi(int((ui.get_tree().root.size.x - 56) / (297 if campaign.engine_reward() or not campaign.part_rewards().is_empty() else 242)),1,3)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 12)
	reward_frame.add_child(row)
	for id in campaign.reward_options():
		var package_panel: VBoxContainer = FocusOffer.instantiate() if package_choice else null
		var take: Button = package_panel.get_node("Offer") if package_choice else AmmoOffer.instantiate()
		take.name = "city_reward_" + id
		take.disabled = (campaign.Model.FocusBuild.replace_opening(ui.model.s.deck,id).is_empty() if package_choice else not can_take_ammo(id)) or ui.busy
		take.custom_minimum_size = OFFER_CARD_SIZE
		take.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		take.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var face: Control = take.get_node("CardInfo")
		var ownership := "새 탄종" if Insight.family_count(ui.model.s,Ammo.source_id(id))==0 else "동일 성능 %d장 보유" % ui.model.s.deck.count(id)
		if focus: ownership = "주력 탄 2장" if package_choice else campaign.Model.FocusBuild.offer_label(ui.model.s,id)
		face.setup(id,2 if package_choice else 1,ui.model.s,take.disabled,false,ownership)
		take.pressed.connect(func(): ui.feedback.play("click"))
		if package_choice:
			take.tooltip_text = campaign.Model.FocusBuild.package_text(id) + " · 기본탄 3장 교체"
			take.pressed.connect(action.bind("reward",id))
			row.add_child(package_panel)
			package_panel.get_node("Package").text = campaign.Model.FocusBuild.package_text(id)
		else:
			take.pressed.connect(acquire_ammo.bind(id,"reward",id))
			row.add_child(take)
	for id in campaign.part_rewards():
		var panel = ui._panel(row)
		panel.get_parent().custom_minimum_size.x = 285
		part_card(panel, id, false, false)
		if preload("res://redesign/damage_engines.gd").IDS.has(id):
			var summary: Dictionary = {
				"volley_drive":"남은 타격으로 다음 적 공격",
				"thermal_drive":"고열 배율 · 열 한계 도달 시 충격파",
				"siege_drive":"한 발의 초과 피해를 다음 적에게"
			}
			ui._label(panel, summary[id], 18, ui.INK)
			ui._label(panel, preload("res://redesign/damage_engines.gd").growth_rule(ui.model.s,id), 16, ui.MUTED)
			var spacer := Control.new()
			spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
			panel.add_child(spacer)
			var actions := HBoxContainer.new()
			actions.add_theme_constant_override("separation",8)
			panel.add_child(actions)
			var info: Button = ui._button(actions,"상세","city_core_detail_"+id,part_details.bind(id))
			info.autowrap_mode = TextServer.AUTOWRAP_OFF
			info.add_theme_font_size_override("font_size",ui._font_scaled(17))
			info.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			info.custom_minimum_size.x = 88
			ui._primary_button(ui._button(actions,"이 코어 선택","city_reward_"+id,action.bind("reward",id)))
			continue
		ui._label(panel, str(Ammo.part_spec(id,ui.model.s).text), 17, ui.MUTED)
		ui._label(panel, ("성장 코어 · 1개 선택\n" if campaign.engine_reward() else "정예 보상 · 파츠 1개\n") + ("빈 슬롯에 자동 장착" if campaign.can_equip_reward(id) else "획득 후 보관함에서 교체"), 17, ui.MUTED)
		ui._primary_button(ui._button(panel, "파츠 가져가기", "city_reward_" + id, action.bind("reward", id)), Color("f3cf73"))
	if campaign.engine_reward() or first_ammo:
		ui._label(reward_frame,"한 묶음 선택 · 다음 전투부터 사용" if package_choice else "한 장 선택 · 다음 전투부터 사용" if first_ammo else "한 개 선택 · 이번 등반에 유지 · 코어는 동시에 하나만 장착",16,ui.MUTED)
		var alternatives := HBoxContainer.new()
		alternatives.alignment = BoxContainer.ALIGNMENT_END
		reward_frame.add_child(alternatives)
		for choice in [["크레딧 +%d 대신 받기" % campaign.credit_reward(),"credits"],["선택 없이 계속","skip"]]:
			var button: Button = ui._button(alternatives,choice[0],"city_reward_"+choice[1],action.bind("reward",choice[1]))
			button.size_flags_horizontal = Control.SIZE_SHRINK_END
			button.autowrap_mode = TextServer.AUTOWRAP_OFF
			button.add_theme_font_size_override("font_size",ui._font_scaled(17))
			button.custom_minimum_size.x = 240
		return
	if boss_loot:
		return
	var wallet = ui._panel(row)
	wallet.get_parent().custom_minimum_size.x = 285
	ui._label(wallet, "+%d Cr" % campaign.credit_reward(), 42, ui.ACCENT)
	ui._label(wallet, ("정예 고정 배급" if campaign.node().get("elite", false) else "전투 소모가 적을수록 배급 증가") + "\n상점 일반 12Cr · 고급 24Cr", 18, ui.MUTED)
	if campaign.node().route == "duct": ui._label(wallet, "환기구 보너스 +%dCr 포함" % Data.ROUTE_REWARD_BONUS, 16, ui.ACCENT)
	ui._primary_button(ui._button(wallet, "크레딧 받기", "city_reward_credits", action.bind("reward", "credits")), Color("f3cf73"))
	var skip: Button = ui._button(reward_frame, "선택 없이 계속", "city_reward_skip", action.bind("reward", "skip"))
	skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	skip.custom_minimum_size.x = 190

func can_take_ammo(id: String) -> bool:
	if campaign.can_acquire_ammo(id): return true
	for source in campaign.replaceable_ammo():
		if campaign.can_acquire_ammo(id, source): return true
	return false

func acquire_ammo(id: String, command: String, value: Variant, extra: String = "") -> void:
	if int(campaign.s.get("discovery_version",0)) < 3:
		action(command, value, extra)
		return
	var column: VBoxContainer = ui._dialog("탄환 확보", false)
	column.name = "AmmoAcquisition"
	var dialog: Control = column.get_meta("dialog")
	dialog.set_meta("preferred_size",Vector2(980,480))
	dialog._fit()
	var layout: Control = AcquisitionView.instantiate()
	column.add_child(layout)
	var face: Control = layout.get_node("%IncomingCard")
	face.setup(id,1,ui.model.s,false,false,"다음 전투부터 사용")
	var price: Label = layout.get_node("%Price")
	price.visible = command == "buy"
	if command == "buy": price.text = "구매 %d Cr · 교체도 같은 가격" % int(campaign.s.offers[int(value)].price)
	var choices: VBoxContainer = layout.get_node("%ReplaceList")
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	var count: int = ui.model.s.deck.size()
	var refit: bool = command == "resolve" and value == "refit"
	var owned_replacement: bool = ui.model.Reserve.inventory_enabled(ui.model.s)
	layout.get_node("%ReplaceHeading").text = "보유 탄환 한 장과 교체" if owned_replacement else "기본탄 한 장과 교체"
	layout.get_node("%DeckCount").text = "덱 %d장 유지 · 내보낼 탄을 선택하세요" % count
	var finite: bool = ui.model.Reserve.enabled(ui.model.s)
	if finite:
		layout.get_node("%DeckCount").text = "휴대 %d/%d장 · 교체해도 총량은 유지됩니다" % [count, ui.model.deck_limit()]
		var add_host: Control = layout.get_node("%AddHost")
		add_host.get_parent().move_child(add_host, 0)
		layout.get_node("%Alternative").text = "추가: 전투 총량 증가 · 교체: 필요한 탄의 비중 조정"
		layout.get_node("%Alternative").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if refit:
		layout.get_node("%Alternative").text = "무료 정비 1회 사용 · 한 장을 내보내고 한 장 획득"
		layout.get_node("%AddHost").hide()
	var offered := 0
	for source in campaign.replaceable_ammo():
		if not campaign.can_acquire_ammo(id, source): continue
		offered += 1
		var button: Button=preload("res://redesign/ammo_change_choice.tscn").instantiate()
		button.name="ammo_replace_"+str(source)
		choices.add_child(button)
		button.get_node("Margin/Row/Art").ammo_id=source
		var tune: String=str(Ammo.AMMO[source].get("tune",""))
		button.get_node("Margin/Row/Info/Title").text="%s%s · %d장 중 1장"%[Ammo.AMMO[source].name," · 화력" if tune=="power" else (" · 방열" if tune=="cool" else ""),ui.model.s.deck.count(source)]
		button.get_node("Margin/Row/Info/Change").text=preload("res://redesign/ammo_comparison.gd").changes(source,id,ui.model.s)
		button.get_node("Margin/Row/Info/Cost").text=preload("res://redesign/ammo_comparison.gd").costs(source,id,ui.model.s)
		preload("res://redesign/combat_treatment.gd").finish_button(button)
		button.pressed.connect(func():
			dialog.close()
			_acquire_and_notice(command,value,extra,id,source)
		)
		button.tooltip_text="%s 한 장을 %s으로 교체합니다. 총 %d장은 유지되며 내보낸 탄은 돌아오지 않습니다."%[Ammo.AMMO[source].name,Ammo.AMMO[id].name,count]

	if offered==0: ui._label(choices,"교체할 다른 탄환이 없습니다.",17,ui.MUTED)
	ui._button(layout.get_node("%AddHost"),"탄약 추가 · %d → %d장" % [count,count+1] if count<ui.model.deck_limit() else "탄약 가득함 · %d/%d장" % [count,ui.model.deck_limit()],"ammo_acquire_add",func():
		dialog.close()
		_acquire_and_notice(command,value,extra,id)
	,refit or not campaign.can_acquire_ammo(id))
	# Count only the rows actually offered (an identical card is not a replacement).
	dialog.set_meta("preferred_size", Vector2(980, clampf(280 + 108 * offered, 390, 720)))
	dialog._fit()

func _acquire_and_notice(command: String, value: Variant, extra: String, id: String, source: String = "") -> void:
	var before: int = ui.model.s.deck.count(id)
	if command == "resolve": action(command,value,extra,source)
	else: action(command,value,source if not source.is_empty() else extra)
	if ui.model.s.deck.count(id) > before:
		ui._ammo_acquired_notice.call_deferred(id,not source.is_empty())


func _service_place(parent: Node, kind: String, title: String, hint: String, narrative: bool = false) -> Control:
	var place: Control = ServicePlaces[kind].instantiate()
	parent.add_child(place)
	place.configure(title, hint, str(campaign.s.get("outfit", "work")))
	if campaign.modern_places():
		place.use_decision_layout(float(ui.preferences.data.get("text_scale", 1.0)), narrative)
	return place

## One content column owns the art, choices and exit. Extra viewport width stays
## outside the composition; it never stretches cards or separates their actions.
func _place_frame(width: float = 900) -> VBoxContainer:
	place_body = _collection_workspace(ui.body, width)
	place_body.name = "PlaceContent"
	place_body.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	place_body.add_theme_constant_override("separation", 16)
	return place_body

func _place_action(parent: Node, title: String, key: String, callback: Callable, disabled: bool = false, width: float = 216) -> Button:
	var button: Button = ui._button(parent, title, key, callback, disabled)
	button.custom_minimum_size = Vector2(width, 52)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	button.autowrap_mode = TextServer.AUTOWRAP_OFF
	button.add_theme_font_size_override("font_size", ui._font_scaled(18))
	return button

func _place_footer() -> HBoxContainer:
	var parent: Node = place_body if is_instance_valid(place_body) else ui.body
	var space := Control.new()
	space.name = "PlaceFooterSpace"
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space.custom_minimum_size.y = 2
	parent.add_child(space)
	var row := HBoxContainer.new()
	row.name = "PlaceFooter"
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	return row

func _footer_button(row: HBoxContainer, title: String, key: String, callback: Callable, primary: bool = false) -> Button:
	var space := Control.new()
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(space)
	var button := _place_action(row, title, key, callback)
	if primary: ui._primary_button(button)
	return button

func _collection_workspace(parent: VBoxContainer, width: float) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = minf(width, maxf(280, ui.size.x - 56))
	column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override("separation", 12)
	parent.add_child(column)
	return column

func _choice_note(parent: Node, text: String, font_size: int = 18) -> Label:
	var note: Label = ui._label(parent, text, font_size, ui.MUTED)
	# Equal-height grid cells keep their actions on a shared baseline even when
	# one description wraps, or one choice is unavailable.
	note.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return note

func _place_section(title: String) -> void:
	var heading: Label = ui._label(place_body if is_instance_valid(place_body) else ui.body, title, 21, ui.INK)
	heading.name = "PlaceSectionTitle"
	heading.custom_minimum_size.y = 32
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func shop() -> void:
	var view := TerminalShopScreen.instantiate() if campaign.modern_places() else ShopScreen.instantiate()
	view.configure(ui)
	ui.body.add_child(view)

func _legacy_shop_layout() -> void:
	var host: VBoxContainer = _place_frame(1200) if campaign.modern_places() else ui.body
	var resident: Dictionary = Lore.SHOPS[int(campaign.s.region)]
	var place := _service_place(host, "shop", str(campaign.node().name), str(resident.greeting))
	StoryUI.shop_inline(ui, place, int(campaign.s.region))
	var workbench := ShopWorkbench.instantiate()
	workbench.add_theme_constant_override("separation", 8)
	host.add_child(workbench)
	_style_shop_workbench(workbench)
	var top_actions: HFlowContainer = workbench.get_node("%TopActions")
	if not campaign.modern_places():
		ui._button(top_actions, "장착 파츠 %d/5" % campaign.equipped_parts().size(), "city_shop_build", deck)
	if not campaign.modern_places():
		var press_button: Button = ui._button(top_actions, "압축 완료" if campaign.s.shop_refined else "영구 압축 · %dCr" % campaign.COMPRESSION_PRICE, "city_shop_press", compression_dialog.bind("shop"), bool(campaign.s.shop_refined))
		press_button.add_theme_font_size_override("font_size", 16)
		if int(campaign.s.get("discovery_version",0)) >= 2:
			ui._button(top_actions, "개조 완료" if campaign.s.get("shop_tuned",false) else "탄환 개조 · %dCr" % campaign.TUNE_PRICE, "city_shop_tune", tune_choices, bool(campaign.s.get("shop_tuned",false)))
	var reroll: Button = ui._button(top_actions, "새 진열 · %dCr" % campaign.reroll_cost(), "city_reroll", action.bind("reroll"), int(campaign.s.credits) < campaign.reroll_cost())
	reroll.tooltip_text = "이번 상점에서 3 → 5 → 7 → 9Cr. 다음 상점에서는 3Cr로 돌아옵니다."
	if not campaign.modern_places():
		ui._button(top_actions, "맵으로 계속  ›", "city_leave", action.bind("leave"))
	_shop_feedback(workbench)
	(workbench.get_node("%BuildStatus") as Label).text = "%d / %d 장착" % [campaign.equipped_parts().size(), campaign.MAX_EQUIPPED_PARTS]
	(workbench.get_node("%WeaponStatus") as Label).text = "%s · 탄창 %d · 열 한계 %d" % [Ammo.GUNS[campaign.s.gun].name, ui.model.capacity(), Ammo.heat_limit(ui.model.s)]
	(workbench.get_node("%DeckStatus") as Label).text = Insight.deck_summary(ui.model.s.deck)
	(workbench.get_node("%WalletStatus") as Label).text = "%d Cr" % int(campaign.s.credits)

	var row := workbench.get_node("%ShopOfferGrid") as GridContainer
	for preview in row.get_children():
		row.remove_child(preview)
		preview.queue_free()
	row.columns = 3
	for i in range(campaign.s.offers.size()):
		var offer: Dictionary = campaign.s.offers[i]
		var tile: Control = ShopOffer.instantiate()
		tile.name = "ShopOffer_"+str(i)
		row.add_child(tile)
		if campaign.modern_places():
			tile.custom_minimum_size.x = 230
			tile.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var item: Button = tile.get_node("Item")
		if campaign.modern_places(): item.custom_minimum_size = Vector2(230, 164)
		var id := str(offer.id)
		item.name = ("city_offer_compare_" if offer.type=="ammo" else "city_part_info_")+str(i)
		item.pressed.connect(func():
			ui.feedback.play("click")
			_show_shop_offer_compare(workbench,offer,i)
		)
		item.tooltip_text = "선택해서 구매 후 상태를 확인합니다."
		var visual: Control = item.get_node("CardInfo")
		if offer.type=="ammo":
			visual.setup(id,1,ui.model.s)
		else:
			item.remove_child(visual);visual.queue_free()
			visual = part_card(item,id)
			visual.custom_minimum_size = Vector2.ZERO
			visual.portrait = true
		var price: Label = tile.get_node("%Price")
		price.name = "ShopPrice_"+str(i)
		price.text = "구매 완료" if offer.sold else "%d Cr"%int(offer.price)
		price.add_theme_color_override("font_color",ui.MUTED if offer.sold else Color("f3cf73"))
		var status: Label = tile.get_node("%Status")
		status.text = ("동일 성능 %d장 보유"%ui.model.s.deck.count(id)) if offer.type=="ammo" else Ammo.part_grade_name(id)+(" · 코어" if Ammo.is_core_part(id) else " · 파츠")
		status.add_theme_color_override("font_color",ui.MUTED)

	(workbench.get_node("%OfferComparePanel") as Control).show()
	var core_done: bool = bool(campaign.s.shop_compressor_bought)
	var core_full: bool = int(campaign.s.compressor_charges) >= campaign.MAX_COMPRESSOR_CHARGES
	var core_caption := "구매 완료" if core_done else ("최대 충전" if core_full else "동일 탄환 두 발을 전투 중 결합")
	var core_button = ui._button(top_actions, "압축 충전 %d/%d · %dCr" % [campaign.s.compressor_charges, campaign.MAX_COMPRESSOR_CHARGES, campaign.COMPRESSOR_PRICE], "city_buy_compressor", action.bind("buy_compressor"), core_done or core_full or int(campaign.s.credits) < campaign.COMPRESSOR_PRICE)
	core_button.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box: StyleBoxTexture = ui._console_style("button", state)
		box.content_margin_left = 56
		core_button.add_theme_stylebox_override(state, box)
	core_button.tooltip_text = core_caption + " · 전투 중 사용하고 남은 충전은 다음 전투에도 유지됩니다."
	var glyph := CompressorGlyph.new()
	glyph.name = "ShopCompressorGlyph"
	core_button.add_child(glyph)
	glyph.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	glyph.position = Vector2(5, 8)
	glyph.size = Vector2(50, 36)
	glyph.setup(int(campaign.s.compressor_charges), not core_button.disabled)
	core_button.visible = not campaign.magazine_enabled()
	if (workbench.get_node("%ShopHint") as Label).text.is_empty():
		(workbench.get_node("%ShopHint") as Label).text = "파츠는 빈 슬롯에 자동 장착됩니다. 교체는 빌드 작업실에서 할 수 있습니다."

	(workbench.get_node("%DeckStatus") as Label).hide()
	shop_selection = clampi(shop_selection, 0, maxi(0, campaign.s.offers.size() - 1))
	if not campaign.s.offers.is_empty():
		_show_shop_offer_compare(workbench, campaign.s.offers[shop_selection], shop_selection)
	if campaign.modern_places():
		_layout_shop(workbench, reroll, core_button)


func _layout_shop(workbench: Control, reroll: Button, compressor: Button) -> void:
	# Ultra-wide displays do not stretch three cards into shallow banners.
	workbench.add_theme_constant_override("separation", 4)
	workbench.custom_minimum_size.x = 0
	workbench.size_flags_horizontal = Control.SIZE_FILL
	var stock: GridContainer = workbench.get_node("%ShopOfferGrid")
	stock.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var heading: HBoxContainer = workbench.get_node("OffersHeader")
	reroll.reparent(heading)
	reroll.custom_minimum_size = Vector2(180, 44)
	reroll.size_flags_horizontal = Control.SIZE_SHRINK_END
	reroll.add_theme_font_size_override("font_size", ui._font_scaled(17))
	workbench.get_node("%WalletStatus").hide() # Credits already stay in the run header.
	var footer := _place_footer()
	place_body.get_node("PlaceFooterSpace").hide()
	compressor.reparent(footer)
	compressor.custom_minimum_size = Vector2(320, 52)
	compressor.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var build: Button = ui._button(footer, "파츠 관리", "city_shop_build", deck)
	build.custom_minimum_size = Vector2(136, 52)
	build.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	build.add_theme_font_size_override("font_size", ui._font_scaled(17))
	_footer_button(footer, "맵으로 계속  ›", "city_leave", action.bind("leave"))
	workbench.get_node("%TopActions").hide()
	# A quiet shop has no instructional paragraph. Actual purchase/reroll feedback remains.
	var hint: Label = workbench.get_node("%ShopHint")
	if hint.text == "파츠는 빈 슬롯에 자동 장착됩니다. 교체는 빌드 작업실에서 할 수 있습니다." or hint.text == "빈 슬롯이 없거나 코어가 중복되면 구매한 파츠는 보관함으로 이동합니다.":
		hint.hide()


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
			elif Ammo.AMMO.has(id): message = "%s 구매 · %s · 덱 %d장" % [Ammo.AMMO[id].name,"보유 탄과 교체" if not str(detail.get("removed","")).is_empty() else "한 장 추가",ui.model.s.deck.size()]
		"purchase_compressor", "shop_compress", "tune": message = str(campaign.s.message)
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
		var tile := workbench.find_child("ShopOffer_"+str(i),true,false)
		if tile == null: continue
		for card in tile.find_children("*","Control",true,false):
			if card is PartCard or card is Card:
				card.selected_visual=i==offer_index
				card.queue_redraw()
	var title: Label=workbench.get_node("%OfferCompareTitle")
	var body: Label=workbench.get_node("%OfferCompareBody")
	var status: Label=workbench.get_node("%OfferCompareStatus")
	var cost: Label=workbench.get_node("%OfferCompareCost")
	var change: Label=workbench.get_node("%OfferCompareChange")
	var actions: Control=workbench.get_node("%OfferCompareActions")
	for child in actions.get_children(): actions.remove_child(child);child.queue_free()
	var id:=str(offer.id)
	var sold:=bool(offer.sold)
	var rules: Callable
	if str(offer.type)=="ammo":
		title.text=str(Ammo.AMMO[id].name)
		status.text="구매 완료" if sold else "보유 탄과 교체 또는 한 장 추가"
		var face:=Card.new()
		face.setup(id,1,ui.model.s)
		body.text=face.effect_text()
		face.free()
		cost.text="발열 "+Ammo.heat_label(id,ui.model.s)
		if Ammo.is_compressed(id): cost.text+=" · "+Ammo.compression_cost_text(id,ui.model.s)
		change.text="동일 성능 %d장 보유 · 탄약 %d/%d장"%[ui.model.s.deck.count(id),ui.model.s.deck.size(),ui.model.deck_limit()]
		rules=func():
			var dialog=ui._dialog(str(Ammo.AMMO[id].name),true)
			ammo_card(dialog,id)
			ui._label(dialog,preload("res://redesign/readability.gd").description(id,ui.model.s),18)
	else:
		var part: Dictionary=Ammo.part_spec(id,ui.model.s)
		title.text=str(part.name)
		body.text=str(part.upside)
		cost.text="대가 · "+str(part.downside) if not str(part.downside).is_empty() else ""
		if sold:
			status.text="구매 완료 · "+("장착 중" if campaign.is_equipped(id) else "보관 중")
			change.text="파츠 관리에서 구성을 바꿀 수 있습니다."
		elif _purchase_will_equip(id):
			status.text="구매 후 · 빈 장착대에 장착"
			var proposed: Dictionary=ui.model.s.duplicate(true)
			proposed.equipped_parts=campaign.equipped_parts()
			proposed.equipped_parts.append(id)
			var deltas:=_part_stat_changes(ui.model.s,proposed)
			change.text="\n".join(deltas) if not deltas.is_empty() else "장착 %d → %d/5"%[campaign.equipped_parts().size(),proposed.equipped_parts.size()]
		else:
			status.text="구매 후 · 보관함으로"
			change.text="현재 장착은 유지됩니다. 파츠 관리에서 교체하세요."
			if Ammo.is_core_part(id) and campaign.equipped_parts().any(func(key): return Ammo.is_core_part(str(key))):
				change.text="코어는 1개만 장착합니다. 구매 후 기존 코어와 교체할 수 있습니다."
		rules=part_details.bind(id)
	cost.visible=not cost.text.is_empty()
	var detail: Button=ui._button(actions,"상세 규칙","city_offer_detail_"+str(offer_index),rules)
	detail.custom_minimum_size.y=44
	detail.add_theme_font_size_override("font_size",ui._font_scaled(16))
	var callback: Callable=acquire_ammo.bind(id,"buy",offer_index) if str(offer.type)=="ammo" else action.bind("buy",offer_index)
	var unavailable:=sold or int(campaign.s.credits)<int(offer.price) or (str(offer.type)=="ammo" and not can_take_ammo(id))
	var label:="구매 완료" if sold else "%dCr 구매 · 잔액 %d"%[int(offer.price),int(campaign.s.credits)-int(offer.price)]
	if not sold and int(campaign.s.credits)<int(offer.price): label="%dCr 부족"%(int(offer.price)-int(campaign.s.credits))
	elif not sold and str(offer.type)=="ammo" and not can_take_ammo(id): label="가방이 가득함 · 교체할 탄 없음"
	var purchase: Button=ui._button(actions,label,"city_compare_buy_"+str(offer_index),callback,unavailable)
	ui._primary_button(purchase)
	purchase.custom_minimum_size=Vector2(180,48)
	purchase.add_theme_font_size_override("font_size",ui._font_scaled(18))
	if campaign.modern_places():
		detail.size_flags_horizontal = Control.SIZE_SHRINK_END
		detail.custom_minimum_size.x = 140
		purchase.size_flags_horizontal = Control.SIZE_SHRINK_END
		purchase.custom_minimum_size.x = 280

func _part_stat_changes(before: Dictionary, after: Dictionary) -> PackedStringArray:
	var projection=ui.model.get_script().new()
	projection.s=after
	var changes: PackedStringArray=[]
	if Ammo.replacement_cooling(before)!=Ammo.replacement_cooling(after): changes.append("재장전 냉각  %d → %d"%[Ammo.replacement_cooling(before),Ammo.replacement_cooling(after)])
	if Ammo.hand_capacity(before)!=Ammo.hand_capacity(after): changes.append("선택 패  %d → %d장"%[Ammo.hand_capacity(before),Ammo.hand_capacity(after)])
	if Ammo.heat_limit(before)!=Ammo.heat_limit(after): changes.append("열 한계  %d → %d"%[Ammo.heat_limit(before),Ammo.heat_limit(after)])
	if Ammo.hot_threshold(before)!=Ammo.hot_threshold(after) and (Ammo.uses_hot_effect(before) or Ammo.uses_hot_effect(after)):
		changes.append("고열 조건  %d → %d"%[Ammo.hot_threshold(before),Ammo.hot_threshold(after)])
	if Ammo.capacity(before)!=Ammo.capacity(after): changes.append("탄창  %d → %d칸"%[Ammo.capacity(before),Ammo.capacity(after)])
	if ui.model.reload_cost()!=projection.reload_cost(): changes.append("재장전  %d → %d턴"%[ui.model.reload_cost(),projection.reload_cost()])
	return changes

func _style_shop_workbench(workbench: Control) -> void:
	var panel: PanelContainer=workbench.get_node("%OfferComparePanel")
	panel.add_theme_stylebox_override("panel",ui._console_style("panel"))
	workbench.get_node("%OfferCompareTitle").add_theme_color_override("font_color",Color("e4f2ee"))
	workbench.get_node("%OfferCompareStatus").add_theme_color_override("font_color",Color("5cdddc"))
	workbench.get_node("%OfferCompareCost").add_theme_color_override("font_color",Color("ff9a6a"))
	workbench.get_node("%OfferCompareChange").add_theme_color_override("font_color",Color("8fb0b0"))

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
	if campaign.modern_places():
		if campaign.s.phase == "event": encounter_service()
		elif campaign.node().get("workshop", false) and not campaign.s.resolved: modern_workshop()
		else: modern_supply()
		return
	if campaign.node().get("workshop", false) and not campaign.s.resolved:
		workshop()
		return
	var question := "공개된 탄환 한 장을 보급하세요." if campaign.s.phase == "supply" else "얻는 것과 다음 전투의 비용을 함께 확인하세요."
	var service_color: Color = Color("5cdddc") if campaign.s.phase == "supply" else ui.DANGER
	var service_marker := "□" if campaign.s.phase == "supply" else "!"
	if campaign.node().get("workshop", false):
		_service_place(ui.body, "workshop", "정비 공방" if campaign.modern_places() else "정비 작업대", "작업을 마쳤습니다.")
	elif campaign.s.phase == "supply":
		_service_place(ui.body, "supply", str(campaign.node().name), "탄환을 확보했습니다." if campaign.s.resolved else ("보유 탄 보충 또는 새로운 탄환\n무료로 한 장을 고르세요." if campaign.modern_places() else "가져갈 탄환을 고르세요.\n한 장을 받을 수 있습니다."))
	else:
		_phase_intro(service_marker, str(campaign.node().name), question, service_color)
	if campaign.s.resolved:
		ui._label(ui.body, str(campaign.s.message), 24)
		if campaign.s.phase in ["supply", "bypass"]:
			if campaign.modern_places(): ui._button(ui.body, "내 빌드 확인", "city_service_build", deck)
			else: equipment(ui.body)
		ui._button(ui.body, "맵으로 계속", "city_leave", action.bind("leave"))
		return
	if campaign.s.phase != "supply": ui._label(ui.body, Data.hint(campaign.node()), 22, ui.MUTED)
	if campaign.s.phase == "supply":
		var row = _service_ammo_grid(ui.body) if campaign.modern_places() else ui._row(ui.body)
		for id in campaign.reward_options():
			var panel = ui._panel(row)
			if campaign.modern_places(): panel.get_parent().custom_minimum_size.x = 285
			ammo_card(panel, id)
			if campaign.modern_places(): ui._label(panel, "보유 탄 보충 · 동일 성능 %d장" % ui.model.s.deck.count(id) if ui.model.s.deck.has(id) else "새 탄환 발견", 18, ui.MUTED)
			ui._button(panel, "1장 확보", "city_supply_" + id, acquire_ammo.bind(id,"resolve","ammo",id), not can_take_ammo(id))
	else:
		match str(campaign.node().event):
			"siphon": ui._button(ui.body, "+20Cr / 다음 전투 시작 거리 −2m", "city_event_power", action.bind("resolve", "power"))
			"archive":
				ui._button(ui.body, "도시 기록 회수 · 영구 보관", "city_event_lore", action.bind("resolve", "lore"))
				var id: String = campaign.reward_options()[0]
				var panel = ui._panel(ui.body)
				ammo_card(panel, id)
				ui._button(panel, "대신 탄환 1장 회수", "city_event_ammo", acquire_ammo.bind(id,"resolve","ammo",id), not can_take_ammo(id))
			"salvage": remove_choices("sell", "1장 분해 · +16Cr", "city_sell_")
	ui._button(ui.body, "현재 구성을 유지하고 통과", "city_service_skip", action.bind("resolve", "skip"))

func workshop() -> void:
	if campaign.modern_places():
		modern_workshop()
		return
	_service_place(ui.body, "workshop", "정비 작업대", "하나만 선택\n이번 정비는 무료입니다.")
	var row = ui._row(ui.body)
	var press = ui._panel(row)
	ui._label(press, "탄환 압축", 26)
	ui._label(press, "일반탄 2장 → 고급탄 1장\n효과와 장전 제약 확인", 18, ui.MUTED)
	ui._button(press, "압축할 탄 선택", "city_workshop_press", workshop_choices.bind("compress"), campaign.compressible_ids().is_empty())
	ui._label(press, "압축 가능한 탄 %d종" % campaign.compressible_ids().size(), 17, ui.MUTED)
	var trim = ui._panel(row)
	ui._label(trim, "덱 정리", 26)
	ui._label(trim, "선택한 탄 1장 제거\n최소 8장을 유지합니다.", 18, ui.MUTED)
	ui._button(trim, "제거할 탄 선택", "city_workshop_trim", workshop_choices.bind("remove"), ui.model.s.deck.size() <= campaign.minimum_deck())
	var core = ui._panel(row)
	ui._label(core, "압축 코어", 26)
	ui._label(core, "%d → %d / 2" % [campaign.s.compressor_charges, mini(2, int(campaign.s.compressor_charges) + 1)], 36, Color("f3cf73"))
	ui._label(core, "전투 중 압축 +1회\n미사용 기회 유지", 18, ui.MUTED)
	ui._button(core, "코어 충전", "city_workshop_core", action.bind("resolve", "core"), int(campaign.s.compressor_charges) >= 2)
	var bag = ui._panel(row)
	ui._label(bag, "가방 확장", 26)
	var bag_before := Ammo.hand_capacity(ui.model.s)
	ui._label(bag, "%d → %d장" % [bag_before, bag_before + (1 if campaign.can_grow_bag() else 0)], 36, Color("f3cf73"))
	ui._label(bag, campaign.bag_growth_hint(), 18, ui.MUTED)
	ui._button(bag, "가방 +1장", "city_workshop_bag", action.bind("resolve", "bag"), not campaign.can_grow_bag())
	ui._button(ui.body, "정비 없이 계속", "city_service_skip", action.bind("resolve", "skip"))

func workshop_choices(operation: String) -> void:
	var panel = ui._workspace("압축할 탄 선택" if operation == "compress" else "제거할 탄 선택", "선택하면 이번 정비를 사용합니다. 닫으면 아직 사용하지 않습니다.")
	panel = _collection_workspace(panel, 870)
	if not campaign.modern_places():
		_service_place(panel, "workshop", "탄환 압축" if operation == "compress" else "덱 정리", "결과를 보고 확정하세요.\n닫으면 정비가 남습니다.")
	var grid := GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	panel.add_child(grid)
	var sources: Array = campaign.compressible_ids() if operation == "compress" else ui.model.s.deck
	var seen: Array = []
	for source in sources:
		var id := str(source)
		if seen.has(id): continue
		seen.append(id)
		var cell = ui._panel(grid)
		cell.get_parent().custom_minimum_size.x = 282
		if operation == "compress":
			var holder := Control.new()
			holder.custom_minimum_size = Vector2(250, 140)
			cell.add_child(holder)
			var preview := CompressionChoice.new()
			preview.setup(id, ui.model.s)
			holder.add_child(preview)
			_choice_note(cell, ui.Readability.description(Ammo.compressed_id(id), ui.model.s), 17)
		else:
			ammo_card(cell, id)
			ui._label(cell, "보유 %d장 → %d장" % [ui.model.s.deck.count(id), ui.model.s.deck.count(id) - 1], 18, ui.MUTED)
		ui._button(cell, "압축 확정" if operation == "compress" else "1장 제거 확정", "city_workshop_" + operation + "_" + id, action.bind("resolve", operation, id))

func remove_choices(choice: String, title: String, prefix: String) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	ui.body.add_child(grid)
	var seen: Array = []
	for id in ui.model.s.deck:
		if seen.has(id): continue
		seen.append(id)
		ui._button(grid, "%s\n%s" % [Ammo.AMMO[id].name + " · 피해 %d · 열 %s" % [Ammo.damage(id,ui.model.s), Ammo.heat_label(id,ui.model.s)], title], prefix + id, action.bind("resolve", choice, id), ui.model.s.deck.size() <= 8)
	ui._label(ui.body, "분해 뒤에도 덱 8장을 유지합니다.", 17, ui.MUTED)

func gate() -> void:
	if campaign.modern_gates():
		preload("res://redesign/gate_reward_ui.gd").render(self)
		return
	_phase_intro("▲", "구역 관문 통과", "다음 구역까지 유지할 성장 하나를 선택하세요.", Color("f3cf73"))
	ui._label(ui.body, Data.info(int(campaign.s.region) + 1).name + " / " + Data.info(int(campaign.s.region) + 1).brief, 21, ui.MUTED)
	var row := GridContainer.new()
	row.name = "GateUpgradeGrid"
	row.columns = 2
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("h_separation", 12)
	row.add_theme_constant_override("v_separation", 12)
	ui.body.add_child(row)
	var slot_button = ui._button(row, "", "city_gate_slot", action.bind("gate", "slot"), int(campaign.s.slots) >= 2)
	upgrade_card(slot_button, "slot", {"before": ui.model.capacity(), "after": ui.model.capacity() + 1})
	var compression_button = ui._button(row, "", "city_gate_compress", compression_dialog, campaign.compressible_ids().is_empty())
	upgrade_card(compression_button, "compress")
	var credits_button = ui._button(row, "", "city_gate_credits", action.bind("gate", "credits"))
	upgrade_card(credits_button, "credits", {"amount": 24})
	var bag_button = ui._button(row, "", "city_gate_bag", action.bind("gate", "bag"), not campaign.can_grow_bag())
	var before := Ammo.hand_capacity(ui.model.s)
	upgrade_card(bag_button, "bag", {"before": before, "after": before + (1 if campaign.can_grow_bag() else 0), "caption": campaign.bag_growth_hint()})

func tune_choices() -> void:
	var panel = ui._workspace("탄환 개조", "보유한 한 장만 영구 변경 · 카드당 한 번 · 압축은 별도 작업")
	panel = _collection_workspace(panel, 870)
	ui._label(panel, "무료 작업 1회 · 확정해야 공방 기회를 사용합니다." if campaign.modern_places() else "이번 방문 1회 · %dCr · 보유 %dCr" % [campaign.TUNE_PRICE,campaign.s.credits], 20, ui.ACCENT)
	var grid := GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.columns = 3
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	panel.add_child(grid)
	var seen: Array = []
	for index in range(ui.model.s.deck.size()):
		var id := str(ui.model.s.deck[index])
		if seen.has(id) or Ammo.Variants.tuned(id,Ammo.AMMO,"power").is_empty(): continue
		seen.append(id)
		var cell = ui._panel(grid)
		cell.get_parent().custom_minimum_size.x = 282
		ammo_card(cell,id)
		_choice_note(cell, Ammo.profile_detail(id) + " · 보유 %d장" % ui.model.s.deck.count(id),17)
		ui._button(cell,"이 중 1장 개조", "city_tune_select_"+str(index),tune_preview.bind(index))
	if seen.is_empty(): ui._label(panel,"개조할 수 있는 기본탄·철갑탄·연타탄이 없습니다.",20,ui.MUTED)

func tune_preview(index: int) -> void:
	if index < 0 or index >= ui.model.s.deck.size(): return
	var id := str(ui.model.s.deck[index])
	var panel = ui._workspace("%s · 1장 개조" % Ammo.AMMO[id].name, "한 가지 선택 · 이 카드의 위력과 발열을 영구 변경합니다.")
	panel = _collection_workspace(panel, 692)
	ui._label(panel,"현재  피해 %d · 열 %s · %s" % [Ammo.damage(id,ui.model.s),Ammo.heat_label(id,ui.model.s),Ammo.profile_detail(id)],22)
	var grid := GridContainer.new()
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.columns=2
	grid.add_theme_constant_override("h_separation",12)
	panel.add_child(grid)
	for mode in ["power","cool"]:
		var result := Ammo.Variants.tuned(id,Ammo.AMMO,mode)
		var cell = ui._panel(grid)
		cell.get_parent().custom_minimum_size.x = 340
		ui._label(cell,"화력 개조" if mode=="power" else "방열 개조",25,ui.ACCENT)
		var preview := ammo_card(cell,result if not result.is_empty() else id)
		preview.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
		var effect: Label = ui._label(cell, "이미 최소 발열입니다." if result.is_empty() else preload("res://redesign/ammo_comparison.gd").changes(id,result,ui.model.s)+"\n"+preload("res://redesign/ammo_comparison.gd").costs(id,result,ui.model.s),18,ui.MUTED)
		effect.name="TuneDelta_"+mode
		effect.custom_minimum_size.y = ui._scaled(48)
		effect.size_flags_vertical = Control.SIZE_EXPAND_FILL
		ui._button(cell,"무료 · 1장 개조 확정" if campaign.modern_places() else "%dCr · 1장 개조 확정" % campaign.TUNE_PRICE,"city_tune_"+mode,action.bind("tune",index,mode),result.is_empty() or (campaign.s.resolved if campaign.modern_places() else int(campaign.s.credits)<campaign.TUNE_PRICE or bool(campaign.s.get("shop_tuned",false))))
	ui._label(panel,"나머지 %d장은 그대로 유지됩니다." % (ui.model.s.deck.size()-1),18,ui.MUTED)
	var back: Button = ui._button(panel,"다른 탄환 고르기","city_tune_back",tune_choices)
	back.custom_minimum_size.x = 240
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

func compression_dialog(context: String = "gate") -> void:
	var panel = ui._workspace("일반 2장 → 고급 1장", "탄종·위력·개조가 같은 2장만 압축 · 최소 8장 유지 · 고급탄 재압축 불가")
	_service_place(panel, "workshop", "탄환 압축소", "일반탄 2장 → 고급탄 1장\n효과와 장전 제약 확인")
	if context == "shop": ui._label(panel, "이번 방문 1회 · %dCr · 보유 %dCr" % [campaign.COMPRESSION_PRICE, campaign.s.credits], 20, ui.ACCENT)
	if campaign.compressible_ids().is_empty(): ui._label(panel, "탄종·위력·개조가 같은 2장과 압축 후 덱 8장 이상이 필요합니다.", 20, ui.MUTED)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	panel.add_child(grid)
	for source in campaign.compressible_ids():
		var source_id := str(source)
		var result_id := Ammo.compressed_id(source_id)
		var cell = ui._panel(grid)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(270, 134)
		cell.add_child(holder)
		var preview := CompressionChoice.new()
		preview.setup(source_id, ui.model.s)
		holder.add_child(preview)
		var effect_view := Card.new()
		effect_view.setup(result_id, 1, ui.model.s)
		ui._label(cell, effect_view.effect_text(), 20, ui.ACCENT)
		effect_view.free()
		ui._label(cell, preload("res://redesign/ammo_comparison.gd").changes(source_id,result_id,ui.model.s)+"\n"+preload("res://redesign/ammo_comparison.gd").costs(source_id,result_id,ui.model.s), 17, ui.MUTED)
		if not Ammo.anchor(result_id).is_empty(): ui._label(cell, "첫 발 고정 · 마지막에 장전" if Ammo.anchor(result_id) == "first" else "마지막 발 고정 · 먼저 장전", 17, ui.DANGER)
		ui._button(cell, "영구 압축 확정", "city_compress_" + source_id, func():
			if context == "shop": action("shop_compress", source_id)
			else: action("gate", "compress", source_id)
		, context == "shop" and (int(campaign.s.credits) < campaign.COMPRESSION_PRICE or bool(campaign.s.shop_refined)))

func ending() -> void:
	var motion := 0.0
	if results_for_campaign != campaign:
		results_for_campaign = campaign
		results_details_open = false
		if ui.preferences.data.motion != "instant":
			motion = ui.preferences.motion_scale()
	var view := ResultsScreen.instantiate()
	ui.body.add_child(view)
	view.present(campaign, motion, ui.save_error)
	view.fit_available(ui.ReadableUI.available(ui).size)
	view.set_details(results_details_open)
	view.details_changed.connect(func(open: bool): results_details_open = open)
	view.archive_requested.connect(archive)
	view.new_run_requested.connect(_new_challenge)

func _new_challenge() -> void:
	if ui.busy:
		return
	ui.preparation_seed = ""
	ui._open_preparation()

## 빌드 작업실 (reworked 2026-11-08): redesign/build/workshop.gd, registered as the
## screen's workspace overlay so 닫기/Esc/focus return behave as before.
func deck(initial_tab: String = "parts") -> void:
	ui._close_workspace()
	var prior: Control = ui.get_viewport().gui_get_focus_owner()
	if prior != null: ui.workspace_return_focus = weakref(prior)
	var view: Control = BuildWorkshop.new()
	view.name = "WorkspaceOverlay"
	view.configure(ui, self, initial_tab, workspace_feedback)
	workspace_feedback = ""
	ui.add_child(view)
	ui.workspace_overlay = view

func _inspect_part(view: Control, id: String) -> void:
	if not is_instance_valid(view): return
	selected_part_id=id
	var column: VBoxContainer=view.get_node("%PartDetails")
	for child in column.get_children(): column.remove_child(child);child.queue_free()
	var detail: Control=PartInspection.instantiate()
	column.add_child(detail)
	var data: Dictionary=Ammo.part_spec(id,ui.model.s)
	var active: bool=campaign.is_equipped(id)
	var status: Label=detail.get_node("Status")
	status.text=Ammo.part_grade_name(id)+" · "+("장착 중" if active else ("코어 · 1개만 장착" if Ammo.is_core_part(id) else "보관 파츠"))
	status.add_theme_color_override("font_color",ui.MUTED)
	detail.get_node("Identity").setup(id,ui.model.s,active,true)
	var effects: Label=detail.get_node("PartEffectChanges")
	var cost: Label=detail.get_node("PartCostChanges")
	var delta: Label=detail.get_node("PartChangePreview")
	var apply: Button=detail.get_node("Actions/Apply")
	var rules: Button=detail.get_node("Actions/Rules")
	var dismantle: Button=detail.get_node("Dismantle")
	for button in [apply, rules, dismantle]:
		button.pressed.connect(func(): ui.feedback.play("click"))
	rules.name="part_rules"
	rules.pressed.connect(part_details.bind(id))
	apply.name="city_deck_equip_"+id
	ui._primary_button(apply)
	dismantle.visible=false
	cost.text=""
	var proposed: Array=campaign.equipped_parts()
	var outgoing:=""
	if id=="none" or not campaign.can_manage_parts():
		effects.text="파츠를 최대 5개 조합해 무기의 성능과 규칙을 바꿉니다." if id=="none" else str(data.text)
		cost.hide();delta.hide();apply.hide()
		status.text="보관 파츠를 모아 장착하세요." if id=="none" else "교전 중 · 열람만 가능"
	else:
		if active: proposed.erase(id)
		elif campaign.can_equip(id): proposed.append(id)
		else:
			var replacements: Array=[]
			for candidate in proposed:
				var test:=proposed.duplicate()
				test[test.find(candidate)]=id
				if Ammo.valid_part_set(str(campaign.s.gun),test): replacements.append(candidate)
			if replacements.is_empty():
				effects.text="이 구성에는 장착할 수 없습니다."
				cost.hide();delta.hide();apply.hide()
				ui._workspace_focus_chain.call_deferred()
				return
			if not replacements.has(replacement_part_id): replacement_part_id=str(replacements[0])
			outgoing=replacement_part_id
			var host: Control=detail.get_node("ReplacementHost")
			ui._label(host,"교체할 장착 파츠",16,ui.MUTED)
			var choice:=OptionButton.new()
			choice.name="PartReplacement"
			choice.custom_minimum_size.y=44
			for candidate in replacements:
				choice.add_item(str(Ammo.PARTS[candidate].name))
				choice.set_item_metadata(choice.item_count-1,candidate)
				if candidate==outgoing: choice.select(choice.item_count-1)
			choice.item_selected.connect(func(index:int):
				replacement_part_id=str(choice.get_item_metadata(index))
				_inspect_part(view,id)
				var fresh:=view.find_child("PartReplacement",true,false) as Control
				if fresh!=null: ui._focus_control.call_deferred(fresh)
			)
			host.add_child(choice)
			proposed[proposed.find(outgoing)]=id
		var before: Dictionary=ui.model.s
		var after: Dictionary=before.duplicate(true)
		after.equipped_parts=proposed
		var lines: PackedStringArray=[]
		var costs: PackedStringArray=[]
		if not active:
			lines.append("얻음  "+PartChoice.effect(id,after))
			if not str(data.downside).is_empty(): costs.append("대가  "+str(data.downside))
		var removed_id:=id if active else outgoing
		if not removed_id.is_empty():
			var removed: Dictionary=Ammo.part_spec(removed_id,ui.model.s)
			lines.append("잃음  "+PartChoice.effect(removed_id,before))
			if not str(removed.downside).is_empty(): costs.append("해제  "+str(removed.downside))
		var fit:=PartChoice.fit(id,after)
		if not fit.is_empty():lines.append(fit)
		effects.text="\n".join(lines)
		cost.text="\n".join(costs)
		cost.visible=not cost.text.is_empty()
		var changes:=_part_stat_changes(before,after)
		changes.append_array(PartChoice.deltas(before,after))
		var projection=ui.model.get_script().new();projection.s=after
		delta.text="\n".join(changes) if not changes.is_empty() else "탄창 %d칸 · 재장전 %d턴 유지"%[Ammo.capacity(after),projection.reload_cost()]
		var command:="replace_part" if not outgoing.is_empty() else "equip"
		apply.text="장착 해제" if active else ("교체 장착" if not outgoing.is_empty() else "장착")
		apply.pressed.connect(_apply_part_change.bind(command,outgoing if not outgoing.is_empty() else id,id))
		dismantle.visible=not active and str(campaign.s.phase) in ["shop","supply"]
		dismantle.name="city_deck_dismantle_"+id
		dismantle.pressed.connect(_confirm_part_dismantle.bind(id))
	for button in view.find_children("*","Button",true,false):
		if not str(button.name).begins_with("equipped_part_detail_") and not str(button.name).begins_with("city_part_select_"): continue
		for child in button.get_children():
			if child is PartCard:
				child.selected_visual=str(child.part_id)==id
				child.outgoing_visual=str(child.part_id)==outgoing
				child.queue_redraw()
		for key in ["normal","hover","pressed","focus","disabled"]: button.add_theme_stylebox_override(key,StyleBoxEmpty.new())
	ui._workspace_focus_chain.call_deferred()

func _confirm_part_dismantle(id: String) -> void:
	ui._confirmation("파츠 분해", "%s을 분해해 10Cr를 받습니다.\n분해한 파츠는 보관함에서 사라집니다." % Ammo.PARTS[id].name, "PartDismantleConfirmation", "분해 · +10Cr", "보관", _apply_part_change.bind("dismantle", id, id))

func _apply_part_change(command: String, value: String, selected: String) -> void:
	selected_part_id = selected
	ui._close_workspace()
	action(command, value, selected if command == "replace_part" else "")
	workspace_feedback = "구성을 적용했습니다." if command != "dismantle" else "%s 분해 · +10Cr" % Ammo.PARTS[selected].name
	deck.call_deferred("parts")


## 기록실 (2026-11-08): records by region with a reading panel, and the supply
## preferences, in the workshop/gate/depot theme. Registered as the workspace overlay.
func archive(initial_tab: String = "records") -> void:
	ui._close_workspace()
	var prior: Control = ui.get_viewport().gui_get_focus_owner()
	if prior != null: ui.workspace_return_focus = weakref(prior)
	var view = ArchiveRoom.new()
	view.name = "WorkspaceOverlay"
	view.configure(ui, self, initial_tab)
	ui.add_child(view)
	ui.workspace_overlay = view

## Gate scene (approved 2026-11-05 threshold review), linked to the live run 2026-11-07.
## Older gate rules keep gate() below.
func modern_gate() -> void:
	var view := GateScreen.instantiate()
	view.name = "GateScreen"
	# Fill the screen exactly (no 540 floor): the scene is a fixed stage, not a scroll page.
	view.custom_minimum_size.y = ui.ReadableUI.available(ui).size.y
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.configure(ui, self)
	ui.body.add_child(view)

## Depot scene (3rd draft, approved 2026-11-08): offers on the bottom shelf, swap
## switches the shelf to owned stacks. Saves without the place revision keep service().
func modern_depot() -> void:
	var view := DepotScreen.instantiate()
	view.name = "DepotScreen"
	view.custom_minimum_size.y = ui.ReadableUI.available(ui).size.y
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.configure(ui, self)
	ui.body.add_child(view)

## Event scene (approved 2026-11-08): corridor art, story panel with clue choices,
## result plus one action; found rounds add or swap on the bottom shelf.
func modern_event() -> void:
	var view := EventScreen.instantiate()
	view.name = "EventScreen"
	view.custom_minimum_size.y = ui.ReadableUI.available(ui).size.y
	view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view.configure(ui, self)
	ui.body.add_child(view)

func modern_workshop() -> void:
	var view := preload("res://redesign/workbench/screen.tscn").instantiate()
	view.custom_minimum_size.y = maxf(540, ui.ReadableUI.available(ui).size.y)
	ui.body.add_child(view)
	view.configure(ui, self)

func workshop_refit() -> void:
	var panel = ui._workspace("탄종 교체", "후보를 고른 뒤 내보낼 탄 한 장을 선택합니다. 확정하면 이번 무료 정비를 사용합니다.")
	panel = _collection_workspace(panel, 870)
	var grid := _service_ammo_grid(panel)
	for id in campaign.workshop_ammo_options():
		var cell = ui._panel(grid)
		ammo_card(cell, id)
		var replaceable: bool = campaign.replaceable_ammo().any(func(source): return campaign.can_acquire_ammo(id, source))
		ui._button(cell, "내보낼 탄 선택", "city_refit_" + id, acquire_ammo.bind(id, "resolve", "refit", id), not replaceable)

func modern_supply() -> void:
	var host := _place_frame()
	var workshop: bool = bool(campaign.node().get("workshop", false))
	_service_place(host, "workshop" if workshop else "supply", str(campaign.node().name), str(campaign.s.message) if campaign.s.resolved else "보유 탄을 보충하거나 새로운 탄환을 확보하세요.\n무료로 한 장을 가져갈 수 있습니다.")
	if campaign.s.resolved:
		var footer := _place_footer()
		var build := _place_action(footer, "내 빌드 확인", "city_service_build", deck)
		build.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		_footer_button(footer, "맵으로 계속  ›", "city_leave", action.bind("leave"), true)
		return
	_place_section("가져갈 탄환 선택 · 1장")
	var row := _service_ammo_grid(host)
	for id in campaign.reward_options():
		var cell = ui._panel(row)
		cell.get_parent().custom_minimum_size.x = 262
		ammo_card(cell, id)
		_choice_note(cell, "보유 탄 보충 · 동일 성능 %d장" % ui.model.s.deck.count(id) if ui.model.s.deck.has(id) else "새 탄환 발견")
		var claim := _place_action(cell, "1장 확보", "city_supply_" + id, acquire_ammo.bind(id,"resolve","ammo",id), not can_take_ammo(id), 160)
		claim.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_footer_button(_place_footer(), "보급 없이 계속", "city_service_skip", action.bind("resolve", "skip"))

func encounter_service() -> void:
	var host := _place_frame()
	var scene: Dictionary = campaign.encounter_scene()
	var stage: String = campaign.s.get("encounter", {}).get("stage", "")
	_service_place(host, "supply", str(scene.title), str(scene.text) if stage.is_empty() else str(campaign.s.message), true)
	if campaign.s.resolved:
		_footer_button(_place_footer(), "맵으로 계속  ›", "city_leave", action.bind("leave"), true)
	elif stage == "ambush":
		_place_section("적이 길을 막았습니다. 탄환을 준비하세요.")
		_footer_button(_place_footer(), "전투 준비", "city_encounter_fight", action.bind("resolve", "fight"), true)
	elif stage == "loot":
		_place_section("발견한 탄환 · 1장 선택")
		var row := _service_ammo_grid(host)
		for id in campaign.reward_options():
			var cell = ui._panel(row)
			cell.get_parent().custom_minimum_size.x = 262
			ammo_card(cell, id)
			var claim := _place_action(cell, "1장 확보", "city_event_ammo_" + id, acquire_ammo.bind(id,"resolve","ammo",id), not can_take_ammo(id), 160)
			claim.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_footer_button(_place_footer(), "탄환을 남기고 계속", "city_service_skip", action.bind("resolve", "skip"))
	else:
		_place_section("어떻게 행동할까요?")
		var row := ui._row(host) as HBoxContainer
		row.name = "EncounterChoices"
		row.add_theme_constant_override("separation", 12)
		for option in scene.choices:
			var cell = ui._panel(row)
			var hint := _choice_note(cell, str(option.hint), 20)
			hint.custom_minimum_size.y = ui._scaled(56)
			var caption: String = option.label + (" · %dCr" % int(option.cost) if int(option.cost) > 0 else "")
			_place_action(cell, caption, "city_encounter_" + str(option.id), action.bind("resolve", "encounter", str(option.id)), int(campaign.s.credits) < int(option.cost), 260)
		_footer_button(_place_footer(), "관여하지 않고 지나간다", "city_service_skip", action.bind("resolve", "skip"))

func _service_ammo_grid(parent: Node) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3 if ui.size.x >= 900 else 2 if ui.size.x >= 620 else 1
	grid.size_flags_horizontal = Control.SIZE_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	parent.add_child(grid)
	return grid
