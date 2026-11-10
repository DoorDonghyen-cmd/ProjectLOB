extends SceneTree
const Actor = preload("res://redesign/weapon_actor.gd")
const Content = preload("res://redesign/content.gd")
const Services = preload("res://redesign/service_actor_catalog.gd")
var screen: Control
var output := ""
var checks := 0
var failures := 0
var evidence: Array = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: " + label)
func settle() -> void:
	for n in range(5): await process_frame
	await RenderingServer.frame_post_draw
func capture(name: String) -> void:
	await settle()
	check(root.get_texture().get_image().save_png(output.path_join(name + ".png")) == OK, "saved " + name)
func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/outfits_unified_20261025/"):
		quit(2); return
	output = OS.get_environment("QA_OUTPUT_DIR")
	root.size = Vector2i(1280,900); root.content_scale_size = root.size
	screen = load("res://redesign/main.tscn").instantiate(); screen.save_enabled = false; root.add_child(screen)
	await settle()
	for outfit in Content.OUTFITS:
		for gun in Content.GUNS:
			screen._open_preparation(false); await settle()
			var equipment = screen.find_child("EquipmentScreen",true,false)
			equipment._select_outfit(outfit); equipment._select_weapon(gun); await settle()
			var preview = equipment.get_node("%OutfitPortrait")
			var selected_hash := hash(preview.actor_viewport.get_texture().get_image().get_data())
			var selected_source: String = preview.actor.body_texture().resource_path
			if gun == "single" or (outfit in ["carrier","scout"] and gun == "burst"):
				await capture("equipment_" + outfit + "_" + gun)
			screen._debug_challenge("elite"); await settle()
			screen.model.s.outfit = outfit; screen.model.s.gun = gun; screen.redraw(); await settle()
			var view = screen.battle_view
			view.reduced_feedback = true; await settle()
			var actual = view.weapon_viewport.get_node("Actor")
			var battle_hash := hash(view.weapon_viewport.get_texture().get_image().get_data())
			check(selected_source == actual.body_texture().resource_path, "same actual source " + outfit + gun)
			check(selected_hash == battle_hash, "pixel-identical equipment/battle " + outfit + gun)
			evidence.append({"outfit":outfit,"gun":gun,"identical":selected_hash==battle_hash,"source":selected_source})
			if gun == "single" or (outfit in ["carrier","scout"] and gun == "burst"):
				await capture("battle_" + outfit + "_" + gun)
			view.set_process(false)
			for action in Actor.POSES[Actor.family(gun)]:
				actual.configure(gun, action, 0.5 if action=="recoil" else 0.0,0.4,0.8)
				var frame := Actor.frame_for(outfit,gun,action)
				var grip: Vector2 = actual.registered_transform() * Actor.WEAPONS[gun].grip
				check(grip.distance_to(Actor.FOOT+(frame.grip-frame.foot)*frame.scale)<0.01, "measured grip follows body " + outfit+gun+action)
				check(Rect2(Vector2.ZERO,actual.body_texture().get_size()).encloses(frame.source), "source frame within PNG")
				var projected: Vector2 = actual.registered_muzzle(view.player_feet(),view.character_scale())
				check(Rect2(Vector2.ZERO,view.size).has_point(projected), "live muzzle inside battlefield")
				for hand in actual.registered_hands():
					check(Rect2(Vector2.ZERO,frame.source.size).encloses(hand), "foreground hand inside source frame")
			view.set_process(true)
	for resolution in [Vector2i(1280,900), Vector2i(1008,630), Vector2i(1440,630)]:
		root.size = resolution; root.content_scale_size = resolution
		for outfit in Content.OUTFITS:
			for place_kind in ["shop","supply","workshop"]:
				screen._debug_city(place_kind);screen.campaign.s.outfit=outfit;screen.model.s.outfit=outfit;screen.redraw();await settle()
				var place: Control = screen.find_child("ShopScreen" if place_kind == "shop" else "ServiceLocation",true,false)
				check(place != null, "room exists")
				if place == null: continue
				var actor: Control = place.field("Hero") if place_kind == "shop" else place.get_node("%PlaceActor")
				check(actor.profile == Services.resolve(outfit, place_kind).profile, "selected indoor outfit " + outfit+place_kind)
				check(actor.image_rect().encloses(actor.actor_rect()), "room actor within panorama")
				check(actor.material is ShaderMaterial,"room shares clean alpha cutout")
				if resolution.x == 1280 or outfit in ["carrier","scout"]:
					await capture("%s_%s_%d" % [place_kind,outfit,resolution.x])
	var file := FileAccess.open(output.path_join("same_actor_evidence.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"\t"));file.close()
	check(Services.resolve("unknown_legacy_outfit","shop").displayed == "work", "legacy missing ID has explicit fallback")
	screen.queue_free();await process_frame
	print("UNIFIED OUTFIT COMPLETE checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
