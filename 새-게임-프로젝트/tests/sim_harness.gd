extends RefCounted
## 결정론적 전투 시뮬레이터 — 인카운터(적) + 탄창 스택 → 승패·마진·넉백락 산출.
## 12-combat-simulator 스킬을 실행형으로 구현. 밸런스 회귀 테스트 겸 튜닝 도구.
##
## 기본형은 "발사만" 반복하는 순수 루프(리로드/언로드 제외).
## 사용 예:
##   var e := SimHarness._enemy(Enums.EnemyArchetype.RUSHER, 6, 0, 0, 1, 10)
##   var r := SimHarness.simulate(e, [b1, b2, ...], SimHarness._gun(6, false))
##   print(r.result)  # "win" / "lose" / "out_of_ammo" / "timeout"


static func _gun(cap: int, chamber: bool) -> GunData:
	var g := GunData.new()
	g.magazine_capacity = cap
	g.has_chamber = chamber
	return g


static func _bullet(dmg: int, acc: int, pen: int, kb: int = 0, slow: int = 0) -> BulletData:
	var b := BulletData.new()
	b.damage = dmg
	b.accuracy = acc
	b.penetration = pen
	b.knockback = kb
	b.slow = slow
	return b


## 효과를 가진 탄. 연계(버프·파쇄)와 공격탄 체인을 모델링하기 위해 필요하다.
static func _fx_bullet(dmg: int, acc: int, pen: int, effect: int, value: int) -> BulletData:
	var b := _bullet(dmg, acc, pen)
	b.effect_type = effect
	b.effect_value = value
	return b


static func _enemy(arch: int, hp: int, def_v: int, eva: int, spd: int, dist: int) -> EnemyInstance:
	var d := EnemyData.new()
	d.archetype = arch
	d.max_hp = hp
	d.defense = def_v
	d.evasion = eva
	d.speed = spd
	d.start_distance = dist
	return EnemyInstance.new(d)


## 전투 시뮬레이션. 결과 딕셔너리를 반환한다.
static func simulate(enemy: EnemyInstance, bullets: Array, gun: GunData, max_turns: int = 200) -> Dictionary:
	var mag := Magazine.new(gun)
	var typed: Array[BulletData] = []
	for b in bullets:
		typed.append(b)
	mag.load_bullets(typed)

	var log: Array[String] = []
	var start_dist := enemy.current_distance
	var min_dist := start_dist
	var turns := 0
	var result := "timeout"
	var total_damage := 0

	# ── 연계 버프 상태 (정본: docs/gdd/22_ammo_expansion.md §22.2) ──
	# 공격탄은 일반 적에게 단독으로 작동하고, 버프는 다음 1발의 대응 범위를 넓힌다.
	# 규칙: 다음 1발만 · 유효 적중 시에만 · 중첩 없음.
	var pending_acc := 0
	var pending_pen := 0
	var buffed_shots := 0

	while turns < max_turns:
		if mag.is_empty():
			result = "out_of_ammo"
			break
		turns += 1
		var bullet := mag.fire()

		# 대기 중인 버프를 이번 탄에 소비한다(다음 1발 한정이므로 즉시 비운다).
		var eff_bullet := bullet
		if pending_acc != 0 or pending_pen != 0:
			eff_bullet = bullet.duplicate()
			eff_bullet.accuracy += pending_acc
			eff_bullet.penetration += pending_pen
			buffed_shots += 1
		var used_acc := pending_acc
		var used_pen := pending_pen
		pending_acc = 0
		pending_pen = 0

		var hit := DamageCalculator.check_hit(eff_bullet, enemy.current_evasion, gun)
		var dmg := 0
		var kb := 0
		if hit:
			dmg = DamageCalculator.calculate_damage(eff_bullet, enemy.current_def, gun)
			enemy.apply_damage(dmg)
			total_damage += dmg
			kb = DamageCalculator.calculate_knockback(eff_bullet, gun)
			enemy.apply_knockback(kb)
			if bullet.slow > 0:
				enemy.apply_slow(bullet.slow)

			# ── 연계 효과 ──
			# ⚠️ 파쇄는 **명중만으로** 발동한다. 유효 적중을 요구하면 관통 게이트를
			#    여는 제 역할을 못 한다(막혔을 때 써야 의미가 있는 탄이므로).
			#    반대로 버프는 **유효 적중**을 요구한다 — "막힌 탄은 아무 일도 일으키지 않는다".
			if bullet.effect_type == Enums.BulletEffect.ARMOR_SHRED:
				enemy.apply_armor_shred(bullet.effect_value)
			elif dmg > 0:
				if bullet.effect_type == Enums.BulletEffect.BUFF_ACC:
					pending_acc = bullet.effect_value
				elif bullet.effect_type == Enums.BulletEffect.BUFF_PEN:
					pending_pen = bullet.effect_value

		enemy.apply_shot_and_check_shift()
		var tag := "HIT" if hit else "MISS"
		var buff_tag := ""
		if used_acc != 0 or used_pen != 0:
			buff_tag = " [버프 ACC+%d PEN+%d]" % [used_acc, used_pen]
		if enemy.is_dead():
			result = "win"
			log.append("T%d: %s%s dmg=%d kb=%d → 처치" % [turns, tag, buff_tag, dmg, kb])
			break
		enemy.advance()
		min_dist = mini(min_dist, enemy.current_distance)
		log.append("T%d: %s%s dmg=%d kb=%d dist=%d hp=%d def=%d" % [
			turns, tag, buff_tag, dmg, kb, enemy.current_distance, enemy.current_hp, enemy.current_def])
		if enemy.is_at_player():
			result = "lose"
			break

	return {
		"result": result,
		"turns": turns,
		"remaining_hp": enemy.current_hp,
		"final_distance": enemy.current_distance,
		"min_distance": min_dist,
		"start_distance": start_dist,
		"total_damage": total_damage,
		"buffed_shots": buffed_shots,
		# 넉백 우세(홀딩): 적이 시작 거리보다 가까워진 적이 없고 몇 턴 이상 버팀
		"knockback_lock": min_dist >= start_dist and turns >= 3,
		"log": log,
	}


static func run(t) -> void:
	t.section("CombatSim")

	# ── 시나리오1: PEN0 탄으로는 DEF3 적 처치 불가 (이진 관통 게이트) ──
	var e1 := _enemy(Enums.EnemyArchetype.RUSHER, 12, 3, 0, 1, 12)
	var bs1: Array = []
	for i in range(6):
		bs1.append(_bullet(3, 7, 0))
	var r1 := simulate(e1, bs1, _gun(6, false))
	t.check(r1.result != "win", "PEN0 탄으로 DEF3 적 처치 불가 (실제=%s)" % r1.result)

	# ── 시나리오2: PEN4 탄이면 DEF3 관통해 처치 ──
	var e2 := _enemy(Enums.EnemyArchetype.RUSHER, 6, 3, 0, 1, 12)
	var bs2: Array = []
	for i in range(6):
		bs2.append(_bullet(3, 7, 4))
	var r2 := simulate(e2, bs2, _gun(6, false))
	t.eq(r2.result, "win", "PEN4 탄이면 DEF3 관통 처치")

	# ── 시나리오3: 넉백 우세 홀딩 감지 ──
	var e3 := _enemy(Enums.EnemyArchetype.RUSHER, 30, 0, 0, 1, 8)
	var bs3: Array = []
	for i in range(6):
		bs3.append(_bullet(1, 7, 0, 3)) # 강넉백(3) > 적 SPD(1)
	var r3 := simulate(e3, bs3, _gun(6, false))
	t.check(r3.knockback_lock, "넉백(3) > SPD(1) 홀딩 구간을 하니스가 감지")

	# ── 시나리오4: 빗나감(ACC<EVA)은 탄 소모하되 무피해 ──
	var e4 := _enemy(Enums.EnemyArchetype.RUSHER, 6, 0, 8, 1, 12) # EVA8
	var bs4: Array = []
	for i in range(6):
		bs4.append(_bullet(5, 4, 0)) # ACC4 < EVA8 → 전부 빗나감
	var r4 := simulate(e4, bs4, _gun(6, false))
	t.eq(r4.result, "out_of_ammo", "ACC<EVA면 전탄 빗나가 탄 소진")
	t.eq(r4.remaining_hp, 6, "빗나감은 HP 무변화")

	# ══════════════════════════════════════════════════════════
	# 연계/공격 체인 (정본: docs/gdd/22_ammo_expansion.md)
	#
	# 공격탄은 일반 적에게 단독으로 작동하고, 연계탄은 고회피·중장갑 전문 적까지
	# 대응 범위를 넓힌다. 실패 시 전탄 무효가 아니라 효율 손실로 남기는 것이 목표다.
	# ══════════════════════════════════════════════════════════

	# ── 시나리오5: 공격탄은 일반 EVA5 적에게 단독으로 작동한다 ──
	var e5 := _enemy(Enums.EnemyArchetype.RUSHER, 30, 0, 5, 0, 12)
	var bs5: Array = []
	for i in range(6):
		bs5.append(_bullet(5, 5, 1))
	var r5 := simulate(e5, bs5, _gun(6, false))
	t.eq(int(r5.total_damage), 30, "⭐ 공격탄 단독 → EVA5 적에게 5×6=30 피해")

	# ── 시나리오6: 연계탄은 같은 공격탄을 EVA7 전문 적까지 확장한다 ──
	# ⚠️ LIFO: 나중에 넣은 탄이 먼저 나가므로, 연계탄을 공격탄보다 뒤에 적재한다.
	var e6 := _enemy(Enums.EnemyArchetype.RUSHER, 20, 0, 7, 0, 12)
	var bs6: Array = []
	for i in range(3):
		bs6.append(_bullet(5, 5, 1))                                    # 공격 (먼저 적재)
		bs6.append(_fx_bullet(1, 8, 1, Enums.BulletEffect.BUFF_ACC, 3)) # 연계 (나중 적재)
	var r6 := simulate(e6, bs6, _gun(6, false))
	t.eq(int(r6.total_damage), 18,
		"⭐ ACC 연계→공격 3쌍 = 18 피해, EVA7까지 대응")
	t.check(int(r6.buffed_shots) >= 3, "버프가 실제로 %d발에 적용됨" % int(r6.buffed_shots))

	# ── 시나리오7: PEN2 공격탄은 일반 DEF2 적에게 단독으로 작동한다 ──
	var e7 := _enemy(Enums.EnemyArchetype.RUSHER, 25, 2, 0, 0, 12)
	var bs7: Array = []
	for i in range(6):
		bs7.append(_bullet(5, 6, 2))
	var r7 := simulate(e7, bs7, _gun(6, false))
	t.eq(int(r7.total_damage), 25, "⭐ PEN2 공격탄 단독 → DEF2 적에게 25 피해")

	# PEN3 연계 → PEN2 공격탄(+3)으로 DEF3 전문 적 대응.
	var e8 := _enemy(Enums.EnemyArchetype.RUSHER, 25, 3, 0, 0, 12)
	var bs8: Array = []
	for i in range(3):
		bs8.append(_bullet(5, 6, 2))
		bs8.append(_fx_bullet(1, 6, 3, Enums.BulletEffect.BUFF_PEN, 3))
	var r8 := simulate(e8, bs8, _gun(6, false))
	t.eq(int(r8.total_damage), 18,
		"⭐ PEN 연계→공격 3쌍 = 18 피해, DEF3까지 대응")

	# ── 시나리오8: 버프는 다음 1발만 (누수 방지) ──
	# 연계 1발 + 공격 3발 → 첫 공격만 버프를 받아야 한다.
	var e9 := _enemy(Enums.EnemyArchetype.RUSHER, 40, 0, 7, 0, 12)
	var bs9: Array = []
	for i in range(3):
		bs9.append(_bullet(5, 5, 1))
	bs9.append(_fx_bullet(1, 8, 1, Enums.BulletEffect.BUFF_ACC, 3))
	var r9 := simulate(e9, bs9, _gun(6, false))
	t.eq(int(r9.buffed_shots), 1,
		"⭐ 버프는 다음 1발만 — 연계 1발에 버프 적용도 1발")

	# ── 시나리오9: 막힌 연계탄은 버프를 주지 않는다 ──
	# 연계(PEN0)가 DEF3에 막히면 뒤 공격탄은 ACC5로 EVA7에 빗나간다.
	var e10 := _enemy(Enums.EnemyArchetype.RUSHER, 30, 3, 7, 0, 12)
	var bs10: Array = []
	for i in range(3):
		bs10.append(_bullet(5, 5, 4))
		bs10.append(_fx_bullet(1, 8, 0, Enums.BulletEffect.BUFF_ACC, 3))
	var r10 := simulate(e10, bs10, _gun(6, false))
	t.eq(int(r10.buffed_shots), 0,
		"⭐ 관통 실패한 연계는 버프를 주지 않음 (유효 적중 조건)")

	# ── 시나리오10: 파쇄는 막혀도 발동한다 (버프와의 의도된 비대칭) ──
	# ⚠️ 파쇄가 유효 적중을 요구하면 관통 게이트를 여는 제 역할을 못 한다.
	#    막혔을 때 써야 의미가 있는 탄이므로 **명중만으로** 발동해야 한다.
	var e11 := _enemy(Enums.EnemyArchetype.RUSHER, 30, 4, 0, 0, 12)
	var bs11: Array = []
	for i in range(6):
		bs11.append(_fx_bullet(1, 7, 0, Enums.BulletEffect.ARMOR_SHRED, 2))  # PEN0 → 전탄 막힘
	var r11 := simulate(e11, bs11, _gun(6, false))
	t.check(e11.current_def < 4,
		"⭐ 파쇄는 관통에 막혀도 DEF를 깎는다 (4 → %d) — 버프와 의도된 비대칭" % e11.current_def)

	# ── 데모 로그 출력 (하니스 가시성) ──
	print("  · 연계→공격 체인 로그 (시나리오6):")
	for line in r6.log:
		print("      " + line)
