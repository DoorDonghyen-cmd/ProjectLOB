extends "res://tests/shop_live_runner.gd"

func press(key: String) -> void:
	var control: Button=screen.find_child(key,true,false)
	check(control!=null,"control exists "+key)
	if control==null:return
	control.grab_focus()
	var parent=control.get_parent()
	while parent!=null:
		if parent is ScrollContainer:parent.ensure_control_visible(control)
		parent=parent.get_parent()
	await settle()
	check(not control.disabled and control.is_visible_in_tree(),"control available "+key)
	check(screen.get_viewport_rect().encloses(control.get_global_rect()),"control on screen "+key)
	for down in [true,false]:
		var event:=InputEventScreenTouch.new();event.index=0;event.position=control.get_global_rect().get_center();event.pressed=down
		root.push_input(event,true);await process_frame
	await settle()

func enter_workshop() -> void:
	var c=Campaign.new();c.start("heavy",731042,0,"balanced",3,"carrier")
	c.s.departure_step=3
	var nodes:Array=c.current_nodes()
	var target:Dictionary=nodes.filter(func(n):return n.get("workshop",false))[0]
	var parent:Dictionary=nodes.filter(func(n):return n.next.has(target.id))[0]
	c.s.node=parent.id;c.s.floor=parent.floor;c.s.visited=[parent.id]
	while int(parent.floor)>1:
		parent=nodes.filter(func(n):return n.next.has(parent.id))[0];c.s.visited.push_front(parent.id)
	c.model.s.deck.append("bore")
	screen.campaign=c;screen.model=c.model;screen.page="run";screen.debug_session=false
	screen._campaign_action("enter",target.id);await settle()
	check(c.s.phase=="supply" and c.node().workshop,"production workshop entry")

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/playtest_revision_20261026/"):quit(2);return
	output=OS.get_environment("QA_OUTPUT_DIR")
	Input.emulate_mouse_from_touch=true;Input.emulate_touch_from_mouse=true
	screen=load("res://redesign/main.tscn").instantiate();screen.save_enabled=true
	root.add_child(screen);await settle()
	for resolution in [Vector2i(1008,630),Vector2i(1280,576),Vector2i(1280,800)]:
		root.size=resolution;root.content_scale_size=resolution
		screen.selected_outfit_id="scout";screen._open_preparation(false);await settle()
		check(screen.find_child("OutfitSummary",true,false).text.contains("휴대 28장"),"scout carry cap shown")
		await press("outfit_select_expedition")
		check(screen.find_child("OutfitSummary",true,false).text.contains("휴대 40장"),"expedition carry cap shown")
		var outfit_stats=screen.find_child("outfit_select_expedition",true,false).get_node("Content/Copy/Stats")
		check(outfit_stats.is_visible_in_tree() and outfit_stats.text.contains("휴대 40") and outfit_stats.text.contains("교환 0"),"visible outfit row retains exchange count")
		check(not screen.main_scroll.get_h_scroll_bar().visible,"equipment no horizontal overflow")
		await capture("equipment_%dx%d"%[resolution.x,resolution.y])
		await enter_shop()
		screen.model.s.deck=["bore","cool","precise_c","pierce_c","charge","arc","push","shatter","bypass","chase","detonate","spread","vent","charge_heat","charge_hot","pierce_p3"]
		while screen.model.s.deck.size()<32:screen.model.s.deck.append("bore")
		screen.campaign.s.offers=[{"type":"ammo","id":"precise_p2","price":12,"sold":false}]
		screen.redraw();await settle()
		check(shop().field("Buy").disabled,"full bag add disabled")
		await tap("Replace")
		check(shop().field("Overlay").visible,"production replacement overlay")
		check(shop().bag_ids.size()==16,"all owned profiles offered")
		check(shop().field("NextPage").visible,"long inventory has more pages")
		await capture("replacement_%dx%d"%[resolution.x,resolution.y])
		await tap("CloseOverlay")
		check(screen.campaign.s.credits==75 and not screen.campaign.s.offers[0].sold,"cancel changes no ownership or credits")
		await tap("Replace")
		for i in 3:await tap("NextPage")
		check(shop().bag_page==3 and shop().field("NextPage").text.contains("4/4"),"last replacement page reachable")
		await capture("replacement_last_%dx%d"%[resolution.x,resolution.y])
		await tap("AmmoRow3")
		check(screen.model.s.deck.size()==32 and not screen.model.s.deck.has("pierce_p3") and screen.model.s.deck.has("precise_p2"),"touch replaces last scroll row")
		check(screen.campaign.s.credits==63 and screen.campaign.s.offers[0].sold,"purchase charges once")
		var restored=Campaign.new()
		check(restored.restore() and restored.model.s.deck==screen.model.s.deck and restored.s.inventory_version==1,"purchase autosave exact")
		screen._ammo_bag();await settle()
		check(screen.find_child("StateHint",true,false).text.contains("휴대 32/32장") and screen.find_child("StateHint",true,false).text.contains("비상 기본탄"),"bag separates capacity and emergency supply")
		await capture("bag_%dx%d"%[resolution.x,resolution.y]);await press("workspace_close")
		await enter_workshop()
		await capture("workshop_%dx%d"%[resolution.x,resolution.y])
		await press("city_workshop_refit")
		var candidate:String=screen.campaign.workshop_ammo_options()[0]
		await press("city_refit_"+candidate)
		check(not screen.find_child("ammo_acquire_add",true,false).is_visible_in_tree(),"workshop has no add option")
		var layout=screen.find_child("AcquisitionLayout",true,false)
		check(layout.get_node("%ReplaceScroll").get_v_scroll_bar().max_value>layout.get_node("%ReplaceScroll").get_v_scroll_bar().page,"workshop replacement list scrolls")
		await capture("workshop_exchange_%dx%d"%[resolution.x,resolution.y])
		await press("DialogClose")
		check(not screen.campaign.s.resolved,"cancel preserves workshop action")
		await press("city_refit_"+candidate);await press("ammo_replace_bore" if candidate!="bore" else "ammo_replace_basic_p1")
		check(screen.campaign.s.resolved and screen.model.s.deck.size()==21 and screen.model.s.deck.has(candidate),"workshop touch exchange resolves one work")
		check(restored.restore() and restored.model.s.deck==screen.model.s.deck and restored.s.resolved,"workshop autosave exact")
		await press("city_leave")
		check(screen.campaign.s.phase=="map","workshop returns to map")
	print("PLAYTEST REVISION INVENTORY UI COMPLETE checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
