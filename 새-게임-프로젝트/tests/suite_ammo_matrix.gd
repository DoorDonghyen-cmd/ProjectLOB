extends RefCounted
## 탄환 v6 실제 전투 매트릭스.
## 구경 무관 보조탄, 결정형 크리티컬, 영구 디버프, 잔여 탄창 버프와
## 조건부 공격탄의 LIFO 계약을 CombatManager 경로로 고정한다.

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
		loadout.append(load("res://resources/bullets/%s.tres" % fire_order[i]))
	var cm = CombatManagerScript.new()
	var gun: GunData = load("res://resources/guns/%s.tres" % gun_id)
	var enemies: Array[EnemyData] = [_enemy_data(enemy_id)]
	var no_parts: Array[PartData] = []
	var fired_ids: Array[String] = []
	var fired_damage: Array[int] = []
	cm.bullet_fired.connect(func(
		bullet: BulletData, _hit: bool, damage: int,
		_target: EnemyInstance, _remaining: int
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
	var result := {
		"dead": enemy.is_dead(),
		"hp": enemy.current_hp,
		"def": enemy.current_def,
		"eva": enemy.current_evasion,
		"distance": enemy.current_distance,
		"fired": fired_ids,
		"damages": fired_damage,
		"remaining": cm.magazine.get_remaining(),
		"pending_acc": cm.pending_buff_acc,
		"pending_pen": cm.pending_buff_pen,
		"pending_dmg": cm.pending_buff_dmg,
		"mag_acc": cm.magazine_buff_acc,
		"mag_pen": cm.magazine_buff_pen,
		"discard": cm.discard_pile.size(),
		"exile": cm.exile_pile.size(),
	}
	cm.free()
	return result


static func run(t) -> void:
	t.section("AmmoMatrixV6")
	RunManager.infiltration_risk_level = 1

	var base := _fight("revolver", "rusher", ["cal_9mm", "cal_9mm"])
	t.check(base.dead, "⭐ 9mm 기반탄 2발로 폭동 돌격병 처치")
	t.eq(base.damages, [3, 3], "기반탄 피해 3×2")

	# ACC+3이 없으면 12G ACC5가 EVA7에 실패하고, 있으면 통과해 5×1.5=7.
	var acc_critical := _fight("revolver", "dodger", ["marker", "cal_12g"])
	t.check(acc_critical.dead, "⭐ 표식→12G로 EVA7 게이트 개방")
	t.eq(acc_critical.damages, [2, 7], "결정형 ACC 크리티컬 floor(5×1.5)=7")

	# PEN+3이 없으면 9mm PEN1이 DEF3에 실패하고, 있으면 3×1.5=4.
	var pen_critical := _fight("revolver", "tank", ["borer", "cal_9mm"])
	t.eq(pen_critical.damages, [2, 4], "⭐ 천공→9mm 결정형 PEN 크리티컬")
	t.eq(int(pen_critical.pending_pen), 0, "인접 PEN 버프는 다음 1발에서 소비")

	# 산탄 프로필에서 PEN이 1 감소한 파쇄탄은 도탄해도 '명중' 효과를 적용한다.
	var shred_gate := _fight("shotgun", "absorber_mech", ["shred"])
	t.eq(int(shred_gate.def), 2, "⭐ 파쇄탄 명중으로 흡수체 DEF 4→2")
	t.eq(int(shred_gate.exile), 1, "피해 0 범용 파쇄탄은 전투 풀에서 소멸")
	t.check(not shred_gate.dead, "피해 0은 흡수체 배리어 유효타가 아님")

	var jammer := _fight("revolver", "dodger", ["jammer", "cal_762"])
	t.eq(int(jammer.eva), 5, "⭐ 교란탄 명중으로 EVA 7→5 영구 감소")
	t.eq(jammer.damages, [2, 4], "영구 EVA 감소가 후속 7.62 명중을 개방")

	var guide := _fight("revolver", "dodger", ["guide", "cal_45acp"])
	t.eq(int(guide.mag_acc), 1, "유도탄 잔여 탄창 ACC +1 유지")
	t.eq(guide.damages, [2, 3], "유도 ACC+1로 .45ACP 강화 규격이 EVA7 통과")

	var align := _fight("revolver", "boss_seraph", ["align", "cal_9mm"])
	t.eq(int(align.mag_pen), 1, "정렬탄 잔여 탄창 PEN +1 유지")
	t.eq(align.damages, [2, 3], "정렬 PEN+1로 9mm가 DEF2 통과")

	var booster := _fight("revolver", "rusher", ["chain", "cal_9mm"])
	t.check(booster.dead, "장약 증폭탄이 다음 1발의 피해를 높임")
	t.eq(booster.damages, [2, 5], "장약 증폭탄 2 뒤 9mm 피해 3+2")
	t.eq(int(booster.pending_dmg), 0, "인접 DMG 버프는 다음 1발에서 소비")

	var finale := _fight("revolver", "rusher", ["cal_9mm", "finale"])
	t.eq(finale.damages, [3, 7], "마무리탄 마지막 발 정액 +4")

	var opener := _fight("revolver", "tank", ["opener"])
	t.eq(int(opener.def), 2, "선제탄 첫 발 명중 시 DEF -1")

	# 명중 전문축 뒤 화력 전문축 교대탄을 발사하면 전문축 경계를 읽는다.
	var crosscal := _fight("revolver", "rusher", ["marker", "crosscal"])
	t.check(crosscal.dead, "교대탄이 명중·화력 전문축 경계를 읽음")
	t.eq(crosscal.damages, [2, 6], "교대탄 2+4")

	var control := _fight("revolver", "caster", ["impact"])
	t.check(int(control.distance) > 10, "충격탄 넉백으로 비전진 적과 거리 확보")
