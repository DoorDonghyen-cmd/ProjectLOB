extends "res://tests/ammo_risk_ui_runner.gd"

func finger(point: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = root.get_final_transform() * point
	event.pressed = down
	event.window_id = root.get_window_id()
	Input.parse_input_event(event)
	await process_frame

func swipe(point: Vector2, movement: Vector2) -> void:
	await finger(point, true)
	for i in range(1, 13):
		var event := InputEventScreenDrag.new()
		event.index = 0
		event.position = root.get_final_transform() * (point + movement * i / 12.0)
		event.relative = root.get_final_transform().basis_xform(movement / 12.0)
		event.screen_relative = event.relative
		event.window_id = root.get_window_id()
		Input.parse_input_event(event)
		await create_timer(0.018).timeout
	await finger(point + movement, false)
	await create_timer(0.4).timeout
	await settle()


func press(key: String) -> void:
	var button := screen.find_child(key, true, false) as Control
	if button == null:
		check(false, "missing " + key)
		return
	var ancestor := button.get_parent()
	while ancestor != null:
		if ancestor is ScrollContainer: ancestor.ensure_control_visible(button)
		ancestor = ancestor.get_parent()
	await settle()
	await tap(key)

func place_check(kind: String) -> void:
	var place := screen.find_child("ServiceLocation", true, false) as Control
	check(place != null, "location visible " + kind)
	if place == null: return
	var art := place.get_node("%PlaceArt") as TextureRect
	check(art.texture.resource_path.ends_with(kind + "_background.png"), "correct artwork " + kind)
	check(art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_CENTERED, "complete image preserved")
	check(art.mouse_filter == Control.MOUSE_FILTER_IGNORE, "art allows touch scrolling")
	check(place.size.x <= screen.size.x, "location fits width")
	check(not screen.main_scroll.get_h_scroll_bar().visible, "no horizontal scrolling")

func check_layers(kind: String) -> void:
	var place: Control = screen.find_child("ServiceLocation",true,false)
	var art := place.get_node("%PlaceArt") as TextureRect
	var actor: Control = place.get_node("%PlaceActor")
	var original: Resource = actor.profile
	var state_before := hash(screen.campaign.s)
	var model_before := hash(screen.model.s)
	var background := art.texture
	check(original.texture.get_image().detect_alpha() != Image.ALPHA_NONE, "sprite has genuine transparency")
	check(actor.image_rect().encloses(actor.actor_rect()), "registered actor lies inside complete panorama")
	var foot: Vector2 = actor.actor_rect().position + actor.actor_rect().size * original.foot_in_source
	check(foot.distance_to(actor.image_rect().position + actor.image_rect().size * actor.room_foot) < 0.01, "foot uses the room transform")
	for outfit in ["carrier","scout","unknown",""]:
		place.set_outfit(outfit)
		check(place.requested_outfit == outfit and place.displayed_outfit == "work" and place.outfit_fallback, "missing outfit art falls back explicitly " + outfit)
		check(art.texture == background and actor.profile == original, "fallback does not alter room or blank hero")
	place.set_outfit("work")
	check(not place.outfit_fallback, "default outfit exists")
	check(hash(screen.campaign.s) == state_before and hash(screen.model.s) == model_before, "visual selection does not mutate run or combat")
	if root.size.x != 1008: return
	# Let screen entrance colors settle before byte-exact layer comparisons.
	await create_timer(0.8).timeout
	await settle()
	var shown := root.get_texture().get_image()
	actor.hide()
	await capture("layers_hidden_"+kind)
	var hidden := root.get_texture().get_image()
	var region: Rect2 = actor.actor_rect()
	var transform := root.get_final_transform() * actor.get_global_transform_with_canvas()
	region.position = transform * region.position
	region.size = transform.basis_xform(region.size)
	shown.save_png(OS.get_environment("QA_OUTPUT_DIR").path_join("layers_before_"+kind+".png"))
	var x0 := maxi(0,floori(region.position.x)-3)
	var x1 := mini(shown.get_width(),ceili(region.end.x)+3)
	check(shown.get_region(Rect2i(0,0,x0,shown.get_height())).get_data() == hidden.get_region(Rect2i(0,0,x0,hidden.get_height())).get_data(), "hiding actor leaves left background byte-identical")
	check(shown.get_region(Rect2i(x1,0,shown.get_width()-x1,shown.get_height())).get_data() == hidden.get_region(Rect2i(x1,0,hidden.get_width()-x1,hidden.get_height())).get_data(), "hiding actor leaves right background byte-identical")
	check(shown.get_data() != hidden.get_data(), "independent hero actually renders")
	actor.show()
	await capture("layers_composed_"+kind)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/service_locations/"):
		quit(1); return
	Input.emulate_mouse_from_touch = true
	Input.emulate_touch_from_mouse = true
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1280,900),Vector2i(1008,630),Vector2i(1440,630)]:
		root.size = resolution
		for kind in ["shop","supply","workshop"]:
			screen._debug_city(kind)
			await settle()
			place_check(kind)
			await check_layers(kind)
			await capture("%s_%d" % [kind,resolution.x])
			if kind == "shop":
				check(screen.find_child("ShopStoryText", true, false) != null, "shop story on arrival")
				check(not is_instance_valid(screen.workspace_overlay), "story leaves trading available")
				var credits: int = screen.campaign.s.credits
				var price: int = screen.campaign.s.offers[0].price
				await press("city_compare_buy_0")
				check(screen.campaign.s.offers[0].sold and screen.campaign.s.credits == credits-price, "purchase keeps price and sold state")
				await press("city_shop_press")
				var before: String = JSON.stringify(screen.campaign.s)
				await capture("compression_%d" % resolution.x)
				await press("workspace_close")
				check(JSON.stringify(screen.campaign.s) == before, "cancel compression costs nothing")
				await press("city_shop_press")
				var source: String = screen.campaign.compressible_ids()[0]
				var count: int = screen.model.s.deck.size()
				credits = screen.campaign.s.credits
				await press("city_compress_"+source)
				check(screen.campaign.s.shop_refined and screen.model.s.deck.size() == count-1, "compression consumes two cards creates one")
				check(screen.campaign.s.credits == credits-screen.campaign.COMPRESSION_PRICE, "compression price retained")
				await press("city_leave")
				check(screen.campaign.s.phase == "map", "shop exit")
			elif kind == "supply":
				var count: int = screen.model.s.deck.size()
				await press("city_supply_"+str(screen.campaign.reward_options()[0]))
				check(screen.campaign.s.resolved and screen.model.s.deck.size() == count+1, "supply receipt")
				place_check("supply")
				await press("city_leave")
				check(screen.campaign.s.phase == "map", "supply exit")
			else:
				await press("city_workshop_press")
				var source: String = screen.campaign.compressible_ids()[0]
				await press("city_workshop_compress_"+source)
				check(screen.campaign.s.resolved, "free workshop compression resolves")
				place_check("workshop")
				await press("city_leave")
				check(screen.campaign.s.phase == "map", "workshop exit")
	root.size = Vector2i(1008,630)
	screen._debug_city("shop")
	await settle()
	var art: Control = screen.find_child("ServiceLocation",true,false).get_node("%PlaceArt")
	var before_credits: int = screen.campaign.s.credits
	await swipe(art.get_global_rect().get_center(), Vector2(0,-150))
	check(screen.main_scroll.scroll_vertical > 30, "finger scroll begins on location art")
	check(screen.campaign.s.credits == before_credits, "art swipe does not purchase")
	await capture("shop_touch_scroll_1008")
	screen.campaign.s.credits = 0
	screen.redraw()
	await settle()
	await press("city_shop_press")
	var id: String = screen.campaign.compressible_ids()[0]
	check(screen.find_child("city_compress_"+id,true,false).disabled, "unaffordable compression disabled")
	var scroll := screen.workspace_overlay.find_child("WorkspaceScroll",true,false) as ScrollContainer
	art = screen.workspace_overlay.find_child("ServiceLocation",true,false).get_node("%PlaceArt")
	await swipe(art.get_global_rect().get_center(),Vector2(0,-140))
	check(scroll.scroll_vertical > 30, "finger scroll begins on compression illustration")
	await press("workspace_close")
	screen._debug_city("supply")
	screen.model.s.deck.resize(14)
	screen.redraw()
	await settle()
	for ammo in screen.campaign.reward_options():
		check(screen.find_child("city_supply_"+str(ammo),true,false).disabled,"full deck cannot receive")
	await press("city_service_skip")
	await press("city_leave")
	check(screen.campaign.s.phase == "map", "full deck can leave supply")
	# The live campaign, not the preparation selection, drives each location.
	for outfit in ["work", "carrier", "scout"]:
		screen._debug_city("shop")
		screen.campaign.s.outfit = outfit
		screen.model.s.outfit = outfit
		screen.redraw()
		await settle()
		var place: Control = screen.find_child("ServiceLocation",true,false)
		check(place.requested_outfit == outfit, "campaign outfit reaches location " + outfit)
		await press("city_shop_press")
		place = screen.workspace_overlay.find_child("ServiceLocation",true,false)
		check(place.requested_outfit == outfit, "campaign outfit reaches compression overlay " + outfit)
		await press("workspace_close")
	# Every location has a composed scene even with its script removed before ready.
	for kind in ["shop","supply","workshop"]:
		var scene: Control = load("res://redesign/location_"+kind+".tscn").instantiate()
		scene.set_script(null)
		check(scene.get_node("%PlaceArt").texture != null and not scene.get_node("%PlaceTitle").text.is_empty(), "authored scene has art and context before ready")
		scene.free()
	print("SERVICE LOCATIONS COMPLETE checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
