extends SceneTree
var screen
var output: String
var rows: Array=[]
func _initialize() -> void:run.call_deferred()
func settle() -> void:
	for frame in range(14):await process_frame
func run() -> void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/equipment_information_20261106/"):quit(2);return
	screen=load("res://redesign/main.tscn").instantiate();screen.save_enabled=false
	root.add_child(screen);await settle()
	for extent in [Vector2i(1280,800),Vector2i(1170,540),Vector2i(2340,1080),Vector2i(2340,960),Vector2i(1008,454),Vector2i(844,390)]:
		root.size=extent;await settle()
		for gun in ["single","heavy","amplifier"]:
			screen.selected_weapon_id=gun;screen.selected_outfit_id="carrier"
			screen._open_preparation(false);await settle()
			var view: Control=screen.find_child("EquipmentScreen",true,false)
			var scroll: ScrollContainer=view.find_child("SelectionScroll",true,false)
			scroll.scroll_vertical=0;await settle()
			var geometry: Dictionary={}
			for id in ["Header","Stage","SelectedWeaponPanel","PortraitArea","OutfitPortrait","OutfitSelection","OutfitScroll","SelectionScroll","WeaponSelection","weapon_info","starting_deck","loadout_back","preparation_options",str(view.launch.name)]:
				var control: Control=view.find_child(id,true,false)
				geometry[id]=str(control.get_global_rect())
			geometry.actor_rect=str(view.find_child("OutfitPortrait",true,false).display_rect())
			for button in view.find_children("*","Button",true,false):
				if str(button.name).begins_with("weapon_select_") or str(button.name).begins_with("outfit_select_"):
					geometry[str(button.name)]=str(button.get_global_rect())
			rows.append({"extent":str(extent),"gun":gun,"geometry":geometry,"body_scroll":scroll.get_v_scroll_bar().max_value-scroll.get_v_scroll_bar().page})
			root.get_texture().get_image().save_png(output.path_join("%s_%dx%d.png"%[gun,extent.x,extent.y]))
	root.size=Vector2i(1170,540);await settle()
	screen.selected_weapon_id="single";screen.selected_outfit_id="expedition"
	screen._open_preparation(false);await settle()
	screen.find_child("EquipmentScreen",true,false)._deck_details();await settle()
	root.get_texture().get_image().save_png(output.path_join("capacity_detail_1170x540.png"))
	FileAccess.open(output.path_join("geometry.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	screen.free();await settle()
	print("EQUIPMENT INFORMATION CAPTURE COMPLETE states=",rows.size());quit()
