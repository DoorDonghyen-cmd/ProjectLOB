extends "res://tests/build_roles_rules.gd"
const Review=preload("res://redesign/run_balance.gd")

func current(rounds: Array,parts: Array,gun: String="single"):
	var m=build(rounds,parts,gun)
	m.s.balance_version=1;m.s.specialist_core_version=1
	return m

func run()->void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/balance_review_20261106/"):quit(2);return
	for gun in ["single","burst","scatter","heavy","amplifier"]:
		for changed in [false,true]:
			var m=build(["bore","basic_p2"],["inferno","coil"],gun)
			m.s.specialist_core_version=1
			if changed:m.s.balance_version=1
			m.s.engine.levels.thermal_drive=6
			targets(m,3,80,2)
			var expected: int=(4 if changed else 5) if gun!="amplifier" else (6 if changed else 7)
			# Inferno adds +2 to its inherited growth; the base gun contributes 2/4.
			expected+=2
			check(Content.burn_damage(m.s)==expected,"growth cadence and weapon base are versioned "+gun)
			var r:=shot(m)
			check(r.burn_tick==expected,"actual shot uses the displayed burn tick")
			check(r.fire_zones[0].damage==expected+(1 if changed else 2),"coil area bonus respects profile")
			check(r.fire_zones[0].left==(3 if changed else 4),"impact duration matches profile")
			check(m.s.fire_zones[0].left==(2 if changed else 3),"elapsed enemy action consumes one fire tick")
			restore_check(m)
			check(m.reload_magazine(),"real multi-turn reload resolves persistent fire")
			restore_check(m)
	for core in ["siege_drive","volley_drive","thermal_drive"]:
		var old=build(["precise_p2","basic_p2"],[core],"heavy")
		old.s.engine.levels[core]=6
		old.s.heat=Content.hot_threshold(old.s)
		var revised=Model.new();revised.s=Model.simulation_state(old.s);revised.s.balance_version=1
		check(shot(old).damage==shot(revised).damage,"direct core damage remains intact "+core)
	var area=current(["bore","basic_p2"],["inferno","coil"])
	area.s.engine.levels.thermal_drive=6
	check(Content.part_spec("inferno",area.s).text.contains("3적 행동") and Content.part_spec("inferno",area.s).text.contains("3회당"),"specialist tooltip states current duration and growth")
	check(Content.part_spec("coil",area.s).text.contains("피해 +1"),"coil tooltip reports the real bonus")
	check(Content.part_spec("thermal_drive",area.s).text.contains("성장 3회마다"),"thermal tooltip reports burn growth cadence")
	var description: String=preload("res://redesign/readability.gd").description("bore",area.s)
	check(description.contains("3적 행동") and description.contains("불길은 7피해"),"ammo detail reports the actual area duration and damage")
	for region in range(5):
		for rank in ["combat","elite","boss"]:
			var fixture_state: Dictionary={"balance_version":1,"enemies":[{"hp":20,"max_hp":20,"speed":1,"distance":40},{"hp":20,"speed":0,"distance":35}],"reinforcements":[{"hp":20,"speed":2,"distance":50}]}
			Review.approach(fixture_state,{"region":region,"kind":"boss" if rank=="boss" else "combat","elite":rank=="elite"})
			check(fixture_state.enemies[0].distance==(40 if region<2 or rank=="boss" else 36 if rank=="elite" else 33),"only later moving formations receive pressure")
			check(fixture_state.enemies[1].distance==35 and fixture_state.enemies[0].hp==20,"stationary clock and HP remain authored")
	var c=Campaign.new();c.start("heavy",17,0,"balanced",4,"carrier",true)
	check(c.s.balance_version==1 and c.model.s.balance_version==1,"fresh production start opts in")
	check(c.save("user://current.json")==OK,"new profile saves")
	var restored=Campaign.new();check(restored.restore("user://current.json"),"new profile restores atomically")
	var data: Dictionary=canonical({"campaign":c.s,"combat":c.model.s,"profile":c.profile})
	data.campaign.erase("balance_version")
	check(not restored.restore_state(data),"campaign/combat profile mismatch is rejected")
	data.combat.erase("balance_version")
	check(restored.restore_state(data) and not Review.enabled(restored.model.s),"old profile remains old after resume")
	for invalid in [-1,0.5,2,"1",true]:
		var copy: Dictionary=canonical(c.model.s);copy.balance_version=invalid
		check(not Model.new().restore_state(copy),"malformed profile is rejected")
	# Reusing the exact random forecast state across old/new profiles cannot return
	# a cached result from the other version, including post-shot area damage.
	var random=build(["bore","basic_p2"],["inferno","coil"],"scatter")
	random.s.specialist_core_version=1;random.s.engine.levels.thermal_drive=6;targets(random,3,80,2)
	Forecast.analyze(random.s)
	random.s.balance_version=1
	var cached: Dictionary=Forecast.analyze(random.s)
	Forecast.cached_key=""
	check(canonical(cached)==canonical(Forecast.analyze(random.s)),"random forecast cache separates balance profiles")
	FileAccess.open(output.path_join("rules.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("BALANCE REVIEW COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
