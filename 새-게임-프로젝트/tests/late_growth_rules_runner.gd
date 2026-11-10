extends "res://tests/heat_rules_runner.gd"
const Growth = preload("res://redesign/core_growth.gd")
const Engines = preload("res://redesign/damage_engines.gd")
const Gates = preload("res://redesign/gate_upgrades.gd")
var evidence: Array = []

func earned_gate(region: int):
	var c=Campaign.new()
	check(c.restore(ProjectSettings.globalize_path("res://../qa_runtime/economy_20261029/b1_single_burst_carrier/gate_single_731042_r%d.json" % region)),"earned gate restores")
	return c

func rejection(source: Dictionary, label: String) -> void:
	var holder=Campaign.new();holder.start("single",17)
	var before := JSON.stringify(holder.s)+JSON.stringify(holder.model.s)
	check(not holder.restore_state(source) and before==JSON.stringify(holder.s)+JSON.stringify(holder.model.s),"atomic campaign rejection: "+label)

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/late_growth_20261030/"):quit(2);return
	var started=Campaign.new();started.start("single",731042)
	check(started.s.growth_version==1 and started.model.s.growth_version==1 and Growth.limit(started.model.s)==8,"new runs keep early cap and opt into late choice")
	for region in [1,2,3,4]:
		var legacy=earned_gate(region)
		var old: Dictionary=legacy.model.s.duplicate(true)
		check(not legacy.gate_options().has("growth") and not legacy.gate("growth"),"existing saves never gain new option")
		check(legacy.model.s==old and not legacy.model.s.has("growth_version"),"legacy state is preserved")
		legacy.s.growth_version=1;legacy.model.s.growth_version=1
		check(legacy.gate_options().has("growth")== (region>=2),"late option starts after second boss")
		if region==1:continue
		var before: Dictionary=legacy.model.s.engine.duplicate(true)
		var parts: Array=legacy.s.parts.duplicate();var deck: Array=legacy.model.s.deck.duplicate()
		check(legacy.gate("growth") and Growth.limit(legacy.model.s)==10,"first expansion uses a real gate choice")
		check(legacy.model.s.engine==before and legacy.model.s.deck==deck and legacy.s.parts==parts,"expansion grants no immediate level ammo or part")
		check(not legacy.gate("thermal") and not legacy.gate("growth"),"choice cannot duplicate or claim another reward")
		check(legacy.save("user://expanded.json")==OK,"expansion saves")
		var restored=Campaign.new();check(restored.restore("user://expanded.json") and restored.gate_ready(),"expansion resumes at reorganization")
		check(restored.depart_gate() and not restored.depart_gate(),"explicit departure once")
	var valid: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("user://expanded.json"))
	for marker in [-1,2,0.5,"1",true]:
		var broken: Dictionary=valid.duplicate(true);broken.campaign.growth_version=marker
		rejection(broken,"marker "+str(marker))
	var broken: Dictionary=valid.duplicate(true);broken.combat.erase("growth_version");rejection(broken,"mixed rules")
	broken=valid.duplicate(true);broken.combat.gate_mods.growth=4;rejection(broken,"too many expansions")
	broken=valid.duplicate(true);broken.combat.gate_mods="invalid";rejection(broken,"malformed modifiers")
	broken=valid.duplicate(true);broken.combat.engine.levels.siege_drive=11;rejection(broken,"level exceeds purchased cap")
	var early=earned_gate(1);early.s.growth_version=1;early.model.s.growth_version=1;early.model.s.gate_mods.growth=1
	check(early.save("user://too_early.json")==OK,"invalid fixture serializes")
	rejection(JSON.parse_string(FileAccess.get_file_as_string("user://too_early.json")),"expansion before second boss")
	for core in Engines.IDS:
		for upgrades in range(4):
			var cap := 8+2*upgrades
			var s := {"growth_version":1,"combat_revision":2,"gate_mods":{} if upgrades==0 else {"growth":upgrades},"phase":"reward","engine":Engines.fresh()}
			s.engine.levels[core]=cap-1;s.engine.hits=3;s.engine.hot=true;s.engine.siege=true
			Engines.settle(s,[core]);check(Engines.level(s,core)==cap and s.engine.gains==[core],"win earns exactly one additional level")
			var earned: Dictionary=s.duplicate(true);Engines.settle(s,[core]);check(s==earned,"settlement idempotent")
			check(Engines.valid(s.engine,Growth.limit(s)),"extended engine save validation")
			Engines.begin(s);s.engine.hits=3;s.engine.hot=true;s.engine.siege=true
			Engines.settle(s,[core]);check(Engines.level(s,core)==cap and s.engine.gains.is_empty(),"purchased limit cannot be exceeded")
			Engines.begin(s);s.engine.levels[core]=cap-1;s.phase="lost";s.engine.hits=3;s.engine.hot=true;s.engine.siege=true
			Engines.settle(s,[core]);check(Engines.level(s,core)==cap-1,"defeat never grows")
		for level in [8,9,10,12,14]:
			for gun in Ammo.GUNS:
				var m=fixture(["pierce","precise"],[["wall",200,2,1,30]],gun)
				m.s.combat_revision=2;m.s.sustained_version=1;m.s.sustained_attacks=0
				m.s.growth_version=1;m.s.gate_mods={"growth":3};Gates.begin(m.s)
				m.s.equipped_parts=[core];m.s.engine.levels[core]=level
				if core=="thermal_drive":m.s.heat=ceili(Ammo.heat_limit(m.s)/2.0)
				var shots := fire(m,["pierce"])
				evidence.append({"core":core,"gun":gun,"level":level,"value":Engines.value(m.s,core),"damage":shots[0].damage})
	# Growth without an earned condition, or with an unequipped core, stays unchanged.
	for parts in [[],["siege_drive"]]:
		var s := {"growth_version":1,"gate_mods":{"growth":1},"phase":"reward","engine":Engines.fresh()}
		s.engine.levels.siege_drive=8;Engines.settle(s,parts)
		check(Engines.level(s,"siege_drive")==8,"no growth without condition and equipped core")
	# Earlier saves retain their original maximum even with a high requested level.
	var old=fixture(["pierce"]);old.s.engine.levels.siege_drive=9
	check(not Model.new().restore_state(old.s),"unmarked save rejects levels above eight")
	FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("rules.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"damage":evidence},"  "))
	print("LATE GROWTH RULES COMPLETE checks=%d failures=%d" % [checks,failures]);quit(1 if failures else 0)
