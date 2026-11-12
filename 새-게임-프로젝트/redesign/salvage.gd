extends RefCounted
## Salvaged rounds (2026-11-11, user: "탄환을 적과의 전투에서 파밍하는 방식은 어떤것 같아",
## "설계문서 및 시험판 진행해 줘"). Design: docs/direction/salvage.md.
## Each enemy kind drops the round that answers it (장갑벽 → 철갑탄 …). The enemy killed LAST
## in a fight decides the salvage card: it replaces one reward card, marked 회수, and the
## player still chooses. Elites drop the upgraded round as an extra card next to their parts.
## Bosses do not drop. New runs only (model.s.salvage_version).
const Content = preload("res://redesign/content.gd")
const VERSION := 1
## The round that answers each kind (content.gd ENEMY_RULES).
const ROUNDS := {
	"wall": "pierce",      # 높은 장갑 → 관통
	"evader": "arc",       # 전도 선체 → 전기
	# 운반 사족체 (runner) drops nothing: it is the fodder in nearly every fight and often the
	# last reinforcement, so it took 59% of salvage cards in the first climbs (11-11).
	"absorber": "precise", # 배리어 → 여러 번 타격
	"caster": "disrupt",   # 충전 → 차단
	"spitter": "bore",     # 압력두꺼비 → 화상
	"stance": "bypass",    # 교대 장갑 → 우회
}

static func enabled(state: Dictionary) -> bool:
	return int(state.get("salvage_version", 0)) == VERSION

static func round_for(kind: String) -> String:
	return str(ROUNDS.get(kind, ""))

## Index of the enemy that drops something and was killed last in this fight (shots,
## follow-up hits, burn ticks), or -1.
static func last_kill(state: Dictionary) -> int:
	var history: Array = state.get("history", [])
	for i in range(history.size() - 1, -1, -1):
		var event: Dictionary = history[i]
		if str(event.get("action", "")) == "encounter": break
		var detail: Dictionary = event.get("detail", {})
		var kills: Array = []
		for shot in detail.get("results", []):
			if not shot.get("intercept", false) and shot.has("target") and int(shot.get("hp", 1)) == 0 and not shot.has("wreckage_hit"): kills.append(int(shot.target))
			for follow in shot.get("secondary", []):
				if follow.has("target") and int(follow.get("hp", 1)) == 0 and not follow.get("intercept", false) and not follow.has("wreckage_hit"): kills.append(int(follow.target))
		var advance: Array = detail.get("advance_events", []) + detail.get("forced_cooling", {}).get("advance_events", [])
		for tick in advance:
			if str(tick.get("kind", "")) == "burn" and int(tick.get("hp", 1)) == 0: kills.append(int(tick.target))
		var enemies: Array = state.get("enemies", [])
		for k in range(kills.size() - 1, -1, -1):
			var index := int(kills[k])
			if index >= 0 and index < enemies.size() and int(enemies[index].get("hp", 1)) == 0 and not round_for(str(enemies[index].get("kind", ""))).is_empty(): return index
	return -1

## {id, kind, name} of the salvage card for the fight just won, or {} when there is none.
static func card(state: Dictionary, elite: bool, boss: bool) -> Dictionary:
	if not enabled(state) or boss: return {}
	var index := last_kill(state)
	if index < 0: return {}
	var enemy: Dictionary = state.enemies[index]
	var id := round_for(str(enemy.get("kind", "")))
	if id.is_empty() or not Content.AMMO.has(id): return {}
	if elite:
		var improved := preload("res://redesign/focus_build.gd").upgrade(id)
		if not improved.is_empty(): id = improved
	return {"id": id, "kind": str(enemy.get("kind", "")), "name": str(enemy.get("name", Content.ENEMY_NAMES.get(str(enemy.get("kind", "")), "")))}

static func valid(state: Dictionary) -> bool:
	var version = state.get("salvage_version", 0)
	return (version is int or version is float) and int(version) == version and int(version) >= 0 and int(version) <= VERSION
