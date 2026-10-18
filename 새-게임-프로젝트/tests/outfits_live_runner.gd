extends "res://tests/navigation_ui_runner.gd"
const Actor = preload("res://redesign/weapon_actor.gd")
const OutfitArt = preload("res://redesign/outfit_art.gd")
const Model = preload("res://redesign/model.gd")
const IDS := ["heatworker", "hoist", "recovery", "expedition"]

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/outfits_live/"):
		quit(2)
		return
	output = OS.get_environment("QA_OUTPUT_DIR")
	Input.emulate_mouse_from_touch = true
	Input.emulate_touch_from_mouse = true
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	await settle()
	check(screen.selected_outfit_id == "scout", "fresh menu defaults to four-card scout")
	screen._open_preparation(false)
	await settle()
	var rail: ScrollContainer = screen.find_child("OutfitScroll", true, false)
	rail.scroll_vertical = 0
	await settle()
	var point := rail.get_global_rect().get_center() + Vector2(0,60)
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.window_id = root.get_window_id()
	down.position = root.get_final_transform() * point
	down.pressed = true
	Input.parse_input_event(down)
	await process_frame
	for step in range(1,13):
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.window_id = root.get_window_id()
		drag.position = root.get_final_transform() * (point - Vector2(0,step*12))
		drag.relative = Vector2(0,-12)
		drag.screen_relative = drag.relative
		Input.parse_input_event(drag)
		await create_timer(0.02).timeout
	down = down.duplicate()
	down.pressed = false
	down.position -= Vector2(0,144)
	Input.parse_input_event(down)
	await create_timer(0.4).timeout
	check(rail.scroll_vertical > 30, "finger swipe scrolls costume rail")
	check(screen.selected_outfit_id == "scout", "scroll gesture does not select costume")
	bounds("start_" + screen.selected_weapon_id)
	for id in IDS:
		for gun in Content.GUNS:
			var campaign = Campaign.new()
			campaign.start(gun, 19324, 0, "balanced", 1, id)
			check(campaign.enter(101), "legal room entry")
			check(campaign.model.s.hand.size() == Content.OUTFITS[id].hand, "opening hand capacity " + id)
			check(campaign.model.s.exchange_left == 0, "no unassigned exchange bonus")
			var ammo: String = campaign.model.s.hand[0]
			check(campaign.model.load_round(ammo), "real owned card can load")
			var saved := {"campaign": campaign.s.duplicate(true), "combat": campaign.model.s.duplicate(true), "profile": campaign.profile.duplicate(true)}
			var restored = Campaign.new()
			check(restored.restore_state(saved), "new outfit restores pending card")
			check(restored.s.outfit == id and restored.model.s.outfit == id, "resume keeps outfit")
			check(restored.model.s.plan == campaign.model.s.plan, "resume keeps plan")
			check(restored.model.confirm() and restored.model.fire(), "new outfit combat executes")
			campaign.s.region = 4
			campaign.s.phase = "gate"
			campaign.s.resolved = false
			while campaign.can_grow_bag(): campaign._grow_bag()
			check(Content.hand_capacity(campaign.model.s) == 10, "existing growth caps at ten")
			check(not campaign.gate("bag"), "growth beyond ten rejected")
			check(Model.new().restore_state(campaign.model.s), "expanded bag state valid")
	# Older v1 outfits keep their previous bag and need no migration.
	for id in ["work", "carrier", "scout"]:
		var legacy = Model.new()
		legacy.start("single", 231, false, id)
		legacy.s.erase("bag_version")
		legacy.s.erase("bag_upgrades")
		check(Content.hand_capacity(legacy.s) == Content.LEGACY_OUTFIT_HAND[id], "legacy capacity preserved " + id)
	for resolution in [Vector2i(1280,900), Vector2i(1008,630), Vector2i(1440,630)]:
		root.size = resolution
		root.content_scale_size = resolution
		await settle()
		for id in IDS:
			var campaign = Campaign.new()
			campaign.start("single", 19324, 0, "balanced", 1, id)
			campaign.enter(101)
			screen.campaign = campaign
			screen.model = campaign.model
			screen.page = "run"
			screen.redraw()
			await settle()
			var view: Control = screen.battle_view
			var actor: Node2D = view.weapon_viewport.get_node("Actor")
			check(actor.outfit_id == id, "live campaign selects body " + id)
			check(actor.body_texture() == OutfitArt.BODIES[id].pistol, "live body is distinct")
			await capture("battle_%s_%d" % [id,resolution.x])
			# Use the production viewport and compositing code for every gun/key pose.
			for gun in Content.GUNS:
				for pose in Actor.POSES[Actor.family(gun)]:
					actor.configure(gun, pose, 0.6, 0.4, 0.7)
					view.set_process(false)
					view.weapon_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
					await settle()
					var pixels: Image = view.weapon_viewport.get_texture().get_image()
					check(not pixels.is_invisible(), "costume renders " + id + gun + pose)
					check(actor.body_texture() == OutfitArt.BODIES[id][Actor.family(gun)], "correct weapon family")
					var used := pixels.get_used_rect()
					check(used.position.x > 0 and used.position.y > 0 and used.end.x < 768 and used.end.y <= 512, "no actor clipping " + id + gun + pose)
					if resolution.x == 1280 and pose == "aim":
						pixels.save_png(output.path_join("actor_%s_%s.png" % [id,gun]))
			view.set_process(true)
			for place_kind in ["shop", "supply", "workshop"]:
				screen._debug_city(place_kind)
				screen.campaign.s.outfit = id
				screen.model.s.outfit = id
				screen.redraw()
				await settle()
				var place: Control = screen.find_child("ServiceLocation",true,false)
				check(place != null, "service screen present")
				if place == null: continue
				check(place.displayed_outfit == id and not place.outfit_fallback, "service uses selected costume " + place_kind + id)
				var room_actor: Control = place.get_node("%PlaceActor")
				check(room_actor.image_rect().encloses(room_actor.actor_rect()), "room actor grounded inside panorama")
				await capture("%s_%s_%d" % [place_kind,id,resolution.x])
	print("OUTFITS LIVE COMPLETE checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
