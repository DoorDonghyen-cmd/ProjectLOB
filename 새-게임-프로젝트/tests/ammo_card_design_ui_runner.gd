extends "res://tests/ammo_cycle_ui_runner.gd"

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/card_design/"): quit(1);return
	screen=load("res://redesign/main.tscn").instantiate()
	screen.save_enabled=false
	screen.presentation_speed=0.02
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1008,630),Vector2i(1280,900),Vector2i(1440,630)]:
		root.size=resolution
		await setup_hand(["basic_p1","basic_p5","precise_p2_power","pierce_p3_cool","charge","cool"])
		cards_fit()
		var initial_height: float=screen.body.size.y
		await tap("load_charge")
		await tap("load_basic_p5")
		check(screen.model.s.plan==["basic_p5","charge"],"art preserves last-loaded-first firing")
		check(is_equal_approx(screen.body.size.y,initial_height),"loading does not grow the page")
		await capture("hand_selected_%d"%resolution.x)
		await setup_hand(["pierce_c","precise_c","charge_c","cool_c","bore_c","arc_c"])
		for button in screen.find_child("AmmoGrid",true,false).get_children():
			if button.visible: bounds(str(button.name))
		await capture("compressed_%d"%resolution.x)
		await setup_hand(["basic_p1","basic_p2","basic_p3","charge","precise","pierce","arc","push","bore","cool"],true)
		await tap("hand_next")
		check(screen.find_child("load_cool",true,false).is_visible_in_tree(),"ten-card bag still exposes last card")
		await capture("last_page_%d"%resolution.x)
		await tap("load_cool")
		check(screen.model.s.plan==["cool"],"last-page cooling card remains usable")
		screen._debug_city("reward");await settle()
		await tap("city_reward_volley_drive")
		var id: String=screen.campaign.reward_options()[0]
		var offer: Button=screen.find_child("city_reward_"+id,true,false)
		check(screen.get_node_or_null("AmmoAcquiredNotice")==null,"prior acquisition notice clears on navigation")
		offer.grab_focus();await settle()
		check(root.gui_get_focus_owner()==offer,"offer is keyboard focusable")
		await capture("focused_offer_%d"%resolution.x)
		await tap("city_reward_"+id)
		var before: Array=screen.model.s.deck.duplicate()
		await tap("DialogClose")
		check(screen.model.s.deck==before,"closing redesigned modal leaves deck untouched")
		await tap("city_reward_"+id);await tap("ammo_replace_basic_p1")
		var notice: Label=screen.get_node_or_null("AmmoAcquiredNotice")
		check(notice!=null and notice.text.contains("교체") and notice.mouse_filter==Control.MOUSE_FILTER_IGNORE,"successful acquisition has nonblocking feedback")
		await create_timer(0.15).timeout
		await capture("acquired_%d"%resolution.x)
	# Narrow display with larger surrounding text, many replacement profiles, and instant motion.
	root.size=Vector2i(1008,630)
	screen.preferences.data.text_scale=1.1
	screen.preferences.data.motion="instant"
	screen._debug_city("reward");await settle();await tap("city_reward_siege_drive")
	screen.model.s.deck=["basic_p1","basic_p2","basic_p3","basic_p4","basic_p5","basic_p2_power","basic_p3_cool","basic_p1","basic_p2","basic_p3"]
	screen.redraw();await settle()
	var id: String=screen.campaign.reward_options()[0]
	await tap("city_reward_"+id)
	await tap("ammo_replace_basic_p3_cool")
	check(screen.model.s.deck.has("basic_p2_power") and not screen.model.s.deck.has("basic_p3_cool"),"scrolling reaches exact modified card, without replacing similar stats")
	var notice: Label=screen.get_node_or_null("AmmoAcquiredNotice")
	check(notice!=null and is_equal_approx(notice.modulate.a,1.0),"instant preference keeps feedback legible without animation")
	# Both new authored scenes render representative contents outside campaign construction.
	var preview: Button = load("res://redesign/ammo_offer.tscn").instantiate()
	preview.position=Vector2(30,150);preview.size=Vector2(320,312)
	screen.add_child(preview)
	await settle()
	check(not preview.get_node("CardInfo").state.is_empty(),"standalone offer has representative data")
	preview.queue_free()
	check(not screen.save_enabled,"isolated design QA cannot save the player run")
	screen.queue_free();await process_frame
	print("AMMO CARD DESIGN UI COMPLETE checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
