extends "res://tests/foundry_campaign_runner.gd"
const Gates = preload("res://redesign/gate_upgrades.gd")
var chosen := "thermal"
var activations: Dictionary = {}

func command(c, item: Dictionary) -> bool:
	var step := item.duplicate(true)
	if step.action=="reward" and c.boss_loot() and str(step.id)=="credits":
		step.id=c.reward_options()[0]
		step.replace=replacement(c,step.id)
	if step.action=="gate":
		step.id=chosen if int(c.s.region)==0 else "thermal"
		if step.id=="production":
			var specimen: String=Gates.specimens(c.model.s.deck)[0]
			var originals:=Gates.basics(c.model.s.deck).slice(0,3)
			if not check(c.gate("production",specimen,originals),"earned production transaction"):return false
			step.ammo=specimen;step.sources=originals;commands.append(step)
			if not roundtrip(c): return false
			return command(c,{"action":"gate_depart"})
		if OS.get_environment("QA_GATE_IMMEDIATE_BASELINE")=="1":
			# Former gate() applied its reward and advanced before saving once.
			if not check(c.gate(str(step.id)),"immediate comparison upgrade"): return false
			c._advance_region()
			commands.append(step)
			return roundtrip(c)
	if step.action=="gate_depart":
		if not check(c.depart_gate(),"explicit gate departure"): return false
		commands.append(step)
		return roundtrip(c)
	var charged:=int(c.model.s.get("gate_charge",0))
	var chain:=Gates.chain_percent(c.model.s)
	var accepted:=super.command(c,step)
	if accepted and step.action=="gate" and c.gate_ready():
		return command(c,{"action":"gate_depart"})
	if accepted and step.action=="fire" and int(c.s.region)==1:
		if charged>0 and int(c.model.s.get("gate_charge",0))==0:activations["charge_spent"]+=1
		if chain>100:activations["chain_actions"]+=1
	return accepted

func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/gate/"):quit(1);return
	output=OS.get_environment("QA_OUTPUT_DIR")
	test_map_version=3;solver.candidate_limit=700
	for row in [["heavy","thermal_drive","thermal"],["burst","volley_drive","chain"],["amplifier","siege_drive","production"]]:
		var gun: String=row[0]
		if OS.get_environment("QA_GATE_IMMEDIATE_BASELINE")=="1" and gun!="heavy": continue
		preferred_core=row[1];chosen=row[2]
		activations={"charge_spent":0,"chain_actions":0}
		print("GATE CAMPAIGN START ",gun," upgrade=",chosen)
		await first_region(gun,731042,"safe")
		if reports.back().phase!="gate":continue
		var c=Campaign.new()
		if not check(c.restore("user://city_probe.json"),"earned first gate restores"):continue
		if not command(c,{"action":"gate","id":chosen}):continue
		snapshot(c,"entry_"+gun)
		await second_region(c,gun,731042)
		endpoints.back().gate_choice=chosen
		endpoints.back().activations=activations.duplicate()
		print("GATE EFFECTS ",gun," ",activations)
		var file=FileAccess.open(output.path_join("campaign.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"battles":battles,"runs":endpoints,"first_regions":reports},"  "));file.close()
	print("GATE CAMPAIGN COMPLETE checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
