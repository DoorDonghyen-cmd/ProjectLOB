extends RefCounted
## Deck-building revision for the full-climb magazine (2026-11-01).
## Applies only to new runs that record `magazine_build_version = 1` (campaign and
## combat state). Older saves, training and comparison fixtures keep their rules.
##
## 1. Leaner start deck: 14 basics (power 2 x8, power 3 x6) instead of 20, so earned
##    rounds show up more often in each automatically loaded magazine.
## 2. The player no longer orders rounds, so three parts that paid off a hand-built
##    firing order now read the loaded magazine's composition (`magazine_loaded`):
##    triad, compression_sink and afterburner. Rejected rounds (ejection) leave it.
## 3. combos(): a short readout of what the current magazine forms, for the HUD.
## 4. Version 2 (user playtest 2026-11-01: "fights end before one magazine is empty"):
##    enemy HP x2.0 normal / x1.6 elite at combat entry, so a fight spends several
##    magazines and the deck actually cycles. Bosses keep authored HP: they already
##    spanned 1.8-2.8 magazines, and x1.2 already made Splinter's final boss
##    unwinnable. Moving enemies start farther by half the HP increase (x1.5 / x1.3): the extra work gets
##    some extra time, but the net pressure still rises. Stationary shooters keep
##    their position and shot clock. Armoured enemies (def or guard armour > 0) get
##    half the HP increase, because percentage armour already multiplies their
##    effective HP (a doubled 16 HP / armour 6 shield could not be beaten in time).
##    Version 1 runs keep HP and distance.
## Design record: docs/direction/magazine-build.md
const Content = preload("res://redesign/content.gd")
const VERSION := 2
const VITALITY_VERSION := 2
const HP_SCALE := {"normal": 2.0, "elite": 1.6, "boss": 1.0}
## Share of the HP increase given back as starting distance for moving enemies.
const DISTANCE_SHARE := 0.5
## Share of the HP increase applied to armoured enemies.
const ARMOUR_SHARE := 0.5
const TRIAD_KINDS := 3
const TRIAD_BONUS := 3
const COMPRESSION_SAVE := 2

static func enabled(state: Dictionary) -> bool:
	return int(state.get("magazine_build_version", 0)) >= 1

static func vitality(state: Dictionary) -> bool:
	return int(state.get("magazine_build_version", 0)) >= VITALITY_VERSION

## Scale every enemy of the encounter (active and reinforcements) once, at entry.
static func strengthen(state: Dictionary, rank: String) -> void:
	if not vitality(state): return
	var factor: float = float(HP_SCALE.get(rank, HP_SCALE.normal))
	for group in [state.get("enemies", []), state.get("reinforcements", [])]:
		for enemy in group:
			var hp_factor: float = hp_scale(enemy, factor)
			enemy.max_hp = ceili(int(enemy.max_hp) * hp_factor)
			enemy.hp = mini(int(enemy.max_hp), ceili(int(enemy.hp) * hp_factor))
			if int(enemy.get("speed", 0)) > 0:
				enemy.distance = ceili(int(enemy.distance) * (1.0 + (factor - 1.0) * DISTANCE_SHARE))

static func hp_scale(enemy: Dictionary, factor: float) -> float:
	var armoured: bool = maxi(int(enemy.get("def", 0)), int(enemy.get("guard_armor", 0))) > 0
	return 1.0 + (factor - 1.0) * ARMOUR_SHARE if armoured else factor

## Three-round pulse guns (Ratchet, Splinter, Reactor; MagazineTrial.WEAPON_PULSES 3)
## burn a magazine per one or two actions; with v2 enemy HP they emptied the
## 14-card deck and leaned on emergency resupply (v2 check: 12 / 9+ / 9 uses, and
## Splinter's final boss became unwinnable). They start with 6 more basics.
const PULSE_GUN_EXTRA := {"burst": [["basic_p2", 4], ["basic_p3", 2]], "scatter": [["basic_p2", 4], ["basic_p3", 2]], "heavy": [["basic_p2", 4], ["basic_p3", 2]], "rewinder":[["basic_p2",4],["basic_p3",2]], "deadbolt":[["basic_p2",4],["basic_p3",2]]}

static func start_deck(gun: String = "") -> Array:
	var result: Array = []
	for row in [["basic_p2", 8], ["basic_p3", 6]] + PULSE_GUN_EXTRA.get(gun, []):
		for unused in range(int(row[1])): result.append(row[0])
	result.sort()
	return result

## Rounds of the current magazine as loaded, minus ejected rounds. Fired rounds stay.
static func loaded(state: Dictionary) -> Array:
	return state.get("magazine_loaded", [])

static func on_load(state: Dictionary) -> void:
	if enabled(state): state.magazine_loaded = state.magazine.duplicate()

static func on_eject(state: Dictionary, removed: Array) -> void:
	if not enabled(state): return
	var rounds: Array = loaded(state).duplicate()
	for id in removed: rounds.erase(id)
	state.magazine_loaded = rounds

static func special_kinds(state: Dictionary) -> int:
	var kinds: Array = []
	for id in loaded(state):
		var family := Content.source_id(str(id))
		if family != "basic" and not kinds.has(family): kinds.append(family)
	return kinds.size()

static func is_special(id: String) -> bool:
	return Content.source_id(id) != "basic"

static func has_boost(state: Dictionary) -> bool:
	return loaded(state).any(func(id): return str(Content.AMMO.get(str(id), {}).get("effect", "")) == "boost")

static func has_ordinary_tactical(state: Dictionary) -> bool:
	return loaded(state).any(func(id): return Content.AMMO.has(str(id)) and Content.grade(str(id)) == 0)

# --- part conditions used by Model._shot -------------------------------------------

## Triad: 3+ special kinds in the magazine -> each special attack round +3.
static func triad_bonus(state: Dictionary, id: String) -> int:
	return TRIAD_BONUS if is_special(id) and Content.is_attack(id) and special_kinds(state) >= TRIAD_KINDS else 0

## Compression stabiliser: any ordinary tactical round in the magazine -> compressed rounds heat -2.
static func compression_ready(state: Dictionary, id: String) -> bool:
	return Content.is_compressed(id) and has_ordinary_tactical(state)

## Afterburner: a boost round in the magazine is enough; it no longer has to sit
## directly before the last single-hit attack.
static func afterburner_ready(state: Dictionary) -> bool:
	return has_boost(state)

# --- HUD readout -------------------------------------------------------------------

## What the current magazine forms, in firing order. At most three short items.
static func combos(state: Dictionary) -> PackedStringArray:
	var items: PackedStringArray = []
	var stack: Array = state.get("magazine", [])
	var parts: Array = Content.equipped_parts(state)
	var focus := int(state.get("focus_build_version",0)) == 1
	if focus:
		var fired := 0
		for i in range(state.get("history",[]).size()-1,-1,-1):
			var event: Dictionary = state.history[i]
			if event.get("action","") == "load": break
			if event.get("action","") == "fire": fired += event.get("detail",{}).get("results",[]).size()
		if parts.has("third_striker") and fired <= 2 and stack.size() > 2-fired:
			var third := str(stack[2-fired])
			items.append("3번째 %s ×3" % Content.AMMO[third].name if Content.is_attack(third) else "3번째 지원탄 · 강화 없음")
		if parts.has("opening") and fired == 0 and not stack.is_empty() and Content.is_attack(str(stack[0])): items.append("첫 발 ×2")
	for i in range(stack.size()):
		var id := str(stack[i])
		if str(Content.AMMO.get(id, {}).get("effect", "")) != "boost": continue
		for j in range(i + 1, stack.size()):
			if Content.is_attack(str(stack[j])):
				items.append("%s→%s" % [Content.AMMO[id].name, Content.AMMO[str(stack[j])].name])
				break
	if parts.has("triad") and special_kinds(state) >= TRIAD_KINDS: items.append("삼중 %d종 +%d" % [special_kinds(state), TRIAD_BONUS])
	if parts.has("afterburner") and afterburner_ready(state): items.append("후미: 강화 단타 ×3" if focus else "후미 결산 ×2")
	if parts.has("compression_sink") and stack.any(func(id): return compression_ready(state, str(id))): items.append("압축 발열 −%d" % COMPRESSION_SAVE)
	return items.slice(0, 3)

static func combo_line(state: Dictionary) -> String:
	var items := combos(state)
	return "연계  " + " · ".join(items) if not items.is_empty() else ""
