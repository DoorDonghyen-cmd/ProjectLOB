extends "res://tests/weapon_magazine_ui.gd"

func ejection_layout() -> void:
	weapon_layout()
	for id in ["EjectToggle","EjectApply"]:
		var button: Button=preview.node(id)
		if not button.visible:continue
		check(preview.get_global_rect().encloses(button.get_global_rect()),"Ejection action stays in viewport")
		check(button.size.y*float(root.size.y)/800.0>=44,"Ejection touch target at smallest aspect")
		var width:=button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x
		check(width+24<=button.size.x,"Ejection action text fits")
	check(not preview.node("EjectToggle").get_global_rect().intersects(preview.node("RoundRow").get_global_rect()),"Entry button does not cover cards")
	check(not preview.node("EjectToggle").get_global_rect().intersects(preview.node("SequenceHint").get_global_rect()),"Quota and direction labels separate")
	for i in range(preview.model.s.magazine.size()):
		if not preview.eject_mode:continue
		check(preview.node("Select%d"%i).get_global_rect()==preview.node("Round%d"%i).get_global_rect(),"Whole card is selectable")

func run() -> void:
	out=OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/magazine_ejection_20261031/"):quit(2);return
	Input.emulate_mouse_from_touch=true
	preview=load("res://redesign/samples/combat_weapon_magazine.tscn").instantiate();preview.resume_saved=false;root.add_child(preview);await settle()
	for size in [Vector2i(1008,630),Vector2i(1280,576),Vector2i(1280,800)]:
		root.size=size;root.content_scale_size=Vector2i(1280,800)
		for gun_index in range(5):
			preview.gun_index=gun_index;preview.case_index=1;preview.mount(false);await settle()
			var gun: String=preview.model.s.gun
			var suffix: String="%s_%dx%d"%[gun,size.x,size.y]
			var original:=JSON.stringify(preview.model.s)
			await tap("EjectToggle");check(preview.eject_mode and preview.node("EjectApply").disabled,"Entry waits for an explicit selection")
			await tap("Select1");check(preview.eject_selected==[1],"Middle card selects by touch")
			check(JSON.stringify(preview.model.s)==original,"Preview does not spend ammo or RNG")
			var predicted: Dictionary=preview.eject_preview.duplicate(true)
			check(preview.last_prediction==preview.Forecast.analyze(predicted,true),"Display forecasts the selected surviving magazine")
			ejection_layout();await capture("selected_"+suffix)
			await preview.fire();await preview.cool();await preview.reload_magazine()
			check(JSON.stringify(preview.model.s)==original,"Planning mode blocks competing combat actions")
			await tap("EjectToggle");check(not preview.eject_mode and JSON.stringify(preview.model.s)==original,"Cancel preserves exact live state")
			await tap("EjectToggle");await tap("Select1");await tap("Select3")
			check(preview.node("Select0").disabled and not preview.node("Select1").disabled,"Two selections cap new picks but permit deselection")
			await tap("Select3");check(preview.eject_selected==[1],"Selected card toggles off")
			var before: Dictionary=preview.model.s.duplicate(true)
			await tap("EjectApply")
			check(not preview.eject_mode and preview.model.ejection_remaining()==1,"Confirm spends one removal")
			check(preview.model.s.magazine==before.magazine.slice(0,1)+before.magazine.slice(2),"Middle removal shifts only the suffix")
			check(preview.model.s.turns==before.turns and preview.model.s.heat==before.heat and preview.model.s.enemies==before.enemies,"Confirm does not cool or move enemies")
			ejection_layout();await capture("removed_"+suffix)
			await tap("Fire");check(preview.model.ejection_remaining()==1,"Real shot keeps used quota")
			check(not preview.busy,"Input unlocks after real shot animation")
			if preview.model.s.phase=="ready" and not preview.model.s.magazine.is_empty():
				await tap("EjectToggle");await tap("Select0");await tap("EjectApply")
				check(preview.model.ejection_remaining()==0 and preview.node("EjectToggle").disabled,"Second removal is the per-magazine limit")
				if not preview.node("Cool").disabled:
					await tap("Cool");check(preview.model.ejection_remaining()==0,"Cooling cannot recover quota")
				if not preview.node("Reload").disabled:
					await tap("Reload")
					if preview.model.s.phase=="ready":check(preview.model.ejection_remaining()==2,"Paid replacement restores quota")
	# Resume the exact one-used removal state, including hidden targeting stream.
	preview.gun_index=2;preview.case_index=1;preview.mount(false);await tap("EjectToggle");await tap("Select2");await tap("EjectApply")
	var saved: Dictionary=JSON.parse_string(JSON.stringify(preview.model.s))
	preview.queue_free();await settle();preview=load("res://redesign/samples/combat_weapon_magazine.tscn").instantiate();root.add_child(preview);await settle()
	check(preview.resumed and not preview.eject_mode and preview.model.ejection_remaining()==1 and JSON.parse_string(JSON.stringify(preview.model.s))==saved,"Resume preserves spent card, quota and RNG")
	await capture("resumed_scatter")
	await tap("EjectToggle");await tap("Select0");await tap("Help")
	check(preview.node("DetailBody").text.contains("탄창당2발"),"Rules explain removal limit")
	var unchanged:=JSON.stringify(preview.model.s);preview.apply_ejection();check(JSON.stringify(preview.model.s)==unchanged,"Help modal blocks spending selected ammo")
	await tap("CloseDetail");await tap("EjectToggle")
	# Victory scenario: controlled ordering of owned cards, same real enemy state.
	preview.gun_index=0;preview.case_index=0;preview.mount(false)
	var pool: Array=preview.model.s.magazine+preview.model.s.draw
	var chosen: Array=["charge","basic_p1","pierce_p2","basic_p2"]
	for id in chosen:pool.erase(id)
	preview.model.s.magazine=chosen;preview.model.s.draw=pool;preview.refresh();await settle()
	await tap("EjectToggle");await tap("Select1");ejection_layout()
	check(preview.node("Value0").text=="+3" and preview.node("Gain0").text=="지원 효과","Boost preview shows its effect instead of zero cooling")
	check(preview.node("Value2").text=="10","Surviving piercing round displays boosted actual damage")
	await capture("owned_combo_preview")
	await tap("EjectApply");await tap("Fire")
	check(preview.model.s.history.back().detail.results[1].id=="pierce_p2","Public removal delivers boost into piercing shot")
	var route: Array=JSON.parse_string(FileAccess.get_file_as_string(out.get_base_dir().path_join("rules/rules.json"))).examples[0].winning_path
	check(not route.is_empty() and route[0]=="fire","Verified continuation exists after selecting middle round")
	for action in route.slice(1):await tap({"fire":"Fire","cool":"Cool","swap":"Reload","emergency":"Reload"}[action])
	check(preview.model.s.phase in ["won","reward"],"Removal then continued real actions finish the owned-order fight")
	check(preview.node("EjectToggle").disabled,"No ejection after victory");await capture("owned_combo_victory")
	FileAccess.open(out.path_join("ui.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"action_animation_ms":action_times},"  "))
	print("EJECTION UI COMPLETE checks=%d failures=%d"%[checks,failures.size()]);preview.queue_free();await settle();quit(0 if failures.is_empty() else 1)
