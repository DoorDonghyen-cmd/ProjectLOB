extends "res://tests/fire_control_ui.gd"
func run()->void:
	output=OS.get_environment("QA_OUTPUT_DIR");Input.emulate_mouse_from_touch=true
	if not output.replace("\\","/").contains("/qa_runtime/late_balance_20261103/"):quit(2);return
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../qa_runtime/late_balance_20261103/climb_fire_v2_reference/combat_heavy_731042_r5_n40201.json"))
	for extent in [Vector2i(844,390),Vector2i(1280,800)]:
		root.size=extent
		var c=Campaign.new();check(c.restore_state(source),"earned v2 late battle restores for public UI")
		await mount(c);hud_bounds()
		check(Model.Content.burn_damage(c.model.s)==6,"earned level eight displays six damage fire")
		await tap("Parts")
		check(host.campaign_hud.node("DetailBody").text.contains("성장 2회마다"),"public build detail includes fire growth")
		await capture("thermal_growth_%dx%d"%[extent.x,extent.y])
		await tap("DetailDown")
		if extent.x<1000:check(host.campaign_hud.node("DetailScroll").scroll_vertical>0,"small detail can scroll through remaining build rules")
		await tap("CloseDetail")
		await tap("SelectedDetail")
		check(host.campaign_hud.node("DetailBody").text.contains("행동당 6"),"ammo detail displays current earned burn damage")
		await capture("fire_detail_%dx%d"%[extent.x,extent.y])
		await tap("CloseDetail")
		# Full actual forecast/shot/save with the owned late-game magazine.
		var oracle=Model.new();oracle.s=c.model.s.duplicate(true)
		host.campaign_hud.select_budget(1);oracle.s.fire_heat_trial.rounds=1;oracle.fire()
		host.campaign_hud.hud.feedback.save_setting("motion","fast")
		await tap("Fire")
		check(canonical(c.model.s)==canonical(oracle.s),"live v2 shot equals actual model")
		check(c.model.s.history.back().detail.results[0].burn_tick==6 and not c.model.s.fire_zones.is_empty(),"actual owned incendiary round leaves grown fire")
		var restored=Campaign.new();check(restored.restore() and canonical(restored.model.s)==canonical(c.model.s),"public v2 shot auto-saves exactly")
		await capture("grown_fire_%dx%d"%[extent.x,extent.y])
	host.free();await settle()
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("LATE BALANCE COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
