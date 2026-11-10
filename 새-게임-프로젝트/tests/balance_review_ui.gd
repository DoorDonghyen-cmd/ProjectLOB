extends "res://tests/campaign_magazine_ui.gd"

func run()->void:
	output=OS.get_environment("QA_OUTPUT_DIR");Input.emulate_mouse_from_touch=true
	if not output.replace("\\","/").contains("/qa_runtime/balance_review_20261106/"):quit(2);return
	var folder: String=ProjectSettings.globalize_path("res://../qa_runtime/balance_review_20261106/after_heavy17")
	var files: PackedStringArray=DirAccess.get_files_at(folder);files.sort()
	var source: Dictionary={}
	for file in files:
		if not file.begins_with("combat_") or not file.ends_with(".json"):continue
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(file)))
		if data.combat.get("balance_version",0)==1 and data.combat.equipped_parts.has("inferno") and data.combat.magazine.has("bore"):
			source=data;break
	if not check(not source.is_empty(),"actual newly earned specialist snapshot exists"):quit(1);return
	for extent in [Vector2i(1280,800),Vector2i(1008,454),Vector2i(2340,1080)]:
		root.size=extent;root.content_scale_factor=1;root.content_scale_size=Vector2i.ZERO
		var c=Campaign.new();check(c.restore_state(source),"earned current balance snapshot restores")
		await mount(c);hud_bounds()
		var untouched: Dictionary=canonical(c.model.s)
		await capture("current_%dx%d"%[extent.x,extent.y])
		await tap("Parts")
		check(host.campaign_hud.node("DetailBody").text.contains("3적 행동") and host.campaign_hud.node("DetailBody").text.contains("3회당"),"public build detail uses current fire duration and inherited growth")
		await capture("rules_%dx%d"%[extent.x,extent.y])
		await tap("CloseDetail")
		check(canonical(c.model.s)==untouched,"build inspection leaves state and RNG unchanged")
		var oracle=Model.new();oracle.s=c.model.s.duplicate(true)
		check(oracle.fire(),"earned balance model accepts fire")
		await tap("Fire")
		check(canonical(c.model.s)==canonical(oracle.s),"public firing matches the current balance resolver")
		var restored=Campaign.new();check(restored.restore() and canonical(restored.model.s)==canonical(c.model.s),"public firing autosaves the exact current profile")
		await capture("fired_%dx%d"%[extent.x,extent.y])
	if is_instance_valid(host):host.free()
	FileAccess.open(output.path_join("ui.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("BALANCE REVIEW COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
