class_name DamageCalculator

## 결정론적 대미지 계산기 (정적 함수 모음)
##
## 모든 계산은 덧셈/뺄셈 기반. 확률 요소 없음.
## GDD §3.2의 공식을 그대로 구현한다.
##
## 사용법:
##   var hit = DamageCalculator.check_hit(bullet, enemy_eva)
##   var dmg = DamageCalculator.calculate_damage(bullet, enemy_def, enemy_pres, gun)


## 명중 판정 (결정론적 임계값 비교)
## ACC ≥ EVA이면 명중. 확률이 아니다.
## gun이 주어지면 패시브 명중 보너스를 가산한다.
static func check_hit(bullet: BulletData, enemy_evasion: int, gun: GunData = null) -> bool:
	var total_acc := bullet.accuracy
	if gun:
		total_acc += gun.passive_acc_bonus
	return total_acc >= enemy_evasion


## 대미지 계산
## 1) 유효 관통 = PEN - PRES   (최소 0)
## 2) 실 대미지 = DMG + 유효 관통 - DEF
## 3) 최종 대미지 = max(실 대미지, 0)
##
## gun이 주어지면 패시브 보너스를 가산한다.
static func calculate_damage(
	bullet: BulletData,
	enemy_def: int,
	gun: GunData = null
) -> int:
	var total_dmg := bullet.damage
	var total_pen := bullet.penetration

	# 총 패시브 가산
	if gun:
		total_dmg += gun.passive_dmg_bonus
		total_pen += gun.passive_pen_bonus

	# 이진 관통 게이트: PEN < DEF 이면 0
	if total_pen < enemy_def:
		return 0
	return total_dmg


## 넉백량 계산 (총 패시브 포함)
static func calculate_knockback(bullet: BulletData, gun: GunData = null) -> int:
	var total_kb := bullet.knockback
	if gun:
		total_kb += gun.passive_knockback_bonus
	return total_kb


## 디버그용: 대미지 계산 과정을 문자열로 반환
static func damage_breakdown(
	bullet: BulletData,
	enemy_def: int,
	gun: GunData = null
) -> String:
	var total_dmg := bullet.damage
	var total_pen := bullet.penetration
	if gun:
		total_dmg += gun.passive_dmg_bonus
		total_pen += gun.passive_pen_bonus

	var is_penetrated := total_pen >= enemy_def
	var final_damage := total_dmg if is_penetrated else 0

	return "PEN(%d) vs DEF(%d) -> %s | DMG: %d" % [
		total_pen, enemy_def, "관통" if is_penetrated else "도탄(0)", final_damage
	]
