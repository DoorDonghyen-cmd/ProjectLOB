extends SceneTree
## Real earned campaign snapshots, same public load commands before/after changes.
const Model = preload("res://redesign/model.gd")
const Forecast = preload("res://redesign/forecast.gd")
const Content = preload("res://redesign/content.gd")
var failures := 0
var rows: Array = []
var references: Dictionary = {}
var output := ""
var tag := ""

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	if not ok: failures += 1; print("FAIL: " + label)

func sample(operation: Callable, count: int = 9) -> Dictionary:
	var times: Array = []
	operation.call()
	for i in count:
		var start := Time.get_ticks_usec()
		operation.call()
		times.append(float(Time.get_ticks_usec() - start) / 1000.0)
	times.sort()
	return {"median_ms": times[count / 2], "max_ms": times.back()}

func verify(label: String, value: Dictionary) -> void:
	if tag != "baseline":
		check(references.has(label), "baseline exists: " + label)
		if references.has(label): check(JSON.parse_string(JSON.stringify(value)) == references[label], "unchanged prediction: " + label)
	else: references[label] = value

func measure(state: Dictionary, label: String) -> void:
	var model = Model.new()
	model.s = state
	var saved := JSON.stringify(state)
	var row := {"label":label,"history_events":state.history.size(),"state_bytes":saved.length()}
	row.legacy_full_copy = sample(func(): return state.duplicate(true))
	row.legacy_request_key = sample(func(): return JSON.stringify(state))
	row.snapshot = sample(func(): return Model.simulation_state(state))
	row.request_key = sample(func(): return JSON.stringify(Model.simulation_state(state)))
	row.preview = sample(func(): return model.preview())
	row.reload = sample(func(): return Forecast.reload_now(state,true))
	row.forecast = sample(func(): return Forecast.analyze(state,true,true),3)
	verify(label,{"preview":model.preview(),"forecast":Forecast.analyze(state,true,true),"reload":Forecast.reload_now(state,true)})
	check(saved == JSON.stringify(state), "profiling leaves live state and history unchanged: " + label)
	rows.append(row)
	print(JSON.stringify(row))

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/playtest_revision_20261026/"): quit(2); return
	output = OS.get_environment("QA_OUTPUT_DIR")
	tag = OS.get_environment("QA_REVISION_TAG")
	var base := ProjectSettings.globalize_path("res://../qa_runtime/central_live/balance/final_731042/")
	var reference_path := ProjectSettings.globalize_path("res://../qa_runtime/playtest_revision_20261026/performance/baseline/reference.json")
	if tag != "baseline" and FileAccess.file_exists(reference_path): references = JSON.parse_string(FileAccess.get_file_as_string(reference_path))
	var files := DirAccess.get_files_at(base)
	files.sort()
	for gun in Content.GUNS:
		var matching: Array = []
		for name in files:
			if name.begins_with("combat_"+gun+"_") and name.ends_with(".json"): matching.append(name)
		check(matching.size()>1,"recorded early and late campaign: "+gun)
		if matching.size()<2:continue
		for selected in [matching.front(),matching.back()]:
			var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base.path_join(selected)))
			var model = Model.new()
			check(model.restore_state(record.combat),"current snapshot restores "+selected)
			var loaded := 0
			for id in model.s.hand.duplicate():
				if model.load_round(str(id)): loaded += 1
				if loaded >= 3: break
			check(loaded>0,"legal test load "+selected)
			measure(model.s,selected.trim_suffix(".json")+"_plan")
			if gun == "amplifier":
				check(model.confirm() and model.fire(),"real partial single shot")
				measure(model.s,selected.trim_suffix(".json")+"_after_fire")
	FileAccess.open(output.path_join("performance.json"),FileAccess.WRITE).store_string(JSON.stringify({"rows":rows,"failures":failures,"scope":"CPU operation timing on recorded campaign states; not GPU or device FPS."},"  "))
	if tag == "baseline":FileAccess.open(output.path_join("reference.json"),FileAccess.WRITE).store_string(JSON.stringify(references))
	print("PLAYTEST REVISION PERFORMANCE COMPLETE failures=%d" % failures)
	quit(1 if failures else 0)
