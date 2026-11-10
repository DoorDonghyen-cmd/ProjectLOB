extends "res://tests/combat_ui_stage1_ui.gd"

func run() -> void:
	out=OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/combat_ui_capacity_20261031/"):quit(2);return
	Input.emulate_mouse_from_touch=true
	preview=load("res://redesign/samples/combat_ui_capacity.tscn").instantiate()
	root.add_child(preview);await settle()
	for size in [Vector2i(1008,630),Vector2i(1280,576),Vector2i(1280,800)]:
		root.size=size;root.content_scale_size=Vector2i(1280,800);await settle()
		preview.study_capacity=6;preview.mount(false);await settle();geometry()
		check(preview.model.capacity()==6 and preview.model.s.plan.size()==6,"Six actual rounds fit the candidate")
		for i in range(6):
			var card: Control=preview.node("Round%d" % i)
			check(preview.get_global_rect().encloses(card.get_global_rect()),"Round fits "+str(i))
			if i>0:check(not card.get_global_rect().intersects(preview.node("Round%d" % (i-1)).get_global_rect()),"Rounds do not overlap")
		check(preview.node("Role3").text=="미발사","No invented damage after battle ends")
		var suffix:="%dx%d" % [size.x,size.y]
		await capture("six_ready_"+suffix)
		await tap("Other");check(preview.study_capacity==3 and preview.model.s.plan.size()==3,"Touch compares original capacity")
		await tap("Other");check(preview.study_capacity==6,"Touch restores six-slot comparison")
		await tap("Pressure");check(preview.pressure,"Touch opens earned boss case")
		check(preview.node("Role4").text=="미발사" and preview.node("Gain4").text=="과열 중단","Unfired rounds explain overheat")
		await capture("six_boss_"+suffix)
		await tap("Fire")
		check(preview.fired_detail.results.size()==4 and preview.model.s.discard.size()==6,"Four fired and two discarded on forced reload")
		check(preview.node("IntentTitle").text.contains("과열"),"Forced reload outcome visible")
		check(preview.board.salvo_receipt.is_empty(),"No duplicate receipt over the boss header")
		await capture("six_overheat_"+suffix)
		await tap("Reset");check(not preview.pressure and preview.study_capacity==6,"Reset keeps selected capacity")
		await tap("Bag");check(preview.overlay_open,"Ammo detail remains available")
		await tap("CloseDetail");check(not preview.overlay_open,"Detail closes")
	preview.queue_free();await settle()
	FileAccess.open(out.path_join("ui.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("CAPACITY UI COMPLETE checks=%d failures=%d" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
