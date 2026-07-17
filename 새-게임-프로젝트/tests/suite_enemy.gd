extends RefCounted
## EnemyInstance 검증 — 태세 전환(N발 주기), 전진/둔화/넉백 거리 계산.
## 정본: scripts/core/enemy_instance.gd


static func _enemy(arch: int, hp: int, def_v: int, eva: int, spd: int, dist: int, interval: int = 3) -> EnemyData:
	var d := EnemyData.new()
	d.archetype = arch
	d.max_hp = hp
	d.defense = def_v
	d.evasion = eva
	d.speed = spd
	d.start_distance = dist
	d.stance_shift_interval = interval
	return d


static func run(t) -> void:
	t.section("EnemyInstance/Stance")

	# ── TANK: 시작 IRON_SHIELD, 3발 주기 태세 교대 ──
	var tank := EnemyInstance.new(_enemy(Enums.EnemyArchetype.TANK, 12, 4, 1, 1, 12))
	t.eq(tank.current_stance, Enums.EnemyStance.IRON_SHIELD, "탱크 시작 태세 = IRON_SHIELD")
	t.eq(tank.current_def, 4, "IRON_SHIELD 초기 DEF = 4")
	tank.apply_shot_and_check_shift() # 1
	tank.apply_shot_and_check_shift() # 2
	t.eq(tank.current_stance, Enums.EnemyStance.IRON_SHIELD, "2발 후 아직 IRON_SHIELD")
	var shifted: bool = tank.apply_shot_and_check_shift() # 3 → 전환
	t.check(shifted, "3발째에 태세 전환 발생")
	t.eq(tank.current_stance, Enums.EnemyStance.ACTIVE_DODGER, "전환 후 ACTIVE_DODGER")
	t.eq(tank.current_def, 0, "ACTIVE_DODGER DEF = 0")
	t.eq(tank.current_evasion, 7, "ACTIVE_DODGER EVA = 7")

	# ── RUSHER: 태세 NONE → 전환 없음 ──
	var rush := EnemyInstance.new(_enemy(Enums.EnemyArchetype.RUSHER, 6, 0, 2, 3, 10))
	t.eq(rush.current_stance, Enums.EnemyStance.NONE, "러셔 태세 = NONE")
	t.check(not rush.apply_shot_and_check_shift(), "NONE 태세는 전환하지 않음")

	# ── 전진 / 넉백 / 둔화 거리 계산 ──
	var e := EnemyInstance.new(_enemy(Enums.EnemyArchetype.RUSHER, 6, 0, 0, 2, 10))
	t.eq(e.advance(), 2, "SPD2 → 2칸 전진")
	t.eq(e.current_distance, 8, "전진 후 거리 = 8")
	e.apply_knockback(3)
	t.eq(e.current_distance, 11, "넉백 3 → 거리 11")
	e.apply_slow(1)
	t.eq(e.advance(), 1, "둔화1 적용 시 SPD2 → 1칸만 전진")
	t.eq(e.current_distance, 10, "둔화 전진 후 거리 = 10")
