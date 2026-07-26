class_name EnemyInstance
extends RefCounted

## 적 런타임 인스턴스 — EnemyData의 가변 상태 래퍼
## EnemyData(템플릿)를 복사하여, 전투 중 변하는 HP·방어·거리 등을 관리한다.

var data: EnemyData          ## 원본 데이터 참조

## CSV 동기화까지 반영한 런타임 최대 HP. UI 비율 계산은 원본 .tres가 아니라 이 값을 사용한다.
var max_hp: int
var current_hp: int
var current_def: int
var current_evasion: int
var current_speed: int
var current_distance: int
var slow_stacks: int = 0
var start_distance: int     ## 누적 둔화량 (다음 전진 시 소비)
var current_stance: Enums.EnemyStance = Enums.EnemyStance.NONE
var shot_counter: int = 0
var knockback_resistance: int = 0

# ── 술사형(CASTER) 차징 변수 ──
var charge_turns_max: int = 3
var charge_turns_current: int = 0
## 차징 활성 여부 — 술사형 및 보스 차징 기믹 공유 플래그
var is_charger: bool = false

# ── 스택 스펀지(ABSORBER) 변수 ──
var is_stack_sponge: bool = false
var barrier_cells: int = 3
## 배리어 최대치 — HP 바가 비율을 그리려면 최댓값이 필요하다. 초기화 끝에 현재값으로 확정한다.
var max_barrier_cells: int = 3

# ── 보스 전용 변수 ──
## 현재 페이즈 (1 = 기본, 2 = 코어 노출 등)
var current_phase: int = 1
## 태세 전환 주기 (피격 N회마다 전환)
var stance_shift_interval: int = 3
## 보스 여부
var is_boss: bool = false
## 3단 태세 순환 여부 (실험체 Ω 전용)
var has_triple_stance: bool = false
## 페이즈 2 실체 HP (최종 보스용)
var phase2_hp: int = 0


func _init(enemy_data: EnemyData) -> void:
	data = enemy_data
	
	var res_id := enemy_data.resource_path.get_file().get_basename()
	var csv := DataLoader.get_enemy(res_id)
	
	var current_arch = data.archetype
	
	if not csv.is_empty():
		max_hp = csv.max_hp
		current_hp = max_hp
		current_def = csv.defense
		current_evasion = csv.evasion
		current_speed = csv.speed
		current_distance = csv.start_distance
		knockback_resistance = csv.knockback_resistance
		current_arch = csv.archetype
	else:
		max_hp = data.max_hp
		current_hp = max_hp
		current_def = data.defense
		current_evasion = data.evasion
		current_speed = data.speed
		current_distance = data.start_distance
		knockback_resistance = data.knockback_resistance
		
	if RunManager.infiltration_risk_level >= 3:
		current_distance = maxi(current_distance - 1, 1)

	# ── 승천 적용 (정본: docs/gdd/20_ascension_intention.md §4) ──
	# ⚠️ 적 DEF/EVA는 절대 건드리지 않는다. 이진 관통 게이트라 절벽이 되어
	#    난이도가 균일하게 오르지 않고 특정 빌드만 골라 죽인다.
	#    거리와 SPD는 게이트와 무관한 양적 손잡이라 완만하게 조여진다.
	var asc := RunManager.ascension_effects()
	current_distance = maxi(current_distance + int(asc.start_dist_delta), 1)
	current_speed = maxi(current_speed + int(asc.enemy_spd_delta), 0)

	start_distance = current_distance
	
	# 데이터에서 보스/태세 전환 주기 읽기
	is_boss = data.is_boss
	stance_shift_interval = data.stance_shift_interval
	
	# ── 일반 아키타입 초기화 ──
	if current_arch == Enums.EnemyArchetype.TANK:
		current_stance = Enums.EnemyStance.IRON_SHIELD
	elif current_arch == Enums.EnemyArchetype.DODGER:
		current_stance = Enums.EnemyStance.ACTIVE_DODGER
	elif current_arch == Enums.EnemyArchetype.CASTER:
		current_speed = 0 # 술사는 전진하지 않고 원거리 차징에 전념
		is_charger = true
	elif current_arch == Enums.EnemyArchetype.ABSORBER:
		is_stack_sponge = true
		barrier_cells = 3
		if RunManager.infiltration_risk_level >= 4:
			barrier_cells = 4
		current_hp = 99
	elif current_arch == Enums.EnemyArchetype.SCRAMBLER:
		current_stance = Enums.EnemyStance.IRON_SHIELD
		current_def = 4
		current_evasion = 1
		current_speed = 1
	
	# ── 보스 아키타입 초기화 ──
	elif current_arch == Enums.EnemyArchetype.BOSS_TANK_DODGE:
		# 보스 #1: 디렉터 강 — 방패↔회피 태세 전환 (3발 주기)
		current_stance = Enums.EnemyStance.IRON_SHIELD
		
	elif current_arch == Enums.EnemyArchetype.BOSS_CASTER_SPONGE:
		# 보스 #2: 세라프 프로토콜 — 배리어 + 차징 동시 활성화
		is_stack_sponge = true
		barrier_cells = 4
		current_hp = 99
		is_charger = true
		current_speed = 0
		charge_turns_max = 4
		
	elif current_arch == Enums.EnemyArchetype.BOSS_SCRAMBLER:
		# 보스 #3: 실험체 Ω — 3단 태세 순환 (방패→회피→돌격, 2발 주기)
		current_stance = Enums.EnemyStance.IRON_SHIELD
		has_triple_stance = true
		stance_shift_interval = 2
		
	elif current_arch == Enums.EnemyArchetype.BOSS_FINAL:
		# 최종 보스: L.O.B 코어 — 페이즈 1: 배리어(5) + 차징
		current_phase = 1
		is_stack_sponge = true
		barrier_cells = 5
		current_hp = 99
		is_charger = true
		current_speed = 0
		charge_turns_max = 3
		phase2_hp = 30

	# 배리어 최대치를 초기값으로 확정한다(전 분기 공통). HP 바 비율 계산에 쓰인다.
	max_barrier_cells = maxi(barrier_cells, 1)


## 대미지 적용. HP는 0 미만으로 내려가지 않는다.
func apply_damage(amount: int) -> void:
	current_hp = maxi(current_hp - amount, 0)


## 적 전진. 둔화 적용 후 소비. 실제 이동한 칸 수를 반환한다.
## 술사 및 고정 유닛(SPD 0)은 전진하지 않고 0을 반환한다.
func advance() -> int:
	if current_speed == 0:
		return 0
		
	var effective_speed := maxi(current_speed - slow_stacks, 0)
	current_distance = maxi(current_distance - effective_speed, 0)
	slow_stacks = 0  # 둔화는 1회 소비
	return effective_speed


## 차징 카운터 진행. 차징 완료되어 격발 시 true 반환.
## 둔화(slow_stacks) 상태일 경우 차징이 1턴 지연된다.
## 술사형 및 보스 차징 기믹 모두 이 함수를 공유한다.
func advance_charger() -> bool:
	if not is_charger:
		return false
		
	if slow_stacks > 0:
		slow_stacks = maxi(slow_stacks - 1, 0)
		return false
		
	charge_turns_current += 1
	if charge_turns_current >= charge_turns_max:
		charge_turns_current = 0
		return true
	return false



## 넉백. 거리를 증가시킨다 (= 생존 자원 회복). 실제 적용된 넉백 칸 수를 반환한다.
func apply_knockback(amount: int) -> int:
	var effective_kb := maxi(amount - knockback_resistance, 0)
	current_distance += effective_kb
	return effective_kb


## 둔화 누적. 다음 advance()에서 적용된다.
func apply_slow(amount: int) -> void:
	slow_stacks += amount


## 장갑 파쇄. DEF를 영구적으로 감소시킨다.
func apply_armor_shred(amount: int) -> void:
	current_def = maxi(current_def - amount, 0)


## 적이 죽었는가
func is_dead() -> bool:
	if is_stack_sponge:
		return barrier_cells <= 0
	return current_hp <= 0


## 적이 플레이어에게 도달했는가 (거리 0)
func is_at_player() -> bool:
	return current_distance <= 0


## 격발이 1회 정산되었을 때 누적 카운트를 계산하고 태세 교대 여부를 확인한다.
## 태세가 변경되면 true를 반환한다.
func apply_shot_and_check_shift() -> bool:
	if current_stance == Enums.EnemyStance.NONE:
		return false
		
	shot_counter += 1
	if shot_counter >= stance_shift_interval:
		shot_counter = 0
		_shift_stance()
		return true
	return false


## 태세 교대 처리.
## 3단 순환(실험체 Ω)과 2단 순환(일반/보스 #1)을 분기한다.
func _shift_stance() -> void:
	if has_triple_stance:
		_shift_stance_triple()
	else:
		_shift_stance_dual()


## 2단 태세 순환: IRON_SHIELD ↔ ACTIVE_DODGER
func _shift_stance_dual() -> void:
	if current_stance == Enums.EnemyStance.IRON_SHIELD:
		current_stance = Enums.EnemyStance.ACTIVE_DODGER
		current_def = 0
		current_evasion = 7
		current_speed = 3
	elif current_stance == Enums.EnemyStance.ACTIVE_DODGER:
		current_stance = Enums.EnemyStance.IRON_SHIELD
		current_def = 4
		current_evasion = 1
		current_speed = 1


## 3단 태세 순환: IRON_SHIELD → ACTIVE_DODGER → RUSH_CHARGE → 반복
## 실험체 Ω(보스 #3) 전용.
func _shift_stance_triple() -> void:
	if current_stance == Enums.EnemyStance.IRON_SHIELD:
		current_stance = Enums.EnemyStance.ACTIVE_DODGER
		current_def = 0
		current_evasion = 7
		current_speed = 2
	elif current_stance == Enums.EnemyStance.ACTIVE_DODGER:
		current_stance = Enums.EnemyStance.RUSH_CHARGE
		current_def = 1
		current_evasion = 2
		current_speed = 4
	elif current_stance == Enums.EnemyStance.RUSH_CHARGE:
		current_stance = Enums.EnemyStance.IRON_SHIELD
		current_def = 5
		current_evasion = 1
		current_speed = 1


## 최종 보스 전용: 배리어 소거 완료 시 페이즈 2로 전환한다.
## 페이즈 2에서는 배리어 모드 해제, 실체 HP 노출, 전진+태세 전환 시작.
## 전환 성공 시 true를 반환한다.
func check_phase_transition() -> bool:
	if data.archetype != Enums.EnemyArchetype.BOSS_FINAL:
		return false
	if current_phase != 1:
		return false
	if barrier_cells > 0:
		return false
	
	# 페이즈 2 전환: 코어 노출
	current_phase = 2
	is_stack_sponge = false
	max_hp = phase2_hp
	current_hp = phase2_hp
	current_speed = 1
	knockback_resistance = 2
	# 태세 전환 시작 (방패↔회피, 3발 주기)
	current_stance = Enums.EnemyStance.IRON_SHIELD
	current_def = 3
	current_evasion = 1
	# 차징은 계속 유지 (is_charger = true)
	return true
