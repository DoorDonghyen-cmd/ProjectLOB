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


func _initialize() -> void:
	print("\n╔══════ Last on Board · 자동 검증 ══════╗")
	# 테스트 중 메타 저장이 실제 세이브(user://meta_save.cfg)를 덮어쓰지 않도록 임시 경로로 리다이렉트
	var override_path := "user://__test_meta_override.cfg"
	RunManager.save_path_override = override_path

	var t := LobTest.new()

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

	# 테스트 임시 세이브 정리 및 오버라이드 해제
	DirAccess.remove_absolute(override_path)
	RunManager.save_path_override = ""

	var code := t.summary()
	print("╚═════════════════════════════════════╝")
	quit(code)
