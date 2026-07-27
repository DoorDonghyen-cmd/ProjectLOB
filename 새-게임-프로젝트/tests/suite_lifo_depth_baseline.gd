extends RefCounted
## v5 LIFO 역사 기준선 보존 검사.
## v6 전환 후에는 삭제된 v5 리소스로 현재 결과를 재생성하지 않는다.
## 이 파일은 개편 전 비교 자료가 손상되지 않았는지만 검증한다.

const BASELINE_PATH := "res://tests/baseline/lifo_depth_v5.json"


static func run(t) -> void:
	t.section("LIFODepthBaseline")
	t.check(FileAccess.file_exists(BASELINE_PATH), "v5 LIFO 역사 기준 JSON 존재")
	if not FileAccess.file_exists(BASELINE_PATH):
		return
	var file := FileAccess.open(BASELINE_PATH, FileAccess.READ)
	var value = JSON.parse_string(file.get_as_text())
	file.close()
	t.check(value is Dictionary, "v5 LIFO 역사 기준 JSON 파싱")
	if not value is Dictionary:
		return
	var baseline: Dictionary = value
	t.eq(str(baseline.schema), "lob.lifo_depth_baseline", "역사 기준선 스키마")
	t.eq(int(baseline.version), 1, "역사 기준선 버전")
	t.eq(int(baseline.effective_capacity), 7,
		"수정 전 Tempo 7발 결함 상태를 역사적으로 보존")
	t.eq(int(baseline.permutation_count), 360, "v5 6탄 멀티셋 고유 순열 360개")
	t.check(bool(baseline.enemy_specific_optima), "v5에서도 적별 최적 순서가 달랐음")
	t.check((baseline.enemies as Array).size() >= 3, "적별 비교 결과 보존")
