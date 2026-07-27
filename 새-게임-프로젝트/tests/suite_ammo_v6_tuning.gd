extends RefCounted
## v6 튜닝 후보의 비파괴 산출물을 고정한다.
## 실제 런타임은 v5를 유지하며, 마이그레이션 승인 전 수치·해법 기준만 검사한다.

const Probe := preload("res://tests/ammo_v6_tuning_probe.gd")
const REPORT_PATH := "res://tests/baseline/ammo_v6_tuning_matrix.json"
const EXPECTED_DAMAGE := {
	"cal_9mm": 3,
	"cal_45acp": 3,
	"cal_556": 3,
	"cal_762": 4,
	"cal_12g": 5,
}


static func _by_gun(entries: Array) -> Dictionary:
	var result := {}
	for entry in entries:
		result[str(entry.gun_id)] = entry
	return result


static func run(t) -> void:
	t.section("AmmoV6Tuning")
	t.check(FileAccess.file_exists(REPORT_PATH), "v6 튜닝 매트릭스 JSON 존재")
	if not FileAccess.file_exists(REPORT_PATH):
		return
	var file := FileAccess.open(REPORT_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	t.check(parsed is Dictionary, "v6 튜닝 매트릭스 JSON 파싱")
	if not parsed is Dictionary:
		return
	var report: Dictionary = parsed
	t.eq(str(report.schema), "lob.ammo_v6_tuning", "v6 튜닝 스키마")
	t.eq(int(report.version), 1, "v6 튜닝 버전")

	for base_id in EXPECTED_DAMAGE:
		t.check(report.base_damage.has(base_id), "%s 후보 피해 존재" % base_id)
		if report.base_damage.has(base_id):
			t.eq(int(report.base_damage[base_id]), int(EXPECTED_DAMAGE[base_id]),
				"%s 후보 피해 고정" % base_id)

	var current := _by_gun(report.current_signature_cycles)
	var tuned := _by_gun(report.tuned_signature_cycles)
	t.eq(tuned.size(), 9, "9총기 튜닝 사이클 존재")
	for gun_id in tuned:
		t.check(bool(tuned[gun_id].accepted),
			"%s 후보 사이클이 화력 밴드 또는 거리 게이트 예외" % gun_id)
	t.check(not bool(current.gambler.in_band), "현행 도박형 시그니처는 밴드 초과 감지")
	t.check(not bool(current.suppressor.in_band), "현행 제압형 리로드는 밴드 초과 감지")
	t.eq(float(tuned.gambler.cycle_dpt), 2.71, "도박형 보정 후보 2.71 DMG/턴")
	t.eq(float(tuned.suppressor.cycle_dpt), 3.0, "제압형 보정 후보 3.00 DMG/턴")
	t.eq(float(tuned.shotgun.cycle_dpt), 4.17, "샷건 종이 화력 4.17 DMG/턴")
	t.check(bool(tuned.shotgun.range_gated_exception), "샷건은 원거리 명중 게이트 예외")

	var shotgun_start_effective := 0
	for distance_profile in report.distance_profiles:
		if str(distance_profile.gun_id) != "shotgun":
			continue
		for enemy in distance_profile.enemies:
			if int(enemy.start.damage) > 0:
				shotgun_start_effective += 1
	t.eq(shotgun_start_effective, 0, "⭐ 샷건 기반탄 시작 거리 직통 0/13 — DPT 예외 근거")

	t.eq(report.ordinary_failures.size(), 0,
		"⭐ 일반 적 9총기×8종은 처치 또는 안전한 다음 사이클 해법 존재")
	t.eq(report.signature_failures.size(), 0,
		"시그니처 적 9총기×5종은 최소 안전 진행 경로 존재")
	t.eq(report.starting_deck_failures.size(), 0,
		"⭐ 시작 덱 후보가 첫 무기고 전 러셔·방패병·회피병을 기본/환기구에서 해결")
	t.eq(report.control_required.size(), 1, "지원탄만으로 막힌 제어탄 필수 매치업 1개")
	if report.control_required.size() == 1:
		var control: Dictionary = report.control_required[0]
		t.eq(str(control.gun_id), "shotgun", "제어탄 필수 총기 = 샷건")
		t.eq(str(control.enemy_id), "tank", "제어탄 필수 대상 = 방패병")
		t.check(control.air_duct_best.has("impact") or control.air_duct_best.has("adhesive"),
			"환기구 샷건→방패병 해법에 제어탄 포함")

	# 총기별 일반 적 최적 지원 패키지 집합을 만들고, 9총기 모두에 공통인 단일 패키지가 없는지 본다.
	var package_by_gun := {}
	for solution in report.solutions:
		if not Probe.ORDINARY_ENEMY_IDS.has(str(solution.enemy_id)):
			continue
		var gun_id := str(solution.gun_id)
		if not package_by_gun.has(gun_id):
			package_by_gun[gun_id] = {}
		var key := "+".join(solution.normal.best_supports)
		package_by_gun[gun_id][key] = true
	t.eq(package_by_gun.size(), 9, "9총기 일반 적 최적 패키지 집계")
	var shared_packages: Dictionary = package_by_gun.values()[0].duplicate()
	for packages_variant in package_by_gun.values():
		var packages: Dictionary = packages_variant
		for key in shared_packages.keys():
			if not packages.has(key):
				shared_packages.erase(key)
	t.eq(shared_packages.size(), 0, "⭐ 9총기 전체를 지배하는 단일 지원 패키지 없음")

	t.eq(report.runtime_contract_drifts.size(), 2,
		"마이그레이션 전 해결할 런타임 계약 드리프트 2건 추적")
