extends "res://tests/reserve_balance_runner.gd"
func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/art_cohesion/"):quit(1);return
	var solver=Solver.new();solver.candidate_limit=1000
	var model=finite_case("boss","heavy","thermal_drive",731042)
	var started:=Time.get_ticks_msec()
	var path:Array=solver.solve(model,16,20)
	for command in path:
		var accepted:=false
		match str(command.action):
			"load":accepted=model.load_round(str(command.id))
			"confirm":accepted=model.confirm()
			"fire":accepted=model.fire()
			"reload":accepted=model.reload_magazine()
		check(accepted,"wider path replays legally")
	var result:Dictionary={"solved":not path.is_empty() and model.s.phase in ["won","reward"],"path":path,"turns":model.s.turns,"used":model.s.discard.size(),"remaining":model.s.deck.size()-model.s.discard.size(),"elapsed_ms":Time.get_ticks_msec()-started,"candidate_limit":1000,"width":16,"depth":20}
	var file=FileAccess.open(OS.get_environment("QA_OUTPUT_DIR").path_join("reactor_reachability.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"  "));file.close()
	print("REACTOR REACHABILITY ",result.solved," checks=",checks," failures=",failures," turns=",result.turns," used=",result.used)
	quit(0 if failures==0 else 1)
