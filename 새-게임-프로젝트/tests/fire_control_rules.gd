extends "res://tests/fire_heat_rules.gd"
const Campaign=preload("res://redesign/campaign.gd")
func finish()->void:
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"  "))
	print("FIRE CONTROL COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
func data(c)->Dictionary:return canonical({"campaign":c.s,"combat":c.model.s,"profile":c.profile})
func run()->void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/fire_control_20261102/"):quit(2);return
	for gun in ["single","burst","scatter","heavy","amplifier"]:
		var c=Campaign.new();c.start(gun,17,0,"balanced",3,"carrier",true)
		check(c.s.fire_control_version==1 and Trial.range_enabled(c.model.s),"fresh full campaign enables prefix firing")
		check(c.save("user://new.json")==OK,"map saves")
		var loaded=Campaign.new();check(loaded.restore("user://new.json"),"new map restores")
		check(c.enter(101),"enter real first fight")
		c.model.s.fire_heat_trial.rounds=1;verify_fire(c.model)
		var heat: int=c.model.s.heat;var streak:=Content.Sustained.count(c.model.s)
		check(c.model.reload_magazine(),"actual campaign replacement succeeds")
		check(c.model.s.heat==heat and Content.Sustained.count(c.model.s)==streak,"replacement keeps heat and sustained count")
		c.sync_combat();c.save("user://new.json")
		check(loaded.restore("user://new.json") and data(loaded)==data(c),"mid-combat exact campaign save resumes prefix and RNG")
		var stable:=data(loaded)
		for invalid in [0.5,2,"1"]:
			var corrupt:=data(c);corrupt.campaign.fire_control_version=invalid
			check(not loaded.restore_state(corrupt) and data(loaded)==stable,"malformed campaign rule version rejected without mutation")
		for key in ["reload","damage","input"]:
			var corrupt:=data(c);corrupt.combat.fire_heat_trial[key]={"reload":"legacy","damage":true,"input":"fixed"}[key]
			check(not loaded.restore_state(corrupt) and data(loaded)==stable,"campaign cannot silently opt into experimental rules")
		# Exact old-magazine saved games retain old behavior, even after a new encounter.
		var old_path:=ProjectSettings.globalize_path("res://../qa_runtime/campaign_magazine_20261101/v3_%s/rules/combat_%s_731042_r1_n401.json"%[gun,gun])
		var old: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(old_path))
		check(loaded.restore_state(old),"historical magazine campaign restores")
		check(not Trial.enabled(loaded.model.s),"historical campaign never migrated")
		loaded.model.fire();var initial: int=loaded.model.s.heat
		var expected:=Content.heat_after_reload(loaded.model.s)
		if loaded.model.s.phase=="ready":
			loaded.model.reload_magazine()
			check(loaded.model.s.phase!="ready" or loaded.model.s.heat==expected,"historical reload still uses weapon cooling")
		check(not loaded.s.has("fire_control_version"),"legacy campaign metadata remains absent")
		# Controlled equipment contracts, not claimed as earned acquisitions.
		for part in ["none","cooling_breech","thermal_drive","radiator","chain_sink","compression_sink"]:
			var state: Dictionary=old.combat.duplicate(true)
			state.equipped_parts=[] if part=="none" else [part];state.part="none"
			Trial.activate_campaign(state)
			state.heat=8;state.sustained_attacks=3
			check(Content.heat_after_reload(state)==(4 if part=="cooling_breech" else 8),"only explicit equipment reload cooling is retained")
			var m=Model.new();m.s=state;m.s.fire_heat_trial.rounds=1
			var before: Array=m.s.magazine.duplicate()
			check(m.cool_magazine(),"dedicated cooling with equipped part")
			check(m.s.magazine==before and Content.Sustained.count(m.s)==0,"cooling preserves rounds and resets streak with parts")
			if m.s.phase=="ready":
				check(m.s.heat==0,"dedicated production cooling fully vents heat")
		print("RULES ",gun)
	finish()
