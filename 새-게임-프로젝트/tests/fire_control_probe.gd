extends SceneTree
const Model=preload("res://redesign/model.gd")
const Solver=preload("res://tests/fire_control_solver.gd")
var rows: Array=[]
func _initialize()->void:run.call_deferred()
func run()->void:
	var output:=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/fire_control_20261102/"):quit(2);return
	for entry in [["scatter","climb_bursts/combat_scatter_731042_r2_n10301.json"],["amplifier","climb_heavy_amp/combat_amplifier_731042_r5_n41002.json"]]:
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../qa_runtime/fire_control_20261102/")+entry[1]))
		var m=Model.new();m.restore_state(data.combat)
		var solver=Solver.new()
		var path:=solver.ranged(m.s,384,100,true)
		for step in path:
			match step.action:
				"fire":m.s.fire_heat_trial.rounds=step.rounds;m.fire()
				"reload":m.reload_magazine()
				"cool":m.cool_magazine()
				"emergency":m.emergency_resupply()
				"eject":m.eject_magazine_rounds(step.indices)
		rows.append({"gun":entry[0],"path":path,"phase":m.s.phase,"turns":m.s.turns-data.combat.turns,"start":data.combat})
		FileAccess.open(output.path_join("probe.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
		print("PROBE ",entry[0]," path=",path.size()," phase=",m.s.phase)
		await process_frame
	print("FIRE CONTROL COMPLETE checks=0 failures=0");quit()
