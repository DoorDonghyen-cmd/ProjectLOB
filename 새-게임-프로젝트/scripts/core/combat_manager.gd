class_name CombatManager
extends Node

const CaliberProfiles = preload("res://scripts/core/caliber_profiles.gd")
const PlaytestLoggerScript = preload("res://scripts/core/playtest_logger.gd")

## 화면 로그의 표준 태그와 실제 장착 파츠를 연결한다.
## 파츠 효과 메시지가 바뀌면 이 맵과 회귀 테스트도 함께 갱신해야 한다.
const PART_LOG_TOKENS := {
	Enums.PartID.DEEP_LOADER: "[딥로더]",
	Enums.PartID.RHYTHM_CHAMBER: "[리듬 챔버]",
	Enums.PartID.INTERRUPTER: "[인터럽터]",
	Enums.PartID.UNDERFLOW: "[언더플로우]",
	Enums.PartID.CHASER: "[체이서]",
	Enums.PartID.POINT_BLANK: "[돌격형 시그니처]",
	Enums.PartID.LONG_SHOT: "[롱샷]",
	Enums.PartID.EXECUTIONER: "[처형자]",
	Enums.PartID.RECOIL_PUSH: "[리코일 푸시]",
	Enums.PartID.HIGH_PRECISION: "[고정밀 총열]",
	Enums.PartID.ARMOR_PIERCING: "[철갑 총열]",
	Enums.PartID.SHRED_MUZZLE: "[파쇄 총구]",
	Enums.PartID.VERSATILE_CHAMBER: "[만능 약실]",
	Enums.PartID.TARGET_INDICATOR: "[표적 지시기]",
	Enums.PartID.CHAIN_ACC: "[연동 조준]",
	Enums.PartID.STANCE_FORESIGHT: "[태세 예지]",
	Enums.PartID.STANCE_LOCK: "[태세 고정]",
	Enums.PartID.INERTIA_FIRE: "[관성 격발]",
	Enums.PartID.BLIND_FIRE: "[블라인드파이어]",
	Enums.PartID.QUICK_LOAD: "[퀵로드]",
	Enums.PartID.SPREAD_SHOT: "[확산 격발]",
	Enums.PartID.MARKSMAN_SCOPE: "[저격경]",
}

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
## 기본 보급탄은 덱과 분리된 고정 슬롯 하나로 표시한다.
signal basic_supply_updated(bullet: BulletData, current: int, capacity: int)
signal buttstroke_triggered(enemy: EnemyInstance, new_distance: int)
## 경량탄 집중 표식. triggered=true면 이번 격발에서 집중 폭발이 발생했다.
signal focus_updated(enemy_inst: EnemyInstance, stacks: int, threshold: int, triggered: bool)
## 탄종 전용 연출 이벤트. kind = focus / rifle / shotgun.
signal ammo_family_triggered(
	kind: String,
	source: EnemyInstance,
	targets: Array,
	value: int
)

# ── 상태 ──
enum State { INACTIVE, LOADING, PLAYER_TURN, RELOADING, WON, LOST }

var state: State = State.INACTIVE
var gun: GunData
var magazine: Magazine
var enemies: Array[EnemyInstance] = []
var last_shot_hit: bool = false
var last_shot_effective: bool = false
var reload_turns_remaining: int = 0
var _insert_seal_active: bool = false
var eject_used_this_turn: bool = false
var has_inserted_bullet_this_turn: bool = false
var is_magazine_first_shot: bool = true
var _is_full_auto_burst: bool = false
var _burst_knockback_budget: int = 0

# ── 순환 탄약 & 긴급 격퇴 가변 상태 ──
var draw_pile: Array[BulletData] = []
var discard_pile: Array[BulletData] = []
var exile_pile: Array[BulletData] = []
var basic_supply_bullet: BulletData = null
var basic_supply_current: int = 0
var basic_supply_capacity: int = 0
var buttstroke_used_this_encounter: bool = false

# ── 총기 파츠 및 기믹 상태 ──
var equipped_parts: Array[PartData] = []
var chaser_pen_bonus: int = 0
var target_marker_active: bool = false
var same_stance_hit_count: int = 0
var last_stance: Enums.EnemyStance = Enums.EnemyStance.NONE
var last_inertia_target: EnemyInstance = null
var consecutive_role_count: int = 0
## 적 인스턴스별 경량탄 집중. 적 사망·재장전·인카운터 종료 시 제거한다.
var focus_stacks: Dictionary = {}

## ── 셋업 버프 (정본: docs/gdd/22_ammo_expansion.md §22.2) ──
## **다음 1발**에만 적용된다. 탄창 전체 지속이면 "셋업 하나 깔고 나머지 전부 고화력"이
## 최적해가 되어 조합이 다시 단순해지므로, 1발 한정이라야 버프-딜러 교차가 강제된다.
## 중첩 없이 덮어쓰며, 리로드 시 소멸한다(탄창 끝에 셋업 깔아두기 방지).
var pending_buff_acc: int = 0
var pending_buff_pen: int = 0
## 유도탄·정렬탄이 부여하는 현재 탄창 잔여 전체 버프. 리로드 시 소멸한다.
var magazine_buff_acc: int = 0
var magazine_buff_pen: int = 0
var visible_magazine_slots: int = 2
var final_kill_distance: int = 99

# ── 탄환 역할 기반 순서 기억 ──
## 구경은 총기의 고정 프로필이며, 런 중 순서 빌드는 공격·연계·제어 역할 교대로 만든다.
var last_fired_role: String = ""

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

# ── 플레이테스트 텔레메트리 ──
var telemetry_started_at: String = ""
var telemetry_initial_enemies: Array[Dictionary] = []
var telemetry_shots: Array[Dictionary] = []
var telemetry_family_events: Array[Dictionary] = []
var telemetry_part_events: Array[Dictionary] = []
var telemetry_combat_log: Array[String] = []
var telemetry_bullet_summary: Dictionary = {}
var telemetry_family_summary: Dictionary = {}
var telemetry_part_summary: Dictionary = {}
var telemetry_reload_count: int = 0
var telemetry_reload_turns: int = 0
var _telemetry_pending_family_events: Array[Dictionary] = []


func _init() -> void:
	combat_log.connect(_capture_telemetry_log)
	bullet_fired.connect(_capture_telemetry_shot)
	ammo_family_triggered.connect(_capture_telemetry_family)
	reload_started.connect(_capture_telemetry_reload)


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


## 인카운터를 시작한다. 기본 보급탄은 전술 덱과 분리해 총기 장전 한도만큼 지급한다.
## 마지막 인자는 선택 사항이라 테스트용 임의 전투와 레거시 호출은 기존 동작을 유지한다.
func start_encounter(
	gun_data: GunData,
	enemy_datas: Array[EnemyData],
	deck_bullets: Array[BulletData],
	parts: Array[PartData] = [],
	supply_bullet: BulletData = null
) -> void:
	_reset_telemetry()
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
	last_shot_effective = false
	_insert_seal_active = false
	has_inserted_bullet_this_turn = false
	last_fired_role = ""
	is_magazine_first_shot = true
	_is_full_auto_burst = false
	_burst_knockback_budget = 0
	focus_stacks.clear()
	
	# 탄약 순환 자원 데이터 및 긴급 격퇴 초기화
	basic_supply_bullet = supply_bullet
	basic_supply_capacity = _max_load_capacity() if basic_supply_bullet != null else 0
	basic_supply_current = basic_supply_capacity
	draw_pile.clear()
	for bullet in deck_bullets:
		# 구 세션/세이브가 덱 안에 기반탄을 보유해도 고정 보급과 중복시키지 않는다.
		if basic_supply_bullet != null and _is_basic_supply_bullet(bullet):
			continue
		draw_pile.append(bullet)
	discard_pile.clear()
	exile_pile.clear()
	buttstroke_used_this_encounter = false
	draw_pile_updated.emit(draw_pile)
	piles_updated.emit(draw_pile, discard_pile, exile_pile)
	basic_supply_updated.emit(basic_supply_bullet, basic_supply_current, basic_supply_capacity)
	
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
	last_inertia_target = null
	consecutive_role_count = 0
	pending_buff_acc = 0
	pending_buff_pen = 0
	magazine_buff_acc = 0
	magazine_buff_pen = 0
	
	# 예고창 슬롯 수 보정 (Scope, Blind Fire 파츠)
	visible_magazine_slots = gun.preview_window_size if gun != null else 2
	if _has_part(Enums.PartID.SCOPE):
		visible_magazine_slots += 1
	if _has_part(Enums.PartID.BLIND_FIRE):
		visible_magazine_slots = max(1, visible_magazine_slots - 1)
		
	_stance_lock_used = false
	telemetry_initial_enemies = _telemetry_enemy_snapshots()

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

	# UI 상태와 별개로 실제 보유량을 다시 검증한다. 기본탄은 고정 보급 잔량에서,
	# 전술탄은 draw_pile에서 꺼내므로 중복 장전이 생기지 않는다.
	var accepted: Array[BulletData] = []
	for b in bullets:
		if accepted.size() >= _max_load_capacity():
			break
		if _is_basic_supply_bullet(b):
			if basic_supply_current <= 0:
				continue
			basic_supply_current -= 1
			accepted.append(b)
			continue
		var draw_idx := _find_draw_pile_index(b)
		if draw_idx < 0:
			continue
		accepted.append(b)
		draw_pile.remove_at(draw_idx)

	magazine.load_bullets(accepted)
	draw_pile_updated.emit(draw_pile)
	piles_updated.emit(draw_pile, discard_pile, exile_pile)
	basic_supply_updated.emit(basic_supply_bullet, basic_supply_current, basic_supply_capacity)
	
	state = State.PLAYER_TURN
	eject_used_this_turn = false
	magazine_updated.emit(magazine.get_remaining(), magazine.get_capacity())
	is_magazine_first_shot = true
	combat_log.emit("── 탄창 장전 완료! %d발 ──" % magazine.get_remaining())


## 약실을 포함한 실제 최대 장전 수. 기본 보급 상한과 UI가 같은 정본을 사용한다.
func _max_load_capacity() -> int:
	if gun == null:
		return 0
	return gun.magazine_capacity + (1 if gun.has_chamber else 0)


func _is_basic_supply_bullet(bullet: BulletData) -> bool:
	return bullet != null \
		and basic_supply_bullet != null \
		and bullet.is_basic \
		and bullet.weapon_class == basic_supply_bullet.weapon_class


func _find_draw_pile_index(bullet: BulletData) -> int:
	if bullet == null:
		return -1
	for i in range(draw_pile.size()):
		var candidate := draw_pile[i]
		if candidate == bullet or (
			candidate != null
			and candidate.resource_path == bullet.resource_path
			and not bullet.resource_path.is_empty()
		) or (candidate != null and candidate.display_name == bullet.display_name):
			return i
	return -1


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
		acc += CaliberProfiles.bonus_for(b, gun, "accuracy")
		pen += CaliberProfiles.bonus_for(b, gun, "penetration")
	acc += magazine_buff_acc
	pen += magazine_buff_pen
	var acc_without_adjacent := acc
	var pen_without_adjacent := pen
	acc += pending_buff_acc
	pen += pending_buff_pen
	var target := _get_nearest_enemy()
	var critical := false
	var family := CaliberProfiles.family_for_gun(gun)
	var focus_current := get_focus_stacks(target)
	var focus_will_trigger := false
	var line_targets: Array[EnemyInstance] = []
	var scatter_targets: Array[EnemyInstance] = []
	if target != null:
		var hit_without := acc_without_adjacent >= target.current_evasion
		var pen_without := pen_without_adjacent >= target.current_def
		var hit_with := acc >= target.current_evasion
		var pen_with := pen >= target.current_def
		critical = hit_with and pen_with and (not hit_without or not pen_without)
		if hit_with and pen_with:
			focus_will_trigger = family == Enums.AmmoFamily.LIGHT \
				and focus_current + 1 >= CaliberProfiles.FOCUS_THRESHOLD
			var snapshot := _alive_enemies_by_distance()
			line_targets = _preview_line_targets(b, target, pen, snapshot)
			scatter_targets = _preview_scatter_targets(target, snapshot, line_targets)
	return {
		"bullet": b,
		"acc": acc,
		"pen": pen,
		"buffed_acc": pending_buff_acc > 0,
		"buffed_pen": pending_buff_pen > 0,
		"magazine_buff_acc": magazine_buff_acc,
		"magazine_buff_pen": magazine_buff_pen,
		"critical": critical,
		"permanent_loss_on_failure": not _bullet_is_caliber_safe(b),
		"ammo_family": family,
		"focus_current": focus_current,
		"focus_threshold": CaliberProfiles.FOCUS_THRESHOLD,
		"focus_will_trigger": focus_will_trigger,
		"line_targets": line_targets,
		"scatter_targets": scatter_targets,
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
	_is_full_auto_burst = true
	_burst_knockback_budget = 2

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
			_is_full_auto_burst = false
			return

	# ── 버스트 전체를 1턴으로 정산: 적 전진 1회 ──
	_is_full_auto_burst = false
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
	var role_changed := not last_fired_role.is_empty() and bullet.role != last_fired_role
	if bullet.role == last_fired_role:
		consecutive_role_count += 1
	else:
		consecutive_role_count = 1

	# ── 1. 명중 판정 파츠 가산 ──
	var part_acc_bonus := 0
	
	# 연동 조준 (CHAIN_ACC): 직전 탄 명중 시 ACC +2
	if _has_part(Enums.PartID.CHAIN_ACC) and last_shot_hit:
		part_acc_bonus += 2
		combat_log.emit("   ↳ 🎯 [연동 조준] 직전 명중으로 ACC +2 적용")
		
	# 만능 약실: 직전과 **역할이 다르면** ACC +1 (PEN은 아래에서 +1).
	# 구경은 고정 프로필이므로 공격·연계·제어 역할 교대가 LIFO 순서 빌드를 담당한다.
	var versatile_active := _has_part(Enums.PartID.VERSATILE_CHAMBER) and role_changed
	if versatile_active:
		part_acc_bonus += 1
		combat_log.emit("   ↳ 🔧 [만능 약실] 역할 교대로 ACC +1 · PEN +1")

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
		# 전환 주기는 적마다 다르다(일반 태세병 3발, 실험체 Ω 2발).
		# 이번 격발이 실제 전환을 일으키는지를 데이터 기반으로 판단한다.
		if target.shot_counter + 1 >= target.stance_shift_interval:
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
	calc_bullet_acc.accuracy += part_acc_bonus + magazine_buff_acc + buff_acc

	var hit := DamageCalculator.check_hit(calc_bullet_acc, target_evasion, gun)
	var calc_bullet_without_adjacent := calc_bullet_acc.duplicate()
	calc_bullet_without_adjacent.accuracy -= buff_acc
	var hit_without_adjacent := DamageCalculator.check_hit(
		calc_bullet_without_adjacent, target_evasion, gun
	)
	# 콤보 판정은 "직전 격발"의 명중 여부를 봐야 하므로 덮어쓰기 전에 보존한다.
	# (보존하지 않으면 현재 격발의 명중 여부를 읽어 첫 발부터 항상 발동하는 버그가 된다)
	var prev_shot_effective := last_shot_effective
	last_shot_hit = hit

	if hit:
		# 다중 타격 대상은 주 피해 전에 고정한다. 주 대상 사망으로 생존 배열 인덱스가
		# 당겨져도 같은 격발의 관통·확산 대상이 바뀌면 안 된다.
		var formation_snapshot := _alive_enemies_by_distance()
		var collateral_kills: Array[EnemyInstance] = []
		var scatter_targets: Array[EnemyInstance] = []
		var family_events: Array[Dictionary] = []

		# ── 2. 대미지 및 관통 파츠 가산 ──
		var part_dmg_bonus := 0
		var part_pen_bonus := magazine_buff_pen + buff_pen

		# 철갑 총열 (ARMOR_PIERCING): **탄창 첫 탄**에 PEN +2 (선두 관통)
		# ⚠️ 상시 PEN이 아니라 스택 위치 조건이다. 관통 버프탄과 겹치지 않도록 LIFO 고유의
		#    "첫 탄" 축을 쓴다. 연발에서 상시 PEN+1은 탄창 전체를 뒤집어 특히 위험했다.
		if _has_part(Enums.PartID.ARMOR_PIERCING) and is_first:
			part_pen_bonus += 2
			combat_log.emit("   ↳ 🛡 [철갑 총열] 선두 탄 PEN +2")

		# 만능 약실: 역할 교대일 때 PEN +1 (위 ACC +1과 한 쌍)
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
				
		# 리듬 챔버: 동일 역할의 짝수 번째 연속 격발에 DMG +1
		# ⚠️ 연속 횟수를 그대로 보너스로 쓰면 연발 6발에서 +20이 되어 발사 방식이
		#    곧 지배 전략이 된다. 2·4·6번째 박자만 보상해 슬롯 가치만 남긴다.
		if _has_part(Enums.PartID.RHYTHM_CHAMBER):
			if consecutive_role_count % 2 == 0:
				part_dmg_bonus += 1
				combat_log.emit("   ↳ 🎶 [리듬 챔버] 동일 역할 %d번째 박자! DMG +1" % consecutive_role_count)
			
		# 인터럽터: 직전 탄과 역할이 다를 시 DMG 보너스 (+3)
		if _has_part(Enums.PartID.INTERRUPTER) and role_changed:
			part_dmg_bonus += 3
			combat_log.emit("   ↳ 🔀 [인터럽터] 역할 교대 격발! DMG +3 가산")
				
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
			var gambler_bonus := int(floori(float(depth) / 2.0))
			part_dmg_bonus += gambler_bonus
			combat_log.emit("   ↳ 🎲 [도박형 시그니처] 올인 격발! 깊이 %d단계 보너스로 DMG +%d 가산!" % [depth, gambler_bonus])

		# v6 피해 순서: 탄·총기·탄 조건 → 결정형 크리티컬 → 파츠 정액.
		# 파츠 보너스를 먼저 배율에 넣으면 크리티컬이 탄환 빌드가 아니라 파츠 증폭기가 된다.
		var calc_bullet := bullet.duplicate()
		calc_bullet.penetration += part_pen_bonus
		var core_damage := DamageCalculator.calculate_damage(calc_bullet, target.current_def, gun)
		var gate_total_pen := bullet.penetration + part_pen_bonus
		var gate_pen_without_adjacent := gate_total_pen - buff_pen
		if gun != null:
			gate_total_pen += gun.passive_pen_bonus
			gate_pen_without_adjacent += gun.passive_pen_bonus
			var caliber_pen := CaliberProfiles.bonus_for(bullet, gun, "penetration")
			gate_total_pen += caliber_pen
			gate_pen_without_adjacent += caliber_pen
		var penetrated := gate_total_pen >= target.current_def
		var penetrated_without_adjacent := gate_pen_without_adjacent >= target.current_def
		var critical := penetrated and hit and (
			not hit_without_adjacent or not penetrated_without_adjacent
		)
		var breakdown := DamageCalculator.damage_breakdown(calc_bullet, target.current_def, gun)

		# ── 2.3 마무리탄: 배율이 아닌 정액 +4 ──
		if bullet.effect_type == Enums.BulletEffect.LAST_SHOT and is_last and core_damage > 0:
			core_damage += bullet.effect_value
			breakdown += " + [막탄 보너스] %d" % bullet.effect_value
			combat_log.emit("   ↳ 🎯 [마무리탄] 탄창 최종 격발! 피해 +%d" % bullet.effect_value)

		# ── 2.4 연쇄탄: 직전 '명중'이 아니라 직전 유효 적중 ──
		if bullet.effect_type == Enums.BulletEffect.COMBO and prev_shot_effective and core_damage > 0:
			core_damage += bullet.effect_value
			breakdown += " + [연쇄 보너스] %d" % bullet.effect_value
			combat_log.emit("   ↳ 🔥 [연쇄탄] 직전 유효 적중 연계! 피해 +%d" % bullet.effect_value)

		# ── 2.5 교대탄: 직전 탄환과 역할이 다를 때 발동 ──
		if bullet.effect_type == Enums.BulletEffect.CALIBER_DIFF \
				and role_changed \
				and core_damage > 0:
			core_damage += bullet.effect_value
			breakdown += " + [역할 교대] %d" % bullet.effect_value
			combat_log.emit("   ↳ ⚡ [교대탄] 직전 역할(%s)과 달라 피해 +%d" % [
				last_fired_role, bullet.effect_value
			])

		var damage := core_damage
		if critical and damage > 0:
			var before_critical := damage
			damage = floori(float(damage) * 1.5)
			breakdown += " x [결정형 크리티컬 1.5]"
			combat_log.emit("   ↳ ✦ [크리티컬] 보조탄으로 게이트 개방! 피해 %d → %d" % [
				before_critical, damage
			])

		# 샷건은 원거리에서도 명중할 수 있지만 산개로 주 피해가 약해진다.
		# ACC를 낮춰 완전 무효로 만들지 않고, 최소 1의 견제 피해로 접근 턴을 의미 있게 유지한다.
		if _gun_is("shotgun") and target.current_distance > CaliberProfiles.SHOTGUN_MAX_RANGE:
			var before_attenuation := damage
			damage = CaliberProfiles.shotgun_damage_for_distance(damage, target.current_distance)
			if damage < before_attenuation:
				breakdown += " + [원거리 산개] -%d" % (before_attenuation - damage)
				combat_log.emit("   ↳ ⚠ [원거리 산개] 주 피해 %d → %d" % [
					before_attenuation, damage
				])

		# 관성 격발: 같은 적·같은 태세에 대한 유효 적중 3회마다 정액 +2.
		# 과거 무제한 +1 누적은 연발에서 자동 폭증했으므로 3회 주기 보상으로 제한한다.
		if _has_part(Enums.PartID.INERTIA_FIRE):
			if _advance_inertia_chain(target, damage > 0):
				part_dmg_bonus += 2
				combat_log.emit("   ↳ 📈 [관성 격발] 동일 태세 유효 적중 3회! DMG +2")

		# 보조 타격은 탄·총기·탄 조건·크리티컬까지만 복제한다.
		# 이후의 파츠 정액, 집중, 처형은 주 대상 전용이다.
		var collateral_base_damage := damage
		if damage > 0:
			damage = maxi(damage + part_dmg_bonus, 0)

		# 경량탄 집중은 별도 피격이 아니라 이번 주 피해에 정액 합산한다.
		# 흡수체 배리어가 한 발에 두 칸 차감되거나 적중 효과가 재귀하지 않는다.
		var focus_result := _advance_focus(target, damage > 0)
		var focus_bonus := int(focus_result.get("bonus", 0))
		if focus_bonus > 0:
			damage += focus_bonus
			combat_log.emit("   ↳ ✦ [집중 폭발] 3회 유효 적중 완성! 피해 +%d" % focus_bonus)
		if bool(focus_result.get("updated", false)):
			family_events.append({
				"kind": "focus",
				"targets": [target],
				"value": focus_bonus,
			})

		# 처형자 (EXECUTIONER): 거리 1 이하에서 체력이 3 이하인 적 즉사
		if _has_part(Enums.PartID.EXECUTIONER) and target.current_distance <= 1 and target.current_hp <= 3:
			damage = target.current_hp + 10
			combat_log.emit("   ↳ 🗡 [처형자] 빈사 상태의 적 즉사 처형!")

		# ── 3. 대미지 적용 ──
		_apply_damage_to_enemy(target, damage)
		last_shot_effective = damage > 0
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
				Enums.BulletEffect.BUFF_MAG_ACC:
					magazine_buff_acc += bullet.effect_value
					combat_log.emit("   ↳ ✨ [유도] 탄창 잔여 ACC +%d" % bullet.effect_value)
				Enums.BulletEffect.BUFF_MAG_PEN:
					magazine_buff_pen += bullet.effect_value
					combat_log.emit("   ↳ ✨ [정렬] 탄창 잔여 PEN +%d" % bullet.effect_value)
		else:
			battle_stats.zero_damage_hits += 1

		# ── 3.5 탄종 계열 보조 타격 ──
		var collateral_result := _apply_family_collateral(
			bullet,
			target,
			collateral_base_damage,
			gate_total_pen,
			formation_snapshot
		)
		collateral_kills.assign(collateral_result.get("kills", []))
		scatter_targets.assign(collateral_result.get("scatter_targets", []))
		for event in collateral_result.get("events", []):
			family_events.append(event)
		# UI는 이 이벤트를 다음 bullet_fired 큐 항목에 붙여 탄환 도착 시 재생한다.
		for event in family_events:
			ammo_family_triggered.emit(
				str(event.get("kind", "")),
				target,
				event.get("targets", []),
				int(event.get("value", 0))
			)

		combat_log.emit("🔫 %s → [%s] 명중! %d 대미지" % [bullet.display_name, target.data.display_name, damage])
		combat_log.emit("   %s" % breakdown)
		var remaining_durability := target.current_hp if not target.is_stack_sponge else target.barrier_cells
		bullet_fired.emit(bullet, true, damage, target, remaining_durability)
		enemy_damaged.emit(target, damage, remaining_durability, true)

		# ── 4. 피격 후 효과 ──
		_apply_post_hit_effects(bullet, target, is_first, is_last)

		# 파쇄 총구 (SHRED_MUZZLE): 명중 시 적 DEF 영구 -1
		if _has_part(Enums.PartID.SHRED_MUZZLE):
			target.apply_armor_shred(1)
			armor_shredded.emit(target, target.current_def, 1)
			combat_log.emit("   ↳ ⚙ [파쇄 총구] 명중 피드백으로 적 DEF -1 영구 파쇄!")

		# ── 5. 넉백 ──
		var calc_bullet_kb := bullet.duplicate()
		calc_bullet_kb.damage += part_dmg_bonus
		calc_bullet_kb.penetration += part_pen_bonus
		
		var kb := DamageCalculator.calculate_knockback(calc_bullet_kb, gun)
		if _is_full_auto_burst and kb > 0:
			var requested_kb := kb
			kb = mini(kb, _burst_knockback_budget)
			_burst_knockback_budget = maxi(_burst_knockback_budget - kb, 0)
			if kb < requested_kb:
				combat_log.emit("   ↳ ⚠ [연발 제어 상한] 버스트 총 넉백 2칸 초과분 억제")

		# 샷건 자체 넉백은 초근접 보너스를 스스로 끊지 않도록 <=2m에서 제외하고,
		# 원거리에서는 적을 계속 밀어 접근을 봉쇄하지 않도록 >3m에서 제외한다.
		# 탄환 자체 넉백은 플레이어의 의도적 선택이므로 두 구간 모두 그대로 유지한다.
		if gun and _gun_is("shotgun") and (
			target.current_distance <= 2
			or target.current_distance > CaliberProfiles.SHOTGUN_MAX_RANGE
		):
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
				
			# 확산 격발 장치는 실제 확산 피해 대상으로만 넉백을 전파한다.
			if _has_part(Enums.PartID.SPREAD_SHOT) and not scatter_targets.is_empty():
				var splash_kb: int = maxi(1, floori(float(kb) * 0.5))
				for splash_target in scatter_targets:
					if splash_target == null or splash_target.is_dead():
						continue
					var eff_splash := splash_target.apply_knockback(splash_kb)
					if eff_splash > 0:
						enemy_knocked_back.emit(splash_target, splash_target.current_distance, eff_splash)
						combat_log.emit("     ↳ ☄ [확산 격발] [%s]에게 넉백 %d 전파" % [
							splash_target.data.display_name, eff_splash
						])

		# ── 6. 둔화 ──
		var slow_val := bullet.slow
		if _has_part(Enums.PartID.UNDERFLOW) and is_last and slow_val > 0:
			slow_val *= 2
			combat_log.emit("   ↳ 💥 [언더플로우] 피날레 둔화 2배 증폭 적용!")
			
		if slow_val > 0:
			target.apply_slow(slow_val)
			combat_log.emit("   ↳ 둔화 -%d (다음 턴)" % slow_val)

		# ── 7. 적 사망 체크 ──
		var killed_this_shot: Array[EnemyInstance] = collateral_kills.duplicate()
		if target.is_dead() and target not in killed_this_shot:
			killed_this_shot.append(target)
		_register_kills_for_shot(killed_this_shot, calc_bullet)
	else:
		_reset_inertia_chain()
		last_shot_effective = false
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

	# 직전 역할 업데이트
	last_fired_role = bullet.role

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


## 적별 경량탄 집중을 UI·테스트가 읽는 단일 정본.
func get_focus_stacks(target: EnemyInstance) -> int:
	if target == null:
		return 0
	return int(focus_stacks.get(target, 0))


## 경량탄 유효 적중을 3회 주기로 정산한다.
## 빗나감·도탄은 스택을 올리지도 지우지도 않는다.
func _advance_focus(target: EnemyInstance, effective: bool) -> Dictionary:
	var result := {
		"updated": false,
		"triggered": false,
		"stacks": get_focus_stacks(target),
		"bonus": 0,
	}
	if target == null or not effective \
			or CaliberProfiles.family_for_gun(gun) != Enums.AmmoFamily.LIGHT:
		return result

	var stacks := get_focus_stacks(target) + 1
	var triggered := stacks >= CaliberProfiles.FOCUS_THRESHOLD
	var bonus := 0
	if triggered:
		stacks = 0
		bonus = CaliberProfiles.focus_bonus_for_gun(gun)
	focus_stacks[target] = stacks
	focus_updated.emit(target, stacks, CaliberProfiles.FOCUS_THRESHOLD, triggered)
	combat_log.emit("   ↳ ◉ [경량탄 집중] %d/%d%s" % [
		stacks if not triggered else CaliberProfiles.FOCUS_THRESHOLD,
		CaliberProfiles.FOCUS_THRESHOLD,
		" — 폭발" if triggered else "",
	])
	result.updated = true
	result.triggered = triggered
	result.stacks = stacks
	result.bonus = bonus
	return result


func _clear_focus() -> void:
	for key in focus_stacks.keys():
		if key is EnemyInstance:
			focus_updated.emit(key, 0, CaliberProfiles.FOCUS_THRESHOLD, false)
	focus_stacks.clear()


## 관성 격발은 같은 적·같은 태세의 유효 적중만 잇는다.
## 3회째에 +2를 반환하고 주기를 0으로 되돌린다.
func _advance_inertia_chain(target: EnemyInstance, effective: bool) -> bool:
	if not effective or target == null:
		_reset_inertia_chain()
		return false
	if target != last_inertia_target or target.current_stance != last_stance:
		same_stance_hit_count = 1
	else:
		same_stance_hit_count += 1
	last_inertia_target = target
	last_stance = target.current_stance
	if same_stance_hit_count >= 3:
		same_stance_hit_count = 0
		return true
	return false


func _reset_inertia_chain() -> void:
	same_stance_hit_count = 0
	last_inertia_target = null
	last_stance = Enums.EnemyStance.NONE


func _alive_enemies_by_distance() -> Array[EnemyInstance]:
	var snapshot := get_alive_enemies()
	snapshot.sort_custom(func(a: EnemyInstance, b: EnemyInstance) -> bool:
		if a.current_distance == b.current_distance:
			return enemies.find(a) < enemies.find(b)
		return a.current_distance < b.current_distance
	)
	return snapshot


func _preview_line_targets(
	bullet: BulletData,
	target: EnemyInstance,
	total_pen: int,
	snapshot: Array[EnemyInstance]
) -> Array[EnemyInstance]:
	var result: Array[EnemyInstance] = []
	if target == null:
		return result
	var depth := CaliberProfiles.line_depth_for_gun(gun, bullet)
	if depth <= 0:
		return result
	var target_idx := snapshot.find(target)
	if target_idx < 0:
		return result
	for depth_index in range(depth):
		var idx := target_idx + depth_index + 1
		if idx >= snapshot.size():
			break
		var candidate := snapshot[idx]
		# 직선 관통은 중간 게이트가 막히면 뒤 대상을 건너뛰지 않는다.
		if total_pen < candidate.current_def:
			break
		result.append(candidate)
	return result


func _scatter_candidates(
	target: EnemyInstance,
	snapshot: Array[EnemyInstance]
) -> Array[EnemyInstance]:
	var result: Array[EnemyInstance] = []
	if target == null \
			or CaliberProfiles.family_for_gun(gun) != Enums.AmmoFamily.SHOTGUN \
			or target.current_distance > CaliberProfiles.SHOTGUN_MAX_RANGE:
		return result
	var radius := CaliberProfiles.scatter_radius_for_gun(
		gun, _has_part(Enums.PartID.SPREAD_SHOT)
	)
	for candidate in snapshot:
		if candidate == target or candidate.is_dead():
			continue
		if absi(candidate.current_distance - target.current_distance) <= radius:
			result.append(candidate)
	result.sort_custom(func(a: EnemyInstance, b: EnemyInstance) -> bool:
		var da := absi(a.current_distance - target.current_distance)
		var db := absi(b.current_distance - target.current_distance)
		if da == db:
			if a.current_distance == b.current_distance:
				return enemies.find(a) < enemies.find(b)
			return a.current_distance < b.current_distance
		return da < db
	)
	return result


func _preview_scatter_targets(
	target: EnemyInstance,
	snapshot: Array[EnemyInstance],
	excluded: Array[EnemyInstance] = []
) -> Array[EnemyInstance]:
	var result: Array[EnemyInstance] = []
	var count := CaliberProfiles.scatter_count_for_gun(
		gun, _has_part(Enums.PartID.SPREAD_SHOT)
	)
	if count <= 0:
		return result
	for candidate in _scatter_candidates(target, snapshot):
		if candidate in excluded:
			continue
		result.append(candidate)
		if result.size() >= count:
			break
	return result


## 주 적중 뒤에 발생하는 탄종 보조 피해.
## 파츠 정액·집중·탄 후속 효과를 복제하지 않는 비재귀 경로다.
func _apply_family_collateral(
	bullet: BulletData,
	target: EnemyInstance,
	base_damage: int,
	total_pen: int,
	snapshot: Array[EnemyInstance]
) -> Dictionary:
	var kills: Array[EnemyInstance] = []
	var events: Array[Dictionary] = []
	var scatter_targets: Array[EnemyInstance] = []
	if target == null or base_damage <= 0:
		return {
			"kills": kills,
			"events": events,
			"scatter_targets": scatter_targets,
		}

	var used_targets: Dictionary = {}
	var line_targets := _preview_line_targets(bullet, target, total_pen, snapshot)
	var successful_line: Array[EnemyInstance] = []
	var heavy_boost := _gun_is("heavy") and total_pen > target.current_def
	for depth_index in range(line_targets.size()):
		var line_target := line_targets[depth_index]
		used_targets[line_target] = true
		var collateral := CaliberProfiles.line_damage_for_gun(gun, depth_index, heavy_boost)
		if collateral <= 0:
			continue
		_apply_damage_to_enemy(line_target, collateral)
		successful_line.append(line_target)
		combat_log.emit("   ↳ ➜ [직선 관통 %d] [%s] 스침 피해 %d" % [
			depth_index + 1,
			line_target.data.display_name,
			collateral,
		])
		enemy_damaged.emit(
			line_target,
			collateral,
			line_target.current_hp if not line_target.is_stack_sponge else line_target.barrier_cells,
			false
		)
		if line_target.is_dead() and line_target not in kills:
			kills.append(line_target)
	if not successful_line.is_empty():
		events.append({
			"kind": "rifle",
			"targets": successful_line,
			"value": successful_line.size(),
		})

	var scatter_limit := CaliberProfiles.scatter_count_for_gun(
		gun, _has_part(Enums.PartID.SPREAD_SHOT)
	)
	var scatter_attempts := 0
	for scatter_target in _scatter_candidates(target, snapshot):
		if used_targets.has(scatter_target):
			continue
		scatter_attempts += 1
		if scatter_attempts > scatter_limit:
			break
		# 산탄 펠릿은 후보별로 PEN 게이트를 검사하되 다른 후보까지 막지는 않는다.
		if total_pen < scatter_target.current_def:
			combat_log.emit("   ↳ ◁ [산탄 확산] [%s] DEF %d에 막힘" % [
				scatter_target.data.display_name, scatter_target.current_def
			])
			continue
		var scatter_damage := CaliberProfiles.collateral_damage(base_damage, 0.5)
		if scatter_damage <= 0:
			continue
		_apply_damage_to_enemy(scatter_target, scatter_damage)
		scatter_targets.append(scatter_target)
		combat_log.emit("   ↳ ◁ [산탄 확산] [%s] %d 피해 (50%%)" % [
			scatter_target.data.display_name, scatter_damage
		])
		enemy_damaged.emit(
			scatter_target,
			scatter_damage,
			scatter_target.current_hp if not scatter_target.is_stack_sponge else scatter_target.barrier_cells,
			false
		)
		if scatter_target.is_dead() and scatter_target not in kills:
			kills.append(scatter_target)
	if not scatter_targets.is_empty():
		events.append({
			"kind": "shotgun",
			"targets": scatter_targets,
			"value": scatter_targets.size(),
		})

	return {
		"kills": kills,
		"events": events,
		"scatter_targets": scatter_targets,
	}


## 한 격발에서 주·보조 대상으로 발생한 처치를 일괄 등록한다.
## 체이서·리코일 푸시·샷건 끌어당김은 대상 수와 무관하게 한 번만 발동한다.
func _register_kills_for_shot(
	killed_enemies: Array[EnemyInstance],
	calc_bullet: BulletData
) -> void:
	if killed_enemies.is_empty():
		return
	var unique: Array[EnemyInstance] = []
	for killed in killed_enemies:
		if killed == null or killed in unique:
			continue
		unique.append(killed)
		combat_log.emit("💀 [%s] 처치!" % killed.data.display_name)
		enemy_killed.emit(killed)
		battle_stats.total_kills += 1
		battle_stats.total_kill_dist_sum += killed.current_distance
		battle_stats.kills_this_turn += 1
		if killed.data.archetype == Enums.EnemyArchetype.TANK \
				and calc_bullet.penetration <= killed.current_def:
			battle_stats.shred_only_tank_kills += 1
		if killed.current_stance != Enums.EnemyStance.NONE and killed.slow_stacks == 0:
			battle_stats.stance_kills_without_slow += 1
		if focus_stacks.has(killed):
			focus_stacks.erase(killed)

	if _gun_is("shotgun"):
		var alive_list := _alive_enemies_by_distance()
		if not alive_list.is_empty():
			var next_enemy := alive_list[0]
			next_enemy.current_distance = maxi(next_enemy.current_distance - 1, 0)
			combat_log.emit("   ↳ ⚠ [돌격형 시그니처] 처치 격발로 다음 적 [%s]이 1칸 전진! (현재 거리 %dm)" % [
				next_enemy.data.display_name, next_enemy.current_distance
			])
			enemy_moved.emit(next_enemy, next_enemy.current_distance, -1)

	if _has_part(Enums.PartID.CHASER):
		chaser_pen_bonus += 2
		combat_log.emit("   ↳ 🚀 [체이서] 처치 격발! 다음 격발 PEN +2 충전")

	if _has_part(Enums.PartID.RECOIL_PUSH):
		combat_log.emit("   ↳ 🛡 [리코일 푸시] 처치 격발 반동!")
		for alive in enemies:
			if alive.is_dead():
				continue
			alive.apply_knockback(1)
			enemy_knocked_back.emit(alive, alive.current_distance, 1)
			combat_log.emit("     ↳ [%s] 강제 넉백 1칸 → 거리 %d" % [
				alive.data.display_name, alive.current_distance
			])



## 적 대미지 적용 공통 헬퍼 (스택 스펀지 포함)
func _apply_damage_to_enemy(enemy: EnemyInstance, dmg_amount: int) -> void:
	if enemy.is_stack_sponge:
		# 흡수체의 셀은 '명중 횟수'가 아니라 양 게이트를 통과한 유효 적중만 센다.
		# 피해 0인 관통 실패 명중으로 셀이 줄면 DEF 게이트가 사실상 사라진다.
		if dmg_amount <= 0:
			return
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
func _class_name(cls: int) -> String:
	return CaliberProfiles.short_label_for_class(cls)


## 실패 시 런 덱에서도 보존되는 탄인지 미리보기와 실제 소실 계약이 공유하는 판정.
func _bullet_is_caliber_safe(bullet: BulletData) -> bool:
	if bullet == null:
		return false
	if bullet.is_basic:
		return true
	if bullet.weapon_class == Enums.WeaponClass.UNIVERSAL:
		return false
	if gun != null and bullet.weapon_class == gun.weapon_class:
		return true
	for part in equipped_parts:
		if part != null and part.is_conversion_kit() \
				and part.conversion_class == bullet.weapon_class:
			return true
	return false


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
func request_insert_bullet(bullet: BulletData) -> bool:
	if state != State.PLAYER_TURN:
		return false
	var cap := gun.magazine_capacity
	var has_ch := gun.has_chamber
	var max_cap := cap + (1 if has_ch else 0)
	if magazine.get_remaining() >= max_cap:
		combat_log.emit("⚠ 탄창이 가득 차서 납탄할 수 없습니다.")
		return false

	if _is_basic_supply_bullet(bullet):
		if basic_supply_current <= 0:
			combat_log.emit("⚠ 이번 재장전 사이클의 기본 보급탄을 모두 사용했습니다.")
			return false
		basic_supply_current -= 1
		basic_supply_updated.emit(basic_supply_bullet, basic_supply_current, basic_supply_capacity)
	else:
		var draw_idx := _find_draw_pile_index(bullet)
		if draw_idx < 0:
			combat_log.emit("⚠ 가방에 남은 탄환이 없습니다.")
			return false
		draw_pile.remove_at(draw_idx)
		draw_pile_updated.emit(draw_pile)
		piles_updated.emit(draw_pile, discard_pile, exile_pile)
		
	magazine.insert_bullet(bullet)
	battle_stats.lead_bullets_fired += 1
	combat_log.emit("📥 [%s] 탄환을 탄창 맨 위에 장전했습니다. (가방을 닫으면 템포 세금이 적용됩니다)" % bullet.display_name)

	# 템포 세금 플래그 활성화 (모든 적 1회 전진 보장용)
	has_inserted_bullet_this_turn = true

	# 납탄 봉인
	if state == State.PLAYER_TURN:
		_insert_seal_active = true

	magazine_updated.emit(magazine.get_remaining(), magazine.get_capacity())
	return true

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
			if b and not _is_basic_supply_bullet(b):
				draw_pile.append(b)

	magazine.clear()
	_clear_focus()
	_reset_inertia_chain()
	# 셋업 버프는 리로드로 소멸한다.
	# ⚠️ 유지되면 "탄창 끝에 셋업 깔아두기"가 항상 이득이 되어 리로드 공백의 비용이 흐려진다.
	pending_buff_acc = 0
	pending_buff_pen = 0
	magazine_buff_acc = 0
	magazine_buff_pen = 0

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

	# 리로드 완료: 전술탄만 버린 더미에서 순환한다. 기본탄은 고정 보급량으로 일괄 복구한다.
	if not discard_pile.is_empty():
		for b in discard_pile:
			if not _is_basic_supply_bullet(b):
				draw_pile.append(b)
		discard_pile.clear()
		draw_pile.shuffle()
		combat_log.emit("♻ 버린 더미의 탄환들이 가방(Draw Pile)으로 셔플 순환되었습니다.")
	# 실패·빼내기로 소멸된 기본탄 표시는 복구와 함께 제거한다. 전술탄 소멸 기록은 유지한다.
	for i in range(exile_pile.size() - 1, -1, -1):
		if _is_basic_supply_bullet(exile_pile[i]):
			exile_pile.remove_at(i)
	basic_supply_current = basic_supply_capacity
	draw_pile_updated.emit(draw_pile)
	piles_updated.emit(draw_pile, discard_pile, exile_pile)
	basic_supply_updated.emit(basic_supply_bullet, basic_supply_current, basic_supply_capacity)

	reload_finished.emit()
	if basic_supply_bullet != null:
		combat_log.emit("🔄 리로드 완료! 기본 보급탄 %d발 복구" % basic_supply_current)
	else:
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
		Enums.BulletEffect.DEBUFF_EVA:
			target.apply_evasion_shred(bullet.effect_value)
			combat_log.emit("   ↳ 조준 교란! EVA -%d → %d" % [
				bullet.effect_value, target.current_evasion
			])
		Enums.BulletEffect.OPENING_SHOT:
			if is_first:
				target.apply_armor_shred(1)
				armor_shredded.emit(target, target.current_def, 1)
				var eff_kb := target.apply_knockback(bullet.effect_value)
				if eff_kb > 0:
					enemy_knocked_back.emit(target, target.current_distance, eff_kb)
					combat_log.emit("   ↳ 선제 사격! 추가 넉백 +%d 및 장갑 파쇄 -1 적용 (실제 밀려남: %d칸)" % [bullet.effect_value, eff_kb])
				else:
					combat_log.emit("   ↳ 선제 사격! 넉백 저항으로 밀려나지 않음 (저항 %d, 장갑 파쇄 -1만 적용)" % target.knockback_resistance)
			else:
				combat_log.emit("   ↳ 선제탄 첫 발 조건 불충족 — 추가 효과 없음")
		_:
			pass


## 플레이테스트 보고서는 화면용 BBCode 문자열을 보존하되,
## 탄·파츠·탄종 효과는 별도 필드로 저장해 자동 비교가 가능하게 한다.
func _reset_telemetry() -> void:
	telemetry_started_at = Time.get_datetime_string_from_system(false, true)
	telemetry_initial_enemies.clear()
	telemetry_shots.clear()
	telemetry_family_events.clear()
	telemetry_part_events.clear()
	telemetry_combat_log.clear()
	telemetry_bullet_summary.clear()
	telemetry_family_summary.clear()
	telemetry_part_summary.clear()
	telemetry_reload_count = 0
	telemetry_reload_turns = 0
	_telemetry_pending_family_events.clear()


func _capture_telemetry_log(message: String) -> void:
	telemetry_combat_log.append(message)
	for part in equipped_parts:
		if part == null:
			continue
		var token := str(PART_LOG_TOKENS.get(part.part_id, ""))
		if token.is_empty() or not message.contains(token):
			continue
		var snapshot := PlaytestLoggerScript.resource_snapshot(part)
		var part_id := str(snapshot.get("id", "part_%d" % part.part_id))
		var event := {
			"event_index": telemetry_part_events.size() + 1,
			"after_shot": telemetry_shots.size(),
			"part": snapshot,
			"message": message,
			"declared_bonus_damage": _telemetry_declared_bonus(message, "DMG +"),
			"declared_bonus_accuracy": _telemetry_declared_bonus(message, "ACC +"),
			"declared_bonus_penetration": _telemetry_declared_bonus(message, "PEN +"),
		}
		telemetry_part_events.append(event)
		var summary: Dictionary = telemetry_part_summary.get(part_id, {
			"part": snapshot,
			"effect_events": 0,
			"declared_bonus_damage": 0,
			"declared_bonus_accuracy": 0,
			"declared_bonus_penetration": 0,
		})
		summary.effect_events = int(summary.effect_events) + 1
		summary.declared_bonus_damage = int(summary.declared_bonus_damage) \
			+ int(event.declared_bonus_damage)
		summary.declared_bonus_accuracy = int(summary.declared_bonus_accuracy) \
			+ int(event.declared_bonus_accuracy)
		summary.declared_bonus_penetration = int(summary.declared_bonus_penetration) \
			+ int(event.declared_bonus_penetration)
		telemetry_part_summary[part_id] = summary


func _capture_telemetry_family(
	kind: String,
	source: EnemyInstance,
	targets: Array,
	value: int
) -> void:
	var target_snapshots: Array[Dictionary] = []
	for target in targets:
		if target is EnemyInstance:
			target_snapshots.append(_telemetry_enemy_snapshot(target, enemies.find(target)))
	var event := {
		"event_index": telemetry_family_events.size() + 1,
		"shot_number": telemetry_shots.size() + 1,
		"kind": kind,
		"source": _telemetry_enemy_snapshot(source, enemies.find(source)),
		"targets": target_snapshots,
		"value": value,
	}
	telemetry_family_events.append(event)
	_telemetry_pending_family_events.append(event.duplicate(true))
	var summary: Dictionary = telemetry_family_summary.get(kind, {
		"events": 0,
		"triggers": 0,
		"value_total": 0,
		"targets_total": 0,
	})
	summary.events = int(summary.events) + 1
	# 경량탄은 1/3·2/3 진행 갱신도 같은 시그널을 쓴다.
	# 실제 폭발(value > 0)만 trigger로 세어 체감 지표를 부풀리지 않는다.
	if value > 0:
		summary.triggers = int(summary.triggers) + 1
	summary.value_total = int(summary.value_total) + value
	summary.targets_total = int(summary.targets_total) + target_snapshots.size()
	telemetry_family_summary[kind] = summary


func _capture_telemetry_shot(
	bullet: BulletData,
	hit: bool,
	damage: int,
	target: EnemyInstance,
	remaining_durability: int
) -> void:
	var bullet_snapshot := PlaytestLoggerScript.resource_snapshot(bullet)
	bullet_snapshot["role"] = bullet.role
	bullet_snapshot["family"] = bullet.family
	bullet_snapshot["is_basic"] = bullet.is_basic
	bullet_snapshot["damage"] = bullet.damage
	bullet_snapshot["penetration"] = bullet.penetration
	bullet_snapshot["accuracy"] = bullet.accuracy
	var bullet_id := str(bullet_snapshot.get("id", "unknown"))
	var shot := {
		"shot_number": telemetry_shots.size() + 1,
		"bullet": bullet_snapshot,
		"target_after": _telemetry_enemy_snapshot(target, enemies.find(target)),
		"hit": hit,
		"effective": hit and damage > 0,
		"primary_damage": damage,
		"remaining_durability": remaining_durability,
		"magazine_remaining": magazine.get_remaining() if magazine != null else 0,
		"family_events": _telemetry_pending_family_events.duplicate(true),
		"combat_log_lines": telemetry_combat_log.size(),
	}
	telemetry_shots.append(shot)
	_telemetry_pending_family_events.clear()
	var summary: Dictionary = telemetry_bullet_summary.get(bullet_id, {
		"bullet": bullet_snapshot,
		"shots": 0,
		"hits": 0,
		"effective_hits": 0,
		"primary_damage": 0,
	})
	summary.shots = int(summary.shots) + 1
	if hit:
		summary.hits = int(summary.hits) + 1
	if hit and damage > 0:
		summary.effective_hits = int(summary.effective_hits) + 1
	summary.primary_damage = int(summary.primary_damage) + damage
	telemetry_bullet_summary[bullet_id] = summary


func _capture_telemetry_reload(turns: int) -> void:
	telemetry_reload_count += 1
	telemetry_reload_turns += turns


func _telemetry_declared_bonus(message: String, marker: String) -> int:
	var index := message.find(marker)
	if index < 0:
		return 0
	return message.substr(index + marker.length()).to_int()


func _telemetry_enemy_snapshot(enemy_inst: EnemyInstance, slot: int) -> Dictionary:
	if enemy_inst == null:
		return {}
	return {
		"slot": slot,
		"id": PlaytestLoggerScript.resource_id(enemy_inst.data),
		"display_name": enemy_inst.data.display_name,
		"hp": enemy_inst.current_hp,
		"max_hp": enemy_inst.max_hp,
		"defense": enemy_inst.current_def,
		"evasion": enemy_inst.current_evasion,
		"speed": enemy_inst.current_speed,
		"distance": enemy_inst.current_distance,
		"start_distance": enemy_inst.start_distance,
		"barrier_cells": enemy_inst.barrier_cells if enemy_inst.is_stack_sponge else 0,
		"dead": enemy_inst.is_dead(),
	}


func _telemetry_enemy_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(enemies.size()):
		result.append(_telemetry_enemy_snapshot(enemies[index], index))
	return result


func build_playtest_report() -> Dictionary:
	var result_name := "in_progress"
	match state:
		State.WON: result_name = "won"
		State.LOST: result_name = "lost"
	var part_snapshots: Array[Dictionary] = []
	for part in equipped_parts:
		part_snapshots.append(PlaytestLoggerScript.resource_snapshot(part))
	return {
		"started_at": telemetry_started_at,
		"finished_at": Time.get_datetime_string_from_system(false, true),
		"result": result_name,
		"gun": PlaytestLoggerScript.resource_snapshot(gun),
		"basic_ammo": PlaytestLoggerScript.resource_snapshot(basic_supply_bullet),
		"equipped_parts": part_snapshots,
		"initial_enemies": telemetry_initial_enemies.duplicate(true),
		"final_enemies": _telemetry_enemy_snapshots(),
		"summary": {
			"shots": telemetry_shots.size(),
			"reloads": telemetry_reload_count,
			"reload_turns": telemetry_reload_turns,
			"battle_stats": battle_stats.duplicate(true),
			"bullets": telemetry_bullet_summary.duplicate(true),
			"ammo_families": telemetry_family_summary.duplicate(true),
			"parts": telemetry_part_summary.duplicate(true),
		},
		"shots": telemetry_shots.duplicate(true),
		"family_events": telemetry_family_events.duplicate(true),
		"part_events": telemetry_part_events.duplicate(true),
		"combat_log": telemetry_combat_log.duplicate(),
	}


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
