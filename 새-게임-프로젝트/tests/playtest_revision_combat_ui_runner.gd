extends "res://tests/playtest_revision_ui_runner.gd"
const RECIPES := {
	"volley":{"parts":["volley_drive","duplex","sequencer"],"order":["charge","precise_p3","cool"],"heat":0,"inspect":"duplex"},
	"siege":{"parts":["siege_drive","sequencer","afterburner"],"order":["charge","pierce_p3","cool"],"heat":0,"inspect":"afterburner"},
	"thermal":{"parts":["thermal_drive","sequencer","reclaimer"],"order":["charge_heat","pierce_p3","cool"],"heat":7,"inspect":"thermal_drive"}
}

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/playtest_revision_20261026/"):quit(2);return
	screen=load("res://redesign/main.tscn").instantiate()
	screen.save_enabled=false;screen.presentation_speed=0.04
	root.add_child(screen);await settle()
	for resolution in [Vector2i(1008,630),Vector2i(1280,800)]:
		root.size=resolution;await settle()
		for build in RECIPES:
			var recipe: Dictionary=RECIPES[build]
			await setup_hand(recipe.order)
			screen.model.s.gun="burst";screen.campaign.s.gun="burst"
			screen.model.s.equipped_parts=recipe.parts.duplicate()
			screen.campaign.s.equipped_parts=recipe.parts.duplicate();screen.campaign.s.parts=recipe.parts.duplicate()
			screen.model.s.engine.levels[recipe.parts[0]]=8
			screen.model.s.heat=recipe.heat
			screen.model.s.enemies=[Data._enemy(["wall",140,5,1,30]),Data._enemy(["runner",30,0,2,34])]
			screen.model.s.encounter_total=2;screen.model.s.deployed=2
			screen.model.assign_opening_lanes()
			screen.redraw();await settle()
			for id in screen.Content.loading_order(recipe.order):await tap("load_"+str(id))
			var label: String=str(build)+"_"+str(resolution.x)
			check(not screen.main_scroll.get_h_scroll_bar().visible,"build UI fits "+label)
			var forecast: Dictionary=screen.combat_forecast.duplicate(true)
			check(not forecast.is_empty(),"build forecast visible "+label)
			await capture(label+"_loaded")
			await tap("confirm");await tap("fire")
			check(forecast.enemies==screen.model.s.enemies,"visible build prediction equals actual result "+label)
			check(screen.last_presentation.shown_enemies==screen.model.s.enemies,"animation ends on actual build result "+label)
			await capture(label+"_fired")
			screen._combat_part_details(str(recipe.inspect));await settle()
			var details=screen.find_child("CombatPartDetails",true,false)
			check(details!=null,"part detail opens "+label)
			if details!=null:
				var expected: String=str(screen.Content.part_spec(recipe.inspect,screen.model.s).text)
				check(details.find_children("*","Label",true,false).any(func(node):return node.text==expected),"part detail states revised rule "+label)
			await capture(label+"_detail")
			await tap("DialogClose")
	print("PLAYTEST REVISION COMBAT UI COMPLETE checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
