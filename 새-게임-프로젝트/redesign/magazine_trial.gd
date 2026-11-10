extends RefCounted
## Opt-in magazine comparison, with an optional per-weapon cadence.
## Campaign creation never enables either comparison rule.
const VERSION := 1
const EXTRA_SLOTS := 3
const PULSE := 2

static func cooling_amount(reload_cooling: int) -> int:
	return maxi(1, ceili(reload_cooling * 0.75))

static func enabled(state: Dictionary) -> bool:
	return int(state.get("magazine_trial_version", 0)) == VERSION

## Keep the already shuffled reserve order. Incompatible anchors/large rounds
## wait in reserve; no reshuffle, deletion, duplicated card, or free reroll.
static func take(pool: Array, capacity_value: int, slot_cost: Callable, anchor: Callable) -> Dictionary:
	var selected: Array = []
	var remaining: Array = []
	var first := ""
	var last := ""
	var used := 0
	for value in pool:
		var id := str(value)
		var position: String = anchor.call(id)
		var cost: int = slot_cost.call(id)
		if used + cost > capacity_value or (position == "first" and not first.is_empty()) or (position == "last" and not last.is_empty()):
			remaining.append(id)
			continue
		used += cost
		if position == "first": first = id
		elif position == "last": last = id
		else: selected.append(id)
	if not first.is_empty(): selected.push_front(first)
	if not last.is_empty(): selected.append(last)
	return {"selected": selected, "remaining": remaining}

# Separate opt-in keeps the original Rivet comparison and existing saves intact.
const WEAPON_VERSION := 1
const WEAPON_PULSES := {"single":2, "burst":3, "scatter":3, "heavy":3, "amplifier":99, "rewinder":3, "deadbolt":3}

static func weapons_enabled(state: Dictionary) -> bool:
	return enabled(state) and int(state.get("weapon_magazine_version", 0)) == WEAPON_VERSION

static func pulse(state: Dictionary) -> int:
	var normal:=int(WEAPON_PULSES.get(state.get("gun", ""), PULSE)) if weapons_enabled(state) else PULSE
	return preload("res://redesign/fire_heat_trial.gd").cap(state,normal+preload("res://redesign/combat_roles.gd").pulse_bonus(state))

# Ejection counts cards, not occupied slots; only a fresh whole magazine resets it.
const EJECT_LIMIT := 2
