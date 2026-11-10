extends "res://tests/campaign_magazine_ui.gd"
const Cases=preload("res://tests/surface_fx_cases.gd")
const Surface=preload("res://redesign/surface_feedback.gd")
const VFX=preload("res://redesign/combat_vfx.gd")
var recording:=false
var current_case:=""
var seen:Dictionary={}
var frames:Array=[]
var pending:Dictionary={}
var contacts:Dictionary={}

func pixels(image: Image, area: Rect2, color: Color) -> int:
	var rect:=Rect2i(area).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	var count:=0
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			var pixel:=image.get_pixel(x,y)
			if absf(pixel.r-color.r)<0.02 and absf(pixel.g-color.g)<0.02 and absf(pixel.b-color.b)<0.02:count+=1
	return count

func post_draw() -> void:
	if not recording or not is_instance_valid(host) or not is_instance_valid(host.campaign_hud):return
	var b=host.campaign_hud.board
	if b.float_target<0 or b.surface_profile.is_empty():return
	var phase:=0 if b.pulse<0.06 else 1 if b.pulse<0.3 else 2 if b.pulse<0.65 else 3
	var key:="%s_%s_%d_%d"%[current_case,b.surface_profile.kind,b.float_target,phase]
	if seen.has(key):return
	seen[key]=true
	var image:Image=root.get_texture().get_image()
	var global:Transform2D=b.get_global_transform_with_canvas()*b.finish_camera()
	var point:Vector2=b.surface_contact(b.float_target)
	if b.surface_profile.kind=="shot" and not current_case.begins_with("acquired"):
		if contacts.has(current_case):check(point.is_equal_approx(contacts[current_case]),"contact remains fixed through recoil/push "+key)
		else:contacts[current_case]=point
	var links:Array=[]
	for packet in b.chain_targets:
		var end:Vector2=b.surface_contact(int(packet.target))
		var source:Vector2=point
		if packet.kind=="burn_transfer":source=b.burn_anchor(b.float_target);end=b.burn_anchor(int(packet.target))
		links.append({"kind":packet.kind,"source":str(global*source),"destination":str(global*end),"receipt":packet})
		if packet.kind=="burn_transfer" and phase in [1,2] and not b.reduced_feedback:
			var spark:Vector2=global*VFX.ember_point(source,end,clampf(b.pulse/0.72,0,1))
			check(pixels(image,Rect2(spark-Vector2(5,5),Vector2(10,10)),Color("df9460"))>=2,"visible embers travel from enemy, not muzzle "+key)
	var readouts:Array=[]
	if phase==0 and b.surface_profile.metal and b.surface_profile.contact and not b.reduced_feedback:
		check(pixels(image,Rect2(global*point-Vector2(75,55),Vector2(150,110)),Color("d9c99f"))>=4,"metal ricochets visible outside digits "+key)
	for item in b.damage_popup_layout():
		var bounds:Rect2=global*item.bounds
		var area:=Rect2(bounds.position,Vector2(bounds.size.x,maxf(1,bounds.size.y-18)))
		var ink:=pixels(image,area,item.entry.color)
		if phase==0:check(ink>=4,"numbers remain visible over effects "+key)
		readouts.append({"number":item.entry.number,"bounds":str(bounds),"pixels":ink})
	pending[key+".png"]=image
	frames.append({"case":current_case,"phase":phase,"pulse":b.pulse,"profile":b.surface_profile.duplicate(true),"point":str(global*point),"foot":str(global*b.enemy_feet(b.float_target)),"muzzle":str(global*b.player_muzzle()),"links":links,"readouts":readouts,"image":key+".png"})

func flush() -> void:
	for name in pending:pending[name].save_png(output.path_join(name))
	pending.clear()

func fire_compare(c) -> void:
	var oracle=Model.new();oracle.s=c.model.s.duplicate(true)
	check(oracle.fire(),"oracle accepts same public prefix "+current_case)
	recording=true;await tap("Fire");recording=false;flush()
	check(canonical(c.model.s)==canonical(oracle.s),"presentation preserves complete model and RNG "+current_case)
	var b=host.campaign_hud.board
	check(b.surface_profile.is_empty() and b.damage_popups.is_empty(),"transient surface feedback clears "+current_case)
	check(b.readout_layer.z_index>=7,"effect layer is above targeted actor and below number draw order")

func exercise(kind: String, size: Vector2i, reduced: bool=false) -> void:
	root.size=size
	var c=Cases.make(kind);await mount(c);host.save_enabled=false
	var b=host.campaign_hud.board;b.speed_scale=2.0 if size.x==1280 else 1.0;b.reduced_feedback=reduced
	current_case=kind+("_reduced" if reduced else "")+"_%dx%d"%[size.x,size.y]
	host.campaign_hud.select_budget(1)
	await fire_compare(c)
	check(frames.any(func(f):return f.case==current_case),"surface/burn native frame observed "+current_case)
	hud_bounds()
	if kind in ["fire","burn"]:
		var before:Dictionary=canonical(c.model.s);var clock:float=b.effect_clock
		await create_timer(0.24).timeout
		check(canonical(c.model.s)==before,"idle fire animation never advances a turn")
		if not reduced:check(b.effect_clock!=clock,"active flames animate while waiting")
	await capture("settled_"+current_case)

func acquired_regions() -> void:
	var folder:=ProjectSettings.globalize_path("res://../qa_runtime/focus_build_20261103/climb_growth_primary")
	var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("balance.json")))
	for region in range(1,6):
		var c
		for battle in report.battles:
			if battle.gun!="single" or int(battle.region)!=region:continue
			var candidate=Campaign.new()
			if candidate.restore(folder.path_join("combat_single_%d_r%d_n%d.json"%[battle.seed,battle.region,battle.node])) and candidate.model.s.phase=="ready":c=candidate;break
		if not check(c!=null,"earned region save available "+str(region)):continue
		root.size=Vector2i(1280,800);await mount(c);host.save_enabled=false
		host.campaign_hud.board.speed_scale=1.0
		host.campaign_hud.select_budget(3);current_case="acquired_r%d"%region
		await fire_compare(c)
		var path:=output.path_join(current_case+"_after.json")
		check(c.save(path)==OK,"earned region saves")
		var resumed=Campaign.new();check(resumed.restore(path),"earned region resumes")
		check(canonical(resumed.model.s)==canonical(c.model.s),"region resume remains exact")
		await capture("settled_"+current_case)

func run() -> void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/surface_fx_20261106/"):quit(2);return
	root.content_scale_size=Vector2i.ZERO;root.content_scale_factor=1
	RenderingServer.frame_post_draw.connect(post_draw)
	for kind in Cases.SPECS:await exercise(kind,Vector2i(1280,800))
	for kind in ["shield_break","arc","fire","transfer"]:await exercise(kind,Vector2i(1008,454))
	for kind in ["shield_break","fire","transfer"]:await exercise(kind,Vector2i(1008,454),true)
	await acquired_regions()
	RenderingServer.frame_post_draw.disconnect(post_draw)
	if is_instance_valid(host):host.free()
	FileAccess.open(output.path_join("frames.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"frames":frames},"  "))
	print("SURFACE FX UI COMPLETE checks=%d failures=%d frames=%d"%[checks,failures.size(),frames.size()]);quit(0 if failures.is_empty() else 1)
