extends "res://redesign/samples/shop_terminal_review/console_preview.gd"

var host

func _feedback_transaction(event: Dictionary, effects) -> void:
	var command:=str(event.command)
	if command in ["buy","reroll","buy_compressor"]:
		if int(event.before.credits)!=int(event.after.credits):
			effects.pulse(%ConsoleWallet,"money");effects.pulse(%Wallet,"money")
		effects.pulse(%Feedback,"complete")
		if command=="buy":effects.pulse(offer_button(int(event.value)),"acquired")
		elif command=="reroll":
			for i in range(run.s.offers.size()):effects.pulse(offer_button(i),"stock")
	elif command in ["equip","replace_part"] and not %PartsPane.is_visible_in_tree():
		effects.pulse(%PartsButton,"installed")

func configure(screen) -> void:
	host = screen
	run = host.campaign
	selected = clampi(host.city_ui.shop_selection, 0, maxi(0, run.s.offers.size() - 1))

func _ready() -> void:
	if host == null:
		return
	bind_trade_controls()
	bind_terminal_controls()
	bind_console_controls()
	%PartsPane.perform_action = perform_trade
	%Details.pressed.connect(open_rules)
	%Bag.pressed.connect(host._ammo_bag)
	%Tools.pressed.connect(open_tools)
	get_viewport().gui_focus_changed.connect(guard_replacement_focus)
	fit()
	sync_glass_size()
	refresh()
	show_record(false)
	restart_idle_sweep()

func motion_enabled() -> bool:
	return host == null or str(host.preferences.data.motion) != "instant"

func fit() -> void:
	if size.x > 0.0 and size.y > 0.0:
		fit_area(Rect2(Vector2.ZERO, size))

func select_offer(index: int) -> void:
	host.city_ui.shop_selection = index
	super.select_offer(index)

func refresh() -> void:
	super.refresh()
	%Details.visible = not current_offer().is_empty()
	%Charge.visible = %Stock.visible and not run.magazine_enabled()
	%SaveNotice.text = host.save_error
	%SaveNotice.visible = not host.save_error.is_empty()

func show_details(offer: Dictionary, state: Dictionary, credits: int) -> void:
	super.show_details(offer, state, credits)
	var id := str(offer.id)
	if offer.type == "part" and not offer.sold and not run.s.parts.has(id) and run.can_equip_reward(id):
		var after := state.duplicate(true)
		after.equipped_parts = run.equipped_parts()
		after.equipped_parts.append(id)
		var changes: PackedStringArray = host.city_ui._part_stat_changes(state, after)
		if not changes.is_empty():
			%Effect.text += "\n" + " · ".join(changes)

func show_record(open: bool) -> void:
	super.show_record(open)
	%Bag.visible = not open

func open_parts() -> void:
	super.open_parts()
	%Bag.hide()

func perform_trade(command: String, value: Variant = "", extra: String = "") -> bool:
	var accepted: bool = host._campaign_action(command, value, extra, "", false)
	%SaveNotice.text = host.save_error
	%SaveNotice.visible = not host.save_error.is_empty()
	return accepted

func apply_purchase(replaced: String) -> void:
	if perform_trade("buy", selected, replaced):
		close_replacement()
		%Feedback.text = "교체 완료" if not replaced.is_empty() else "구매 완료"
		refresh()
		offer_button(selected).grab_focus()

func close_replacement() -> void:
	var was_open: bool = %ReplaceOverlay.visible
	super.close_replacement()
	if was_open:
		%Replace.grab_focus()

func guard_replacement_focus(control: Control) -> void:
	if %ReplaceOverlay.is_visible_in_tree() and not %ReplaceOverlay.is_ancestor_of(control):
		%Cancel.grab_focus()

func reroll() -> void:
	if perform_trade("reroll"):
		selected = 0
		host.city_ui.shop_selection = 0
		%Feedback.text = "새 물건이 도착했습니다."
		refresh()

func charge() -> void:
	if perform_trade("buy_compressor"):
		%Feedback.text = "압축 충전 완료"
		refresh()

func return_to_map() -> void:
	host._campaign_action("leave")

func open_rules() -> void:
	var offer := current_offer()
	if offer.is_empty():
		return
	var id := str(offer.id)
	if offer.type == "part":
		host.city_ui.part_details(id)
		return
	var column: VBoxContainer = host._workspace(str(Data.AMMO[id].name))
	host._label(column, preload("res://redesign/readability.gd").description(id, run.model.s), 18)

func open_tools() -> void:
	var column: VBoxContainer = host._workspace("상점 메뉴")
	host._button(column, "빌드 작업실", "city_shop_build", host.city_ui.deck.bind("parts"))
	host._button(column, "설정", "shop_settings", host._settings)
	host._button(column, "타이틀", "shop_title", host._to_menu)

func _input(event: InputEvent) -> void:
	if host == null or not is_visible_in_tree() or is_instance_valid(host.workspace_overlay) or not event.is_action_pressed("ui_cancel"):
		return
	if %ReplaceOverlay.visible:
		close_replacement()
	elif %PartsPane.visible or %Record.visible:
		show_record(false)
	else:
		return
	get_viewport().set_input_as_handled()

func _unhandled_key_input(_event: InputEvent) -> void:
	pass
