extends Control
## Isolated design prototype. Uses the production purchase model; never loads/saves a run.
const Data = preload("res://redesign/content.gd")
const Campaign = preload("res://redesign/campaign.gd")
const CardView = preload("res://redesign/ammo_card_view.gd")
var campaign = Campaign.new()
var selected := 0
var inspecting := ""
var replace_mode := false
var bag_page := 0
var bag_ids: Array = []
var rules_open := false

func field(key: String) -> Node:
	return find_child(key, true, false)

func _ready() -> void:
	get_window().content_scale_size = Vector2i(1600, 900)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	get_window().title = "ORVASK · 상점 UI 시안"
	for i in range(3): field("Offer%d" % i).pressed.connect(select_offer.bind(i))
	for i in range(5): field("Slot%d" % i).pressed.connect(inspect_slot.bind(i))
	for i in range(4): field("AmmoRow%d" % i).pressed.connect(select_bag_row.bind(i))
	field("Reset").pressed.connect(reset)
	field("Reroll").pressed.connect(reroll)
	field("Buy").pressed.connect(purchase.bind(""))
	field("Replace").pressed.connect(open_bag.bind(true))
	field("Bag").pressed.connect(open_bag.bind(false))
	field("Charge").pressed.connect(charge)
	field("Exit").pressed.connect(func(): get_tree().quit())
	field("CloseOverlay").pressed.connect(close_bag)
	field("Details").pressed.connect(open_rules)
	field("NextPage").pressed.connect(func(): bag_page += 1; refresh_bag())
	reset()

func reset() -> void:
	campaign = Campaign.new()
	campaign.start("burst", 251025, 0, "balanced", Campaign.Content.RouteMap.VERSION, "carrier")
	for room in campaign.current_nodes():
		if room.kind == "shop":
			campaign.s.node = room.id
			break
	campaign.s.phase = "shop"
	campaign.s.credits = 75
	campaign.s.parts = ["volley_drive", "radiator"]
	campaign.s.equipped_parts = campaign.s.parts.duplicate()
	campaign._sync_equipped_parts()
	campaign.model.s.deck = ["basic_p1", "basic_p1", "basic_p1", "basic_p1", "basic_p1", "basic_p1", "basic_p1", "basic_p1", "basic_p2", "basic_p2", "basic_p2", "basic_p2", "basic_p2", "basic_p2", "basic_p2", "basic_p2", "pierce_p2", "pierce_p2", "precise_p1", "precise_p1"]
	campaign.s.offers = [{"id":"precise_p1", "type":"ammo", "price":12, "sold":false}, {"id":"supply", "type":"part", "price":30, "sold":false}, {"id":"lens", "type":"part", "price":30, "sold":false}]
	selected = 0
	inspecting = ""
	rules_open = false
	field("Overlay").hide()
	field("Feedback").text = ""
	field("PartName").text = "코어 · 연쇄 구동핵"
	refresh()

func select_offer(index: int) -> void:
	selected = index
	inspecting = ""
	field("Feedback").text = ""
	refresh()

func refresh() -> void:
	var state: Dictionary = campaign.model.s
	field("Wallet").text = "%d Cr" % int(campaign.s.credits)
	field("DeckCount").text = "보유 탄약 %d / 32" % state.deck.size()
	var counts := {}
	for id in state.deck:
		var family := Data.source_id(str(id))
		counts[family] = int(counts.get(family, 0)) + 1
	var chips: PackedStringArray = []
	for family in counts: chips.append("%s %d" % [str(Data.AMMO[family].name).trim_suffix("탄"), counts[family]])
	field("Composition").text = "  ·  ".join(chips)
	field("Composition").text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	field("ChargeInfo").text = "압축 충전 %d / 2" % int(campaign.s.compressor_charges)
	field("Charge").disabled = campaign.s.shop_compressor_bought or campaign.s.compressor_charges >= 2 or campaign.s.credits < 18
	field("Charge").text = "충전 완료" if campaign.s.shop_compressor_bought else "1회 충전 · 18 Cr"
	field("Reroll").text = "새 진열 · %d Cr" % campaign.reroll_cost()
	field("Reroll").disabled = campaign.s.credits < campaign.reroll_cost()
	field("SlotCount").text = "%d / 5" % campaign.s.equipped_parts.size()
	field("Weapon").text = "%s   탄창 %d   열 한계 %d" % [Data.GUNS[state.gun].name, Data.capacity(state), Data.heat_limit(state)]
	for i in range(5):
		var slot: Button = field("Slot%d" % i)
		var icon = slot.get_node("Icon")
		var occupied: bool = i < campaign.s.equipped_parts.size()
		var core: bool = occupied and Data.is_core_part(str(campaign.s.equipped_parts[i]))
		slot.get_node("CoreBadge").visible = core
		icon.offset_bottom = -16.0 if core else 0.0
		icon.visible = occupied
		slot.text = "" if occupied else "+"
		if occupied:
			icon.item_id = campaign.s.equipped_parts[i]
			slot.tooltip_text = Data.PARTS[icon.item_id].name
		else: slot.tooltip_text = "빈 장착대"
	for i in range(3):
		var card: Button = field("Offer%d" % i)
		if i >= campaign.s.offers.size(): card.hide(); continue
		card.show()
		var offer: Dictionary = campaign.s.offers[i]
		var id := str(offer.id)
		var ammo: bool = offer.type == "ammo"
		var spec: Dictionary = Data.AMMO[id] if ammo else Data.PARTS[id]
		card.add_theme_stylebox_override("normal", load("res://assets/ui/shop_preview/offer_%s.tres" % ("selected" if i == selected and inspecting.is_empty() else "normal")))
		card.find_child("Kind").text = "탄환" if ammo else ("코어" if Data.is_core_part(id) else "파츠")
		var upgraded: bool = (Data.grade(id) if ammo else int(spec.get("grade", 0))) > 0
		card.find_child("Grade").text = "고급" if upgraded else "일반"
		card.find_child("Grade").add_theme_color_override("font_color", Color("bfa678") if upgraded else Color("92a399"))
		card.find_child("Name").text = spec.name
		card.find_child("Stat").text = ("%s %s" % [Data.primary_stat(id, state).label, Data.primary_stat(id, state).value]) if ammo else ("탄창 +1" if id == "supply" else str(spec.value))
		card.find_child("Description").text = ammo_note(id) if ammo else spec.effect
		card.find_child("Heat").text = "열 %s" % Data.heat_label(id, state) if ammo else ""
		card.find_child("Owned").text = "보유 %d장" % state.deck.count(id) if ammo else ("보유 중" if campaign.s.parts.has(id) else "")
		card.find_child("Price").text = "구매 완료" if offer.sold else "%d Cr" % int(offer.price)
		var icon = card.find_child("Icon")
		icon.is_part = not ammo
		icon.item_id = id
		card.modulate = Color(0.58, 0.64, 0.62) if offer.sold else Color.WHITE
	show_details()

func show_details() -> void:
	var state: Dictionary = campaign.model.s
	var offer: Dictionary = campaign.s.offers[selected]
	var owned := not inspecting.is_empty()
	var id := inspecting if owned else str(offer.id)
	var ammo: bool = not owned and offer.type == "ammo"
	var spec: Dictionary = Data.AMMO[id] if ammo else Data.PARTS[id]
	var part_kind := "코어" if not ammo and Data.is_core_part(id) else "파츠"
	field("Eyebrow").text = "장착 중인 " + part_kind if owned else ("선택한 물건   /   " + ("탄환" if ammo else part_kind))
	field("ItemName").text = spec.name
	field("DetailText").text = "같은 적에게 두 번 타격합니다." if ammo and Data.source_id(id) == "precise" else (str(spec.text) if ammo else str(spec.get("upside", spec.text)))
	field("AffinityTitle").text = "내 장비와의 연결"
	field("ChangeTitle").text = "현재 효과" if owned else "구매 시 변화"
	if ammo:
		field("Change").text = "보유 탄약   %d → %d장\n동일 성능   %d → %d장" % [state.deck.size(), state.deck.size() + 1, state.deck.count(id), state.deck.count(id) + 1]
		field("Affinity").text = "각 타격에 코어 피해 +1\n처치 후 남은 타격은 다음 적으로" if Data.source_id(id) == "precise" else (ammo_note(id) + ("\n직접 타격에 코어 피해 +1" if Data.is_attack(id) else "\n직접 피해 대신 탄창을 지원"))
		field("Cost").text = "적용 발열 %s  ·  탄창 %d칸" % [Data.heat_label(id, state), Data.slot_cost(id)]
	else:
		var proposed := state.duplicate(true)
		if not owned and campaign.can_equip_reward(id): proposed.equipped_parts.append(id)
		if id == "supply":
			field("Change").text = "탄창   %d → %d칸" % [Data.capacity(state), Data.capacity(proposed)]
			field("Affinity").text = "래칫 · 연쇄 사격\n탄창을 더 채워 발사할 수 있습니다."
			field("Cost").text = "가방 크기와 열 한계는 그대로"
		elif id == "lens":
			field("Change").text = "철갑탄 관통   %d → %d" % [Data.penetration("pierce_p2", state), Data.penetration("pierce_p2", proposed)]
			field("Affinity").text = "보유 철갑탄 2장에 적용\n관통이 있는 탄환을 강화합니다."
			field("Cost").text = "기본탄·연타탄에 관통을 부여하지 않음"
		else:
			field("Change").text = str(spec.value)
			field("Affinity").text = str(spec.get("role", ""))
			field("Cost").text = str(spec.get("downside", ""))
		if not owned and not campaign.can_equip_reward(id): field("Change").text = "장착 조건 불충족 · 보관함에 추가"
	var affordable: bool = campaign.s.credits >= int(offer.price)
	field("Buy").visible = not owned
	field("Balance").visible = not owned
	field("Replace").visible = ammo and not owned and not offer.sold
	field("Buy").text = ("%d Cr · 한 장 추가" if ammo else "%d Cr · 구매 후 장착" if campaign.can_equip_reward(id) else "%d Cr · 구매 후 보관") % int(offer.price)
	if offer.sold: field("Buy").text = "구매 완료"
	elif not affordable: field("Buy").text = "%d Cr 부족" % (int(offer.price) - int(campaign.s.credits))
	elif ammo and not campaign.can_acquire_ammo(id): field("Buy").text = "보유 탄약 가득 참 · 교체 가능"
	field("Buy").disabled = offer.sold or not affordable or (ammo and not campaign.can_acquire_ammo(id))
	field("Replace").disabled = not affordable
	field("Balance").text = "구매 완료" if offer.sold else "구매 후 %d Cr" % (int(campaign.s.credits) - int(offer.price)) if affordable else "보유 %d Cr" % int(campaign.s.credits)
	if offer.sold and not owned:
		field("ChangeTitle").text = "구매 반영 완료"
		field("Change").text = "보유 탄약 %d장 · 동일 성능 %d장" % [state.deck.size(),state.deck.count(id)] if ammo else ("장착 중" if campaign.s.equipped_parts.has(id) else "보관함에 추가됨")
	# The counter shows one decision, not the entire rulebook. Details remain available.
	if ammo and not offer.sold:
		field("Change").text = "코어 적용 · 타격당 피해 +1" if Data.is_attack(id) else ammo_note(id)
		if not campaign.can_acquire_ammo(id): field("Change").text = "탄약 가득 참 · 한 장 교체 가능"
	elif not ammo and id == "supply" and not owned and not offer.sold:
		field("Change").text = "탄창   %d → %d칸" % [Data.capacity(state), Data.capacity(proposed_state(id))] if campaign.can_equip_reward(id) else "구매 후 보관함에 추가"
	field("Cost").visible = not ammo and not str(spec.get("downside", "")).is_empty()
	if field("Cost").visible: field("Cost").text = str(spec.downside)
	field("Affinity").hide()
	field("AffinityTitle").hide()
	field("ChangeTitle").hide()
	field("Buy").text = "구매 완료" if offer.sold else field("Buy").text
	field("Buy").visible = not owned

func proposed_state(id: String) -> Dictionary:
	var result: Dictionary = campaign.model.s.duplicate(true)
	if campaign.can_equip_reward(id): result.equipped_parts.append(id)
	return result

func open_rules() -> void:
	rules_open = true
	var offer: Dictionary = campaign.s.offers[selected]
	var id := str(offer.id) if inspecting.is_empty() else inspecting
	var ammo: bool = inspecting.is_empty() and offer.type == "ammo"
	var spec: Dictionary = Data.AMMO[id] if ammo else Data.PARTS[id]
	field("ModalTitle").text = str(spec.name)
	field("ModalHint").text = "탄환 상세" if ammo else ("코어 상세" if Data.is_core_part(id) else "파츠 상세")
	var description := str(spec.text)
	if ammo:
		description += "\n\n적용 발열 %s · 탄창 %d칸" % [Data.heat_label(id, campaign.model.s), Data.slot_cost(id)]
		description += "\n\n" + str(Data.PARTS.volley_drive.name) + "\n" + str(Data.PARTS.volley_drive.text)
	field("RulesText").text = description
	field("RulesText").scroll_to_line(0)
	field("RulesText").show()
	for i in range(4): field("AmmoRow%d" % i).hide()
	field("NextPage").hide()
	field("Overlay").show()
	field("CloseOverlay").grab_focus()

func purchase(replace_id: String) -> void:
	if campaign.buy(selected, replace_id):
		field("Overlay").hide()
		field("Feedback").text = "구매 완료 · 시안에만 반영됩니다."
	refresh()

func ammo_note(id: String) -> String:
	var card = CardView.new()
	card.setup(id, 1, campaign.model.s)
	var result: String = card.effect_text()
	card.free()
	return result

func charge() -> void:
	if campaign.buy_compressor_charge(): field("Feedback").text = "압축 충전 +1"
	refresh()

func reroll() -> void:
	if campaign.reroll(): selected = 0; inspecting = ""
	field("Feedback").text = "새 물건이 도착했습니다."
	refresh()

func inspect_slot(index: int) -> void:
	if index >= campaign.s.equipped_parts.size():
		field("Feedback").text = "새 파츠를 장착할 수 있는 빈 자리입니다."
		return
	inspecting = str(campaign.s.equipped_parts[index])
	field("PartName").text = ("코어 · " if Data.is_core_part(inspecting) else "") + str(Data.PARTS[inspecting].name)
	field("Feedback").text = "상품을 누르면 구매 화면으로 돌아갑니다."
	refresh()

func open_bag(replacing: bool) -> void:
	rules_open = false
	field("RulesText").hide()
	replace_mode = replacing
	bag_page = 0
	bag_ids = []
	for id in campaign.model.s.deck:
		if not bag_ids.has(id): bag_ids.append(id)
	field("ModalTitle").text = "교체할 탄환 선택" if replacing else "보유 탄약"
	field("ModalHint").text = "선택한 탄 한 장을 교체하고 구매합니다." if replacing else "상점 시안 전용 탄약 · 실제 저장에는 반영되지 않습니다."
	refresh_bag()
	field("Overlay").show()
	field("CloseOverlay").grab_focus()

func refresh_bag() -> void:
	if bag_page * 4 >= bag_ids.size(): bag_page = 0
	for row in range(4):
		var index := bag_page * 4 + row
		var button: Button = field("AmmoRow%d" % row)
		button.visible = index < bag_ids.size()
		if not button.visible: continue
		var id: String = bag_ids[index]
		button.text = "%s  ·  피해 %s  ·  발열 %s     ×%d" % [Data.AMMO[id].name, Data.primary_stat(id, campaign.model.s).value, Data.heat_label(id, campaign.model.s), campaign.model.s.deck.count(id)]
		button.disabled = replace_mode and not campaign.can_acquire_ammo(str(campaign.s.offers[selected].id), id)
	field("NextPage").visible = bag_ids.size() > 4

func select_bag_row(row: int) -> void:
	if replace_mode: purchase(str(bag_ids[bag_page * 4 + row]))

func close_bag() -> void:
	field("Overlay").hide()
	field("Details" if rules_open else "Bag").grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if field("Overlay").visible: close_bag()
		else: get_tree().quit()
