extends "res://tests/fire_heat_rules.gd"
const Scene=preload("res://redesign/samples/fire_heat/screen.tscn")
var ui
func settle()->void:
	for i in range(8):await process_frame
	await RenderingServer.frame_post_draw
func capture(label: String)->void:
	await settle();root.get_texture().get_image().save_png(output.path_join(label+".png"))
func point(id: String)->Vector2:
	var node: Control=ui.node(id)
	return node.get_global_transform_with_canvas()*(node.size*0.5)
func touch(pos: Vector2,down: bool,index: int=0)->void:
	var event:=InputEventScreenTouch.new();event.index=index;event.position=pos;event.pressed=down
	root.push_input(event,true);await process_frame
func motion(pos: Vector2,relative: Vector2)->void:
	var event:=InputEventScreenDrag.new();event.index=0;event.position=pos;event.relative=relative
	root.push_input(event,true);await process_frame
func tap(id: String)->void:
	var button: Button=ui.node(id)
	check(not button.disabled and button.is_visible_in_tree(),"public button enabled "+id)
	if button.disabled:return
	if ui.node("MenuScroll").is_ancestor_of(button):ui.node("MenuScroll").ensure_control_visible(button);await settle()
	await touch(point(id),true);await touch(point(id),false)
	var start:=Time.get_ticks_msec()
	while ui.busy and Time.get_ticks_msec()-start<12000:await process_frame
	await settle()
func drag_prefix(count: int,release: bool=true)->void:
	ui.node("MagazineHousing").scroll_horizontal=0;await settle()
	var from:=point("Select0");var to:=point("Select%d"%(count-1))
	await touch(from,true)
	await motion(from+Vector2(16,0),Vector2(16,0))
	await motion(to,to-from-Vector2(16,0))
	if release:await touch(to,false)
	await settle()
func state_without_input(state: Dictionary)->Dictionary:
	var result: Dictionary=canonical(state)
	result.fire_heat_trial.rounds=0
	return result
func geometry()->void:
	for id in ["Title","Actions","MagazineHeader","MagazineHousing"]:
		check(ui.get_global_rect().encloses(ui.node(id).get_global_rect()),"comparison group stays inside viewport "+id)
	check(ui.board.size.y>=80,"comparison retains usable battlefield")
func run()->void:
	if not setup():return
	Input.emulate_mouse_from_touch=true
	ui=Scene.instantiate();ui.resume_saved=false;root.add_child(ui);await settle()
	ui.hud.feedback.save_setting("motion","fast")
	for size in [Vector2i(740,360),Vector2i(844,390),Vector2i(1280,800)]:
		root.size=size;await settle();geometry();await capture("ready_%dx%d"%[size.x,size.y])
		await tap("Menu");await capture("menu_%dx%d"%[size.x,size.y]);await tap("MenuClose")
	for index in range(5):
		root.size=Vector2i(740,360) if index%2==0 else Vector2i(844,390)
		ui.gun_index=index;ui.mount(false);await settle()
		var before: Dictionary=state_without_input(ui.model.s)
		var two:=mini(2,ui.maximum_budget())
		await drag_prefix(two)
		check(ui.current_budget()==two and not ui.eject_mode,"drag edits firing prefix without ejection")
		check(state_without_input(ui.model.s)==before,"drag does not spend ammo, time or RNG")
		await drag_prefix(1)
		check(ui.current_budget()==1,"dragging back to first card chooses one")
		check(ui.last_prediction.shots.size()==1,"preview uses selected one-card budget")
		var oracle=Model.new();oracle.s=ui.model.s.duplicate(true);oracle.fire()
		await tap("Fire")
		check(canonical(ui.model.s)==canonical(oracle.s),"public fire obeys exact selected budget and results")
		ui.mount(false);await settle();await tap("Select1")
		check(ui.eject_mode and ui.eject_selected==[1],"short tap retains middle-card ejection")
		var count: int=ui.model.s.magazine.size()
		await tap("EjectToggle")
		check(ui.model.s.magazine.size()==count-1,"existing immediate ejection still works")
		ui.mount(false);await settle();ui.select_budget(1)
		var old: Dictionary=canonical(ui.model.s)
		await drag_prefix(2,false)
		await touch(Vector2(2,2),false);await settle()
		check(canonical(ui.model.s)==old and not ui.drag.active,"release outside cancels prefix change")
		await drag_prefix(2,false)
		ui.notification(Control.NOTIFICATION_APPLICATION_FOCUS_OUT);await touch(Vector2(2,2),false);await settle()
		check(canonical(ui.model.s)==old,"focus loss cancels without a queued shot")
		await drag_prefix(2,false)
		await touch(point("Select1"),true,1);await touch(point("Select1"),false,1);await touch(Vector2(2,2),false);await settle()
		check(canonical(ui.model.s)==old,"second finger cancels instead of firing")
		await drag_prefix(2,false)
		var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true
		root.push_input(escape,true);await touch(Vector2(2,2),false);await settle()
		check(canonical(ui.model.s)==old and not ui.overlay_open,"Escape cancels drag without opening a menu")
		print("UI ",ui.model.s.gun)
	# Native mouse must not rely on touch-to-mouse emulation.
	ui.gun_index=0;ui.mount(false);await settle()
	var from:=point("Select0");var to:=point("Select2")
	var press:=InputEventMouseButton.new();press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true;press.position=from
	root.push_input(press,true);await process_frame
	var move:=InputEventMouseMotion.new();move.position=to;move.relative=to-from;move.button_mask=MOUSE_BUTTON_MASK_LEFT
	root.push_input(move,true);await process_frame
	press=press.duplicate();press.pressed=false;press.position=to;root.push_input(press,true);await settle()
	check(ui.current_budget()==2 and not ui.eject_mode,"native mouse clamps selection to weapon limit")
	await capture("prefix_mouse_740x360")
	ui.gun_index=3;ui.mount(false);await settle()
	await drag_prefix(2,false)
	var housing: ScrollContainer=ui.node("MagazineHousing")
	var edge: Vector2=housing.get_global_transform_with_canvas()*Vector2(housing.size.x-6,housing.size.y*0.5)
	await motion(edge,Vector2(30,0));await create_timer(0.8).timeout;await settle()
	check(housing.scroll_horizontal>0 and ui.current_budget()==ui.maximum_budget(),"held drag edge scrolls long magazine while retaining weapon cap")
	await touch(edge,false);await settle()
	check(not ui.drag.active and not ui.eject_mode,"releasing scrolled prefix commits without ejection")
	await tap("Menu");await tap("TrialBaseline")
	check(ui.options.input=="fixed" and ui.options.reload=="legacy" and not ui.options.damage,"one button restores actual baseline")
	await tap("TrialInput");await tap("TrialReload");await tap("TrialDamage")
	check(ui.options.input=="range" and ui.options.reload=="none" and ui.options.damage,"independent menu conditions restart same opening")
	await tap("BudgetLess");var budget: int=ui.current_budget();await tap("MenuClose")
	var saved: Dictionary=canonical(ui.model.s)
	ui.free();await settle();ui=Scene.instantiate();root.add_child(ui);await settle()
	check(ui.resumed and canonical(ui.model.s)==saved and ui.current_budget()==budget,"separate save resumes all conditions and selected prefix")
	check(not FileAccess.file_exists("user://campaign.json") and not FileAccess.file_exists("user://combat_weapon_magazine_v1.json"),"comparison never writes campaign or previous comparison saves")
	await capture("resumed_conditions")
	ui.free();await settle();finish()
