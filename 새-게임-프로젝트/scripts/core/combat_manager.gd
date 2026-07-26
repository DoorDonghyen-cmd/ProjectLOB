class_name CombatManager
extends Node

## 전투 루프 오케스트레이터 (다수 적 공유 트랙 + Tier 2 확장 버전)
## 상태 머신으로 전투 플로우를 제어하고, 시그널로 UI에 이벤트를 전달한다.

# ── 시그널 ──
signal encounter_started(enemy_list: Array[EnemyInstance])
signal loading_phase_started()
## 실제 피격 대상과 정산 직후 잔여 내구도를 함께 전달한다.
## 전투는 동기 정산하되 UI가 탄환 도착 시점에 정확한 대상·HP를 재생하기 위한 스냅샷이다.
signal bullet_fired(
	bullet: BulletData,
	hit: bool,
	damage: int,
	target: EnemyInstance,
	remaining_durability: int
)
## defer_visual=true인 주 사격 대상은 탄환 도착 큐가 HP·피격 연출을 담당한다.
## 과관통·관통 다중타 같은 보조 피해는 false로 즉시 표시해 누락을 막는다.
signal enemy_damaged(enemy_inst: EnemyInstance, damage: int, remaining_hp: int, defer_visual: bool)
signal enemy_moved(enemy_inst: EnemyInstance, new_distance: int, speed_used: int)
signal all_enemies_moved()
signal enemy_knocked_back(enemy_inst: EnemyInstance, new_distance: int, amount: int)
signal armor_shredded(enemy_inst: EnemyInstance, new_def: int, amount: int)
signal enemy_stance_changed(enemy_inst: EnemyInstance, new_stance: Enums.EnemyStance)
signal enemy_killed(enemy_inst: EnemyInstance)
signal reload_started(turns: int)
signal reload_finished()
signal encounter_won()
signal player_died()
signal combat_log(message: String)
signal magazine_updated(remaining: int, capacity: int)
signal bullet_unloaded(bullet: BulletData)
signal bullet_exiled(bullet: BulletData)
signal draw_pile_updated(bullets: Array[BulletData])
signal piles_updated(draw_pile: Array[BulletData], discard_pile: Array[BulletData], exile_pile: Array[BulletData])
signal buttstroke_triggered(enemy: EnemyInstance, new_distance: int)

# ── 상태 ──
enum State { INACTIVE, LOADING, PLAYER_TURN, RELOADING, WON, LOST }

var state: State = State.INACTIVE
var gun: GunData
var magazine: Magazine
var enemies: Array[EnemyInstance] = []
var last_shot_hit: bool = false
var reload_turns_remaining: int = 0
var _insert_seal_active: bool = false
var eject_used_this_turn: bool = false
var has_inserted_bullet_this_turn: bool = false
var is_magazine_first_shot: bool = true

# ── 순환 탄약 & 긴급 격퇴 가변 상태 ──
var draw_pile: Array[BulletData] = []
var discard_pile: Array[BulletData] = []
var exile_pile: Array[BulletData] = []
var buttstroke_used_this_encounter: bool = false

# ── 총기 파츠 및 기믹 상태 ──
var equipped_parts: Array[PartData] = []
var chaser_pen_bonus: int = 0
var target_marker_active: bool = false
var same_stance_hit_count: int = 0
var last_stance: Enums.EnemyStance = Enums.EnemyStance.NONE
var consecutive_caliber_count: int = 0

## ── 셋업 버프 (정본: docs/gdd/22_ammo_expansion.md §22.2) ──
## **다음 1발**에만 적용된다. 탄창 전체 지속이면 "셋업 하나 깔고 나머지 전부 고화력"이
## 최적해가 되어 조합이 다시 단순해지므로, 1발 한정이라야 버프-딜러 교차가 강제된다.
## 중첩 없이 덮어쓰며, 리로드 시 소멸한다(탄창 끝에 셋업 깔아두기 방지).
var pending_buff_acc: int = 0
var pending_buff_pen: int = 0
var visible_magazine_slots: int = 2
var final_kill_distance: int = 99

# ── 구경 기반 순서 기억 ──
var last_fired_class: Enums.WeaponClass = Enums.WeaponClass.PISTOL

# ── 전투 세션 통계 ──
var battle_stats := {
	"misses": 0,
	"zero_damage_hits": 0,
	"kills_this_turn": 0,
	"lead_bullets_fired": 0,
	"shred_only_tank_kills": 0,
	"stance_kills_without_slow": 0,
	"max_kills_in_single_turn": 0,
	"min_dist_allowed": 99,
	"total_kills": 0,
	"total_kill_dist_sum": 0.0,
	"magazine_emptied_wins": 0,
	## 적이 접근한 최소 거리 / 그 적의 시작 거리 (0.0~1.0). 낮을수록 가까이 붙였다는 뜻.
	## ⚠️ 절대 거리가 아니라 **비율**이다. 승천이 시작 거리를 좁히면 임계값도 함께 좁아져야
	##    "거리를 통제했는가"라는 의도가 난이도와 무관하게 유지된다.
	"min_dist_ratio": 1.0
}


## 태세 고정(STANCE_LOCK) 사용 여부 — 전투당 1회
var _stance_lock_used: bool = false


## 하위 호환 래퍼: 최근접 적 1마리를 반환한다. (UI 및 레거시 코드와의 호환용)
var enemy: EnemyInstance:
	get:
		return _get_nearest_enemy()


## 최근접 적을 반환한다 (강제 타겟팅의 핵심).
## 거리가 가장 짧은 생존 적. 동률이면 배열 앞쪽(= 먼저 등장한 적) 우선.
func _get_nearest_enemy() -> EnemyInstance:
	var nearest: EnemyInstance = null
	var min_dist: int = 99999
	for e in enemies:
		if not e.is_dead() and e.current_distance < min_dist:
			min_dist = e.current_distance
			nearest = e
	return nearest


## 생존 중인 적 목록을 반환한다.
func get_alive_enemies() -> Array[EnemyInstance]:
	var alive: Array[EnemyInstance] = []
	for e in enemies:
		if not e.is_dead():
			alive.append(e)
	return alive


## 인카운터를 시작한다. 총과 적 데이터 배열, 장착 파츠 목록을 받아 초기화.
func start_encounter(gun_data: GunData, enemy_datas: Array[EnemyData], deck_bullets: Array[BulletData], parts: Array[PartData] = []) -> void:
	gun = gun_data
	enemies.clear()
	var offset := 0
	for ed in enemy_datas:
		var inst := EnemyInstance.new(ed)
		inst.start_distance += offset
		inst.current_distance += offset
		enemies.append(inst)
		# 대열이 겹치지 않고 한 줄로 늘어서도록 2m 간격 스태거링 적용
		offset += 2
	magazine = Magazine.new(gun)
	last_shot_hit = false
	_insert_seal_active = false
	has_inserted_bullet_this_turn = false
	last_fired_class = Enums.WeaponClass.PISTOL
	is_magazine_first_shot = true
	
	# 탄약 순환 자원 데이터 및 긴급 격퇴 초기화
	draw_pile = deck_bullets.duplicate()
	discard_pile.clear()
	exile_pile.clear()
	buttstroke_used_this_encounter = false
	draw_pile_updated.emit(draw_pile)
	piles_updated.emit(draw_pile, discard_pile, exile_pile)
	
	# 전투 통계 초기화
	var init_min_dist = 99
	for e in enemies:
		if e.current_distance < init_min_dist:
			init_min_dist = e.current_distance
	battle_stats = {
		"misses": 0,
		"zero_damage_hits": 0,
		"kills_this_turn": 0,
		"lead_bullets_fired": 0,
		"shred_only_tank_kills": 0,
		"stance_kills_without_slow": 0,
		"max_kills_in_single_turn": 0,
		"min_dist_allowed": init_min_dist,
		"total_kills": 0,
		"total_kill_dist_sum": 0.0,
		"magazine_emptied_wins": 0,
		"min_dist_ratio": 1.0
	}
	final_kill_distance = 99
	
	# 파츠 및 기믹 상태 초기화
	equipped_parts = parts
	chaser_pen_bonus = 0
	target_marker_active = false
	same_stance_hit_count = 0
	last_stance = Enums.EnemyStance.NONE
	consecutive_caliber_count = 0
	pending_buff_acc = 0
	pending_buff_pen = 0
	
	# 예고창 슬롯 수 보정 (Scope, Blind Fire 파츠)
	visible_magazine_slots = gun.preview_window_size if gun != null else 2
	if _has_part(Enums.PartID.SCOPE):
		visible_magazine_slots += 1
	if _has_part(Enums.PartID.BLIND_FIRE):
		visible_magazine_slots = max(1, visible_magazine_slots - 1)
		
	_stance_lock_used = false

	# 태세 예지 (STANCE_FORESIGHT): 전투 개시 시 태세 전환 주기를 미리 공개한다.
	# 전환 타이밍을 알면 LIFO 적재 순서를 그에 맞춰 설계할 수 있다.
	if _has_part(Enums.PartID.STANCE_FORESIGHT):
		for e in enemies:
			if e.current_stance != Enums.EnemyStance.NONE:
				combat_log.emit("🔮 [태세 예지] [%s]는 %d발마다 태세를 교대합니다. (다음 전환까지 %d발)" % [
					e.data.display_name, e.stance_shift_interval,
					maxi(e.stance_shift_interval - e.shot_counter, 1)])

	encounter_started.emit(enemies)
	_enter_loading_phase()


## 장전 페이즈 진입
func _enter_loading_phase() -> void:
	state = State.LOADING
	_insert_seal_active = false
	eject_used_this_turn = false
	loading_phase_started.emit()


## 장전 확인 — UI가 정렬된 총알 배열을 전달하면 탄창에 넣고 전투 시작.
func confirm_loading(bullets: Array[BulletData]) -> void:
	if state != State.LOADING:
		return
	magazine.load_bullets(bullets)
	
	# 장전된 탄환을 가방(draw_pile)에서 제외
	for b in bullets:
		for i in range(draw_pile.size()):
			if draw_pile[i].display_name == b.display_name:
				draw_pile.remove_at(i)
				break
	draw_pile_updated.emit(draw_pile)
	piles_updated.emit(draw_pile, discard_pile, exile_pile)
	
	state = State.PLAYER_TURN
	eject_used_this_turn = false
	magazine_updated.emit(magazine.get_remaining(), magazine.get_capacity())
	is_magazine_first_shot = true
	combat_log.emit("── 탄창 장전 완료! %d발 ──" % magazine.get_remaining())


## 이 총이 연발(FULL_AUTO)인가. 정본: docs/gdd/21_fire_mode.md
func is_full_auto() -> bool:
	return gun != null and gun.fire_mode == Enums.FireMode.FULL_AUTO


## 다음에 발사될 탄의 **유효 ACC/PEN**을 미리 계산한다 (게이트 판정 표시의 단일 정본).
##
## ⚠️ UI가 이 계산을 자기 안에서 중복하지 않게 한 곳에 둔다.
##    포함: 탄 기본값 + 총기 패시브 + **대기 중인 셋업 버프**.
##    ⚠️ 버프를 빼면 판정이 거짓이 된다 — 관통 버프탄을 깔아도 "도탄 ✗"로 표시되어
##       실제로는 뚫리는데 화면이 안 뚫린다고 거짓말을 한다(v5가 만든 불일치).
##    제외: 조건부 파츠(거리·스택 위치·연속 명중 등)는 실제 격발 시점에만 확정되므로
##       미리보기에 넣지 않는다. 이 표시는 "탄 + 버프"까지만 책임진다.
func preview_next_shot() -> Dictionary:
	if magazine == null or magazine.is_empty():
		return {}
	var b := magazine.peek()
	var acc := b.accuracy
	var pen := b.penetration
	if gun != null:
		acc += gun.passive_acc_bonus
		pen += gun.passive_pen_bonus
	acc += pending_buff_acc
	pen += pending_buff_pen
	return {
		"bullet": b,
		"acc": acc,
		"pen": pen,
		"buffed_acc": pending_buff_acc > 0,
		"buffed_pen": pending_buff_pen > 0,
	}


## 발사 — 탄창에서 한 발 꺼내 최근접 적에게 쏜다 (강제 타겟팅).
func fire() -> void:
	battle_stats.kills_this_turn = 0
	if is_full_auto():
		_fire_full_auto()
	else:
		var target := _get_nearest_enemy()
		_fire_internal(target)
	battle_stats.max_kills_in_single_turn = maxi(battle_stats.max_kills_in_single_turn, battle_stats.kills_this_turn)


## 연발 — 탄창의 모든 탄이 나간다. 중간에 멈출 수 없다.
##
## ⚠️ 전체가 **1턴**이다. 발당 1턴이면 "멈출 수만 없는 단발"이 되어 하위호환이 된다.
##    그래서 적 전진은 마지막에 한 번만 일어난다.
##
## 발당 도는 것(오버킬 이월·ARMOR_SHRED·태세 전환)은 _fire_internal이 이미 처리한다.
##  - 매 탄 _get_nearest_enemy()를 다시 부르므로 앞의 적이 죽으면 자연히 다음 적으로 이월된다.
##    강제 타겟이 "최근접 1명"이라 규칙을 새로 추가하지 않아도 성립한다.
##  - 태세 전환 검사는 _fire_internal 안의 전진 블록 밖에 있어 전진을 억제해도 발당 돈다.
func _fire_full_auto() -> void:
	if state != State.PLAYER_TURN:
		return
	if magazine.is_empty():
		combat_log.emit("⚠ 탄창이 비었습니다! 리로드하세요.")
		return
	if _get_nearest_enemy() == null:
		combat_log.emit("⚠ 타겟이 없습니다.")
		return

	var burst_size := magazine.get_remaining()
	combat_log.emit("💥 [연발 개시] 탄창 %d발을 전부 쏟아붓습니다." % burst_size)

	var fired := 0
	while not magazine.is_empty():
		var target := _get_nearest_enemy()
		if target == null:
			break

		fired += 1
		combat_log.emit("🔥 [%d/%d발째]" % [fired, burst_size])
		_fire_internal(target, false)  # 적 전진은 버스트 종료 후 1회만

		# ⚠️ 전투가 끝나면(승리/패배) 남은 탄을 인위적으로 비우지 않는다.
		#    "중간에 멈출 수 없다"는 전투 **중** 판단 변경을 막는 규칙이지,
		#    쏠 대상이 사라진 뒤까지 적용할 이유가 없다. 억지로 비우면
		#    "탄창을 비운 채 승리" 같은 조건이 무의미해지고, 플레이어에게
		#    아무 영향도 없는 규칙만 하나 늘어난다.
		if state != State.PLAYER_TURN:
			return

	# ── 버스트 전체를 1턴으로 정산: 적 전진 1회 ──
	eject_used_this_turn = false
	_all_enemies_advance()
	if state == State.LOST:
		return

	combat_log.emit("🔻 탄창이 비었습니다. 재장전이 필요합니다 (%d턴)." % gun.reload_turns)


## 지정 사격 — 특정 적을 지정하여 쏜다 (슬로우 탄 자유 조준 사격용).
func fire_at_target(target_enemy: EnemyInstance) -> void:
	battle_stats.kills_this_turn = 0
	_fire_internal(target_enemy, true)
	battle_stats.max_kills_in_single_turn = maxi(battle_stats.max_kills_in_single_turn, battle_stats.kills_this_turn)


## 실제 격발 정산 로직
func _fire_internal(target: EnemyInstance, advance_enemies: bool = true) -> void:
	if state != State.PLAYER_TURN:
		return
	if magazine.is_empty():
		combat_log.emit("⚠ 탄창이 비었습니다! 리로드하세요.")
		return

	if _insert_seal_active:
		_insert_seal_active = false
		combat_log.emit("⏸ [납탄 봉인] 삽입한 탄환이 약실로 이동 중입니다. 다시 발사 버튼을 누르세요.")
		return

	if target == null:
		combat_log.emit("⚠ 타겟이 없습니다.")
		return

	var is_refunded := false
	var is_first := is_magazine_first_shot
	is_magazine_first_shot = false
	var is_last := magazine.is_next_last_shot()
	
	# 격발 직전 탄창의 잔탄 개수
	var remaining_before_fire := magazine.get_remaining()
	var bullet := magazine.fire()

	# ── 1. 명중 판정 파츠 가산 ──
	var part_acc_bonus := 0
	
	# 연동 조준 (CHAIN_ACC): 직전 탄 명중 시 ACC +2
	if _has_part(Enums.PartID.CHAIN_ACC) and last_shot_hit:
		part_acc_bonus += 2
		combat_log.emit("   ↳ 🎯 [연동 조준] 직전 명중으로 ACC +2 적용")
		
	# 만능 약실 (VERSATILE_CHAMBER): 직전과 **구경이 다르면** ACC +1 (PEN은 아래에서 +1)
	# ⚠️ 상시 보정이 아니라 교차 구경 조건이다. 버프탄(적을 읽는 상황적 보정)과 겹치지 않도록
	#    "호환·교차 빌드"라는 다른 축을 쓴다. (정본: docs/gdd/22_ammo_expansion §22.0-B 파츠 경계)
	var versatile_active := _has_part(Enums.PartID.VERSATILE_CHAMBER) and bullet.weapon_class != last_fired_class
	if versatile_active:
		part_acc_bonus += 1
		combat_log.emit("   ↳ 🔧 [만능 약실] 교차 구경으로 ACC +1 · PEN +1")

	# 고정밀 총열 (HIGH_PRECISION): **직전 탄이 빗나갔으면** ACC +3 (실패 보정)
	# ⚠️ 상시 ACC가 아니라 회복 조건이다. 명중 버프탄이 상황적으로 하는 걸,
	#    파츠는 "빗나감 다음"이라는 다른 조건으로 한다.
	if _has_part(Enums.PartID.HIGH_PRECISION) and not is_first and not last_shot_hit:
		part_acc_bonus += 3
		combat_log.emit("   ↳ 🎯 [고정밀 총열] 직전 빗나감 보정으로 ACC +3")

	# 저격경 (MARKSMAN_SCOPE): ACC +4 상시 가산 및 첫 탄환 EVA 무시
	if _has_part(Enums.PartID.MARKSMAN_SCOPE):
		part_acc_bonus += 4
		combat_log.emit("   ↳ 🎯 [저격경] 패시브로 명중률 ACC +4 가산")

	var target_evasion := target.current_evasion
	
	# ── 저격형(Marksman) 총기 시그니처: 명중 게이트 무시 (거리 > 1) ──
	var is_marksman_ignore_eva := false
	if _gun_is("dmr"):
		if target.current_distance > 1:
			target_evasion = 0
			is_marksman_ignore_eva = true
			combat_log.emit("   ↳ 🎯 [저격형 시그니처] 명중 게이트 무시 발동! (거리 %dm)" % target.current_distance)
		else:
			combat_log.emit("   ↳ ⚠ [저격형 페널티] 초근접(DIST <= 1m) 조준선 불일치로 명중 우회 규칙 해제!")
	
	# 저격경 (MARKSMAN_SCOPE) 첫 탄 확정 명중
	if _has_part(Enums.PartID.MARKSMAN_SCOPE) and is_first:
		target_evasion = 0
		combat_log.emit("   ↳ 🎯 [저격경] 첫 탄환 격발! 적의 회피율(EVA) 무시 확정 명중 적용!")
	
	# 표적 지시기 (TARGET_INDICATOR): 턴당 최초 1회 타겟 회피 0 고정
	if _has_part(Enums.PartID.TARGET_INDICATOR) and not target_marker_active:
		target_evasion = 0
		target_marker_active = true
		combat_log.emit("   ↳ 🎯 [표적 지시기] 적의 회피율을 이번 사격에 한해 0으로 고정!")

	# ── 태세 사냥꾼(Stance Hunter) 총기 시그니처: 파훼 ──
	var is_stance_hunter_bypass := false
	if _gun_is("stance_hunter") and target.current_stance != Enums.EnemyStance.NONE:
		if target.shot_counter == 2:
			is_stance_hunter_bypass = true
			target_evasion = 0
			combat_log.emit("   ↳ 🎯 [태세 사냥꾼 시그니처] 파훼 발동! 태세 전환 타이밍 간파 (게이트 무조건 통과!)")

	# 대기 중인 셋업 버프를 이번 탄에 소비한다(다음 1발 한정이므로 즉시 비운다).
	var buff_acc := pending_buff_acc
	var buff_pen := pending_buff_pen
	pending_buff_acc = 0
	pending_buff_pen = 0
	if buff_acc > 0 or buff_pen > 0:
		combat_log.emit("   ↳ 🎯 [셋업 적용] ACC +%d · PEN +%d" % [buff_acc, buff_pen])

	var calc_bullet_acc := bullet.duplicate()
	calc_bullet_acc.accuracy += part_acc_bonus + buff_acc

	# ── 돌격형(Bruiser) 총기 페널티: 원거리 조준 불안정 ──
	if _gun_is("shotgun") and target.current_distance >= 4:
		calc_bullet_acc.accuracy -= 4
		combat_log.emit("   ↳ ⚠ [돌격형 페널티] 원거리 조준 불안정으로 이번 사격 ACC -4 감소!")

	var hit := DamageCalculator.check_hit(calc_bullet_acc, target_evasion, gun)
	# 콤보 판정은 "직전 격발"의 명중 여부를 봐야 하므로 덮어쓰기 전에 보존한다.
	# (보존하지 않으면 현재 격발의 명중 여부를 읽어 첫 발부터 항상 발동하는 버그가 된다)
	var prev_shot_hit := last_shot_hit
	last_shot_hit = hit

	if hit:
		# ── 2. 대미지 및 관통 파츠 가산 ──
		var part_dmg_bonus := 0
		var part_pen_bonus := buff_pen

		# 철갑 총열 (ARMOR_PIERCING): **탄창 첫 탄**에 PEN +2 (선두 관통)
		# ⚠️ 상시 PEN이 아니라 스택 위치 조건이다. 관통 버프탄과 겹치지 않도록 LIFO 고유의
		#    "첫 탄" 축을 쓴다. 연발에서 상시 PEN+1은 탄창 전체를 뒤집어 특히 위험했다.
		if _has_part(Enums.PartID.ARMOR_PIERCING) and is_first:
			part_pen_bonus += 2
			combat_log.emit("   ↳ 🛡 [철갑 총열] 선두 탄 PEN +2")

		# 만능 약실 (VERSATILE_CHAMBER): 교차 구경일 때 PEN +1 (위 ACC +1과 한 쌍)
		if versatile_active:
			part_pen_bonus += 1
			
		# 블라인드파이어 (BLIND_FIRE): DMG +2
		if _has_part(Enums.PartID.BLIND_FIRE):
			part_dmg_bonus += 2
			combat_log.emit("   ↳ 🔫 [블라인드파이어] 정보 은폐 대가로 DMG +2 적용")
			
		# 딥로더 (DEEP_LOADER): 바닥 스택에 가까울수록 DMG 점진 증가
		if _has_part(Enums.PartID.DEEP_LOADER):
			var deep_bonus = magazine.get_capacity() - remaining_before_fire
			if deep_bonus > 0:
				part_dmg_bonus += deep_bonus
				combat_log.emit("   ↳ 📥 [딥로더] 탄창 깊이(%d)에 따른 DMG +%d 가산" % [deep_bonus, deep_bonus])
				
		# 리듬 챔버 (RHYTHM_CHAMBER): 동일 클래스의 짝수 번째 연속 격발에 DMG +1
		# ⚠️ 연속 횟수를 그대로 보너스로 쓰면 연발 6발에서 +20이 되어 발사 방식이
		#    곧 지배 전략이 된다. 2·4·6번째 박자만 보상해 슬롯 가치만 남긴다.
		if _has_part(Enums.PartID.RHYTHM_CHAMBER):
			if bullet.weapon_class == last_fired_class:
				consecutive_caliber_count += 1
			else:
				consecutive_caliber_count = 1
			if consecutive_caliber_count % 2 == 0:
				part_dmg_bonus += 1
				combat_log.emit("   ↳ 🎶 [리듬 챔버] 동일 클래스 %d번째 박자! DMG +1" % consecutive_caliber_count)
		else:
			consecutive_caliber_count = 0
			
		# 인터럽터 (INTERRUPTER): 직전 클래스와 다를 시 DMG 보너스 (+3)
		if _has_part(Enums.PartID.INTERRUPTER):
			if bullet.weapon_class != last_fired_class:
				part_dmg_bonus += 3
				combat_log.emit("   ↳ 🔀 [인터럽터] 클래스 교차 격발! DMG +3 가산")
				
		# 언더플로우 (UNDERFLOW): 탄창 가장 마지막 1발(바닥 탄) 발사 시 DMG +5
		if _has_part(Enums.PartID.UNDERFLOW) and is_last:
			part_dmg_bonus += 5
			combat_log.emit("   ↳ 💥 [언더플로우] 피날레 격발! DMG +5 가산")

		# 포인트블랭크 (POINT_BLANK): 거리 1~2칸 초근접 시 DMG +4 (돌격형 총기 기본 내장)
		if (_has_part(Enums.PartID.POINT_BLANK) or _gun_is("shotgun")) and target.current_distance <= 2:
			part_dmg_bonus += 4
			combat_log.emit("   ↳ ⚡ [돌격형 시그니처] 초근접(DIST %dm) 보너스로 DMG +4 가산!" % target.current_distance)
			
		# 롱샷 (LONG_SHOT): 거리 3칸 이상 원거리 시 DMG 비례 상승 (DIST - 2)
		if _has_part(Enums.PartID.LONG_SHOT) and target.current_distance >= 3:
			var long_bonus = target.current_distance - 2
			part_dmg_bonus += long_bonus
			combat_log.emit("   ↳ 🎯 [롱샷] 원거리 저격! DMG +%d 가산" % long_bonus)
			
		# 관성 격발 (INERTIA_FIRE): 적 태세 고정 중 연속 명중 시 피해 누적 증가
		if _has_part(Enums.PartID.INERTIA_FIRE):
			if target.current_stance == last_stance:
				same_stance_hit_count += 1
				part_dmg_bonus += same_stance_hit_count
				combat_log.emit("   ↳ 📈 [관성 격발] 동일 태세 명중 유지! DMG +%d 누적 가산" % same_stance_hit_count)
			else:
				same_stance_hit_count = 0
			last_stance = target.current_stance

		# 체이서 (CHASER): 누적 PEN 가산
		if _has_part(Enums.PartID.CHASER):
			part_pen_bonus += chaser_pen_bonus
			if chaser_pen_bonus > 0:
				combat_log.emit("   ↳ 🚀 [체이서] 누적 관통력 PEN +%d 적용" % chaser_pen_bonus)

		# 태세 사냥꾼(Stance Hunter) 파훼 관통 우회
		if is_stance_hunter_bypass:
			part_pen_bonus += 99

		# 저격형(Marksman) 근거리 패널티 (DIST <= 1)
		if _gun_is("dmr") and target.current_distance <= 1:
			part_dmg_bonus -= 2
			combat_log.emit("   ↳ ⚠ [저격형 페널티] 초근접(DIST <= 1m) 사격 패널티로 DMG -2 감쇄!")

		# 도박형(Gambler) 올인 데미지 가산
		if _gun_is("gambler"):
			var depth := remaining_before_fire - 1
			var gambler_bonus := depth * 2
			part_dmg_bonus += gambler_bonus
			combat_log.emit("   ↳ 🎲 [도박형 시그니처] 올인 격발! 깊이 %d단계 보너스로 DMG +%d 가산!" % [depth, gambler_bonus])

		var calc_bullet := bullet.duplicate()
		calc_bullet.damage += part_dmg_bonus
		calc_bullet.penetration += part_pen_bonus

		# 처형자 (EXECUTIONER): 거리 1 이하에서 체력이 3 이하인 적 즉사
		if _has_part(Enums.PartID.EXECUTIONER) and target.current_distance <= 1 and target.current_hp <= 3:
			calc_bullet.damage = target.current_hp + target.current_def + 10
			combat_log.emit("   ↳ 🗡 [처형자] 빈사 상태의 적 즉사 처형!")

		var damage := DamageCalculator.calculate_damage(
			calc_bullet, target.current_def, gun
		)
		var breakdown := DamageCalculator.damage_breakdown(
			calc_bullet, target.current_def, gun
		)

		# ── 2.3 마무리 사격 (Last Shot) 배율 적용 ──
		if bullet.effect_type == Enums.BulletEffect.LAST_SHOT and is_last:
			if damage > 0:
				var multiplier := float(bullet.effect_value) / 100.0
				var base_dmg = damage
				damage = int(round(damage * multiplier))
				breakdown += " x [막탄 배율 %s]" % str(multiplier)
				combat_log.emit("   ↳ 🎯 [막탄 강화] 탄창 최종 격발! 대미지 %d → %d" % [base_dmg, damage])

		# ── 2.4 연발 콤보 (Combo Shot) 대미지 가산 적용 ──
		if bullet.effect_type == Enums.BulletEffect.COMBO and prev_shot_hit:
			if damage > 0:
				damage += bullet.effect_value
				breakdown += " + [콤보 보너스] %d" % bullet.effect_value
				combat_log.emit("   ↳ 🔥 [콤보 사격] 연속 명중 보너스! 추가 대미지 +%d" % bullet.effect_value)

		# ── 2.5 클래스 다름/교차구경 조건부 추가피해 ──
		if bullet.effect_type == Enums.BulletEffect.CALIBER_DIFF:
			if bullet.weapon_class != last_fired_class or bullet.weapon_class == Enums.WeaponClass.UNIVERSAL:
				var bonus := bullet.effect_value
				damage += bonus
				breakdown += " + [구경다름 보너스] %d" % bonus
				combat_log.emit("   ↳ ⚡ [교차 구경] 직전 클래스(%s)와 다름! 추가 대미지 +%d" % [_class_name(last_fired_class), bonus])

		# ── 3. 대미지 적용 ──
		_apply_damage_to_enemy(target, damage)
		if damage > 0:
			is_refunded = true
			# ── 셋업 버프 부여 (유효 적중 시에만) ──
			# ⚠️ "막힌 탄은 아무 일도 일으키지 않는다" — 환급 원칙과 같은 선상이다.
			#    셋업탄도 게이트를 넘어야 하므로 셋업 자체가 리스크가 된다.
			#    (파쇄는 반대로 명중만으로 발동한다 — _apply_post_hit_effects 참조)
			match bullet.effect_type:
				Enums.BulletEffect.BUFF_ACC:
					pending_buff_acc = bullet.effect_value
					combat_log.emit("   ↳ ✨ [연계] 다음 탄 ACC +%d" % bullet.effect_value)
				Enums.BulletEffect.BUFF_PEN:
					pending_buff_pen = bullet.effect_value
					combat_log.emit("   ↳ ✨ [연계] 다음 탄 PEN +%d" % bullet.effect_value)
		else:
			battle_stats.zero_damage_hits += 1
		combat_log.emit("🔫 %s → [%s] 명중! %d 대미지" % [bullet.display_name, target.data.display_name, damage])
		combat_log.emit("   %s" % breakdown)
		var remaining_durability := target.current_hp if not target.is_stack_sponge else target.barrier_cells
		bullet_fired.emit(bullet, true, damage, target, remaining_durability)
		enemy_damaged.emit(target, damage, remaining_durability, true)

		# ── 중장형(Heavy) 총기 시그니처: 과관통 ──
		if _gun_is("heavy"):
			var total_pen := bullet.penetration + part_pen_bonus
			if gun: total_pen += gun.passive_pen_bonus
			var excess_pen := total_pen - target.current_def
			if excess_pen > 0:
				var alive_list := get_alive_enemies()
				alive_list.sort_custom(func(a, b): return a.current_distance < b.current_distance)
				var target_idx := alive_list.find(target)
				if target_idx != -1 and target_idx + 1 < alive_list.size():
					var e2: EnemyInstance = alive_list[target_idx + 1]
					if excess_pen >= e2.current_def:
						var dmg2 := bullet.damage + part_dmg_bonus
						if gun: dmg2 += gun.passive_dmg_bonus
						dmg2 = maxi(dmg2, 1)
						_apply_damage_to_enemy(e2, dmg2)
						combat_log.emit("   ↳ 🎯 [중장형 과관통] 초과 관통(PEN %d vs DEF %d)으로 [%s] 관통! %d 대미지" % [excess_pen, e2.current_def, e2.data.display_name, dmg2])
						enemy_damaged.emit(e2, dmg2, e2.current_hp if not e2.is_stack_sponge else e2.barrier_cells, false)
						if e2.is_dead():
							combat_log.emit("💀 [%s] 처치!" % e2.data.display_name)
							enemy_killed.emit(e2)

		# ── 4. 피격 후 효과 ──
		_apply_post_hit_effects(bullet, target, is_first, is_last)

		# 파쇄 총구 (SHRED_MUZZLE): 명중 시 적 DEF 영구 -1
		if _has_part(Enums.PartID.SHRED_MUZZLE):
			target.apply_armor_shred(1)
			armor_shredded.emit(target, target.current_def, 1)
			combat_log.emit("   ↳ ⚙ [파쇄 총구] 명중 피드백으로 적 DEF -1 영구 파쇄!")

		# ── 4.5 관통 다중 타격 (PIERCE 효과) ──
		if bullet.effect_type == Enums.BulletEffect.PIERCE:
			var alive_list := get_alive_enemies()
			alive_list.sort_custom(func(a, b): return a.current_distance < b.current_distance)
			var target_idx := alive_list.find(target)
			if target_idx != -1:
				if target_idx + 1 < alive_list.size():
					var e2: EnemyInstance = alive_list[target_idx + 1]
					var dmg2: int = maxi(1, int(round(DamageCalculator.calculate_damage(bullet, e2.current_def, gun) * 0.5)))
					_apply_damage_to_enemy(e2, dmg2)
					combat_log.emit("   ↳ 🎯 [관통 다중타] → [%s] 명중! %d 대미지 (50%% 감쇄)" % [e2.data.display_name, dmg2])
					enemy_damaged.emit(e2, dmg2, e2.current_hp if not e2.is_stack_sponge else e2.barrier_cells, false)
					if e2.is_dead():
						combat_log.emit("💀 [%s] 처치!" % e2.data.display_name)
						enemy_killed.emit(e2)
				if target_idx + 2 < alive_list.size():
					var e3: EnemyInstance = alive_list[target_idx + 2]
					var dmg3: int = maxi(1, int(round(DamageCalculator.calculate_damage(bullet, e3.current_def, gun) * 0.25)))
					_apply_damage_to_enemy(e3, dmg3)
					combat_log.emit("   ↳ 🎯 [관통 다중타] → [%s] 명중! %d 대미지 (75%% 감쇄)" % [e3.data.display_name, dmg3])
					enemy_damaged.emit(e3, dmg3, e3.current_hp if not e3.is_stack_sponge else e3.barrier_cells, false)
					if e3.is_dead():
						combat_log.emit("💀 [%s] 처치!" % e3.data.display_name)
						enemy_killed.emit(e3)

		# ── 5. 넉백 ──
		var calc_bullet_kb := bullet.duplicate()
		calc_bullet_kb.damage += part_dmg_bonus
		calc_bullet_kb.penetration += part_pen_bonus
		
		var kb := DamageCalculator.calculate_knockback(calc_bullet_kb, gun)

		# 돌격형(샷건) 시그니처 보호: 초근접 보너스 구간(거리 <= 2)에서는 자체 패시브 넉백을 제외한다.
		# 제외하지 않으면 샷건이 자기 사격으로 적을 보너스 구간 밖으로 밀어내
		# 초근접 특화가 첫 발에만 적용되고 이후 원거리 페널티까지 받는 자기모순이 발생한다.
		# (탄환 자체 넉백은 플레이어의 의도적 선택이므로 그대로 유지)
		if gun and _gun_is("shotgun") and target.current_distance <= 2:
			kb = maxi(kb - gun.passive_knockback_bonus, 0)

		# 언더플로우 (UNDERFLOW): 피날레 넉백 2배 증폭
		if _has_part(Enums.PartID.UNDERFLOW) and is_last and kb > 0:
			kb *= 2
			combat_log.emit("   ↳ 💥 [언더플로우] 피날레 넉백 2배 증폭 적용!")
			
		if kb > 0:
			var eff_kb := target.apply_knockback(kb)
			if eff_kb > 0:
				enemy_knocked_back.emit(target, target.current_distance, eff_kb)
				combat_log.emit("   ↳ 넉백 %d칸 → 거리 %d" % [eff_kb, target.current_distance])
			else:
				combat_log.emit("   ↳ 넉백 저항! 적의 저항으로 밀려나지 않음 (저항 %d)" % target.knockback_resistance)
				
			# 확산 격발 장치 (SPREAD_SHOT - 샷건 고유): 주 타겟 양옆의 적들에게도 넉백 전파
			if _has_part(Enums.PartID.SPREAD_SHOT):
				var alive_list := get_alive_enemies()
				alive_list.sort_custom(func(a, b): return a.current_distance < b.current_distance)
				var idx := alive_list.find(target)
				if idx != -1:
					var splash_kb: int = maxi(1, int(kb / 2))
					if idx > 0:
						var prev_e: EnemyInstance = alive_list[idx - 1]
						var eff_prev_kb := prev_e.apply_knockback(splash_kb)
						if eff_prev_kb > 0:
							enemy_knocked_back.emit(prev_e, prev_e.current_distance, eff_prev_kb)
							combat_log.emit("     ↳ ☄ [확산 격발] 인접 적 [%s]에게 넉백 %d 전파" % [prev_e.data.display_name, eff_prev_kb])
					if idx + 1 < alive_list.size():
						var next_e: EnemyInstance = alive_list[idx + 1]
						var eff_next_kb := next_e.apply_knockback(splash_kb)
						if eff_next_kb > 0:
							enemy_knocked_back.emit(next_e, next_e.current_distance, eff_next_kb)
							combat_log.emit("     ↳ ☄ [확산 격발] 인접 적 [%s]에게 넉백 %d 전파" % [next_e.data.display_name, eff_next_kb])

		# ── 6. 둔화 ──
		var slow_val := bullet.slow
		if _has_part(Enums.PartID.UNDERFLOW) and is_last and slow_val > 0:
			slow_val *= 2
			combat_log.emit("   ↳ 💥 [언더플로우] 피날레 둔화 2배 증폭 적용!")
			
		if slow_val > 0:
			target.apply_slow(slow_val)
			combat_log.emit("   ↳ 둔화 -%d (다음 턴)" % slow_val)

		# ── 7. 적 사망 체크 ──
		if target.is_dead():
			combat_log.emit("💀 [%s] 처치!" % target.data.display_name)
			enemy_killed.emit(target)
			
			# 전투 통계 가산
			battle_stats.total_kills += 1
			battle_stats.total_kill_dist_sum += target.current_distance
			battle_stats.kills_this_turn += 1
			
			# 탱커 파쇄 처치 판정 (관통이 방어력을 넘지 않았는데 처치)
			if target.data.archetype == Enums.EnemyArchetype.TANK:
				if calc_bullet.penetration <= target.current_def:
					battle_stats.shred_only_tank_kills += 1
					
			# 태세병 슬로우 없이 처치 판정
			if target.current_stance != Enums.EnemyStance.NONE and target.slow_stacks == 0:
				battle_stats.stance_kills_without_slow += 1
			
			# 돌격형(Bruiser) 총기 시그니처: 끌어당김
			if _gun_is("shotgun"):
				var alive_list := get_alive_enemies()
				var next_enemy: EnemyInstance = null
				var min_dist := 999
				for e in alive_list:
					if e != target and e.current_distance < min_dist:
						min_dist = e.current_distance
						next_enemy = e
				if next_enemy:
					next_enemy.current_distance = maxi(next_enemy.current_distance - 1, 0)
					combat_log.emit("   ↳ ⚠ [돌격형 시그니처] 끌어당김 발동! 다음 적 [%s]이 1칸 전진! (현재 거리 %dm)" % [next_enemy.data.display_name, next_enemy.current_distance])
					enemy_moved.emit(next_enemy, next_enemy.current_distance, -1)
			
			# 체이서 (CHASER): 처치 성공 시 다음 사격 PEN +2 누적
			if _has_part(Enums.PartID.CHASER):
				chaser_pen_bonus += 2
				combat_log.emit("   ↳ 🚀 [체이서] 처치 성공! 다음 격발 PEN +2 충전")
				
			# 리코일 푸시 (RECOIL_PUSH): 처치 시 뒷 적들 넉백 +1
			if _has_part(Enums.PartID.RECOIL_PUSH):
				combat_log.emit("   ↳ 🛡 [리코일 푸시] 처치 반동 발동!")
				for e in enemies:
					if not e.is_dead() and e != target:
						e.apply_knockback(1)
						enemy_knocked_back.emit(e, e.current_distance, 1)
						combat_log.emit("     ↳ [%s] 강제 넉백 1칸 → 거리 %d" % [e.data.display_name, e.current_distance])
	else:
		combat_log.emit("🔫 %s → [%s] 빗나감! (ACC %d < EVA %d)" % [
			bullet.display_name, target.data.display_name, bullet.accuracy, target.current_evasion
		])
		var remaining_durability := target.current_hp if not target.is_stack_sponge else target.barrier_cells
		bullet_fired.emit(bullet, false, 0, target, remaining_durability)
		battle_stats.misses += 1

	# 탄약 순환 자원 정산
	if is_refunded:
		discard_pile.append(bullet)
		combat_log.emit("   ↳ ♻ [순환] 유효 적중! 탄환이 버린 더미로 이동했습니다.")
	else:
		exile_pile.append(bullet)
		bullet_exiled.emit(bullet)
		combat_log.emit("   ↳ 💀 [소멸] 관통 실패 또는 빗나감! 탄환이 이번 전투에서 소멸(Exile) 처리되었습니다.")
	piles_updated.emit(draw_pile, discard_pile, exile_pile)

	# 직전 클래스 업데이트
	last_fired_class = bullet.weapon_class

	# 탄창 상태 갱신
	magazine_updated.emit(magazine.get_remaining(), magazine.get_capacity())

	# ── 전체 적 사망 체크 (승리 조건) ──
	if _check_all_enemies_dead():
		state = State.WON
		if target:
			final_kill_distance = target.current_distance
		# [전탄 소모] 판정 — 탄창을 한 발도 남기지 않고 비운 채 이겼는가.
		# 제압형(연발) 해금 조건. 연발이 강제하는 행동을 단발 총으로 미리 연습시킨다.
		if magazine.is_empty():
			battle_stats.magazine_emptied_wins += 1
		combat_log.emit("★ 모든 적 처치! 승리!")
		encounter_won.emit()
		return

	# ── 모든 생존 적 전진 (매발 전진) ──
	if advance_enemies:
		eject_used_this_turn = false
		_all_enemies_advance()
		if state == State.LOST:
			return

	# ── 적 상태 변환 체크 ──
	if target and not target.is_dead():
		_check_enemy_stance_shift(target)

	# 탄창 비었으면 알림
	if magazine.is_empty() and state == State.PLAYER_TURN:
		combat_log.emit("⚠ 탄창 소진! 리로드가 필요합니다.")



## 적 대미지 적용 공통 헬퍼 (스택 스펀지 포함)
func _apply_damage_to_enemy(enemy: EnemyInstance, dmg_amount: int) -> void:
	if enemy.is_stack_sponge:
		enemy.barrier_cells = maxi(enemy.barrier_cells - 1, 0)
		combat_log.emit("   [color=#33ffff]🛡️ 배리어 충전 셀 차감! 남은 보호막: %d/3[/color]" % enemy.barrier_cells)
		# 최종 보스: 배리어 소진 시 페이즈 2(코어 노출)로 전환한다.
		# 전환에 성공하면 is_stack_sponge가 해제되고 실체 HP가 노출되어 사망 처리되지 않는다.
		if enemy.check_phase_transition():
			combat_log.emit("   [color=#ff5555]⚠️ 배리어 붕괴! 코어 노출 — 페이즈 2 개시! (실체 HP %d)[/color]" % enemy.current_hp)
			enemy_stance_changed.emit(enemy, enemy.current_stance)
	else:
		enemy.apply_damage(dmg_amount)


## 클래스 이름 텍스트 변환
func _class_name(cls: Enums.WeaponClass) -> String:
	match cls:
		Enums.WeaponClass.PISTOL: return "권총(9mm)"
		Enums.WeaponClass.SMG: return "기관단총(.45ACP)"
		Enums.WeaponClass.RIFLE: return "소총(5.56mm)"
		Enums.WeaponClass.DMR: return "지정사수(7.62mm)"
		Enums.WeaponClass.SHOTGUN: return "샷건(12Gauge)"
		Enums.WeaponClass.UNIVERSAL: return "교차구경"
	return "?"


## 빼내기 요청 (Unload)
func request_unload() -> void:
	if state != State.PLAYER_TURN:
		return
	if magazine.is_empty():
		combat_log.emit("⚠ 탄창이 이미 비어있어 빼낼 탄환이 없습니다.")
		return
		
	# 퀵로드 (QUICK_LOAD) 파츠: 맨 위 탄을 잃지 않고 덱으로 빼내고, 대신 맨 바닥 탄을 잃음
	if _has_part(Enums.PartID.QUICK_LOAD):
		var bullet := magazine.unload()
		if bullet:
			combat_log.emit("⚡ [퀵로드] 맨 위 탄환 [%s]을(를) 즉시 환수하여 보관했습니다!" % bullet.display_name)
			bullet_unloaded.emit(bullet)
			
			if magazine.get_remaining() > 0:
				var lost_bullet = magazine._bullets.pop_front() # 탄창 바닥 탄 제거
				exile_pile.append(lost_bullet)
				bullet_exiled.emit(lost_bullet)
				combat_log.emit("   ↳ ⚠ [퀵로드 패널티] 탄창 바닥의 [%s] 탄환이 유실되어 폐기되었습니다." % lost_bullet.display_name)
				
			magazine_updated.emit(magazine.get_remaining(), magazine.get_capacity())
			piles_updated.emit(draw_pile, discard_pile, exile_pile)
			
			if RunManager.infiltration_risk_level >= 5:
				combat_log.emit("🚨 [완벽 봉쇄령] 빼내기 전술 기동의 후폭풍으로 모든 적이 1칸 전진합니다!")
				_all_enemies_advance()
			
			if magazine.is_empty() and state == State.PLAYER_TURN:
				combat_log.emit("⚠ 탄창 소진! 리로드가 필요합니다.")
		return
		
	var bullet := magazine.unload()
	if bullet:
		exile_pile.append(bullet)
		bullet_exiled.emit(bullet)
		combat_log.emit("🗑 [%s] 탄환을 빼내어 이번 인카운터 풀에서 제외(소멸)했습니다." % bullet.display_name)
		bullet_unloaded.emit(bullet)
		magazine_updated.emit(magazine.get_remaining(), magazine.get_capacity())
		piles_updated.emit(draw_pile, discard_pile, exile_pile)
		
		if RunManager.infiltration_risk_level >= 5:
			combat_log.emit("🚨 [완벽 봉쇄령] 빼내기 전술 기동의 후폭풍으로 모든 적이 1칸 전진합니다!")
			_all_enemies_advance()
		
		if magazine.is_empty() and state == State.PLAYER_TURN:
			combat_log.emit("⚠ 탄창 소진! 리로드가 필요합니다.")


## 인게임 중간 장전(납탄) 요청
func request_insert_bullet(bullet: BulletData) -> void:
	if state != State.PLAYER_TURN:
		return
	var cap := gun.magazine_capacity
	var has_ch := gun.has_chamber
	var max_cap := cap + (1 if has_ch else 0)
	if magazine.get_remaining() >= max_cap:
		combat_log.emit("⚠ 탄창이 가득 차서 납탄할 수 없습니다.")
		return
		
	magazine.insert_bullet(bullet)
	battle_stats.lead_bullets_fired += 1
	combat_log.emit("📥 [%s] 탄환을 탄창 맨 위에 장전했습니다. (가방을 닫으면 템포 세금이 적용됩니다)" % bullet.display_name)

	# 템포 세금 플래그 활성화 (모든 적 1회 전진 보장용)
	has_inserted_bullet_this_turn = true

	# 납탄 봉인
	if state == State.PLAYER_TURN:
		_insert_seal_active = true

	magazine_updated.emit(magazine.get_remaining(), magazine.get_capacity())

## 가방 닫힘 시 템포 세금 정산 (적이 단 한 번만 전진하도록 보장)
func apply_bullet_insertion_tax() -> void:
	if has_inserted_bullet_this_turn:
		combat_log.emit("🚨 [템포 세금] 납탄 장전 완료로 인해 모든 적이 1칸 전진합니다!")
		_all_enemies_advance()
		has_inserted_bullet_this_turn = false


func _check_enemy_stance_shift(target: EnemyInstance) -> void:
	# 태세 고정 (STANCE_LOCK): 전투당 1회, 적의 태세 전환을 무효화해 현재 태세를 유지시킨다.
	# 태세 전환병(Scrambler) 축의 카운터 — 준비한 관통/명중 계획이 뒤집히는 것을 막는다.
	if _has_part(Enums.PartID.STANCE_LOCK) and not _stance_lock_used:
		if target.shot_counter + 1 >= target.stance_shift_interval and target.current_stance != Enums.EnemyStance.NONE:
			_stance_lock_used = true
			target.shot_counter = 0  # 전환 직전 카운터를 되돌려 이번 전환을 무효화
			combat_log.emit("   ↳ 🔒 [태세 고정] 전환 신호를 차단했습니다! [%s]의 태세가 유지됩니다." % target.data.display_name)
			return

	if target.apply_shot_and_check_shift():
		var stance_str := ""
		match target.current_stance:
			Enums.EnemyStance.IRON_SHIELD:
				stance_str = "물리 장갑 태세 (DEF 6 / EVA 1 / SPD 1)"
			Enums.EnemyStance.ACTIVE_DODGER:
				stance_str = "회피 돌격 태세 (DEF 0 / EVA 7 / SPD 3)"
		combat_log.emit("🔄 [태세 교대] [%s]가 '%s'로 변환!" % [target.data.display_name, stance_str])
		enemy_stance_changed.emit(target, target.current_stance)


## 리로드 요청
func request_reload() -> void:
	if state != State.PLAYER_TURN:
		return

	var remaining := magazine.get_remaining()
	if remaining > 0:
		combat_log.emit("남은 %d발을 가방으로 반환하고 리로드합니다." % remaining)
		while not magazine.is_empty():
			var b := magazine.unload()
			if b:
				draw_pile.append(b)

	magazine.clear()
	# 셋업 버프는 리로드로 소멸한다.
	# ⚠️ 유지되면 "탄창 끝에 셋업 깔아두기"가 항상 이득이 되어 리로드 공백의 비용이 흐려진다.
	pending_buff_acc = 0
	pending_buff_pen = 0

	var turns := gun.reload_turns
	reload_turns_remaining = turns
	state = State.RELOADING
	reload_started.emit(reload_turns_remaining)
	combat_log.emit("🔄 리로드 시작! (%d턴 소요)" % reload_turns_remaining)

	while reload_turns_remaining > 0:
		reload_turns_remaining -= 1
		_all_enemies_advance()
		if state == State.LOST:
			return

	# 리로드 완료: 버린 카드 더미(discard_pile)를 가방(draw_pile)에 합산 및 셔플
	if not discard_pile.is_empty():
		draw_pile.append_array(discard_pile)
		discard_pile.clear()
		draw_pile.shuffle()
		combat_log.emit("♻ 버린 더미의 탄환들이 가방(Draw Pile)으로 셔플 순환되었습니다.")
	draw_pile_updated.emit(draw_pile)
	piles_updated.emit(draw_pile, discard_pile, exile_pile)

	reload_finished.emit()
	combat_log.emit("🔄 리로드 완료!")
	magazine_updated.emit(0, magazine.get_capacity())
	_enter_loading_phase()


## 거리 1에 다다른 최근접 적에 대해 전투당 1회 무상 자동 격퇴 발동 검사.
## 격퇴 발동 성공하여 사망 정산을 우회해야 하는 경우 true 반환.
func _check_and_trigger_buttstroke(e: EnemyInstance) -> bool:
	if e.current_distance == 1 and not buttstroke_used_this_encounter:
		buttstroke_used_this_encounter = true
		
		# 저항 무시 2칸 강제 넉백 (1 ➡️ 3)
		e.current_distance = e.current_distance + 2
		# 1턴 기절 (둔화 99 누적)
		e.apply_slow(99)
		
		combat_log.emit("🛡️ [긴급 격퇴] 적 [%s]이 요원의 거리에 도달했습니다! 개머리판으로 격퇴하여 2m 넉백 및 기절 부여! (남은 생존 장치: 0)" % e.data.display_name)
		buttstroke_triggered.emit(e, e.current_distance)
		return true
	return false


## 모든 생존 적 전진 처리
func _all_enemies_advance() -> void:
	for e in enemies:
		if e.is_dead():
			continue
		var speed_used := e.advance()

		# 이동형 적은 먼저 전진을 정산한다. 최종 보스 페이즈 2처럼
		# "전진 + 차징"을 동시에 수행하는 적도 있으므로 차저 여부와 이동을 분리한다.
		if speed_used > 0 or not e.is_charger:
			enemy_moved.emit(e, e.current_distance, speed_used)
			combat_log.emit("👣 [%s] 전진 %d칸 → 거리 %d" % [e.data.display_name, speed_used, e.current_distance])

			# 자동 긴급 격퇴 검사 추가
			if _check_and_trigger_buttstroke(e):
				pass
			elif e.is_at_player():
				state = State.LOST
				combat_log.emit("💀 [%s]가 도달했습니다... 사망!" % e.data.display_name)
				player_died.emit()
				return

		# 차징은 아키타입 문자열이 아니라 런타임 기믹 플래그로 판정한다.
		# 일반 술사뿐 아니라 세라프와 L.O.B 코어도 같은 경로를 사용한다.
		if e.is_charger:
			var is_fired := e.advance_charger()
			if is_fired:
				combat_log.emit("⚠ [술사 경보] [%s]의 차징 공격 발동! 적 대열이 플레이어 방향으로 2칸 강제 전진!" % e.data.display_name)
				_caster_force_advance_all(2)
				if state == State.LOST:
					return
	
	_track_closest_approach()
	all_enemies_moved.emit()


## 술사 차징 공격 시 다른 적들을 2칸 강제 전진시킴
func _caster_force_advance_all(amount: int) -> void:
	for e in enemies:
		# 차징 주체와 다른 차저는 고정 포대다. 강제전진 대상은 호위 대열뿐이다.
		if e.is_dead() or e.is_charger:
			continue
		e.current_distance = maxi(e.current_distance - amount, 0)
		enemy_moved.emit(e, e.current_distance, amount)
		combat_log.emit("👣 [술사 강제전진] [%s]가 %d칸 강제 이동당했습니다! 거리 %d" % [e.data.display_name, amount, e.current_distance])
		
		# 자동 긴급 격퇴 검사 추가
		if _check_and_trigger_buttstroke(e):
			continue

		if e.is_at_player():
			state = State.LOST
			combat_log.emit("💀 [%s]가 도달했습니다... 사망!" % e.data.display_name)
			player_died.emit()
			return
			
	_track_closest_approach()


## 적이 얼마나 가까이 붙었는지를 기록한다.
## 절대 거리(min_dist_allowed)와 **시작 거리 대비 비율**(min_dist_ratio)을 함께 남긴다.
## 비율 쪽이 승천 등급과 무관하게 "거리를 통제했는가"를 재는 지표다.
func _track_closest_approach() -> void:
	for e in enemies:
		if e.is_dead():
			continue
		battle_stats.min_dist_allowed = mini(battle_stats.min_dist_allowed, e.current_distance)
		var start := maxi(e.start_distance, 1)
		var ratio := float(e.current_distance) / float(start)
		battle_stats.min_dist_ratio = minf(battle_stats.min_dist_ratio, ratio)


## 전체 적 사망 검사
func _check_all_enemies_dead() -> bool:
	for e in enemies:
		if not e.is_dead():
			return false
	return true


## 피격 후 효과 처리
func _apply_post_hit_effects(bullet: BulletData, target: EnemyInstance, is_first: bool, _is_last: bool) -> void:
	match bullet.effect_type:
		Enums.BulletEffect.ARMOR_SHRED:
			target.apply_armor_shred(bullet.effect_value)
			armor_shredded.emit(target, target.current_def, bullet.effect_value)
			combat_log.emit("   ↳ 장갑 파쇄! DEF -%d → %d" % [
				bullet.effect_value, target.current_def
			])
		Enums.BulletEffect.OPENING_SHOT:
			target.apply_armor_shred(1)
			armor_shredded.emit(target, target.current_def, 1)
			if is_first:
				var eff_kb := target.apply_knockback(bullet.effect_value)
				if eff_kb > 0:
					enemy_knocked_back.emit(target, target.current_distance, eff_kb)
					combat_log.emit("   ↳ 선제 사격! 추가 넉백 +%d 및 장갑 파쇄 -1 적용 (실제 밀려남: %d칸)" % [bullet.effect_value, eff_kb])
				else:
					combat_log.emit("   ↳ 선제 사격! 넉백 저항으로 밀려나지 않음 (저항 %d, 장갑 파쇄 -1만 적용)" % target.knockback_resistance)
			else:
				combat_log.emit("   ↳ 견제 사격! 장갑 파쇄 -1 적용")
		_:
			pass


## 총기 시그니처 판정 — 표시명(문구 변경·현지화에 취약) 대신 리소스 ID로 안정 판정한다.
## 예: _gun_is("dmr") → res://resources/guns/dmr.tres
func _gun_is(gun_id: String) -> bool:
	return gun_is(gun_id)


## 총기 식별 — **리소스 ID로 판정한다.**
## ⚠️ 표시명 문자열 매칭을 쓰지 말 것. 표시명이 바뀌면 조용히 어긋난다
##    (실제로 시그니처가 발동하지 않던 결함의 원인이었다).
func gun_is(gun_id: String) -> bool:
	if gun == null:
		return false
	return gun.resource_path.get_file().get_basename() == gun_id


## 파츠 장착 여부 검사
func _has_part(part_id: Enums.PartID) -> bool:
	for p in equipped_parts:
		if p != null and p.part_id == part_id:
			return true
	return false


## 이젝트 요청 (곡예형 시그니처)
func request_eject() -> void:
	if state != State.PLAYER_TURN:
		return
	if magazine.is_empty():
		combat_log.emit("⚠ 탄창이 비어있어 이젝트할 탄환이 없습니다.")
		return
	if eject_used_this_turn:
		combat_log.emit("⚠ 이젝트 기믹은 턴당 1회만 사용할 수 있습니다.")
		return
		
	var bullet := magazine.unload()
	if bullet:
		var dup := bullet.duplicate()
		dup.damage = maxi(dup.damage - 1, 0)
		magazine._bullets.insert(0, dup)
		eject_used_this_turn = true
		
		combat_log.emit("⚡ [곡예형 시그니처] 이젝트 발동! 맨 위 [%s] 탄환을 맨 밑으로 이동했습니다. (이동된 탄환 DMG -1)" % bullet.display_name)
		magazine_updated.emit(magazine.get_remaining(), magazine.get_capacity())
