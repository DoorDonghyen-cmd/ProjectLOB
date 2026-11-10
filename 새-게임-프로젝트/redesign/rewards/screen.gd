extends Control

const Campaign = preload("res://redesign/campaign.gd")
const Data = preload("res://redesign/content.gd")
const Focus = preload("res://redesign/focus_build.gd")
const PartChoice = preload("res://redesign/part_choice.gd")
const BuildGuide = preload("res://redesign/build_guide.gd")
const EXCHANGE_PAGE_SIZE := 3

var run: Campaign
var selected := ""
var outgoing := ""
var choosing_outgoing := false
var exchange_page := 0
var prototype_card: Button
var cards: Dictionary = {}
var reveal: Tween
var reveal_duration := 0.26

func _ready() -> void:
	prototype_card = %Offers.get_child(0).duplicate()
	prototype_card.button_pressed = false
	%Confirm.pressed.connect(confirm)
	%Skip.pressed.connect(skip)
	%Credits.pressed.connect(claim.bind("credits"))
	%PrevPage.pressed.connect(change_exchange_page.bind(-1))
	%NextPage.pressed.connect(change_exchange_page.bind(1))

func _exit_tree() -> void:
	if is_instance_valid(prototype_card):
		prototype_card.free()

func present() -> void:
	var node := run.node()
	%Backdrop.present(run)
	%Location.text = "%s  /  %s" % [run.region_info().name, node.name]
	%Title.text = "보스 격파" if run.boss_loot() else "정예 격파" if node.get("elite", false) else "전투 승리"
	reset_choices()

func reset_choices(preferred: String = "") -> void:
	choosing_outgoing = false
	outgoing = ""
	var ids := run.reward_options() + run.part_rewards()
	selected = preferred if ids.has(preferred) else str(ids[0]) if not ids.is_empty() else ""
	rebuild_cards(ids)
	refresh()
	if reveal != null:
		reveal.kill()
	%Offers.modulate.a = 1.0
	if reveal_duration <= 0.0:
		return
	%Offers.modulate.a = 0.35
	reveal = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	reveal.tween_property(%Offers, "modulate:a", 1.0, reveal_duration)

func rebuild_cards(ids: Array) -> void:
	for child in %Offers.get_children():
		%Offers.remove_child(child)
		child.queue_free()
	cards.clear()
	var package := run.first_ammo_reward() and Focus.enabled(run.s)
	for id in ids:
		var card := prototype_card.duplicate() as Button
		card.name = ("ammo_replace_" if choosing_outgoing else "city_reward_") + str(id)
		var label := card.get_node("Caption") as Label
		var meta := card.get_node("Meta") as Label
		var quantity := card.get_node("Quantity") as Label
		var glyph = card.get_node("Glyph")
		var item_name := title_for(str(id))
		glyph.item_id = id
		glyph.is_part = Data.PARTS.has(id)
		label.text = item_name
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		meta.text = card_readout(str(id))
		meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		quantity.visible = choosing_outgoing or package
		quantity.text = "×%d" % (2 if package else run.model.s.deck.count(id))
		label.tooltip_text = item_name
		card.tooltip_text = item_name
		card.pressed.connect(pick.bind(str(id)))
		%Offers.add_child(card)
		cards[id] = card
	%Offers.get_parent().scroll_horizontal = 0

func title_for(id: String) -> String:
	return str(Data.part_spec(id, run.model.s).name) if Data.PARTS.has(id) else str(Data.AMMO[id].name)

func ammo_stats(id: String) -> String:
	var stat := Data.primary_stat(id, run.model.s)
	return "%s %s   ·   열 %s" % [stat.label, stat.value, Data.heat_label(id, run.model.s)]

func card_readout(id: String) -> String:
	if Data.PARTS.has(id):
		return str(Data.part_spec(id, run.model.s).get("value", "")).get_slice(" · ", 0)
	var stat := Data.primary_stat(id, run.model.s)
	return "%s %s · 열%s" % [stat.label, stat.value, Data.heat_label(id, run.model.s)]

func pick(id: String) -> void:
	if choosing_outgoing:
		outgoing = id
	else:
		selected = id
	refresh()

func refresh() -> void:
	var state: Dictionary = run.model.s
	var is_part := Data.PARTS.has(selected)
	var opening := run.engine_reward()
	var core := is_part and str(Data.PARTS[selected].kind) == "core"
	var opening_title := "첫 파츠 · 1/2" if is_part and not core else "성장 코어 · 1/2"
	var package := run.first_ammo_reward() and Focus.enabled(run.s)
	var has_room := not selected.is_empty() and run.can_acquire_ammo(selected)
	var bag := "가방 %d / %d" % [state.deck.size(), run.model.deck_limit()]
	var mixed := not choosing_outgoing and cards.keys().any(func(id): return Data.PARTS.has(id) != is_part)
	%Section.text = "내보낼 탄환" if choosing_outgoing else opening_title if opening else "주력 탄 묶음 · 2/2" if package else "전투 보상 · 1개 선택" if mixed else "회수할 파츠" if is_part else "회수할 탄환"
	%Count.text = "장착대 %d / %d" % [run.equipped_parts().size(), Campaign.MAX_EQUIPPED_PARTS] if is_part else bag
	%Credits.text = "대신 %d Cr" % run.credit_reward()
	%Credits.visible = not choosing_outgoing
	%Pages.visible = choosing_outgoing and exchange_choices().size() > EXCHANGE_PAGE_SIZE
	%Skip.show()
	%Skip.text = "후보로 돌아가기" if choosing_outgoing else "보류"
	for id in cards:
		cards[id].set_pressed_no_signal(id == (outgoing if choosing_outgoing else selected))
	%Item.text = title_for(selected) if not selected.is_empty() else "회수할 물건 없음"
	%Confirm.disabled = selected.is_empty()
	%Fit.text = ""
	%Gain.text = ""
	%Cost.text = ""
	%Status.text = ""
	%Exchange.visible = choosing_outgoing
	%Item.visible = not choosing_outgoing
	%Gain.visible = not choosing_outgoing
	if choosing_outgoing:
		var incoming_count: int = state.deck.count(selected)
		var outgoing_count: int = state.deck.count(outgoing)
		%IncomingName.text = title_for(selected)
		%IncomingStats.text = ammo_stats(selected)
		%IncomingCount.text = "%d → %d장" % [incoming_count, incoming_count + 1]
		%OutgoingName.text = "선택 대기" if outgoing.is_empty() else title_for(outgoing)
		%OutgoingStats.text = "" if outgoing.is_empty() else ammo_stats(outgoing)
		%OutgoingCount.text = "" if outgoing.is_empty() else "%d → %d장" % [outgoing_count, outgoing_count - 1]
		%Confirm.disabled = outgoing.is_empty()
		%Confirm.text = "이 탄으로 교체"
		%Status.text = "가방 수량 유지"
	elif is_part:
		var spec := Data.part_spec(selected, state)
		%Gain.text = PartChoice.effect(selected, state)
		%Cost.text = str(spec.get("downside", ""))
		%Fit.text = BuildGuide.connection(selected, state)
		var main := Focus.main_round(state)
		if selected == Focus.NEW_PART and not main.is_empty():
			%Fit.text = "현재 주력 · %s %d장" % [title_for(main), PartChoice.family_count(state, Data.source_id(main))]
		%Status.text = "획득 시 장착" if run.can_equip_reward(selected) else "획득 후 보관"
		%Confirm.text = "코어 회수" if opening and core else "파츠 회수"
	elif not selected.is_empty():
		%Gain.text = Focus.package_text(selected) if package else ammo_stats(selected)
		%Fit.text = "기본탄 3장 교체 · 가방 수량 유지" if package else Focus.offer_label(state, selected)
		%Status.text = "" if package else "가방에 1장 추가" if has_room else "가방 가득 참"
		%Confirm.text = "묶음 회수" if package else "탄환 회수" if has_room else "교체할 탄 고르기"
		%Confirm.disabled = Focus.replace_opening(state.deck, selected).is_empty() if package else not has_room and exchange_choices().is_empty()
	%Cost.visible = not %Cost.text.is_empty()
	%Fit.visible = not %Fit.text.is_empty()

func exchange_choices() -> Array:
	return run.replaceable_ammo().filter(func(id): return run.can_acquire_ammo(selected, id))

func change_exchange_page(delta: int) -> void:
	var candidates := exchange_choices()
	var pages := maxi(1, ceili(float(candidates.size()) / EXCHANGE_PAGE_SIZE))
	exchange_page = clampi(exchange_page + delta, 0, pages - 1)
	var start := exchange_page * EXCHANGE_PAGE_SIZE
	rebuild_cards(candidates.slice(start, start + EXCHANGE_PAGE_SIZE))
	%Page.text = "%d / %d" % [exchange_page + 1, pages]
	%PrevPage.disabled = exchange_page == 0
	%NextPage.disabled = exchange_page == pages - 1
	refresh()
	if not cards.is_empty():
		var first: Button = cards.values()[0]
		first.grab_focus()

func cancel_exchange() -> void:
	choosing_outgoing = false
	outgoing = ""
	rebuild_cards(run.reward_options())
	refresh()
	if cards.has(selected):
		cards[selected].grab_focus()

func skip() -> void:
	if choosing_outgoing:
		cancel_exchange()
	else:
		claim("skip")

func confirm() -> void:
	if choosing_outgoing:
		if not outgoing.is_empty():
			claim(selected, outgoing)
	elif Data.PARTS.has(selected) or (run.first_ammo_reward() and Focus.enabled(run.s)) or run.can_acquire_ammo(selected):
		claim(selected)
	elif not selected.is_empty():
		open_exchange()

func open_exchange() -> void:
	choosing_outgoing = true
	exchange_page = 0
	change_exchange_page(0)

func claim(_id: String, _removed: String = "") -> void:
	pass
