extends RefCounted
## Growth structure v2, first prototype (2026-11-10, user: "이대로 진행해 줘" on the
## from-scratch growth design, docs/direction/growth-structure.md). New runs only.
## 1. Special-first magazine: owned special rounds always fill the magazine before basic
##    rounds, so the deck no longer dilutes the build. Basics stay owned (carry, refit and
##    gate production keep working); they only fill the slots specials leave.
## 2. No forced early core: the first win skips the growth-core pick and goes straight to
##    the main-round package; cores lose the one-core limit and act as rare parts.
## 3. Ammo mastery (the 'planet card'): a gate option raises one family; every attack round
##    of that family gets +1 damage per hit per level (+2 for single-hit rounds).
## 4. Built-in drives: each gun carries a growth drive (content.gd GUN_ENGINES).
const Content = preload("res://redesign/content.gd")
const FocusBuild = preload("res://redesign/focus_build.gd")
const VERSION := 1
const MASTERY_LIMIT := 4

static func enabled(state: Dictionary) -> bool:
	return int(state.get("growth_structure_version", 0)) == VERSION

static func is_basic(id: String) -> bool:
	return Content.source_id(id) == "basic"

## Keep the shuffled order inside each group; specials first, then basics.
static func order_draw(state: Dictionary) -> void:
	var specials: Array = []
	var basics: Array = []
	for value in state.draw:
		if is_basic(str(value)): basics.append(value)
		else: specials.append(value)
	state.draw = specials + basics

## Where an unfired special goes back into the draw: after the other specials.
static func return_index(state: Dictionary) -> int:
	for index in range(state.draw.size()):
		if is_basic(str(state.draw[index])): return index
	return state.draw.size()

static func mastery_family(state: Dictionary) -> String:
	var main := FocusBuild.main_round(state)
	return Content.source_id(main) if not main.is_empty() else ""

static func mastery(state: Dictionary, family: String) -> int:
	return int(state.get("mastery", {}).get(family, 0))

static func can_master(state: Dictionary) -> bool:
	var family := mastery_family(state)
	return enabled(state) and not family.is_empty() and mastery(state, family) < MASTERY_LIMIT

## The support family the deck holds most of (support mastery, content.gd SUPPORT_MASTERY_STEPS).
static func support_family(state: Dictionary) -> String:
	var best := ""
	var most := 0
	for family in Content.SUPPORT_MASTERY_STEPS:
		var count: int = state.get("deck", []).filter(func(id): return Content.source_id(str(id)) == family).size()
		if count > most: best = family; most = count
	return best

static func can_master_support(state: Dictionary) -> bool:
	var family := support_family(state)
	return enabled(state) and not family.is_empty() and mastery(state, family) < MASTERY_LIMIT

static func support_name(state: Dictionary) -> String:
	var family := support_family(state)
	return str(Content.AMMO[family].name) if Content.AMMO.has(family) else "지원탄"

static func add_mastery(state: Dictionary, support: bool = false) -> bool:
	if not (can_master_support(state) if support else can_master(state)): return false
	var family := support_family(state) if support else mastery_family(state)
	if not state.has("mastery"): state.mastery = {}
	state.mastery[family] = mastery(state, family) + 1
	return true

## Flat damage per hit for attack rounds of a mastered family (before multipliers).
## Single-hit rounds get +2 per level, multi-hit rounds +1 per hit: in the climb comparison
## +1 for single-hit 철갑 made mastery much weaker for 리벳 than for 연타 (래칫).
static func mastery_bonus(state: Dictionary, id: String) -> int:
	if not enabled(state) or not Content.is_attack(id): return 0
	var level := mastery(state, Content.source_id(id))
	return level * (2 if Content.hit_count(id, state) <= 1 else 1)

static func family_name(state: Dictionary) -> String:
	var family := mastery_family(state)
	return str(Content.AMMO[family].name) if Content.AMMO.has(family) else "주력 탄"

static func valid(state: Dictionary) -> bool:
	var version = state.get("growth_structure_version", 0)
	if not (version is int or version is float) or int(version) != version or int(version) < 0 or int(version) > VERSION: return false
	if not state.has("mastery"): return true
	if int(version) == 0 or not state.mastery is Dictionary: return false
	for key in state.mastery:
		var value = state.mastery[key]
		if not Content.AMMO.has(str(key)) or str(key) == "basic": return false
		if not (value is int or value is float) or int(value) != value or int(value) < 0 or int(value) > MASTERY_LIMIT: return false
	return true
