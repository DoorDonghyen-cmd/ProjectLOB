extends RefCounted
## 교차 사격 (2026-11-11, user: "다음 단계 진행해 줘" after mixed rewards; earlier "숫자를 키워야
## 잡는 체감은 좋은 것 같아", "숫자 플로팅이 연달아 탁탁 뜨는 느낌도 좋고"). A reason to mix
## rounds that grows numbers instead of blocking them: within one magazine, an attack round of
## a different family than the previous attack round gets +1 per hit, +1 more for each switch
## in a row (max +3). Same family again resets; basic and support rounds neither count nor
## reset. A one-round deck gets nothing. New runs only (model.s.mix_combo_version).
const Content = preload("res://redesign/content.gd")
const VERSION := 1
const LIMIT := 3

static func enabled(state: Dictionary) -> bool:
	return int(state.get("mix_combo_version", 0)) == VERSION

static func _counts(family: String) -> bool:
	return family != "basic" and Content.AMMO.has(family) and Content.is_attack(family)

## Switch level after a sequence of fired round families (since the magazine was loaded).
static func level(families: Array, state: Dictionary = {}) -> int:
	var current := 0
	var last := ""
	var revision := preload("res://redesign/ammo_revision.gd")
	for value in families:
		var family := str(value)
		if not _counts(family): continue
		# 연계탄 (ammo_revision.gd): raises the step by +2 instead of counting as one switch.
		if family == "sequence" and revision.enabled(state): current = mini(LIMIT, current + revision.SEQUENCE_STEP)
		elif last.is_empty() or family == last: current = 0
		else: current = mini(LIMIT, current + 1)
		last = family
	return current

## Per-hit bonus for firing id after the rounds already fired from this magazine.
static func bonus(state: Dictionary, id: String, fired_families: Array) -> int:
	if not enabled(state): return 0
	var family := Content.source_id(id)
	if not _counts(family): return 0
	# 연계탄 gets the step it finds, then raises it for the rounds after it.
	if family == "sequence" and preload("res://redesign/ammo_revision.gd").enabled(state): return level(fired_families, state) if not fired_families.is_empty() else 0
	return level(fired_families + [family], state)

static func valid(state: Dictionary) -> bool:
	var version = state.get("mix_combo_version", 0)
	return (version is int or version is float) and int(version) == version and int(version) >= 0 and int(version) <= VERSION
