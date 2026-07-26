extends RefCounted
## 탄환 역할 재조정 실전 매트릭스.
## 실제 CSV 적 스탯 + 실제 총기/탄환 리소스를 CombatManager에 넣어
## "공격탄 단독 유효 / 연계탄 전문 게이트 확장" 계약을 고정한다.

const CombatManagerScript := preload("res://scripts/core/combat_manager.gd")


static func _enemy_data(id: String) -> EnemyData:
	var row: Dictionary = DataLoader.get_enemy(id)
	var d := EnemyData.new()
	d.display_name = str(row.display_name)
	d.archetype = int(row.archetype)
	d.max_hp = int(row.max_hp)
	d.defense = int(row.defense)
	d.evasion = int(row.evasion)
	d.speed = int(row.speed)
	d.start_distance = int(row.start_distance)
	d.knockback_resistance = int(row.knockback_resistance)
	return d


## 사람이 읽는 발사 순서를 받아 LIFO 장전 순서로 뒤집어 전투한다.
static func _fight(gun_id: String, enemy_id: String, fire_order: Array[String]) -> Dictionary:
	var loadout: Array[BulletData] = []
	for i in range(fire_order.size() - 1, -1, -1):
		var bullet: BulletData = load("res://resources/bullets/%s.tres" % fire_order[i])
		loadout.append(bullet)

	var cm = CombatManagerScript.new()
	var gun: GunData = load("res://resources/guns/%s.tres" % gun_id)
	var enemies: Array[EnemyData] = [_enemy_data(enemy_id)]
	var no_parts: Array[PartData] = []
	var fired_ids: Array[String] = []
	var fired_damage: Array[int] = []
	cm.bullet_fired.connect(func(
		bullet: BulletData,
		_hit: bool,
		damage: int,
		_target: EnemyInstance,
		_remaining: int
	):
		fired_ids.append(bullet.resource_path.get_file().get_basename())
		fired_damage.append(damage)
	)
	cm.start_encounter(gun, enemies, loadout, no_parts)
	cm.confirm_loading(loadout)

	var guard := 0
	while not cm.enemies[0].is_dead() and not cm.magazine.is_empty() and guard < 20:
		guard += 1
		cm.fire()

	var enemy: EnemyInstance = cm.enemies[0]
	var total_damage := 0
	for damage in fired_damage:
		total_damage += damage
	var result := {
		"dead": enemy.is_dead(),
		"hp": enemy.current_hp,
		"def": enemy.current_def,
		"distance": enemy.current_distance,
		"fired": fired_ids,
		"damage": total_damage,
		"remaining": cm.magazine.get_remaining(),
		"pending_acc": cm.pending_buff_acc,
		"pending_pen": cm.pending_buff_pen,
	}
	cm.free()
	return result


static func run(t) -> void:
	t.section("AmmoMatrix")
	RunManager.infiltration_risk_level = 1

	# 공격탄은 연계 없이도 일반 적에게 작동한다.
	var rusher := _fight("revolver", "rusher", [
		"overpressure_pistol", "overpressure_pistol",
	])
	t.check(rusher.dead, "⭐ 고압탄 단독 2발로 폭동 돌격병 처치")
	t.eq(int(rusher.damage), 10, "고압탄 단독 피해 5×2=10")
	t.eq(rusher.fired, ["overpressure_pistol", "overpressure_pistol"],
		"고압탄 발사 순서 고정")

	# ACC 연계는 같은 공격탄을 EVA7 전문 적까지 확장한다.
	var dodger := _fight("revolver", "dodger", [
		"flare_pistol", "overpressure_pistol", "basic_pistol",
	])
	t.check(dodger.dead, "⭐ 발광→고압→재생으로 나노 침투병 처치")
	t.eq(int(dodger.damage), 9, "고회피 연계 피해 1+5+3=9")
	t.eq(dodger.fired, ["flare_pistol", "overpressure_pistol", "basic_pistol"],
		"LIFO 발사 순서가 연계→공격으로 유지")

	# DEF3 방패병은 파쇄 후 PEN2 공격탄이 단독 게이트를 넘는다.
	var tank := _fight("heavy", "tank", [
		"shred_rifle", "heavyslug_rifle", "basic_rifle",
	])
	t.check(tank.dead, "⭐ 파쇄→중격→재생 3발로 진압 방패병 처치")
	t.eq(int(tank.damage), 12, "중장형 보정 포함 2+6+4=12")
	t.eq(int(tank.def), 1, "파쇄탄으로 방패병 DEF 3→1")

	# 흡수체는 3회 유효타 배리어가 정본이라 세 번째 적중에서 HP와 무관하게 처치된다.
	var absorber := _fight("heavy", "absorber_mech", [
		"shred_rifle", "heavyslug_rifle", "heavyslug_rifle", "basic_rifle",
	])
	t.check(absorber.dead, "⭐ 파쇄→중격×2의 유효타 3회로 흡수 보안로봇 배리어 파괴")
	t.eq(int(absorber.damage), 14, "흡수체는 3회 유효타 2+6+6=14에서 처치")
	t.eq(absorber.fired.size(), 3, "흡수체 처치 후 네 번째 탄은 보존")
	t.eq(int(absorber.def), 2, "파쇄 후 흡수체 DEF 4→2")

	# 방패병은 3발째 태세 전환 후 EVA7이 되므로 마지막 탄을 ACC7 교차 구경으로 설계한다.
	var auto_tank := _fight("suppressor", "tank", [
		"shred_rifle", "heavyslug_rifle", "heavyslug_rifle", "basic_dmr",
	])
	t.check(auto_tank.dead, "⭐ 제압형 교차 구경 1버스트로 진압 방패병 처치")
	t.eq(int(auto_tank.damage), 15, "태세 전환 대응 1+5+5+4=15")
	t.eq(auto_tank.fired.size(), 4, "제압형 4발 순차 정산")

	# PEN0 ACC 연계탄은 방패병에게 막히며 버프를 만들지 않는다.
	var blocked := _fight("revolver", "tank", [
		"flare_pistol", "overpressure_pistol",
	])
	t.check(not blocked.dead, "방패병에게 ACC 연계만으로는 처치 불가")
	t.eq(int(blocked.hp), 12, "⭐ 도탄된 연계는 버프 미생성, 후속 공격도 0 피해")
	t.eq(int(blocked.pending_acc), 0, "막힌 발광탄의 ACC 버프 없음")

	# EVA9 전용 적은 탄 수치 억지가 아니라 DMR 시그니처로 카운터한다.
	var stalker := _fight("dmr", "nano_stalker", ["basic_dmr"])
	t.check(stalker.dead, "⭐ DMR 재생탄 1발로 EVA9 나노 스토커 처치")
	t.eq(int(stalker.damage), 4, "DMR 명중 게이트 우회 후 4 피해")
