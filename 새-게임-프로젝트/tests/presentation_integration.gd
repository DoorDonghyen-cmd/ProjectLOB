extends "res://tests/campaign_magazine_ui.gd"
## Native production-entry lifecycle/render checks. Never use the player's profile.
const Cases=preload("res://tests/surface_fx_cases.gd")
var samples:Array=[]
var captures:Array=[]
var frame_samples:Array=[]
var active_case:=""
var last_frame_usec:=0
var impact_regions:Dictionary={}

func tick_sample() -> void:
	var now:=Time.get_ticks_usec()
	if last_frame_usec>0:frame_samples.append(float(now-last_frame_usec)/1000.0)
	last_frame_usec=now

func metrics(label:String) -> Dictionary:
	var values:=frame_samples.duplicate();values.sort()
	return {"label":label,"frames":values.size(),"frame_ms_median":values[values.size()/2] if not values.is_empty() else 0,"frame_ms_p95":values[mini(values.size()-1,ceili(values.size()*0.95)-1)] if not values.is_empty() else 0,"nodes":get_node_count(),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"orphans":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),"static_bytes":Performance.get_monitor(Performance.MEMORY_STATIC),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"tweens":get_processed_tweens().size()}

func picture(label:String) -> void:
	await capture(label);captures.append(label+".png")

func remember_impact() -> void:
	if active_case!="flow" or not is_instance_valid(host) or not is_instance_valid(host.campaign_hud):return
	var region:int=host.campaign.s.region
	var b=host.campaign_hud.board
	if impact_regions.has(region) or b.damage_popups.is_empty():return
	impact_regions[region]=true
	var name:="impact_r%d.png"%(region+1)
	var image:Image=root.get_texture().get_image()
	image.save_png(output.path_join(name));captures.append(name)
	var label:Label=host.campaign_hud.node("FireName")
	var ink:Color=label.get_theme_color("font_color")*label.modulate
	check(ink.get_luminance()>0.08,"disabled primary label keeps readable ink during actual impact")
	var area:=Rect2i(label.get_global_rect()).intersection(Rect2i(Vector2i.ZERO,image.get_size()))
	var pixels:=0
	for y in range(area.position.y,area.end.y):
		for x in range(area.position.x,area.end.x):
			var pixel:=image.get_pixel(x,y)
			if absf(pixel.r-ink.r)<0.02 and absf(pixel.g-ink.g)<0.02 and absf(pixel.b-ink.b)<0.02:pixels+=1
	check(pixels>=12,"disabled primary label is visible in native captured pixels")
	var camera:Transform2D=b.get_global_transform_with_canvas()*b.finish_camera()
	var visible:Rect2=Rect2(Vector2.ZERO,Vector2(root.size))
	for item in b.damage_popup_layout():
		check(visible.encloses(camera*item.bounds),"damage reading remains inside viewport r%d"%(region+1))

func title_and_dispose() -> Dictionary:
	host.page="menu";host.redraw();await settle()
	check(not is_instance_valid(host.campaign_hud),"leaving combat disposes its live HUD")
	await create_timer(0.4).timeout
	check(get_processed_tweens().is_empty(),"title has no abandoned effect/confirmation tweens")
	return metrics("title")

func stress() -> void:
	active_case="stress"
	host=load("res://redesign/main.tscn").instantiate();root.add_child(host);host.save_enabled=false;await settle()
	var late_counts:Array=[]
	for cycle in range(15):
		var c=Cases.make(["arc","transfer","fire"][cycle%3])
		host.campaign=c;host.model=c.model;host.page="run";host.redraw();await settle()
		var adapter=host.campaign_hud
		adapter.board.speed_scale=0.01
		adapter.hud.feedback.save_setting("motion","normal");await settle()
		var before:Dictionary=canonical(c.model.s)
		await tap("Menu");await tap("MenuClose");await tap("Parts");await tap("CloseDetail")
		check(canonical(c.model.s)==before,"menu/detail does not mutate complete model/RNG")
		await tap("Fire")
		check(adapter.board.damage_popups.is_empty() and adapter.board.surface_profile.is_empty(),"combined impact/transfer surfaces settle")
		# The actual menu preference is shared with subsequent screens.
		await tap("Menu");await tap("CombatMotion");await tap("CombatMotion");await tap("MenuClose")
		check(adapter.hud.feedback.preferences.data.motion=="instant","public menu selects instant presentation")
		await settle()
		var draws:Dictionary={"board":0,"readout":0}
		adapter.board.draw.connect(func():draws.board+=1)
		adapter.board.readout_layer.draw.connect(func():draws.readout+=1)
		frame_samples=[];last_frame_usec=0
		var exact:Dictionary=canonical(c.model.s)
		for frame in range(35):await process_frame
		check(canonical(c.model.s)==exact,"idle combined effects never advance model/RNG")
		check(draws.board==0 and draws.readout==0,"instant idle has no recurring battlefield redraws")
		var row:=metrics("cycle_%02d_%s"%[cycle,["arc","transfer","fire"][cycle%3]])
		row.draws=draws.duplicate();samples.append(row)
		var old_hud:WeakRef=weakref(adapter)
		var title:Dictionary=await title_and_dispose();title.cycle=cycle;samples.append(title)
		check(old_hud.get_ref()==null,"old HUD is released after navigation")
		if cycle>=3:late_counts.append(title.nodes)
		if cycle in [2,14]:await picture("title_after_%02d"%cycle)
		print("INTEGRATION CYCLE ",cycle," title_nodes=",title.nodes," orphans=",title.orphans," redraws=",draws)
	check(late_counts.max()==late_counts.min(),"same warmed-up title node count remains constant across repeated combat cycles")
	check(samples.filter(func(row):return row.label=="title").all(func(row):return row.orphans==0),"no orphan nodes remain after repeated navigation")
	host.free();host=null;await settle()

func flow() -> void:
	active_case="flow"
	var folder:=ProjectSettings.globalize_path("res://../qa_runtime/boss_skills_20261106/heavy_elite")
	var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("balance.json")))
	var endpoint:Dictionary=report.endpoints[0]
	var c=Campaign.new()
	check(c.restore(folder.path_join("combat_heavy_17_r1_n101.json")),"earned latest full-campaign opening restores")
	await mount(c);host.save_enabled=true
	var phase_captures:Dictionary={}
	var regions:Dictionary={}
	for index in range(endpoint.commands.size()):
		var command:Dictionary=endpoint.commands[index]
		var action:String=command.action
		if index==0 and action=="enter":continue
		frame_samples=[];last_frame_usec=0
		if action in ["fire","cool","reload","emergency","eject"]:
			if not check(is_instance_valid(host.campaign_hud),"recorded public combat has live production HUD"):break
			var adapter=host.campaign_hud
			adapter.board.speed_scale=0.01
			if not regions.has(int(c.s.region)):
				regions[int(c.s.region)]=true
				root.size=[Vector2i(1280,800),Vector2i(1170,540),Vector2i(1008,454)][int(c.s.region)%3];await settle();hud_bounds()
				adapter.hud.feedback.save_setting("motion","normal")
				await picture("battle_r%d"%(int(c.s.region)+1))
				await tap("Menu");await tap("MenuClose");await tap("Parts");await tap("CloseDetail")
			if action=="eject":
				for slot in command.indices:await tap("Select%d"%int(slot))
				await tap("EjectToggle")
			else:
				if action=="fire" and int(command.get("rounds",0))>0:adapter.select_budget(int(command.rounds),false)
				await tap({"fire":"Fire","cool":"Cool","reload":"Reload","emergency":"Reload"}[action])
		else:
			check(host._campaign_action(action,command.get("id",""),str(command.get("replace","")) if action in ["reward","buy"] else str(command.get("ammo","")),str(command.get("replace",""))),"actual campaign handler accepts recorded "+action)
			await settle()
		check(not host.busy,"no stranded input lock after "+action)
		if command.has("phase"):check(c.s.phase==command.phase,"recorded phase remains exact after "+action)
		if command.has("credits"):check(int(c.s.credits)==int(command.credits),"recorded wallet remains exact after "+action)
		var phase:String=c.s.phase
		if not phase_captures.has(phase) and phase!="combat":
			phase_captures[phase]=true;await picture("flow_"+phase)
		if phase!="combat" and samples.size()<70:samples.append(metrics("flow_%03d_%s"%[index,phase]))
		if index%35==0:print("INTEGRATION FLOW ",index,"/",endpoint.commands.size()," region=",c.s.region," phase=",phase)
		if failures.size()>8:break
	check(c.s.phase=="won" and regions.size()==5,"all five regions reach final ending through live HUD/controllers")
	# The recorded endpoint's `parts` field is the equipped set, not all storage.
	check(c.model.s.deck==endpoint.deck and c.equipped_parts()==endpoint.parts,"final earned deck and equipped parts match recorded route")
	var recorded:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("Roaming/Godot/app_userdata/Last on Board - Core Redesign/city_probe.json")))
	check(canonical({"campaign":c.s,"combat":c.model.s,"profile":c.profile})==canonical(recorded),"complete campaign/model/RNG/profile matches original committed replay")
	check(host.save_error.is_empty(),"actual isolated autosave has no error")
	var saved=Campaign.new();check(saved.restore(),"last production autosave restores")
	check(canonical({"campaign":saved.s,"combat":saved.model.s,"profile":saved.profile})==canonical({"campaign":c.s,"combat":c.model.s,"profile":c.profile}),"final full-campaign save is exact")
	host.free();host=null;await settle()

func run() -> void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/presentation_integration_20261106/"):quit(2);return
	root.content_scale_size=Vector2i.ZERO;root.content_scale_factor=1
	Input.emulate_mouse_from_touch=false;Input.emulate_touch_from_mouse=false
	process_frame.connect(tick_sample)
	RenderingServer.frame_post_draw.connect(remember_impact)
	if OS.get_environment("QA_INTEGRATION_MODE")=="flow":await flow()
	else:await stress()
	RenderingServer.frame_post_draw.disconnect(remember_impact)
	process_frame.disconnect(tick_sample)
	FileAccess.open(output.path_join("integration.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"samples":samples,"captures":captures,"scope":"Native PC Compatibility integration; accelerated replay; not sustained Android FPS/temperature or human readability."},"  "))
	print("PRESENTATION INTEGRATION COMPLETE checks=%d failures=%d samples=%d"%[checks,failures.size(),samples.size()]);quit(0 if failures.is_empty() else 1)
