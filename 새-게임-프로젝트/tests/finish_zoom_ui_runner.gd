extends "res://tests/finish_feedback_ui_runner.gd"
var zoom_frames:=0
var zoom_seen: Dictionary={}
var peak_zoom: Dictionary={}
var restore_seen: Dictionary={}
var fixed_rects: Dictionary={}
var case_key:=""
var watch_zoom:=false
var sprite_checked:=false

func fixture(kind:String) -> void:
	if kind=="wall_finish":
		await super.fixture("production")
		screen.model.s.enemies=[Data._enemy(["wall",1,0,1,22])]
		screen.model.s.encounter_total=1;screen.model.s.deployed=1
	elif kind in ["edge_left","edge_right"]:
		await super.fixture("finish")
		screen.model.s.enemies[0].distance=1 if kind=="edge_left" else 50
	else:
		await super.fixture(kind)
		return
	screen.model.assign_opening_lanes();screen.redraw();await settle()

func inspect_zoom() -> void:
	if not watch_zoom or not screen.busy or not is_instance_valid(screen.battle_view): return
	var view=screen.battle_view
	var camera:Transform2D=view.finish_camera()
	for name in ["HeatGauge","AmmoGrid","QueuePanel","skip_animation"]:
		var control:Control=screen.find_child(name,true,false)
		if control==null: continue
		if not fixed_rects.has(name): fixed_rects[name]=control.get_global_rect()
		elif fixed_rects[name]!=control.get_global_rect(): errors["HUD moves "+name]=true
	if not view.finish_active or view.fast_forward or view.reduced_feedback:
		if camera!=Transform2D.IDENTITY: errors["camera outside finish"]=true
		return
	var zoom:float=camera.get_scale().x
	if zoom<1.0 or zoom>1.2501: errors["excessive zoom"]=true
	peak_zoom[case_key]=maxf(float(peak_zoom.get(case_key,1.0)),zoom)
	if zoom>1.005:
		zoom_frames+=1
		zoom_seen[case_key]=true
	if view.finish_progress>0.97 and zoom<1.01: restore_seen[case_key]=true
	var viewport:=Rect2(Vector2.ZERO,view.size)
	if not (camera*viewport).grow(1).encloses(viewport): errors["background gaps "+case_key]=true
	for popup in view.damage_popup_layout():
		if not viewport.grow(1).encloses(camera*popup.bounds): errors["cropped number "+case_key]=true
	if case_key.begins_with("wall_finish") and view.finish_progress>0.3 and view.finish_progress<0.55:
		for index in view.creature_sprites:
			var sprite:Sprite2D=view.creature_sprites[index]
			if not sprite.visible: continue
			var expected:Vector2=camera*view.MonsterAnimation.position(sprite.texture,view.enemy_feet(index)+view._actor_offset(index))
			if sprite.position.distance_to(expected)>4: errors["child sprite off camera"]=true
			if not is_equal_approx(sprite.scale.x,zoom*view.MonsterAnimation.Data.SCALE): errors["child sprite scale"]=true
			sprite_checked=true

func run_zoom(kind:String,expect:bool,skip:bool=false) -> void:
	case_key="%s_%d_%s"%[kind,root.size.x,screen.preferences.data.motion]
	fixed_rects.clear();watch_zoom=true
	await exercise(kind,expect,skip)
	watch_zoom=false
	if expect and not skip:
		check(zoom_seen.has(case_key),"camera actually pushes toward finish "+case_key)
		check(restore_seen.has(case_key),"camera eases back before transition "+case_key)
		if kind=="finish": check(float(peak_zoom.get(case_key,1.0))>=1.24,"centered finisher reaches requested 25 percent zoom")
		print("FINISH ZOOM ",case_key," peak=",peak_zoom.get(case_key,1.0))
	else: check(not zoom_seen.has(case_key),"instant/skip avoids additional camera travel")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/finish_zoom/"): quit(1);return
	screen=load("res://redesign/main.tscn").instantiate()
	screen.save_enabled=false;screen.presentation_speed=1.0
	root.add_child(screen);await settle()
	screen.preferences.data.motion="normal"
	process_frame.connect(inspect_zoom)
	for resolution in [Vector2i(1008,630),Vector2i(1280,800),Vector2i(1440,630)]:
		root.size=resolution;await settle()
		for kind in ["finish","multi","wall_finish","edge_left","edge_right"]: await run_zoom(kind,true)
	await run_zoom("burn",true)
	case_key="";zoom_seen.clear()
	await run_zoom("finish",true,true)
	screen.preferences.data.motion="fast";screen.presentation_speed=0.55
	await run_zoom("finish",true)
	screen.preferences.data.motion="instant";screen.presentation_speed=0.05
	await run_zoom("finish",false)
	check(sprite_checked,"separate wall sprite follows world camera")
	check(zoom_frames>20,"intermediate zoom frames measured")
	for error in errors: check(false,error)
	print("FINISH ZOOM UI COMPLETE checks=%d failures=%d"%[checks,failures])
	screen.queue_free();await process_frame
	quit(0 if failures==0 else 1)
