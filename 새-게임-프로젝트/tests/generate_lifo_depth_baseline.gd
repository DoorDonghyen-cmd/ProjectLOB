extends SceneTree
## 실행:
##   godot --headless --path <project> --script res://tests/generate_lifo_depth_baseline.gd

const Probe := preload("res://tests/lifo_depth_probe.gd")
const OUTPUT_PATH := "res://tests/baseline/lifo_depth_v5.json"


func _initialize() -> void:
	var report := Probe.generate_report()
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		printerr("LIFO baseline: 파일을 열 수 없습니다: %s" % OUTPUT_PATH)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("LIFO baseline 저장: %s" % ProjectSettings.globalize_path(OUTPUT_PATH))
	print("  고유 순열: %d" % int(report.permutation_count))
	print("  적별 최적 순서 수: %d" % int(report.distinct_best_orders))
	quit(0)
