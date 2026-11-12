extends RefCounted
const AttackBoosts = preload("res://redesign/attack_boosts.gd")
## One serializable state; commands validate before mutation. Preview executes the
## same shot resolver on a copy and never changes live state or RNG.
const Content = preload("res://redesign/content.gd")
const Ranged = preload("res://redesign/ranged.gd")
const Wreckage = preload("res://redesign/wreckage.gd")
const Noble = preload("res://redesign/noble_house.gd")
const Central = preload("res://redesign/central_guard.gd")
const Patterns = preload("res://redesign/leader_patterns.gd")
const BossSkills = preload("res://redesign/boss_skills.gd")
const Engines = preload("res://redesign/damage_engines.gd")
const Gates = preload("res://redesign/gate_upgrades.gd")
const Reserve = preload("res://redesign/ammo_reserve.gd")
const MagazineTrial = preload("res://redesign/magazine_trial.gd")
const FireHeatTrial = preload("res://redesign/fire_heat_trial.gd")
const WeaponRoles = preload("res://redesign/weapon_role_trial.gd")
# Deck-building revision for new full-climb runs (2026-11-01). See magazine_build.gd.
const MagazineBuild = preload("res://redesign/magazine_build.gd")
const FocusBuild = preload("res://redesign/focus_build.gd")
const BuildEngine = preload("res://redesign/build_engine.gd")
const GrowthV2 = preload("res://redesign/growth_structure.gd")
const TagBuild = preload("res://redesign/tag_build.gd")
const Overheat = preload("res://redesign/overheat_cost.gd")
const RewardTrim = preload("res://redesign/reward_trim.gd")
const RewardMix = preload("res://redesign/reward_mix.gd")
const MixCombo = preload("res://redesign/mix_combo.gd")
const Salvage = preload("res://redesign/salvage.gd")
const PartTuning = preload("res://redesign/part_tuning.gd")
const AmmoRevision = preload("res://redesign/ammo_revision.gd")
const Roles = preload("res://redesign/combat_roles.gd")
const Balance = preload("res://redesign/run_balance.gd")
const VERSION := 15
var s: Dictionary = {}
# Exact forecast resolves the same rules without presentation snapshots or draws
# after the final action. This flag is never serialized or used by live commands.
var forecast_only := false
var last_reload_detail: Dictionary = {}
var _save_history: RefCounted

func start(gun_id: String, run_seed: int, course: bool = false, outfit: String = "work") -> void:
	assert(Content.GUNS.has(gun_id) and Content.OUTFITS.has(outfit))
	s = {"weapon_version": 1, "version": VERSION, "ammo_cycle": 1, "outfit": outfit, "bag_version": Content.BAG_VERSION, "bag_upgrades": 0, "course": course, "seed": str(run_seed), "gun": gun_id, "part": "none", "equipped_parts": [], "floor": 0, "deck": Content.cycle_start_deck(Content.COURSE_GRANTS[0]) if course else Content.start_deck(gun_id), "turns": 0, "shots": 0, "reloads": 0, "history": [], "reward_taken": false}
	if gun_id in WeaponRoles.KINDS:
		# New weapons have no historical insertion/heat mode. Their raw Model
		# entry is also save-valid; Campaign adds its current roles and economy.
		assert(not course)
		s.phase="plan";s.magazine=[]
		s.magazine_trial_version=MagazineTrial.VERSION;s.weapon_magazine_version=MagazineTrial.WEAPON_VERSION
		s.reserve_version=Reserve.VERSION;s.magazine_build_version=MagazineBuild.VERSION
		s.deck=MagazineBuild.start_deck(gun_id)
		FireHeatTrial.activate_campaign(s)
		WeaponRoles.activate(s,gun_id)
	begin_encounter()

func begin_encounter(field_charges: int = 1) -> void:
	WeaponRoles.clear(s)
	if Roles.enabled(s):s.fire_zones=[]
	if FireHeatTrial.enabled(s):s.fire_heat_trial.rounds=0
	if Reserve.emergency_enabled(s): s.emergency_uses = 0
	Engines.begin(s)
	Gates.begin(s)
	s.phase = "plan"
	s.enemies = Content.enemies_for(int(s.floor), int(s.seed), s.get("course", false), str(s.gun))
	s.reinforcements = []
	s.projectiles = []
	s.projectile_serial = 0
	s.loss_reason = ""
	assign_opening_lanes()
	s.encounter_total = s.enemies.size()
	s.deployed = s.enemies.size()
	s.wave = 1
	s.hand = []
	s.draw = s.deck.duplicate()
	s.discard = []
	s.magazine = []
	if MagazineBuild.enabled(s): s.magazine_loaded = []
	s.plan = []
	s.plan_load_order = []
	s.buff = {}
	s.heat = 0
	Content.Sustained.reset(s)
	s.legacy_reload_penalty = 0
	s.previous_kill = false
	s.prepared = []
	if AmmoRevision.enabled(s): s.held_front = []
	s.push_left = Content.push_budget(s)
	s.exchange_left = Content.exchange_capacity(s)
	s.field_compression_left = 0 if s.get("course", false) else clampi(field_charges, 0, 2) + Content.field_compression_bonus(s)
	s.field_compression = {}
	s.supply = supply_capacity()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(s.seed) + int(s.floor) * 104729
	s.rng_state = str(rng.state)
	s.target_rng_state = _target_state(s)
	_shuffle(s.draw)
	if GrowthV2.enabled(s): GrowthV2.order_draw(s)
	Reserve.prepare_opening(s, Content.source_id)
	_refill()
	if s.get("course", false):
		# Each newly taught round is in the first hand. Keep ownership and RNG intact.
		for id in Content.COURSE_GRANTS[int(s.floor)]:
			if not s.hand.has(id) and s.draw.has(id):
				var replace_index: int = s.hand.size() - 1
				while Content.COURSE_GRANTS[int(s.floor)].has(s.hand[replace_index]) and s.hand.count(s.hand[replace_index]) == 1:
					replace_index -= 1
				var outgoing = s.hand[replace_index]
				s.hand.remove_at(replace_index)
				s.draw.erase(id)
				s.draw.append(outgoing)
				s.hand.push_front(id)
	s.message = "마지막에 넣은 탄부터 발사 · 발사 순서는 왼쪽부터 · 확정 전 자유롭게 설계"
	_record("encounter", {"index": s.floor})

func capacity() -> int:
	return Content.capacity(s)

func reload_cost() -> int:
	if MagazineTrial.weapons_enabled(s):
		var inferno_cost:=1 if Roles.builds(s) and Content.equipped_parts(s).has("inferno") else 0
		return maxi(2, base_reload_cost()-inferno_cost)+inferno_cost
	if MagazineTrial.enabled(s): return base_reload_cost() + 1
	return base_reload_cost() + (1 if int(s.get("heat", 0)) >= Content.heat_limit(s) else 0) + int(s.get("legacy_reload_penalty", 0))

func base_reload_cost() -> int:
	return maxi(1, int(Content.weapon_spec(s).reload) + Content.reload_modifier(s))

func assign_opening_lanes() -> void:
	var used: Array = []
	for enemy in s.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0: continue
		var lane := int(enemy.get("lane", -1))
		if lane < 0 or lane > 3 or used.has(lane):
			lane = 0
			while used.has(lane) and lane < 4: lane += 1
		enemy.lane = clampi(lane, 0, 3)
		used.append(enemy.lane)
	for enemy in s.get("reinforcements", []): enemy.lane = -1

func supply_capacity() -> int:
	return Content.supply_capacity(s)

func available(id: String) -> int:
	return (int(s.supply) if id == "basic" and not Content.uses_ammo_cards(s) else s.hand.count(id)) - s.plan.count(id)

func can_load(id: String) -> bool:
	return load_block_reason(id).is_empty()

func load_block_reason(id: String) -> String:
	if MagazineTrial.enabled(s): return "탄창 단위로 교체"
	if s.phase != "plan": return "장전 확정 상태"
	if not Content.AMMO.has(id) or Content.is_temporary(id): return "직접 장전 불가"
	if available(id) <= 0: return "보유 없음"
	var reason := Content.insertion_block_reason(s.plan, id, capacity())
	if Reserve.enabled(s) and reason == "선두 탄 회수": return "첫 발 고정"
	return reason

func load_round(id: String) -> bool:
	if not can_load(id):
		return false
	var index := Content.insertion_index(s.plan, id)
	s.plan.insert(index, id)
	s.plan_load_order.append(id)
	s.message = "%s를 맨 앞에 장전 · 마지막에 넣은 탄부터 발사합니다." % Content.AMMO[id].name
	return true

func undo() -> bool:
	# Recall the stack top, including after an explicit rail edit.
	return remove_planned(0)

func confirm() -> bool:
	if s.phase != "plan" or s.plan.is_empty() or not Content.valid_stack(s.plan, capacity()):
		return false
	for id in s.plan:
		if not Content.AMMO.has(id) or (Content.is_temporary(id) and str(s.field_compression.get("id", "")) != id) or (not Content.is_temporary(id) and available(id) < 0):
			return false
	for id in s.plan:
		if id == "basic" and not Content.uses_ammo_cards(s):
			s.supply -= 1
		elif not Content.is_temporary(id):
			s.hand.erase(id)
	s.magazine = s.plan.duplicate()
	s.previous_kill = false
	if not s.field_compression.is_empty(): s.field_compression.zone = "magazine"
	_record("load", {"load_order": s.plan.duplicate(), "hand_left": s.hand.duplicate()})
	s.plan.clear()
	s.plan_load_order.clear()
	s.phase = "ready"
	s.message = "장전 확정. 발사하거나 %d턴을 써서 다시 장전할 수 있습니다." % reload_cost()
	return true

func fire() -> bool:
	if s.phase != "ready" or s.magazine.is_empty():
		return false
	var results: Array = []
	var peak_heat := int(s.get("heat", 0))
	var overdrive_pending := false
	var overdrive_used := false
	# Amplifier is the deliberate single-shot weapon, but a kill keeps the trigger
	# window open. The first survivor ends the execution chain and advances time.
	var count: int = s.magazine.size() if Content.chains(s) or s.gun == "amplifier" else 1
	# 냉각 약실 (part_tuning.gd): the first attack round after a manual cool.
	var breech := PartTuning.breech_ready(s, Content.active_parts(s))
	if MagazineTrial.enabled(s): count = mini(count, MagazineTrial.pulse(s))
	var recent_rounds: Array = _recent_part_rounds()
	var previous_round: String = str(recent_rounds.back()) if not recent_rounds.is_empty() else ""
	var recent_sources: Array = _recent_part_sources()
	var fired_in_action := 0
	while fired_in_action < count or (MagazineTrial.weapons_enabled(s) and overdrive_pending):
		if target_index() < 0 or s.magazine.is_empty():
			break
		fired_in_action += 1
		var weapon_factor := WeaponRoles.consume_front(s)
		var id: String = s.magazine.pop_front()
		var source: String = Content.source_id(id)
		var triad_ready: bool = recent_sources.size() >= 2 and recent_sources[-1] != recent_sources[-2] and source != recent_sources[-1] and source != recent_sources[-2]
		var result := _shot(id, -1, {"weapon_factor":weapon_factor,"overdrive":overdrive_pending,"first": recent_sources.is_empty(), "last": s.magazine.is_empty(), "last_attack": not s.magazine.any(func(round_id): return Content.is_attack(str(round_id))), "triad": triad_ready, "previous_round": previous_round, "fired_count": recent_sources.size(), "sequence_count": Content.prior_kind_count(recent_sources, id), "recent_sources": recent_sources.duplicate(), "breech": breech and Content.is_attack(id)})
		if breech and Content.is_attack(id): breech = false
		result.overdrive = overdrive_pending
		results.append(result)
		peak_heat = maxi(peak_heat, int(s.get("heat", 0)))
		previous_round = id
		recent_sources.append(source)
		s.shots += 1
		_discard_fired_round(id)
		if overdrive_pending:
			overdrive_used = true
			break
		if int(s.get("heat", 0)) >= Content.heat_limit(s):
			if Content.reactor_enabled(s) and not s.magazine.is_empty() and target_index() >= 0 and FireHeatTrial.may_overdrive(s,fired_in_action):
				overdrive_pending = true
				result.overdrive_next = true
			else:
				break
		elif s.gun == "amplifier" and (int(result.get("hp", 1)) > 0 or result.has("wreckage_hit")):
			break
	var detail := finish_fire(1 if overdrive_used else 0)
	detail.overdrive = overdrive_used
	detail.results = results
	detail.heat_peak = peak_heat
	detail.overheated = results.any(func(result): return bool(result.get("overheated", false)))
	var lines: PackedStringArray = []
	for result in results: lines.append(("강행 · " if result.get("overdrive", false) else "") + str(result.text))
	if not detail.forced_reload.is_empty(): lines.append("과열 · 사격 중단 · 강제 재장전 %d턴" % int(detail.forced_reload.cost))
	if detail.has("forced_cooling") and not detail.forced_cooling.is_empty(): lines.append("과열 · 냉각 %d행동 · 남은 탄 보존" % int(detail.forced_cooling.cost))
	s.message = "\n".join(lines)
	if s.get("loss_reason","") == "ammo": s.message += "\n탄약 소진 · 이번 전투에 쓸 탄이 없습니다."
	_record("fire", detail)
	return true

# Shared by actual fire and exact scatter branches. Resolves the ONE firing turn,
# then an obligatory reload only if combat survives the overheat shot.
func finish_fire(overdrive_cost: int = 0) -> Dictionary:
	var overheated := int(s.get("heat", 0)) >= Content.heat_limit(s)
	s.turns += 1
	var advance_events: Array = []
	if target_index() < 0 and reserve_count() == 0:
		s.phase = "won" if int(s.floor) == Content.ENCOUNTERS.size() - 1 else "reward"
		s.reward_taken = false
	else:
		advance_events = _advance(1)
	var deployments: Array = []
	if s.phase != "lost" and reserve_count() > 0:
		deployments = _deploy_reinforcements(alive_count() == 0)
	if s.phase != "lost" and target_index() < 0 and reserve_count() == 0:
		s.phase = "won" if int(s.floor) == Content.ENCOUNTERS.size() - 1 else "reward"
		s.reward_taken = false
	if s.phase in ["reward", "won", "lost"]:
		WeaponRoles.clear(s)
		Gates.begin(s)
		s.heat = 0
		Content.Sustained.reset(s)
		s.prepared = []
		s.legacy_reload_penalty = 0
		_release_unfired_field_round()
	Engines.settle(s, Content.active_parts(s))
	var firing_enemies: Array = [] if forecast_only else s.enemies.duplicate(true)
	var firing_projectiles: Array = [] if forecast_only else s.get("projectiles", []).duplicate(true)
	var firing_reinforcements: Array = [] if forecast_only else s.get("reinforcements", []).duplicate(true)
	var forced: Dictionary = {}
	var cooling: Dictionary = {}
	if overheated and s.phase == "ready":
		if MagazineTrial.enabled(s):
			cooling = _trial_cool(true, overdrive_cost if MagazineTrial.weapons_enabled(s) else 0)
		else:
			reload_magazine(overdrive_cost)
			forced = last_reload_detail.duplicate(true)
	_settle_ammo_exhaustion()
	var detail := {"advance_events": advance_events, "deployments": deployments, "phase": s.phase, "forced_reload": forced, "firing_enemies": firing_enemies, "firing_projectiles": firing_projectiles, "firing_reinforcements": firing_reinforcements}
	if MagazineTrial.enabled(s): detail.forced_cooling = cooling
	return detail

func trial_load_magazine() -> bool:
	if not MagazineTrial.enabled(s) or s.phase != "plan" or not s.plan.is_empty() or not s.magazine.is_empty(): return false
	# 예약탄 (ammo_revision.gd): held rounds go in first.
	var held: Array = s.get("held_front", []) if AmmoRevision.enabled(s) else []
	var picked := MagazineTrial.take(held + s.hand + s.draw, capacity(), Content.slot_cost, Content.anchor)
	if picked.selected.is_empty(): return false
	if AmmoRevision.enabled(s): s.held_front = []
	s.magazine = picked.selected
	MagazineBuild.on_load(s)
	if MagazineTrial.weapons_enabled(s): s.magazine_ejected = 0
	s.draw = picked.remaining
	s.hand = []
	s.prepared = []
	s.previous_kill = false
	s.phase = "ready"
	WeaponRoles.on_load(s, Content.is_attack)
	_record("load", {"load_order": s.magazine.duplicate(), "hand_left": [], "whole_magazine": true})
	s.message = "탄창 %d발 · 다음 두 발부터 사격" % s.magazine.size()
	return true

func ejection_remaining() -> int:
	return maxi(0, Content.eject_limit(s) - int(s.get("magazine_ejected", 0))) if MagazineTrial.weapons_enabled(s) else 0

# Validate the entire selection before mutation. Duplicate ammo IDs remain
# independent physical cards; remove by position without reordering survivors.
func eject_magazine_rounds(indices: Array) -> bool:
	if not MagazineTrial.weapons_enabled(s) or s.phase != "ready" or indices.is_empty() or indices.size() > ejection_remaining(): return false
	var positions: Array[int] = []
	for index in indices:
		if not _whole(index, 0, s.magazine.size()-1) or positions.has(int(index)): return false
		if int(index) == WeaponRoles.mark(s): return false
		positions.append(int(index))
	positions.sort()
	var removed: Array = []
	for index in positions: removed.append(s.magazine[index])
	# 리벳 rework (2026-11-10, v2): a pulled round goes to the back of this magazine instead of
	# being spent, so the order can be set without losing the round. Counts toward the limit.
	if GrowthV2.enabled(s) and str(s.gun) == "single":
		for i in range(positions.size()-1,-1,-1): s.magazine.remove_at(positions[i])
		s.magazine.append_array(removed)
		s.magazine_ejected = int(s.get("magazine_ejected",0)) + removed.size()
		s.message = "%d발 탄창 뒤로 · 남은 빼내기 %d" % [removed.size(), ejection_remaining()]
		_record("eject", {"positions":positions,"rounds":removed,"retained":s.magazine.duplicate(),"cost":0,"elapsed":0,"ejected":int(s.magazine_ejected),"remaining":ejection_remaining(),"moved":true})
		return true
	WeaponRoles.on_eject(s, positions)
	for i in range(positions.size()-1,-1,-1): s.magazine.remove_at(positions[i])
	for id in removed: _discard_fired_round(str(id))
	MagazineBuild.on_eject(s, removed)
	s.magazine_ejected = int(s.get("magazine_ejected",0)) + removed.size()
	# No shot/heat/time/RNG or reload effects. Terminal exhaustion alone keeps
	# the existing cleanup, emergency-resupply and burning-enemy rules.
	_settle_ammo_exhaustion()
	s.message = "%d발 빼내기 · 이번 전투 소모 · 남은 탄 %d발" % [removed.size(),s.magazine.size()]
	if s.phase == "lost": s.message += " · 탄약 소진"
	_record("eject", {"positions":positions,"rounds":removed,"retained":s.magazine.duplicate(),"cost":0,"elapsed":0,"ejected":int(s.magazine_ejected),"remaining":ejection_remaining(),"phase":s.phase})
	return true

func cool_magazine() -> bool:
	if not MagazineTrial.enabled(s) or s.phase != "ready" or int(s.get("heat", 0)) <= 0: return false
	_trial_cool(false)
	return true

## Enemy actions of a forced cooling (before 강행). With the overheat cost (part_tuning.gd) the
## swap-cost penalties of parts (후미 점화기·열폭주 노심 +1) do not apply to overheating a second
## time; 회수 가속기 (−1) still shortens it (magazine swaps have a 2-turn floor, so this is
## where the part acts).
func forced_cooling_cost() -> int:
	var reload := maxi(1, int(Content.weapon_spec(s).reload) + mini(0, Content.reload_modifier(s))) if PartTuning.enabled(s) else base_reload_cost()
	return reload + 1 + Overheat.extra(s)

func _trial_cool(forced: bool, overdrive_cost: int = 0) -> Dictionary:
	var cost := forced_cooling_cost() + overdrive_cost if forced else 1
	var before := int(s.heat)
	var start_turns := int(s.turns)
	var events := _advance(cost, true)
	var deployments: Array = []
	if s.phase not in ["lost", "reward", "won"] and reserve_count() > 0 and alive_count() == 0:
		deployments = _deploy_reinforcements(true)
	s.heat = 0 if forced or int(s.get("fire_control_version",0))==FireHeatTrial.CAMPAIGN_VERSION else maxi(0, before - MagazineTrial.cooling_amount(Content.reload_cooling(s)))
	Content.Sustained.reset(s)
	if s.phase in ["lost", "reward", "won"]:
		WeaponRoles.clear(s)
		s.heat = 0
		s.prepared = []
		s.legacy_reload_penalty = 0
		Gates.begin(s)
		_release_unfired_field_round()
	Engines.settle(s, Content.active_parts(s))
	_settle_ammo_exhaustion()
	var reversed := WeaponRoles.after_cool(s, forced, Content.anchor)
	var detail := {"cost": cost, "elapsed": int(s.turns) - start_turns, "heat_before": before, "heat_after": int(s.heat), "forced": forced, "retained": s.magazine.duplicate(), "advance_events": events, "deployments": deployments, "phase": s.phase}
	if WeaponRoles.enabled(s): detail.reversed = reversed
	s.message = "냉각 · 적 %d행동 · 열 %d→%d · 남은 %d발 보존" % [detail.elapsed, before, s.heat, s.magazine.size()]
	if not forced: _record("cool", detail)
	return detail

func _recent_part_sources() -> Array:
	return _recent_part_rounds().map(func(id): return Content.source_id(str(id)))

func _recent_part_rounds() -> Array:
	var result: Array = []
	for history_index in range(s.history.size() - 1, -1, -1):
		var event: Dictionary = s.history[history_index]
		if str(event.get("action", "")) == "load": break
		if str(event.get("action", "")) != "fire": continue
		var fired: Array = []
		for shot in event.get("detail", {}).get("results", []): fired.append(str(shot.get("id", "")))
		for fired_index in range(fired.size() - 1, -1, -1): result.push_front(fired[fired_index])
	return result

func can_emergency_resupply() -> bool:
	return Reserve.emergency_available(s, Content.is_attack) and has_remaining_enemies()

func emergency_cost() -> int:
	return reload_cost() + 1 + int(s.get("emergency_uses", 0))

func emergency_resupply() -> bool:
	if not can_emergency_resupply(): return false
	return _reload_magazine(0, true)

func reload_magazine(overdrive_cost: int = 0) -> bool:
	return _reload_magazine(overdrive_cost, false)

func _reload_magazine(overdrive_cost: int, emergency: bool) -> bool:
	if WeaponRoles.locked(s): return false
	if s.phase != "ready" and not (s.phase == "plan" and Content.uses_ammo_cards(s)):
		return false
	if s.phase == "plan":
		# A full reload is the only way to abandon inserted finite-reserve rounds.
		if Reserve.enabled(s):
			while not s.plan.is_empty(): _spend_planned(0)
		elif not s.field_compression.is_empty():
			s.hand.append(s.field_compression.source)
			s.hand.append(s.field_compression.source)
			s.field_compression = {}
		s.plan.clear()
		s.plan_load_order.clear()
	for id in s.magazine.duplicate():
		if MagazineTrial.enabled(s) and GrowthV2.enabled(s) and not GrowthV2.is_basic(str(id)): s.draw.insert(GrowthV2.return_index(s), id)
		elif MagazineTrial.enabled(s): s.draw.append(id)
		else: _discard_fired_round(str(id))
	s.magazine.clear()
	WeaponRoles.clear(s)
	s.previous_kill = false
	s.buff = AttackBoosts.after_reload(s.buff)
	s.reloads += 1
	if not FireHeatTrial.separate_reload(s): Content.Sustained.reset(s)
	var cost := reload_cost() + (clampi(overdrive_cost, 0, 1) if Content.reactor_enabled(s) and int(s.get("heat", 0)) >= Content.heat_limit(s) else 0)
	var heat_paid := 0 if MagazineTrial.enabled(s) else cost - base_reload_cost()
	var emergency_paid := 1 + int(s.get("emergency_uses", 0)) if emergency else 0
	cost += emergency_paid
	var granted := 0
	var heat_before := int(s.get("heat", 0))
	var heat_after := Content.heat_after_reload(s)
	var advance_events := _advance(cost, true)
	s.heat = heat_after if s.phase not in ["reward", "won", "lost"] else 0
	Gates.after_reload(s, heat_before, heat_after, heat_before >= Content.heat_limit(s))
	s.legacy_reload_penalty = 0
	var deployments: Array = []
	if s.phase != "lost" and reserve_count() > 0 and alive_count() == 0:
		deployments = _deploy_reinforcements(true)
	# Count each actual elapsed turn, including a lethal partial reload.
	if s.phase in ["reward", "won"]:
		s.message = "화상이 전진 전에 마지막 적을 처치했습니다."
	elif s.phase != "lost":
		s.phase = "plan"
		s.supply = supply_capacity()
		s.push_left = Content.push_budget(s)
		s.exchange_left = Content.exchange_capacity(s)
		# Unused rounds cycle into discard; ownership is conserved, including in previews.
		if not Reserve.enabled(s):
			s.discard.append_array(s.hand)
			s.hand.clear()
		if emergency:
			# Uninserted supports return to reserve; the new rounds always fit in
			# the hand. Owned deck and spent specials are never replenished.
			s.draw.append_array(s.hand)
			s.hand.clear()
			for unused in range(Reserve.EMERGENCY_COUNT): s.draw.push_front(Reserve.EMERGENCY_ROUND)
			s.emergency_uses = int(s.get("emergency_uses", 0)) + 1
			granted = Reserve.EMERGENCY_COUNT
			s.prepared = []
			_refill()
		elif not forecast_only:
			_draw_prepared()
			_refill()
		else: s.prepared = []
		s.message = "재장전 · %d턴 · 열 %d→%d · 손패 %d장" % [cost, heat_before, s.heat, s.hand.size()]
		if emergency: s.message = "비상 보급 %d회 · 기본탄 %d발 · 적 %d턴 · 다음 보급 추가 %d턴" % [s.emergency_uses, granted, cost, 1 + s.emergency_uses]
	else:
		s.message = "재장전 도중 적이 0m에 도달했습니다."
	if s.phase in ["reward", "won", "lost"]:
		s.prepared = []
		Content.Sustained.reset(s)
	_settle_ammo_exhaustion()
	Engines.settle(s, Content.active_parts(s))
	last_reload_detail = {"cost": cost, "heat_paid": heat_paid, "heat_before": heat_before, "heat_after": int(s.heat), "advance_events": advance_events, "deployments": deployments, "phase": s.phase}
	if emergency: last_reload_detail.merge({"emergency":true,"emergency_paid":emergency_paid,"granted":granted,"emergency_uses":int(s.get("emergency_uses",0))})
	if not forecast_only: _record("reload", last_reload_detail)
	if MagazineTrial.enabled(s) and s.phase == "plan":
		trial_load_magazine()
		last_reload_detail.phase = s.phase
	return true

func _settle_ammo_exhaustion() -> void:
	if not Reserve.exhausted(s): return
	WeaponRoles.clear(s)
	s.phase = "lost"
	s.loss_reason = "ammo"
	Gates.begin(s)
	s.heat = 0
	Content.Sustained.reset(s)
	s.prepared = []
	s.legacy_reload_penalty = 0
	s.message = "탄약 소진 · 남은 적을 상대할 탄이 없습니다."

func _advance(turn_count: int, count_turns: bool = false) -> Array:
	var events: Array = []
	for i in range(turn_count):
		if count_turns:
			s.turns += 1
		# Every burning enemy resolves before any survivor moves this turn.
		for enemy_index in range(s.enemies.size()):
			var e: Dictionary = s.enemies[enemy_index]
			if int(e.hp) <= 0:
				continue
			var burning:=int(e.get("burn",0))>0
			var ground_damage:=Roles.zone_damage(s,int(e.distance)) if Roles.enabled(s) else 0
			if burning or ground_damage>0:
				var hp_before:=int(e.hp)
				e.hp=maxi(0,hp_before-maxi(Content.burn_damage(s) if burning else 0,ground_damage))
				e.burn=maxi(0,int(e.get("burn",0))-1)
				if not forecast_only:
					events.append({"turn":i,"target":enemy_index,"kind":"burn","damage":hp_before-int(e.hp),"hp":e.hp,"burn":e.burn})
					if Roles.enabled(s):events[-1].ground=ground_damage>0
		var wrecks := Wreckage.spawn(s.enemies)
		if not wrecks.is_empty() and not forecast_only:
			events.append({"kind": "wreckage_spawn", "turn": i, "stacks": wrecks})
		if Roles.enabled(s) and not s.fire_zones.is_empty():
			Roles.tick(s)
			if not forecast_only:events.append({"turn":i,"kind":"fire_zone_tick","zones":s.fire_zones.duplicate(true)})
		if target_index() < 0 and reserve_count() == 0:
			s.phase = "won" if int(s.floor) == Content.ENCOUNTERS.size() - 1 else "reward"
			s.reward_taken = false
			break
		elif target_index() < 0:
			continue
		# Charging units publish their clock. On completion they pull every other
		# survivor before ordinary movement, so the full distance cost is knowable.
		events.append_array(BossSkills.advance(s,i,not forecast_only))
		events.append_array(Central.advance(s,i,not forecast_only))
		if s.phase=="lost": break
		for source_index in range(s.enemies.size()):
			var source: Dictionary = s.enemies[source_index]
			if int(source.hp) <= 0 or int(source.get("charge_max", 0)) <= 0 or int(source.get("jammed", 0)) > 0:
				continue
			source.charge = int(source.get("charge", 0)) + 1
			var released := int(source.charge) >= int(source.charge_max)
			if not forecast_only: events.append({"turn": i, "target": source_index, "kind": "charge", "charge": 0 if released else source.charge, "charge_max": source.charge_max, "released": released})
			if released:
				source.charge = 0
				var pull := int(source.get("charge_pull", 2))
				for enemy_index in range(s.enemies.size()):
					if enemy_index == source_index or int(s.enemies[enemy_index].hp) <= 0: continue
					var ally: Dictionary = s.enemies[enemy_index]
					var before_pull := int(ally.distance)
					ally.distance = maxi(0, before_pull - pull)
					if not forecast_only: events.append({"turn": i, "target": enemy_index, "source": source_index, "kind": "pull", "from": before_pull, "to": ally.distance, "amount": pull})
					if int(ally.distance) == 0: s.phase = "lost"
		if s.phase == "lost":
			break
		for enemy_index in range(s.enemies.size()):
			var e: Dictionary = s.enemies[enemy_index]
			if int(e.hp) <= 0: continue
			var distance_before := int(e.distance)
			var step := int(e.speed)
			if preload("res://redesign/foundry_workers.gd").winding(e):
				var motion := preload("res://redesign/foundry_workers.gd").movement(e)
				step = int(motion.step)
				if not forecast_only:
					var event := motion.duplicate(true)
					event.merge({"turn":i,"target":enemy_index,"kind":"foundry_state"})
					events.append(event)
			elif preload("res://redesign/garden_hunters.gd").active(e):
				var motion := preload("res://redesign/garden_hunters.gd").movement(e)
				step = int(motion.step)
				if not forecast_only:
					var event := motion.duplicate(true)
					event.merge({"turn":i,"target":enemy_index,"kind":"garden_state"})
					events.append(event)
			elif Noble.shielded(e):
				var motion := Noble.movement(e)
				step = int(motion.step)
				if not forecast_only:
					var event := motion.duplicate(true)
					event.merge({"turn":i,"target":enemy_index,"kind":"noble_state"})
					events.append(event)
			if Roles.enabled(s):step=Roles.movement(e,step)
			e.distance = maxi(0, distance_before - step)
			if not forecast_only:
				events.append({"turn": i, "target": enemy_index, "kind": "move", "from": distance_before, "to": e.distance})
				if Roles.enabled(s):events[-1].slow_left=int(e.get("slow_left",0))
			if int(e.distance) == 0:
				s.phase = "lost"
		# Stance changes after movement and is therefore the public defense for the
		# player's next decision. Multi-turn reloads alternate once per elapsed turn.
		for enemy_index in range(s.enemies.size()):
			var e: Dictionary = s.enemies[enemy_index]
			if int(e.hp) <= 0 or not bool(e.get("stance", false)): continue
			e.stance_closed = not bool(e.get("stance_closed", true))
			e.def = int(e.get("stance_def", 4)) if bool(e.stance_closed) else 0
			if not forecast_only: events.append({"turn": i, "target": enemy_index, "kind": "stance", "def": e.def, "closed": e.stance_closed})
		if s.phase == "lost":
			break
		events.append_array(Ranged.advance(s, i, not forecast_only))
		for enemy in s.enemies:
			if int(enemy.get("jammed", 0)) > 0: enemy.jammed = int(enemy.jammed) - 1
		if s.phase == "lost": break
	return events

func target_index() -> int:
	var selected := -1
	var distance := 2147483647
	for i in range(s.enemies.size()):
		var e: Dictionary = s.enemies[i]
		if int(e.hp) > 0 and int(e.distance) < distance:
			selected = i
			distance = int(e.distance)
	for projectile in Ranged.active(s):
		if int(projectile.distance) <= distance:
			selected = Ranged.target_id(projectile)
			distance = int(projectile.distance)
	return selected

func target_entity(index: int) -> Dictionary:
	return Ranged.entity(s, index)

func active_targets() -> Array:
	var result: Array = []
	for i in range(s.enemies.size()):
		if int(s.enemies[i].hp) > 0: result.append(i)
	for projectile in Ranged.active(s): result.append(Ranged.target_id(projectile))
	return result

func _rear_transfer_targets(impact_distance: int) -> Array[int]:
	var targets: Array[int] = []
	for i in range(s.enemies.size()):
		var enemy: Dictionary = s.enemies[i]
		if int(enemy.hp) > 0 and int(enemy.distance) > impact_distance: targets.append(i)
	targets.sort_custom(func(a: int, b: int):
		var left := int(s.enemies[a].distance)
		var right := int(s.enemies[b].distance)
		return a < b if left == right else left < right
	)
	return targets

func shot_targets(id: String) -> Array:
	var nearest := target_index()
	if nearest < 0: return []
	if Ranged.is_projectile(nearest): return [nearest]
	var targets := active_targets().filter(func(index): return not Ranged.is_projectile(int(index)))
	targets.sort_custom(func(a, b): return int(s.enemies[a].distance) < int(s.enemies[b].distance) if int(s.enemies[a].distance) != int(s.enemies[b].distance) else int(a) < int(b))
	if str(Content.AMMO.get(id, {}).get("effect", "")) == "bypass" and targets.size() > 1:
		targets.pop_front()
	return targets if s.gun == "scatter" else [targets[0]]

func scatter_targets(id: String = "basic") -> Array:
	var nearest := target_index()
	if Ranged.is_projectile(nearest): return [nearest]
	var targets := active_targets().filter(func(index): return not Ranged.is_projectile(int(index)))
	if str(Content.AMMO.get(id, {}).get("effect", "")) == "bypass" and targets.size() > 1: targets.erase(nearest)
	return targets

func alive_count() -> int:
	var count := 0
	for enemy in s.get("enemies", []):
		if int(enemy.get("hp", 0)) > 0: count += 1
	return count

func reserve_count() -> int:
	return s.get("reinforcements", []).size()

func has_remaining_enemies() -> bool:
	return alive_count() > 0 or reserve_count() > 0 or not Ranged.active(s).is_empty()

func _deploy_reinforcements(force: bool = false) -> Array:
	var deployments: Array = []
	if reserve_count() == 0 or (not force and alive_count() > 2 and not BossSkills.called_waiting(s)):
		return deployments
	var room := maxi(0, 4 - alive_count())
	while room > 0 and not s.reinforcements.is_empty():
		var selected := -1
		for i in range(s.reinforcements.size()):
			if not BossSkills.can_deploy(s, s.reinforcements[i]): continue
			if selected < 0: selected = i
			if s.reinforcements[i].get("brood_reserve", false): selected = i; break
		if selected < 0: break
		var enemy: Dictionary = s.reinforcements.pop_at(selected)
		var used_lanes: Array = []
		for active_index in range(s.enemies.size()):
			var active: Dictionary = s.enemies[active_index]
			if int(active.get("hp", 0)) > 0: used_lanes.append(int(active.get("lane", active_index % 4)))
		var open_lane := 0
		while used_lanes.has(open_lane) and open_lane < 4: open_lane += 1
		enemy.lane = clampi(open_lane, 0, 3)
		s.enemies.append(enemy)
		deployments.append({"target": s.enemies.size() - 1, "enemy": enemy.duplicate(true)})
		room -= 1
	if not deployments.is_empty():
		s.deployed = int(s.get("deployed", 0)) + deployments.size()
		s.wave = int(s.get("wave", 1)) + 1
	return deployments

func _random_target(id: String = "basic") -> int:
	var alive := scatter_targets(id)
	if alive.is_empty(): return -1
	if Ranged.is_projectile(int(alive[0])): return int(alive[0])
	var rng := RandomNumberGenerator.new()
	rng.state = int(s.target_rng_state)
	var index: int = alive[rng.randi_range(0, alive.size() - 1)]
	s.target_rng_state = str(rng.state)
	return index

func _target_state(state: Dictionary) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(state.get("seed", 0)) ^ (int(state.get("floor", 0)) * 7919 + 15485863)
	return str(rng.state)

# These values depend only on the bullet and the current weapon/parts, not on
# a random target. Forecast branches share a read-only profile for this step.
static func shot_profile(id: String, state: Dictionary) -> Dictionary:
	return {"parts": Content.active_parts(state), "damage": Content.damage(id, state), "pen": Content.penetration(id, state), "effect": Content.effect_value(id, state), "hits": Content.hit_count(id, state), "burn": Content.burn_amount(id, state), "burn_tick": Content.burn_damage(state), "heat_limit": Content.heat_limit(state), "hot_threshold": Content.hot_threshold(state)}

func _shot(id: String, forced_target: int = -1, part_context: Dictionary = {}) -> Dictionary:
	var index := forced_target
	if index < 0:
		if s.gun == "scatter": index = _random_target(id)
		else:
			var candidates := shot_targets(id)
			index = int(candidates[0]) if not candidates.is_empty() else -1
	var e := target_entity(index)
	if e.is_empty(): return {}
	if int(e.hp) <= 0: return {}
	var spec: Dictionary = Content.AMMO[id]
	var minimal := bool(part_context.get("forecast_minimal", false))
	var profile: Dictionary = part_context.get("profile", {})
	if profile.is_empty(): profile = shot_profile(id, s)
	var active_parts: Array = profile.parts
	var previous_round := str(part_context.get("previous_round", ""))
	var relay_ready := MagazineBuild.compression_ready(s, id) if MagazineBuild.enabled(s) else Content.compression_link(previous_round, id)
	var relay_saved := mini(MagazineBuild.COMPRESSION_SAVE, Content.heat_cost(id)) if active_parts.has("compression_sink") and relay_ready else 0
	var heat_added := maxi(0, Roles.base_heat(s,Content.heat_cost(id)) - relay_saved)
	var heat_before := int(s.get("heat", 0))
	var attack := Content.is_attack(id)
	var applied := AttackBoosts.resolve(s.buff, heat_before, int(profile.hot_threshold)) if attack else {"dmg":0,"factor":1,"heat":0,"hot_failed":false}
	heat_added += int(applied.heat)
	heat_added += Content.part_heat_bonus(id,s)
	var sustained_before := Content.Sustained.count(s)
	var sustained_heat := Content.Sustained.fire(s, attack, str(spec.effect) in ["cool", "vent"])
	heat_added += sustained_heat
	var cooled := mini(heat_before, int(profile.effect)) if spec.effect == "cool" else 0
	var vented := mini(heat_before, int(spec.get("heat_spend", 0))) if spec.effect == "vent" else 0
	var thermal_bonus := 0 # Historical result field; the retired heat-threshold round is now incendiary.
	var vent_bonus := vented * int(profile.effect)
	s.heat = heat_before + heat_added - cooled - vented
	var wreck := Wreckage.blocker(s.enemies, index) if attack else -1
	if wreck >= 0:
		var receipt := Wreckage.strike(s.enemies, wreck, Wreckage.STACKS if Content.source_id(id) == "pierce" else int(profile.hits))
		s.buff = AttackBoosts.consume(s.buff)
		if s.has("gate_charge"): s.gate_charge = 0
		s.previous_kill = false
		var chain_cooled := _cool_third_round(active_parts, part_context)
		receipt.merge({"id": id, "hit": true, "hits": 0, "push": 0, "heat_before": heat_before, "heat_after": int(s.heat), "heat_added": heat_added,
			"overheated": int(s.heat) >= int(profile.heat_limit), "cooled": vented + chain_cooled, "chain_cooled": chain_cooled,
			"vented": vented, "sustained_active": Content.Sustained.enabled(s), "sustained_heat": sustained_heat,
			"sustained_before": sustained_before, "sustained_after": Content.Sustained.count(s),
			"text": "잔해 −%d칸" % int(receipt.wreckage_hit)})
		return receipt
	var chase_bonus := int(profile.effect) if spec.effect == "chase" and bool(s.get("previous_kill", false)) else 0
	# 연계탄 (ammo_revision.gd) raises the 교차 step instead of its own +2 per kind.
	var sequence_bonus := int(profile.effect) * int(part_context.get("sequence_count", 0)) if spec.effect == "sequence" and not AmmoRevision.enabled(s) else 0
	var prepared_rounds: Array = []
	var held_round := false
	if spec.effect == "prepare" and AmmoRevision.enabled(s) and MagazineTrial.enabled(s):
		# 예약탄 (ammo_revision.gd): the round behind it waits for the front of the next magazine.
		if not s.has("held_front"): s.held_front = []
		for slot in range(s.magazine.size()):
			var next_id := str(s.magazine[slot])
			if Content.is_temporary(next_id) or s.held_front.size() >= AmmoRevision.HELD_LIMIT: continue
			s.magazine.remove_at(slot)
			s.held_front.append(next_id)
			prepared_rounds.append(next_id)
			held_round = true
			break
	elif spec.effect == "prepare":
		if not s.has("prepared"): s.prepared = []
		var candidates: Array = []
		for value in s.magazine:
			var next_id := str(value)
			if (next_id == "basic" and not Content.uses_ammo_cards(s)) or Content.is_temporary(next_id): continue
			candidates.append(next_id)
			if s.prepared.count(next_id) >= candidates.count(next_id): continue
			if s.prepared.size() >= 3 or prepared_rounds.size() >= int(profile.effect): break
			s.prepared.append(next_id)
			prepared_rounds.append(next_id)
	var alive_before := alive_count()
	var dmg_buff := int(applied.dmg)
	var factor := int(applied.factor)
	var pen := int(profile.pen)
	var weakness_bonus := Content.weakness_bonus(id, e)
	var part_bonus := 0
	var part_factor: Variant = 1
	var part_combo: PackedStringArray = []
	var part_effects: Array = []
	var ordinary_bonus := 2 * int(part_context.get("sequence_count",0)) if active_parts.has("ordinary_chain") and bool(part_context.get("last_attack",false)) and Content.is_attack(id) else 0
	if ordinary_bonus > 0:
		part_bonus += ordinary_bonus
		if not minimal: part_combo.append("다종 급탄 +%d" % ordinary_bonus)
		if not minimal: part_effects.append({"id": "ordinary_chain", "label": "다종 급탄 +%d" % ordinary_bonus})
	var burn_before := int(e.get("burn", 0))
	var control_bonus:=Roles.control_bonus(s,active_parts,e) if attack else 0
	if control_bonus>0:
		part_bonus+=control_bonus
		if not minimal:part_combo.append("경직 추격 +2");part_effects.append({"id":"rammer","label":"경직 피해 +2"})
	if active_parts.has("ember_core") and heat_before >= int(profile.hot_threshold):
		var bonus := int(Content.PARTS.ember_core.hot_damage) + PartTuning.ember_extra(s)
		part_bonus += bonus
		if not minimal: part_combo.append("잔열 +%d" % bonus)
		if not minimal: part_effects.append({"id": "ember_core", "label": "고열 피해 +%d" % bonus})
	if active_parts.has("igniter") and int(e.get("burn", 0)) > 0:
		part_bonus += 2
		if not minimal: part_combo.append("점화 +2")
		if not minimal: part_effects.append({"id": "igniter", "label": "피해 +2"})
	if active_parts.has("executioner") and PartTuning.executes(s, int(e.hp), int(e.get("max_hp", e.hp))):
		var execute := PartTuning.execute_bonus(s)
		part_bonus += execute
		if not minimal: part_combo.append("처형 +%d" % execute)
		if not minimal: part_effects.append({"id": "executioner", "label": "피해 +%d" % execute})
	# 가속 총열 (part_tuning.gd): its damage is in Content.damage; show it acting.
	if attack and not minimal and active_parts.has("lens") and PartTuning.lens_damage(s) > 0 and int(Content.AMMO[id].pen) > 0:
		part_effects.append({"id": "lens", "label": "관통탄 +%d" % PartTuning.lens_damage(s)})
	if active_parts.has("opening") and bool(part_context.get("first", false)):
		if FocusBuild.enabled(s): part_factor *= 2
		else: part_bonus += 2
		var label := "첫 발 ×2" if FocusBuild.enabled(s) else "선두 +2"
		if not minimal: part_combo.append(label)
		if not minimal: part_effects.append({"id": "opening", "label": label})
	if FocusBuild.enabled(s) and active_parts.has("third_striker") and int(part_context.get("fired_count", -1)) == 2:
		const StrikerTrial = preload("res://redesign/samples/opening_build/third_striker_trial.gd")
		part_factor *= StrikerTrial.multiplier(s)
		if not minimal:
			var label := "3번째 " + StrikerTrial.multiplier_label(s)
			part_combo.append(label)
			part_effects.append({"id":"third_striker", "label":label})
	if Content.revised_combat(s) and active_parts.has("afterburner") and attack and int(profile.hits) == 1 and bool(part_context.get("last_attack",false)) and (dmg_buff > 0 or factor > 1 or (not FocusBuild.enabled(s) and MagazineBuild.enabled(s) and MagazineBuild.afterburner_ready(s))):
		var ending_factor := 3 if FocusBuild.enabled(s) else 2
		part_factor *= ending_factor
		if not minimal: part_combo.append("후미 결산 ×%d" % ending_factor)
		if not minimal: part_effects.append({"id":"afterburner","label":"강화 단타 ×%d" % ending_factor})
	elif not Content.revised_combat(s) and active_parts.has("afterburner") and bool(part_context.get("last", false)):
		part_bonus += 3
		if not minimal: part_combo.append("후미 +3")
		if not minimal: part_effects.append({"id": "afterburner", "label": "피해 +3"})
	var tally_bonus := BuildEngine.tally_bonus(s) if BuildEngine.enabled(s) and active_parts.has("tally") and BuildEngine.is_volley_round(id) else 0
	if tally_bonus > 0:
		part_bonus += tally_bonus
		if not minimal: part_combo.append("기록 +%d" % tally_bonus)
		if not minimal: part_effects.append({"id": "tally", "label": "기록 +%d" % tally_bonus})
	var resonant := attack and BuildEngine.resonance(s, id, active_parts)
	# Tag parts (tag_build.gd): + per hit now, × after the drive line below.
	var tag_effect: Dictionary = TagBuild.shot(s, id, active_parts, e, heat_before, int(profile.hot_threshold)) if attack else {"add": 0, "percent": 100, "labels": []}
	part_bonus += int(tag_effect.add)
	if not minimal:
		for item in tag_effect.labels:
			part_combo.append(str(Content.PARTS[item.id].name) + " " + str(item.label))
			part_effects.append({"id": item.id, "label": str(item.label), "source": str(item.get("source", item.id))})
	if MagazineBuild.enabled(s):
		var triad_bonus := MagazineBuild.triad_bonus(s, id) if active_parts.has("triad") else 0
		if triad_bonus > 0:
			part_bonus += triad_bonus
			if not minimal: part_combo.append("삼중 +%d" % triad_bonus)
			if not minimal: part_effects.append({"id": "triad", "label": "피해 +%d" % triad_bonus})
	elif active_parts.has("triad") and bool(part_context.get("triad", false)):
		part_bonus += 5
		if not minimal: part_combo.append("삼중 +5")
		if not minimal: part_effects.append({"id": "triad", "label": "피해 +5"})
	if not attack:
		part_factor = 1
		weakness_bonus = 0
		part_bonus = 0
		ordinary_bonus = 0
		part_combo.clear()
		part_effects.clear()
	var engine_flat := Engines.flat(s,active_parts) if attack else 0
	var engine_percent := Engines.percent(s,active_parts,int(profile.hits),heat_before>=int(profile.hot_threshold)) if attack else 100
	part_bonus += engine_flat
	var engine_id := "volley_drive" if engine_flat>0 else ("thermal_drive" if active_parts.has("thermal_drive") and engine_percent>100 else ("siege_drive" if engine_percent>100 else ""))
	if not engine_id.is_empty() and not minimal: part_effects.append({"id":engine_id,"label":Engines.value(s,engine_id)})
	# The drive alone (11-11): hot checks and drive labels must not see the tag multiplier.
	var drive_percent := engine_percent
	if int(tag_effect.percent) != 100: engine_percent = engine_percent * int(tag_effect.percent) / 100
	var mastery_bonus := GrowthV2.mastery_bonus(s, id) if attack else 0
	if mastery_bonus > 0 and not minimal: part_combo.append("숙련 +%d" % mastery_bonus)
	# 교차 사격 (mix_combo.gd): a different attack family than the previous attack round.
	var cross_bonus := MixCombo.bonus(s, id, part_context.get("recent_sources", [])) if attack else 0
	var breech_bonus := PartTuning.BREECH_BONUS if attack and part_context.get("breech", false) else 0
	if breech_bonus > 0 and not minimal:
		part_combo.append("냉각 직후 +%d" % breech_bonus)
		part_effects.append({"id": "cooling_breech", "label": "냉각 직후 +%d" % breech_bonus})
	if cross_bonus > 0 and not minimal: part_combo.append("교차 +%d" % cross_bonus)
	var subtotal := int(profile.damage) + dmg_buff + weakness_bonus + part_bonus + chase_bonus + thermal_bonus + vent_bonus + sequence_bonus + mastery_bonus + cross_bonus + breech_bonus
	var gate_percent := Gates.chain_percent(s) if attack else 100
	var gate_charge := int(s.get("gate_charge",0)) if attack else 0
	if attack and s.has("gate_charge"): s.gate_charge = 0
	var overdrive_percent := Content.overdrive_percent(s) if attack and bool(part_context.get("overdrive",false)) else 100
	var weapon_factor := int(part_context.get("weapon_factor",1)) if WeaponRoles.kind(s)=="deadbolt" and attack else 1
	var raw := int(subtotal * factor * part_factor * weapon_factor * engine_percent * gate_percent * overdrive_percent / 1000000.0) if attack else 0
	var heat_percent:=FireHeatTrial.damage_percent(s,heat_before,int(profile.heat_limit))
	var first_raw:=raw+gate_charge
	if heat_percent<100:
		raw=FireHeatTrial.scaled_damage(raw,heat_percent)
		first_raw=FireHeatTrial.scaled_damage(first_raw,heat_percent)
	var armor := maxi(0, int(e.def) - pen)
	var per_hit := Content.armored_damage(raw,armor,s)
	# One-hit charge is added after multipliers, before armor; never once per hit.
	var first_hit := Content.armored_damage(first_raw,armor,s)
	var requested_hits := int(profile.hits) if attack else 0
	var hp_before := int(e.hp)
	var focus_before := int(e.get("focus_hits", 0))
	var focus_damage := 0
	var focus_triggers := 0
	var hits := 0
	var barrier_before := int(e.get("barrier", 0))
	var blocked_hits := 0
	var barrier_removed := 0
	var combo: Array = []
	if not minimal and (dmg_buff > 0): combo.append("증폭 +%d" % dmg_buff)
	if not minimal and factor > 1: combo.append("배율 ×%d" % factor)
	if not minimal and bool(applied.hot_failed): combo.append("잔열 부족 · 강화 소멸")
	if not minimal and int(applied.heat) > 0: combo.append("배율 대가 · 열 +%d" % int(applied.heat))
	if not minimal and (weakness_bonus > 0): combo.append("약점 +%d" % weakness_bonus)
	if not minimal and (chase_bonus > 0): combo.append("추격 +%d" % chase_bonus)
	if not minimal: combo.append_array(part_combo)
	if not minimal and weapon_factor>1: combo.append("봉인탄 ×3")
	for hit_index in range(requested_hits):
		if int(e.hp) <= 0: break
		hits += 1
		var blocked := false
		if int(e.get("barrier", 0)) > 0:
			var strip_count := (2 if active_parts.has("breaker") else 1) + (1 if (Noble.shielded(e) or Central.active(e)) and str(spec.attribute)=="electric" else 0)
			var removed := Noble.strip(e, strip_count, Content.source_id(id))
			barrier_removed += removed
			blocked_hits += 1
			blocked = true
		else:
			var hit_damage := first_hit if hit_index==0 else (Content.armored_damage(raw * (hit_index + 1), armor, s) if resonant else per_hit)
			e.hp = maxi(0, int(e.hp) - hit_damage)
		if s.gun == "burst" and not WeaponRoles.enabled(s):
			e.focus_hits = int(e.get("focus_hits", 0)) + 1
			if int(e.focus_hits) == 3:
				e.focus_hits = 0
				focus_triggers += 1
				var extra := 0 if blocked else mini(4, int(e.hp))
				e.hp -= extra
				focus_damage += extra
	var primary_direct_kill := attack and hp_before>0 and int(e.hp)==0 and not Ranged.is_projectile(index)
	if primary_direct_kill: BuildEngine.record_kill(s, id, active_parts)
	if primary_direct_kill: TagBuild.record_kill(s, id, active_parts)
	if resonant and hits > 1 and not minimal:
		combo.append("공명 ×1~×%d" % hits)
		part_effects.append({"id": "resonator", "label": "공명 ×1~×%d" % hits})
	var detonation := 0
	if spec.effect == "detonate" and not Ranged.is_projectile(index):
		detonation = mini(int(e.hp), burn_before * int(profile.burn_tick) * int(spec.get("detonate_scale", 1)))
		e.hp -= detonation
		e.burn = 0
		if not minimal and (detonation > 0): combo.append("화상 기폭 %d" % detonation)
	var armor_removed := 0
	var armor_before := int(e.def)
	if spec.effect == "shatter" and not Ranged.is_projectile(index):
		var stored_armor := int(e.get("stance_def", e.def)) if bool(e.get("stance", false)) else int(e.def)
		if Ranged.is_gatekeeper(e): stored_armor = int(e.guard_armor)
		elif int(e.get("foundry_version", 0)) == 3: stored_armor = int(e.shell_armor)
		armor_removed = mini(stored_armor, int(profile.effect))
		if Ranged.is_gatekeeper(e):
			e.guard_armor = stored_armor - armor_removed
			e.def = int(e.guard_armor) if str(e.ranged_phase) == "guard" else 0
		elif int(e.get("foundry_version", 0)) == 3:
			e.shell_armor = stored_armor - armor_removed
			e.def = 0 if bool(e.recovering) else int(e.shell_armor)
		elif bool(e.get("stance", false)):
			e.stance_def = stored_armor - armor_removed
			e.def = int(e.stance_def) if bool(e.stance_closed) else 0
		else: e.def -= armor_removed
		if not minimal and (armor_removed > 0): combo.append("장갑 −%d" % armor_removed)
	var damage := hp_before - int(e.hp)
	var shield_rule := Noble.shield_rule(e)
	if not minimal and (blocked_hits > 0):
		combo.append("철갑탄 전용" if barrier_removed == 0 and shield_rule == Noble.PIERCE_ONLY else "배리어 −%d" % barrier_removed)
	if not minimal and (focus_triggers > 0): combo.append("집중 추가 피해 %d" % focus_damage)
	if not minimal and (heat_added > 0): combo.append("열 +%d" % heat_added)
	if not minimal and (cooled > 0): combo.append("냉각 −%d" % cooled)
	if attack: s.buff = AttackBoosts.consume(s.buff)
	var boost_replaced := false
	if spec.effect == "boost":
		var boost_channel := "carry" if Content.is_compressed(id) else ("factor" if Content.boost_factor(id,s) > 1 else "flat")
		boost_replaced = AttackBoosts.layers(s.buff).any(func(v): return AttackBoosts.channel(v) == boost_channel)
		s.buff = AttackBoosts.prepare(s.buff, int(profile.effect), Content.boost_factor(id, s), Content.boost_rounds(id), Content.is_compressed(id), bool(spec.get("boost_hot",false)), int(spec.get("boost_heat",0)))
		if not minimal: combo.append("다음 공격 %d발 %s" % [Content.boost_rounds(id), Content.boost_label(id, s)])
	if Roles.enabled(s) and spec.effect=="burn" and not Ranged.is_projectile(index):Roles.ignite(s,int(e.distance),int(profile.burn_tick),active_parts)
	var burn_added := 0
	if spec.effect == "burn" and int(e.hp) > 0:
		burn_added = int(profile.burn)
		e.burn = mini(6, int(e.get("burn", 0)) + burn_added)
		if not minimal: combo.append("화상 %d · 턴당 %d" % [e.burn, int(profile.burn_tick)])
	var pushed := 0
	if int(e.hp) > 0 and spec.effect == "push":
		var local_budget := int(s.push_left) + int(spec.get("push_budget_bonus", 0)) * Content.multiplier(s)
		pushed = mini(int(profile.effect), local_budget)
		e.distance += pushed
		s.push_left = maxi(0, int(s.push_left) - pushed)
	var secondary: Array = []
	var relay_hits := 0
	var relay_damage := 0
	if attack and int(e.hp)<=0:
		var remainder := maxi(0,first_hit-hp_before) if requested_hits==1 and blocked_hits==0 and active_parts.has("siege_drive") else 0
		var remaining_hits := requested_hits-hits if active_parts.has("volley_drive") else 0
		# Target-dependent bonuses are recomputed; the prepared buff is paid only once.
		var base_subtotal := subtotal-weakness_bonus-control_bonus-(2 if active_parts.has("igniter") and burn_before>0 else 0)-(PartTuning.execute_bonus(s) if active_parts.has("executioner") and PartTuning.executes(s, hp_before, int(e.get("max_hp", hp_before))) else 0)
		var relay := _engine_relay(id,remaining_hits,remainder,base_subtotal,factor * weapon_factor * (part_factor if FocusBuild.enabled(s) else 1),engine_percent,pen,active_parts,gate_percent,overdrive_percent)
		secondary = relay.events
		relay_hits = int(relay.hits)
		relay_damage = int(relay.damage)
	var chain_earned := Gates.level(s,"chain")>0 and (primary_direct_kill or secondary.any(func(v): return int(v.hp)==0 and not bool(v.get("intercept",false)) and not v.has("wreckage_hit")))
	if chain_earned: s.gate_chain = mini(4,int(s.get("gate_chain",0))+1)
	Engines.observe(s,active_parts,(hits-blocked_hits if damage>0 else 0)+relay_hits,drive_percent>100 and active_parts.has("thermal_drive"),(damage-detonation+relay_damage) if requested_hits==1 else 0)
	# A hot direct hit that reaches the heat limit releases a single pressure wave.
	# Resolve before kill-cooling: a kill-cooling build may earn its way out of reload.
	var shock_damage := 0
	if active_parts.has("thermal_drive") and drive_percent>100 and damage-detonation>0 and int(s.heat)>=int(profile.heat_limit):
		var shock_raw := int(raw/2)
		# The seal boosts this cartridge's direct impacts, not an extra wave proc.
		if weapon_factor>1:
			var unsealed_raw := int(subtotal * factor * part_factor * engine_percent * gate_percent * overdrive_percent / 1000000.0)
			if heat_percent<100: unsealed_raw=FireHeatTrial.scaled_damage(unsealed_raw,heat_percent)
			shock_raw=int(unsealed_raw/2)
		for other_index in active_targets():
			if int(other_index)==index: continue
			var other := target_entity(int(other_index))
			var blocked := int(other.get("barrier",0))>0
			var dealt := 0 if blocked else mini(int(other.hp),Content.armored_damage(shock_raw,int(other.def),s,0))
			var removed := Noble.strip(other, 1) if blocked else 0
			other.hp -= dealt
			shock_damage += dealt
			secondary.append({"kind":"heat_wave","target":other_index,"damage":dealt,"hp":other.hp,"raw":shock_raw,"armor":other.def,"barrier":int(other.get("barrier",0)),"blocked_hits":1 if blocked else 0,"intercept":Ranged.is_projectile(int(other_index)) and int(other.hp)<=0})
			if Content.pressure_combat(s): secondary[-1].armor_percent = Content.armor_percent(int(other.def))
			if Noble.shielded(other):
				secondary[-1].exposure_left=int(other.exposure_left)
				secondary[-1].barrier_removed=removed
			elif Central.active(other):
				secondary[-1].exposure_left=1 if int(other.barrier)==0 else 0
				secondary[-1].barrier_removed=1 if blocked else 0
	var interrupted := 0
	if spec.effect == "disrupt" and int(e.hp) > 0 and not Ranged.is_projectile(index) and not bool(e.get("disrupted", false)):
		if int(e.get("charge_max", 0)) > 0 or Central.leader(e) or preload("res://redesign/foundry_workers.gd").winding(e) or preload("res://redesign/garden_hunters.gd").active(e) or (Noble.shielded(e) and int(e.barrier)==0) or (str(e.get("kind", "")) == "spitter" and (str(e.get("ranged_phase", "")) == "prepare" or (BossSkills.salvo(e) and str(e.get("ranged_phase", "")) == "burst"))):
			interrupted = int(profile.effect)
			e.jammed = interrupted
			e.disrupted = true
	var slowed := Roles.slow(e,Roles.slow_duration(s,Content.is_compressed(id),active_parts)) if Roles.enabled(s) and spec.effect=="disrupt" and not Ranged.is_projectile(index) else 0
	var transferred := 0
	if spec.effect == "spread" and not Ranged.is_projectile(index) and burn_before > 0:
		var others := _rear_transfer_targets(int(e.distance))
		if not others.is_empty():
			var other: Dictionary = s.enemies[others[0]]
			transferred = mini(mini(burn_before, int(profile.effect)), 6 - int(other.get("burn", 0)))
			e.burn = int(e.burn) - transferred
			other.burn = int(other.get("burn", 0)) + transferred
			if transferred > 0: secondary.append({"kind": "burn_transfer", "target": others[0], "damage": 0, "hp": other.hp, "burn": other.burn, "transferred": transferred})
	if spec.effect == "arc":
		var others := _rear_transfer_targets(int(e.distance))
		var target_count := mini(others.size(), int(spec.get("arc_targets", 1)) + Content.arc_target_bonus(s))
		for other_index in range(target_count):
			var other: int = int(others[other_index])
			var other_entity: Dictionary = s.enemies[other]
			var amount := mini(int(other_entity.hp), int(profile.effect))
			other_entity.hp -= amount
			secondary.append({"kind": "arc", "target": other, "damage": amount, "hp": other_entity.hp})
		if not minimal and (not secondary.is_empty()): combo.append("전이 %d명" % secondary.size())
	s.previous_kill = alive_count() < alive_before
	var kill_cooled := mini(int(s.heat), int(Content.PARTS.reclaimer.cool_on_kill)) if active_parts.has("reclaimer") and s.previous_kill else 0
	s.heat -= kill_cooled
	var chain_cooled := _cool_third_round(active_parts, part_context)
	var wrecks := Wreckage.spawn(s.enemies)
	if minimal: return {"sustained_heat":sustained_heat,"sustained_before":sustained_before,"sustained_after":Content.Sustained.count(s),"engine_id":engine_id,"relay_damage":relay_damage,"ordinary_bonus": ordinary_bonus if hits > blocked_hits else 0, "relay_saved": relay_saved, "damage": damage, "heat_after": int(s.heat), "heat_before": heat_before, "overheated": int(s.heat) >= int(profile.heat_limit), "kill_cooled": kill_cooled, "chain_cooled": chain_cooled, "prepared_rounds": prepared_rounds, "interrupted": interrupted, "transferred": transferred, "sequence_bonus": sequence_bonus, "vented": vented, "thermal_bonus": thermal_bonus, "part_hot": active_parts.has("ember_core") and heat_before >= int(profile.hot_threshold) and hits > blocked_hits}
	if relay_saved > 0: combo.append("압축 발열 −%d" % relay_saved)
	if chain_cooled > 0: combo.append("세 번째 발 냉각 −%d" % chain_cooled)
	if interrupted > 0: combo.append("특수 행동 %d턴 차단" % interrupted)
	if transferred > 0: combo.append("화상 %d 이동" % transferred)
	if sequence_bonus > 0: combo.append("탄종 연계 +%d" % sequence_bonus)
	if not prepared_rounds.is_empty():
		var labels: PackedStringArray = []
		for next_id in prepared_rounds: labels.append(Content.AMMO[next_id].name)
		combo.append("다음 패 예약 · " + "/".join(labels))
	if not minimal and (kill_cooled > 0): combo.append("처치 냉각 −%d" % kill_cooled)
	if not minimal and (vented > 0): combo.append("열 %d 소모 · 피해 +%d" % [vented, vent_bonus])
	if not minimal and (thermal_bonus > 0): combo.append("고열 피해 +%d" % thermal_bonus)
	if gate_charge>0: combo.append("축열 첫 타격 +%d" % gate_charge)
	if gate_percent>100: combo.append("처치 연쇄 ×%.2f" % (gate_percent/100.0))
	if chain_earned: combo.append("다음 공격 ×%.2f" % (Gates.chain_percent(s)/100.0))
	if heat_percent<100 and attack:combo.append("고열 위력 %d%%"%heat_percent)
	var math := {"base": int(profile.damage), "boost": dmg_buff, "weakness": weakness_bonus, "part_bonus": part_bonus, "thermal": thermal_bonus, "vent": vent_bonus, "subtotal": subtotal, "factor": factor, "raw": raw, "armor": armor, "per_hit": per_hit, "hits": hits, "hp_before": hp_before, "armor_before": int(e.def), "focus": focus_damage, "barrier_before": barrier_before, "blocked_hits": blocked_hits, "barrier_removed": barrier_removed}
	var description := "%s → %s: %d피해" % [spec.name, e.name, damage]
	if not combo.is_empty(): description += " · " + " / ".join(combo)
	if e.hp == 0: description += " · 요격" if Ranged.is_projectile(index) else " · 처치"
	var result := {"id": id, "target": index, "hit": true, "damage": damage, "hits": hits, "pen": pen, "hp": e.hp, "burn": int(e.get("burn", 0)), "burn_added": burn_added, "burn_tick": int(profile.burn_tick), "push": pushed, "secondary": secondary, "math": math, "combo": combo, "text": description, "focus_before": focus_before, "focus_after": int(e.get("focus_hits", 0)), "focus_damage": focus_damage, "focus_triggers": focus_triggers, "barrier_before": barrier_before, "barrier": int(e.get("barrier", 0)), "blocked_hits": blocked_hits, "barrier_removed": barrier_removed, "boost_granted": int(profile.effect) if spec.effect == "boost" else 0}
	# Salvage (salvage.gd): what this kill would drop if it is the last one.
	if int(e.hp) == 0 and Salvage.enabled(s) and not Salvage.round_for(str(e.get("kind", ""))).is_empty(): result.salvage = Salvage.round_for(str(e.get("kind", "")))
	if WeaponRoles.enabled(s):
		result.weapon_factor = weapon_factor
		result.math.weapon_factor = weapon_factor
	result.engine_id = engine_id
	if FocusBuild.enabled(s):
		result.position_label = " · ".join(Array(part_combo).filter(func(label): return "×" in label))
		result.magazine_ordinal = int(part_context.get("fired_count", 0)) + 1
	if FireHeatTrial.enabled(s):result.math.heat_percent=heat_percent
	result.gate_charge = gate_charge
	result.gate_charge_after = int(s.get("gate_charge",0))
	result.gate_percent = gate_percent
	result.gate_chain_earned = chain_earned
	result.gate_next_percent = Gates.chain_percent(s)
	result.math.first_hit = first_hit
	result.math.gate_charge = gate_charge
	result.math.gate_percent = gate_percent
	result.engine_percent = drive_percent
	result.relay_damage = relay_damage
	result.relay_hits = relay_hits
	result.shock_damage = shock_damage
	result.math.engine_percent = drive_percent
	# Tag parts (tag_build.gd), recorded apart so readouts can name them; only when they act,
	# so other runs keep their exact records.
	if int(tag_effect.percent) != 100: result.math.tag_percent = int(tag_effect.percent)
	if int(tag_effect.add) != 0: result.math.tag_add = int(tag_effect.add)
	if cross_bonus > 0: result.math.cross = cross_bonus
	if breech_bonus > 0: result.math.breech = breech_bonus
	if Content.revised_combat(s):
		result.part_factor = part_factor
		result.math.part_factor = part_factor
	if Content.pressure_combat(s):
		result.overdrive_percent = overdrive_percent
		result.math.overdrive_percent = overdrive_percent
		result.math.armor_percent = Content.armor_percent(armor)
	result.boost_rounds = Content.boost_rounds(id)
	result.boost_replaced = boost_replaced
	result.boost_hot = bool(spec.get("boost_hot",false))
	result.boost_heat = int(spec.get("boost_heat",0))
	result.boost_heat_paid = int(applied.heat)
	result.boost_hot_failed = bool(applied.hot_failed)
	result.boost_factor_granted = Content.boost_factor(id, s) if spec.effect == "boost" else 1
	result.pending_boost = s.buff.duplicate(true)
	if Roles.builds(s):result.slowed=slowed;result.fire_zones=s.fire_zones.duplicate(true)
	if not shield_rule.is_empty(): result.shield_rule = shield_rule
	result.part_effects = preload("res://redesign/part_feedback.gd").shot_effects(s, result, part_effects, burn_before)
	if chain_cooled > 0: result.part_effects.append({"id": "chain_sink", "label": "세 번째 발 냉각 −%d" % chain_cooled})
	if active_parts.has("indexer") and prepared_rounds.size() > Content.multiplier(s): result.part_effects.append({"id": "indexer", "label": "예약 +1장"})
	if transferred > int(spec.value) * Content.multiplier(s):
		if active_parts.has("coil"): result.part_effects.append({"id": "coil", "label": "화상 이동 강화"})
		if active_parts.has("inferno"): result.part_effects.append({"id": "inferno", "label": "화상 이동 강화"})
	if kill_cooled > 0: result.part_effects.append({"id": "reclaimer", "label": "처치 냉각 −%d" % kill_cooled})
	if relay_saved > 0: result.part_effects.append({"id": "compression_sink", "label": "압축 발열 −%d" % relay_saved})
	result.relay_saved = relay_saved
	result.ordinary_bonus = ordinary_bonus
	result.heat_added = heat_added
	result.sustained_active = Content.Sustained.enabled(s)
	result.sustained_before = sustained_before
	result.sustained_after = Content.Sustained.count(s)
	result.sustained_heat = sustained_heat
	result.cooled = cooled + vented + kill_cooled + chain_cooled
	result.chain_cooled = chain_cooled
	result.prepared_rounds = prepared_rounds
	if held_round: result.held = true
	result.interrupted = interrupted
	if Roles.enabled(s):
		result.slowed=slowed;result.slow_left=int(e.get("slow_left",0));result.slow_used=bool(e.get("slow_used",false));result.fire_zones=s.fire_zones.duplicate(true)
	result.transferred = transferred
	result.sequence_bonus = sequence_bonus
	result.math.sequence = sequence_bonus
	result.kill_cooled = kill_cooled
	result.vented = vented
	result.thermal_bonus = thermal_bonus
	result.vent_bonus = vent_bonus
	result.heat_after = int(s.heat)
	result.heat_before = heat_before
	result.overheated = int(s.heat) >= Content.heat_limit(s)
	result.chase_bonus = chase_bonus
	result.detonation = detonation
	result.armor_removed = armor_removed
	result.armor = int(e.def)
	result.stance_def = int(e.get("stance_def", 0))
	if Noble.shielded(e): result.exposure_left=int(e.exposure_left)
	elif Central.active(e): result.exposure_left=1 if int(e.barrier)==0 else 0
	if e.has("shield_open_left"): result.shield_open_left = int(e.shield_open_left)
	if Ranged.is_gatekeeper(e): result.guard_armor = int(e.guard_armor)
	if int(e.get("foundry_version", 0)) == 3: result.shell_armor = int(e.shell_armor)
	result.math.armor_before = armor_before
	result.math.chase = chase_bonus
	if Ranged.is_projectile(index) and int(e.hp) == 0: result.intercept = true
	if not wrecks.is_empty(): result.wreckage_spawn = wrecks
	return result

func _cool_third_round(parts: Array, context: Dictionary) -> int:
	var cooled := mini(int(s.heat), int(Content.PARTS.chain_sink.third_cooling)) if parts.has("chain_sink") and int(context.get("fired_count", -1)) == 2 else 0
	s.heat -= cooled
	return cooled

# Follow-up direct impacts are bounded by remaining hits/targets. No recursive
# status, boost, heat or proc reactivation. Scatter's initial target stays random;
# continuation always uses the public nearest-target rule.
func _engine_relay(id: String, remaining: int, overflow: int, base: int, factor: float, percent: int, pen: int, parts: Array, gate_percent: int = 100, overdrive_percent: int = 100) -> Dictionary:
	var events: Array = []
	var total := 0
	var connected := 0
	var reached: Array=[]
	while remaining>0 or overflow>0:
		var next := target_index()
		if next<0: break
		var wreck := Wreckage.blocker(s.enemies, next)
		if wreck >= 0:
			events.append(Wreckage.strike(s.enemies, wreck, Wreckage.STACKS if Content.source_id(id) == "pierce" else maxi(1, remaining)))
			break
		if not reached.has(next):
			if reached.size()>=Roles.relay_limit(s,parts):break
			reached.append(next)
		var other := target_entity(next)
		var is_overflow := overflow>0
		var hp := int(other.hp)
		var blocked := int(other.get("barrier",0))>0
		var amount := overflow
		if not is_overflow:
			var added := Content.weakness_bonus(id,other)+Roles.control_bonus(s,parts,other)+(2 if parts.has("igniter") and int(other.get("burn",0))>0 else 0)+(PartTuning.execute_bonus(s) if parts.has("executioner") and PartTuning.executes(s, hp, int(other.get("max_hp", hp))) else 0)
			amount = int((base+added)*factor*percent*gate_percent*overdrive_percent/1000000.0)
		amount = Content.armored_damage(amount,maxi(0,int(other.def)-pen),s,0 if is_overflow else 1)
		var dealt := 0
		var removed := 0
		if blocked:
			removed=Noble.strip(other,(2 if parts.has("breaker") else 1)+(1 if (Noble.shielded(other) or Central.active(other)) and str(Content.AMMO[id].attribute)=="electric" and not is_overflow else 0), "" if is_overflow else Content.source_id(id))
		else:
			dealt = mini(hp,amount)
			other.hp -= dealt
			if dealt>0: connected += 1
		if not is_overflow and s.gun=="burst" and not WeaponRoles.enabled(s):
			other.focus_hits = int(other.get("focus_hits",0))+1
			if int(other.focus_hits)>=3:
				other.focus_hits = 0
				var extra := mini(4,int(other.hp)) if not blocked else 0
				other.hp -= extra
				dealt += extra
		total += dealt
		events.append({"kind":"overflow" if is_overflow else "relay","target":next,"damage":dealt,"hp":int(other.hp),"barrier":int(other.get("barrier",0)),"focus_hits":int(other.get("focus_hits",0)),"blocked_hits":1 if blocked else 0,"intercept":Ranged.is_projectile(next) and int(other.hp)<=0})
		if Roles.builds(s) and not is_overflow and not blocked and Roles.control_bonus(s,parts,other)>0:events[-1].control_bonus=2
		if Noble.shielded(other):
			events[-1].exposure_left=int(other.exposure_left)
			events[-1].barrier_removed=removed
		elif Central.active(other):
			events[-1].exposure_left=1 if int(other.barrier)==0 else 0
			events[-1].barrier_removed=removed
		if is_overflow: overflow = maxi(0,amount-hp) if not blocked else 0
		else: remaining -= 1
	return {"events":events,"damage":total,"hits":connected}

## Detached simulation/presentation state. Historical receipts before the last
## confirmed magazine cannot affect its part sequence. Slice BEFORE deep-copying
## so forecast cost does not grow with completed encounters. Never use for saves.
static func simulation_state(state: Dictionary) -> Dictionary:
	var copy := state.duplicate(false)
	var history: Array = state.get("history", [])
	var start := 0
	for i in range(history.size() - 1, -1, -1):
		if str(history[i].get("action", "")) == "load":
			start = i
			break
	copy.history = history.slice(start)
	return copy.duplicate(true)

func preview() -> Dictionary:
	var stack: Array = s.plan if s.phase == "plan" else s.magazine
	if stack.is_empty() or target_index() < 0 or s.gun == "scatter":
		return {}
	var copy = get_script().new()
	copy.s = simulation_state(s)
	var recent: Array = _recent_part_sources() if s.phase == "ready" else []
	var source: String = Content.source_id(str(stack.front()))
	var triad_ready: bool = recent.size() >= 2 and recent[-1] != recent[-2] and source != recent[-1] and source != recent[-2]
	var rounds := _recent_part_rounds() if s.phase == "ready" else []
	return copy._shot(str(stack.front()), -1, {"weapon_factor":3 if WeaponRoles.mark(s)==0 else 1,"previous_round": str(rounds.back()) if not rounds.is_empty() else "", "first": recent.is_empty(), "last": stack.size() == 1, "last_attack": not stack.slice(1).any(func(round_id): return Content.is_attack(str(round_id))), "triad": triad_ready, "fired_count": recent.size(), "sequence_count": Content.prior_kind_count(recent, str(stack.front())), "recent_sources": recent.duplicate(), "breech": PartTuning.breech_ready(s, Content.active_parts(s)) and Content.is_attack(str(stack.front()))})

func movement_preview(turn_count: int) -> Array:
	var copy = get_script().new()
	copy.s = simulation_state(s)
	copy._advance(turn_count)
	var result: Array = []
	for e in copy.s.enemies: result.append(int(e.distance))
	return result

func choose_reward(id: String, remove_id: String = "") -> bool:
	if s.phase != "reward" or s.reward_taken:
		return false
	var options: Array = reward_options()
	if id == "skip":
		pass
	elif id == "remove":
		if s.deck.size() <= minimum_deck() or not s.deck.has(remove_id):
			return false
		s.deck.erase(remove_id)
	elif options.has(id) and Content.AMMO.has(id):
		if s.deck.size() >= deck_limit():
			return false
		s.deck.append(id)
	elif options.has(id) and Content.PARTS.has(id):
		var equipped := Content.equipped_parts(s)
		var proposed := equipped.duplicate()
		proposed.append(id)
		if not Content.valid_part_set(str(s.gun), proposed, s): return false
		s.equipped_parts = proposed
		s.part = id
	else:
		return false
	s.reward_taken = true
	_record("reward", {"choice": id, "removed": remove_id})
	s.floor += 1
	if s.get("course", false): s.deck.append_array(Content.COURSE_GRANTS[int(s.floor)])
	begin_encounter()
	return true

func minimum_deck() -> int:
	return 2 if s.get("course", false) else 8

func deck_limit() -> int:
	var reserved := 0
	if s.get("course", false):
		for stage in range(int(s.floor) + 1, 7): reserved += Content.COURSE_GRANTS[stage].size()
	return Reserve.limit(s) - reserved

func reward_options() -> Array:
	var options := Content.rewards_for(int(s.floor), int(s.seed), str(s.gun), s.get("course", false))
	for id in Content.equipped_parts(s): options.erase(str(id))
	return options

func remove_planned(index: int) -> bool:
	if s.phase != "plan" or index < 0 or index >= s.plan.size(): return false
	# In finite-reserve runs insertion commits the round; only a full reload
	# can eject it. Rejected undo must not mutate inventory, RNG or history.
	if Reserve.enabled(s): return false
	var id: String = str(s.plan[index])
	if Content.is_temporary(id): return _cancel_field_compression()
	s.plan.remove_at(index)
	var history_index: int = s.plan_load_order.rfind(id)
	if history_index >= 0: s.plan_load_order.remove_at(history_index)
	return true

func _spend_planned(index: int) -> void:
	# Ordinary planned rounds are still in hand; temporary originals are already removed.
	var id := str(s.plan.pop_at(index))
	var history_index: int = s.plan_load_order.rfind(id)
	if history_index >= 0: s.plan_load_order.remove_at(history_index)
	if not Content.is_temporary(id): s.hand.erase(id)
	_discard_fired_round(id)

func can_move_planned(from: int, to: int) -> bool:
	if s.phase != "plan" or from == to or from < 0 or to < 0 or from >= s.plan.size() or to >= s.plan.size(): return false
	var proposed: Array = s.plan.duplicate()
	var id: String = str(proposed.pop_at(from))
	proposed.insert(to, id)
	return Content.valid_stack(proposed, capacity())

func move_planned(from: int, to: int) -> bool:
	if not can_move_planned(from, to): return false
	var id: String = str(s.plan.pop_at(from))
	s.plan.insert(to, id)
	return true

func field_compressible_ids() -> Array:
	var result: Array = []
	if s.phase != "plan" or s.get("course", false) or int(s.get("field_compression_left", 0)) <= 0 or not s.get("field_compression", {}).is_empty():
		return result
	for source in Content.FIELD_COMPRESSIONS:
		if can_field_compress(str(source)): result.append(str(source))
	return result

func can_field_compress(source: String) -> bool:
	if WeaponRoles.enabled(s): return false
	if s.phase != "plan" or s.get("course", false) or int(s.get("field_compression_left", 0)) <= 0 or not s.get("field_compression", {}).is_empty(): return false
	if not Content.FIELD_COMPRESSIONS.has(source) or Content.is_compressed(source) or available(source) < 2: return false
	return Content.can_insert(s.plan, Content.field_id(source), capacity())

func field_compress(source: String) -> bool:
	if not can_field_compress(source): return false
	var id := Content.field_id(source)
	s.hand.erase(source)
	s.hand.erase(source)
	var index := Content.insertion_index(s.plan, id)
	s.plan.insert(index, id)
	s.plan_load_order.append(id)
	s.field_compression = {"source": source, "id": id, "zone": "plan"}
	s.field_compression_left -= 1
	s.message = "%s 두 발을 현장 압축 · 확정 전 되돌리면 압축 코어가 복구됩니다." % Content.AMMO[source].name
	if Reserve.enabled(s): s.message = "%s 두 발 현장 압축 · 개별 회수 불가 · 재장전 배출 시 원본 두 발도 사용함으로 이동합니다." % Content.AMMO[source].name
	return true

func _cancel_field_compression() -> bool:
	if s.phase != "plan" or s.get("field_compression", {}).is_empty() or str(s.field_compression.get("zone", "")) != "plan": return false
	var id := str(s.field_compression.id)
	var source := str(s.field_compression.source)
	var plan_index: int = s.plan.find(id)
	var order_index: int = s.plan_load_order.find(id)
	if plan_index < 0 or order_index < 0: return false
	if Reserve.enabled(s): return false
	s.plan.remove_at(plan_index)
	s.plan_load_order.remove_at(order_index)
	s.hand.append(source)
	s.hand.append(source)
	s.field_compression = {}
	s.field_compression_left = mini(2 + Content.field_compression_bonus(s), int(s.field_compression_left) + 1)
	s.message = "현장 압축 취소 · 원본 두 발과 압축 코어를 복구했습니다."
	return true

func _discard_fired_round(id: String) -> void:
	if Content.is_temporary(id) and not s.get("field_compression", {}).is_empty() and str(s.field_compression.get("id", "")) == id:
		var source := str(s.field_compression.source)
		s.discard.append(source)
		s.discard.append(source)
		s.field_compression = {}
	elif id != "basic" or Content.uses_ammo_cards(s):
		s.discard.append(id)

func _release_unfired_field_round() -> void:
	if s.get("field_compression", {}).is_empty() or str(s.field_compression.get("zone", "")) != "magazine": return
	var id := str(s.field_compression.id)
	if s.magazine.has(id):
		s.magazine.erase(id)
		_discard_fired_round(id)

func exchange(id: String) -> bool:
	if s.phase != "plan" or int(s.exchange_left) <= 0 or (id == "basic" and not Content.uses_ammo_cards(s)) or available(id) <= 0: return false
	# The exchanged round joins discard only AFTER replacement: never redraw itself.
	if s.draw.is_empty() and (Reserve.enabled(s) or s.discard.is_empty()): return false
	s.hand.erase(id)
	_refill(s.hand.size() + 1)
	s.discard.append(id)
	s.exchange_left -= 1
	s.message = "%s 교환 · 이번 전투 사용함으로 이동" % Content.AMMO[id].name if Reserve.enabled(s) else "%s 교환 · 다음 재장전 때 교환 %d회 복구" % [Content.AMMO[id].name, Content.exchange_capacity(s)]
	_record("exchange", {"id": id})
	return true

func _shuffle(items: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.state = int(s.rng_state)
	for i in range(items.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var value = items[i]
		items[i] = items[j]
		items[j] = value
	s.rng_state = str(rng.state)

func _draw_prepared() -> void:
	# Reservations move owned cards, never add cards or consume draw RNG.
	for id in s.get("prepared", []):
		if s.hand.size() >= Content.hand_capacity(s): break
		for zone in ([s.draw] if Reserve.enabled(s) else [s.discard, s.draw]):
			if zone.has(id):
				zone.erase(id)
				s.hand.append(id)
				break
	s.prepared = []

func _refill(target_size: int = -1) -> void:
	if target_size < 0: target_size = Content.hand_capacity(s)
	while s.hand.size() < target_size:
		if s.draw.is_empty():
			if Reserve.enabled(s) or s.discard.is_empty():
				break
			s.draw = s.discard.duplicate()
			s.discard.clear()
			_shuffle(s.draw)
		s.hand.append(s.draw.pop_front())

func _record(action: String, detail: Dictionary) -> void:
	s.history.append({"action": action, "floor": s.floor, "turn": s.turns, "detail": detail})
	if s.has("encounter_id"): s.history.back()["node"] = s.encounter_id

func serialized_state() -> String:
	if _save_history == null: _save_history = preload("res://redesign/history_json.gd").new()
	return _save_history.stringify(s)

func save_run(path: String) -> Error:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(serialized_state())
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path)

func restore_run(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return false
	var parsed = parser.data
	if not parsed is Dictionary:
		return false
	return restore_state(parsed)

func restore_state(source: Dictionary) -> bool:
	var parsed: Dictionary = source.duplicate(true)
	if not FireHeatTrial.valid(parsed):return false
	if not preload("res://redesign/combat_approach_trial.gd").valid(parsed): return false
	if not _whole(parsed.get("magazine_trial_version", 0), 0, MagazineTrial.VERSION): return false
	if not _whole(parsed.get("weapon_magazine_version", 0), 0, MagazineTrial.WEAPON_VERSION): return false
	if int(parsed.get("weapon_magazine_version", 0)) > 0 and (not MagazineTrial.enabled(parsed) or int(parsed.get("weapon_version", 0)) != 1): return false
	if parsed.has("magazine_ejected") and (not MagazineTrial.weapons_enabled(parsed) or not _whole(parsed.magazine_ejected,0,Content.eject_limit(parsed))): return false
	if not _whole(parsed.get("magazine_build_version", 0), 0, MagazineBuild.VERSION): return false
	if not Roles.valid(parsed):return false
	if not _whole(parsed.get("focus_build_version", 0), 0, FocusBuild.VERSION): return false
	if not BuildEngine.valid(parsed): return false
	if not GrowthV2.valid(parsed): return false
	if not TagBuild.valid(parsed): return false
	if not Overheat.valid(parsed): return false
	if not RewardTrim.valid(parsed): return false
	if not RewardMix.valid(parsed): return false
	if not MixCombo.valid(parsed): return false
	if not Salvage.valid(parsed): return false
	if not AmmoRevision.valid(parsed): return false
	if not Balance.valid(parsed): return false
	if not Patterns.valid(parsed): return false
	if FocusBuild.enabled(parsed) and int(parsed.get("fire_control_version",0)) != FireHeatTrial.CAMPAIGN_VERSION: return false
	if MagazineBuild.enabled(parsed) and not MagazineTrial.weapons_enabled(parsed): return false
	if parsed.has("magazine_loaded"):
		if not MagazineBuild.enabled(parsed) or not parsed.magazine_loaded is Array: return false
		for id in parsed.magazine_loaded:
			if not id is String or not Content.AMMO.has(id): return false
	if MagazineTrial.enabled(parsed):
		if (parsed.get("gun", "") != "single" and not MagazineTrial.weapons_enabled(parsed)) or not Reserve.enabled(parsed) or parsed.get("course", false) or not parsed.get("field_compression", {}) is Dictionary or not parsed.get("field_compression", {}).is_empty(): return false
	Content.Merge.combat(parsed)
	if not _whole(parsed.get("weapon_version", 0), 0, 1): return false
	if not _whole(parsed.get("sustained_version", 0), 0, Content.Sustained.VERSION): return false
	if not _whole(parsed.get("growth_version", 0), 0, Engines.Growth.VERSION): return false
	if not _whole(parsed.get("combat_revision", 0), 0, Content.COMBAT_REVISION): return false
	parsed.weapon_version = int(parsed.get("weapon_version", 0))
	if parsed.has("ammo_cycle") and not _whole(parsed.ammo_cycle, 1, 1): return false
	if not Content.valid_bag_state(parsed): return false
	if parsed.has("outfit") and (not parsed.outfit is String or not Content.OUTFITS.has(parsed.outfit)): return false
	if int(parsed.get("version", -1)) == 2:
		parsed = _migrate_v7(_migrate_v6(_migrate_v5(_migrate_v4(_migrate_v3(_migrate_v2(parsed))))))
	elif int(parsed.get("version", -1)) == 3:
		parsed = _migrate_v7(_migrate_v6(_migrate_v5(_migrate_v4(_migrate_v3(parsed)))))
	elif int(parsed.get("version", -1)) == 4:
		parsed = _migrate_v7(_migrate_v6(_migrate_v5(_migrate_v4(parsed))))
	elif int(parsed.get("version", -1)) == 5:
		parsed = _migrate_v7(_migrate_v6(_migrate_v5(parsed)))
	elif int(parsed.get("version", -1)) == 6:
		parsed = _migrate_v7(_migrate_v6(parsed))
	elif int(parsed.get("version", -1)) == 7:
		parsed = _migrate_v7(parsed)
	elif int(parsed.get("version", -1)) not in [8, 9, 10, 11, 12, 13, 14, VERSION]:
		return false
	if int(parsed.version)<15: parsed.engine = Engines.fresh()
	if not Gates.valid(parsed): return false
	if not Engines.valid(parsed.get("engine"),Engines.Growth.limit(parsed)): return false
	if not parsed.has("course"): parsed.course = false
	if not parsed.course is bool: return false
	# Old heat meant extra reload turns, never temperature. Preserve that debt
	# for one reload while migrating to a zero-temperature v9 state.
	if int(parsed.version) == 8:
		if not _whole(parsed.get("reload_heat", 0), 0, 1000000): return false
		parsed.legacy_reload_penalty = int(parsed.get("reload_heat", 0))
		parsed.heat = 0
		parsed.erase("reload_heat")
		parsed.version = VERSION
	if int(parsed.version) in [9, 10, 11, 12, 13, 14]:
		# Saved arrays already describe displayed firing order. Keep that order,
		# including a confirmed/partially fired magazine; new input uses LIFO.
		parsed.version = VERSION
	if not parsed.has("prepared"): parsed.prepared = []
	if not _whole(parsed.get("heat", -1), 0, 1000000): return false
	if not _whole(parsed.get("legacy_reload_penalty", 0), 0, 1000000): return false
	parsed.heat = int(parsed.heat)
	parsed.legacy_reload_penalty = int(parsed.get("legacy_reload_penalty", 0))
	if not parsed.get("previous_kill", false) is bool: return false
	parsed.previous_kill = bool(parsed.get("previous_kill", false))
	if parsed.heat > 0 and parsed.get("phase", "") not in ["plan", "ready"]: return false
	if parsed.legacy_reload_penalty > 0 and parsed.get("phase", "") != "ready": return false
	for key in ["seed", "gun", "part", "equipped_parts", "floor", "deck", "turns", "shots", "reloads", "history", "reward_taken", "phase", "enemies", "reinforcements", "encounter_total", "deployed", "wave", "hand", "draw", "discard", "magazine", "plan", "plan_load_order", "buff", "push_left", "supply", "rng_state", "target_rng_state", "message", "exchange_left", "field_compression_left", "field_compression"]:
		if not parsed.has(key):
			return false
	if not Content.GUNS.has(parsed.gun) or not Content.PARTS.has(parsed.part) or not _whole(parsed.floor, 0, 6) or not parsed.phase in ["plan", "ready", "reward", "won", "lost"]:
		return false
	if parsed.heat >= Content.heat_limit(parsed): return false
	if not parsed.equipped_parts is Array or not Content.valid_part_set(str(parsed.gun), parsed.equipped_parts, parsed): return false
	# `part` remains readable for older automation and v7 migration. A current save
	# must still satisfy the five-slot and one-core limits after that legacy value
	# is folded into the equipped list.
	if not Content.valid_part_set(str(parsed.gun), Content.equipped_parts(parsed), parsed): return false
	# JSON numbers cannot preserve every signed 64-bit seed. New saves use text;
	# old ordinary numeric seeds remain readable, unsafe numeric seeds are rejected.
	if parsed.seed is String:
		if not parsed.seed.is_valid_int() or str(int(parsed.seed)) != parsed.seed:
			return false
	elif not _whole(parsed.seed, -9007199254740991, 9007199254740991):
		return false
	parsed.seed = str(int(parsed.seed))
	if not parsed.rng_state is String or not parsed.rng_state.is_valid_int() or not parsed.target_rng_state is String or not parsed.target_rng_state.is_valid_int():
		return false
	for key in ["turns", "shots", "reloads"]:
		if not _whole(parsed[key], 0, 1000000): return false
	if not Content.Sustained.valid(parsed): return false
	# Preserve unmarked legacy state without adding inactive fields.
	if parsed.has("sustained_version"): parsed.sustained_version = int(parsed.sustained_version)
	if parsed.has("sustained_attacks"): parsed.sustained_attacks = int(parsed.sustained_attacks)
	if not _whole(parsed.get("reserve_version", 0), 0, Reserve.VERSION): return false
	if not _whole(parsed.get("inventory_version", 0), 0, Reserve.INVENTORY_VERSION): return false
	if not _whole(parsed.get("emergency_version", 0), 0, Reserve.EMERGENCY_VERSION): return false
	if int(parsed.get("emergency_version",0)) > 0 and not Reserve.enabled(parsed): return false
	if Reserve.emergency_enabled(parsed):
		if not _whole(parsed.get("emergency_uses", -1), 0, int(parsed.reloads)): return false
	elif parsed.has("emergency_uses") and parsed.emergency_uses != 0: return false
	if not parsed.history is Array or not parsed.message is String or not parsed.reward_taken is bool or not parsed.buff is Dictionary:
		return false
	if not AttackBoosts.valid(parsed.buff): return false
	if not _whole(parsed.get("capacity_bonus", 0), 0, 2): return false
	var limit: int = Content.capacity(parsed)
	var supply_limit := Content.supply_capacity(parsed)
	if not _whole(parsed.exchange_left, 0, Content.exchange_capacity(parsed)): return false
	var compression_limit := 2 + Content.field_compression_bonus(parsed)
	if not _whole(parsed.field_compression_left, 0, compression_limit) or not parsed.field_compression is Dictionary: return false
	if parsed.buff.has("dmg") != parsed.buff.has("dmg_left"): return false
	if parsed.buff.has("persistent") and not parsed.buff.has("dmg"): return false
	if parsed.buff.has("dmg") and not _whole(parsed.buff.dmg_left, 1, 2): return false
	if not _whole(parsed.supply, 0, supply_limit) or not _whole(parsed.push_left, 0, Content.push_budget(parsed)): return false
	for key in ["deck", "hand", "draw", "discard", "magazine", "plan", "plan_load_order"]:
		if not parsed[key] is Array:
			return false
		for id in parsed[key]:
			if not Content.AMMO.has(id): return false
			if key in ["deck", "hand", "draw", "discard"] and id == "basic" and not Content.uses_ammo_cards(parsed): return false
			if key in ["deck", "hand", "draw", "discard"] and Content.is_temporary(str(id)): return false
	if not WeaponRoles.valid(parsed,Content.is_attack): return false
	if not parsed.prepared is Array or parsed.prepared.size() > 3: return false
	for id in parsed.prepared:
		if not id is String or not Content.AMMO.has(id) or (id == "basic" and not Content.uses_ammo_cards(parsed)) or Content.is_temporary(id): return false
		if parsed.prepared.count(id) > parsed.deck.count(id) + (Reserve.generated_count(parsed) if id == Reserve.EMERGENCY_ROUND else 0): return false
	# Legacy city saves may already contain six or seven cards. They remain
	# readable, while every new removal/compression path enforces the new floor 8.
	if Reserve.inventory_enabled(parsed) and (not Reserve.enabled(parsed) or parsed.get("bag_version", 0) != Content.BAG_VERSION or not Reserve.CARRY_LIMITS.has(parsed.get("outfit", ""))): return false
	if Reserve.enabled(parsed) and (parsed.course or not Content.uses_ammo_cards(parsed)): return false
	if parsed.deck.size() < (2 if parsed.course else 6) or parsed.deck.size() > Reserve.limit(parsed) or parsed.hand.size() > Content.hand_capacity(parsed) or not Content.valid_stack(parsed.magazine, limit) or not Content.valid_stack(parsed.plan, limit):
		return false
	if (parsed.phase == "plan" and not parsed.magazine.is_empty()) or (parsed.phase != "plan" and (not parsed.plan.is_empty() or not parsed.plan_load_order.is_empty())): return false
	var planned_sorted: Array = parsed.plan.duplicate()
	var history_sorted: Array = parsed.plan_load_order.duplicate()
	planned_sorted.sort()
	history_sorted.sort()
	if planned_sorted != history_sorted: return false
	for id in parsed.plan:
		if not Content.is_temporary(str(id)):
			var count: int = int(parsed.supply) if id == "basic" and not Content.uses_ammo_cards(parsed) else parsed.hand.count(id)
			if parsed.plan.count(id) > count: return false
	var transient_ids: Array = []
	for id in parsed.plan + parsed.magazine:
		if Content.is_temporary(str(id)): transient_ids.append(str(id))
	if parsed.field_compression.is_empty():
		if not transient_ids.is_empty(): return false
	else:
		for key in ["source", "id", "zone"]:
			if not parsed.field_compression.has(key) or not parsed.field_compression[key] is String: return false
		var field_source := str(parsed.field_compression.source)
		var field_id := str(parsed.field_compression.id)
		var field_zone := str(parsed.field_compression.zone)
		if not Content.FIELD_COMPRESSIONS.has(field_source) or Content.field_id(field_source) != field_id or transient_ids != [field_id] or int(parsed.field_compression_left) > compression_limit - 1: return false
		if field_zone == "plan":
			if parsed.phase != "plan" or parsed.plan.count(field_id) != 1 or parsed.plan_load_order.count(field_id) != 1: return false
		elif field_zone == "magazine":
			if parsed.phase != "ready" or parsed.magazine.count(field_id) != 1: return false
		else: return false
	if parsed.course and (int(parsed.field_compression_left) != 0 or not parsed.field_compression.is_empty()): return false
	var owned: Array = parsed.hand + parsed.draw + parsed.discard
	for id in parsed.magazine:
		if Content.is_temporary(str(id)):
			owned.append(Content.compression_source(str(id)))
			owned.append(Content.compression_source(str(id)))
		elif id != "basic" or Content.uses_ammo_cards(parsed): owned.append(id)
	for id in parsed.plan:
		if Content.is_temporary(str(id)):
			owned.append(Content.compression_source(str(id)))
			owned.append(Content.compression_source(str(id)))
	owned.sort()
	if owned.size() != parsed.deck.size() + Reserve.generated_count(parsed): return false
	var expected: Array = parsed.deck.duplicate()
	for unused in range(Reserve.generated_count(parsed)): expected.append(Reserve.EMERGENCY_ROUND)
	expected.sort()
	if owned != expected: return false
	if not parsed.enemies is Array or parsed.enemies.is_empty() or parsed.enemies.size() > 8: return false
	if not parsed.reinforcements is Array or parsed.reinforcements.size() > 8 or parsed.enemies.size() + parsed.reinforcements.size() > 8: return false
	if not _whole(parsed.encounter_total, 1, 8) or not _whole(parsed.deployed, 1, 8) or not _whole(parsed.wave, 1, 8): return false
	for enemy in parsed.enemies + parsed.reinforcements:
		if not _valid_enemy(enemy): return false
		if int(enemy.get("foundry_version", 0)) == 3 and not Patterns.enabled(parsed): return false
		if not Content.pressure_combat(parsed) and (int(enemy.get("foundry_version",0))>=2 or int(enemy.get("central_version",0))>=2): return false
	if not Ranged.valid_state(parsed): return false
	if not Wreckage.valid(parsed.enemies, parsed.reinforcements): return false
	if not BossSkills.valid(parsed): return false
	if parsed.get("loss_reason","") == "ammo":
		if Reserve.emergency_enabled(parsed): return false
		if not Reserve.enabled(parsed) or parsed.phase != "lost" or not (parsed.hand + parsed.draw + parsed.magazine).is_empty(): return false
	parsed.projectiles = parsed.get("projectiles", [])
	parsed.projectile_serial = int(parsed.get("projectile_serial", 0))
	parsed.loss_reason = str(parsed.get("loss_reason", ""))
	s = parsed
	return true

func _migrate_v3(old_state: Dictionary) -> Dictionary:
	var old_seed: Variant = old_state.get("seed")
	if old_seed is String:
		if not old_seed.is_valid_int() or str(int(old_seed)) != old_seed: return {}
	elif not _whole(old_seed, -9007199254740991, 9007199254740991): return {}
	if not _whole(old_state.get("floor"), 0, 6): return {}
	var migrated: Dictionary = old_state.duplicate(true)
	migrated.target_rng_state = _target_state(migrated)
	migrated.version = 4
	return migrated

func _migrate_v4(old_state: Dictionary) -> Dictionary:
	var migrated: Dictionary = old_state.duplicate(true)
	migrated.plan_load_order = migrated.get("plan", []).duplicate()
	migrated.version = 5
	return migrated

func _migrate_v5(old_state: Dictionary) -> Dictionary:
	var migrated: Dictionary = old_state.duplicate(true)
	migrated.field_compression_left = 0 if migrated.get("course", false) else 1
	migrated.field_compression = {}
	migrated.version = 6
	return migrated

func _migrate_v6(old_state: Dictionary) -> Dictionary:
	var migrated: Dictionary = old_state.duplicate(true)
	migrated.reinforcements = []
	migrated.encounter_total = migrated.get("enemies", []).size()
	migrated.deployed = migrated.get("enemies", []).size()
	migrated.wave = 1
	migrated.version = 7
	return migrated

func _migrate_v7(old_state: Dictionary) -> Dictionary:
	var migrated: Dictionary = old_state.duplicate(true)
	var legacy := str(migrated.get("part", "none"))
	migrated.equipped_parts = [legacy] if Content.PARTS.has(legacy) and legacy != "none" else []
	migrated.version = 8
	return migrated

func _migrate_v2(old_state: Dictionary) -> Dictionary:
	var migrated: Dictionary = old_state.duplicate(true)
	var replacements := {"mark": "charge", "slow": "push", "finish": "pierce"}
	for key in ["deck", "hand", "draw", "discard", "magazine", "plan"]:
		if migrated.get(key) is Array:
			for i in range(migrated[key].size()):
				var old_id := str(migrated[key][i])
				if replacements.has(old_id): migrated[key][i] = replacements[old_id]
	if migrated.get("buff") is Dictionary:
		migrated.buff.erase("acc")
		migrated.buff.erase("acc_left")
	if migrated.get("enemies") is Array:
		for enemy in migrated.enemies:
			if not enemy is Dictionary: continue
			enemy.erase("eva")
			enemy.erase("slow")
			enemy.erase("crack")
			enemy.burn = 0
			if Content.ENEMY_NAMES.has(enemy.get("kind", "")): enemy.name = Content.ENEMY_NAMES[enemy.kind]
	migrated.version = 3
	return migrated

func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float): return false
	return is_finite(float(value)) and float(value) == floorf(float(value)) and value >= minimum and value <= maximum

func _valid_enemy(enemy: Variant) -> bool:
	if not enemy is Dictionary: return false
	if not preload("res://redesign/foundry_workers.gd").valid(enemy): return false
	if not preload("res://redesign/garden_hunters.gd").valid(enemy): return false
	if not Noble.valid(enemy): return false
	if not Central.valid(enemy): return false
	if not _whole(enemy.get("jammed", 0), 0, 2) or not enemy.get("disrupted", false) is bool: return false
	if int(enemy.get("jammed", 0)) > 0 and not bool(enemy.get("disrupted", false)): return false
	for key in ["kind", "name", "hp", "max_hp", "def", "speed", "distance", "burn"]:
		if not enemy.has(key): return false
	if not Content.ENEMY_NAMES.has(enemy.kind) or not enemy.name is String: return false
	for key in ["hp", "max_hp", "def", "speed", "distance", "burn"]:
		if not _whole(enemy[key], 0, 1000000): return false
	if enemy.hp > enemy.max_hp or not _whole(enemy.burn, 0, 6) or not _whole(enemy.get("focus_hits", 0), 0, 2): return false
	if not _whole(enemy.get("barrier", 0), 0, 9) or not _whole(enemy.get("barrier_max", 0), 0, 9) or int(enemy.get("barrier", 0)) > int(enemy.get("barrier_max", 0)): return false
	if not _whole(enemy.get("charge", 0), 0, 9) or not _whole(enemy.get("charge_max", 0), 0, 9) or not _whole(enemy.get("charge_pull", 0), 0, 9): return false
	if int(enemy.get("charge_max", 0)) > 0 and int(enemy.get("charge", 0)) >= int(enemy.get("charge_max", 0)): return false
	if enemy.has("stance") and not enemy.stance is bool: return false
	if bool(enemy.get("stance", false)):
		if not enemy.get("stance_closed", true) is bool or not _whole(enemy.get("stance_def", 4), 0, 9): return false
		if int(enemy.def) != (int(enemy.stance_def) if bool(enemy.get("stance_closed", true)) else 0): return false
	if enemy.has("lane") and not _whole(enemy.lane, -1, 3): return false
	if enemy.has("weakness") and (not enemy.weakness is String or not str(enemy.weakness) in ["", "electric"]): return false
	return true
