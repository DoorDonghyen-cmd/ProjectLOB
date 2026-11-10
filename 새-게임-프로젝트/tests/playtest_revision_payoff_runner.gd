extends "res://tests/ammo_expansion_rules_runner.gd"
const Payoff = preload("res://redesign/combat_payoff.gd")
const Engines = preload("res://redesign/damage_engines.gd")

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/playtest_revision_20261026/"): quit(2);return
	var rows: Array = []
	for revision in [0,1,2]:
		for recipe in [
			{"parts":["volley_drive","duplex","sequencer"],"order":["charge","precise_p3"],"kind":"volley","heat":0},
			{"parts":["siege_drive","afterburner","sequencer"],"order":["charge","pierce_p3"],"kind":"siege","heat":0},
			{"parts":["thermal_drive","sequencer","reclaimer"],"order":["charge_heat","pierce_p3"],"kind":"thermal","heat":7}]:
			var m=fixture(recipe.order,[["wall",140,5,1,30],["runner",30,0,2,34]],"burst")
			m.s.combat_revision=revision;m.s.equipped_parts=recipe.parts.duplicate();m.s.engine.levels[recipe.parts[0]]=8;m.s.heat=recipe.heat
			var results:=fire(m,recipe.order)
			var before:=JSON.stringify(m.s)
			var receipt:=Payoff.receipt(results)
			check(receipt.signature.kind==recipe.kind,"resolved build signature "+recipe.kind)
			check(receipt.damage==170-int(m.s.enemies[0].hp)-int(m.s.enemies[1].hp),"receipt matches actual HP removal")
			check(receipt==Payoff.last_receipt(m.s),"receipt persists after action")
			check(JSON.stringify(m.s)==before,"presentation reads are pure")
			var restored=Model.new()
			check(restored.restore_state(JSON.parse_string(before)),"receipt save restores")
			check(Payoff.last_receipt(restored.s)==receipt,"receipt survives load")
			check(m.reload_magazine() and Payoff.last_receipt(m.s).is_empty(),"reload clears preceding salvo")
			rows.append({"revision":revision,"kind":recipe.kind,"damage":receipt.damage,"parts":receipt.parts})
	var blocked=fixture(["pierce"],[["absorber",50,0,1,30]],"single")
	blocked.s.equipped_parts=["siege_drive"]
	var blocked_results:=fire(blocked,["pierce"])
	check(Payoff.receipt(blocked_results).signature.kind=="plain","blocked hit does not announce core payoff")
	check(Payoff.receipt(blocked_results).damage==0,"blocked damage is zero")
	check(Payoff.signature({"damage":0,"math":{"boost":6,"factor":2},"blocked_hits":1}).kind=="plain","blocked boost never claims powered hit")
	check(Payoff.signature({"part_effects":[{"id":"retired_unknown"}]}).parts.is_empty(),"unknown historical effect is safe to display")
	var support=fixture(["charge"])
	support.s.combat_revision=2;support.s.equipped_parts=["sequencer"]
	var support_receipt:=Payoff.receipt(fire(support,["charge"]))
	check(support_receipt.signature.kind=="boost" and support_receipt.damage==0 and support_receipt.detail.contains("공격"),"support announces grant instead of damage")
	var synthetic={"damage":4,"hp":0,"target":0,"secondary":[{"damage":2,"hp":0,"target":0},{"damage":3,"hp":0,"target":10000}]}
	check(Payoff.describe(synthetic).kills==1,"duplicate death and projectile never inflate kills")
	check(Payoff.receipt([synthetic,synthetic]).kills==1,"salvo unique defeated targets")
	var relay={"hits":1,"part_effects":[{"id":"duplex"}],"secondary":[{"kind":"relay"},{"kind":"relay"},{"kind":"arc"}]}
	check(Payoff.signature(relay).title.contains("3회"),"hit count includes real relays but excludes arc")
	for id in Engines.IDS:
		for revision in [0,2]:
			var rule:=Engines.growth_rule({"combat_revision":revision},id)
			check(rule.contains("2회 성장") if revision==2 and id=="volley_drive" else rule.contains("타격 +1") if id=="volley_drive" else rule.contains("0.15" if revision==2 else "0.25"),"reward rule follows saved growth version")
		for level in range(1,9):
			var state={"combat_revision":2,"engine":{"levels":{id:level},"gains":[id]}}
			var snapshot:=JSON.stringify(state)
			var text:=Engines.gain_summary(state,id)
			check(text.contains("축적") if id=="volley_drive" and level%2==1 else text.contains("→"),"growth accumulation versus real increase")
			check(JSON.stringify(state)==snapshot,"growth text leaves save unchanged")
	var latest={"history":[{"action":"fire","detail":{"results":[synthetic]}},{"action":"encounter","detail":{}}]}
	check(Payoff.last_receipt(latest).is_empty(),"new encounter does not show prior damage")
	FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("payoff.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows},"  "))
	print("PLAYTEST REVISION PAYOFF COMPLETE checks=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
