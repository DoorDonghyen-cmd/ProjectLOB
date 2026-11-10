extends SceneTree
const Campaign = preload("res://redesign/campaign.gd")
const Model = preload("res://redesign/model.gd")
const HistoryJSON = preload("res://redesign/history_json.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + label)

func same_json(a: Variant, b: Variant) -> bool:
	return JSON.parse_string(JSON.stringify(a)) == JSON.parse_string(JSON.stringify(b))

func save_campaign(run: RefCounted, label: String) -> void:
	check(run.save("user://roundtrip.json") == OK, "atomic save " + label)
	var disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://roundtrip.json"))
	check(same_json(disk, {"campaign":run.s,"combat":run.model.s,"profile":run.profile}), "every field equals ordinary JSON " + label)
	var restored := Campaign.new()
	check(restored.restore("user://roundtrip.json"), "restore " + label)
	check(same_json(restored.model.s, run.model.s), "restored combat " + label)
	check(same_json(restored.s, run.s), "restored campaign " + label)

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/playtest_revision_20261026/mobile_save/"):
		quit(2); return
	var cache := HistoryJSON.new()
	var state := {"history": [{"detail":{"text":"한글 · \"quoted\" \\ path\nline", "values":[1, 2.5, null, true]}}], "rng_state":"9223372036854775807"}
	for step in 7:
		match step:
			1: state.history[0].detail.values[0] = 99
			2: state.history.append({"detail":{"result":"append"}})
			3: state.history[0] = {"detail":{"result":"same length replacement"}}
			4: state.history.resize(1)
			5: state.history.clear()
			6: state = {"history":[{"detail":{"result":"new run"}}]}
		for repeat in 2:
			check(same_json(JSON.parse_string(cache.stringify(state)), state), "no stale history or escaping " + str(step))
	for gun in ["burst", "scatter"]:
		var path := ProjectSettings.globalize_path("res://../qa_runtime/central_live/balance/final_731042/combat_%s_731042_r5_n41002.json" % gun)
		var record: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
		var campaign := Campaign.new()
		check(campaign.restore_state(record), "late campaign fixture " + gun)
		save_campaign(campaign, gun + " late")
		save_campaign(campaign, gun + " unchanged")
		# Nested edits in an old entry must never be hidden by cached JSON.
		campaign.model.s.history[0].detail["qa_note"] = ["nested", {"value":42}]
		save_campaign(campaign, gun + " edited old entry")
		for i in 3:
			var loaded := false
			for id in campaign.model.s.hand:
				if campaign.model.load_round(id):
					loaded = true
					break
			check(loaded, "real hand insertion")
			save_campaign(campaign, gun + " load " + str(i))
		check(campaign.model.confirm(), "confirm real magazine")
		check(campaign.model.fire(), "real shot appends history")
		save_campaign(campaign, gun + " fired")
		check(campaign.restore_state(record), "rewind shorter original state")
		save_campaign(campaign, gun + " rewind")
		check(campaign.save("user://missing_directory/save.json") != OK, "failed write reports error")
		save_campaign(campaign, gun + " after failed write")
		campaign.start(gun, 82519)
		save_campaign(campaign, gun + " new run")
	var training := Model.new()
	training.start("single", 17, true)
	check(training.save_run("user://training.json") == OK, "training saves")
	var restored_training := Model.new()
	check(restored_training.restore_run("user://training.json"), "training restores")
	check(same_json(training.s, restored_training.s), "training full state")
	print("PLAYTEST REVISION MOBILE SAVE COMPLETE checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
