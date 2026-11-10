extends "res://tests/shop_live_runner.gd"

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/playtest_revision_20261026/"):quit(2);return
	output=OS.get_environment("QA_OUTPUT_DIR")
	Input.emulate_mouse_from_touch=true;Input.emulate_touch_from_mouse=true
	screen=load("res://redesign/main.tscn").instantiate();screen.save_enabled=true
	root.add_child(screen);await settle()
	for resolution in [Vector2i(1008,630),Vector2i(1280,800)]:
		root.size=resolution;root.content_scale_size=resolution
		for revision in [0,1]:
			await enter_shop()
			screen.campaign.s.combat_revision=revision;screen.model.s.combat_revision=revision
			screen.campaign.s.offers=[]
			for id in ["sequencer","duplex","afterburner"]:
				screen.campaign.s.offers.append({"id":id,"type":"part","price":30,"sold":false})
			screen.redraw();await settle()
			for index in 3:
				var id: String=screen.campaign.s.offers[index].id
				var spec: Dictionary=Data.part_spec(id,screen.model.s)
				var card=shop().field("Offer%d"%index)
				check(card.find_child("Stat").text==spec.value,"shop face follows revision "+id)
				await tap("Offer%d"%index)
				check(shop().field("Change").text.contains(spec.upside),"shop benefit follows revision "+id)
				await tap("Details")
				check(shop().field("RulesText").text==spec.text,"shop rules follow revision "+id)
				await tap("CloseOverlay")
			await capture("shop_builds_v%d_%d"%[revision,resolution.x])
			await tap("Buy")
			check(screen.campaign.s.credits==45 and screen.campaign.s.equipped_parts.has("afterburner"),"revised offer purchase applies")
			var restored=Campaign.new()
			check(restored.restore() and int(restored.model.s.combat_revision)==revision,"shop disk autosave preserves rule version")
	print("PLAYTEST REVISION SHOP UI COMPLETE checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
