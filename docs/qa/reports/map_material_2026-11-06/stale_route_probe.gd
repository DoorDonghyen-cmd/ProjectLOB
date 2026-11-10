extends "res://tests/campaign_magazine_rules.gd"
## Diagnostic only: replays the old record without loading any map UI.
func _run() -> void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").ends_with("/qa_runtime/map_ui_20261106"):quit(2);return
	var source:=ProjectSettings.globalize_path("res://../qa_runtime/campaign_magazine_20261101/integrated/rules/balance.json")
	var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(source))
	var route:Array=[]
	for endpoint in report.endpoints:
		if endpoint.gun=="single" and endpoint.won:route=endpoint.commands;break
	var c=Campaign.new();c.start("single",731042,0,"balanced",3,"carrier",true);c.advance_departure(true)
	for index in range(route.size()):
		if not command(c,route[index].duplicate(true)):
			FileAccess.open(output.path_join("stale_route.json"),FileAccess.WRITE).store_string(JSON.stringify({"scope":"No UI scenes instantiated. Diagnostic of outdated recorded route; not a passing integration test.","rejected_index":index,"rejected":route[index],"phase":c.s.phase,"failures":failures},"  "))
			print("STALE ROUTE REPRODUCED WITHOUT UI ",index," ",route[index].action," ",route[index].get("id",""));quit();return
	push_error("Old route did not reproduce the expected stale record rejection");quit(1)
