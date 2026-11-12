extends "res://tests/campaign_magazine_ui.gd"
const Cases=preload("res://tests/impact_parts_cases.gd")
const Style=preload("res://redesign/impact_style.gd")
const FX=preload("res://redesign/firing_vfx.gd")
const Tier=preload("res://redesign/enhanced_shot_fx.gd").Tier
const EXPECTED_TIERS={"add":Tier.TRACER,"opening":Tier.EMBERS,"third":Tier.SHOCKWAVE,"stacked":Tier.SHOCKWAVE,"thermal":Tier.EMBERS,"kill":Tier.EMBERS,"tag_add":Tier.TRACER,"tag_multiplier":Tier.EMBERS}
var recording:=false
var current_case:=""
var seen:Dictionary={}
var frames:Array=[]
var flights:Dictionary={}
var pending_images: Dictionary = {}

func palette_pixels(frame: Image, rect: Rect2, color: Color) -> int:
	var area:=Rect2i(rect).intersection(Rect2i(Vector2i.ZERO,frame.get_size()))
	var count:=0
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			var pixel:=frame.get_pixel(x,y)
			if absf(pixel.r-color.r)<0.015 and absf(pixel.g-color.g)<0.015 and absf(pixel.b-color.b)<0.015:count+=1
	return count

func post_draw() -> void:
	if not recording or not is_instance_valid(host) or not is_instance_valid(host.campaign_hud):return
	var board=host.campaign_hud.board
	if board.launch_ready and not board.bullet.is_empty() and board.bullet_progress >= 0.5 and not flights.has(current_case):
		var path:=FX.geometry(board.projectile_origin(),board.enemy_position(board.projectile_target),board.bullet_progress,board.firing_profile,board.reduced_feedback)
		flights[current_case]={"tier":board.firing_profile.tier,"tail":path.tail_length,"part_powered":board.firing_profile.part_powered}
		pending_images[current_case+"_flight.png"] = root.get_texture().get_image()
	if board.damage_popups.is_empty():return
	var phase:=0 if board.pulse<0.02 else 1 if board.pulse<0.25 else 2 if board.pulse<0.55 else 3 if board.pulse<0.72 else 4
	var ordinal: int = board.salvo_results.size()
	var key := "%s_%d_%d" % [current_case, ordinal, phase] if current_case == "boost_salvo" else "%s_%d" % [current_case, phase]
	if seen.has(key):return
	seen[key]=true
	var image:Image=root.get_texture().get_image()
	var entries:Array=[]
	for item in board.damage_popup_layout():
		var entry:Dictionary=item.entry
		var global:Rect2=board.get_global_transform_with_canvas()*item.bounds
		var ink:Rect2=global
		ink.size.y=maxf(1,ink.size.y-18)
		var pixels:=palette_pixels(image,ink,entry.color)
		entries.append({"target":entry.target,"number":entry.number,"amount":entry.amount,"color":entry.color.to_html(false),"family":entry.style.family,"operator":entry.style.operator,"rank":entry.style.rank,"kill":entry.kill,"bounds":str(global),"palette_pixels":pixels})
		if phase==0 and entry.style.active:check(pixels>=8,"actual number hue rendered "+key+"/"+str(entry.target))
		if current_case == "stacked_1008x454" and entry.get("activated", false):
			check(not item.bounds.intersects(board.enemy_plaque(entry.target)), "boosted number stays clear of its HP plate " + key)
	var badges: Array = board.activation_badges()
	var accent: Color = board.impact_style.color if board.impact_style.get("active", false) else Color("b9c4a3")
	for badge in badges:
		var ink: Rect2 = board.get_global_transform_with_canvas() * Rect2(badge.bounds.position, Vector2(2, badge.bounds.size.y))
		check(palette_pixels(image, ink, accent) > 0, "activation plate actually rendered " + key)
	frames.append({"case":current_case,"ordinal":ordinal,"phase":phase,"pulse":board.pulse,"reduced":board.reduced_feedback,"impact":board.impact_style,"tier":board.firing_profile.get("tier", Tier.STANDARD),"entries":entries,"badges":badges,"number_reacts":board.damage_popups[0].get("activated",false),"image":key+".png"})
	pending_images[key+".png"] = image

func fire_and_compare(c) -> void:
	var oracle=Model.new();oracle.s=c.model.s.duplicate(true)
	check(oracle.fire(),"oracle accepts the same public prefix "+current_case)
	await tap("Fire")
	for name in pending_images: pending_images[name].save_png(output.path_join(name))
	pending_images.clear()
	check(canonical(c.model.s)==canonical(oracle.s),"presentation leaves complete model and RNG exact "+current_case)
	check(host.campaign_hud.board.damage_popups.is_empty() and host.campaign_hud.board.impact_style.is_empty(),"hit sprites/readouts reset "+current_case)
	check(host.campaign_hud.board.activation_badges().is_empty(),"activation clears after the shot "+current_case)

func exercise(kind: String, size: Vector2i, reduced: bool=false) -> void:
	root.size=size
	var c=Cases.make(kind);await mount(c);host.save_enabled=false
	host.campaign_hud.board.speed_scale=1.0;host.campaign_hud.board.reduced_feedback=reduced
	current_case=kind+("_reduced" if reduced else "")+"_%dx%d"%[size.x,size.y]
	var count:int=Cases.SPECS[kind].rounds.size()
	for i in range(count):
		host.campaign_hud.select_budget(1)
		recording=i==count-1
		await fire_and_compare(c)
		recording=false
	var observed:Array=frames.filter(func(f):return f.case==current_case)
	var tier: int = EXPECTED_TIERS.get(kind, Tier.STANDARD)
	if check(flights.has(current_case),"actual flight observed "+current_case):
		var flight: Dictionary = flights[current_case]
		check(flight.tier == tier,"flight selects the resolved tier "+current_case)
		check(flight.tail == 0.0 if reduced else (flight.tail <= 20.0 if tier == Tier.STANDARD else flight.tail > 30.0),"trail fits tier and motion setting "+current_case)
		if kind.begins_with("tag_"):
			check(flight.part_powered, "real tag part powers the launch effect "+current_case)
	check(not observed.is_empty(),"actual impact observed "+current_case)
	check(observed.all(func(frame): return int(frame.tier) == tier),"impact keeps the flight tier "+current_case)
	if not observed.is_empty():check(observed[0].entries[0].family==Cases.SPECS[kind].family,"resolved trigger uses expected visible family "+current_case)
	if kind=="blocked":check(observed.all(func(f):return not f.impact.active),"blocked part never displays product burst")
	if kind in ["plain", "blocked"]:check(observed.all(func(frame): return frame.badges.is_empty()),"no badges for a plain or fully blocked shot")
	if kind=="stacked":
		check(observed.any(func(frame): return frame.badges.size()==3 and frame.number_reacts),"simultaneous part and ammo triggers with the same damage number")
		check(observed.all(func(frame): return frame.badges.all(func(badge): return badge.scale==1.0) if reduced else true),"motion setting holds icons at their resting size")
		if not reduced:
			check(observed.any(func(frame): return frame.badges.any(func(badge): return badge.scale > 1.30)),"activation reaches visible overshoot")
			check(observed.any(func(frame): return frame.badges.all(func(badge): return badge.scale == 1.0)),"all activations settle to the resting size "+current_case)
	if kind=="kill":check(observed.any(func(f):return f.entries[0].kill and f.entries[0].family=="multiply"),"lethal product retains violet hue")
	if kind=="arc":check(observed.any(func(f):return f.entries.size()>1 and f.entries[1].family=="volley"),"secondary arc has its own hue")
	if kind == "tag_multiplier":
		check(observed.any(func(frame): return frame.badges.size() == 2 and frame.badges[0].effect.id == "tag_single_mult" and frame.badges[1].effect.id == "tag_copy"), "tag multiplier and the copy part each get a badge")
	hud_bounds()
	await capture("settled_"+current_case)

func boost_salvo() -> void:
	root.size = Vector2i(1008,454)
	var c=Cases.make("add")
	await mount(c)
	host.save_enabled=false
	host.campaign_hud.select_budget(2)
	current_case="boost_salvo"
	recording=true
	await fire_and_compare(c)
	recording=false
	var observed := frames.filter(func(frame): return frame.case == current_case)
	check(observed.any(func(frame): return frame.ordinal == 1 and not frame.badges.is_empty() and frame.badges[0].effect.title == "증폭 준비" and not frame.number_reacts), "first round prepares a boost without a damage pulse")
	check(observed.any(func(frame): return frame.ordinal == 2 and not frame.badges.is_empty() and frame.badges[0].effect.title == "증폭 적용" and frame.number_reacts), "second round consumes the boost and marks its own damage number")

func acquired() -> void:
	var folder:=ProjectSettings.globalize_path("res://../qa_runtime/focus_build_20261103/climb_growth_primary")
	var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("balance.json")))
	var c
	for battle in report.battles:
		if battle.gun!="single" or not battle.parts.has("third_striker"):continue
		var candidate=Campaign.new()
		var path:=folder.path_join("combat_single_731042_r%d_n%d.json"%[battle.region,battle.node])
		if candidate.restore(path) and candidate.model.s.phase=="ready":c=candidate;break
	if not check(c!=null,"actual acquired positional build available"):return
	root.size=Vector2i(1280,800);await mount(c);host.save_enabled=false
	host.campaign_hud.board.speed_scale=0.55;current_case="acquired";recording=true
	await fire_and_compare(c);recording=false
	var path:=output.path_join("acquired_after.json")
	check(c.save(path)==OK,"real acquired state saves")
	var restored=Campaign.new();check(restored.restore(path),"real acquired state resumes")
	check(canonical(restored.model.s)==canonical(c.model.s),"resume keeps exact model after coloured hits")

func run() -> void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/impact_parts_20261106/"):quit(2);return
	root.content_scale_size=Vector2i.ZERO;root.content_scale_factor=1
	RenderingServer.frame_post_draw.connect(post_draw)
	for kind in Cases.SPECS:await exercise(kind,Vector2i(1280,800))
	for kind in ["plain","opening","stacked"]:await exercise(kind,Vector2i(1008,454))
	await exercise("stacked",Vector2i(1008,454),true)
	await boost_salvo()
	await acquired()
	RenderingServer.frame_post_draw.disconnect(post_draw)
	if is_instance_valid(host):host.free()
	FileAccess.open(output.path_join("frames.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"frames":frames},"  "))
	print("IMPACT PARTS UI COMPLETE checks=%d failures=%d frames=%d"%[checks,failures.size(),frames.size()]);quit(0 if failures.is_empty() else 1)
