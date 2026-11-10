extends "res://tests/fire_control_ui.gd"
func labels(node: Node)->String:
	var result:=""
	if node is Label or node is RichTextLabel:result=node.text+"\n"
	for child in node.get_children():result+=labels(child)
	return result
func run()->void:
	output=OS.get_environment("QA_OUTPUT_DIR");Input.emulate_mouse_from_touch=true
	if not output.replace("\\","/").contains("/qa_runtime/build_roles_20261103/"):quit(2);return
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../qa_runtime/build_roles_20261103/climb_earned/shop_heavy_17_r1_n503.json"))
	for extent in [Vector2i(844,390),Vector2i(1280,800)]:
		root.size=extent
		var c=Campaign.new();check(c.restore_state(source),"earned role-specific shop restores")
		await mount(c)
		check(c.s.offers[1].id=="coil","actual fire deck exposes fire module")
		await tap("Offer1");await capture("fire_shop_%dx%d"%[extent.x,extent.y])
		await tap("Details")
		check(host.find_child("RulesText",true,false).text.contains("불길"),"public fire module detail explains ground synergy")
		await capture("coil_detail_%dx%d"%[extent.x,extent.y])
		# Remount the exact earned shop for a real unsold purchase and auto-save.
		await mount(c)
		var offer: Dictionary=c.s.offers[2];var credits: int=c.s.credits
		check(not offer.sold and credits>=int(offer.price),"earned wallet can buy alternate role")
		await tap("Offer2");await tap("Buy")
		check(c.s.parts.has(offer.id) and c.s.credits==credits-int(offer.price),"touch purchase grants exact offered part and debits price")
		var restored=Campaign.new();check(restored.restore() and canonical(restored.s)==canonical(c.s),"new offer purchase resumes from auto-save")
		var battle: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../qa_runtime/build_roles_20261103/climb_earned/combat_heavy_17_r4_n30101.json"))
		c=Campaign.new();check(c.restore_state(battle),"earned new-rule combat restores")
		await mount(c);hud_bounds();await tap("Parts")
		check(host.campaign_hud.node("DetailBody").text.contains("경직"),"equipped build detail includes control follow-up relationship")
		await capture("fire_build_%dx%d"%[extent.x,extent.y]);await tap("CloseDetail")
		host.campaign_hud.select_budget(1)
		var oracle=Model.new();oracle.s=c.model.s.duplicate(true);oracle.fire()
		host.campaign_hud.hud.feedback.save_setting("motion","fast")
		await tap("Fire")
		check(canonical(c.model.s)==canonical(oracle.s),"live new-rule shot matches model")
		check(restored.restore() and canonical(restored.model.s)==canonical(c.model.s),"live new-rule shot auto-saves exactly")
		await capture("fire_shot_%dx%d"%[extent.x,extent.y])
	host.free();await settle()
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("BUILD ROLES COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
