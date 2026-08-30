extends RefCounted
## 전용 QA 브리지 MVP: manifest, 단계 계약, 공개/오라클 분리, 실제 CombatManager 행동 왕복.

const ManifestScript := preload("res://scripts/qa/qa_session_manifest.gd")
const BridgeScript := preload("res://scripts/qa/qa_bridge.gd")
const TEST_OUTPUT := "user://__test_qa_bridge"


static func _gun() -> GunData:
	var gun := GunData.new()
	gun.display_name = "QA Workhorse"
	gun.weapon_class = Enums.WeaponClass.PISTOL
	gun.magazine_capacity = 2
	gun.has_chamber = false
	gun.reload_turns = 1
	gun.preview_window_size = 1
	return gun


static func _bullet(id: String, damage: int) -> BulletData:
	var bullet := BulletData.new()
	bullet.display_name = id
	bullet.weapon_class = Enums.WeaponClass.PISTOL
	bullet.damage = damage
	bullet.accuracy = 7
	bullet.penetration = 1
	bullet.role = "attack"
	bullet.specialty = "damage"
	return bullet


static func _enemy() -> EnemyData:
	var enemy := EnemyData.new()
	enemy.display_name = "QA Target"
	enemy.archetype = Enums.EnemyArchetype.RUSHER
	enemy.max_hp = 9
	enemy.defense = 0
	enemy.evasion = 0
	enemy.speed = 0
	enemy.start_distance = 8
	return enemy


static func run(t) -> void:
	t.section("QABridge")
	RunManager.infiltration_risk_level = 1
	RunManager.meta_ascension_level = 0

	var invalid_manifest := ManifestScript.create("", "qa-commit", "quick_smoke", "fixed_ammo")
	t.check(not ManifestScript.is_valid(invalid_manifest), "빈 session_id manifest 거절")

	var manifest := ManifestScript.create(
		"qa-test-session",
		"qa-commit",
		"quick_smoke",
		"fixed_ammo_specialty",
		true
	)
	t.check(ManifestScript.is_valid(manifest), "QA manifest 필수 계약 통과")

	var light := _bullet("qa_light", 3)
	var heavy := _bullet("qa_heavy", 6)
	var deck: Array[BulletData] = [light, heavy]
	var enemies: Array[EnemyData] = [_enemy()]
	var parts: Array[PartData] = []
	var bridge = BridgeScript.new()
	t.eq(bridge.configure(manifest, TEST_OUTPUT), OK, "QA 출력 폴더·manifest 구성")
	t.eq(bridge.start_fixed_combat(_gun(), enemies, deck, parts), OK,
		"실제 CombatManager 고정 전투 시작")

	var state0: Dictionary = bridge.state_bundle()
	t.eq(int(state0.step), 0, "초기 QA 단계 0")
	t.eq(str(state0.player_view.combat_state), "loading", "초기 상태는 장전 단계")
	t.eq(state0.player_view.available_ammo.size(), 2, "플레이어 공개 탄환 후보 2종")
	t.check(FileAccess.file_exists(TEST_OUTPUT + "/manifest.json"), "QA manifest JSON 저장")
	t.check(FileAccess.file_exists(TEST_OUTPUT + "/state_0000.json"), "초기 상태 JSON 저장")

	var wrong_step: Dictionary = bridge.submit_action({"step": 1, "action": "load", "bullet_id": "qa_light"})
	t.check(not bool(wrong_step.accepted), "미래 단계 행동 거절")
	t.eq(bridge.step, 0, "거절된 행동은 단계 불변")

	var unknown: Dictionary = bridge.submit_action({"step": 0, "action": "load", "bullet_id": "missing"})
	t.check(not bool(unknown.accepted), "보유하지 않은 탄환 장전 거절")
	t.eq(bridge.step, 0, "불법 탄환 행동도 단계 불변")

	var load_light: Dictionary = bridge.submit_action({"step": 0, "action": "load", "bullet_id": "qa_light"})
	t.check(bool(load_light.accepted), "첫 탄 장전 행동 수락")
	var load_heavy: Dictionary = bridge.submit_action({"step": 1, "action": "load", "bullet_id": "qa_heavy"})
	t.check(bool(load_heavy.accepted), "두 번째 탄 장전 행동 수락")
	var loading: Dictionary = bridge.state_bundle()
	t.eq(loading.player_view.pending_load_order.size(), 2, "장전 확정 전 순서 공개")

	var confirm: Dictionary = bridge.submit_action({"step": 2, "action": "confirm_load"})
	t.check(bool(confirm.accepted), "장전 확정 행동 수락")
	var ready: Dictionary = bridge.state_bundle()
	t.eq(str(ready.player_view.combat_state), "player_turn", "장전 후 플레이어 턴")
	t.eq(ready.player_view.magazine.visible_fire_order.size(), 1,
		"플레이어 공개 상태는 예고 슬롯 1발만 노출")
	t.eq(int(ready.player_view.magazine.hidden_count), 1, "깊은 탄창 1발 은폐")
	t.eq(ready.oracle_state.magazine_fire_order.size(), 2, "오라클은 전체 탄창 확인")
	t.eq(str(ready.oracle_state.magazine_fire_order[0].id), "qa_heavy",
		"LIFO 첫 격발은 마지막에 넣은 고화력탄")

	var first_fire: Dictionary = bridge.submit_action({"step": 3, "action": "fire"})
	t.check(bool(first_fire.accepted), "첫 격발 행동 수락")
	var after_first: Dictionary = bridge.state_bundle()
	t.eq(int(after_first.oracle_state.enemies[0].hp), 3, "실제 CombatManager로 고화력탄 6 피해")
	t.eq(str(after_first.player_view.combat_state), "player_turn", "적 생존 시 전투 지속")

	var second_fire: Dictionary = bridge.submit_action({"step": 4, "action": "fire"})
	t.check(bool(second_fire.accepted), "두 번째 격발 행동 수락")
	var final_state: Dictionary = bridge.state_bundle()
	t.eq(int(final_state.step), 5, "수락 행동만 단계 증가")
	t.eq(str(final_state.player_view.combat_state), "won", "두 발 LIFO 전투 승리")
	t.check(final_state.player_view.legal_actions.is_empty(), "종료 상태에는 합법 행동 없음")
	t.check(FileAccess.file_exists(TEST_OUTPUT + "/state_0005.json"), "최종 상태 JSON 저장")

	var file := FileAccess.open(TEST_OUTPUT + "/state_0005.json", FileAccess.READ)
	var parsed = JSON.parse_string(file.get_as_text()) if file != null else null
	t.check(parsed is Dictionary, "최종 QA 상태 JSON 파싱")
	if parsed is Dictionary:
		t.eq(str(parsed.session_id), "qa-test-session", "상태 JSON에 session ID 유지")
		t.eq(str(parsed.player_view.combat_state), "won", "저장 JSON 전투 결과 유지")

	var stale: Dictionary = bridge.submit_action({"step": 4, "action": "reload"})
	t.check(not bool(stale.accepted), "종료 뒤 과거 단계 행동 거절")
	t.eq(bridge.step, 5, "과거 행동 거절 뒤 최종 단계 유지")
	bridge.close()

	# 실제 에이전트 왕복의 바닥선. 장전 후보를 올렸다 되돌리는 합법 행동으로
	# 상태/행동 파일 20단계를 통과하고 단계가 유실되지 않는지 검증한다.
	var long_manifest := ManifestScript.create(
		"qa-20-step-session", "qa-commit", "quick_smoke", "fixed_20_step")
	var long_bridge = BridgeScript.new()
	var long_output := TEST_OUTPUT + "/twenty_steps"
	t.eq(long_bridge.configure(long_manifest, long_output), OK, "20단계 QA 세션 구성")
	var one_bullet_deck: Array[BulletData] = [light]
	t.eq(long_bridge.start_fixed_combat(_gun(), enemies, one_bullet_deck, parts), OK,
		"20단계 고정 전투 시작")
	var all_accepted := true
	for i in range(10):
		var load_result: Dictionary = long_bridge.submit_action({
			"step": long_bridge.step,
			"action": "load",
			"bullet_id": "qa_light",
		})
		var undo_result: Dictionary = long_bridge.submit_action({
			"step": long_bridge.step,
			"action": "undo_load",
		})
		all_accepted = all_accepted \
			and bool(load_result.get("accepted", false)) \
			and bool(undo_result.get("accepted", false))
	t.check(all_accepted, "상태/행동 JSON 20단계 연속 수락")
	t.eq(long_bridge.step, 20, "20단계 왕복 뒤 단조 단계 유지")
	t.check(FileAccess.file_exists(long_output + "/state_0020.json"),
		"20단계 최종 상태 JSON 저장")
	long_bridge.close()
