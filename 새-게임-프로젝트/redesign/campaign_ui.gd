extends RefCounted
const Data = preload("res://redesign/campaign_content.gd")
const Ammo = preload("res://redesign/content.gd")
const MapView = preload("res://redesign/city_map_view.gd")
const Card = preload("res://redesign/ammo_card_view.gd")
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
	for entry in [["덱·장비", "city_deck", deck], ["기록실", "city_archive", archive], ["메뉴", "menu", ui._to_menu]]:
		var button = ui._button(top, entry[0], entry[1], entry[2])
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		button.custom_minimum_size.x = 115
	ui._label(ui.body, "LV.%d   ·   %dCr   ·   %s   ·   %d칸   ·   덱 %d장   ·   난도 %d%s" % [int(Data.info(int(state.region)).base_level) + maxi(1, int(state.floor)) - 1, state.credits, Ammo.GUNS[state.gun].name, ui.model.capacity(), ui.model.s.deck.size(), state.difficulty, "   /   다음 전투 −2m" if int(state.pressure) > 0 else ""], 18, ui.MUTED)
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

func map_screen() -> void:
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
	ui._label(ui.body, "밝은 경로로 이동 · 다른 방을 누르면 미리 보기 · 환기구 비용은 다음 전투까지 유지", 17, ui.MUTED)

func inspect_node(id: int) -> void:
	var item: Dictionary = {}
	for candidate in campaign.current_nodes():
		if int(candidate.id) == id: item = candidate
	if item.is_empty(): return
	var panel = ui._dialog(str(item.name), true)
	ui._label(panel, Data.hint(item), 22)
	ui._label(panel, "계단 · 무료" if item.route == "stairs" else "환기구 · 다음 전투 시작 거리 −2m", 18, ui.ACCENT)
	if item.kind in ["combat", "boss"]:
		var enemies := Data.encounter(item, int(campaign.s.seed), str(campaign.s.gun), int(campaign.s.difficulty), 2 if item.route == "duct" or int(campaign.s.pressure) > 0 else 0)
		ui._label(panel, Insight.threat_line(enemies), 18)
		for enemy in enemies: ui._label(panel, "%s · HP%d · 장갑%d · %dm / 전진%d" % [enemy.name, enemy.hp, enemy.def, enemy.distance, enemy.speed], 17, ui.MUTED)

func reward() -> void:
	ui._label(ui.body, str(campaign.node().name) + " 통과", 34, ui.ACCENT)
	ui._label(ui.body, Insight.combat_report_line(campaign.encounter_report_state()), 19, ui.MUTED)
	ui._label(ui.body, "탄환으로 지금 강화할까, 크레딧을 모아 무기고에서 고를까?", 22)
	var row = ui._row(ui.body)
	for id in Data.rewards(campaign.node(), int(campaign.s.seed)):
		var panel = ui._panel(row)
		ammo_card(panel, id)
		ui._label(panel, ui.Readability.description(id, ui.model.s), 18)
		ui._button(panel, "1장 가져가기", "city_reward_" + id, action.bind("reward", id), ui.model.s.deck.size() >= 14)
	var wallet = ui._panel(row)
	ui._label(wallet, "+%d Cr" % campaign.credit_reward(), 42, ui.ACCENT)
	ui._label(wallet, "전투 소모가 적을수록 배급 증가\n상점 탄환 12Cr / 파츠 30Cr", 18, ui.MUTED)
	ui._button(wallet, "크레딧 받기", "city_reward_credits", action.bind("reward", "credits"))
	ui._button(ui.body, "현재 구성을 유지하고 계속", "city_reward_skip", action.bind("reward", "skip"))
	ui._button(ui.body, "보상 대신 덱 1장 정제", "city_reward_refine", refine_dialog.bind(false), ui.model.s.deck.size() <= 6)

func shop() -> void:
	ui._label(ui.body, str(campaign.node().name), 34, ui.ACCENT)
	var row = ui._row(ui.body)
	for i in range(campaign.s.offers.size()):
		var offer: Dictionary = campaign.s.offers[i]
		var panel = ui._panel(row)
		if offer.type == "ammo": ammo_card(panel, str(offer.id))
		else:
			ui._label(panel, Ammo.PARTS[offer.id].name, 26, ui.ACCENT)
			ui._label(panel, Ammo.PARTS[offer.id].text, 19)
		var locked: bool = offer.type == "part" and campaign.s.shop_part_bought and not offer.sold
		var title := "구매 완료" if offer.sold else ("이번 방문 파츠 선택 완료" if locked else "%dCr · %s" % [offer.price, "구매·장착" if offer.type == "part" else "덱에 추가"])
		ui._button(panel, title, "city_buy_" + str(i), action.bind("buy", i), offer.sold or locked or int(campaign.s.credits) < int(offer.price) or (offer.type == "ammo" and ui.model.s.deck.size() >= 14))
	ui._button(ui.body, "진열 갱신 · 3Cr", "city_reroll", action.bind("reroll"), int(campaign.s.credits) < 3)
	ui._label(ui.body, "파츠는 방문당 1개 · 갱신해도 한도 유지 · 확장 탄창은 관문 보상", 17, ui.MUTED)
	ui._button(ui.body, "덱 1장 정제 · 12Cr · 방문당 1회", "city_shop_refine", refine_dialog.bind(true), campaign.s.get("shop_refined", false) or int(campaign.s.credits) < 12 or ui.model.s.deck.size() <= 6)
	equipment(ui.body)
	ui._button(ui.body, "맵으로 계속", "city_leave", action.bind("leave"))

func equipment(parent: Node) -> void:
	var panel = ui._panel(parent)
	ui._label(panel, "장착 / " + str(Ammo.PARTS[ui.model.s.part].name), 22, ui.ACCENT)
	var row = ui._row(panel)
	for id in campaign.s.parts:
		var column = ui._panel(row)
		ui._button(column, Ammo.PARTS[id].name + (" · 장착 중" if ui.model.s.part == id else " · 교체"), "city_equip_" + id, action.bind("equip", id), ui.model.s.part == id)
		ui._button(column, "분해 · +10Cr", "city_dismantle_" + id, action.bind("dismantle", id), ui.model.s.part == id or not campaign.s.phase in ["shop", "supply"])
	if not campaign.s.parts.is_empty(): ui._button(panel, "파츠 해제", "city_equip_none", action.bind("equip", "none"), ui.model.s.part == "none")
	else: ui._label(panel, "구매한 파츠가 여기에 보관됩니다.", 18, ui.MUTED)

func service() -> void:
	ui._label(ui.body, str(campaign.node().name), 34, ui.ACCENT)
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
		remove_choices("remove", "1장 정제", "city_refine_")
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
		ui._button(grid, "%s\n%s" % [Ammo.AMMO[id].name, title], prefix + id, action.bind("resolve", choice, id), ui.model.s.deck.size() <= 6)
	ui._label(ui.body, "정제·분해는 최소 6장을 유지합니다.", 17, ui.MUTED)

func refine_dialog(paid: bool) -> void:
	var panel = ui._dialog("정제할 탄환 · 1장 제거", true)
	ui._label(panel, "12Cr · 방문당 한 번" if paid else "이번 전투 보상을 대신 사용", 21, ui.ACCENT)
	var grid := GridContainer.new()
	grid.columns = 2
	panel.add_child(grid)
	var seen: Array = []
	for id in ui.model.s.deck:
		if seen.has(id): continue
		seen.append(id)
		ui._button(grid, "%s ×%d\n1장 제거" % [Ammo.AMMO[id].name, ui.model.s.deck.count(id)], "city_refine_pick_" + id, func():
			panel.get_meta("dialog").hide()
			panel.get_meta("dialog").queue_free()
			if paid: action("shop_refine", id)
			else: action("reward", "remove", id)
		, ui.model.s.deck.size() <= 6)
	ui._label(panel, "최소 6장을 유지합니다. 정제할수록 원하는 탄환이 자주 돌아옵니다.", 17, ui.MUTED)

func gate() -> void:
	ui._label(ui.body, "승강기가 다음 계층을 허락했다.", 34, ui.ACCENT)
	ui._label(ui.body, Data.info(int(campaign.s.region) + 1).name + " / " + Data.info(int(campaign.s.region) + 1).brief, 23)
	var row = ui._row(ui.body)
	ui._button(row, "탄창 %d → %d칸\n성장은 파츠를 교체해도 유지" % [ui.model.capacity(), ui.model.capacity() + 1], "city_gate_slot", action.bind("gate", "slot"), int(campaign.s.slots) >= 2)
	ui._button(row, "+24Cr\n다음 무기고를 위한 저축", "city_gate_credits", action.bind("gate", "credits"))

func ending() -> void:
	var won: bool = campaign.s.phase == "won"
	ui._label(ui.body, "당신은 아직 인간이다." if won else "등반은 여기서 멈췄다.", 44, ui.ACCENT if won else ui.DANGER)
	ui._label(ui.body, "정점은 개조를 권한다. 당신은 거부하고, 그 자리에 선다." if won else "적이 닿기 전에 완성할 순서를 다시 설계해 보세요.", 23)
	ui._label(ui.body, "%d / 35층 · %d전투 통과 · %d턴 · %d발 · 재장전%d회" % [campaign.absolute_floor(), campaign.s.clears, ui.model.s.turns, ui.model.s.shots, ui.model.s.reloads], 21, ui.MUTED)
	ui._label(ui.body, Insight.combat_report_line(ui.model.s), 19, ui.ACCENT)
	ui._label(ui.body, str(campaign.s.message), 22)
	ui._label(ui.body, "최종 덱 / " + Insight.deck_summary(ui.model.s.deck), 19)
	var row = ui._row(ui.body)
	ui._button(row, "같은 경로로 다시 등반", "retry", ui._start.bind(str(campaign.s.gun), true))
	ui._button(row, "기록실", "city_archive", archive)
	ui._button(row, "새 등반 선택", "new_run", ui._to_menu)

func deck() -> void:
	var panel = ui._dialog("덱·장비")
	ui._label(panel, "덱 %d / 14장 · 탄창 %d칸" % [ui.model.s.deck.size(), ui.model.capacity()], 26, ui.ACCENT)
	ui._label(panel, Insight.deck_summary(ui.model.s.deck), 21)
	ui._label(panel, Ammo.PARTS[ui.model.s.part].name + " / " + Ammo.PARTS[ui.model.s.part].text, 20)
	for id in campaign.s.parts: ui._label(panel, "보관 / " + Ammo.PARTS[id].name, 19, ui.MUTED)

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
	ui._label(panel, "도시 기록 %d / 20" % profile.lore.size(), 24, ui.ACCENT)
	for id in range(1, 21):
		if profile.lore.has(id):
			var entry := Lore.entry(id)
			ui._label(panel, "%02d / %s" % [id, entry.title], 21)
			ui._label(panel, entry.text, 19, ui.MUTED)
		else: ui._label(panel, "%02d / 미복원" % id, 18, ui.MUTED)
