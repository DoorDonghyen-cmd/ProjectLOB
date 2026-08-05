extends RefCounted
## 실제 격발 수 기반 전투 효율 정산 회귀.

const CombatManagerScript := preload("res://scripts/core/combat_manager.gd")
const CombatOverlayV2 := preload("res://scripts/ui/overlays/combat_overlay_v2.gd")


static func _enemy_data(id: String) -> EnemyData:
	var row: Dictionary = DataLoader.get_enemy(id)
	var data := EnemyData.new()
	data.display_name = str(row.display_name)
	data.archetype = int(row.archetype)
	data.max_hp = int(row.max_hp)
	data.defense = int(row.defense)
	data.evasion = int(row.evasion)
	data.speed = int(row.speed)
	data.start_distance = int(row.start_distance)
	data.knockback_resistance = int(row.knockback_resistance)
	return data


static func run(t) -> void:
	t.section("CombatRewards")

	# 기본 보급탄도 실제 격발마다 세며, 납탄 횟수 통계와 섞이지 않는다.
	var cm := CombatManagerScript.new()
	var gun := load("res://resources/guns/revolver.tres") as GunData
	var basic := load("res://resources/bullets/cal_9mm.tres") as BulletData
	var enemies: Array[EnemyData] = [_enemy_data("rusher")]
	var no_deck: Array[BulletData] = []
	var no_parts: Array[PartData] = []
	cm.start_encounter(gun, enemies, no_deck, no_parts, basic)
	var loadout: Array[BulletData] = [basic, basic]
	cm.confirm_loading(loadout)
	cm.fire()
	cm.fire()
	t.eq(int(cm.battle_stats.shots_fired), 2, "⭐ 기본 보급탄 실제 격발 2발 집계")
	t.eq(int(cm.battle_stats.lead_bullets_fired), 0, "추가 납탄 통계는 실제 격발 수와 분리")
	cm.free()

	var c_grade := CombatOverlayV2.combat_reward_for_stats(2, 5)
	t.eq(int(c_grade.efficiency), 40, "2처치/5발은 효율 40%")
	t.eq(str(c_grade.grade), "C", "⭐ 2처치/5발은 C등급")
	t.eq(int(c_grade.credits), 10, "C등급 기본 정산 10Cr")

	var zero_shot := CombatOverlayV2.combat_reward_for_stats(0, 0)
	t.eq(int(zero_shot.efficiency), 0, "0발 분모는 100%로 폴백하지 않음")
	t.eq(str(zero_shot.grade), "D", "0발 정산은 S등급이 아님")

	var s_grade := CombatOverlayV2.combat_reward_for_stats(2, 2)
	t.eq(str(s_grade.grade), "S", "2처치/2발은 기존 S등급 유지")
	t.eq(int(s_grade.credits), 50, "S등급 기본 정산 50Cr 유지")
