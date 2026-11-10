extends "res://tests/challenge_ui_runner.gd"

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/reserve/"): quit(1);return
	screen=load("res://redesign/main.tscn").instantiate()
	screen.save_enabled=false;screen.presentation_speed=0.08
	root.add_child(screen);await settle()
	for resolution in [Vector2i(1008,630),Vector2i(1280,900),Vector2i(1440,630)]:
		root.size=resolution;await settle()
		screen._open_preparation(false);await settle()
		var equipment=screen.find_child("EquipmentScreen",true,false)
		for outfit in Ammo.OUTFITS:
			equipment._select_outfit(outfit);await settle()
			var preview=screen.find_child("OutfitPortrait",true,false)
			check(preview.actor.outfit_id==outfit and preview.actor.gun_id==screen.selected_weapon_id,"selection uses combat costume and held gun")
			check(Rect2(Vector2.ZERO,preview.size).encloses(preview.display_rect()),"shared preview fits selection area")
			bounds("OutfitPortrait")
			if resolution.x==1280 or outfit=="work":await capture("equipment_%s_%d"%[outfit,resolution.x])
		await setup_hand(["bore","basic_p1","basic_p2","cool"])
		check(screen.model.s.reserve_version==1,"UI uses finite run")
		check(screen.find_child("QueueHeading",true,false).text.contains("개별 회수 불가"),"lock visible before first insertion")
		var before_detail:=JSON.stringify(screen.model.s)
		screen._hand_ammo_details("bore");await settle()
		check(JSON.stringify(screen.model.s)==before_detail,"pre-insertion details do not commit a round")
		screen._close_workspace();await settle()
		await tap("load_bore");await tap("load_basic_p1")
		check(screen.find_child("remove_selected",true,false)==null,"individual recall control removed")
		var inserted: Dictionary=screen.model.s.duplicate(true)
		await tap("slot_next")
		check(screen.model.s.plan==["bore","basic_p1"] and screen.model.s.hand==inserted.hand and screen.model.s.discard==inserted.discard,"touch reorder remains free")
		var before_undo:=JSON.stringify(screen.model.s)
		screen._undo()
		check(JSON.stringify(screen.model.s)==before_undo,"fallback undo input cannot bypass lock")
		check(screen.find_child("reload",true,false).text.contains("2발 배출") and screen.find_child("reload",true,false).text.contains("적 1턴"),"full ejection count and enemy turns visible")
		bounds("reload");bounds("slot_previous");bounds("slot_next");bounds("QueueHeading")
		await capture("load_lock_%d"%resolution.x)
		await tap("reload")
		check(screen.model.s.discard==["bore","basic_p1"] and not screen.model.s.hand.has("bore") and screen.model.s.hand.has("cool") and screen.model.s.hand.has("basic_p2"),"touch full ejection spends only inserted cards and retains uninserted hand")
		check(screen.model.s.turns==1 and screen.model.s.heat==0,"full ejection pays existing reload cost")
		await tap("ammo_bag");await tap("bag_tab_discard")
		await capture("load_lock_used_%d"%resolution.x)
		screen._close_workspace();await settle()
		await setup_hand(["bore","bore","basic_p1"])
		var compression_charges: int=screen.model.s.field_compression_left
		check(screen.model.field_compress("bore"),"temporary ejection fixture")
		screen.redraw();await settle()
		check(screen.find_child("remove_selected",true,false)==null and screen.find_child("reload",true,false).tooltip_text.contains("2장"),"temporary compression only offers full ejection with original count")
		await tap("reload")
		check(screen.model.s.discard==["bore","bore"] and screen.model.s.field_compression.is_empty() and screen.model.s.field_compression_left==compression_charges-1 and screen.model.s.hand.has("basic_p1"),"touch compressed ejection consumes originals and charge while retaining uninserted hand")
		await setup_hand(["bore","basic_p1","basic_p2","cool"])
		await tap("load_bore");await tap("confirm")
		check(screen.find_child("reload",true,false).text.contains("1발 배출"),"confirmed magazine also shows ejection count")
		await tap("reload")
		check(screen.model.s.discard==["bore"] and screen.model.s.hand.has("cool"),"touch committed ejection/retained hand")
		check(screen.find_child("ammo_bag",true,false).text.contains("9"),"remaining ammunition visible")
		await tap("ammo_bag");await tap("bag_tab_discard");await capture("used_%d"%resolution.x)
		screen._close_workspace();await settle()
		await setup_hand(["basic_p1","basic_p2","basic_p3"])
		screen.city_ui.ui=screen
		screen.city_ui.campaign=screen.campaign
		screen.city_ui.acquire_ammo("bore","reward","bore")
		await settle()
		check(screen.find_child("ammo_acquire_add",true,false)!=null,"acquisition offers addition")
		await capture("acquisition_%d"%resolution.x)
		# Close by the dialog control, without mutating the campaign.
		var close=screen.find_child("DialogClose",true,false)
		if close:await tap("DialogClose")
		for kind in ["elite","boss"]:
			screen._debug_challenge(kind);await settle()
			var view=screen.battle_view
			check(Rect2(Vector2.ZERO,view.size).encloses(view.intent_rect(0)),"actor-linked intent inside field")
			check(not view.intent_rect(0).intersects(view.enemy_plaque(0)),"intent distinct from HP")
			await capture("%s_intent_%d"%[kind,resolution.x])
			await replay_reload();await replay_reload()
			if kind=="elite" and resolution.x==1280:
				screen.presentation_speed=0.5
				await begin_touch("reload")
				var captured_link:=false
				var wait_started:=Time.get_ticks_msec()
				while screen.busy and Time.get_ticks_msec()-wait_started<15000:
					if screen.battle_view.pulled_target>=0 and not captured_link:
						captured_link=true
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join("elite_resonance_link.png"))
					await process_frame
				check(captured_link,"elite source-to-escort link visibly rendered")
				screen.presentation_speed=0.08
			else:await replay_reload()
			view=screen.battle_view
			if kind=="elite":
				check(screen.last_presentation.events.any(func(e):return e.kind=="command_link"),"elite cause-to-target link")
			else:
				check(view.challenge_intent(0).contains("장갑 0"),"open armor consequence explicit")
				await capture("boss_open_%d"%resolution.x)
	root.size=Vector2i(1008,630);await setup_hand(["precise_c","basic_p1","basic_p2"])
	await tap("load_basic_p1");await tap("load_precise_c")
	check(screen.find_child("QueueHeading",true,false).text=="첫 발 고정 · 비우려면 재장전","anchored queue explains available escape")
	check(screen.model.load_block_reason("basic_p2")=="첫 발 고정","anchored blocked card never advises recall")
	bounds("QueueHeading");bounds("reload")
	await capture("load_lock_anchored_1008")
	await tap("reload")
	check(screen.model.can_load("basic_p2") and screen.model.s.discard==["precise_c","basic_p1"],"anchored loadout can be fully ejected through touch")
	# Observe the real overheat sequence before cooling resets the number.
	root.size=Vector2i(1280,900);await setup_hand(["charge_hot","precise","cool"])
	screen.model.s.heat=10
	screen.presentation_speed=0.6
	screen.redraw();await settle()
	for id in ["cool","precise","charge_hot"]:await tap("load_"+id)
	await tap("confirm");await begin_touch("fire")
	var seen:=false
	var started:=Time.get_ticks_msec()
	while screen.busy and Time.get_ticks_msec()-started<15000:
		if screen.preview_label.text.contains("잔탄") and not seen:
			seen=true
			check(screen.find_child("reload",true,false).text.contains("적도"),"forced cooling states enemy action cost")
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join("overheat_cost.png"))
		await process_frame
	check(seen and not screen.busy,"overheat cost readable then completes")
	check(screen.last_presentation.events.any(func(e):return e.kind=="overheat_consequence"),"overheat event retained")
	await capture("after_forced_reload")
	await setup_hand(["basic_p1"])
	screen.model.s.draw.clear();screen.model.s.discard=screen.model.s.deck.duplicate();screen.model.s.discard.erase("basic_p1")
	screen.redraw();await settle()
	await tap("load_basic_p1");await tap("reload")
	check(screen.model.s.loss_reason=="ammo" and screen.campaign.s.phase=="lost","last ejection reaches campaign loss without softlock")
	check(screen.campaign.save()==OK,"ejection exhaustion campaign saves")
	var restored=Campaign.new()
	check(restored.restore() and restored.s.phase=="lost" and restored.model.s.loss_reason=="ammo","ejection exhaustion campaign restores")
	await capture("load_lock_exhaustion")
	await setup_hand(["bore","basic_p1"])
	screen.model.s.erase("reserve_version");screen.redraw();await settle()
	await tap("load_bore")
	check(screen.find_child("remove_selected",true,false)!=null,"legacy save retains its recall control")
	await tap("remove_selected")
	check(screen.model.s.plan.is_empty() and screen.model.s.hand.has("bore") and screen.model.s.discard.is_empty(),"legacy recall still works through UI")
	var file=FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("ui.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures}));file.close()
	print("RESERVE UI COMPLETE checks=%d failures=%d"%[checks,failures])
	screen.queue_free();await process_frame
	quit(0 if failures==0 else 1)
