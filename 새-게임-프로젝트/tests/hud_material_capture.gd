extends "res://tests/campaign_magazine_ui.gd"
## Same earned production checkpoint and public inputs for material comparisons.
var records: Dictionary={}

func record(label: String) -> void:
	await settle()
	var geometry: Dictionary={}
	for item in host.campaign_hud.find_children("*","Control",true,false):
		if not item.is_visible_in_tree():continue
		var rect: Rect2=item.get_global_rect()
		geometry[str(host.campaign_hud.get_path_to(item))]={"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"minimum":[item.custom_minimum_size.x,item.custom_minimum_size.y],"mouse_filter":item.mouse_filter}
	records[label]={"geometry":geometry,"state":canonical({"campaign":host.campaign.s,"combat":host.model.s,"profile":host.campaign.profile})}
	await capture(label)

func run() -> void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/hud_material_20261106/"):quit(2);return
	if OS.get_environment("QA_HUD_AUTHORED_ONLY")=="1":
		root.size=Vector2i(1280,800)
		for name in ["combat_hud","combat_menu","combat_detail"]:
			var authored=load("res://redesign/samples/hud/"+name+".tscn").instantiate()
			authored.set_script(null);root.add_child(authored);await settle()
			check(authored.is_visible_in_tree() and authored.size.x>=700,"authored scene visible without gameplay controller: "+name)
			await capture(name)
			authored.free();await settle()
		print("HUD MATERIAL CAPTURE COMPLETE checks=%d failures=%d"%[checks,failures.size()])
		quit(0 if failures.is_empty() else 1);return
	Input.emulate_mouse_from_touch=true
	var checkpoint:=ProjectSettings.globalize_path("res://../qa_runtime/boss_skills_20261106/heavy_elite/combat_heavy_17_r1_n101.json")
	for extent in [Vector2i(1280,800),Vector2i(1170,540),Vector2i(740,360)]:
		root.size=extent
		var c=Campaign.new()
		if not check(c.restore(checkpoint),"earned current campaign restores"):quit(1);return
		await mount(c);host.save_enabled=false
		var ui=host.campaign_hud
		ui.hud.feedback.preferences.data.motion="instant"
		ui.hud.feedback.configure()
		ui.refresh();await settle();hud_bounds()
		var suffix:="_%dx%d"%[extent.x,extent.y]
		await record("ready"+suffix)
		await tap("Select1");await record("selected"+suffix)
		await tap("SelectedDetail");await record("detail"+suffix)
		await tap("CloseDetail");await tap("CancelSelection")
		await tap("Menu");await record("menu"+suffix);await tap("MenuClose")
		var oracle=Model.new();oracle.s=c.model.s.duplicate(true)
		check(oracle.fire(),"oracle accepts public shot")
		await tap("Fire")
		check(canonical(c.model.s)==canonical(oracle.s),"public fire equals complete model/RNG oracle")
		await record("fired"+suffix)
		check(oracle.reload_magazine(),"oracle accepts replacement")
		await tap("Reload")
		check(canonical(c.model.s)==canonical(oracle.s),"public replacement equals complete model/RNG oracle")
		await record("reloaded"+suffix)
		host.free();host=null;await settle()
	FileAccess.open(output.path_join("comparison.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"  "))
	print("HUD MATERIAL CAPTURE COMPLETE checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
