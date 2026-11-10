extends "res://tests/shop_terminal_live_runner.gd"
const Upgrade=preload("res://redesign/ammo_upgrade.gd")
var mode:="normal"
var case_name:=""
var pending_events:Array=[]
var frames:Array=[]
var images:Dictionary={}

func canonical(value):return JSON.parse_string(JSON.stringify(value))
func bundle():return canonical({"campaign":screen.campaign.s,"combat":screen.model.s,"profile":screen.campaign.profile})
func oracle():
	var copy=Campaign.new();check(copy.restore_state(bundle()),"oracle restores actual UI state "+case_name);return copy

func post_draw() -> void:
	for event in pending_events:
		var targets:Array=[]
		for path in event.targets:
			var target=root.get_node_or_null(NodePath(path)) as Control
			if target==null or not target.is_visible_in_tree():continue
			var effect=target.get_node_or_null("InteractionResponse")
			if effect==null:continue
			check(not effect is Control,"decoration cannot alter container or touch layout")
			if target is Container:check(effect.ink().get_luminance()>0.1,"panel confirmation uses readable current-theme ink")
			check(effect.progress<1 and effect.kind!="input","completion is visible on the updated target "+case_name)
			targets.append({"name":target.name,"path":path,"rect":str(target.get_global_rect()),"progress":effect.progress,"kind":effect.kind,"tween":effect.tween!=null and effect.tween.is_running()})
		check(not targets.is_empty(),"accepted command has actual completion surface "+case_name)
		var name:="%s_%02d.png"%[case_name,frames.size()]
		images[name]=root.get_texture().get_image()
		frames.append({"case":case_name,"motion":mode,"event":event,"targets":targets,"image":name})
	pending_events.clear()

func queue_event(event: Dictionary) -> void:pending_events.append(event.duplicate(true))
func flush() -> void:
	for name in images:images[name].save_png(output.path_join(name))
	images.clear()

func set_motion(value: String) -> void:
	mode=value;screen.preferences.data.motion=value;screen.feedback.configure(screen.preferences.data)
	screen.interactions.motion()

func input_state(button: Button, label: String) -> void:
	var before:Dictionary=bundle();var rect:=button.get_global_rect();var minimum:=button.get_combined_minimum_size()
	var at:Vector2=button.get_global_transform_with_canvas()*(button.size*0.5)
	var motion:=InputEventMouseMotion.new();motion.position=at;root.push_input(motion,true)
	await settle()
	check(bundle()==before,"hover/focus never changes campaign")
	button.grab_focus();await process_frame
	for pressed in [true,false]:
		if not pressed:
			var leave:=InputEventMouseMotion.new();leave.position=Vector2(2,2);leave.global_position=leave.position
			leave.relative=leave.position-at;leave.button_mask=MOUSE_BUTTON_MASK_LEFT
			root.push_input(leave,true);await process_frame
		var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		event.position=at if pressed else Vector2(2,2);event.global_position=event.position;root.push_input(event,true)
		await process_frame
		await RenderingServer.frame_post_draw
		check(button.get_global_rect()==rect and button.get_combined_minimum_size()==minimum,"pressed/focused rect and touch size unchanged")
		root.get_texture().get_image().save_png(output.path_join(label+("_down.png" if pressed else "_cancel.png")))
	check(bundle()==before,"release outside cancels the native button")

func unchecked_touch(button: Button) -> void:
	var at:Vector2=button.get_global_transform_with_canvas()*(button.size*0.5)
	for down in [true,false]:
		var event:=InputEventScreenTouch.new();event.index=0;event.position=at;event.pressed=down
		root.push_input(event,true);await process_frame
	await settle()

func keyboard_select(button: Button) -> void:
	var before:Dictionary=bundle();var count:int=screen.interactions.transactions.size()
	button.grab_focus()
	for down in [true,false]:
		var event:=InputEventAction.new();event.action="ui_accept";event.pressed=down
		root.push_input(event,true);await process_frame
	await settle()
	check(root.gui_get_focus_owner()==button,"paint decoration never steals keyboard focus")
	check(bundle()==before and count==screen.interactions.transactions.size(),"keyboard selection is not a completed transaction")

func shop_actions(size: Vector2i, motion: String) -> void:
	root.size=size;root.content_scale_size=Vector2i.ZERO;root.content_scale_factor=1
	await enter_shop(0,"carrier","burst",true);await fixture_offers();set_motion(motion)
	case_name="shop_%dx%d_%s"%[size.x,size.y,motion]
	await keyboard_select(shop().offer_button(1));await keyboard_select(shop().offer_button(0))
	await input_state(field("Buy"),case_name)
	var expected=oracle();check(expected.buy(0),"same public buy succeeds")
	expected.sync_combat();expected.normalize_for_save()
	var count:int=screen.interactions.transactions.size()
	await touch_key("Buy");await settle();flush()
	check(bundle()==canonical({"campaign":expected.s,"combat":expected.model.s,"profile":expected.profile}),"real touch purchase preserves exact campaign/model/RNG")
	check(screen.interactions.transactions.size()==count+1,"one completion per accepted purchase")
	var before:Dictionary=bundle();var after:int=screen.interactions.transactions.size()
	await unchecked_touch(field("Buy"))
	check(bundle()==before and after==screen.interactions.transactions.size(),"disabled double tap never buys or completes again")
	check(not screen._campaign_action("buy",0,"","",false),"sold purchase rejected")
	await settle();check(bundle()==before and after==screen.interactions.transactions.size(),"rejected command never shows success")
	# Paint removal must not change even container minimum sizes.
	for node in screen.find_children("InteractionResponse","Node2D",true,false):
		var target:Control=node.surface;var rect:=target.get_global_rect();var minimum:=target.get_combined_minimum_size()
		node.halt();check(rect==target.get_global_rect() and minimum==target.get_combined_minimum_size(),"cue does not own layout")
	check(screen.campaign.save()==OK,"post-interaction state saves")
	var restored=Campaign.new();check(restored.restore(),"post-interaction state resumes")
	check(canonical(restored.model.s)==canonical(screen.model.s),"resume keeps exact model")

func part_actions() -> void:
	await enter_shop(0,"carrier","burst",true);await fixture_offers();set_motion("normal")
	for id in ["opening","thermal_drive"]:screen.campaign.s.parts.append(id)
	screen.campaign._sync_equipped_parts();screen.redraw();await settle()
	await touch_key("PartsButton")
	var pane=field("PartsPane")
	await touch_button(pane.stored_buttons["opening"])
	case_name="install";var expected=oracle();check(expected.equip("opening"),"oracle installs owned part")
	await touch_button(pane.get_node("%Apply"));await settle();flush()
	check(canonical(screen.model.s)==canonical(expected.model.s),"installation matches actual resolver")
	case_name="remove";expected=oracle();check(expected.equip("opening"),"oracle removes installed part")
	await touch_button(pane.get_node("%Apply"));await settle();flush()
	check(canonical(screen.model.s)==canonical(expected.model.s),"removal matches actual resolver")
	await touch_button(pane.stored_buttons["thermal_drive"])
	await touch_button(pane.get_node("%Slots").get_child(0))
	case_name="replace_core";expected=oracle();check(expected.replace_part("volley_drive","thermal_drive"),"oracle replaces exclusive core")
	await touch_button(pane.get_node("%Apply"));await settle();flush()
	check(canonical(screen.model.s)==canonical(expected.model.s),"replacement matches actual resolver")

func workshop() -> void:
	var c=Campaign.new();c.start("burst",17,0,"balanced",Campaign.Content.RouteMap.VERSION,"carrier",true);c.advance_departure(true)
	var rooms:Array=c.current_nodes();var wanted:Dictionary=rooms.filter(func(room):return Campaign.Content.room_kind(room)=="workshop")[0]
	var path:Array=[wanted]
	while int(path[0].floor)>1:
		for previous in rooms:
			if previous.next.has(path[0].id):path.push_front(previous);break
	for room in path:
		check(c.enter(int(room.id)),"controlled workshop fixture follows a legal route")
		if int(room.id)==int(wanted.id):break
		match str(c.s.phase):
			"combat":
				for enemy in c.model.s.enemies:enemy.hp=0
				c.model.s.reinforcements=[];c.model.s.phase="reward";c.sync_combat()
				for step in range(5):
					if c.s.phase!="reward":break
					check(c.reward("credits"),"controlled route completes reward")
			"supply","event":c.resolve("skip");c.leave()
			_:c.leave()
	screen.campaign=c;screen.model=c.model;screen.page="run";screen.redraw();await settle();set_motion("normal")
	var view=screen.find_child("WorkbenchScreen",true,false)
	var id:=str(c.compressible_ids()[0])
	await touch_button(view.slots.get_node("Owned_"+id))
	await touch_button(view.get_node("Inspector/Inset/Actions/Apply"))
	var dialog=view.upgrade_dialog()
	var before:Dictionary=bundle();var previous:int=screen.interactions.transactions.size()
	await touch_button(dialog.body.get_node("Actions/Cancel"));await settle()
	check(bundle()==before and previous==screen.interactions.transactions.size(),"cancel upgrade has no completion or state mutation")
	await touch_button(view.get_node("Inspector/Inset/Actions/Apply"))
	dialog=view.upgrade_dialog();case_name="upgrade"
	var expected=Upgrade.copy(c);check(Upgrade.execute(expected,id),"upgrade oracle accepts same pair")
	expected.sync_combat();expected.normalize_for_save()
	await touch_button(dialog.body.get_node("Actions/Confirm"));await settle();flush()
	check(canonical(screen.model.s)==canonical(expected.model.s),"upgrade feedback preserves exact committed result")
	check(frames.any(func(f):return f.case=="upgrade" and f.targets.any(func(t):return t.kind=="upgraded")),"new actual ammo item is highlighted")

func stale_result() -> void:
	await enter_shop(0,"carrier","burst",true);await fixture_offers();set_motion("normal")
	var count:int=screen.interactions.transactions.size()
	check(screen._campaign_action("buy",0,"","",false),"valid purchase before immediate navigation")
	screen.page="menu";screen.redraw();await settle()
	check(screen.interactions.transactions.size()==count,"delayed completion never leaks onto another page")

func copied_controls() -> void:
	await enter_shop(0,"carrier","burst",true);await fixture_offers();set_motion("normal")
	var original:Button=shop().offer_button(0)
	screen.interactions.response(original).pulse("acquired")
	var copy:Button=original.duplicate();copy.name="DuplicateResponseProbe"
	screen.add_child(copy);copy.position=Vector2(-2000,-2000)
	await settle()
	var effect=copy.get_node("InteractionResponse")
	check(effect.surface==copy and effect.feedback==screen.interactions,"duplicated controls bind their own surface and manager")
	check(effect.progress==1 and effect.kind.is_empty(),"duplicates never replay old completion")
	copy.free()
	var flow:=HFlowContainer.new();flow.position=Vector2(-2000,-2000);flow.size=Vector2(400,44);screen.add_child(flow)
	for text in ["75 Cr","탄약 20/30"]:
		var label:=Label.new();label.text=text;flow.add_child(label)
	await settle()
	var minimum:=flow.get_combined_minimum_size();var size_before:=flow.size
	screen.interactions.pulse(flow);await settle()
	check(flow.get_combined_minimum_size()==minimum and flow.size==size_before,"decorations add no phantom flow gap or minimum size")
	flow.free()

func refreshed_stock() -> void:
	await enter_shop(0,"carrier","burst",true);await fixture_offers();set_motion("normal")
	var count:int=screen.interactions.transactions.size();case_name="new_stock"
	var expected=oracle();check(expected.buy(0),"oracle buys before stock refresh")
	expected.sync_combat();expected.normalize_for_save();check(expected.reroll(),"oracle refreshes stock")
	expected.sync_combat();expected.normalize_for_save()
	check(screen._campaign_action("buy",0,"","",false),"purchase accepted before immediate refresh")
	check(screen._campaign_action("reroll","","","",false),"stock refresh accepted")
	shop().refresh();await settle();flush()
	check(bundle()==canonical({"campaign":expected.s,"combat":expected.model.s,"profile":expected.profile}),"rapid refresh keeps both exact actual results/RNG")
	check(screen.interactions.transactions.size()==count+1 and screen.interactions.transactions.back().command=="reroll","old purchase does not mark newly generated stock as bought")

func combat_settings() -> void:
	var c=preload("res://tests/impact_parts_cases.gd").make("plain")
	screen.campaign=c;screen.model=c.model;screen.page="run";screen.redraw();await settle()
	var adapter=screen.campaign_hud
	adapter.hud.feedback.save_setting("motion","normal");await settle()
	var before:Dictionary=bundle()
	await unchecked_touch(adapter.node("Menu"))
	check(adapter.node("CombatMotion").is_visible_in_tree(),"motion setting opened through the actual menu")
	await unchecked_touch(adapter.node("CombatMotion"));await unchecked_touch(adapter.node("CombatMotion"))
	check(adapter.hud.feedback.preferences.data.motion=="instant" and screen.interactions.motion()=="instant","shared button feedback follows live combat setting (hud=%s shared=%s)"%[adapter.hud.feedback.preferences.data.motion,screen.interactions.motion()])
	var effect=adapter.node("CombatMotion").get_node("InteractionResponse")
	check(effect.progress==1 and (effect.tween==null or not effect.tween.is_running()),"instant combat input has no leftover tween")
	check(bundle()==before,"feedback setting never changes combat/RNG")

func run() -> void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/interaction_fx_20261106/"):quit(2);return
	Input.emulate_mouse_from_touch=false;Input.emulate_touch_from_mouse=false
	screen=load("res://redesign/main.tscn").instantiate();root.add_child(screen);await settle()
	screen.interactions.transaction_shown.connect(queue_event)
	RenderingServer.frame_post_draw.connect(post_draw)
	await shop_actions(Vector2i(1280,800),"normal")
	await shop_actions(Vector2i(1170,540),"instant")
	await part_actions();await workshop();await stale_result();await refreshed_stock();await copied_controls();await combat_settings()
	RenderingServer.frame_post_draw.disconnect(post_draw);flush()
	for frame in frames:
		if frame.motion=="instant":check(frame.targets.all(func(t):return not t.tween),"instant setting uses a stationary confirmation")
	FileAccess.open(output.path_join("frames.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"frames":frames},"  "))
	screen.free()
	print("INTERACTION FX UI COMPLETE checks=%d failures=%d frames=%d"%[checks,failures,frames.size()]);quit(0 if failures==0 else 1)
