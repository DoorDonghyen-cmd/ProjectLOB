extends RefCounted
## DamageCalculator 결정론 검증 — 명중(ACC≥EVA 임계값) + 이진 관통 게이트.
## 정본: docs/gdd/03_combat_system.md §3.2, scripts/core/damage_calculator.gd


static func _bullet(dmg: int, acc: int, pen: int, kb: int = 0) -> BulletData:
	var b := BulletData.new()
	b.damage = dmg
	b.accuracy = acc
	b.penetration = pen
	b.knockback = kb
	return b


static func run(t) -> void:
	t.section("DamageCalculator")

	# ── 명중: ACC >= EVA 임계값 (확률 아님) ──
	t.check(DamageCalculator.check_hit(_bullet(3, 7, 0), 7), "ACC7 >= EVA7 → 명중")
	t.check(not DamageCalculator.check_hit(_bullet(3, 6, 0), 7), "ACC6 < EVA7 → 빗나감")
	t.check(DamageCalculator.check_hit(_bullet(3, 5, 0), 0), "ACC5 >= EVA0 → 명중")

	# ── 이진 관통 게이트: PEN < DEF → 0 ──
	t.eq(DamageCalculator.calculate_damage(_bullet(4, 5, 2), 3), 0, "PEN2 < DEF3 → 도탄(0)")
	# PEN >= DEF → DMG 전량 (DEF 감산 없음)
	t.eq(DamageCalculator.calculate_damage(_bullet(4, 5, 3), 3), 4, "PEN3 >= DEF3 → 풀뎀(4)")
	t.eq(DamageCalculator.calculate_damage(_bullet(4, 5, 5), 3), 4, "PEN5 >= DEF3 → 여전히 4(초과 PEN 무가치)")
	t.eq(DamageCalculator.calculate_damage(_bullet(3, 7, 0), 0), 3, "DEF0 → 항상 관통(3)")

	# ── GDD §3.2 계산 예시 재현 ──
	t.eq(DamageCalculator.calculate_damage(_bullet(4, 5, 2), 3), 0, "GDD 예시 상황A(PEN2 vs DEF3) = 0")
	t.eq(DamageCalculator.calculate_damage(_bullet(4, 5, 3), 3), 4, "GDD 예시 상황B(PEN3 vs DEF3) = 4")

	# ── 넉백 계산 ──
	t.eq(DamageCalculator.calculate_knockback(_bullet(1, 4, 0, 2)), 2, "넉백 수치 = 2")
