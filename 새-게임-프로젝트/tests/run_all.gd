extends SceneTree
## 헤드리스 자동 검증 오케스트레이터.
## 실행: godot --headless --path <프로젝트> --script res://tests/run_all.gd
## 종료 코드 0 = 전체 통과, 1 = 실패 있음 (CI 연동 가능).

const LobTest := preload("res://tests/lob_test.gd")
const SuiteDamage := preload("res://tests/suite_damage.gd")
const SuiteMagazine := preload("res://tests/suite_magazine.gd")
const SuiteEnemy := preload("res://tests/suite_enemy.gd")
const ValidateData := preload("res://tests/validate_data.gd")
const SimHarness := preload("res://tests/sim_harness.gd")
const SuiteRunFlow := preload("res://tests/suite_run_flow.gd")
const SuiteSaveLoad := preload("res://tests/suite_save_load.gd")
const SuiteBossGimmicks := preload("res://tests/suite_boss_gimmicks.gd")
const SuiteFullRun := preload("res://tests/suite_full_run.gd")
const SuiteParts := preload("res://tests/suite_parts.gd")
const SuiteGunSignatures := preload("res://tests/suite_gun_signatures.gd")
const SuiteBulletEffects := preload("res://tests/suite_bullet_effects.gd")
const SuiteWeaponUnlock := preload("res://tests/suite_weapon_unlock.gd")
const SuiteSectionProgress := preload("res://tests/suite_section_progress.gd")
const SuiteConsumables := preload("res://tests/suite_consumables.gd")
const SuiteContinuousRun := preload("res://tests/suite_continuous_run.gd")
const SuiteSpawnTiers := preload("res://tests/suite_spawn_tiers.gd")
const SuiteUIDataDrift := preload("res://tests/suite_ui_data_drift.gd")
const SuiteDocDrift := preload("res://tests/suite_doc_drift.gd")
const SuiteUISmoke := preload("res://tests/suite_ui_smoke.gd")


const OVERRIDE_PATH := "user://__test_meta_override.cfg"

## UI 스모크는 씬 트리가 실제로 돌기 시작한 뒤에만 의미가 있다.
## _initialize() 시점에는 root Window가 아직 트리에 들어가지 않아 자식의 _ready()가 호출되지 않고,
## 오버레이 참조가 전부 null인 상태에서 검사하게 된다. 그래서 첫 프레임 이후로 미룬다.
var _t
var _frame := 0


func _initialize() -> void:
	print("\n╔══════ Last on Board · 자동 검증 ══════╗")
	# 테스트 중 메타 저장이 실제 세이브(user://meta_save.cfg)를 덮어쓰지 않도록 임시 경로로 리다이렉트
	RunManager.save_path_override = OVERRIDE_PATH

	var t := LobTest.new()
	_t = t

	SuiteDamage.run(t)      # 전투 수식(관통 게이트 · 명중 임계값)
	SuiteMagazine.run(t)    # 탄창 LIFO
	SuiteEnemy.run(t)       # 적 태세 전환 · 거리 계산
	ValidateData.run(t)     # CSV 데이터 정합성
	SimHarness.run(t)       # 결정론 전투 시뮬레이션
	SuiteRunFlow.run(t)     # 플레이 흐름 통합(무기→맵→노드→전투→클리어→정산)
	SuiteSaveLoad.run(t)    # 메타 세이브/로드 영속화
	SuiteBossGimmicks.run(t) # 보스/특수 기믹 유닛(앱소버·캐스터·삼단태세·페이즈전환)
	SuiteFullRun.run(t)     # 풀 런 통합 스캔(맵 도달성 + 전투 크래시 스캔)
	SuiteParts.run(t)       # 파츠 적용 회귀(파츠 전달 시 전투 효과 반영)
	SuiteGunSignatures.run(t) # 총기 시그니처 발동 회귀(리소스 ID 판정)
	SuiteBulletEffects.run(t) # 탄환 특수효과 발동 실증
	SuiteWeaponUnlock.run(t)  # 무기 해금 조건 판정 + 영속화
	SuiteSectionProgress.run(t) # 구역 완주 판정 + 다음 구역 해금 + 영속화
	SuiteConsumables.run(t)   # 소모품 효과(heal/shred) + 가방 적재·소진
	SuiteContinuousRun.run(t) # 연속 런 구조(계층 체이닝·자원 유지·종료 시점)
	SuiteSpawnTiers.run(t)    # 계층별 스폰 3구간이 모두 도달 가능한지
	SuiteUIDataDrift.run(t)   # UI가 계층 정보를 복사해 두지 않았는지(소스 레벨 드리프트 검사)
	SuiteDocDrift.run(t)      # GDD·스킬 문서에 폐기된 세계관 설정이 남아 있지 않은지
	# SuiteUISmoke는 _process()에서 — 트리 가동 후에 실행해야 한다.


## 1프레임: UI 스모크(트리가 살아 있어야 _ready가 돈다).
## 2프레임: 종료. 스모크가 예약한 queue_free가 처리된 뒤에 끝내야 엔진이 크래시하지 않는다.
func _process(_delta: float) -> bool:
	_frame += 1

	if _frame == 1:
		SuiteUISmoke.run(_t, self) # 메인 씬 실제 인스턴스화 + 오버레이 호출(런타임 오류 검출)
		return false

	# 테스트 임시 세이브 정리 및 오버라이드 해제
	DirAccess.remove_absolute(OVERRIDE_PATH)
	RunManager.save_path_override = ""

	var code: int = _t.summary()
	print("╚═════════════════════════════════════╝")
	quit(code)
	return true
