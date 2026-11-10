extends SceneTree
const Model=preload("res://redesign/model.gd")
const Content=preload("res://redesign/content.gd")
const Forecast=preload("res://redesign/forecast.gd")
const Trial=preload("res://redesign/fire_heat_trial.gd")
var checks:=0
var failures: Array=[]
var records: Array=[]
var output: String
var openings: Array=[]
func _initialize()->void:run.call_deferred()
func check(ok: bool,label: String)->void:
	checks+=1
	if not ok:failures.append(label);print("FAIL: "+label)
func canonical(value):return JSON.parse_string(JSON.stringify(value))
func model(state: Dictionary,mode: String="none",damage: bool=false,input: String="range"):
	var m=Model.new();check(m.restore_state(state),"earned input restores")
	m.s.fire_heat_trial={"version":1,"input":input,"reload":mode,"damage":damage,"rounds":0}
	return m
func restore_check(m)->void:
	var other=Model.new()
	check(other.restore_state(canonical(m.s)),"trial state round-trips through JSON")
	check(canonical(other.s)==canonical(m.s),"restore preserves full rules, order and RNG")
func verify_fire(m)->Dictionary:
	var before:=JSON.stringify(m.s)
	var prediction:=Forecast.analyze(m.s,true)
	check(JSON.stringify(m.s)==before,"forecast does not consume state or RNG")
	check(m.fire(),"actual prefix command fires")
	var detail: Dictionary=m.s.history.back().detail
	var shots: Array=detail.results
	check(not shots.is_empty(),"accepted fire spends at least one card")
	check(shots.size()<=Trial.budget(m.s) or Trial.budget(m.s)==0,"cannot exceed selected prefix, including overdrive")
	if m.s.gun!="scatter":
		check(canonical(prediction.enemies)==canonical(m.s.enemies),"deterministic predicted enemy state matches real command")
		check(canonical(prediction.projectiles)==canonical(m.s.projectiles),"predicted projectile state matches")
		check(prediction.heat.end_min==m.s.heat,"predicted final heat matches")
	else:
		check(shots.size()<=prediction.shots.size(),"scatter only consumes predicted prefix")
		for i in range(shots.size()):
			check(shots[i].damage>=prediction.shots[i].damage_min and shots[i].damage<=prediction.shots[i].damage_max,"scatter damage stays in exact public range")
		records.append({"gun":m.s.gun,"limit":Trial.budget(m.s),"forecast_shots":prediction.shots.size(),"actual_shots":shots.size()})
	restore_check(m)
	return detail
func finish()->void:
	FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"records":records},"  "))
	print("FIRE HEAT COMPLETE checks=%d failures=%d"%[checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
func setup()->bool:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/fire_heat_20261102/"):quit(2);return false
	output=OS.get_environment("QA_OUTPUT_DIR")
	openings=JSON.parse_string(FileAccess.get_file_as_string("res://redesign/samples/fire_heat/openings.json"))
	return true
func run()->void:
	if not setup():return
	var old_script:=GDScript.new()
	old_script.source_code=FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../qa_runtime/fire_heat_20261102/baseline/새-게임-프로젝트/redesign/model.gd"))
	check(old_script.reload()==OK,"pre-change model loads for exact regression")
	for row in openings:
		# Existing run/save behavior is compared to the actual pre-change resolver.
		var legacy=old_script.new();var current=Model.new()
		check(legacy.restore_state(row.state) and current.restore_state(row.state),"legacy opening restores in both versions")
		for method in ["fire","cool_magazine","reload_magazine","fire"]:
			check(legacy.call(method)==current.call(method),"legacy acceptance unchanged")
			check(canonical(legacy.s)==canonical(current.s),"legacy entire state remains identical")
		# Same earned snapshot, explicit prefix limits and opt-in heat modes.
		for mode in Trial.RELOADS:
			for penalty in [false,true]:
				for budget in range(1,5 if row.gun=="heavy" else mini(4,row.state.magazine.size()+1)):
					var m=model(row.state,mode,penalty);m.s.fire_heat_trial.rounds=budget
					var before: Array=m.s.magazine.duplicate()
					var detail:=verify_fire(m)
					check(detail.results.map(func(r):return r.id)==before.slice(0,detail.results.size()),"only contiguous front cards consumed")
					if m.s.phase!="ready" or m.s.heat<=0:continue
					var initial_heat: int=m.s.heat
					var streak: int=Content.Sustained.count(m.s)
					var cooled=model(m.s,mode,penalty)
					check(cooled.cool_magazine(),"dedicated cooling legal")
					check(cooled.s.magazine==m.s.magazine,"cooling keeps exact magazine order")
					check(Content.Sustained.count(cooled.s)==0,"dedicated cooling resets sustained heat")
					if (m.s.hand+m.s.draw).is_empty():continue
					check(m.reload_magazine(),"comparison reload legal")
					if m.s.phase=="ready" and mode!="legacy":
						check(m.s.heat==maxi(0,initial_heat-(2 if mode=="small" else 0)),"unmodified weapon replacement keeps heat or only removes two")
						check(Content.Sustained.count(m.s)==streak,"replacement does not erase sustained fire")
						restore_check(m)
		# Invalid experimental saves must fail without modifying the receiving model.
		for invalid in [{"version":2,"input":"range","reload":"none","damage":false,"rounds":1},{"version":1,"input":"range","reload":"none","damage":false,"rounds":1.5},{"version":1,"input":"range","reload":"none","damage":"yes","rounds":1}]:
			var m=Model.new();m.restore_state(row.state);var before: Dictionary=canonical(m.s)
			var bad: Dictionary=row.state.duplicate(true);bad.fire_heat_trial=invalid
			check(not m.restore_state(bad) and canonical(m.s)==before,"malformed trial save rejected atomically")
		print("RULES ",row.gun," ",row.node)
	# Explicit boundary fixtures verify arithmetic; these are not claimed as earned runs.
	for row in openings:
		for offset in [-1,0]:
			var m=model(row.state,"none",true)
			m.s.heat=Trial.threshold(Content.heat_limit(m.s))+offset
			m.s.fire_heat_trial.rounds=1
			var detail:=verify_fire(m)
			check(detail.results[0].math.heat_percent==(100 if offset<0 else 80),"75% heat boundary uses heat before the shot")
		# A legal first shot followed by waiting through reloads must still save a loss.
		var terminal=model(row.state)
		terminal.s.fire_heat_trial.rounds=1
		terminal.fire()
		for step in range(24):
			if terminal.s.phase!="ready":break
			if not terminal.reload_magazine():break
		if terminal.s.phase=="lost":
			check(Content.Sustained.count(terminal.s)==0,"reload death clears terminal sustained counter")
			restore_check(terminal)
	# Cooling-breech equipment is a component fixture, independent of earned inventory.
	var part_state: Dictionary=openings[0].state.duplicate(true)
	part_state.equipped_parts=["cooling_breech"];part_state.part="none";part_state.heat=8
	for mode in ["none","small"]:
		part_state.fire_heat_trial={"version":1,"input":"range","reload":mode,"damage":false,"rounds":1}
		check(Content.heat_after_reload(part_state)==(4 if mode=="none" else 2),"cooling-breech +4 remains active in both replacement trials")
	finish()
