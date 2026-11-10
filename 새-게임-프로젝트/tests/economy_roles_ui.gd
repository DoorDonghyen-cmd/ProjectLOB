extends "res://tests/fire_control_ui.gd"
## RETIRED 2026-11-08 as a run target: checks old gate and shop buttons (city_gate_*). Replaced by: gate_live_ui, shop_terminal_live_runner.
## Current UI suites: docs/qa/ui-test-suites.md
func fixture(folder: String,file: String):
	var c=Campaign.new()
	check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string("res://../qa_runtime/economy_roles_20261103/"+folder+"/"+file+".json"))),"earned economy UI fixture restores")
	return c
func run()->void:
	output=OS.get_environment("QA_OUTPUT_DIR");Input.emulate_mouse_from_touch=true
	if not output.replace("\\","/").contains("/qa_runtime/economy_roles_20261103/"):quit(2);return
	for extent in [Vector2i(844,390),Vector2i(1280,800)]:
		root.size=extent
		var c=fixture("climb_carrier_heavy","shop_heavy_17_r1_n503")
		await mount(c);await tap("Offer1")
		check(host.find_child("Balance",true,false).text.contains("첫 연결"),"purchase panel explains one-time offer")
		await capture("intro_offer_%dx%d"%[extent.x,extent.y])
		var wallet: int=c.s.credits
		await tap("Buy")
		check(c.s.intro_part_bought and c.s.credits==wallet-18 and c.s.parts.has("coil"),"public discounted purchase grants exact owned module")
		var resumed=Campaign.new();check(resumed.restore() and canonical(resumed.s)==canonical(c.s),"discount consumption auto-saves")
		c=fixture("climb_scout_burst","gate_burst_731042_r1")
		await mount(c);await tap("city_gate_cadence");await tap("city_gate_apply")
		var limit: int=c.model.deck_limit();wallet=c.s.credits
		var ammo: Array=c.model.s.deck.duplicate()
		await tap("city_gate_bag_service")
		check(c.s.gate_bag_used and c.model.deck_limit()==limit+2 and c.s.credits==wallet-18,"paid gate input increases carry capacity and charges once")
		check(c.model.s.deck==ammo and c.model.s.gate_mods.cadence==1,"paid reorganization keeps ammo and free upgrade")
		var button: Button=host.find_child("city_gate_bag_service",true,false)
		check(button.disabled,"double input prevented after paid service")
		var viewport: Rect2=Rect2(Vector2.ZERO,Vector2(extent))
		var rect:=Rect2(button.get_global_transform_with_canvas().origin,button.size*button.get_global_transform_with_canvas().get_scale())
		# Scroll the existing page through the same visible control used by tap().
		var parent: Node=button.get_parent()
		while parent!=null:
			if parent is ScrollContainer:parent.ensure_control_visible(button)
			parent=parent.get_parent()
		await settle();rect.position=button.get_global_transform_with_canvas().origin
		check(viewport.grow(1).encloses(rect),"paid service fits actual viewport after scroll")
		await capture("gate_storage_%dx%d"%[extent.x,extent.y])
		check(resumed.restore() and canonical(resumed.s)==canonical(c.s) and canonical(resumed.model.s)==canonical(c.model.s),"paid expansion auto-saves all state")
		await tap("city_gate_depart")
		check(c.s.phase=="map" and not c.s.gate_bag_used,"departure resets visit lock")
		c=fixture("climb_expedition_single","gate_single_931104_r1")
		await mount(c);await tap("city_gate_cadence");await tap("city_gate_apply")
		var main: String=Model.FocusBuild.main_round(c.model.s)
		var count: int=c.model.s.deck.count(main);wallet=c.s.credits
		await tap("city_gate_copy_service")
		check(host.find_child("GateCopyOptions",true,false)!=null,"copy choice opens existing dialog shell")
		await capture("gate_copy_%dx%d"%[extent.x,extent.y])
		await tap("gate_copy_"+main)
		check(c.s.gate_ammo_used and c.model.s.deck.count(main)==count+1 and c.s.credits==wallet-c.gate_copy_price(main),"public copy pays exact price and grants one owned round")
		check(host.find_child("city_gate_bag_service",true,false).disabled and host.find_child("city_gate_copy_service",true,false).disabled,"both services lock after copy")
		check(resumed.restore() and canonical(resumed.model.s)==canonical(c.model.s),"copied ammo automatically resumes")
	host.free();await settle()
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("ECONOMY ROLES COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
