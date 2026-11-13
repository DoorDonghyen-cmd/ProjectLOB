extends "res://tests/campaign_magazine_ui.gd"
const Content=preload("res://redesign/content.gd")
var recording:=false
var motion_seen: Dictionary={}
func record_motion() -> void:
	if not recording or not is_instance_valid(host) or not is_instance_valid(host.campaign_hud):return
	var board=host.campaign_hud.board
	var actor=board.weapon_viewport.get_node("Actor")
	var label: String=actor.gun_id+"_"+actor.pose_id+"_"+str(roundi(actor.recoil_amount*2))+"_"+str(roundi(actor.reload_amount*2))
	if motion_seen.has(label):return
	motion_seen[label]={"pose":actor.pose_id,"muzzle":str(board.player_muzzle()),"outfit":actor.outfit_id}
	root.get_texture().get_image().save_png(output.path_join("action_"+label+".png"))
func key(action: String) -> void:
	for pressed in [true,false]:
		var event:=InputEventAction.new();event.action=action;event.pressed=pressed
		root.push_input(event,true);await process_frame
	await settle()
func swipe(rail: Control) -> void:
	var point: Vector2=rail.get_global_transform_with_canvas()*Vector2(rail.size.x-30,rail.size.y*0.5)
	var start:=InputEventScreenTouch.new();start.index=0;start.position=point;start.pressed=true
	Input.parse_input_event(start);await process_frame
	for unused in range(24):
		point.x-=16
		var drag:=InputEventScreenDrag.new();drag.index=0;drag.position=point;drag.relative=Vector2(-16,0);drag.velocity=Vector2(-600,0)
		Input.parse_input_event(drag);await process_frame
	var end:=InputEventScreenTouch.new();end.index=0;end.position=point;end.pressed=false
	Input.parse_input_event(end);await settle()
func run() -> void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").ends_with("/qa_runtime/weapon_live_20261106/ui"):quit(2);return
	root.content_scale_size=Vector2i.ZERO;root.content_scale_factor=1
	Input.emulate_mouse_from_touch=true
	# ScrollContainer enables drag scrolling on desktop only when touch
	# emulation is advertised, matching the Android capability in this PC check.
	Input.emulate_touch_from_mouse=true
	print("QA touch capability: ",DisplayServer.is_touchscreen_available())
	RenderingServer.frame_post_draw.connect(record_motion)
	if FileAccess.file_exists(Campaign.SAVE):DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.SAVE))
	host=load("res://redesign/main.tscn").instantiate();host.save_enabled=false;root.add_child(host);await settle()
	for extent in [Vector2i(1280,800),Vector2i(1170,540),Vector2i(1008,454)]:
		root.size=extent;host.preferences.data.text_scale=1.0;host._open_preparation(false);await settle()
		var equipment: Control=host.find_child("EquipmentScreen",true,false)
		var rail: ScrollContainer=equipment.find_child("WeaponScroll",true,false)
		var launch: Control=equipment.launch
		var layout_before: Rect2=launch.get_global_rect()
		await tap("weapon_select_single")
		rail.scroll_horizontal=0;await settle()
		var selected_before: String=host.selected_weapon_id
		var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true;wheel.position=rail.get_global_transform_with_canvas()*(rail.size*0.5)
		root.push_input(wheel,true);await settle()
		check(rail.scroll_horizontal>0 and host.selected_weapon_id==selected_before,"PC mouse wheel browses horizontal choices")
		rail.scroll_horizontal=0;await settle()
		await swipe(rail)
		check(rail.scroll_horizontal>0,"real touch swipes native horizontal rail "+str(extent))
		check(host.selected_weapon_id==selected_before,"drag does not accidentally select a gun")
		check(launch.get_global_rect()==layout_before,"horizontal browsing never moves launch")
		for id in ["deadbolt","rewinder"]:
			await tap("weapon_select_"+id)
			check(host.selected_weapon_id==id,"touch selects new gun")
			var button: Control=equipment.find_child("weapon_select_"+id,true,false)
			check(rail.get_global_rect().encloses(button.get_global_rect()),"selected gun fully visible in rail")
			var expected_width:=floorf((rail.size.x-40)/5)
			check(is_equal_approx(button.size.x,expected_width) and button.size.y==92,"new gun preserves previous five-column card size")
			var portrait: Control=equipment.find_child("OutfitPortrait",true,false)
			check(portrait.actor.gun_id==id,"new art bound to actual live actor")
			check(host.ReadableUI.available(host).encloses(launch.get_global_rect()),"start available without scrolling page")
			await capture("equipment_"+id+"_%dx%d"%[extent.x,extent.y])
			await tap("weapon_info")
			var details: Node=host.find_child("WeaponDetails",true,false)
			check(details!=null and details.find_children("*","Label",true,false).any(func(label):return "기본 3발" in label.text),"native new-weapon details include starting cadence")
			await capture("details_"+id+"_%dx%d"%[extent.x,extent.y])
			await tap("DialogClose")
		await tap("weapon_select_single")
		rail.scroll_horizontal=0;await settle()
		var last: Control=equipment.find_child("weapon_select_deadbolt",true,false)
		last.grab_focus();await settle();await key("ui_accept")
		check(host.selected_weapon_id=="deadbolt" and rail.scroll_horizontal>0,"keyboard focus follows seventh gun")
	root.size=Vector2i(1280,800)
	for gun in ["deadbolt","rewinder"]:
		var c=Campaign.new();c.start(gun,17,0,"balanced",4,"carrier",true)
		check(c.advance_departure(true) and c.enter(101),"native current-run encounter")
		await mount(c);host.save_enabled=true
		var hud: Control=host.campaign_hud
		hud.hud.feedback.preferences.data.motion="fast";hud.hud.feedback.preferences.data.effects_volume=0.0;hud.hud.feedback.configure()
		hud.board.speed_scale=0.2
		hud_bounds()
		check(hud.node("Weapon").text==Content.GUNS[gun].name,"native battle uses correct name")
		if gun=="deadbolt":
			var mark: int=Model.WeaponRoles.mark(c.model.s)
			check(hud.node("Seal%d"%mark).visible and hud.node("Reload").disabled,"native battle shows seal and locks reload")
			var before: Dictionary=c.model.s.duplicate(true)
			await tap("Select%d"%mark)
			check(hud.node("Detail").visible and hud.eject_selected.is_empty(),"native sealed card opens detail, never ejection")
			await tap("CloseDetail")
			check(c.model.s==before,"native sealed inspection retains RNG and exact state")
		await capture("combat_"+gun+"_ready")
		hud.select_budget(1)
		var expected=Model.new();expected.s=c.model.s.duplicate(true);check(expected.fire(),"oracle real fire")
		recording=true
		await tap("Fire")
		check(canonical(c.model.s)==canonical(expected.s),"native UI fires the exact real resolver")
		if c.s.phase=="combat" and gun=="rewinder":
			var copy=Model.new();copy.s=c.model.s.duplicate(true)
			check(copy.cool_magazine() and copy.s.phase=="ready","native first cooling survives")
			check(hud.node("CoolName").text=="냉각·되감기","native first cooling advertises reversal")
			await capture("combat_rewinder_before_cool")
			await tap("Cool")
			check(canonical(c.model.s)==canonical(copy.s) and c.model.s.weapon_role_trial.rewound,"native UI reversal matches exact model")
			check(hud.node("CoolName").text=="냉각","native reversal spent")
			await capture("combat_rewinder_after_cool")
		recording=false
		var restored=Campaign.new();check(restored.restore(),"native automatic Campaign save resumes")
		check(canonical(restored.s)==canonical(c.s) and canonical(restored.model.s)==canonical(c.model.s),"native auto save retains full weapon/RNG/order state")
	# Existing training remains available, with only its original weapons.
	host._open_preparation(true);await settle()
	check(host.selected_weapon_id=="single","training safely selects existing weapon")
	for gun in ["deadbolt","rewinder"]:
		var option: Button=host.find_child("weapon_select_"+gun,true,false)
		check(option.disabled and option.tooltip_text.contains("탄창"),"new magazine-only gun explains training restriction")
	RenderingServer.frame_post_draw.disconnect(record_motion)
	FileAccess.open(output.path_join("ui.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"motion_frames":motion_seen},"  "))
	host.free();await settle()
	print("WEAPON LIVE UI COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
