extends "res://tests/shop_live_runner.gd"

func field(key: String):
	return shop().get_node_or_null("%" + key)

func touch_button(button: Button) -> void:
	var available := is_instance_valid(button) and button.is_visible_in_tree() and not button.disabled
	check(available, "button available for touch")
	if not available:
		return
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	for down in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await settle()

func touch_key(key: String) -> void:
	var button := field(key) as Button
	check(is_instance_valid(button), "button exists " + key)
	await touch_button(button)

func escape() -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ESCAPE
		event.pressed = down
		root.push_input(event, true)
		await process_frame
	await settle()

func set_size(resolution: Vector2i) -> void:
	root.content_scale_size = resolution
	root.size = resolution
	await settle()

func terminal_bounds(keys: Array) -> void:
	var display: Rect2 = field("Display").get_global_rect()
	var viewport := root.get_visible_rect()
	for key in keys:
		var item := field(key) as Control
		check(item != null and item.is_visible_in_tree() and display.grow(2).encloses(item.get_global_rect()), "control visible inside display: " + key)
	for key in ["Buy", "PartsButton"]:
		var item := field(key) as Control
		check(item != null and item.is_visible_in_tree() and field("ModeKeys").get_global_rect().encloses(item.get_global_rect()), "important action occupies physical key: " + key)
		check(not display.intersects(item.get_global_rect()), "important key is separate from screen content: " + key)
		check(viewport.encloses(item.get_global_rect()), "important key entirely visible: " + key)
	check(viewport.grow(2).encloses(field("Terminal").get_global_rect()), "terminal inside viewport")
	check(not display.intersects(field("ConsoleWallet").get_global_rect()), "credits on separate controls")
	check(field("ScreenGlass").mouse_filter == Control.MOUSE_FILTER_IGNORE, "glass passes input")

func load_save() -> Campaign:
	var saved := Campaign.new()
	check(saved.restore(), "isolated autosave restores")
	return saved

func run() -> void:
	var save_path := ProjectSettings.globalize_path("user://").replace("\\", "/")
	if not save_path.contains("/qa_runtime/shop_terminal_live/"):
		print("Unexpected QA save path: " + save_path)
		quit(2)
		return
	output = OS.get_environment("QA_OUTPUT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	Input.emulate_mouse_from_touch = true
	Input.emulate_touch_from_mouse = true
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = true
	root.add_child(screen)
	await settle()

	for extent in [Vector2i(1280, 800), Vector2i(1008, 454), Vector2i(2340, 1080), Vector2i(1170, 540), Vector2i(844, 390)]:
		await set_size(extent)
		await enter_shop(0, "carrier", "burst", true)
		if shop() == null or not shop().get_script().resource_path.ends_with("shop_terminal_live.gd") or field("ScreenGlass") == null:
			check(false, "modern map uses live CRT console")
			quit(1)
			return
		terminal_bounds(["Details", "Reroll", "Bag", "Tools", "Leave", "LogTab"])
		check(screen.main_scroll.get_v_scroll_bar().max_value <= screen.main_scroll.get_v_scroll_bar().page, "stock fits without outer scroll")
		check(field("ConsoleWallet").text == "75 Cr", "real credits on side controls")
		check(field("Balance").get_theme_font_size("font_size") == 32, "checkout balance uses a full pixel-font step")
		var buy_rect: Rect2 = field("Buy").get_global_rect()
		check(absf(buy_rect.position.x - field("PartsButton").get_global_rect().position.x) < 2.0, "physical purchase and parts keys share alignment")
		check(buy_rect.end.y <= field("PartsButton").get_global_rect().position.y, "purchase is first physical action")
		check(not field("StockTab").visible, "shopping needs no duplicate stock tab")
		check(not field("Charge").visible, "current magazine campaign hides old compression charge")
		await capture("stock_%dx%d" % [extent.x, extent.y])
		screen.campaign.s.credits = 0
		shop().refresh()
		await settle()
		check(field("ConsoleWallet").text == "0 Cr" and field("Balance").text.contains("부족") and field("Buy").disabled, "insufficient credits are visible and prevent purchase")
		check(field("Balance").get_theme_color("font_color").r > field("Balance").get_theme_color("font_color").g, "insufficient balance has danger ink")
		screen.campaign.s.credits = 75
		shop().refresh()
		await settle()
		await touch_key("LogTab")
		check(field("Record").visible and not field("Stock").visible, "records open with quiet footer action")
		check(field("Buy").disabled and field("StockTab").visible, "record mode blocks purchase and offers return to items")
		check(field("RecordTitle").text == "다시 닫힌 난방", "regional record visible")
		await capture("record_%dx%d" % [extent.x, extent.y])
		await touch_key("StockTab")
		check(field("Stock").visible and not field("StockTab").visible and not field("Buy").disabled, "return action restores physical purchase")
		await touch_key("LogTab")
		await escape()
		check(field("Stock").visible and screen.page == "run", "Escape returns to stock")
		if extent.y == 390:
			await touch_key("PartsButton")
			check(field("PartsPane").visible, "short landscape opens parts with touch")
			terminal_bounds(["StockTab", "Leave"])
			await capture("parts_844x390")
			await touch_key("StockTab")
			var price := int(shop().current_offer().price)
			var remaining: int = screen.campaign.s.credits - price
			await touch_key("Buy")
			check(shop().current_offer().sold and screen.campaign.s.credits == remaining, "short landscape purchase completes on touch")

	await set_size(Vector2i(1280, 800))
	await enter_shop(0, "carrier", "burst", true)
	await fixture_offers()
	var terminal = shop()
	await touch_button(terminal.offer_button(1))
	check(field("Effect").text.contains("탄창"), "part preview shows real capacity effect")
	var capacity: int = Data.capacity(screen.model.s)
	await touch_key("Buy")
	check(shop() == terminal and field("Buy").disabled, "purchase keeps terminal and locks sold offer")
	check(screen.campaign.s.credits == 45 and Data.capacity(screen.model.s) == capacity + 1, "part purchase updates run")
	var saved := load_save()
	check(saved.s.get("credits") == 45 and saved.s.offers[1].sold and saved.s.equipped_parts.has("supply"), "autosave has purchase, balance and installed part")
	screen._to_menu()
	await settle()
	screen._resume()
	await settle()
	check(shop() != null and screen.campaign.s.phase == "shop" and field("ConsoleWallet").text == "45 Cr", "title continue reopens live terminal")

	await enter_shop()
	await fixture_offers()
	screen.campaign.s.parts.append_array(["supply", "ordinary_chain", "loader"])
	screen.campaign.s.equipped_parts = screen.campaign.s.parts.duplicate()
	screen.campaign._sync_equipped_parts()
	await touch_button(shop().offer_button(2))
	await touch_key("Buy")
	check(screen.campaign.s.parts.has("lens") and not screen.campaign.is_equipped("lens"), "full slots buy to storage")
	await touch_key("PartsButton")
	var pane = field("PartsPane")
	var slots: HBoxContainer = pane.get_node("%Slots")
	var apply: Button = pane.get_node("%Apply")
	check(pane.visible and pane.selected_id == "lens" and apply.disabled, "purchased part selected, pending outgoing slot")
	check(field("Buy").disabled and field("StockTab").visible, "mount mode disables purchase and exposes return")
	await touch_key("StockTab")
	check(not pane.visible and screen.campaign.s.credits == 45, "returning from mount leaves balance unchanged")
	await touch_key("PartsButton")
	await touch_button(slots.get_child(1))
	check(not apply.disabled and pane.get_node("%Gain").visible and pane.get_node("%Loss").visible, "selected slot shows gains and losses before swap")
	await capture("parts_swap_1280x800")
	await touch_button(apply)
	check(screen.campaign.is_equipped("lens") and pane.stored_buttons.has("radiator") and screen.campaign.s.credits == 45, "swap installs part without a second charge")
	check(screen.model.s.equipped_parts.has("lens"), "live combat model updated")
	saved = load_save()
	check(saved.s.get("equipped_parts", []).has("lens") and not saved.s.equipped_parts.has("radiator"), "autosave has replacement")
	await touch_button(apply)
	check(pane.stored_buttons.has("lens") and not screen.campaign.is_equipped("lens"), "unequip sends part to storage")
	await touch_button(apply)
	check(screen.campaign.is_equipped("lens"), "equip from storage uses free slot")
	await escape()
	check(field("Stock").visible and not pane.visible, "Escape returns from mount to stock")
	await touch_key("Details")
	check(screen.find_child("PartDetails", true, false) != null, "part details opens real modal")
	await escape()
	check(screen.find_child("PartDetails", true, false) == null and screen.page == "run", "Escape closes details in the shop")
	await touch_key("Bag")
	check(is_instance_valid(screen.workspace_overlay), "ammo bag opens real workspace")
	await escape()
	await touch_key("Tools")
	check(screen.workspace_overlay.find_child("city_shop_build", true, false) != null, "shop menu retains the build workspace")
	await escape()
	await touch_key("Leave")
	check(shop() == null and screen.campaign.s.phase == "map", "leave returns to map")
	saved = load_save()
	check(saved.s.get("phase") == "map" and saved.s.credits == 45 and saved.s.equipped_parts.has("lens"), "map autosave retains loadout")

	await enter_shop()
	await fixture_offers()
	while screen.model.s.deck.size() < screen.model.deck_limit():
		screen.model.s.deck.append("basic_p1")
	var size_before: int = screen.model.s.deck.size()
	shop().refresh()
	await settle()
	check(field("Buy").disabled and not field("Replace").disabled, "full deck has a legal exchange")
	await touch_key("Replace")
	check(field("ReplaceOverlay").visible and field("Confirm").disabled, "exchange waits for choice")
	field("Leave").grab_focus()
	check(root.gui_get_focus_owner() == field("Cancel"), "exchange keeps focus inside its modal")
	await escape()
	check(not field("ReplaceOverlay").visible and screen.campaign.s.credits == 75, "cancel does not spend")
	await touch_key("Replace")
	await touch_button(field("Candidates").get_child(0))
	await touch_key("Confirm")
	check(screen.model.s.deck.size() == size_before and screen.model.s.deck.has("precise_p1") and screen.campaign.s.credits == 63, "ammo swap spends once and keeps deck size")
	await touch_key("Charge")
	check(screen.campaign.s.compressor_charges == 2 and screen.campaign.s.credits == 45, "non-magazine compression available")
	await touch_key("Reroll")
	check(screen.campaign.s.credits == 42 and field("Charge").disabled, "refresh preserves charge lock")
	saved = load_save()
	check(saved.s.get("credits") == 42 and saved.s.compressor_charges == 2, "refresh and compression persist")

	await set_size(Vector2i(1008, 454))
	await enter_shop(0, "carrier", "burst", true)
	await fixture_offers()
	await touch_key("PartsButton")
	pane = field("PartsPane")
	var compact_display: Rect2 = field("Display").get_global_rect()
	check(compact_display.encloses(pane.get_node("%Apply").get_global_rect()), "compact parts action stays inside the CRT")
	check(compact_display.encloses(pane.get_node("%Slots").get_global_rect()), "compact parts mount stays inside the CRT")
	await capture("parts_1008x454")
	await escape()
	await set_size(Vector2i(1280, 800))

	for region in range(5):
		await enter_shop(region, "expedition", "heavy")
		await touch_key("LogTab")
		var story: Dictionary = preload("res://redesign/city_story.gd").SHOPS[region]
		check(field("Title").text == screen.campaign.node().name, "current region name %d" % region)
		check(field("Greeting").text == story.greeting and field("Memo").text + "\n" + field("Transcript").text == story.story, "current region story %d" % region)
	screen.preferences.data.motion = "instant"
	await enter_shop()
	check(shop().idle_sweep == null, "motion preference stops idle sweep")
	await enter_shop(0, "carrier", "burst", false, 2)
	screen._to_menu()
	await settle()
	screen._resume()
	await settle()
	check(shop() != null and not screen.campaign.modern_places() and shop().field("LegacyServices").visible, "continued legacy save retains its original shop services")

	screen.queue_free()
	await process_frame
	print("SHOP TERMINAL LIVE COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
