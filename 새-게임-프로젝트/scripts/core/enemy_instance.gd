class_name EnemyInstance
extends RefCounted

## 적 런타임 인스턴스 — EnemyData의 가변 상태 래퍼
## EnemyData(템플릿)를 복사하여, 전투 중 변하는 HP·방어·거리 등을 관리한다.

var data: EnemyData          ## 원본 데이터 참조

var current_hp: int
var current_def: int
var current_pres: int
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


func _init(enemy_data: EnemyData) -> void:
	data = enemy_data
	current_hp = data.max_hp
	current_def = data.defense
	current_pres = data.pen_resist
	current_evasion = data.evasion
	current_speed = data.speed
	current_distance = data.start_distance
	start_distance = data.start_distance
	knockback_resistance = data.knockback_resistance
	
	if data.archetype == Enums.EnemyArchetype.TANK:
		current_stance = Enums.EnemyStance.IRON_SHIELD
	elif data.archetype == Enums.EnemyArchetype.DODGER:
		current_stance = Enums.EnemyStance.ACTIVE_DODGER
	elif data.archetype == Enums.EnemyArchetype.CASTER:
		current_speed = 0 # 술사는 전진하지 않고 원거리 차징에 전념


## 대미지 적용. HP는 0 미만으로 내려가지 않는다.
func apply_damage(amount: int) -> void:
	current_hp = maxi(current_hp - amount, 0)


## 적 전진. 둔화 적용 후 소비. 실제 이동한 칸 수를 반환한다.
## 술사는 전진하지 않고 0을 반환한다.
func advance() -> int:
	if data.archetype == Enums.EnemyArchetype.CASTER:
		return 0
		
	var effective_speed := maxi(current_speed - slow_stacks, 0)
	current_distance = maxi(current_distance - effective_speed, 0)
	slow_stacks = 0  # 둔화는 1회 소비
	return effective_speed


## 술사 차징 카운터 진행. 차징 완료되어 격발 시 true 반환.
## 둔화(slow_stacks) 상태일 경우 차징이 1턴 지연된다.
func advance_charger() -> bool:
	if data.archetype != Enums.EnemyArchetype.CASTER:
		return false
		
	if slow_stacks > 0:
		slow_stacks = maxi(slow_stacks - 1, 0)
		return false
		
	charge_turns_current += 1
	if charge_turns_current >= charge_turns_max:
		charge_turns_current = 0
		return true
	return false



## 넉백. 거리를 증가시킨다 (= 생존 자원 회복).
func apply_knockback(amount: int) -> void:
	var effective_kb := maxi(amount - knockback_resistance, 0)
	current_distance += effective_kb


## 둔화 누적. 다음 advance()에서 적용된다.
func apply_slow(amount: int) -> void:
	slow_stacks += amount


## 장갑 파쇄. DEF를 영구적으로 감소시킨다.
func apply_armor_shred(amount: int) -> void:
	current_def = maxi(current_def - amount, 0)


## 적이 죽었는가
func is_dead() -> bool:
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
	if shot_counter >= 3:
		shot_counter = 0
		_shift_stance()
		return true
	return false


func _shift_stance() -> void:
	if current_stance == Enums.EnemyStance.IRON_SHIELD:
		current_stance = Enums.EnemyStance.ACTIVE_DODGER
		current_def = 0
		current_pres = 0
		current_evasion = 7
		current_speed = 3
	elif current_stance == Enums.EnemyStance.ACTIVE_DODGER:
		current_stance = Enums.EnemyStance.IRON_SHIELD
		current_def = 6
		current_pres = 3
		current_evasion = 1
		current_speed = 1
