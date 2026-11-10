extends "res://tests/ammo_cycle_ui_runner.gd"
var applications := 0
var burns := 0

func on_impact(result: Dictionary) -> void:
	if int(result.get("burn_added",0)) <= 0: return
	applications += 1
	check(screen.preview_label.text.contains("화상 2/턴"),"live impact announces successful burn")
	var text: Dictionary=preload("res://redesign/damage_readout.gd").entry(result)
	check(text.number=="화상" and text.label.contains("3턴"),"shielded impact popup describes application")
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join("shielded_application.png"))==OK,"application capture")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/incendiary/"):
		quit(1);return
	screen=load("res://redesign/main.tscn").instantiate()
	screen.save_enabled=false
	screen.presentation_speed=0.4
	root.add_child(screen)
	await settle()
	for resolution in [Vector2i(1008,630),Vector2i(1280,900),Vector2i(1440,630)]:
		root.size=resolution
		await setup_hand(["bore","bore_c","basic_p3","cool"])
		screen.model.s.enemies=[Data._enemy(["absorber",40,6,1,24])]
		screen.model.assign_opening_lanes()
		screen.redraw()
		await settle()
		cards_fit()
		var card=screen.find_child("load_bore",true,false).get_node("CardInfo")
		check(Ammo.primary_stat("bore",screen.model.s)=={"label":"화상 / 턴","value":"2"},"primary communicates tick damage")
		check(card.footer_text()=="3턴 · 보호막 무시","full card explains duration and shield")
		check(preload("res://redesign/ammo_hand_face.gd").secondary("bore",screen.model.s)=="3턴 지속","compact duration")
		check(card.heat_text()=="+4","weapon heat distinct from burn")
		await tap("load_bore")
		check(screen.model.s.plan==["bore"],"touch loads incendiary")
		check(screen.find_child("HeatGauge",true,false).reading_text()=="발열 0 → 예상 4 / 12","load previews heat")
		check(screen.preview_label.text.contains("피해 2(화상 2)"),"summary counts actual first burn tick")
		check(screen.magazine_view.forecast_readout(0).value=="화상 2/턴" and screen.magazine_view.forecast_readout(0).note=="3턴 · 보호막 무시","rendered rail emphasizes burn over blocked impact")
		cards_fit()
		await capture("planned_%d"%resolution.x)
		screen._hand_ammo_details("bore")
		await settle()
		await capture("details_%d"%resolution.x)
		screen._close_workspace()
		await settle()
		if resolution.x==1280:
			await tap("confirm")
			screen.battle_view.shot_impacted.connect(on_impact)
			await tap("fire")
			check(screen.model.s.enemies[0].hp==38 and screen.model.s.enemies[0].barrier==1,"public fire bypasses remaining shield")
			check(screen.model.s.enemies[0].burn==2 and screen.model.s.heat==4,"burn and weapon heat are distinct states")
			for event in screen.last_presentation.events:
				if event.kind=="burn":
					burns+=1
					check(event.damage==2,"shown dot matches actual damage")
			await capture("after_burn")
			await tap("reload")
			check(screen.model.s.enemies[0].hp==36 and screen.model.s.enemies[0].burn==1,"public reload ticks again")
			await capture("after_reload")
	check(applications==1 and burns==1,"burn application and tick both presented")
	check(not screen.save_enabled,"user save untouched")
	var file=FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("ui.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"applications":applications,"ticks":burns},"  "));file.close()
	screen.queue_free()
	await process_frame
	print("INCENDIARY UI COMPLETE checks=%d failures=%d"%[checks,failures])
	quit(0 if failures==0 else 1)
