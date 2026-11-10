extends Control
## Production binding for the approved shop composition. All writes use the run host.
const Data = preload("res://redesign/content.gd")
const Readability = preload("res://redesign/readability.gd")
const Lore = preload("res://redesign/city_story.gd")
const Actors = preload("res://redesign/service_actor_catalog.gd")
const Card = preload("res://redesign/ammo_card_view.gd")
var host
var campaign
var selected := 0
var inspecting := ""
var replace_mode := false
var bag_page := 0
var bag_ids: Array = []
var return_button := "Bag"
var pending := false
var fit_queued := false

func configure(screen) -> void:
	host = screen
	campaign = screen.campaign
	selected = clampi(host.city_ui.shop_selection, 0, maxi(0, campaign.s.offers.size() - 1))

func field(key: String) -> Node:
	return find_child(key, true, false)

func _ready() -> void:
	field("Overlay").theme = $Canvas.theme
	resized.connect(_fit_canvas)
	$Canvas/Safe/Layout.minimum_size_changed.connect(_queue_fit)
	_fit_canvas()
	if campaign == null: return
	for i in range(3): field("Offer%d" % i).pressed.connect(select_offer.bind(i))
	for i in range(5): field("Slot%d" % i).pressed.connect(inspect_slot.bind(i))
	for i in range(4): field("AmmoRow%d" % i).pressed.connect(select_bag_row.bind(i))
	field("Menu").pressed.connect(host._to_menu)
	field("Settings").pressed.connect(host._settings)
	field("Manage").pressed.connect(host.city_ui.deck.bind("parts"))
	field("Reroll").pressed.connect(dispatch.bind("reroll", "", ""))
	field("Buy").pressed.connect(purchase.bind(""))
	field("Replace").pressed.connect(open_bag.bind(true))
	field("Bag").pressed.connect(open_bag.bind(false))
	field("Charge").pressed.connect(dispatch.bind("buy_compressor", "", ""))
	field("Exit").pressed.connect(dispatch.bind("leave", "", ""))
	field("CloseOverlay").pressed.connect(close_overlay)
	field("Details").pressed.connect(open_rules)
	field("NextPage").pressed.connect(func(): bag_page += 1; refresh_bag())
	field("LegacyCompress").pressed.connect(host.city_ui.compression_dialog.bind("shop"))
	field("LegacyTune").pressed.connect(host.city_ui.tune_choices)
	var text_scale := float(host.preferences.data.get("text_scale", 1.0))
	if not is_equal_approx(text_scale, 1.0):
		for node in find_children("*", "Control", true, false):
			for key in ["font_size", "normal_font_size"]:
				if node.has_theme_font_size_override(key): node.add_theme_font_size_override(key, roundi(node.get_theme_font_size(key) * text_scale))
	refresh()

func _fit_canvas() -> void:
	if size.x <= 0 or size.y <= 0: return
	# Reflow the authored composition; never shrink glyphs with the whole page.
	$Canvas.scale = Vector2.ONE
	$Canvas.size = size
	var narrow := size.x < 1100
	var edge := 16
	for side in ["left","right","top","bottom"]:
		$Canvas/Safe.add_theme_constant_override("margin_"+side,edge)
	field("Overview").vertical = size.x < 720
	field("SelectionRow").vertical = narrow
	field("Footer").vertical = size.x < 900
	for key in ["Inspector", "InspectorFooter", "Detail"]:
		field(key).custom_minimum_size.x = 0 if narrow and key == "Detail" else 300 if size.x < 1280 else 352
	field("Room").custom_minimum_size = Vector2(180 if size.x < 1100 else 240,120)
	field("StoryScroll").custom_minimum_size = Vector2(180 if size.x < 1100 else 220,180)
	field("Story").custom_minimum_size.y = 180
	field("Location").text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	field("Wallet").custom_minimum_size.x = 100
	field("Menu").custom_minimum_size.x = 88
	field("Settings").custom_minimum_size.x = 80
	for i in range(3):
		var card: Control = field("Offer%d" % i)
		card.find_child("Name").add_theme_font_size_override("font_size",16 if size.x < 1200 else 32)
		card.find_child("Price").add_theme_font_size_override("font_size",16)
		card.find_child("Price").autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.find_child("Icon").custom_minimum_size.y = 72
		for margin in card.find_children("Inset","MarginContainer",true,false):
			for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,8)
	field("Detail").custom_minimum_size.y = 240 if narrow else 324
	for key in ["Change", "Buy", "Replace", "ModalHint"]:
		field(key).add_theme_font_size_override("font_size",16)
	for key in ["Buy", "Replace", "ModalHint"]: field(key).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if host != null:
		var safe := preload("res://redesign/ui_readability.gd").available(host)
		field("Center").set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		field("Center").position = safe.position
		field("Center").size = safe.size
		field("Modal").custom_minimum_size = Vector2(minf(720,safe.size.x-32),0)
		field("ModalScroll").custom_minimum_size.y = minf(560,maxf(120,safe.size.y-160))
	custom_minimum_size.y = $Canvas/Safe/Layout.get_combined_minimum_size().y + edge*2

func _queue_fit() -> void:
	if fit_queued: return
	fit_queued = true
	_fit_later.call_deferred()

func _fit_later() -> void:
	fit_queued = false
	if is_inside_tree(): _fit_canvas()

func select_offer(index: int) -> void:
	selected = index
	host.city_ui.shop_selection = index
	inspecting = ""
	refresh()

func refresh() -> void:
	var state: Dictionary = campaign.model.s
	field("Location").text = campaign.region_info().name
	field("Wallet").text = "%d Cr" % int(campaign.s.credits)
	var story: Dictionary = Lore.SHOPS[clampi(int(campaign.s.region), 0, Lore.SHOPS.size() - 1)]
	field("Title").text = story.place
	field("Greeting").text = story.greeting
	var paragraphs: PackedStringArray = str(story.story).split("\n", true, 1)
	field("Narration").text = paragraphs[0]
	field("Voice").text = paragraphs[1] if paragraphs.size() > 1 else ""
	field("Hero").profile = Actors.resolve(str(state.outfit), "shop").profile
	field("DeckCount").text = "보유 탄약 %d / %d" % [state.deck.size(), campaign.model.deck_limit()]
	var counts := {}
	for id in state.deck:
		var family := Data.source_id(str(id))
		counts[family] = int(counts.get(family, 0)) + 1
	var chips: PackedStringArray = []
	for family in counts: chips.append("%s %d" % [str(Data.AMMO[family].name).trim_suffix("탄"), counts[family]])
	field("Composition").text = " · ".join(chips)
	field("Composition").tooltip_text = field("Composition").text
	field("ChargeInfo").text = "압축 충전 %d / %d" % [campaign.s.compressor_charges, campaign.MAX_COMPRESSOR_CHARGES]
	field("Charge").disabled = campaign.s.shop_compressor_bought or campaign.s.compressor_charges >= campaign.MAX_COMPRESSOR_CHARGES or campaign.s.credits < campaign.COMPRESSOR_PRICE
	field("Charge").text = "충전 완료" if campaign.s.shop_compressor_bought else ("최대 충전" if campaign.s.compressor_charges >= campaign.MAX_COMPRESSOR_CHARGES else "1회 충전 · %d Cr" % campaign.COMPRESSOR_PRICE)
	field("Reroll").text = "새 진열 · %d Cr" % campaign.reroll_cost()
	field("Reroll").disabled = campaign.s.credits < campaign.reroll_cost()
	field("SlotCount").text = "%d / %d" % [campaign.equipped_parts().size(), campaign.MAX_EQUIPPED_PARTS]
	field("Weapon").text = "%s   탄창 %d   열 한계 %d" % [Data.GUNS[state.gun].name, Data.capacity(state), Data.heat_limit(state)]
	var core := ""
	for id in campaign.equipped_parts():
		if Data.is_core_part(id): core = id
	field("PartName").text = ("코어 · " + str(Data.PARTS[core].name)) if not core.is_empty() else "코어 미장착"
	for i in range(5):
		var slot: Button = field("Slot%d" % i)
		var occupied: bool = i < campaign.equipped_parts().size()
		var icon = slot.get_node("Icon")
		var id := str(campaign.equipped_parts()[i]) if occupied else "none"
		var is_core: bool = occupied and Data.is_core_part(id)
		slot.get_node("CoreBadge").visible = is_core
		icon.offset_bottom = -16.0 if is_core else 0.0
		icon.visible = occupied
		icon.item_id = id
		slot.text = "" if occupied else "+"
		slot.tooltip_text = str(Data.PARTS[id].name) if occupied else "파츠 관리 열기"
	for i in range(3):
		var card: Button = field("Offer%d" % i)
		card.visible = i < campaign.s.offers.size()
		if not card.visible: continue
		var offer: Dictionary = campaign.s.offers[i]
		var id := str(offer.id)
		var ammo: bool = offer.type == "ammo"
		var spec: Dictionary = Data.AMMO[id] if ammo else Data.part_spec(id,campaign.model.s)
		card.add_theme_stylebox_override("normal", load("res://assets/ui/line_theme_20261101/shop_preview_offer_%s.tres" % ("selected" if i == selected and inspecting.is_empty() else "normal")))
		card.find_child("Kind").text = "탄환" if ammo else ("코어" if Data.is_core_part(id) else "파츠")
		card.find_child("Grade").text = Data.grade_name(id) if ammo else Data.part_grade_name(id)
		card.find_child("Name").text = spec.name
		card.find_child("Stat").text = ("%s %s" % [Data.primary_stat(id, state).label, Data.primary_stat(id, state).value]) if ammo else str(spec.value)
		card.find_child("Description").text = ammo_note(id) if ammo else str(spec.effect)
		card.find_child("Heat").text = "열 %s" % Data.heat_label(id, state) if ammo else ""
		card.find_child("Owned").text = "보유 %d장" % state.deck.count(id) if ammo else ("보유 중" if campaign.s.parts.has(id) else "")
		card.find_child("Price").text = "구매 완료" if offer.sold else "%d Cr" % offer.price
		if offer.get("intro_discount",false) and not offer.sold:card.find_child("Price").text="첫 연결 30 → %d Cr"%offer.price
		var icon = card.find_child("Icon")
		icon.is_part = not ammo
		icon.item_id = id
		card.modulate = Color(0.58, 0.64, 0.62) if offer.sold else Color.WHITE
	field("LegacyServices").visible = not campaign.modern_places()
	field("LegacyCompress").text = "영구 압축 · %d Cr" % campaign.COMPRESSION_PRICE
	field("LegacyCompress").disabled = campaign.s.shop_refined or campaign.s.credits < campaign.COMPRESSION_PRICE
	field("LegacyTune").visible = int(campaign.s.get("discovery_version", 0)) >= 2
	field("LegacyTune").text = "탄환 개조 · %d Cr" % campaign.TUNE_PRICE
	field("LegacyTune").disabled = campaign.s.get("shop_tuned", false) or campaign.s.credits < campaign.TUNE_PRICE
	field("Feedback").text = host.save_error
	if host.save_error.is_empty() and not campaign.s.log.is_empty():
		var event: Dictionary = campaign.s.log.back()
		if event.action in ["purchase", "purchase_compressor"]: field("Feedback").text = campaign.s.message
		elif event.action == "reroll": field("Feedback").text = "새 물건이 도착했습니다."
	field("RunNotice").visible = host.debug_session
	show_details()
	_queue_fit()

func ammo_note(id: String) -> String:
	var card = Card.new()
	card.setup(id, 1, campaign.model.s)
	var result: String = card.effect_text()
	card.free()
	return result

func current_item() -> Dictionary:
	if not inspecting.is_empty(): return {"id":inspecting, "type":"part", "owned":true, "sold":true, "price":0}
	if selected < campaign.s.offers.size(): return campaign.s.offers[selected]
	return {}

func show_details() -> void:
	var offer := current_item()
	if offer.is_empty():
		field("ItemName").text = "진열된 물건이 없습니다."
		for key in ["Buy", "Replace", "Balance", "Details", "Cost", "Change"]: field(key).hide()
		return
	var id := str(offer.id)
	var owned := bool(offer.get("owned", false))
	var ammo: bool = offer.type == "ammo"
	var spec: Dictionary = Data.AMMO[id] if ammo else Data.part_spec(id,campaign.model.s)
	var state: Dictionary = campaign.model.s
	field("ItemName").text = spec.name
	field("Details").show()
	field("Change").show()
	var can_equip: bool = not ammo and campaign.can_equip_reward(id)
	if ammo:
		field("Change").text = ammo_note(id)
	else:
		var changes: PackedStringArray = []
		if can_equip and not owned:
			var proposed := state.duplicate(true)
			proposed.equipped_parts = campaign.equipped_parts()
			proposed.equipped_parts.append(id)
			changes = host.city_ui._part_stat_changes(state, proposed)
		field("Change").text = str(spec.get("upside", spec.text)) + (" · " + " · ".join(changes) if not changes.is_empty() else "")
		if not owned and not offer.sold and not can_equip: field("Change").text = "구매 후 보관함에 추가"
	field("Cost").visible = not ammo and not str(spec.get("downside", "")).is_empty()
	field("Cost").text = str(spec.get("downside", ""))
	var affordable: bool = campaign.s.credits >= int(offer.price)
	var duplicate: bool = not ammo and campaign.s.parts.has(id)
	field("Buy").visible = not owned
	field("Balance").visible = not owned
	field("Replace").visible = ammo and not owned and not offer.sold
	field("Replace").disabled = not affordable or campaign.replaceable_ammo().filter(func(key): return campaign.can_acquire_ammo(id, key)).is_empty()
	field("Buy").text = ("%d Cr · 한 장 추가" if ammo else "%d Cr · 구매 후 장착" if can_equip else "%d Cr · 구매 후 보관") % int(offer.price)
	if offer.sold: field("Buy").text = "구매 완료"
	elif duplicate: field("Buy").text = "이미 보유한 파츠"
	elif not affordable: field("Buy").text = "%d Cr 부족" % (int(offer.price) - int(campaign.s.credits))
	elif ammo and not campaign.can_acquire_ammo(id): field("Buy").text = "탄약 가득 참 · 교체 필요"
	field("Buy").disabled = offer.sold or duplicate or not affordable or (ammo and not campaign.can_acquire_ammo(id))
	field("Balance").text = "구매 완료" if offer.sold else "구매 후 %d Cr" % (int(campaign.s.credits) - int(offer.price)) if affordable else "보유 %d Cr" % int(campaign.s.credits)
	if offer.get("intro_discount",false) and not offer.sold:field("Balance").text+=" · 첫 연결 할인 1회"
	if offer.sold and not owned: field("Change").text = "보유 %d장" % state.deck.count(id) if ammo else ("장착 중" if campaign.is_equipped(id) else "보관 중 · 파츠 관리에서 교체")

func inspect_slot(index: int) -> void:
	if index >= campaign.equipped_parts().size(): host.city_ui.deck("parts"); return
	inspecting = str(campaign.equipped_parts()[index])
	refresh()
	field("PartName").text = ("코어 · " if Data.is_core_part(inspecting) else "") + str(Data.PARTS[inspecting].name)

func dispatch(command: String, value: Variant = "", extra: String = "") -> void:
	if pending: return
	pending = true
	var count: int = campaign.s.log.size()
	host.city_ui.shop_selection = 0 if command == "reroll" else selected
	host._campaign_action(command, value, extra)
	if count == campaign.s.log.size():
		pending = false
		refresh()

func purchase(replace_id: String) -> void:
	if not inspecting.is_empty() or current_item().is_empty(): return
	dispatch("buy", selected, replace_id)

func open_rules() -> void:
	var offer := current_item()
	if offer.is_empty(): return
	var id := str(offer.id)
	var ammo: bool = offer.type == "ammo"
	field("ModalTitle").text = Data.AMMO[id].name if ammo else Data.PARTS[id].name
	field("ModalHint").text = "탄환 상세" if ammo else ("코어 상세" if Data.is_core_part(id) else "파츠 상세")
	field("RulesText").text = Readability.description(id, campaign.model.s) if ammo else str(Data.part_spec(id,campaign.model.s).text)
	field("RulesText").scroll_to_line(0)
	field("RulesText").show()
	for i in range(4): field("AmmoRow%d" % i).hide()
	field("NextPage").hide()
	return_button = "Details"
	field("ModalScroll").scroll_vertical = 0
	field("Overlay").show()
	field("CloseOverlay").grab_focus()

func open_bag(replacing: bool) -> void:
	field("RulesText").hide()
	replace_mode = replacing
	bag_page = 0
	bag_ids = []
	for id in campaign.replaceable_ammo() if replacing else campaign.model.s.deck:
		if not bag_ids.has(id): bag_ids.append(id)
	field("ModalTitle").text = "교체할 탄환 선택" if replacing else "보유 탄약"
	field("ModalHint").text = "보유 탄 한 장과 교체 · 구매 %d Cr · 총 %d장 유지" % [current_item().price, campaign.model.s.deck.size()] if replacing else "등반 중 보유한 탄환과 수량"
	return_button = "Replace" if replacing else "Bag"
	refresh_bag()
	field("ModalScroll").scroll_vertical = 0
	field("Overlay").show()
	field("CloseOverlay").grab_focus()

func refresh_bag() -> void:
	if bag_page * 4 >= bag_ids.size(): bag_page = 0
	for row in range(4):
		var index := bag_page * 4 + row
		var button: Button = field("AmmoRow%d" % row)
		button.visible = index < bag_ids.size()
		if not button.visible: continue
		var id := str(bag_ids[index])
		var stat := Data.primary_stat(id, campaign.model.s)
		button.text = "%s · %s %s · 열 %s    ×%d" % [Data.AMMO[id].name, stat.label, stat.value, Data.heat_label(id, campaign.model.s), campaign.model.s.deck.count(id)]
		button.disabled = replace_mode and not campaign.can_acquire_ammo(str(current_item().id), id)
		button.tooltip_text = "이 탄 한 장은 내보내며 다음 전투에 돌아오지 않습니다." if replace_mode else Readability.description(id, campaign.model.s)
	field("NextPage").visible = bag_ids.size() > 4
	field("NextPage").text = "다음 목록 · %d/%d" % [bag_page+1,ceili(bag_ids.size()/4.0)]

func select_bag_row(row: int) -> void:
	if replace_mode: purchase(str(bag_ids[bag_page * 4 + row]))

func close_overlay() -> void:
	field("Overlay").hide()
	field(return_button).grab_focus()

func _input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed("ui_cancel") and field("Overlay").visible:
		get_viewport().set_input_as_handled()
		close_overlay()
