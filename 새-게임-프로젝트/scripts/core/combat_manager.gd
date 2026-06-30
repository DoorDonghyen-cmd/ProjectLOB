class_name CombatManager
extends Node

## 전투 루프 오케스트레이터 (다수 적 공유 트랙 + Tier 2 확장 버전)
## 상태 머신으로 전투 플로우를 제어하고, 시그널로 UI에 이벤트를 전달한다.

# ── 시그널 ──
signal encounter_started(enemy_list: Array[EnemyInstance])
signal loading_phase_started()
signal bullet_fired(bullet: BulletData, hit: bool, damage: int)
signal enemy_damaged(enemy_inst: EnemyInstance, damage: int, remaining_hp: int)
signal enemy_moved(enemy_inst: EnemyInstance, new_distance: int, speed_used: int)
signal all_enemies_moved()
signal enemy_knocked_back(enemy_inst: EnemyInstance, new_distance: int, amount: int)
signal armor_shredded(enemy_inst: EnemyInstance, new_def: int, amount: int)
signal enemy_stance_changed(enemy_inst: EnemyInstance, new_stance: Enums.EnemyStance)
signal enemy_killed(enemy_inst: EnemyInstance)
signal reload_started(turns: int)
signal reload_finished()
signal encounter_won()
signal player_died()
signal combat_log(message: String)
signal magazine_updated(remaining: int, capacity: int)
signal bullet_unloaded(bullet: BulletData)

# ── 상태 ──
enum State { INACTIVE, LOADING, PLAYER_TURN, RELOADING, WON, LOST }

var state: State = State.INACTIVE
var gun: GunData
var magazine: Magazine
var enemies: Array[EnemyInstance] = []
var last_shot_hit: bool = false
var reload_turns_remaining: int = 0
var active_relics: Array[String] = []
var unload_penalty_waived: bool = false
var _insert_seal_active: bool = false

# ── 총기 파츠 및 기믹 상태 ──
var equipped_parts: Array[PartData] = []
var chaser_pen_bonus: int = 0
var target_marker_active: bool = false
var same_stance_hit_count: int = 0
var last_stance: Enums.EnemyStance = Enums.EnemyStance.NONE
var consecutive_caliber_count: int = 0
var visible_magazine_slots: int = 2

# ── 구경 기반 순서 기억 ──
var last_fired_caliber: Enums.Caliber = Enums.Caliber.CAL_9MM


## 하위 호환 래퍼: 최근접 적 1마리를 반환한다. (UI 및 레거시 코드와의 호환용)
var enemy: EnemyInstance:
	get:
		return _get_nearest_enemy()


## 최근접 적을 반환한다 (강제 타겟팅의 핵심).
## 거리가 가장 짧은 생존 적. 동률이면 배열 앞쪽(= 먼저 등장한 적) 우선.
func _get_nearest_enemy() -> EnemyInstance:
	var nearest: EnemyInstance = null
	var min_dist: int = 99999
	for e in enemies:
		if not e.is_dead() and e.current_distance < min_dist:
			min_dist = e.current_distance
			nearest = e
	return nearest


## 생존 중인 적 목록을 반환한다.
func get_alive_enemies() -> Array[EnemyInstance]:
	var alive: Array[EnemyInstance] = []
	for e in enemies:
		if not e.is_dead():
			alive.append(e)
	return alive


## 인카운터를 시작한다. 총과 적 데이터 배열, 렐릭 및 장착 파츠 목록을 받아 초기화.
func start_encounter(gun_data: GunData, enemy_datas: Array[EnemyData], relics: Array[String] = [], parts: Array[PartData] = []) -> void:
	gun = gun_data
	enemies.clear()
	var offset := 0
	for ed in enemy_datas:
		var inst := EnemyInstance.new(ed)
		inst.start_distance += offset
		inst.current_distance += offset
		enemies.append(inst)
		# 대열이 겹치지 않고 한 줄로 늘어서도록 2m 간격 스태거링 적용
		offset += 2
	magazine = Magazine.new(gun)
	last_shot_hit = false
	active_relics = relics
	unload_penalty_waived = false
	_insert_seal_active = false
	last_fired_caliber = Enums.Caliber.CAL_9MM
	
	# 파츠 및 기믹 상태 초기화
	equipped_parts = parts
	chaser_pen_bonus = 0
	target_marker_active = false
	same_stance_hit_count = 0
	last_stance = Enums.EnemyStance.NONE
	consecutive_caliber_count = 0
	
	# 예고창 슬롯 수 보정 (Scope, Blind Fire 파츠)
	visible_magazine_slots = 2
	if _has_part(Enums.PartID.SCOPE):
		visible_magazine_slots += 1
	if _has_part(Enums.PartID.BLIND_FIRE):
		visible_magazine_slots = max(1, visible_magazine_slots - 1)
		
	encounter_started.emit(enemies)
	_enter_loading_phase()


## 장전 페이즈 진입
func _enter_loading_phase() -> void:
	state = State.LOADING
	_insert_seal_active = false
	loading_phase_started.emit()


## 장전 확인 — UI가 정렬된 총알 배열을 전달하면 탄창에 넣고 전투 시작.
func confirm_loading(bullets: Array[BulletData]) -> void:
	if state != State.LOADING:
		return
	magazine.load_bullets(bullets)
	state = State.PLAYER_TURN
	magazine_updated.emit(magazine.get_remaining(), magazine.get_capacity())
	combat_log.emit("── 탄창 장전 완료! %d발 ──" % magazine.get_remaining())


## 발사 — 탄창에서 한 발 꺼내 최근접 적에게 쏜다 (강제 타겟팅).
func fire() -> void:
	var target := _get_nearest_enemy()
	_fire_internal(target)


## 지정 사격 — 특정 적을 지정하여 쏜다 (슬로우 탄 자유 조준 사격용).
func fire_at_target(target_enemy: EnemyInstance) -> void:
	_fire_internal(target_enemy)


## 실제 격발 정산 로직
func _fire_internal(target: EnemyInstance) -> void:
	if state != State.PLAYER_TURN:
		return
	if magazine.is_empty():
		combat_log.emit("⚠ 탄창이 비었습니다! 리로드하세요.")
		return

	if _insert_seal_active:
		_insert_seal_active = false
		combat_log.emit("⏸ [납탄 봉인] 삽입한 탄환이 약실로 이동 중입니다. 다시 발사 버튼을 누르세요.")
		return

	if target == null:
		combat_log.emit("⚠ 타겟이 없습니다.")
		return

	var is_first := magazine.is_next_first_shot()
	var is_last := magazine.is_next_last_shot()
	
	# 격발 직전 탄창의 잔탄 개수
	var remaining_before_fire := magazine.get_remaining()
	var bullet := magazine.fire()

	# ── 1. 명중 판정 파츠 가산 ──
	var part_acc_bonus := 0
	
	# 연동 조준 (CHAIN_ACC): 직전 탄 명중 시 ACC +2
	if _has_part(Enums.PartID.CHAIN_ACC) and last_shot_hit:
		part_acc_bonus += 2
		combat_log.emit("   ↳ 🎯 [연동 조준] 직전 명중으로 ACC +2 적용")
		
	# 만능 약실 (VERSATILE_CHAMBER): ACC +1, PEN +1
	if _has_part(Enums.PartID.VERSATILE_CHAMBER):
		part_acc_bonus += 1
		
	# 고정밀 총열 (HIGH_PRECISION): ACC +2
	if _has_part(Enums.PartID.HIGH_PRECISION):
		part_acc_bonus += 2

	# 저격경 (MARKSMAN_SCOPE): ACC +4 상시 가산 및 첫 탄환 EVA 무시
	if _has_part(Enums.PartID.MARKSMAN_SCOPE):
		part_acc_bonus += 4
		combat_log.emit("   ↳ 🎯 [저격경] 패시브로 명중률 ACC +4 가산")

	var target_evasion := target.current_evasion
	
	# 저격경 (MARKSMAN_SCOPE) 첫 탄 확정 명중
	if _has_part(Enums.PartID.MARKSMAN_SCOPE) and is_first:
		target_evasion = 0
		combat_log.emit("   ↳ 🎯 [저격경] 첫 탄환 격발! 적의 회피율(EVA) 무시 확정 명중 적용!")
	
	# 표적 지시기 (TARGET_INDICATOR): 턴당 최초 1회 타겟 회피 0 고정
	if _has_part(Enums.PartID.TARGET_INDICATOR) and not target_marker_active:
		target_evasion = 0
		target_marker_active = true
		combat_log.emit("   ↳ 🎯 [표적 지시기] 적의 회피율을 이번 사격에 한해 0으로 고정!")

	var calc_bullet_acc := bullet.duplicate()
	calc_bullet_acc.accuracy += part_acc_bonus

	var hit := DamageCalculator.check_hit(calc_bullet_acc, target_evasion, gun)
	last_shot_hit = hit

	if hit:
		# ── 2. 대미지 및 관통 파츠 가산 ──
		var part_dmg_bonus := 0
		var part_pen_bonus := 0

		# 철갑 총열 (ARMOR_PIERCING): PEN +1
		if _has_part(Enums.PartID.ARMOR_PIERCING):
			part_pen_bonus += 1
			
		# 만능 약실 (VERSATILE_CHAMBER): PEN +1
		if _has_part(Enums.PartID.VERSATILE_CHAMBER):
			part_pen_bonus += 1
			
		# 블라인드파이어 (BLIND_FIRE): DMG +2
		if _has_part(Enums.PartID.BLIND_FIRE):
			part_dmg_bonus += 2
			combat_log.emit("   ↳ 🔫 [블라인드파이어] 정보 은폐 대가로 DMG +2 적용")
			
		# 딥로더 (DEEP_LOADER): 바닥 스택에 가까울수록 DMG 점진 증가
		if _has_part(Enums.PartID.DEEP_LOADER):
			var deep_bonus = magazine.get_capacity() - remaining_before_fire
			if deep_bonus > 0:
				part_dmg_bonus += deep_bonus
				combat_log.emit("   ↳ 📥 [딥로더] 탄창 깊이(%d)에 따른 DMG +%d 가산" % [deep_bonus, deep_bonus])
				
		# 리듬 챔버 (RHYTHM_CHAMBER): 동일 구경 연속 격발 시 DMG 보너스
		if _has_part(Enums.PartID.RHYTHM_CHAMBER):
			if bullet.caliber == last_fired_caliber:
				consecutive_caliber_count += 1
			else:
				consecutive_caliber_count = 1
			if consecutive_caliber_count >= 2:
				var rhythm_bonus := consecutive_caliber_count
				part_dmg_bonus += rhythm_bonus
				combat_log.emit("   ↳ 🎶 [리듬 챔버] 동일 구경 %d회 격발! DMG +%d 가산" % [consecutive_caliber_count, rhythm_bonus])
		else:
			consecutive_caliber_count = 0
			
		# 인터럽터 (INTERRUPTER): 직전 구경과 다를 시 DMG 보너스 (+3)
		if _has_part(Enums.PartID.INTERRUPTER):
			if bullet.caliber != last_fired_caliber:
				part_dmg_bonus += 3
				combat_log.emit("   ↳ 🔀 [인터럽터] 구경 교차 격발! DMG +3 가산")
				
		# 언더플로우 (UNDERFLOW): 탄창 가장 마지막 1발(바닥 탄) 발사 시 DMG +5
		if _has_part(Enums.PartID.UNDERFLOW) and is_last:
			part_dmg_bonus += 5
			combat_log.emit("   ↳ 💥 [언더플로우] 피날레 격발! DMG +5 가산")

		# 포인트블랭크 (POINT_BLANK): 거리 1~2칸 초근접 시 DMG +4
		if _has_part(Enums.PartID.POINT_BLANK) and target.current_distance <= 2:
			part_dmg_bonus += 4
			combat_log.emit("   ↳ ⚡ [포인트블랭크] 초근접 사격! DMG +4 가산")
			
		# 롱샷 (LONG_SHOT): 거리 3칸 이상 원거리 시 DMG 비례 상승 (DIST - 2)
		if _has_part(Enums.PartID.LONG_SHOT) and target.current_distance >= 3:
			var long_bonus = target.current_distance - 2
			part_dmg_bonus += long_bonus
			combat_log.emit("   ↳ 🎯 [롱샷] 원거리 저격! DMG +%d 가산" % long_bonus)
			
		# 관성 격발 (INERTIA_FIRE): 적 태세 고정 중 연속 명중 시 피해 누적 증가
		if _has_part(Enums.PartID.INERTIA_FIRE):
			if target.current_stance == last_stance:
				same_stance_hit_count += 1
				part_dmg_bonus += same_stance_hit_count
				combat_log.emit("   ↳ 📈 [관성 격발] 동일 태세 명중 유지! DMG +%d 누적 가산" % same_stance_hit_count)
			else:
				same_stance_hit_count = 0
			last_stance = target.current_stance

		# 체이서 (CHASER): 누적 PEN 가산
		if _has_part(Enums.PartID.CHASER):
			part_pen_bonus += chaser_pen_bonus
			if chaser_pen_bonus > 0:
				combat_log.emit("   ↳ 🚀 [체이서] 누적 관통력 PEN +%d 적용" % chaser_pen_bonus)

		var calc_bullet := bullet.duplicate()
		calc_bullet.damage += part_dmg_bonus
		calc_bullet.penetration += part_pen_bonus

		# 처형자 (EXECUTIONER): 거리 1 이하에서 체력이 3 이하인 적 즉사
		if _has_part(Enums.PartID.EXECUTIONER) and target.current_distance <= 1 and target.current_hp <= 3:
			calc_bullet.damage = target.current_hp + target.current_def + 10
			combat_log.emit("   ↳ 🗡 [처형자] 빈사 상태의 적 즉사 처형!")

		var damage := DamageCalculator.calculate_damage(
			calc_bullet, target.current_def, gun
		)
		var breakdown := DamageCalculator.damage_breakdown(
			calc_bullet, target.current_def, gun
		)

		# ── 2.3 마무리 사격 (Last Shot) 배율 적용 ──
		if bullet.effect_type == Enums.BulletEffect.LAST_SHOT and is_last:
			if damage > 0:
				var multiplier := float(bullet.effect_value) / 100.0
				var base_dmg = damage
				damage = int(round(damage * multiplier))
				breakdown += " x [막탄 배율 %s]" % str(multiplier)
				combat_log.emit("   ↳ 🎯 [막탄 강화] 탄창 최종 격발! 대미지 %d → %d" % [base_dmg, damage])

		# ── 2.4 연발 콤보 (Combo Shot) 대미지 가산 적용 ──
		if bullet.effect_type == Enums.BulletEffect.COMBO and last_shot_hit:
			if damage > 0:
				damage += bullet.effect_value
				breakdown += " + [콤보 보너스] %d" % bullet.effect_value
				combat_log.emit("   ↳ 🔥 [콤보 사격] 연속 명중 보너스! 추가 대미지 +%d" % bullet.effect_value)

		# ── 2.5 구경 다름 조건부 추가피해 ──
		if bullet.effect_type == Enums.BulletEffect.CALIBER_DIFF:
			if bullet.caliber != last_fired_caliber:
				var bonus := bullet.effect_value
				damage += bonus
				breakdown += " + [구경다름 보너스] %d" % bonus
				combat_log.emit("   ↳ ⚡ [구경 다름] 직전 구경(%s)과 다름! 추가 대미지 +%d" % [_caliber_name(last_fired_caliber), bonus])

		# ── 3. 대미지 적용 ──
		target.apply_damage(damage)
		combat_log.emit("🔫 %s → [%s] 명중! %d 대미지" % [bullet.display_name, target.data.display_name, damage])
		combat_log.emit("   %s" % breakdown)
		bullet_fired.emit(bullet, true, damage)
		enemy_damaged.emit(target, damage, target.current_hp)

		# ── 4. 피격 후 효과 ──
		_apply_post_hit_effects(bullet, target, is_first, is_last)

		# 파쇄 총구 (SHRED_MUZZLE): 명중 시 적 DEF 영구 -1
		if _has_part(Enums.PartID.SHRED_MUZZLE):
			target.apply_armor_shred(1)
			armor_shredded.emit(target, target.current_def, 1)
			combat_log.emit("   ↳ ⚙ [파쇄 총구] 명중 피드백으로 적 DEF -1 영구 파쇄!")

		# ── 4.5 관통 다중 타격 (PIERCE 효과) ──
		if bullet.effect_type == Enums.BulletEffect.PIERCE:
			var alive_list := get_alive_enemies()
			alive_list.sort_custom(func(a, b): return a.current_distance < b.current_distance)
			var target_idx := alive_list.find(target)
			if target_idx != -1:
				if target_idx + 1 < alive_list.size():
					var e2: EnemyInstance = alive_list[target_idx + 1]
					var dmg2: int = maxi(1, int(round(DamageCalculator.calculate_damage(bullet, e2.current_def, gun) * 0.5)))
					e2.apply_damage(dmg2)
					combat_log.emit("   ↳ 🎯 [관통 다중타] → [%s] 명중! %d 대미지 (50%% 감쇄)" % [e2.data.display_name, dmg2])
					enemy_damaged.emit(e2, dmg2, e2.current_hp)
					if e2.is_dead():
						combat_log.emit("💀 [%s] 처치!" % e2.data.display_name)
						enemy_killed.emit(e2)
				if target_idx + 2 < alive_list.size():
					var e3: EnemyInstance = alive_list[target_idx + 2]
					var dmg3: int = maxi(1, int(round(DamageCalculator.calculate_damage(bullet, e3.current_def, gun) * 0.25)))
					e3.apply_damage(dmg3)
					combat_log.emit("   ↳ 🎯 [관통 다중타] → [%s] 명중! %d 대미지 (75%% 감쇄)" % [e3.data.display_name, dmg3])
					enemy_damaged.emit(e3, dmg3, e3.current_hp)
					if e3.is_dead():
						combat_log.emit("💀 [%s] 처치!" % e3.data.display_name)
						enemy_killed.emit(e3)

		# ── 5. 넉백 ──
		var calc_bullet_kb := bullet.duplicate()
		calc_bullet_kb.damage += part_dmg_bonus
		calc_bullet_kb.penetration += part_pen_bonus
		
		var kb := DamageCalculator.calculate_knockback(calc_bullet_kb, gun)
		if active_relics.has("gas_valve") and kb > 0:
			kb += 1
			combat_log.emit("   ↳ 🛡 [가스 밸브] 넉백 +1 증가")
			
		# 언더플로우 (UNDERFLOW): 피날레 넉백 2배 증폭
		if _has_part(Enums.PartID.UNDERFLOW) and is_last and kb > 0:
			kb *= 2
			combat_log.emit("   ↳ 💥 [언더플로우] 피날레 넉백 2배 증폭 적용!")
			
		if kb > 0:
			target.apply_knockback(kb)
			enemy_knocked_back.emit(target, target.current_distance, kb)
			combat_log.emit("   ↳ 넉백 %d칸 → 거리 %d" % [kb, target.current_distance])
			
			# 확산 격발 장치 (SPREAD_SHOT - 샷건 고유): 주 타겟 양옆의 적들에게도 넉백 전파
			if _has_part(Enums.PartID.SPREAD_SHOT):
				var alive_list := get_alive_enemies()
				alive_list.sort_custom(func(a, b): return a.current_distance < b.current_distance)
				var idx := alive_list.find(target)
				if idx != -1:
					var splash_kb: int = maxi(1, int(kb / 2))
					if idx > 0:
						var prev_e: EnemyInstance = alive_list[idx - 1]
						prev_e.apply_knockback(splash_kb)
						enemy_knocked_back.emit(prev_e, prev_e.current_distance, splash_kb)
						combat_log.emit("     ↳ ☄ [확산 격발] 인접 적 [%s]에게 넉백 %d 전파" % [prev_e.data.display_name, splash_kb])
					if idx + 1 < alive_list.size():
						var next_e: EnemyInstance = alive_list[idx + 1]
						next_e.apply_knockback(splash_kb)
						enemy_knocked_back.emit(next_e, next_e.current_distance, splash_kb)
						combat_log.emit("     ↳ ☄ [확산 격발] 인접 적 [%s]에게 넉백 %d 전파" % [next_e.data.display_name, splash_kb])

		# ── 6. 둔화 ──
		var slow_val := bullet.slow
		if _has_part(Enums.PartID.UNDERFLOW) and is_last and slow_val > 0:
			slow_val *= 2
			combat_log.emit("   ↳ 💥 [언더플로우] 피날레 둔화 2배 증폭 적용!")
			
		if slow_val > 0:
			target.apply_slow(slow_val)
			combat_log.emit("   ↳ 둔화 -%d (다음 턴)" % slow_val)

		# ── 7. 적 사망 체크 ──
		if target.is_dead():
			combat_log.emit("💀 [%s] 처치!" % target.data.display_name)
			enemy_killed.emit(target)
			
			# 체이서 (CHASER): 처치 성공 시 다음 사격 PEN +2 누적
			if _has_part(Enums.PartID.CHASER):
				chaser_pen_bonus += 2
				combat_log.emit("   ↳ 🚀 [체이서] 처치 성공! 다음 격발 PEN +2 충전")
				
			# 리코일 푸시 (RECOIL_PUSH): 처치 시 뒷 적들 넉백 +1
			if _has_part(Enums.PartID.RECOIL_PUSH):
				combat_log.emit("   ↳ 🛡 [리코일 푸시] 처치 반동 발동!")
				for e in enemies:
					if not e.is_dead() and e != target:
						e.apply_knockback(1)
						enemy_knocked_back.emit(e, e.current_distance, 1)
						combat_log.emit("     ↳ [%s] 강제 넉백 1칸 → 거리 %d" % [e.data.display_name, e.current_distance])
	else:
		combat_log.emit("🔫 %s → [%s] 빗나감! (ACC %d < EVA %d)" % [
			bullet.display_name, target.data.display_name, bullet.accuracy, target.current_evasion
		])
		bullet_fired.emit(bullet, false, 0)

	# 직전 구경 업데이트
	last_fired_caliber = bullet.caliber

	# 탄창 상태 갱신
	magazine_updated.emit(magazine.get_remaining(), magazine.get_capacity())

	# ── 전체 적 사망 체크 (승리 조건) ──
	if _check_all_enemies_dead():
		state = State.WON
		combat_log.emit("★ 모든 적 처치! 승리!")
		encounter_won.emit()
		return

	# ── 모든 생존 적 전진 (매발 전진) ──
	_all_enemies_advance()
	if state == State.LOST:
		return

	# ── 적 상태 변환 체크 ──
	if target and not target.is_dead():
		_check_enemy_stance_shift(target)

	# 탄창 비었으면 알림
	if magazine.is_empty() and state == State.PLAYER_TURN:
		combat_log.emit("⚠ 탄창 소진! 리로드가 필요합니다.")


## 구경 이름 텍스트 변환
func _caliber_name(c: Enums.Caliber) -> String:
	match c:
		Enums.Caliber.CAL_9MM: return "9mm"
		Enums.Caliber.CAL_556: return "5.56"
		Enums.Caliber.CAL_762: return "7.62"
	return "?"


## 빼내기 요청 (Unload)
func request_unload() -> void:
	if state != State.PLAYER_TURN:
		return
	if magazine.is_empty():
		combat_log.emit("⚠ 탄창이 이미 비어있어 빼낼 탄환이 없습니다.")
		return
		
	# 퀵로드 (QUICK_LOAD) 파츠: 맨 위 탄을 잃지 않고 덱으로 빼내고, 대신 맨 바닥 탄을 잃음
	if _has_part(Enums.PartID.QUICK_LOAD):
		var bullet := magazine.unload()
		if bullet:
			combat_log.emit("⚡ [퀵로드] 맨 위 탄환 [%s]을(를) 즉시 환수하여 보관했습니다!" % bullet.display_name)
			bullet_unloaded.emit(bullet)
			
			if magazine.get_remaining() > 0:
				var lost_bullet = magazine._bullets.pop_front() # 탄창 바닥 탄 제거
				combat_log.emit("   ↳ ⚠ [퀵로드 패널티] 탄창 바닥의 [%s] 탄환이 유실되어 폐기되었습니다." % lost_bullet.display_name)
				
			magazine_updated.emit(magazine.get_remaining(), magazine.get_capacity())
			
			if magazine.is_empty() and state == State.PLAYER_TURN:
				combat_log.emit("⚠ 탄창 소진! 리로드가 필요합니다.")
		return
		
	var bullet := magazine.unload()
	if bullet:
		combat_log.emit("🗑 [%s] 탄환을 빼내어 이번 인카운터 풀에서 제외(소실)했습니다." % bullet.display_name)
		bullet_unloaded.emit(bullet)
		
		if active_relics.has("tactical_gloves") and not unload_penalty_waived:
			unload_penalty_waived = true
			combat_log.emit("🛡 [전술 장갑] Unload 패널티 적 전진이 최초 1회 면제되었습니다!")
		else:
			_unload_penalty_advance()
		
		magazine_updated.emit(magazine.get_remaining(), magazine.get_capacity())
		
		if magazine.is_empty() and state == State.PLAYER_TURN:
			combat_log.emit("⚠ 탄창 소진! 리로드가 필요합니다.")


## 인게임 중간 장전(납탄) 요청
func request_insert_bullet(bullet: BulletData) -> void:
	if state != State.PLAYER_TURN:
		return
	var cap := gun.magazine_capacity
	var has_ch := gun.has_chamber
	var max_cap := cap + (1 if has_ch else 0)
	if magazine.get_remaining() >= max_cap:
		combat_log.emit("⚠ 탄창이 가득 차서 납탄할 수 없습니다.")
		return
		
	magazine.insert_bullet(bullet)
	combat_log.emit("📥 [%s] 탄환을 탄창 맨 위에 장전했습니다. (템포 세금 소모)" % bullet.display_name)

	# 템포 세금: 모든 적 전진
	_all_enemies_advance()

	# 납탄 봉인
	if state == State.PLAYER_TURN:
		_insert_seal_active = true

	magazine_updated.emit(magazine.get_remaining(), magazine.get_capacity())


## Unload 패널티: 최근접 적만 1칸 강제 전진
func _unload_penalty_advance() -> void:
	var target := _get_nearest_enemy()
	if target == null:
		return
	target.current_distance = maxi(target.current_distance - 1, 0)
	enemy_moved.emit(target, target.current_distance, 1)
	combat_log.emit("👣 [Unload 패널티] [%s] 즉시 1칸 강제 전진! 거리 %d" % [target.data.display_name, target.current_distance])
	
	if target.is_at_player():
		state = State.LOST
		combat_log.emit("💀 적이 도달했습니다... 사망!")
		player_died.emit()


func _check_enemy_stance_shift(target: EnemyInstance) -> void:
	if target.apply_shot_and_check_shift():
		var stance_str := ""
		match target.current_stance:
			Enums.EnemyStance.IRON_SHIELD:
				stance_str = "물리 장갑 태세 (DEF 6 / EVA 1 / SPD 1)"
			Enums.EnemyStance.ACTIVE_DODGER:
				stance_str = "회피 돌격 태세 (DEF 0 / EVA 7 / SPD 3)"
		combat_log.emit("🔄 [태세 교대] [%s]가 '%s'로 변환!" % [target.data.display_name, stance_str])
		enemy_stance_changed.emit(target, target.current_stance)


## 리로드 요청
func request_reload() -> void:
	if state != State.PLAYER_TURN:
		return

	var remaining := magazine.get_remaining()
	if remaining > 0:
		combat_log.emit("남은 %d발을 버리고 리로드합니다." % remaining)

	magazine.clear()
	reload_turns_remaining = gun.reload_turns
	state = State.RELOADING
	reload_started.emit(reload_turns_remaining)
	combat_log.emit("🔄 리로드 시작! (%d턴 소요)" % reload_turns_remaining)

	while reload_turns_remaining > 0:
		reload_turns_remaining -= 1
		_all_enemies_advance()
		if state == State.LOST:
			return

	reload_finished.emit()
	combat_log.emit("🔄 리로드 완료!")
	magazine_updated.emit(0, magazine.get_capacity())
	_enter_loading_phase()


## 모든 생존 적 전진 처리
func _all_enemies_advance() -> void:
	for e in enemies:
		if e.is_dead():
			continue
		var speed_used := e.advance()
		
		# 술사가 아닐 경우에만 전진 시그널 및 로그 출력
		if e.data.archetype != Enums.EnemyArchetype.CASTER:
			enemy_moved.emit(e, e.current_distance, speed_used)
			combat_log.emit("👣 [%s] 전진 %d칸 → 거리 %d" % [e.data.display_name, speed_used, e.current_distance])

			if e.is_at_player():
				state = State.LOST
				combat_log.emit("💀 [%s]가 도달했습니다... 사망!" % e.data.display_name)
				player_died.emit()
				return
		else:
			# 술사 차징 진행
			var is_fired := e.advance_charger()
			if is_fired:
				combat_log.emit("⚠ [술사 경보] [%s]의 차징 공격 발동! 적 대열이 플레이어 방향으로 2칸 강제 전진!" % e.data.display_name)
				_caster_force_advance_all(2)
				if state == State.LOST:
					return
	all_enemies_moved.emit()


## 술사 차징 공격 시 다른 적들을 2칸 강제 전진시킴
func _caster_force_advance_all(amount: int) -> void:
	for e in enemies:
		if e.is_dead() or e.data.archetype == Enums.EnemyArchetype.CASTER:
			continue
		e.current_distance = maxi(e.current_distance - amount, 0)
		enemy_moved.emit(e, e.current_distance, amount)
		combat_log.emit("👣 [술사 강제전진] [%s]가 %d칸 강제 이동당했습니다! 거리 %d" % [e.data.display_name, amount, e.current_distance])
		
		if e.is_at_player():
			state = State.LOST
			combat_log.emit("💀 [%s]가 도달했습니다... 사망!" % e.data.display_name)
			player_died.emit()
			return


## 전체 적 사망 검사
func _check_all_enemies_dead() -> bool:
	for e in enemies:
		if not e.is_dead():
			return false
	return true


## 피격 후 효과 처리
func _apply_post_hit_effects(bullet: BulletData, target: EnemyInstance, is_first: bool, _is_last: bool) -> void:
	match bullet.effect_type:
		Enums.BulletEffect.ARMOR_SHRED:
			target.apply_armor_shred(bullet.effect_value)
			armor_shredded.emit(target, target.current_def, bullet.effect_value)
			combat_log.emit("   ↳ 장갑 파쇄! DEF -%d → %d" % [
				bullet.effect_value, target.current_def
			])
		Enums.BulletEffect.OPENING_SHOT:
			if is_first:
				target.apply_knockback(bullet.effect_value)
				combat_log.emit("   ↳ 선제 사격! 추가 넉백 +%d" % bullet.effect_value)
		_:
			pass


## 파츠 장착 여부 검사
func _has_part(part_id: Enums.PartID) -> bool:
	for p in equipped_parts:
		if p != null and p.part_id == part_id:
			return true
	return false
