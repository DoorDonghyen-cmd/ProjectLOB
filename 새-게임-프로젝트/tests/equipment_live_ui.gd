extends "res://tests/navigation_ui_runner.gd"
## Current magazine campaign, real input, fixed actions, native sizes and isolated saves.
const MagazineBuild = preload("res://redesign/magazine_build.gd")
var frames: Array = []

func equipment() -> Control:
	return screen.find_child("EquipmentScreen",true,false)

func key_action(action: String) -> void:
	for pressed in [true,false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame
	await settle()

func touch(key: String) -> void:
	var control := screen.find_child(key,true,false) as Control
	if control != null:
		var parent := control.get_parent()
		while parent != null:
			if parent is ScrollContainer:
				parent.ensure_control_visible(control)
				await settle()
			parent = parent.get_parent()
	check(control!=null and control.is_visible_in_tree(),"visible touch target "+key)
	if control==null:return
	# Feed viewport-local coordinates directly after both scroll containers settle.
	# Avoid screen/window conversions while replaying nested scrolling in this view.
	var point: Vector2=control.get_global_transform_with_canvas()*(control.size*0.5)
	for pressed in [true,false]:
		var event:=InputEventScreenTouch.new();event.index=0;event.position=point;event.pressed=pressed
		root.push_input(event,true);await process_frame
	await settle()

func layout_checks(label: String, rail_fits: bool) -> void:
	var view := equipment()
	var body: ScrollContainer = view.find_child("SelectionScroll",true,false)
	var footer: Control = view.launch.get_parent()
	var header: Control = view.find_child("Header",true,false)
	var safe: Rect2 = screen.ReadableUI.available(screen)
	check(safe.encloses(view.launch.get_global_rect()),label+" launch visible without page scroll")
	check(safe.encloses(header.get_global_rect()),label+" back/header in safe area")
	check(not body.is_ancestor_of(view.launch),label+" launch outside selection scroll")
	check(body.get_global_rect().end.y <= footer.get_global_rect().position.y,label+" body clipped above actions")
	check(screen.main_scroll.get_v_scroll_bar().max_value-screen.main_scroll.get_v_scroll_bar().page <= 1.0,label+" no whole-page vertical scroll")
	check(screen.main_scroll.get_h_scroll_bar().max_value-screen.main_scroll.get_h_scroll_bar().page <= 1.0,label+" no whole-page horizontal scroll")
	check(view.launch.size == Vector2(250,54),label+" launch retains native touch size")
	var portrait: Control = view.find_child("OutfitPortrait",true,false)
	check(is_equal_approx(portrait.preview_scale,0.85),label+" reduced actor uses same live preview")
	var selected: Button = view.find_child("weapon_select_" + screen.selected_weapon_id, true, false)
	var art: Control = selected.get_node("Art")
	var fit: Rect2 = art.art_rect()
	check(Rect2(Vector2.ZERO, art.size).grow(0.5).encloses(fit) and fit.size.x <= 150.01 and fit.size.y <= 40.01,label+" weapon thumbnail fits its shared bounds")
	check(is_equal_approx(fit.size.aspect(), art.texture.get_size().aspect()),label+" weapon thumbnail preserves source ratio")
	check(selected.button_pressed and selected.theme_type_variation==&"EquipmentSelected",label+" active weapon keeps its selected state")
	if rail_fits:
		var rail: ScrollContainer=view.find_child("WeaponScroll",true,false)
		check(body.get_global_rect().encloses(rail.get_global_rect()),label+" five-card rail viewport remains visible")
		check(rail.follow_focus and rail.get_child(0).get_child_count()==Content.GUNS.size(),label+" all gun choices share native horizontal navigation")
	var old_rect: Rect2 = view.launch.get_global_rect()
	body.scroll_vertical = 10000
	await settle()
	check(view.launch.get_global_rect()==old_rect,label+" body scrolling cannot move launch")
	check(body.get_global_rect().encloses(view.find_child("WeaponScroll",true,false).get_global_rect()),label+" rail viewport reachable above actions")
	frames.append({"label":label,"window":str(root.size),"scale":root.content_scale_factor,"launch":str(old_rect),"body_scroll_extent":body.get_v_scroll_bar().max_value-body.get_v_scroll_bar().page})
	for id in ["WeaponName","FireMode","Capacity","Heat","Reload","Cooling"]:
		var info: Label=view.find_child(id,true,false)
		var width:=info.get_theme_font("font").get_string_size(info.text,HORIZONTAL_ALIGNMENT_LEFT,-1,info.get_theme_font_size("font_size")).x
		check(width<=info.size.x+1,label+" information fits "+id)
	for outfit in Content.OUTFITS:
		var card: Button=view.find_child("outfit_select_"+outfit,true,false)
		var icon: TextureRect=card.get_node("Icon")
		check(icon.size==Vector2(64,52) and icon.texture.get_size()==Vector2(32,26),label+" uniform G portrait "+outfit)
		var copy: VBoxContainer=card.get_node("Copy")
		var name: Label=copy.get_node("Name")
		check(name.get_line_count() <= 2 and copy.get_combined_minimum_size().y <= copy.size.y + 0.5,label+" outfit name and carry stay inside card "+outfit)
		var info: Label=card.get_node("Copy/Stats")
		var width:=info.get_theme_font("font").get_string_size(info.text,HORIZONTAL_ALIGNMENT_LEFT,-1,info.get_theme_font_size("font_size")).x
		check(width<=info.size.x+1,label+" outfit limit fits "+outfit)

func last_number(text: String) -> int:
	var pattern:=RegEx.new();pattern.compile("[0-9]+")
	var values:=pattern.search_all(text)
	return int(values.back().get_string()) if not values.is_empty() else -1

func run() -> void:
	output = OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/equipment_live_20261106/"):
		quit(2)
		return
	if FileAccess.file_exists(Campaign.SAVE): DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.SAVE))
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	await settle()
	# Baseline entry path, not a directly instantiated replacement screen.
	await super.touch("new_run_setup")
	check(screen.page=="loadout","title enters authored equipment")
	for scale in ([] if OS.get_environment("QA_EQUIPMENT_LAUNCH_ONLY")=="1" else [0.9,1.0,1.1]):
		screen.preferences.data.text_scale=scale
		for extent in [Vector2i(1280,800),Vector2i(1170,540),Vector2i(2340,1080),Vector2i(2340,960),Vector2i(1008,454),Vector2i(844,390)]:
			root.size=extent
			await settle()
			screen._open_preparation(false)
			await settle()
			for gun in Content.GUNS:
				await touch("weapon_select_"+gun)
				check(screen.selected_weapon_id==gun,"touch selects "+gun)
				var view := equipment()
				var portrait: Control=view.find_child("OutfitPortrait",true,false)
				check(portrait.actor.gun_id==gun,"live held gun "+gun)
				await layout_checks("%s/%s/%s"%[extent,scale,gun],scale==1.0 and extent in [Vector2i(1280,800),Vector2i(1170,540),Vector2i(2340,1080)])
			if scale==1.0:
				await touch("weapon_select_single")
				await touch("outfit_select_carrier")
				var body: ScrollContainer=equipment().find_child("SelectionScroll",true,false)
				body.scroll_vertical=0
				await capture("equipment_%dx%d"%[extent.x,extent.y])
	# Resizing must preserve the actual selection/seed and chooses authored short variant.
	screen.preferences.data.text_scale=1.0
	root.size=Vector2i(1280,800)
	await settle()
	screen._open_preparation(false)
	await settle()
	await touch("weapon_select_heavy")
	await touch("outfit_select_expedition")
	screen.preparation_seed="817263"
	root.size=Vector2i(2340,1080)
	await settle()
	check(screen.selected_weapon_id=="heavy" and screen.selected_outfit_id=="expedition" and screen.preparation_seed=="817263","resize preserves complete selection")
	check(equipment().scene_file_path.ends_with("screen_short.tscn"),"mobile uses authored short layout")
	await capture("equipment_mobile_heavy")
	# Native keyboard action and real touch remain interchangeable.
	var first: Button=screen.find_child("weapon_select_single",true,false)
	first.grab_focus()
	await key_action("ui_accept")
	check(screen.selected_weapon_id=="single","keyboard activates gun")
	await key_action("ui_focus_next")
	check(root.gui_get_focus_owner()!=null and root.gui_get_focus_owner().is_visible_in_tree(),"keyboard retains visible focus")
	# All 35 legal pairs launch the real current campaign and persist correctly.
	for gun in Content.GUNS:
		for outfit in Content.OUTFITS:
			screen._open_preparation(false)
			await settle()
			await touch("weapon_select_"+gun)
			await touch("outfit_select_"+outfit)
			var view := equipment()
			var portrait: Control=view.find_child("OutfitPortrait",true,false)
			check(portrait.actor.gun_id==gun and portrait.actor.outfit_id==outfit,"live pair "+gun+"/"+outfit)
			var visible: Dictionary={}
			for id in ["Capacity","Heat","Reload","FireMode"]:visible[id]=last_number(view.find_child(id,true,false).text)
			visible.carry=last_number(view.find_child("outfit_select_"+outfit,true,false).get_node("Copy/Stats").text)
			await super.touch("start_"+gun)
			check(screen.page=="run" and screen.campaign.s.gun==gun and screen.campaign.s.outfit==outfit,"launch actual pair "+gun+"/"+outfit)
			check(visible.Capacity==screen.model.capacity(),"displayed capacity equals actual new campaign "+gun+"/"+outfit)
			check(visible.Heat==Content.heat_limit(screen.model.s),"displayed heat limit equals actual new campaign "+gun+"/"+outfit)
			check(visible.Reload==screen.model.reload_cost(),"displayed replacement cost equals actual new campaign "+gun+"/"+outfit)
			check(visible.carry==screen.model.deck_limit(),"outfit label equals actual new campaign carry limit "+gun+"/"+outfit)
			if gun!="amplifier":check(visible.FireMode==screen.model.MagazineTrial.pulse(screen.model.s),"displayed base cadence equals actual new campaign "+gun+"/"+outfit)
			var expected := Campaign.new()
			expected.start(gun,817263,screen.selected_difficulty,screen.selected_loadout_id,screen.CampaignContent.RouteMap.VERSION,outfit,true)
			expected.normalize_for_save()
			screen.campaign.normalize_for_save()
			check(expected.s==screen.campaign.s and expected.model.serialized_state()==screen.model.serialized_state(),"launch retains campaign/model/RNG rules "+gun+"/"+outfit)
			var path := "user://equipment_roundtrip.json"
			check(screen.campaign.save(path)==OK,"save pair "+gun+"/"+outfit)
			var restored := Campaign.new()
			var restored_ok: bool = restored.restore(path)
			var restored_campaign: bool = JSON.parse_string(JSON.stringify(restored.s))==JSON.parse_string(JSON.stringify(screen.campaign.s))
			var restored_profile: bool = JSON.parse_string(JSON.stringify(restored.profile))==JSON.parse_string(JSON.stringify(screen.campaign.profile))
			var restored_model: bool = JSON.parse_string(restored.model.serialized_state())==JSON.parse_string(screen.model.serialized_state())
			if not (restored_ok and restored_campaign and restored_profile and restored_model):
				print("RESTORE COMPONENTS ",gun,"/",outfit," ",[restored_ok,restored_campaign,restored_profile,restored_model])
				FileAccess.open(output.path_join("restore_difference.json"),FileAccess.WRITE).store_string(JSON.stringify({"saved":JSON.parse_string(FileAccess.get_file_as_string(path)),"live_campaign":screen.campaign.s,"live_profile":screen.campaign.profile,"live_combat":JSON.parse_string(screen.model.serialized_state()),"restored_campaign":restored.s,"restored_profile":restored.profile,"restored_combat":JSON.parse_string(restored.model.serialized_state())},"  "))
			check(restored_ok and restored_campaign and restored_profile and restored_model,"restore full pair "+gun+"/"+outfit)
	# Modal inspection is read-only; cancel and confirm protect an existing run.
	var saved := Campaign.new()
	saved.start("burst",9182,0,"balanced",screen.CampaignContent.RouteMap.VERSION,"work",true)
	check(saved.save()==OK,"isolated existing campaign fixture")
	var saved_bytes := FileAccess.get_file_as_bytes(Campaign.SAVE)
	screen._open_preparation(false)
	await settle()
	await touch("preparation_options")
	check(screen.find_child("PreparationOptions",true,false)!=null,"options open")
	screen.seed_input.text="817263"
	screen.seed_input.text_changed.emit("817263")
	await touch("DialogClose")
	await touch("starting_deck")
	var capacity_rule: Label=screen.find_child("OutfitCapacityRule",true,false)
	check(capacity_rule!=null and capacity_rule.text.contains("최소 유지") and capacity_rule.text.contains("정비 후 최대"),"outfit minimum and expansion are available in details")
	var seen: Array = []
	for ammo in MagazineBuild.start_deck(screen.selected_weapon_id):
		if seen.has(ammo): continue
		seen.append(ammo)
		var caption := screen.find_child("StartingRound_"+str(ammo),true,false) as Label
		check(caption!=null,"current starting deck detail "+str(ammo))
	await touch("DialogClose")
	check(FileAccess.get_file_as_bytes(Campaign.SAVE)==saved_bytes,"inspection preserves existing save")
	await super.touch("start_"+screen.selected_weapon_id)
	check(screen.find_child("NewRunConfirmation",true,false)!=null,"existing run confirmation retained")
	await touch("DialogCancel")
	check(FileAccess.get_file_as_bytes(Campaign.SAVE)==saved_bytes,"cancel preserves existing run bytes")
	await super.touch("start_"+screen.selected_weapon_id)
	await touch("DialogConfirm")
	check(screen.page=="run" and int(screen.campaign.s.seed)==817263,"confirmation launches selected seed")
	# Emulate asymmetric safe insets without claiming Android device verification.
	screen._open_preparation(false)
	await settle()
	for entry in [["left",40],["right",16],["top",8],["bottom",16]]:
		screen.content_margin.add_theme_constant_override("margin_"+entry[0],entry[1])
	await settle()
	var safe := Rect2(40,8,1114,516)
	check(safe.encloses(equipment().launch.get_global_rect()),"simulated asymmetric safe area retains start")
	await capture("equipment_safe_insets")
	screen._open_preparation(true)
	await settle()
	var locked_outfit := screen.find_child("outfit_select_carrier",true,false) as Button
	var locked_weapon := screen.find_child("weapon_select_deadbolt",true,false) as Button
	check(locked_outfit.disabled,"training outfit restriction retained")
	check(locked_weapon.disabled and locked_weapon.get_node("Art").self_modulate.a<1.0,"training weapon has disabled art")
	check(locked_outfit.get_node("Icon").self_modulate.a<1.0,"training outfit has disabled art")
	await capture("equipment_training_locks")
	await super.touch("start_"+screen.selected_weapon_id)
	check(screen.campaign==null and screen.model.s.outfit=="work","training start binding retained")
	screen.free()
	await settle()
	FileAccess.open(output.path_join("review.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"geometry":frames,"scope":"Native PC touch/keyboard and safe-area emulation; not Android hardware validation."},"  "))
	print("EQUIPMENT LIVE UI COMPLETE checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
