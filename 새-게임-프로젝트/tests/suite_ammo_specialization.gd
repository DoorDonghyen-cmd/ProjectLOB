extends RefCounted
## 전투 전문축 분리 회귀: 실제 총기·적·시작 패키지로 기본/환기구 첫 탄창의
## 처치 또는 유효 대응 해법이 하나 이상 남는지 전수 검사한다.

const CombatManagerScript := preload("res://scripts/core/combat_manager.gd")

const GUN_IDS: Array[String] = [
	"revolver", "trickster", "smg", "gambler", "heavy",
	"stance_hunter", "suppressor", "dmr", "shotgun",
]
const ENEMY_IDS: Array[String] = [
	"rusher", "tank", "dodger", "caster", "absorber_mech", "scrambler_drone",
	"sentry_drone", "nano_stalker", "neuro_caster",
	"boss_director", "boss_seraph", "boss_omega", "boss_lob_core",
]


static func _build_orders(
	base_id: String,
	capacity: int,
	limits: Dictionary,
	current: Array[String],
	result: Array[Array]
) -> void:
	if current.size() == capacity:
		result.append(current.duplicate())
		return
	current.append(base_id)
	_build_orders(base_id, capacity, limits, current, result)
	current.pop_back()
	for ammo_id_variant in limits.keys():
		var ammo_id := str(ammo_id_variant)
		if int(limits[ammo_id]) <= 0:
			continue
		limits[ammo_id] = int(limits[ammo_id]) - 1
		current.append(ammo_id)
		_build_orders(base_id, capacity, limits, current, result)
		current.pop_back()
		limits[ammo_id] = int(limits[ammo_id]) + 1


static func _orders_for(gun: GunData) -> Array[Array]:
	var ids: Array = RunManager.STARTING_AMMO_IDS.get(gun.weapon_class, [])
	var result: Array[Array] = []
	if ids.size() != 3:
		return result
	var current: Array[String] = []
	_build_orders(
		str(ids[0]), gun.magazine_capacity + (1 if gun.has_chamber else 0),
		{str(ids[1]): 2, str(ids[2]): 1}, current, result)
	return result


static func _safe_progress(gun: GunData, enemy_data: EnemyData, fire_order: Array) -> bool:
	var loadout: Array[BulletData] = []
	for i in range(fire_order.size() - 1, -1, -1):
		var bullet := load("res://resources/bullets/%s.tres" % str(fire_order[i])) as BulletData
		loadout.append(bullet.duplicate())
	var cm = CombatManagerScript.new()
	var enemies: Array[EnemyData] = [enemy_data]
	var no_parts: Array[PartData] = []
	cm.start_encounter(gun, enemies, loadout, no_parts)
	cm.confirm_loading(loadout)
	var target: EnemyInstance = cm.enemies[0]
	var hp_before := target.current_hp
	var barrier_before := target.barrier_cells
	var def_before := target.current_def
	var eva_before := target.current_evasion
	var distance_before := target.current_distance
	var guard := 0
	while not cm.magazine.is_empty() \
			and cm.state != CombatManagerScript.State.LOST \
			and not target.is_dead() \
			and guard < 12:
		guard += 1
		cm.fire()
	var won := target.is_dead()
	var progressed := (
		target.current_hp < hp_before
		or target.barrier_cells < barrier_before
		or target.current_def < def_before
		or target.current_evasion < eva_before
		or target.current_distance > distance_before
	)
	cm.free()
	# 보스·정예와 -2m 위험 변형은 첫 탄창 생존을 보장하는 대상이 아니다.
	# 이 스위트는 전문축 변경으로 공격·관통·명중·제어 대응 자체가 막히지 않았는지만 맡는다.
	return won or progressed


static func _has_solution(gun_id: String, enemy_id: String, distance_delta: int) -> bool:
	var gun := (load("res://resources/guns/%s.tres" % gun_id) as GunData).duplicate()
	var source := load("res://resources/enemies/%s.tres" % enemy_id) as EnemyData
	for order in _orders_for(gun):
		var enemy := source.duplicate()
		enemy.start_distance = maxi(enemy.start_distance + distance_delta, 1)
		if _safe_progress(gun, enemy, order):
			return true
	return false


static func run(t) -> void:
	t.section("AmmoSpecialization(9x13)")
	RunManager.infiltration_risk_level = 1
	var failures: Array[String] = []
	for gun_id in GUN_IDS:
		for enemy_id in ENEMY_IDS:
			for distance_delta in [0, -2]:
				if not _has_solution(gun_id, enemy_id, distance_delta):
					failures.append("%s→%s(%+dm)" % [gun_id, enemy_id, distance_delta])
	t.eq(failures.size(), 0,
		"⭐ 시작 패키지 9총기×13적 기본/환기구 첫 탄창 유효 대응 해법 (실패: %s)" % [failures])
