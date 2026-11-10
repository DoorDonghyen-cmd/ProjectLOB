extends "res://tests/navigation_ui_runner.gd"
var samples: Dictionary={}
func top() -> Control:
	for i in range(screen.get_child_count()-1,-1,-1):
		var item=screen.get_child(i)
		if item.has_meta("lob_modal") and item.visible:return item
	return null
func key_escape() -> void:
	var event:=InputEventAction.new();event.action="ui_cancel";event.pressed=true
	Input.parse_input_event(event);await process_frame
	event=InputEventAction.new();event.action="ui_cancel";event.pressed=false
	Input.parse_input_event(event);await settle()
func record(id: String) -> void:
	await settle()
	var dialog:=top()
	check(dialog!=null,"modal visible "+id)
	if dialog==null:return
	var controls: Dictionary={}
	for item in dialog.find_children("*","Control",true,false):
		if not item.is_visible_in_tree() or str(item.name)=="MaterialEdge":continue
		var box: Rect2=item.get_global_rect()
		var data: Dictionary={"rect":[box.position.x,box.position.y,box.size.x,box.size.y],"mouse_filter":item.mouse_filter,"focus":item.focus_mode}
		if item is Label or item is Button or item is LineEdit:
			data.text=item.text;data.font_size=item.get_theme_font_size("font_size")
		controls[str(dialog.get_path_to(item))]=data
	samples[id]=controls
	await capture(id)
func run() -> void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/equipment_dialog_20261106/"):quit(2);return
	screen=load("res://redesign/main.tscn").instantiate();screen.save_enabled=false
	root.add_child(screen);await settle()
	for extent in [Vector2i(1280,800),Vector2i(1170,540)]:
		root.size=extent;await settle();screen._open_preparation(false);await settle()
		var suffix:="_%dx%d"%[extent.x,extent.y]
		await touch("weapon_info");await record("weapon"+suffix)
		await key_escape();check(top()==null,"Escape closes equipment detail")
		await touch("starting_deck");await record("deck"+suffix);await touch("DialogClose")
		await touch("preparation_options");await record("options"+suffix)
		var seed: String=screen.preparation_seed
		screen.seed_input.text="817263";screen.seed_input.text_changed.emit("817263")
		check(screen.preparation_seed=="817263","seed field retains real binding")
		await touch("DialogClose");check(top()==null,"close returns from options")
		# The shared system-settings entry can also be invoked while preparing.
		screen._settings();await record("settings"+suffix)
		# Settings are choice buttons since 2026-11-08 (common window); 글자 크기 is fixed at 100%.
		await touch("EffectsVolumeSetting_1");await settle()
		check(is_equal_approx(float(screen.preferences.data.effects_volume),0.25),"volume selection callback persists real preference")
		await touch("ContextHintsSetting_1");await settle()
		check(not bool(screen.preferences.data.hints),"public toggle updates hint preference")
		if top()!=null:await touch("DialogClose")
		screen._settings();await record("settings_off"+suffix)
		await touch("settings_reset");await settle()
		check(bool(screen.preferences.data.hints) and is_equal_approx(float(screen.preferences.data.effects_volume),0.5),"reset restores actual preferences")
		if top()!=null:await touch("DialogClose")
		var saved=Campaign.new();saved.start("burst",9182,0,"balanced",screen.CampaignContent.RouteMap.VERSION,"work",true)
		check(saved.save()==OK,"isolated existing campaign saved")
		var bytes:=FileAccess.get_file_as_bytes(Campaign.SAVE)
		screen._open_preparation(false);await settle()
		await touch("start_"+screen.selected_weapon_id);await record("confirm"+suffix)
		await touch("DialogCancel")
		check(bytes==FileAccess.get_file_as_bytes(Campaign.SAVE),"cancel keeps existing save bytes")
		screen.preparation_seed=seed
		screen._to_menu();await settle();screen._settings();await record("outside_equipment"+suffix)
		check(top().scene_file_path=="res://redesign/common/window.tscn","other-page modal uses the common window (2026-11-08)")
		await touch("DialogClose")
	if OS.get_environment("QA_DIALOG_AUTHORED")=="1":
		var authored=load("res://redesign/equipment/dialog.tscn").instantiate()
		authored.set_script(null);root.add_child(authored);await settle()
		check(authored.find_child("Preview",true,false).is_visible_in_tree(),"equipment shell has visible authored representative content")
		check(not authored.find_child("DialogActions",true,false).visible,"detail shell does not show unrelated confirmation actions before binding")
		await capture("authored_shell");authored.free();await settle()
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"screens":samples},"  "))
	screen.free();await settle()
	print("EQUIPMENT DIALOG COMPLETE checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
