extends SceneTree

const Probe := preload("res://tests/ammo_v6_tuning_probe.gd")
const OUTPUT_PATH := "res://tests/baseline/ammo_v6_tuning_matrix.json"


func _initialize() -> void:
	var report := Probe.generate_report()
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("v6 tuning report written: %s" % OUTPUT_PATH)
	print("ordinary failures: %d" % report.ordinary_failures.size())
	print("control-required matchups: %d" % report.control_required.size())
	print("signature failures: %d" % report.signature_failures.size())
	print("starting-deck failures: %d" % report.starting_deck_failures.size())
	quit(0)
