extends "res://tests/campaign_magazine_ui.gd"
const Cases=preload("res://tests/impact_parts_cases.gd")
const FX=preload("res://redesign/firing_vfx.gd")
const Data=preload("res://redesign/campaign_content.gd")
const Content=preload("res://redesign/content.gd")
const Outfit=preload("res://redesign/outfit_art.gd")
var recording:=false
var current_case:=""
var seen:Dictionary={}
var frames:Array=[]
var shot_packets:Array=[]
var fixed_origins:Dictionary={}
var geometry_rows:Array=[]
var pending_images:Dictionary={}

func flush_images() -> void:
	for path in pending_images:pending_images[path].save_png(output.path_join(path))
	pending_images.clear()

func make(gun: String, kind: String):
	var c=Campaign.new();c.start(gun,17,0,"balanced",4,"carrier",true);c.enter(101)
	var spec:Dictionary=Cases.SPECS[kind]
	c.s.parts=spec.parts.duplicate();c.s.equipped_parts=spec.parts.duplicate()
	var m=c.model;m.s.equipped_parts=spec.parts.duplicate();m.s.part="none"
	m.s.deck=spec.rounds.duplicate()
	while m.s.deck.size()<14:m.s.deck.append("basic_p2")
	m.begin_encounter()
	m.s.magazine=spec.rounds.duplicate();m.s.magazine_loaded=spec.rounds.duplicate();m.s.hand=[]
	m.s.draw=m.s.deck.duplicate()
	for id in spec.rounds:m.s.draw.erase(id)
	m.s.phase="ready";m.s.magazine_ejected=0;m.s.fire_heat_trial.rounds=1
	m.s.enemies=[Data._enemy(["runner",500,0,1,30]),Data._enemy(["runner",500,0,1,34])]
	m.s.reinforcements=[];m.s.projectiles=[];m.s.encounter_total=2;m.s.deployed=2;m.assign_opening_lanes()
	if kind=="thermal":m.s.heat=ceili(Content.heat_limit(m.s)/2.0)
	if kind=="blocked":m.s.enemies[0].barrier=1
	m._record("load",{"load_order":spec.rounds.duplicate(),"whole_magazine":true})
	return c

func post_draw() -> void:
	if not recording or not is_instance_valid(host) or not is_instance_valid(host.campaign_hud):return
	var b=host.campaign_hud.board
	if b.bullet.is_empty() or not b.launch_ready:return
	var ordinal:=shot_packets.size()
	var key:="%s_%d"%[current_case,ordinal]
	if fixed_origins.has(key):
		check(b.projectile_origin().is_equal_approx(fixed_origins[key]),"in-flight origin stays fixed "+key)
	else:fixed_origins[key]=b.projectile_origin()
	var phase:="flash" if b.bullet_progress<0.22 else "trail" if b.bullet_progress<0.6 else "arrival"
	key+="_"+phase
	if seen.has(key):return
	seen[key]=true
	var packet:Dictionary=shot_packets.back()
	var expected:=FX.profile(str(b.display_state.gun),packet)
	check(b.firing_profile==expected,"visible profile follows actual resolved shot "+key)
	var path:=FX.geometry(b.projectile_origin(),b.enemy_position(b.projectile_target),b.bullet_progress,b.firing_profile,b.reduced_feedback)
	check(path.length<=b.projectile_origin().distance_to(path.head)+0.01,"actual native tail stays outside actor "+key)
	var global_muzzle:Vector2=b.get_global_transform_with_canvas()*b.player_muzzle()
	check(Rect2(Vector2.ZERO,Vector2(root.size)).has_point(global_muzzle),"muzzle inside current window "+key)
	var image:Image=root.get_texture().get_image()
	pending_images[key+".png"]=image
	if phase=="flash" and not b.reduced_feedback and b.firing_profile.attack:
		var color:Color=b.firing_profile.color
		var ink:=0
		var area:=Rect2i(global_muzzle-Vector2(12,65),Vector2(90,100)).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
		for y in range(area.position.y,area.end.y):
			for x in range(area.position.x,area.end.x):
				var pixel:=image.get_pixel(x,y)
				if absf(pixel.r-color.r)<0.02 and absf(pixel.g-color.g)<0.02 and absf(pixel.b-color.b)<0.02:ink+=1
		check(ink>=2,"actual tinted atlas pixels visible at muzzle "+key)
	frames.append({"case":current_case,"ordinal":ordinal,"phase":phase,"progress":b.bullet_progress,"profile":b.firing_profile,"origin":str(b.projectile_origin()),"muzzle":str(b.player_muzzle()),"global_muzzle":str(global_muzzle),"angle":b.muzzle_angle(),"target":b.projectile_target,"head":str(path.head),"image":key+".png"})

func pose_matrix() -> void:
	var b=host.campaign_hud.board
	var original:Dictionary=b.display_state.duplicate(true)
	for outfit in Outfit.BODIES:
		b.display_state.outfit=outfit
		for kick in [0.0,0.2,0.5,0.8,1.0]:
			b.hero_action="fire";b.flash=kick
			var muzzle:Vector2=b.player_muzzle()
			var actor=b.weapon_viewport.get_node("Actor")
			var expected:Vector2=actor.registered_muzzle(b.player_feet(),b.character_scale())+b._recoil()
			check(muzzle.is_equal_approx(expected),"actual gun attachment at every outfit/kick "+str(original.gun)+"/"+outfit)
			check(is_finite(b.muzzle_angle()) and absf(b.muzzle_angle())<PI/2,"flash follows forward barrel orientation")
			if b.WeaponActor.family(original.gun) == "long":
				check_long_gun_grip(actor, original.gun, outfit)
			geometry_rows.append({"gun":original.gun,"outfit":outfit,"kick":kick,"muzzle":str(muzzle),"angle":b.muzzle_angle()})
	b.display_state=original;b.hero_action="aim";b.flash=0

func check_long_gun_grip(actor: Node2D, gun: String, outfit: String) -> void:
	var frame: Dictionary = actor.frame_for(outfit, gun, "aim")
	var weapon: Dictionary = actor.WEAPONS[gun]
	var hold: Transform2D = actor.registered_transform()
	var origin: Vector2 = actor.FOOT - frame.foot * frame.scale
	check(absf(hold.get_rotation()) < deg_to_rad(12.0), "long gun fires close to level " + gun)
	for index in range(2):
		var hand: Rect2 = frame.hands[index]
		var area := Rect2(origin + hand.position * frame.scale, hand.size * frame.scale)
		var contact: Vector2 = hold * (weapon.grip if index == 0 else weapon.support)
		check(area.grow(4.0).has_point(contact), "long gun stays within the hand " + gun + "/" + outfit)

func fire_and_compare(c) -> void:
	var b=host.campaign_hud.board
	shot_packets.clear()
	var listener:=func(r):shot_packets.append(r.duplicate(true))
	b.shot_started.connect(listener)
	var oracle=Model.new();oracle.s=c.model.s.duplicate(true)
	check(oracle.fire(),"oracle accepts current public prefix "+current_case)
	var expected:Array=oracle.s.history.back().detail.results
	await tap("Fire")
	check(canonical(c.model.s)==canonical(oracle.s),"all model, targeting and RNG exact "+current_case)
	check(canonical(shot_packets)==canonical(expected),"one presented launch per actual result "+current_case)
	check(b.bullet.is_empty() and b.firing_profile.is_empty() and not b.launch_ready,"effects reset after action "+current_case)
	b.shot_started.disconnect(listener)
	flush_images()

func exercise(gun: String, kind: String, size: Vector2i, reduced: bool=false) -> void:
	root.size=size
	var c=make(gun,kind);await mount(c);host.save_enabled=false
	var b=host.campaign_hud.board
	# Slow only the comparison captures. Small-window/acquired cases retain 1x.
	b.speed_scale=3.0 if size.x==1280 else 1.0;b.reduced_feedback=reduced
	current_case=gun+"_"+kind+("_reduced" if reduced else "")+"_%dx%d"%[size.x,size.y]
	if kind=="plain" and size.x==1280:pose_matrix()
	var count:int=Cases.SPECS[kind].rounds.size()
	for i in range(count):
		host.campaign_hud.select_budget(1)
		recording=i==count-1
		await fire_and_compare(c)
		recording=false
	var observed:Array=frames.filter(func(f):return f.case==current_case)
	check(not observed.is_empty(),"native flight observed "+current_case)
	if size.x==1280:check(observed.any(func(f):return f.phase=="flash"),"native muzzle pulse observed "+current_case)
	hud_bounds();await capture("settled_"+current_case)

func overdrive_and_support() -> void:
	for kind in ["overdrive","support"]:
		root.size=Vector2i(1280,800)
		var c=make("heavy" if kind=="overdrive" else "single","plain")
		var rounds:Array=["basic","basic","basic","basic","basic"] if kind=="overdrive" else ["charge_hot","basic_p2"]
		c.model.s.magazine=rounds.duplicate();c.model.s.magazine_loaded=rounds.duplicate()
		c.model.s.deck=rounds.duplicate()
		while c.model.s.deck.size()<14:c.model.s.deck.append("basic_p2")
		c.model.s.draw=c.model.s.deck.duplicate()
		for id in rounds:c.model.s.draw.erase(id)
		c.model._record("load",{"load_order":rounds.duplicate(),"whole_magazine":true})
		if kind=="overdrive":c.model.s.heat=Content.heat_limit(c.model.s)-1
		await mount(c);host.save_enabled=false;host.campaign_hud.board.speed_scale=3.0
		host.campaign_hud.select_budget(rounds.size())
		current_case=kind;recording=true
		await fire_and_compare(c);recording=false
		if kind=="overdrive":
			check(shot_packets.any(func(r):return r.overdrive),"native action includes real overdrive")
			check(frames.any(func(f):return f.case==kind and f.profile.overdrive),"actual extra collar gas profile observed")
		else:
			check(frames.any(func(f):return f.case==kind and not f.profile.attack),"support is visibly quiet, no empowered shot")

func acquired() -> void:
	var folder:=ProjectSettings.globalize_path("res://../qa_runtime/focus_build_20261103/climb_growth_primary")
	var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("balance.json")))
	for gun in ["single","burst","heavy"]:
		var c
		for battle in report.battles:
			if battle.gun!=gun:continue
			var candidate=Campaign.new()
			var path:=folder.path_join("combat_%s_%d_r%d_n%d.json"%[gun,battle.seed,battle.region,battle.node])
			if candidate.restore(path) and candidate.model.s.phase=="ready":c=candidate;break
		if not check(c!=null,"actual acquired climb available "+gun):continue
		root.size=Vector2i(1280,800);await mount(c);host.save_enabled=false
		host.campaign_hud.board.speed_scale=1.0
		current_case="acquired_"+gun;recording=true
		await fire_and_compare(c);recording=false
		var path:=output.path_join(current_case+"_after.json")
		check(c.save(path)==OK,"acquired run saves "+gun)
		var restored=Campaign.new();check(restored.restore(path),"acquired run resumes "+gun)
		check(canonical(restored.model.s)==canonical(c.model.s),"resume preserves exact model "+gun)

func run() -> void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/firing_fx_20261106/"):quit(2);return
	root.content_scale_size=Vector2i.ZERO;root.content_scale_factor=1
	RenderingServer.frame_post_draw.connect(post_draw)
	for gun in FX.GUNS:
		for kind in ["plain","opening"]:await exercise(gun,kind,Vector2i(1280,800))
	for kind in ["stacked","blocked","add"]:await exercise("single",kind,Vector2i(1280,800))
	await exercise("heavy","thermal",Vector2i(1280,800))
	for gun in FX.GUNS:await exercise(gun,"opening",Vector2i(1008,454))
	await exercise("single","stacked",Vector2i(1008,454),true)
	await overdrive_and_support()
	await acquired()
	RenderingServer.frame_post_draw.disconnect(post_draw)
	if is_instance_valid(host):host.free()
	FileAccess.open(output.path_join("frames.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"frames":frames,"pose_matrix":geometry_rows},"  "))
	print("FIRING FX UI COMPLETE checks=%d failures=%d frames=%d poses=%d"%[checks,failures.size(),frames.size(),geometry_rows.size()]);quit(0 if failures.is_empty() else 1)
