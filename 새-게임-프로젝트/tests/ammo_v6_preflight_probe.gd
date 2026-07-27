extends RefCounted
## v6 초안의 기반탄을 현행 총기·적·CombatManager에 대입하는 비파괴 프로브.
## 런타임 데이터는 바꾸지 않으며 tests/reference CSV만 읽는다.

const CombatManagerScript := preload("res://scripts/core/combat_manager.gd")
const V6_CSV := "res://tests/reference/bullet_stats_v6_draft.csv"
const GUN_IDS: Array[String] = [
	"revolver", "trickster", "smg", "gambler", "heavy",
	"stance_hunter", "suppressor", "dmr", "shotgun",
]
const ENEMY_IDS: Array[String] = [
	"rusher", "tank", "dodger", "caster", "absorber_mech", "scrambler_drone",
	"sentry_drone", "nano_stalker", "neuro_caster",
	"boss_director", "boss_seraph", "boss_omega", "boss_lob_core",
]


static func _parse_class(value: String) -> int:
	match value:
		"pistol": return Enums.WeaponClass.PISTOL
		"smg": return Enums.WeaponClass.SMG
		"rifle": return Enums.WeaponClass.RIFLE
		"dmr": return Enums.WeaponClass.DMR
		"shotgun": return Enums.WeaponClass.SHOTGUN
	return Enums.WeaponClass.UNIVERSAL


static func _base_rows() -> Dictionary:
	var file := FileAccess.open(V6_CSV, FileAccess.READ)
	var headers := file.get_csv_line()
	var cols := {}
	for i in range(headers.size()):
		cols[headers[i]] = i
	var rows := {}
	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < headers.size() or line[0].is_empty():
			continue
		if line[cols.is_basic] != "true":
			continue
		var cls := _parse_class(line[cols["class"]])
		rows[cls] = {
			"id": line[cols.id],
			"damage": int(line[cols.damage]),
			"penetration": int(line[cols.penetration]),
			"accuracy": int(line[cols.accuracy]),
			"knockback": int(line[cols.knockback]),
			"slow": int(line[cols.slow]),
		}
	file.close()
	return rows


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


static func _bullet(row: Dictionary, cls: int) -> BulletData:
	var b := BulletData.new()
	b.display_name = str(row.id)
	b.weapon_class = cls
	b.damage = int(row.damage)
	b.penetration = int(row.penetration)
	b.accuracy = int(row.accuracy)
	b.knockback = int(row.knockback)
	b.slow = int(row.slow)
	b.is_basic = true
	return b


static func _first_shot(gun_id: String, enemy_id: String, base_rows: Dictionary) -> Dictionary:
	var gun := load("res://resources/guns/%s.tres" % gun_id) as GunData
	var bullet := _bullet(base_rows[gun.weapon_class], gun.weapon_class)
	var cm = CombatManagerScript.new()
	var loadout: Array[BulletData] = [bullet]
	var enemies: Array[EnemyData] = [_enemy_data(enemy_id)]
	var no_parts: Array[PartData] = []
	var observed := {"hit": false, "damage": 0}
	cm.bullet_fired.connect(func(
		_b: BulletData,
		hit: bool,
		damage: int,
		_target: EnemyInstance,
		_remaining: int
	):
		observed.hit = hit
		observed.damage = damage
	)
	cm.start_encounter(gun, enemies, loadout, no_parts)
	cm.confirm_loading(loadout)
	cm.fire()
	var target: EnemyInstance = cm.enemies[0]
	var result := {
		"enemy_id": enemy_id,
		"hit": bool(observed.hit),
		"damage": int(observed.damage),
		"effective": int(observed.damage) > 0,
		"enemy_def": int(DataLoader.get_enemy(enemy_id).defense),
		"enemy_eva": int(DataLoader.get_enemy(enemy_id).evasion),
		"start_distance": int(DataLoader.get_enemy(enemy_id).start_distance),
		"final_def": target.current_def,
		"final_eva": target.current_evasion,
	}
	cm.free()
	return result


static func generate_report() -> Dictionary:
	RunManager.infiltration_risk_level = 1
	var bases := _base_rows()
	var report := {
		"schema": "lob.ammo_v6_preflight",
		"version": 1,
		"source": V6_CSV,
		"guns": [],
	}
	for gun_id in GUN_IDS:
		var gun_row: Dictionary = DataLoader.get_gun(gun_id)
		var cls := int(gun_row["class"])
		var base: Dictionary = bases[cls]
		var shots := int(gun_row.magazine_capacity) + (1 if bool(gun_row.has_chamber) else 0)
		var cycle := (1 + int(gun_row.reload_turns)) \
			if int(gun_row.fire_mode) == Enums.FireMode.FULL_AUTO \
			else (shots + int(gun_row.reload_turns))
		var per_shot := int(base.damage) + int(gun_row.passive_dmg_bonus)
		var direct_effective := 0
		var first_shots: Array = []
		for enemy_id in ENEMY_IDS:
			var shot := _first_shot(gun_id, enemy_id, bases)
			if bool(shot.effective):
				direct_effective += 1
			first_shots.append(shot)
		report.guns.append({
			"gun_id": gun_id,
			"class": cls,
			"base_bullet_id": str(base.id),
			"shots_per_cycle": shots,
			"cycle_turns": cycle,
			"per_shot_damage_before_parts": per_shot,
			"cycle_dpt": snappedf(float(per_shot * shots) / float(cycle), 0.01),
			"direct_effective_enemies": direct_effective,
			"enemy_count": ENEMY_IDS.size(),
			"first_shots": first_shots,
		})
	return report
