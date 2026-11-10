extends SceneTree
const Campaign = preload("res://redesign/campaign.gd")
const Data = preload("res://redesign/content.gd")
var screen
var checks := 0
var failures := 0
var output := ""

func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: " + message)
func settle() -> void:
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
func shop(): return screen.find_child("ShopScreen", true, false)
func capture(name: String) -> void:
	await settle()
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "capture " + name)

func enter_shop(region: int = 0, outfit: String = "carrier", gun: String = "burst", magazine_mode: bool = false, map_version: int = Campaign.Content.RouteMap.VERSION) -> void:
	screen.campaign = Campaign.new()
	screen.campaign.start(gun, 251025, 0, "balanced", map_version, outfit, magazine_mode)
	screen.campaign.s.region = region
	screen.campaign.s.departure_step = 3
	screen.campaign.s.credits = 75
	var rooms: Array = screen.campaign.current_nodes()
	var target: Dictionary = rooms.filter(func(n): return n.kind == "shop")[0]
	var parent: Dictionary = rooms.filter(func(n): return n.next.has(target.id))[0]
	screen.campaign.s.node = parent.id
	screen.campaign.s.floor = parent.floor
	# Saved routes must form an actual path from the first entrance, including
	# previous region gates. Teleport-only fixtures are rightly rejected on load.
	screen.campaign.s.visited = []
	for previous_region in range(region + 1):
		var nodes: Array = Campaign.Content.nodes(previous_region, 251025, map_version)
		var end: Dictionary = parent if previous_region == region else nodes.filter(func(n): return n.kind == "boss")[0]
		var path: Array = [end.id]
		while int(end.floor) > 1:
			end = nodes.filter(func(n): return n.next.has(end.id))[0]
			path.push_front(end.id)
		screen.campaign.s.visited.append_array(path)
	screen.model = screen.campaign.model
	screen.page = "run"
	screen.debug_session = false
	screen.city_ui.shop_selection = 0
	screen._campaign_action("enter", target.id)
	await settle()
	check(shop() != null and screen.campaign.s.phase == "shop", "map entry reaches production shop")

func fixture_offers() -> void:
	screen.campaign.s.offers = [{"id":"precise_p1","type":"ammo","price":12,"sold":false}, {"id":"supply","type":"part","price":30,"sold":false}, {"id":"lens","type":"part","price":30,"sold":false}]
	screen.campaign.s.parts = ["volley_drive", "radiator"]
	screen.campaign.s.equipped_parts = screen.campaign.s.parts.duplicate()
	screen.campaign._sync_equipped_parts()
	screen.redraw()
	await settle()

func tap(key: String) -> void:
	var button: Button = shop().field(key)
	check(not button.disabled and button.is_visible_in_tree(), "tap available " + key)
	var parent: Node = button.get_parent()
	while parent != null:
		if parent is CanvasLayer: break
		if parent is ScrollContainer: parent.ensure_control_visible(button)
		parent = parent.get_parent()
	await settle()
	var point: Vector2 = button.get_global_transform_with_canvas() * (button.size * 0.5)
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.position = point; event.index = 0; event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await settle()

func layout() -> void:
	var view = shop()
	var area := root.get_visible_rect()
	for key in ["Room", "Title", "Manage", "Menu", "Settings", "Reroll", "Offer0", "Offer1", "Offer2", "Detail", "Buy", "Replace", "Bag", "Charge", "Exit"]:
		var control: Control = view.field(key)
		if control.is_visible_in_tree():
			var rect := control.get_global_rect()
			check(rect.position.x >= -2 and rect.end.x <= area.end.x+2,"readable page fits width " + key)
			check(area.grow(2).encloses(rect) or screen.main_scroll.get_v_scroll_bar().max_value > screen.main_scroll.get_v_scroll_bar().page,"offscreen content is reachable by vertical scrolling " + key)
	var card: Rect2 = view.field("Offer0").get_global_rect()
	var detail: Rect2 = view.field("Detail").get_global_rect()
	if view.field("SelectionRow").vertical:
		check(detail.position.y >= card.end.y,"narrow shop places details after offers")
	else:
		check(absf(card.position.y - detail.position.y) < 2 and absf(card.end.y - detail.end.y) < 2, "card/detail edges aligned")
	var actor = view.field("Hero")
	check(actor.image_rect().encloses(actor.actor_rect()), "indoor actor inside image")
	check(view.field("Room").texture.resource_path.contains("service_background_grouped_20261025"), "approved background live")
	check(actor.profile.texture.resource_path.contains("service_cohesion_20261025"), "approved indoor actor live")

func swipe_readable_shop() -> void:
	var scroll: ScrollContainer = shop().field("StoryScroll")
	if scroll.get_v_scroll_bar().max_value <= scroll.get_v_scroll_bar().page:
		check(scroll.get_global_rect().grow(2).encloses(shop().field("Voice").get_global_rect()), "short regional story is fully visible without nested scrolling")
		scroll = screen.main_scroll
		scroll.scroll_vertical = 0
		await settle()
	check(scroll.get_v_scroll_bar().max_value > scroll.get_v_scroll_bar().page, "readable shop provides vertical overflow")
	var origin := scroll.get_global_rect().get_center() + Vector2(0, 45)
	var pressed := InputEventScreenTouch.new()
	pressed.index = 0; pressed.position = root.get_final_transform() * origin; pressed.pressed = true
	pressed.window_id = root.get_window_id()
	Input.parse_input_event(pressed)
	await process_frame
	for i in range(1, 13):
		var drag := InputEventScreenDrag.new()
		drag.index = 0; drag.position = root.get_final_transform() * (origin + Vector2(0, -8 * i))
		drag.relative = root.get_final_transform().basis_xform(Vector2(0,-8)); drag.screen_relative = drag.relative
		drag.window_id = root.get_window_id()
		Input.parse_input_event(drag)
		await create_timer(0.018).timeout
	pressed.pressed = false; pressed.position = root.get_final_transform() * (origin + Vector2(0,-96))
	Input.parse_input_event(pressed)
	await create_timer(0.4).timeout
	check(scroll.scroll_vertical > 5, "finger scrolls the overflowing shop region")
	check(screen.campaign.s.credits == 75 and screen.campaign.s.phase == "shop", "story gesture does not buy or leave")
	await capture("story_touch_scrolled")

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/shop_live/"):
		quit(2); return
	output = OS.get_environment("QA_OUTPUT_DIR")
	DirAccess.make_dir_recursive_absolute(output)
	Input.emulate_mouse_from_touch = true
	Input.emulate_touch_from_mouse = true
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = true
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1600,900), Vector2i(1280,800), Vector2i(1008,630), Vector2i(1280,576), Vector2i(1440,630)]:
		root.size = resolution; root.content_scale_size = resolution
		await enter_shop()
		layout()
		check(shop().field("PartName").text == "코어 미장착", "no fabricated example core")
		await capture("shop_%dx%d" % [resolution.x,resolution.y])
		await fixture_offers()
		await tap("Offer1")
		check(shop().field("Change").text.contains("탄창"), "real part stat change")
		var before: int = Data.capacity(screen.model.s)
		await tap("Buy")
		check(screen.campaign.s.credits == 45 and Data.capacity(screen.model.s) == before + 1, "touch purchase changes current run")
		check(shop().field("Buy").disabled, "sold lock retained after redraw")
		var restored = Campaign.new()
		check(restored.restore() and restored.s.credits == 45 and restored.s.offers[1].sold and restored.s.equipped_parts.has("supply"), "actual automatic save restores purchase")
		layout()
	root.size = Vector2i(1600,900); root.content_scale_size = root.size
	await enter_shop(); await fixture_offers()
	var deck_size: int = screen.model.s.deck.size()
	await tap("Replace")
	check(shop().bag_ids.all(func(id): return Data.source_id(id) == "basic"), "replace choices follow basic-only rule")
	await tap("AmmoRow0")
	check(screen.model.s.deck.size() == deck_size and screen.model.s.deck.count("precise_p1") == 1 and screen.campaign.s.credits == 63, "replacement spends once and preserves deck size")
	await capture("purchase_replaced")
	await tap("Charge")
	check(screen.campaign.s.compressor_charges == 2 and screen.campaign.s.credits == 45, "compression charge saved")
	await tap("Reroll")
	check(screen.campaign.s.credits == 42 and shop().field("Charge").disabled, "reroll preserves visit charge lock")
	await tap("Manage")
	check(is_instance_valid(screen.workspace_overlay), "parts management opens existing run workspace")
	screen._close_workspace(); await settle()
	await tap("Details")
	check(shop().field("Overlay").visible, "real offer details open")
	var key := InputEventKey.new(); key.keycode = KEY_ESCAPE; key.pressed = true
	root.push_input(key, true); await settle()
	check(screen.page == "run" and not shop().field("Overlay").visible, "escape closes details without leaving shop")
	await tap("Exit")
	check(screen.campaign.s.phase == "map" and shop() == null and screen.page == "run", "continue returns to map, not process quit")
	var restored = Campaign.new()
	check(restored.restore() and restored.s.phase == "map" and restored.s.credits == 42, "map departure persisted")
	await enter_shop(); await fixture_offers()
	while screen.model.s.deck.size() < screen.model.deck_limit(): screen.model.s.deck.append("basic_p1")
	screen.redraw(); await settle()
	check(shop().field("Buy").disabled and not shop().field("Replace").disabled, "full deck exposes valid exchange")
	screen.campaign.s.credits = 1; screen.redraw(); await settle()
	check(shop().field("Buy").disabled and shop().field("Replace").disabled and shop().field("Reroll").disabled, "insufficient money blocks spending")
	await enter_shop(); await fixture_offers()
	screen.campaign.s.parts.append_array(["supply","ordinary_chain","loader"])
	screen.campaign.s.equipped_parts = screen.campaign.s.parts.duplicate()
	screen.campaign._sync_equipped_parts(); screen.redraw(); await settle()
	await tap("Offer2"); await tap("Buy")
	check(screen.campaign.s.parts.has("lens") and not screen.campaign.is_equipped("lens") and screen.campaign.equipped_parts().size() == 5, "full part slots buy to storage")
	await capture("part_to_storage")
	for region in range(5):
		await enter_shop(region, "expedition", "heavy")
		check(shop().field("Title").text == preload("res://redesign/city_story.gd").SHOPS[region].place, "region story bound " + str(region))
		check(shop().field("Weapon").text.contains(Data.GUNS.heavy.name), "actual weapon bound")
		layout()
		await capture("region_%d" % region)
	for outfit in Data.OUTFITS:
		await enter_shop(0, outfit)
		check(shop().field("Hero").profile.texture.resource_path.ends_with(outfit + ".png"), "outfit bound " + outfit)
		layout()
	# Long/conditional cards and every supported part use real descriptions, not demo branches.
	for id in ["charge_heat", "bore", "cool", "pierce_c", "arc", "precise_p3"] + Data.PARTS.keys().filter(func(id): return id != "none"):
		var ammo := Data.AMMO.has(id)
		screen.campaign.s.offers[0] = {"id":id,"type":"ammo" if ammo else "part","price":30,"sold":false}
		shop().select_offer(0); await settle()
		layout()
		shop().open_rules(); await settle()
		check(not str(shop().field("RulesText").text).is_empty(), "actual details " + id)
		shop().close_overlay()
	for resolution in [Vector2i(1600,900), Vector2i(1008,630), Vector2i(2340,1080)]:
		root.size = resolution; root.content_scale_size = resolution
		screen.preferences.data.text_scale = 1.1
		await enter_shop(1, "recovery", "heavy")
		layout()
		await capture("large_text_%dx%d" % [resolution.x,resolution.y])
		if resolution.x in [1008,2340]: await swipe_readable_shop()
	screen.preferences.data.text_scale = 1.0
	root.size = Vector2i(1600,900); root.content_scale_size = root.size
	await enter_shop(); screen.campaign.s.place_version = 0; screen.redraw(); await settle()
	check(shop().field("LegacyServices").visible, "legacy shop services preserved")
	layout()
	await capture("legacy_services")
	screen.queue_free(); await process_frame
	print("SHOP LIVE COMPLETE checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
