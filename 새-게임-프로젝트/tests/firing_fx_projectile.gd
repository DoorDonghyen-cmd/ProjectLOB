extends "res://tests/firing_fx_ui.gd"
const BulletVisual=preload("res://redesign/projectile_visual.gd")

func post_draw() -> void:
	var previous:=frames.size()
	super.post_draw()
	if frames.size()==previous or frames.back().phase!="trail":return
	var b=host.campaign_hud.board
	var path:=FX.geometry(b.projectile_origin(),b.enemy_position(b.projectile_target),b.bullet_progress,b.firing_profile,b.reduced_feedback)
	var point:Vector2=b.get_global_transform_with_canvas()*path.head
	var area:=Rect2i(point-Vector2(40,22),Vector2(50,44)).intersection(Rect2i(Vector2i.ZERO,root.size))
	var image:Image=pending_images[frames.back().image]
	var ramp:Array=BulletVisual.STEEL if b.firing_profile.projectile.steel else BulletVisual.COPPER
	if not b.firing_profile.attack:ramp=[Color("34444c"),Color("7d9098"),Color("a7bbc4")]
	var outline:=0;var metal:=0;var band:=0
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			var color:=image.get_pixel(x,y)
			if color.is_equal_approx(ramp[0]):outline+=1
			if absf(color.r-ramp[1].r)<0.01 and absf(color.g-ramp[1].g)<0.01 and absf(color.b-ramp[1].b)<0.01:metal+=1
			if absf(color.r-b.firing_profile.color.r)<0.01 and absf(color.g-b.firing_profile.color.g)<0.01 and absf(color.b-b.firing_profile.color.b)<0.01:band+=1
	# Match renderer's 8-bit quantisation rather than exact float equality.
	check(metal>=5,"metal bullet body visible, not just a tracer "+current_case)
	if b.firing_profile.rank>0:check(band>=2,"actual effect band visible on metal body "+current_case)
	check(path.body_length<=b.projectile_origin().distance_to(path.head)+0.01,"body does not start behind muzzle")
	frames.back().projectile={"shape":b.firing_profile.projectile.shape,"body":str(path.body_size),"metal_pixels":metal,"band_pixels":band,"global_head":str(point),"head":str(path.head),"tail":str(path.tail)}

func exercise_round(gun: String, ammo: String, size: Vector2i, reduced: bool=false, empowered: bool=false) -> void:
	root.size=size
	var c=make(gun,"opening" if empowered else "plain")
	var m=c.model
	m.s.magazine=[ammo];m.s.magazine_loaded=[ammo]
	m.s.deck=[ammo]
	while m.s.deck.size()<14:m.s.deck.append("basic_p2")
	m.s.draw=m.s.deck.duplicate();m.s.draw.erase(ammo)
	m._record("load",{"load_order":[ammo],"whole_magazine":true})
	await mount(c);host.save_enabled=false
	var b=host.campaign_hud.board;b.speed_scale=3.0 if size.x==1280 else 1.0;b.reduced_feedback=reduced
	host.campaign_hud.select_budget(1)
	current_case=gun+"_"+ammo+("_empowered" if empowered else "")+("_reduced" if reduced else "")+"_%dx%d"%[size.x,size.y]
	recording=true;await fire_and_compare(c);recording=false
	var rows:Array=frames.filter(func(f):return f.case==current_case and f.phase=="trail")
	check(not rows.is_empty(),"bullet body captured during actual flight "+current_case)
	hud_bounds()

func run() -> void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/firing_fx_20261106/"):quit(2);return
	root.content_scale_size=Vector2i.ZERO;root.content_scale_factor=1
	RenderingServer.frame_post_draw.connect(post_draw)
	for ammo in ["basic_p2","pierce_p2","precise_p2","push","bore","arc","charge_hot"]:
		await exercise_round("single",ammo,Vector2i(1280,800))
	for gun in FX.GUNS:await exercise_round(gun,"basic_p2",Vector2i(1008,454),false,true)
	await exercise_round("single","pierce_p2",Vector2i(1008,454),true,true)
	await exercise_round("single","basic_p2",Vector2i(1280,800),false,true)
	await acquired()
	RenderingServer.frame_post_draw.disconnect(post_draw)
	if is_instance_valid(host):host.free()
	FileAccess.open(output.path_join("frames.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"frames":frames},"  "))
	print("FIRING FX PROJECTILE COMPLETE checks=%d failures=%d frames=%d"%[checks,failures.size(),frames.size()]);quit(0 if failures.is_empty() else 1)
