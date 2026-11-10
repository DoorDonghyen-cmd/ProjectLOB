extends "res://tests/gate_ui_runner.gd"
const Data = preload("res://redesign/campaign_content.gd")

func earned(node: int):
	var c=Campaign.new()
	check(c.restore(ProjectSettings.globalize_path("res://../qa_runtime/combat_rhythm_20261030/matrix_final/combat_single_731042_v12_carrier_n%d.json" % node)),"earned rhythm checkpoint restores")
	return c

func finish_action() -> void:
	var deadline := Time.get_ticks_msec()+15000
	while screen.busy and Time.get_ticks_msec()<deadline: await process_frame
	check(not screen.busy,"presentation completes")
	await settle()

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/combat_rhythm_20261030/"):quit(2);return
	out=OS.get_environment("QA_OUTPUT_DIR")
	Input.emulate_mouse_from_touch=true;Input.emulate_touch_from_mouse=true
	screen=load("res://redesign/main.tscn").instantiate();screen.save_enabled=true;root.add_child(screen);await settle()
	for size in [Vector2i(1008,630),Vector2i(1280,576),Vector2i(1280,800)]:
		# Keep the shipped 1280x800 canvas; changing it to window pixels bypasses
		# the game's actual stretch and creates artificial clipping at 1008px.
		root.size=size;root.content_scale_size=Vector2i(1280,800)
		await mount(earned(401))
		check(screen.model.s.enemies[0].name=="교대 방패병" and screen.model.s.enemies[0].def==6,"closed guard has correct name and armor")
		check(screen.battle_view.enemies[0].def==6,"closed guard visual state")
		screen.city_ui.ui=screen;screen.city_ui.campaign=screen.campaign;screen.city_ui.inspect_node(401);await settle()
		var count=screen.find_child("FormationCount",true,false)
		check(count!=null and count.text.contains("총 2") and count.text.contains("증원 0"),"map preview shows actual compact formation")
		check(screen.find_children("*","Label",true,false).any(func(n):return n.text.contains("장갑 6과 0")),"map preview explains alternating defense")
		await snap("brief_"+str(size.x)+"x"+str(size.y))
		await tap("workspace_close")
		await snap("guard_closed_"+str(size.x)+"x"+str(size.y))
		await tap("reload");await finish_action()
		check(screen.model.s.enemies[0].def==0 and not screen.model.s.enemies[0].stance_closed,"one-turn reload exposes guard")
		check(screen.battle_view.enemies[0].def==0,"open guard visual state matches simulation")
		var restored=Campaign.new();check(restored.restore(Campaign.SAVE) and restored.model.s.enemies[0].def==0,"automatic save resumes open guard")
		await snap("guard_open_"+str(size.x)+"x"+str(size.y))
		await mount(earned(201))
		check(screen.battle_view.enemies.size()==4 and screen.model.s.reinforcements.is_empty(),"sweep has all four enemies on board")
		for i in screen.battle_view._alive_indices():
			check(Rect2(Vector2.ZERO,screen.battle_view.size).encloses(screen.battle_view.enemy_plaque(i)),"enemy status stays on board")
		await snap("sweep_"+str(size.x)+"x"+str(size.y))
	FileAccess.open(out.path_join("ui.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("COMBAT RHYTHM UI COMPLETE checks=%d failures=%d" % [checks,failures.size()])
	screen.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
