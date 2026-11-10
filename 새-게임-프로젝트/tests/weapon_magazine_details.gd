extends "res://tests/weapon_magazine_ui.gd"

func run() -> void:
	out=OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/weapon_magazine_20261031/"): quit(2); return
	Input.emulate_mouse_from_touch=true
	preview=load("res://redesign/samples/combat_weapon_magazine.tscn").instantiate()
	preview.resume_saved=false; root.add_child(preview); await settle()
	for size in [Vector2i(1008,630),Vector2i(1280,576),Vector2i(1280,800)]:
		root.size=size; root.content_scale_size=Vector2i(1280,800)
		for gun_index in range(5):
			preview.gun_index=gun_index; preview.case_index=1; preview.mount(false); await settle()
			weapon_layout(); await capture("ready_%s_%dx%d" % [preview.model.s.gun,size.x,size.y])
			await tap("Parts")
			var body: Label=preview.node("DetailBody")
			var scroll: ScrollContainer=preview.node("DetailScroll")
			var part: String=preview.Content.equipped_parts(preview.model.s)[0]
			check(body.text.contains(str(preview.Content.part_spec(part,preview.model.s).text)),"Part description follows current combat version")
			check(scroll.get_global_rect().end.y < preview.node("CloseDetail").get_global_rect().position.y,"Scrolling body never overlaps close action")
			check(body.size.x <= scroll.size.x,"Description stays within horizontal bounds")
			check(scroll.get_v_scroll_bar().max_value >= body.size.y,"Full long description is reachable")
			await capture("parts_%s_%dx%d" % [preview.model.s.gun,size.x,size.y])
			await tap("DetailDown")
			if body.size.y>scroll.size.y: check(scroll.scroll_vertical>0,"Long description is reachable by large touch button")
			await tap("DetailUp");check(scroll.scroll_vertical==0,"Touch button returns to description start")
			await tap("CloseDetail"); check(not preview.overlay_open,"Modal closes")
			await tap("Help");check(scroll.scroll_vertical==0,"New detail starts at top");await capture("help_%s_%dx%d" % [preview.model.s.gun,size.x,size.y]);await tap("CloseDetail")
	check(preview.chance_text(0.004)=="<1%" and preview.chance_text(0.996)==">99%","Nonzero/uncertain chance never rounds to certainty")
	FileAccess.open(out.path_join("details.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("WEAPON DETAILS COMPLETE checks=%d failures=%d" % [checks,failures.size()]);preview.queue_free();await settle();quit(0 if failures.is_empty() else 1)
