extends "res://tests/ammo_cycle_ui_runner.gd"

func six_hand() -> void:
	await setup_hand(["charge","precise","pierce","bore","push","cool"])
	screen.model.s.outfit = "carrier"
	screen.model.s.exchange_left = Ammo.exchange_capacity(screen.model.s)
	screen.campaign.s.outfit = "carrier"
	screen.redraw()
	await settle()

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/ammo_synergy/"): quit(1); return
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.03
	root.add_child(screen)
	await settle()
	check(screen.selected_outfit_id == "carrier","new preparation defaults to six-card outfit")
	screen._open_preparation(false)
	await settle()
	await tap("start_single")
	check(screen.campaign.s.outfit == "carrier" and Ammo.hand_capacity(screen.model.s) == 6 and screen.model.s.exchange_left == 0,"real launch keeps six-card choice")
	for resolution in [Vector2i(1008,630),Vector2i(1280,900),Vector2i(1440,630)]:
		root.size = resolution
		await six_hand()
		cards_fit()
		bounds("ammo_synergy")
		bounds("ammo_bag")
		var before := JSON.stringify(screen.model.s)
		await tap("ammo_synergy")
		check(screen.find_child("AmmoSynergyDetails",true,false) != null,"touch opens combination guide")
		await capture("hand_pairs_%d" % resolution.x)
		await tap("workspace_close")
		check(JSON.stringify(screen.model.s)==before,"guide and closing cost no turn/card")
		await tap("load_precise")
		var button := screen.find_child("load_charge",true,false)
		check(not button.get_meta("synergy",{}).is_empty() and not button.get_meta("synergy").move,"support candidate means immediate correct insertion")
		check(button.get_node("CardInfo").footer_text()==button.get_node("CardInfo").effect_text(),"candidate indicator preserves cost and effect text")
		await capture("support_candidates_%d" % resolution.x)
		await six_hand()
		await tap("load_charge")
		check(screen.find_child("load_precise",true,false).get_meta("synergy").move,"reverse insertion explicitly needs reorder")
		check(screen.find_child("load_pierce",true,false).get_meta("synergy").move,"second recipient offered")
		await capture("recipient_candidates_%d" % resolution.x)
		await tap("ammo_synergy")
		await capture("reorder_guide_%d" % resolution.x)
		await tap("workspace_close")
		await tap("load_precise")
		check(screen.model.s.plan==["precise","charge"],"hint never silently reorders LIFO")
		await tap("slot_next")
		check(screen.model.s.plan==["charge","precise"],"explicit rail button creates the suggested order")
		cards_fit()
		await capture("linked_rail_%d" % resolution.x)
		await tap("confirm")
		await tap("fire")
		check(screen.model.s.history.back().detail.results.back().damage==12,"actual input resolves two amplified hits")
		check(screen.find_child("ammo_synergy",true,false).disabled,"guide does not suggest new loads after confirmation")
	print("AMMO SYNERGY UI COMPLETE checks=%d failures=%d" % [checks,failures])
	screen.queue_free()
	await process_frame
	quit(0 if failures==0 else 1)
