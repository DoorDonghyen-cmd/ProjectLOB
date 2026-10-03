extends SceneTree
## Real touch/keyboard input, isolated saves, and atomic part replacement.
const Campaign = preload("res://redesign/campaign.gd")
const Content = preload("res://redesign/content.gd")
var screen: Control
var checks := 0
var failures := 0
var output := ""

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + label)

func settle() -> void:
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw

func touch(key: String) -> void:
	var control := screen.find_child(key, true, false) as Control
	check(control != null and control.is_visible_in_tree(), "visible touch target " + key)
	if control == null: return
	var point := root.get_final_transform() * (control.get_screen_transform() * (control.size * 0.5) - Vector2(DisplayServer.window_get_position()))
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle()

func bounds(key: String) -> void:
	var control := screen.find_child(key, true, false) as Control
	check(control != null and control.is_visible_in_tree() and Rect2(Vector2.ZERO, screen.size).encloses(control.get_global_rect()), "visible bounds " + key)

func capture(id: String) -> void:
	await settle()
	check(root.get_texture().get_image().save_png(output.path_join(id + ".png")) == OK, "capture " + id)

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/weapons/ui/"):
		quit(2)
		return
	output = OS.get_environment("QA_OUTPUT_DIR")
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1280, 800), Vector2i(1008, 630), Vector2i(1440, 720)]:
		root.size = resolution
		await settle()
		screen._to_menu()
		await settle()
		bounds("TitleHero")
		bounds("new_run_setup")
		check(not screen.main_scroll.get_v_scroll_bar().visible, "title fits " + str(resolution))
		await capture("main_" + str(resolution.x))
		await touch("new_run_setup")
		check(screen.page == "loadout", "touch opens preparation")
		for id in Content.GUNS:
			await touch("weapon_select_" + id)
			check(screen.selected_weapon_id == id, "whole card selects " + id)
			var actual = Campaign.new()
			actual.start(id, 817263)
			for ammo in actual.model.s.deck:
				var caption := screen.find_child("StartingRound_" + str(ammo), true, false) as Label
				check(caption != null and caption.text.ends_with("×%d" % actual.model.s.deck.count(ammo)), "starting supply matches actual weapon deck")
			bounds("start_" + id)
			check(not screen.main_scroll.get_v_scroll_bar().visible, "preparation fits " + id)
		screen.seed_input.text = "817263"
		await touch("weapon_select_burst")
		check(screen.preparation_seed == "817263", "seed survives weapon selection")
		bounds("StartingDeckPreview")
		await capture("weapons_" + str(resolution.x))
		screen._debug_city("shop")
		await settle()
		var workbench := screen.find_child("ShopWorkbench", true, false)
		var original: Rect2 = (screen.find_child("OfferComparePanel", true, false) as Control).get_global_rect()
		for i in range(screen.campaign.s.offers.size()):
			var offer: Dictionary = screen.campaign.s.offers[i]
			await touch(("city_offer_compare_" if offer.type == "ammo" else "city_part_info_") + str(i))
			bounds("city_compare_buy_" + str(i))
			check((screen.find_child("OfferComparePanel", true, false) as Control).get_global_rect().is_equal_approx(original), "comparison preserves layout")
			check(not screen.main_scroll.get_v_scroll_bar().visible, "shop fits selected offer")
		await capture("shop_" + str(resolution.x))
		var credits: int = screen.campaign.s.credits
		var offer: Dictionary = screen.campaign.s.offers[1]
		await touch("city_part_info_1")
		await touch("city_compare_buy_1")
		check(screen.campaign.s.credits == credits - int(offer.price) and screen.campaign.s.parts.has(offer.id), "inspector purchase delivers and charges once")
		check((screen.find_child("city_compare_buy_1", true, false) as Button).disabled, "sold offer disables inspector purchase")
		check((screen.find_child("ShopHint", true, false) as Label).text.contains(str(Content.PARTS[offer.id].name)), "purchase feedback identifies the delivered item")
		screen._debug_city("deck")
		await settle()
		var old: Array = screen.campaign.equipped_parts()
		var snapshot := JSON.stringify(screen.campaign.s)
		check(not screen.campaign.replace_part("rammer", "overbore"), "reject second core")
		check(JSON.stringify(screen.campaign.s) == snapshot, "invalid replacement leaves state untouched")
		check(not screen.campaign.replace_part("missing", "overbore"), "reject absent outgoing part")
		await touch("city_part_select_overbore")
		var choice := screen.find_child("PartReplacement", true, false) as OptionButton
		check(choice != null and str(choice.get_item_metadata(choice.selected)) == "field_press", "core replacement identifies the existing core")
		var preview := screen.find_child("PartChangePreview", true, false) as Label
		check(preview != null and preview.text.contains("2 → 3"), "preview includes removed core and incoming penalty")
		bounds("city_deck_equip_overbore")
		bounds("InventoryPanel")
		bounds("EquippedPartGrid")
		check(not (screen.find_child("WorkspaceScroll", true, false) as ScrollContainer).get_v_scroll_bar().visible, "parts replacement fits without outer scroll")
		await capture("parts_replace_" + str(resolution.x))
		await touch("city_deck_equip_overbore")
		check(screen.campaign.equipped_parts().size() == 5 and screen.campaign.equipped_parts()[4] == "overbore", "atomic replacement preserves other slots")
		check(screen.campaign.s.parts.has("field_press") and screen.model.capacity() == 3, "outgoing core retained and preview matches model")
		var saved_path := "user://navigation_roundtrip.json"
		check(screen.campaign.save(saved_path) == OK, "replacement save succeeds")
		var restored = Campaign.new()
		check(restored.restore(saved_path) and restored.equipped_parts() == screen.campaign.equipped_parts(), "replacement survives restore")
		await touch("city_deck_equip_overbore")
		check(screen.campaign.equipped_parts().size() == 4, "selected equipped part can be removed")
		await touch("city_part_select_field_press")
		await touch("city_deck_equip_field_press")
		check(screen.campaign.equipped_parts() == old, "stored part equips into vacant slot")
		await touch("AmmoTab")
		check((screen.find_child("DeckPanel", true, false) as Control).is_visible_in_tree(), "ammo library opens")
		await touch("PartsTab")
		bounds("InventoryPanel")
		check((screen.find_child("PartInspector", true, false) as Control).is_visible_in_tree(), "parts and inventory return together")
		await touch("workspace_close")
		check(not is_instance_valid(screen.workspace_overlay), "touch closes workspace")
		check(screen.campaign.enter(101), "enter actual combat for equipment lock")
		screen.redraw()
		await settle()
		screen.city_ui.deck()
		await settle()
		await touch("equipped_part_detail_0")
		check(screen.find_child("city_deck_equip_capacitor", true, false) == null, "combat equipment is read only")
		check(not screen.campaign.replace_part("field_press", "overbore"), "combat replacement rejected by model")
		screen._close_workspace()
		screen._to_menu()
	# All stored parts remain reachable through a local scroll.
	screen._debug_city("deck")
	await settle()
	screen._close_workspace()
	screen.campaign.s.parts = Content.PARTS.keys().filter(func(id): return id != "none")
	screen.city_ui.deck()
	await settle()
	var inventory_scroll := screen.find_child("InventoryScroll", true, false) as ScrollContainer
	var last := screen.find_child("city_part_select_triad", true, false) as Control
	inventory_scroll.ensure_control_visible(last)
	await settle()
	check(inventory_scroll.get_global_rect().encloses(last.get_global_rect()), "last of full inventory is reachable")
	await touch("city_part_select_triad")
	check(screen.city_ui.selected_part_id == "triad", "touch selects last stored part after scrolling")
	bounds("city_deck_equip_triad")
	await capture("full_inventory")
	screen._close_workspace()
	# Keyboard focus returns to the originating action.
	screen._debug_city("shop")
	await settle()
	var origin := screen.find_child("city_shop_build", true, false) as Button
	origin.grab_focus()
	origin.pressed.emit()
	await settle()
	check(screen.workspace_overlay.is_ancestor_of(root.gui_get_focus_owner()), "workspace takes keyboard focus")
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await settle()
	check(root.gui_get_focus_owner() == origin, "Escape restores origin focus")
	# Dismantling is explicit and cancelable; only the selected stored part is consumed.
	screen.campaign.s.parts.append("lens")
	screen.city_ui.deck()
	await settle()
	await touch("city_part_select_lens")
	await touch("city_deck_dismantle_lens")
	var confirmation := screen.find_child("PartDismantleConfirmation", true, false) as ConfirmationDialog
	check(confirmation != null and screen.campaign.s.parts.has("lens"), "dismantle waits for player confirmation")
	confirmation.canceled.emit()
	await settle()
	check(screen.campaign.s.parts.has("lens"), "cancel keeps stored part")
	var old_credits: int = screen.campaign.s.credits
	await touch("city_deck_dismantle_lens")
	confirmation = screen.find_child("PartDismantleConfirmation", true, false) as ConfirmationDialog
	confirmation.confirmed.emit()
	await settle()
	check(not screen.campaign.s.parts.has("lens") and screen.campaign.s.credits == old_credits + 10, "confirmed dismantle consumes one part for 10 credits")
	screen._close_workspace()
	# A real isolated profile exposes all supply choices and the saved-run entry.
	var saved = Campaign.new()
	saved.profile.unlocks = ["balanced", "amplify", "thermal", "voltage"]
	saved.profile.ascension = 3
	saved.start("burst", 9182)
	check(saved.save() == OK, "write isolated continuation fixture")
	screen._to_menu()
	await settle()
	bounds("resume")
	await capture("main_continue")
	await touch("new_run_setup")
	await touch("loadout_select_thermal")
	var thermal_count: int = saved.Content.LOADOUTS.thermal.deck.count("bore")
	check((screen.find_child("StartingRound_bore", true, false) as Label).text.ends_with("×%d" % thermal_count), "unlocked supply changes actual preview")
	screen.difficulty_option.value = 2
	await settle()
	check(screen.selected_difficulty == 2, "unlocked difficulty can be changed")
	await capture("unlocked_supplies")
	await touch("start_burst")
	var run_confirm := screen.find_child("NewRunConfirmation", true, false) as ConfirmationDialog
	check(run_confirm != null and screen.page == "loadout", "existing run is protected even after developer practice")
	if run_confirm != null: run_confirm.canceled.emit()
	await settle()
	var restored = Campaign.new()
	check(restored.restore() and int(restored.s.seed) == 9182, "cancel new run preserves saved campaign")
	screen.preferences.data.text_scale = 1.2
	screen._to_menu()
	await settle()
	bounds("new_run_setup")
	await touch("new_run_setup")
	bounds("start_burst")
	await capture("large_text_preparation")
	print("NAVIGATION UI COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
