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


func _initialize() -> void:
	print("\n╔══════ Last on Board · 자동 검증 ══════╗")
	var t := LobTest.new()

	SuiteDamage.run(t)      # 전투 수식(관통 게이트 · 명중 임계값)
	SuiteMagazine.run(t)    # 탄창 LIFO
	SuiteEnemy.run(t)       # 적 태세 전환 · 거리 계산
	ValidateData.run(t)     # CSV 데이터 정합성
	SimHarness.run(t)       # 결정론 전투 시뮬레이션

	var code := t.summary()
	print("╚═════════════════════════════════════╝")
	quit(code)
