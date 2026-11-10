extends "res://tests/playtest_rework_rules.gd"
func grown(version: int,level: int,rounds: Array=["bore","detonate","basic_p2"],parts: Array=["thermal_drive"],gun: String="heavy"):
	var m=modern(rounds,parts,gun)
	m.s.combat_roles_version=version;m.s.engine.levels.thermal_drive=level
	return m
func run()->void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/late_balance_20261103/"):quit(2);return
	for level in range(9):
		for version in [1,2]:
			var m=grown(version,level)
			var expected: int=2+(level/2 if version==2 else 0)
			check(Content.burn_damage(m.s)==expected,"earned two-level fire growth only in v2")
			var r:=shot(m)
			check(r.burn_tick==expected and r.fire_zones[0].damage==expected,"impact and ground fire expose real grown damage")
			check(m.s.history.back().detail.advance_events[0].damage==expected,"first attached/ground tick applied once")
			var before_hp: int=m.s.enemies[0].hp
			check(m.cool_magazine(),"one-action cooling remains a legal burn alternative")
			check(before_hp-int(m.s.enemies[0].hp)==expected,"cooling advances damage, does not double-stack")
			restore_check(m)
			var restored=Model.new();check(restored.restore_state(canonical(m.s)),"growing fire resumes")
			var remaining: int=m.s.enemies[0].burn
			var result:=shot(restored)
			check(result.detonation==remaining*expected,"detonation uses actual remaining grown burn")
			var original:=shot(m)
			check(canonical(original)==canonical(result) and canonical(m.s)==canonical(restored.s),"resume preserves next result/RNG/state")
	var coil=grown(2,8,["bore","basic_p2"],["thermal_drive","coil"])
	check(shot(coil).fire_zones[0].damage==8,"coil adds two to six-damage grown ground fire")
	var unsupported=grown(2,8,["bore","basic_p2"],["siege_drive"])
	check(Content.burn_damage(unsupported.s)==2,"unequipped thermal levels do not boost another core")
	for gun in ["single","burst","scatter","heavy","amplifier"]:
		var m=grown(2,8,["bore","basic_p2"],["thermal_drive"],gun)
		var r:=shot(m)
		check(r.burn_tick==(8 if gun=="amplifier" else 6),"grown fire preserves each weapon's base "+gun)
	var expanded=grown(2,8)
	expanded.s.gate_mods.growth=3;expanded.s.engine.levels.thermal_drive=14
	check(Content.burn_damage(expanded.s)==9,"three earned growth expansions keep the same two-level rate")
	restore_check(expanded)
	var heat=grown(2,8);var cold=grown(2,8)
	heat.s.heat=Content.hot_threshold(heat.s)
	check(Content.burn_damage(heat.s)==Content.burn_damage(cold.s),"burn does not multiply again with hot direct damage")
	for version in [1,2]:
		var m=grown(version,8,["basic_p2","vent"])
		m.s.heat=3
		var plain=grown(1,8,["basic_p2","vent"]);plain.s.heat=3
		m.s.fire_heat_trial.rounds=2;plain.s.fire_heat_trial.rounds=2
		var actual:=verify_fire(m);var reference:=verify_fire(plain)
		for shots in [actual.results,reference.results]:
			for result in shots:result.erase("burn_tick")
		check(canonical(actual)==canonical(reference),"direct vent/heat/overdrive mechanics unchanged (unused burn metadata excluded)")
	var c=Campaign.new();c.start("heavy",17,0,"balanced",4,"carrier",true)
	check(c.s.combat_roles_version==Roles.VERSION and c.model.s.combat_roles_version==Roles.VERSION,"fresh full climb uses current role version")
	check(c.restore_state(canonical({"campaign":c.s,"combat":c.model.s,"profile":c.profile})),"fresh v2 campaign restores")
	for version in [1,2]:
		var data: Dictionary=canonical({"campaign":c.s,"combat":c.model.s,"profile":c.profile})
		data.campaign.combat_roles_version=version;data.combat.combat_roles_version=version
		check(c.restore_state(data) and c.s.combat_roles_version==version,"historical version remains pinned")
	for invalid in [-1,1.5,Roles.VERSION+1,"2"]:
		var data: Dictionary=canonical({"campaign":c.s,"combat":c.model.s,"profile":c.profile})
		data.campaign.combat_roles_version=invalid;data.combat.combat_roles_version=invalid
		check(not c.restore_state(data),"invalid role version rejected atomically")
	check(Content.part_spec("thermal_drive",heat.s).text.contains("성장 2회마다"),"part description explains the growth")
	check(Model.Engines.growth_rule(heat.s,"thermal_drive").contains("화상 +1"),"core growth detail explains the fire increase")
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
	print("LATE BALANCE COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
