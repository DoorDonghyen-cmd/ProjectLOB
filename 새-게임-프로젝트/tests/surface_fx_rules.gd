extends "res://tests/fire_heat_rules.gd"
const Cases=preload("res://tests/surface_fx_cases.gd")
const Surface=preload("res://redesign/surface_feedback.gd")
const VFX=preload("res://redesign/combat_vfx.gd")
func run() -> void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/surface_fx_20261106/"):quit(2);return
	var profiles:Dictionary={}
	for kind in Cases.SPECS:
		var c=Cases.make(kind);var detail:=verify_fire(c.model);var packet:Dictionary=detail.results[0]
		var before:=JSON.stringify(packet);var profile:=Surface.resolve(packet)
		check(JSON.stringify(packet)==before,"surface mapping is read only "+kind);profiles[kind]=profile
		match kind:
			"plain":check(profile.contact and not profile.metal and not profile.shield,"unarmored contact")
			"metal":check(profile.metal,"actual armor contact")
			"chips":check(profile.chips,"only actual armor removal emits chips")
			"shield":check(profile.shield and not profile.broken and not profile.contact,"shield catches the complete hit")
			"shield_break","power_shield":check(profile.shield and profile.broken and not profile.contact,"broken shield is not multiplied HP damage")
			"partial":check(profile.shield and profile.contact,"mixed blocked and HP hits preserve both reactions")
			"fire":check(profile.fire and not packet.fire_zones.is_empty(),"actual ignition and floor interval")
			"arc":check(not packet.secondary.is_empty(),"actual arc follow-ups exist")
			"transfer":
				check(not packet.secondary.is_empty() and packet.secondary[0].damage==0,"burn moves stacks without inventing damage")
				check(Surface.resolve(packet.secondary[0],"burn_transfer").transfer,"actual moved fire uses ember transport")
			"support":check(not profile.contact and not profile.shield and not profile.fire,"preparation has no attack burst")
		for event in detail.advance_events:
			if event.kind=="burn":check(Surface.resolve(event,"burn").burn,"each real burn tick owns its visual pulse")
	for start in [Vector2(10,20),Vector2(120,50)]:
		for finish in [start,Vector2(30,40),Vector2(600,20)]:
			check(VFX.ember_point(start,finish,0).is_equal_approx(start) and VFX.ember_point(start,finish,1).is_equal_approx(finish),"embers preserve actual source/destination")
			check(VFX.arc_points(start,finish,0.2)[0].is_equal_approx(start.snapped(Vector2(2,2))),"arc begins at actual source")
	for width in [0,1,64,600,5000]:
		var tiles:=Surface.zone_layout(12,12+width,200)
		check(tiles.size()<=14,"floor fire has bounded draw count")
		for point in tiles:check(point.x>=12 and point.x<=12+width,"flames stay inside actual interval")
	for spec in [[Surface.SHIELD,Vector2i(740,520),Vector2i(148,104),23],[Surface.METAL,Vector2i(760,600),Vector2i(152,100),29]]:
		var image:Image=spec[0].get_image();check(image.get_size()==spec[1],"compact baked surface atlas")
		var index:int=spec[3]-1
		var last:=image.get_region(Rect2i(Vector2i(index%5,index/5)*spec[2],spec[2]))
		check(last.get_used_rect().size==Vector2i.ZERO,"one-shot surface ends transparent")
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"profiles":profiles},"  "))
	print("SURFACE FX RULES COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
