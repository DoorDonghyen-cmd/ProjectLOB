extends RefCounted
## A drag from the first card edits a prefix; a tap keeps ordinary ejection.
var ui: Control
var pending:=false
var active:=false
var pointer:=-2
var origin:=Vector2.ZERO
var last_point:=Vector2.ZERO
var scroll_remainder:=0.0
var old_budget:=0
var old_ejection: Array=[]
var old_focus:=-1
var suppress_until:=-1
func _init(surface: Control)->void:ui=surface
func suppress_tap()->bool:return active or Engine.get_process_frames()<=suppress_until
func inside(control: Control,point: Vector2)->bool:
	return control.is_visible_in_tree() and Rect2(Vector2.ZERO,control.size).has_point(control.get_global_transform_with_canvas().affine_inverse()*point)
func selection_inside(point: Vector2)->bool:
	var housing: Control=ui.node("MagazineHousing")
	var local: Vector2=housing.get_global_transform_with_canvas().affine_inverse()*point
	# Thumb jitter may cross the short top/bottom edge, never another UI action.
	return housing.is_visible_in_tree() and Rect2(0,-20,housing.size.x,housing.size.y+40).has_point(local)
func index_at(point: Vector2,project: bool=false)->int:
	if not (selection_inside(point) if project else inside(ui.node("MagazineHousing"),point)):return -1
	var nearest:=-1
	var distance:=INF
	for i in range(ui.model.s.magazine.size()):
		var card: Control=ui.node("Round%d"%i)
		if not project:
			if inside(card,point):return i
			continue
		var center: Vector2=card.get_global_transform_with_canvas()*(card.size*0.5)
		var gap:=absf(center.x-point.x)
		if gap<distance:distance=gap;nearest=i
	return nearest
func update_selection(force: bool=false)->void:
	var index:=index_at(last_point,true)
	var wanted:=mini(index+1,ui.maximum_budget())
	if index>=0 and (force or wanted!=ui.current_budget()):ui.select_budget(wanted,false)
func tick(delta: float)->void:
	if not active:return
	var housing: ScrollContainer=ui.node("MagazineHousing")
	if not inside(housing,last_point):return
	var local: Vector2=housing.get_global_transform_with_canvas().affine_inverse()*last_point
	var direction:=1 if local.x>housing.size.x-24 else (-1 if local.x<24 else 0)
	if direction==0:scroll_remainder=0;return
	scroll_remainder+=direction*300.0*delta
	var pixels:=int(scroll_remainder)
	scroll_remainder-=pixels
	housing.scroll_horizontal+=pixels
	update_selection()
func cancel()->void:
	if active:
		ui.model.s.fire_heat_trial.rounds=old_budget
		ui.eject_selected.assign(old_ejection);ui.eject_mode=not old_ejection.is_empty();ui.hud.focused_round=old_focus
		suppress_until=Engine.get_process_frames()+2
		ui.refresh()
	pending=false;active=false;pointer=-2
func handle(event: InputEvent)->bool:
	if event is InputEventKey and event.is_action_pressed("ui_cancel") and active:cancel();return true
	if ui.busy or ui.overlay_open or not ui.Trial.range_enabled(ui.model.s):return false
	var point:=Vector2.ZERO
	var id:=-2
	var press:=false
	var release:=false
	var move:=false
	if event is InputEventScreenTouch:
		point=event.position;id=event.index;press=event.pressed;release=not press
		if event.canceled:cancel();return true
	elif event is InputEventScreenDrag:point=event.position;id=event.index;move=true
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.device!=InputEvent.DEVICE_ID_EMULATION:
		point=event.position;id=-1;press=event.pressed;release=not press
	elif event is InputEventMouseMotion and event.device!=InputEvent.DEVICE_ID_EMULATION:
		point=event.position;id=-1;move=true
	else:return false
	if press:
		if pending and pointer!=id:cancel();return true
		if index_at(point)!=0:return false
		pending=true;pointer=id;origin=point;last_point=point;scroll_remainder=0
		old_budget=int(ui.model.s.fire_heat_trial.rounds);old_ejection=ui.eject_selected.duplicate();old_focus=ui.hud.focused_round
		return false
	if not pending or pointer!=id:return false
	if move or release:
		last_point=point
		var housing: Control=ui.node("MagazineHousing")
		var inverse:=housing.get_global_transform_with_canvas().affine_inverse()
		var delta: Vector2=inverse*point-inverse*origin
		if not active:
			if delta.y!=0 and absf(delta.y)>32 and absf(delta.y)>absf(delta.x)*2:
				pending=false;return false
			if delta.x<8:
				if release:pending=false
				return false
			active=true
			update_selection(true)
		else:update_selection()
		if release:
			if not selection_inside(point):cancel();return true
			pending=false;active=false;pointer=-2;suppress_until=Engine.get_process_frames()+2
			ui.persist()
		return true
	return active
