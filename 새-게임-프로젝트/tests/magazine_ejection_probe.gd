extends "res://tests/weapon_magazine_probe.gd"
const Solver=preload("res://tests/weapon_magazine_solver.gd")

func run() -> void:
	var out:=OS.get_environment("QA_OUTPUT_DIR")
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/magazine_ejection_20261031/"):quit(2);return
	# One previously unresolved checkpoint, fixed hidden targeting RNG. A winning
	# replay is feasibility evidence only, never a player-visible recommendation.
	var initial=weapon("scatter","boss",17)
	var selections: Array=[[],[0],[0,1]]
	for i in range(initial.s.magazine.size()):
		if i>0:selections.append([i])
	for i in range(initial.s.magazine.size()):
		for j in range(i+1,initial.s.magazine.size()):
			if i!=0 or j!=1:selections.append([i,j])
	var findings: Array=[]
	for selection in selections:
		var m=Model.new();m.s=Model.simulation_state(initial.s)
		if not selection.is_empty() and not m.eject_magazine_rounds(selection):push_error("Illegal probe selection");quit(1);return
		var removed: Array=selection.map(func(index):return initial.s.magazine[index])
		var path: Array=Solver.solve(m.s)
		for action in path:
			if not Solver.command(m,action):push_error("Probe replay failed");quit(1);return
		var won: bool=m.s.phase in ["won","reward"]
		findings.append({"selection":selection,"removed":removed,"path":path,"won":won,"turns":int(m.s.turns)-int(initial.s.turns)})
		if selection.size()>0 and selection!=[0] and selection!=[0,1] and won:break
	FileAccess.open(out.path_join("probe.json"),FileAccess.WRITE).store_string(JSON.stringify({"gun":"scatter","role":"boss","order_seed":17,"width":48,"depth":26,"rows":findings,"note":"Fixed hidden RNG and initial ejection only. Bounded search failure does not prove impossibility. Not human win rate or a UI recommendation."},"  "))
	print("EJECTION PROBE COMPLETE choices=%d wins=%d"%[findings.size(),findings.filter(func(row):return row.won).size()]);quit()
