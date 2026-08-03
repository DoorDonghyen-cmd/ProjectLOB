extends RefCounted
## 탄종 3계열 행동 회귀.
## 확률 없이 경량 집중·소총 직선 관통·산탄 거리 군집을 실제 CombatManager로 검증한다.

const CombatManagerScript := preload("res://scripts/core/combat_manager.gd")


static func _gun(
	weapon_class: int,
	capacity: int = 6,
	reload_turns: int = 1
) -> GunData:
	var gun := GunData.new()
	gun.weapon_class = weapon_class
	gun.magazine_capacity = capacity
	gun.reload_turns = reload_turns
	gun.fire_mode = Enums.FireMode.SINGLE
	return gun


static func _bullet(
	weapon_class: int,
	damage: int = 4,
	penetration: int = 4,
	accuracy: int = 9,
	effect_type: int = Enums.BulletEffect.NONE,
	effect_value: int = 0
) -> BulletData:
	var bullet := BulletData.new()
	bullet.weapon_class = weapon_class
	bullet.damage = damage
	bullet.penetration = penetration
	bullet.accuracy = accuracy
	bullet.effect_type = effect_type
	bullet.effect_value = effect_value
	return bullet


static func _enemy(
	hp: int = 30,
	defense: int = 0,
	evasion: int = 0,
	distance: int = 12,
	archetype: int = Enums.EnemyArchetype.RUSHER
) -> EnemyData:
	var enemy := EnemyData.new()
	enemy.display_name = "계열 행동 표적"
	enemy.archetype = archetype
	enemy.max_hp = hp
	enemy.defense = defense
	enemy.evasion = evasion
	enemy.speed = 0
	enemy.start_distance = distance
	return enemy


static func _part(part_id: int) -> PartData:
	var part := PartData.new()
	part.part_id = part_id
	return part


static func _start(
	gun: GunData,
	enemy_data: Array[EnemyData],
	bullets: Array[BulletData],
	parts: Array[PartData] = []
) -> CombatManager:
	var cm := CombatManagerScript.new()
	cm.start_encounter(gun, enemy_data, bullets, parts)
	cm.confirm_loading(bullets)
	return cm


static func _fire_count(cm: CombatManager, count: int) -> void:
	for _i in range(count):
		if cm.state != CombatManager.State.PLAYER_TURN or cm.magazine.is_empty():
			break
		cm.fire()


static func run(t) -> void:
	t.section("AmmoFamilyBehavior")
	RunManager.infiltration_risk_level = 1

	# ── 경량탄: 적별 3회 유효 적중 ──
	var light_bullets: Array[BulletData] = []
	for _i in range(3):
		light_bullets.append(_bullet(Enums.WeaponClass.PISTOL, 1, 0, 9))
	var light_cm := _start(
		_gun(Enums.WeaponClass.PISTOL, 3),
		[_enemy()] as Array[EnemyData],
		light_bullets
	)
	_fire_count(light_cm, 2)
	t.eq(light_cm.get_focus_stacks(light_cm.enemies[0]), 2, "9mm 2회 유효 적중 → 집중 2/3")
	t.eq(light_cm.enemies[0].current_hp, 28, "집중 전 두 발은 각 1 피해")
	_fire_count(light_cm, 1)
	t.eq(light_cm.get_focus_stacks(light_cm.enemies[0]), 0, "9mm 3회째 집중 폭발 후 0")
	t.eq(light_cm.enemies[0].current_hp, 26, "9mm 세 번째 발은 기본 1 + 집중 1")
	light_cm.free()

	var enhanced_bullets: Array[BulletData] = []
	for _i in range(3):
		enhanced_bullets.append(_bullet(Enums.WeaponClass.SMG, 1, 0, 9))
	var enhanced_cm := _start(
		_gun(Enums.WeaponClass.SMG, 3),
		[_enemy()] as Array[EnemyData],
		enhanced_bullets
	)
	_fire_count(enhanced_cm, 3)
	t.eq(enhanced_cm.enemies[0].current_hp, 25, ".45 ACP 세 번째 발은 기본 1 + 집중 2")
	enhanced_cm.free()

	# 빗나감은 집중을 지우지 않는다.
	var miss_then_hit: Array[BulletData] = [
		_bullet(Enums.WeaponClass.PISTOL, 1, 0, 9),
		_bullet(Enums.WeaponClass.PISTOL, 1, 0, 0),
		_bullet(Enums.WeaponClass.PISTOL, 1, 0, 9),
	]
	# LIFO: 배열 마지막이 먼저 나가므로 명중→빗나감→명중.
	var miss_cm := _start(
		_gun(Enums.WeaponClass.PISTOL, 3),
		[_enemy(30, 0, 5)] as Array[EnemyData],
		miss_then_hit
	)
	_fire_count(miss_cm, 3)
	t.eq(miss_cm.get_focus_stacks(miss_cm.enemies[0]), 2, "빗나감 사이에서도 집중 2 유지")
	miss_cm.request_reload()
	t.eq(miss_cm.get_focus_stacks(miss_cm.enemies[0]), 0, "재장전 시작 시 집중 초기화")
	miss_cm.free()

	# 집중 추가 피해는 별도 피격이 아니므로 흡수체 셀은 3발에 정확히 3칸만 감소한다.
	var sponge_bullets: Array[BulletData] = []
	for _i in range(3):
		sponge_bullets.append(_bullet(Enums.WeaponClass.PISTOL, 1, 9, 9))
	var sponge_cm := _start(
		_gun(Enums.WeaponClass.PISTOL, 3),
		[_enemy(99, 0, 0, 12, Enums.EnemyArchetype.ABSORBER)] as Array[EnemyData],
		sponge_bullets
	)
	_fire_count(sponge_cm, 3)
	t.eq(sponge_cm.enemies[0].barrier_cells, 0, "집중 폭발도 한 발 한 셀 — 추가 배리어 차감 없음")
	sponge_cm.free()

	# ── 소총탄: 표준 1명 / 강화 3명 직선 관통 ──
	var rifle_cm := _start(
		_gun(Enums.WeaponClass.RIFLE, 1),
		[_enemy(), _enemy()] as Array[EnemyData],
		[_bullet(Enums.WeaponClass.RIFLE, 4, 4)] as Array[BulletData]
	)
	_fire_count(rifle_cm, 1)
	t.eq(rifle_cm.enemies[0].current_hp, 26, "5.56 주 대상 4 피해")
	t.eq(rifle_cm.enemies[1].current_hp, 29, "5.56 후열 1명 고정 스침 피해 1")
	rifle_cm.free()

	# 주 대상 화력이 커져도 후열 피해는 함께 증폭되지 않는다.
	var high_damage_rifle_cm := _start(
		_gun(Enums.WeaponClass.RIFLE, 1),
		[_enemy(), _enemy()] as Array[EnemyData],
		[_bullet(Enums.WeaponClass.RIFLE, 8, 4)] as Array[BulletData]
	)
	_fire_count(high_damage_rifle_cm, 1)
	t.eq(high_damage_rifle_cm.enemies[0].current_hp, 22, "고화력 5.56 주 대상 8 피해")
	t.eq(high_damage_rifle_cm.enemies[1].current_hp, 29, "고화력 5.56도 후열은 고정 스침 피해 1")
	high_damage_rifle_cm.free()

	var dmr_enemies: Array[EnemyData] = [_enemy(), _enemy(), _enemy(), _enemy()]
	var dmr_cm := _start(
		_gun(Enums.WeaponClass.DMR, 1),
		dmr_enemies,
		[_bullet(Enums.WeaponClass.DMR, 4, 4)] as Array[BulletData]
	)
	_fire_count(dmr_cm, 1)
	t.eq(dmr_cm.enemies[0].current_hp, 26, "7.62 주 대상 4 피해")
	t.eq(dmr_cm.enemies[1].current_hp, 29, "7.62 후열1 고정 스침 피해 1")
	t.eq(dmr_cm.enemies[2].current_hp, 29, "7.62 후열2 고정 스침 피해 1")
	t.eq(dmr_cm.enemies[3].current_hp, 29, "7.62 후열3 고정 스침 피해 1")
	dmr_cm.free()

	# 중간 DEF 게이트가 막히면 그 뒤를 건너뛰지 않는다.
	var blocked_cm := _start(
		_gun(Enums.WeaponClass.DMR, 1),
		[_enemy(), _enemy(30, 3), _enemy()] as Array[EnemyData],
		[_bullet(Enums.WeaponClass.DMR, 4, 2)] as Array[BulletData]
	)
	_fire_count(blocked_cm, 1)
	t.eq(blocked_cm.enemies[1].current_hp, 30, "중간 후열 DEF 게이트에서 관통 정지")
	t.eq(blocked_cm.enemies[2].current_hp, 30, "막힌 적 뒤를 건너뛰지 않음")
	blocked_cm.free()

	# 관통탄은 5.56의 깊이를 한 칸 늘린다.
	var pierce_cm := _start(
		_gun(Enums.WeaponClass.RIFLE, 1),
		[_enemy(), _enemy(), _enemy()] as Array[EnemyData],
		[_bullet(
			Enums.WeaponClass.UNIVERSAL, 4, 4, 9,
			Enums.BulletEffect.PIERCE, 1
		)] as Array[BulletData]
	)
	_fire_count(pierce_cm, 1)
	t.eq(pierce_cm.enemies[1].current_hp, 29, "관통탄+5.56 후열1 고정 스침 피해 1")
	t.eq(pierce_cm.enemies[2].current_hp, 29, "관통탄+5.56 추가 후열도 고정 스침 피해 1")
	pierce_cm.free()

	# 파츠 정액 피해는 주 대상에만 적용되고 후열에 복제되지 않는다.
	var blind_cm := _start(
		_gun(Enums.WeaponClass.RIFLE, 1),
		[_enemy(), _enemy()] as Array[EnemyData],
		[_bullet(Enums.WeaponClass.RIFLE, 4, 4)] as Array[BulletData],
		[_part(Enums.PartID.BLIND_FIRE)] as Array[PartData]
	)
	_fire_count(blind_cm, 1)
	t.eq(blind_cm.enemies[0].current_hp, 24, "블라인드파이어 +2는 주 대상에 적용")
	t.eq(blind_cm.enemies[1].current_hp, 29, "후열은 파츠 +2를 복제하지 않고 고정 스침 피해 1")
	blind_cm.free()

	# Heavy는 초과 PEN이 있을 때만 첫 후열 스침을 1에서 2로 강화한다.
	var heavy: GunData = load("res://resources/guns/heavy.tres")
	var heavy_cm := _start(
		heavy,
		[_enemy(), _enemy()] as Array[EnemyData],
		[_bullet(Enums.WeaponClass.RIFLE, 4, 4)] as Array[BulletData]
	)
	_fire_count(heavy_cm, 1)
	t.eq(heavy_cm.enemies[0].current_hp, 25, "Heavy 주 대상은 총기 DMG +1 포함 5 피해")
	t.eq(heavy_cm.enemies[1].current_hp, 28, "Heavy 초과 PEN은 첫 후열 고정 스침 피해 2")
	heavy_cm.free()

	# ── 산탄: 3m 이내 거리 군집 ──
	# start_encounter가 두 번째부터 +2m씩 배치하므로 3,2,0 → 실제 3,4,4m.
	var scatter_cm := _start(
		_gun(Enums.WeaponClass.SHOTGUN, 1),
		[_enemy(30, 0, 0, 3), _enemy(30, 0, 0, 2), _enemy(30, 0, 0, 0)] as Array[EnemyData],
		[_bullet(Enums.WeaponClass.SHOTGUN, 4, 0)] as Array[BulletData]
	)
	_fire_count(scatter_cm, 1)
	t.eq(scatter_cm.enemies[0].current_hp, 26, "12G 주 대상 4 피해")
	t.eq(scatter_cm.enemies[1].current_hp, 28, "12G 가장 가까운 군집 1명 50%")
	t.eq(scatter_cm.enemies[2].current_hp, 30, "기본 산탄 확산 상한 1명")
	scatter_cm.free()

	var spread_cm := _start(
		_gun(Enums.WeaponClass.SHOTGUN, 1),
		[_enemy(30, 0, 0, 3), _enemy(30, 0, 0, 2), _enemy(30, 0, 0, 0)] as Array[EnemyData],
		[_bullet(Enums.WeaponClass.SHOTGUN, 4, 0)] as Array[BulletData],
		[_part(Enums.PartID.SPREAD_SHOT)] as Array[PartData]
	)
	_fire_count(spread_cm, 1)
	t.eq(spread_cm.enemies[1].current_hp, 28, "확산 격발 첫 군집 피해")
	t.eq(spread_cm.enemies[2].current_hp, 28, "확산 격발 대상 +1")
	spread_cm.free()

	var far_scatter_cm := _start(
		_gun(Enums.WeaponClass.SHOTGUN, 1),
		[_enemy(30, 0, 0, 4), _enemy(30, 0, 0, 3)] as Array[EnemyData],
		[_bullet(Enums.WeaponClass.SHOTGUN, 4, 0)] as Array[BulletData]
	)
	_fire_count(far_scatter_cm, 1)
	t.eq(far_scatter_cm.enemies[0].current_hp, 26, "일반 산탄 계열 규칙은 주 대상 피해를 바꾸지 않음")
	t.eq(far_scatter_cm.enemies[1].current_hp, 30, "4m 이상에서는 산탄 확산 없음")
	far_scatter_cm.free()

	var armored_scatter_cm := _start(
		_gun(Enums.WeaponClass.SHOTGUN, 1),
		[_enemy(30, 0, 0, 3), _enemy(30, 1, 0, 2)] as Array[EnemyData],
		[_bullet(Enums.WeaponClass.SHOTGUN, 4, 0)] as Array[BulletData]
	)
	_fire_count(armored_scatter_cm, 1)
	t.eq(armored_scatter_cm.enemies[1].current_hp, 30, "산탄 보조 대상도 자신의 PEN 게이트 검사")
	armored_scatter_cm.free()

	# ── 관성 격발: 무제한 누적 대신 3회 주기 +2 ──
	var inertia_bullets: Array[BulletData] = []
	for _i in range(4):
		inertia_bullets.append(_bullet(Enums.WeaponClass.SHOTGUN, 1, 0))
	var inertia_cm := _start(
		_gun(Enums.WeaponClass.SHOTGUN, 4),
		[_enemy()] as Array[EnemyData],
		inertia_bullets,
		[_part(Enums.PartID.INERTIA_FIRE)] as Array[PartData]
	)
	_fire_count(inertia_cm, 4)
	t.eq(inertia_cm.enemies[0].current_hp, 24, "관성 격발 4발 = 기본4 + 세 번째 +2")
	inertia_cm.free()

	# ── 1차 단일 대상 사이클 후보 ──
	var tempo: GunData = load("res://resources/guns/smg.tres")
	var ammo_45: BulletData = load("res://resources/bullets/cal_45acp.tres")
	var tempo_cycle_damage := (
		ammo_45.damage + tempo.passive_dmg_bonus
	) * 6 + CaliberProfiles.focus_bonus_for_gun(tempo) * 2
	var tempo_dpt := float(tempo_cycle_damage) / float(1 + tempo.reload_turns)
	t.eq(tempo.reload_turns, 4, "Tempo 집중 예산 교환: 리로드 4턴")
	t.eq(ammo_45.damage, 3, ".45 ACP 집중 예산 교환: 기반 DMG 3")
	t.eq(snappedf(tempo_dpt, 0.01), 3.2, "Tempo 기본 6발+집중2회 = 3.20 DMG/턴")
