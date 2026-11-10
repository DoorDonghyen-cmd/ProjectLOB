extends Control

const Campaign = preload("res://redesign/campaign.gd")
const Data = preload("res://redesign/content.gd")
const Story = preload("res://redesign/city_story.gd")
const Readability = preload("res://redesign/ui_readability.gd")
const Card = preload("res://redesign/ammo_card_view.gd")
const Offer = preload("res://redesign/samples/shop_counter_review/offer.gd")
const FIXTURES := "res://../qa_runtime/core_choice_20261103/climb_fresh17/"
const FIRST := "shop_heavy_17_r1_n503"
const STOCKED := "shop_heavy_17_r2_n10502"
const FULL_SLOTS := "shop_heavy_17_r4_n30401"

var run: Campaign
var scenario := 2
var selected := 0
var outgoing := ""
var selection_group := ButtonGroup.new()
var replacement_group := ButtonGroup.new()
var checks := 0
var failures := 0

func _ready() -> void:
	bind_trade_controls()
	%Reset.pressed.connect(load_example.bind(0))
	fit()
	load_example(2)
	var output := OS.get_environment("LOB_SHOP_COUNTER_CAPTURE")
	if not output.is_empty():
		capture_all.call_deferred(output)

func bind_trade_controls() -> void:
	for index in range(3):
		var slot := offer_button(index)
		slot.button_group = selection_group
		slot.pressed.connect(select_offer.bind(index))
	%Buy.pressed.connect(purchase)
	%Replace.pressed.connect(open_replacement)
	%Confirm.pressed.connect(purchase_replacement)
	%Cancel.pressed.connect(close_replacement)
	%Reroll.pressed.connect(reroll)
	%Charge.pressed.connect(charge)
	resized.connect(fit)

func fit() -> void:
	var window := get_window()
	var factor := Readability.scale_for(window.size)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.content_scale_size = Vector2i.ZERO
	window.content_scale_factor = factor
	var compact := window.size.y / factor < 680.0
	var checkout_margin := maxi(34, roundi((window.size.x / factor - 850.0) * 0.5))
	%Checkout.add_theme_constant_override("margin_left", checkout_margin)
	%Checkout.add_theme_constant_override("margin_right", checkout_margin)
	%Stage.custom_minimum_size.y = 282 if compact else 430
	%Checkout.custom_minimum_size.y = 155 if compact else 220
	%Checkout.add_theme_constant_override("margin_top", 12 if compact else 23)
	%Checkout.add_theme_constant_override("margin_bottom", 9 if compact else 20)

func offer_button(index: int) -> Button:
	return %Stage.get_node("Offer%d" % index)

func load_example(index: int) -> void:
	if index > 0:
		scenario = index
	var filename := FIRST if scenario == 1 else FULL_SLOTS if scenario == 4 else STOCKED
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + filename + ".json"))
	var fresh := Campaign.new()
	if not data is Dictionary or not fresh.restore_state(data) or fresh.s.phase != "shop":
		%Feedback.text = "상점 기록을 불러올 수 없습니다."
		if not OS.get_environment("LOB_SHOP_COUNTER_CAPTURE").is_empty():
			get_tree().quit(2)
		return
	run = fresh
	if scenario == 3:
		# Fill remaining slots for the capacity example without changing the stock or prices.
		while run.model.s.deck.size() < run.model.deck_limit():
			run.model.s.deck.append(run.model.s.deck[0])
	close_replacement()
	selected = 1 if scenario == 1 else 2 if scenario == 4 else 0
	%Feedback.text = ""
	refresh()

func select_offer(index: int) -> void:
	selected = index
	%Feedback.text = ""
	refresh()

func refresh() -> void:
	if run == null:
		return
	var state: Dictionary = run.model.s
	var story: Dictionary = Story.SHOPS[int(run.s.region)]
	var credits: int = run.s.credits
	%Title.text = str(story.place)
	%Wallet.text = "%d Cr" % credits
	for index in range(3):
		var button := offer_button(index)
		button.visible = index < run.s.offers.size()
		if button.visible:
			button.show_offer(run.s.offers[index], state, credits, index == selected)
			button.set_pressed_no_signal(index == selected)
	%Reroll.text = "새 진열 · %d Cr" % run.reroll_cost()
	%Reroll.disabled = credits < run.reroll_cost()
	%Charge.visible = not run.magazine_enabled()
	%Charge.disabled = run.s.shop_compressor_bought or run.s.compressor_charges >= run.MAX_COMPRESSOR_CHARGES or credits < run.COMPRESSOR_PRICE
	%Charge.text = "충전 완료" if run.s.shop_compressor_bought else "압축 충전 · %d Cr" % run.COMPRESSOR_PRICE
	var offer := current_offer()
	if offer.is_empty():
		%ItemName.text = "판매품 없음"
		%Buy.disabled = true
		%Replace.hide()
		return
	show_details(offer, state, credits)

func current_offer() -> Dictionary:
	if run == null or selected >= run.s.offers.size():
		return {}
	return run.s.offers[selected]

func show_details(offer: Dictionary, state: Dictionary, credits: int) -> void:
	var id := str(offer.id)
	var is_ammo: bool = offer.type == "ammo"
	var spec: Dictionary = Data.AMMO[id] if is_ammo else Data.part_spec(id, state)
	var sold: bool = offer.sold
	var price := int(offer.price)
	var affordable := credits >= price
	var duplicate: bool = not is_ammo and run.s.parts.has(id)
	var full: bool = is_ammo and not run.can_acquire_ammo(id)
	%ItemName.text = Offer.item_name(id, state)
	%Kind.text = "탄환" if is_ammo else "코어" if Data.is_core_part(id) else "파츠"
	if is_ammo:
		var view = Card.new()
		view.setup(id, 1, state)
		var stat := Data.primary_stat(id, state)
		%Effect.text = "%s %s  ·  열 %s\n%s" % [stat.label, stat.value, Data.heat_label(id, state), view.effect_text()]
		view.free()
		%Owned.text = "보유 %d장  ·  가방 %d / %d" % [state.deck.count(id), state.deck.size(), run.model.deck_limit()]
	else:
		var effect := str(spec.get("upside", spec.get("text", "")))
		var downside := str(spec.get("downside", ""))
		%Effect.text = effect + ("\n" + downside if not downside.is_empty() else "")
		%Owned.text = "장착 슬롯 %d / %d" % [run.equipped_parts().size(), run.MAX_EQUIPPED_PARTS]
		if duplicate:
			%Owned.text = "장착 중" if run.is_equipped(id) else "보관함에 보유"
	var can_equip: bool = not is_ammo and run.can_equip_reward(id)
	var outcome := "가방에 한 장 추가" if is_ammo else "구매 후 장착" if can_equip else "구매 후 보관"
	if sold:
		outcome = "구매 완료"
	elif duplicate:
		outcome = "이미 보유 중"
	elif full:
		outcome = "보유 탄과 교체"
	%Outcome.text = outcome
	%Balance.text = "현재 잔액 %d Cr" % credits if sold or duplicate else "결제 후 %d Cr" % (credits - price) if affordable else "%d Cr 부족" % (price - credits)
	%Balance.add_theme_color_override("font_color", Color("dfd8ba") if affordable or sold or duplicate else Color("df9274"))
	%Buy.text = "구매 완료" if sold else "구매"
	%Buy.disabled = sold or duplicate or not affordable or full
	%Replace.visible = is_ammo and not sold
	%Replace.disabled = not affordable or replacement_ids(id).is_empty()
	%Replace.text = "교체 선택"

func replacement_ids(id: String) -> Array:
	return run.replaceable_ammo().filter(func(candidate): return run.can_acquire_ammo(id, candidate))

func open_replacement() -> void:
	var offer := current_offer()
	if offer.is_empty() or %Replace.disabled:
		return
	outgoing = ""
	%Confirm.disabled = true
	for child in %Candidates.get_children():
		%Candidates.remove_child(child)
		child.queue_free()
	var state: Dictionary = run.model.s
	%ReplaceSummary.text = "%s 한 장 구매 · %d Cr · 가방 %d / %d 유지" % [Offer.item_name(str(offer.id), state), int(offer.price), state.deck.size(), run.model.deck_limit()]
	for id in replacement_ids(str(offer.id)):
		var option := Button.new()
		var stat := Data.primary_stat(str(id), state)
		option.text = "%s  ·  %s %s  ·  보유 %d장" % [Offer.item_name(str(id), state), stat.label, stat.value, state.deck.count(id)]
		option.alignment = HORIZONTAL_ALIGNMENT_LEFT
		option.custom_minimum_size.y = 44
		option.toggle_mode = true
		option.button_group = replacement_group
		option.pressed.connect(select_replacement.bind(str(id)))
		%Candidates.add_child(option)
	%ReplaceOverlay.show()
	%Cancel.grab_focus()

func select_replacement(id: String) -> void:
	outgoing = id
	%Confirm.disabled = false

func close_replacement() -> void:
	%ReplaceOverlay.hide()
	outgoing = ""

func purchase() -> void:
	apply_purchase("")

func purchase_replacement() -> void:
	if not outgoing.is_empty():
		apply_purchase(outgoing)

func apply_purchase(replaced: String) -> void:
	if run != null and run.buy(selected, replaced):
		close_replacement()
		%Feedback.text = "교체 완료" if not replaced.is_empty() else "구매 완료"
		refresh()

func reroll() -> void:
	if run != null and run.reroll():
		selected = 0
		%Feedback.text = "새 물건이 도착했습니다."
		refresh()

func charge() -> void:
	if run != null and run.buy_compressor_charge():
		%Feedback.text = "압축 충전 완료"
		refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F1: load_example(1)
		KEY_F2: load_example(2)
		KEY_F3: load_example(3)
		KEY_F4: load_example(4)
		KEY_ESCAPE: close_replacement()

func verify(condition: bool, context: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(context)

func rendered() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw

func frame(output: String, name: String, size_expected: Vector2i) -> void:
	await rendered()
	var picture := get_viewport().get_texture().get_image()
	verify(picture.get_size() == size_expected, name + " screenshot size")
	verify(picture.save_png(output.path_join(name + ".png")) == OK, name + " screenshot saved")

func touch(control: Control) -> void:
	var point := control.get_global_transform_with_canvas() * (control.size * 0.5)
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.pressed = pressed
		event.position = point
		get_viewport().push_input(event, true)
		await get_tree().process_frame

func inspect_bounds(context: String) -> void:
	var viewport := get_viewport_rect().grow(1.0)
	for node in find_children("*", "Control", true, false):
		if not (node is Button or node is Label) or not node.is_visible_in_tree():
			continue
		if %ReplaceOverlay.visible and %Candidates.is_ancestor_of(node):
			continue
		verify(viewport.encloses(node.get_global_rect()), context + " bounds " + str(node.name))
		if node is Button:
			verify(node.size.y >= 44, context + " touch target " + str(node.name))
		var font: Font = node.get_theme_font("font")
		for character in node.text.replace("\n", ""):
			if not font.has_char(character.unicode_at(0)):
				verify(false, context + " missing glyph " + character)

func capture_all(output: String) -> void:
	Input.emulate_mouse_from_touch = true
	for extent in [Vector2i(1280, 800), Vector2i(2340, 1080), Vector2i(2160, 1032)]:
		get_window().size = extent
		await rendered()
		var suffix := "_%dx%d" % [extent.x, extent.y]
		load_example(1)
		await rendered()
		verify(run.s.credits == 18 and selected == 1 and offer_button(1).get_node("Tag/Price").text == "30 → 18 Cr", "recorded discount")
		inspect_bounds("arrival" + suffix)
		await frame(output, "arrival" + suffix, extent)
		await touch(offer_button(2))
		verify(selected == 2 and %Buy.disabled and %Balance.text == "12 Cr 부족", "credit shortage blocks purchase")
		await frame(output, "unaffordable" + suffix, extent)
		await touch(offer_button(1))
		await touch(%Buy)
		verify(run.s.credits == 0 and run.is_equipped("coil") and run.s.offers[1].sold, "real purchase deducts credits and equips")
		verify(not offer_button(1).get_node("Icon").visible and %Buy.disabled, "sold product leaves the counter")
		await frame(output, "purchased" + suffix, extent)
		load_example(2)
		await rendered()
		inspect_bounds("stocked" + suffix)
		await frame(output, "stocked" + suffix, extent)
		await touch(%Reroll)
		verify(run.s.shop_revision == 1 and run.s.credits == 51, "real reroll charges its published cost")
		load_example(4)
		await rendered()
		verify(%Outcome.text == "구매 후 보관", "no equipment slot predicts storage")
		await touch(%Buy)
		verify(run.s.parts.has("lens") and not run.is_equipped("lens"), "full loadout stores purchase")
		load_example(3)
		await rendered()
		verify(%Buy.disabled and not %Replace.disabled, "full bag enables replacement only")
		var bag_size: int = run.model.s.deck.size()
		await touch(%Replace)
		verify(%ReplaceOverlay.visible and %Confirm.disabled, "replacement opens without commitment")
		inspect_bounds("replacement" + suffix)
		await frame(output, "replacement" + suffix, extent)
		await touch(%Cancel)
		verify(not %ReplaceOverlay.visible and run.model.s.deck.size() == bag_size and run.s.credits == 54, "cancel keeps credits and ammo")
		await touch(%Replace)
		await touch(%Candidates.get_child(0))
		verify(not outgoing.is_empty() and not %Confirm.disabled, "explicit source selected")
		await touch(%Confirm)
		verify(not %ReplaceOverlay.visible and run.s.credits == 30 and run.model.s.deck.size() == bag_size and run.s.offers[0].sold, "real replacement retains bag size")
	verify(not FileAccess.file_exists(Campaign.SAVE), "isolated preview writes no campaign save")
	print("SHOP COUNTER REVIEW checks=%d failures=%d" % [checks, failures])
	get_tree().quit(0 if failures == 0 else 1)

