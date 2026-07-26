extends RefCounted
## 발사 방식(Fire Mode) 검증 — 연발 버스트 동작과 단발 회귀.
##
## 설계 정본: docs/gdd/21_fire_mode.md
##   연발(FULL_AUTO)은 탄창 전체를 **1턴에** 쏟는다. 발당 1턴이면
##   "멈출 수만 없는 단발"이 되어 하위호환이므로, 1턴이 유일하게 성립하는 값이다.
##
## ⚠️ 전술 기관단총은 탄환 v5부터 연발로 전환되었다. 같은 SMG 클래스인 도박형은
##    블라인드 스택 관리 정체성을 위해 단발을 유지하므로 총기별 계약을 따로 검증한다.

const CombatManagerScript := preload("res://scripts/core/combat_manager.gd")

const G_SUPPRESSOR := "res://resources/guns/suppressor.tres"
const G_REVOLVER := "res://resources/guns/revolver.tres"
const G_SMG := "res://resources/guns/smg.tres"
const G_GAMBLER := "res://resources/guns/gambler.tres"
const B_TUNER_SMG := "res://resources/bullets/tuner_smg.tres"
const B_SURGE_SMG := "res://resources/bullets/surge_smg.tres"


static func _bullet(dmg: int, acc: int, pen: int) -> BulletData:
	var b := BulletData.new()
	b.damage = dmg
	b.accuracy = acc
	b.penetration = pen
	return b


static func _enemy(hp: int, def_v: int, eva: int, dist: int, spd: int = 0) -> EnemyData:
	var d := EnemyData.new()
	d.archetype = Enums.EnemyArchetype.RUSHER  # 태세 없음 → 관측 안정
	d.max_hp = hp
	d.defense = def_v
	d.evasion = eva
	d.speed = spd
	d.start_distance = dist
	return d


static func _setup(gun_path: String, enemies: Array[EnemyData], loadout: Array[BulletData]):
	var cm = CombatManagerScript.new()
	var gun: GunData = load(gun_path)
	var no_parts: Array[PartData] = []
	cm.start_encounter(gun, enemies, loadout, no_parts)
	cm.confirm_loading(loadout)
	return cm


static func run(t) -> void:
	t.section("FireMode")
	RunManager.infiltration_risk_level = 1

	# ── 데이터: fire_mode가 CSV에서 읽혀 총기에 반영되는가 ──
	var sup_csv := DataLoader.get_gun("suppressor")
	t.check(not sup_csv.is_empty(), "제압형이 gun_stats.csv에 존재")
	t.eq(int(sup_csv.fire_mode), Enums.FireMode.FULL_AUTO, "제압형 = FULL_AUTO")

	var smg_csv := DataLoader.get_gun("smg")
	t.eq(int(smg_csv.fire_mode), Enums.FireMode.FULL_AUTO, "전술 기관단총 = FULL_AUTO")
	t.eq(int(smg_csv.reload_turns), 3, "전술 기관단총 리로드 = 3턴")
	t.eq(int(smg_csv.preview_window_size), 6, "전술 기관단총 예고창 = 6발")
	t.eq(int(smg_csv.parts_capacity), 3, "전술 기관단총 파츠 슬롯 = 3")
	var smg_res: GunData = load(G_SMG)
	t.check(smg_res.default_part == null, "연발 폭증을 만들던 리듬 챔버 기본 내장 해제")

	# 전술 기관단총을 제외한 기존 총기는 단발을 유지한다. 특히 도박형은 블라인드가 핵심이다.
	for gid in ["revolver", "dmr", "shotgun", "heavy", "trickster", "gambler", "stance_hunter"]:
		var g := DataLoader.get_gun(gid)
		t.eq(int(g.fire_mode), Enums.FireMode.SINGLE, "%s = SINGLE (기존 총기 불변)" % gid)

	# ── 연발: 탄창 전체가 소비되는가 ──
	var loadout: Array[BulletData] = []
	for i in range(5):
		loadout.append(_bullet(2, 9, 5))
	# ⚠️ SPD 1로 둔다 — 전진 횟수를 세려면 실제로 움직여야 한다.
	var enemies: Array[EnemyData] = [_enemy(100, 0, 0, 6, 1)]
	var cm = _setup(G_SUPPRESSOR, enemies, loadout)

	t.check(cm.is_full_auto(), "제압형은 연발로 판정됨")
	var loaded: int = cm.magazine.get_remaining()
	t.eq(loaded, 5, "장전 5발(사전 조건)")

	var dist_before: int = cm.enemies[0].current_distance
	cm.fire()

	t.eq(cm.magazine.get_remaining(), 0, "⭐ 연발 1회로 탄창 전량 소비")
	t.eq(cm.enemies[0].current_hp, 100 - 10, "5발 × 2 = 10 대미지 적용")

	# ── 전체가 1턴인가 (적 전진 1회) ──
	# ⚠️ 이것이 연발의 성립 조건이다. 발당 전진하면 단발의 하위호환이 된다.
	var moved: int = dist_before - cm.enemies[0].current_distance
	t.eq(moved, 1, "⭐ 버스트 전체가 1턴 — 적 전진 1회 (5발인데 1칸)")
	cm.free()

	# ── 오버킬 이월: 앞 적이 죽으면 남은 탄이 다음 적으로 ──
	# 강제 타겟이 "최근접 1명"이므로 규칙 추가 없이 성립해야 한다.
	var loadout2: Array[BulletData] = []
	for i in range(5):
		loadout2.append(_bullet(2, 9, 5))
	var enemies2: Array[EnemyData] = [_enemy(4, 0, 0, 3), _enemy(20, 0, 0, 6)]
	var cm2 = _setup(G_SUPPRESSOR, enemies2, loadout2)
	var fired_targets: Array[EnemyInstance] = []
	var fired_remaining: Array[int] = []
	cm2.bullet_fired.connect(func(
		_bullet_data: BulletData,
		_hit: bool,
		_damage: int,
		target: EnemyInstance,
		remaining: int
	):
		fired_targets.append(target)
		fired_remaining.append(remaining)
	)
	cm2.fire()

	# 앞 적(HP4)은 2발로 사망, 남은 3발이 뒤 적에게 → 20 - 6 = 14
	var survivors := 0
	var back_hp := 0
	for e in cm2.enemies:
		if not e.is_dead():
			survivors += 1
			back_hp = e.current_hp
	t.eq(survivors, 1, "앞 적 사망, 뒤 적 생존")
	t.eq(back_hp, 14, "⭐ 오버킬 이월 — 남은 3발이 다음 적에게 (20 → 14)")
	t.eq(fired_targets.size(), 5, "연발 5발 모두 실제 피격 대상 스냅샷 전달")
	t.check(fired_targets[0] == cm2.enemies[0] and fired_targets[1] == cm2.enemies[0],
		"⭐ 처치까지 첫 2발은 앞 적을 가리킴")
	t.check(fired_targets[2] == cm2.enemies[1] and fired_targets[4] == cm2.enemies[1],
		"⭐ 남은 3발의 연출 대상도 뒤 적으로 이월")
	t.check(fired_remaining == [2, 0, 18, 16, 14],
		"⭐ 발별 HP 스냅샷 4→2→0 / 20→18→16→14")
	cm2.free()

	# ── 막힌 탄: 관통 게이트 미달이면 전량 무효 ──
	# 연발의 핵심 비용. "통하는 탄을 고른다"는 판단의 대가가 탄창 크기만큼 증폭된다.
	var loadout3: Array[BulletData] = []
	for i in range(5):
		loadout3.append(_bullet(3, 9, 0))  # PEN 0
	var enemies3: Array[EnemyData] = [_enemy(30, 5, 0, 6)]  # DEF 5 → 전탄 차단
	var cm3 = _setup(G_SUPPRESSOR, enemies3, loadout3)
	cm3.fire()
	t.eq(cm3.enemies[0].current_hp, 30, "⭐ 관통 실패 시 전량 0 대미지 (탄창만 소모)")
	t.eq(cm3.magazine.get_remaining(), 0, "막혀도 탄은 전부 소모됨")
	cm3.free()

	# ── ARMOR_SHRED가 버스트 도중 뒤 탄에 반영되는가 ──
	# 이것이 적재 퍼즐의 핵심이다: 앞에 파쇄, 뒤에 화력.
	var shred := _bullet(1, 9, 5)
	shred.effect_type = Enums.BulletEffect.ARMOR_SHRED
	shred.effect_value = 3
	var loadout4: Array[BulletData] = [_bullet(5, 9, 2), shred]  # LIFO: 파쇄가 먼저 나감
	var enemies4: Array[EnemyData] = [_enemy(40, 4, 0, 6)]  # DEF4 → 파쇄 후 DEF1
	var cm4 = _setup(G_SUPPRESSOR, enemies4, loadout4)
	cm4.fire()
	# 파쇄탄(PEN5 ≥ DEF4) 통과 1뎀 + DEF 4→1 / 다음 탄(PEN2 ≥ DEF1) 통과 5뎀
	t.eq(cm4.enemies[0].current_hp, 40 - 6, "⭐ 파쇄가 뒤 탄의 관통 게이트를 열어줌 (적재 퍼즐)")
	cm4.free()

	# ── 적 전멸 시 버스트가 멈추고 남은 탄은 그대로 남는다 ──
	# ⚠️ "중간에 멈출 수 없다"는 전투 **중** 판단 변경을 막는 규칙이다.
	#    쏠 대상이 사라진 뒤까지 적용해 탄창을 인위적으로 비우면,
	#    "탄창을 비운 채 승리" 같은 조건이 무의미해지고 규칙만 하나 늘어난다.
	var loadout5: Array[BulletData] = []
	for i in range(5):
		loadout5.append(_bullet(10, 9, 5))
	var enemies5: Array[EnemyData] = [_enemy(5, 0, 0, 6)]
	var cm5 = _setup(G_SUPPRESSOR, enemies5, loadout5)
	cm5.fire()
	t.eq(cm5.magazine.get_remaining(), 4, "⭐ 적 전멸 시 버스트 중단 — 남은 탄 보존")
	cm5.free()

	# ══════════════════════════════════════════════
	# 단발 회귀 — 기존 총기 동작이 바뀌지 않았는가
	# ══════════════════════════════════════════════

	# 리볼버: 1발 쏘면 1발만 소비되고 나머지는 남는다.
	var loadout6: Array[BulletData] = []
	for i in range(5):
		loadout6.append(_bullet(2, 9, 5))
	var enemies6: Array[EnemyData] = [_enemy(100, 0, 0, 6)]
	var cm6 = _setup(G_REVOLVER, enemies6, loadout6)
	t.check(not cm6.is_full_auto(), "리볼버는 연발이 아님")

	var before6: int = cm6.magazine.get_remaining()
	cm6.fire()
	t.eq(cm6.magazine.get_remaining(), before6 - 1, "⭐ 단발: 1발만 소비 (회귀)")
	t.eq(cm6.enemies[0].current_hp, 98, "단발: 2 대미지만 적용 (회귀)")
	cm6.free()

	# 전술 기관단총: 조율→과부하를 3번 연결한 6발 시퀀스가 한 턴에 완성된다.
	# 적재 배열은 LIFO이므로 페이로드를 먼저, 셋업을 나중에 넣는다.
	var loadout7: Array[BulletData] = []
	for i in range(3):
		loadout7.append((load(B_SURGE_SMG) as BulletData).duplicate())
		loadout7.append((load(B_TUNER_SMG) as BulletData).duplicate())
	var enemies7: Array[EnemyData] = [_enemy(100, 0, 6, 8, 1)]
	var cm7 = _setup(G_SMG, enemies7, loadout7)
	t.check(cm7.is_full_auto(), "전술 기관단총은 연발")
	t.check(not cm7.has_method("_fire_double_tap"), "더블탭 발사 경로 제거")
	var dist_before7: int = cm7.enemies[0].current_distance
	cm7.fire()
	t.eq(cm7.magazine.get_remaining(), 0, "⭐ 전술 기관단총 6발 전량 소비")
	t.eq(cm7.enemies[0].current_hp, 85,
		"⭐ 조율(1피해)+과부하(4피해) 3쌍 = 15피해, 버프 체인 작동")
	t.eq(dist_before7 - cm7.enemies[0].current_distance, 1,
		"전술 기관단총 6발도 적 전진은 1회")
	t.eq(cm7.pending_buff_acc, 0, "6발 체인 종료 후 보류 ACC 버프 없음")
	cm7.free()

	# 같은 SMG 클래스인 도박형은 블라인드 스택 관리 때문에 단발을 유지한다.
	var loadout_gambler: Array[BulletData] = []
	for i in range(5):
		loadout_gambler.append(_bullet(2, 9, 5))
	var gambler_enemies: Array[EnemyData] = [_enemy(100, 0, 0, 6)]
	var gambler_cm = _setup(G_GAMBLER, gambler_enemies, loadout_gambler)
	t.check(not gambler_cm.is_full_auto(), "도박형은 단발 유지")
	var gambler_before: int = gambler_cm.magazine.get_remaining()
	gambler_cm.fire()
	t.eq(gambler_cm.magazine.get_remaining(), gambler_before - 1,
		"⭐ 도박형은 발사 1회에 1발만 소비")
	gambler_cm.free()

	# ── 밸런스: 연발 총의 턴당 화력이 기존 밴드 안인가 ──
	# 사이클 = 1턴(발사) + reload_turns. 제압형은 3 → 4턴 사이클.
	var cycle: int = 1 + int(sup_csv.reload_turns)
	t.eq(cycle, 4, "제압형 사이클 = 4턴 (발사 1 + 리로드 3)")

	# 기본탄(DMG2) 5발 = 10 / 4턴 = 2.50
	var dpt := 10.0 / float(cycle)
	t.check(dpt >= 2.0 and dpt <= 3.4,
		"⭐ 기본 적재 턴당 DMG %.2f — 기존 밴드(2.14~3.33) 내" % dpt)

	var smg_cycle: int = 1 + int(smg_csv.reload_turns)
	var smg_basic_dpt := float(6 * (3 + int(smg_csv.passive_dmg_bonus))) / float(smg_cycle)
	var smg_chain_dpt := 15.0 / float(smg_cycle)
	t.eq(smg_cycle, 4, "전술 기관단총 사이클 = 4턴")
	t.eq(smg_basic_dpt, 3.0, "⭐ 전술 기관단총 기본 6발 = 3.00 DMG/턴")
	t.eq(smg_chain_dpt, 3.75, "⭐ 전술 기관단총 조율→과부하 체인 = 3.75 DMG/턴")

	# 리듬 챔버를 선택 장착해도 연속 횟수만큼 폭증하지 않고 2·4·6번째에 +1씩만 붙는다.
	var rhythm_loadout: Array[BulletData] = []
	for i in range(6):
		rhythm_loadout.append(_bullet(3, 9, 5))
	var rhythm_enemies: Array[EnemyData] = [_enemy(100, 0, 0, 8)]
	var rhythm_parts: Array[PartData] = [load("res://resources/parts/rhythm_chamber.tres")]
	var rhythm_cm = CombatManagerScript.new()
	rhythm_cm.start_encounter(smg_res, rhythm_enemies, rhythm_loadout, rhythm_parts)
	rhythm_cm.confirm_loading(rhythm_loadout)
	rhythm_cm.fire()
	t.eq(rhythm_cm.enemies[0].current_hp, 85,
		"⭐ 리듬 챔버 6발 = 기본 12 + 짝수 박자 3, 폭증 차단")
	rhythm_cm.free()

	# ⚠️ 연발 총의 패시브는 탄창 크기만큼 증폭된다. 특히 PEN은 이진 게이트라 절벽이다.
	#    (전량 0 대미지 ↔ 전량 통과) 그래서 제압형의 패시브는 전부 0이어야 한다.
	t.eq(int(sup_csv.passive_dmg_bonus), 0, "제압형 패시브 DMG = 0 (탄창 배 증폭 방지)")
	t.eq(int(sup_csv.passive_pen_bonus), 0, "⭐ 제압형 패시브 PEN = 0 (이진 게이트라 절벽)")
	t.eq(int(sup_csv.passive_acc_bonus), 0, "제압형 패시브 ACC = 0")

	# 넉백락 방어: rifle 계열 탄은 넉백이 전부 0이라 구조적으로 불가능하다.
	# ⚠️ 넉백 상한 규칙을 새로 만들지 않고 클래스 선택으로 해결했다는 사실을 못박는다.
	t.eq(int(sup_csv.class), Enums.WeaponClass.RIFLE, "제압형 = rifle 클래스 (넉백락 구조적 차단)")
	var kb_max := 0
	for bid in DataLoader.get_all_bullet_ids():
		var b := DataLoader.get_bullet(bid)
		if int(b.class) == Enums.WeaponClass.RIFLE:
			kb_max = maxi(kb_max, int(b.knockback))
	t.eq(kb_max, 0, "⭐ rifle 계열 탄의 넉백 최대치 = 0 (넉백락 불가)")

	# ── 해금 조건: [전탄 소모] 탄창을 비운 채 승리 ──
	# 연발이 강제하는 행동(전량 커밋)을 단발 총으로 미리 연습시키는 조건이다.
	var prev_unlocked: Array[String] = RunManager.meta_unlocked_weapons.duplicate()
	var prev_override: String = RunManager.save_path_override
	RunManager.save_path_override = "user://__test_firemode.cfg"

	# 탄을 남긴 채 이기면 해금되지 않는다.
	RunManager.meta_unlocked_weapons = ["workhorse"] as Array[String]
	var rm_a := RunManager.new()
	rm_a.run_stats.magazine_emptied_wins = 0
	t.check(not rm_a.check_weapon_unlocks().has("suppressor"), "탄 남기고 승리 → 제압형 미해금")

	# 탄창을 비운 채 이기면 해금된다.
	RunManager.meta_unlocked_weapons = ["workhorse"] as Array[String]
	var rm_b := RunManager.new()
	rm_b.run_stats.magazine_emptied_wins = 1
	t.check(rm_b.check_weapon_unlocks().has("suppressor"), "⭐ [전탄 소모] 달성 → 제압형 해금")

	DirAccess.remove_absolute("user://__test_firemode.cfg")
	RunManager.save_path_override = prev_override
	RunManager.meta_unlocked_weapons = prev_unlocked

	# ── 실전 판정: 전투에서 실제로 통계가 잡히는가 ──
	# ⚠️ 조건 로직만 맞고 통계가 안 쌓이면 해금이 영영 불가능하다.
	#    (실제로 "구현했는데 연결이 빠진" 결함이 반복해서 나왔다.)
	var loadout8: Array[BulletData] = [_bullet(10, 9, 5)]
	var enemies8: Array[EnemyData] = [_enemy(5, 0, 0, 6)]
	var cm8 = _setup(G_REVOLVER, enemies8, loadout8)
	cm8.fire()  # 1발로 처치 = 탄창도 비었다
	t.eq(int(cm8.battle_stats.magazine_emptied_wins), 1, "⭐ 전투가 실제로 [전탄 소모] 승리를 기록")
	cm8.free()

	# 탄이 남은 채 이긴 전투는 기록되지 않는다.
	var loadout9: Array[BulletData] = [_bullet(10, 9, 5), _bullet(10, 9, 5)]
	var enemies9: Array[EnemyData] = [_enemy(5, 0, 0, 6)]
	var cm9 = _setup(G_REVOLVER, enemies9, loadout9)
	cm9.fire()
	t.eq(int(cm9.battle_stats.magazine_emptied_wins), 0, "탄 남은 승리는 기록되지 않음")
	cm9.free()

	# ── UI 등록: 준비실 목록에 제압형이 있는가 ──
	# ⚠️ 총기를 만들어도 준비실에 등록하지 않으면 플레이어가 영영 고를 수 없다.
	t.check(LoadoutOverlay.WEAPON_PROFILES.has("suppressor"), "⭐ 준비실 무기 목록에 제압형 등록됨")
	if LoadoutOverlay.WEAPON_PROFILES.has("suppressor"):
		var prof: Dictionary = LoadoutOverlay.WEAPON_PROFILES["suppressor"]
		t.eq(str(prof.res_key), "suppressor", "준비실 res_key가 리소스와 일치")
		t.eq(int(prof.ammo), int(sup_csv.magazine_capacity), "준비실 표기 탄창 = CSV 값")
		t.eq(int(prof.cap), int(sup_csv.parts_capacity), "준비실 표기 파츠 슬롯 = CSV 값")
