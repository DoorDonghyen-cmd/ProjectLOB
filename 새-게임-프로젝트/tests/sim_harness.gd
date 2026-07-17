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

	while turns < max_turns:
		if mag.is_empty():
			result = "out_of_ammo"
			break
		turns += 1
		var bullet := mag.fire()
		var hit := DamageCalculator.check_hit(bullet, enemy.current_evasion, gun)
		var dmg := 0
		var kb := 0
		if hit:
			dmg = DamageCalculator.calculate_damage(bullet, enemy.current_def, gun)
			enemy.apply_damage(dmg)
			kb = DamageCalculator.calculate_knockback(bullet, gun)
			enemy.apply_knockback(kb)
			if bullet.slow > 0:
				enemy.apply_slow(bullet.slow)
		enemy.apply_shot_and_check_shift()
		if enemy.is_dead():
			result = "win"
			log.append("T%d: %s dmg=%d kb=%d → 처치" % [turns, "HIT" if hit else "MISS", dmg, kb])
			break
		enemy.advance()
		min_dist = mini(min_dist, enemy.current_distance)
		log.append("T%d: %s dmg=%d kb=%d dist=%d hp=%d" % [
			turns, "HIT" if hit else "MISS", dmg, kb, enemy.current_distance, enemy.current_hp])
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

	# ── 데모 로그 출력 (하니스 가시성) ──
	print("  · 데모 시나리오2 로그:")
	for line in r2.log:
		print("      " + line)
