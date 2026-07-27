extends SceneTree

const Probe := preload("res://tests/ammo_v6_preflight_probe.gd")
const OUTPUT_PATH := "res://tests/baseline/ammo_v6_preflight_matrix.json"


func _initialize() -> void:
	var report := Probe.generate_report()
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		printerr("v6 preflight: 파일을 열 수 없습니다: %s" % OUTPUT_PATH)
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t") + "\n")
	file.close()
	print("v6 preflight 저장: %s" % ProjectSettings.globalize_path(OUTPUT_PATH))
	for gun in report.guns:
		print("  %s: %.2f DMG/턴, 기본탄 직통 %d/%d" % [
			str(gun.gun_id), float(gun.cycle_dpt),
			int(gun.direct_effective_enemies), int(gun.enemy_count)])
	quit(0)
