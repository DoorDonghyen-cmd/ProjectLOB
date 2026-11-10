extends "res://tests/playtest_presentation_ui.gd"
func run()->void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/playtest_20261102/"):quit(2);return
	output=OS.get_environment("QA_OUTPUT_DIR")
	for factor in [1.0,1.25]:
		root.content_scale_factor=factor
		var original: Array=scale_state().slice(0,3)
		for start in [Vector2i(740,360),Vector2i(844,390),Vector2i(2016,908)]:
			root.size=start;await settle()
			await mount("carrier","single")
			for size in [Vector2i(844,390),Vector2i(2016,908),Vector2i(2400,1080),start]:
				root.size=size;await settle()
				var expected:=maxf(1.0,floorf(minf(float(size.x)/1008,float(size.y)/454)))
				check(root.content_scale_factor==expected,"active HUD responds to window resize")
				check(host.campaign_hud.get_global_rect().encloses(host.campaign_hud.node("Actions").get_global_rect()),"actions remain inside resized HUD")
			host._to_menu();await settle()
			check(scale_state().slice(0,3)==original,"exit restores exact prior viewport settings after resize")
			records.append({"start":str(start),"prior":str(original),"after":str(scale_state())})
			if factor==1.0 and start.x==2016:await capture("menu_restored_2016x908")
			host.free();host=null
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"  "))
	print("PRESENTATION COMPLETE checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
