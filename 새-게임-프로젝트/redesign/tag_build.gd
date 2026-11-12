extends RefCounted
## Tag-based rounds and parts, prototype (2026-11-10, user: "태그 기반 탄환 파츠 설계를 별도로
##진행해주고 두 가지 다 테스트"). Chosen per run in 등반 설정 (model.s.tag_build_version).
## Rounds carry tags; tag parts read tags instead of naming a round, so every new round
## combines with the existing parts. Design: docs/direction/tag-build.md.
## In a tag run the round-specific additive parts (RETIRED) leave the offer pools and the
## tag parts (PARTS) take their place. Positional, rule, drive and handling parts stay.
const Content = preload("res://redesign/content.gd")
const VERSION := 1

## Element and role per round family. Form (단타/다회) comes from the actual hit count.
const FAMILY_TAGS := {
	"precise": ["물리"], "pierce": ["물리"], "bypass": ["물리"], "sequence": ["물리"],
	"bore": ["화염"], "detonate": ["화염", "마무리"], "spread": ["화염", "준비"],
	"arc": ["전기", "광역"],
	"chase": ["물리", "마무리"], "push": ["물리", "제어"], "disrupt": ["제어"],
	"vent": ["열"], "cool": ["열"],
	"charge": ["준비"], "charge_hot": ["준비"], "charge_heat": ["준비"], "shatter": ["준비", "물리"], "prepare": ["준비"],
}
## Card chips (2026-11-11, user: "탄환 카드가 … 태그 효과를 잘 모르겠어"): one syllable and a
## colour per tag on the combat magazine card; the round details spell the tags out.
## 타격 was dropped the same day: no part read it and it only repeated "attack round".
const SHORT := {"화염": "화", "전기": "전", "물리": "물", "열": "열", "단타": "단", "다회": "다", "마무리": "마", "제어": "제", "준비": "준", "광역": "광"}
## Card numbers raised by tag parts (combat_hud_presenter.gd).
const BOOSTED := Color("8fe388")
const COLORS := {"화염": Color("e8743b"), "전기": Color("e9c84f"), "물리": Color("aab8bd"), "열": Color("e05a6a"), "단타": Color("f28fb8"), "다회": Color("7fb8ff"), "마무리": Color("d9675f"), "제어": Color("6fc7d8"), "준비": Color("8fcf78"), "광역": Color("b99be0")}
## Tag parts. kind: add (+ per hit), mult (% on the attack), deck (% when the deck holds
## enough of a tag), variety (+ per hit with many tags in the magazine), growth (kills of a
## tag grow + per hit), burn (+ burn turns from rounds with the tag; 11-10 fire parts), copy (repeats the nearest tag part on its left; plain parts between are skipped).
const PARTS := {
	"tag_fire_add": {"kind": "add", "tag": "화염", "value": 2},
	"tag_shock_add": {"kind": "add", "tag": "전기", "value": 2},
	"tag_multi_add": {"kind": "add", "tag": "다회", "value": 1},
	"tag_single_add": {"kind": "add", "tag": "단타", "value": 2},
	"tag_finisher_add": {"kind": "add", "tag": "마무리", "value": 3},
	"tag_single_mult": {"kind": "mult", "tag": "단타", "percent": 150},
	"tag_hot_mult": {"kind": "mult", "condition": "hot", "percent": 150},
	"tag_low_mult": {"kind": "mult", "condition": "low_hp", "percent": 200},
	"tag_control_mult": {"kind": "mult", "condition": "controlled", "percent": 200},
	# Fire status parts (2026-11-10, user "화염파츠 추가해 줘"): the reactor lost its burn support
	# (열축전 코일 burn +1, 점화 약실 +2 on burning) when those parts retire in tag runs.
	"tag_fire_burn": {"kind": "burn", "tag": "화염", "value": 1},
	"tag_burning_mult": {"kind": "mult", "condition": "burning", "percent": 200},
	"tag_fire_deck": {"kind": "deck", "tag": "화염", "count": 6, "percent": 150},
	"tag_variety": {"kind": "variety", "kinds": 4, "value": 3},
	"tag_fire_growth": {"kind": "growth", "tag": "화염", "step": 3, "limit": 6},
	"tag_copy": {"kind": "copy"},
}
## Round-specific additive parts replaced by tag parts in a tag run.
const RETIRED := ["lens", "coil", "capacitor", "rammer", "sequencer", "igniter", "breaker", "executioner", "ordinary_chain", "triad", "indexer"]

static func enabled(state: Dictionary) -> bool:
	return int(state.get("tag_build_version", 0)) == VERSION

static func tags(state: Dictionary, id: String) -> Array:
	var family := Content.source_id(id)
	if family == "basic": return []
	var result: Array = FAMILY_TAGS.get(family, []).duplicate()
	if Content.is_attack(id): result.append("다회" if Content.hit_count(id, state) > 1 else "단타")
	return result

static func has_tag(state: Dictionary, id: String, tag: String) -> bool:
	return tags(state, id).has(tag)

static func deck_count(state: Dictionary, tag: String) -> int:
	return state.get("deck", []).filter(func(value): return has_tag(state, str(value), tag)).size()

static func magazine_tags(state: Dictionary) -> int:
	var seen: Array = []
	for value in state.get("magazine_loaded", state.get("magazine", [])):
		for tag in tags(state, str(value)):
			if not seen.has(tag): seen.append(tag)
	return seen.size()

static func growth(state: Dictionary, part: String) -> int:
	return int(state.get("tag_growth", {}).get(part, 0))

## Tag parts in slot order, each copy replaced by the nearest tag part on its left (if any).
## Plain parts between do not break it: equipping a copy last copies the latest tag part.
static func effective(state: Dictionary, parts: Array) -> Array:
	var result: Array = []
	var previous := ""
	for value in parts:
		var id := str(value)
		if not PARTS.has(id): continue
		if str(PARTS[id].kind) == "copy":
			if not previous.is_empty(): result.append({"id": previous, "via": id})
		else:
			result.append({"id": id, "via": id})
			previous = id
	return result

## {add, percent, labels} for one attack shot on enemy e.
static func shot(state: Dictionary, id: String, parts: Array, enemy: Dictionary, heat_before: int, hot_threshold: int) -> Dictionary:
	var out := {"add": 0, "percent": 100, "labels": []}
	if not enabled(state) or not Content.is_attack(id) or Content.source_id(id) == "basic": return out
	for item in effective(state, parts):
		var spec: Dictionary = PARTS[item.id]
		var applied := false
		match str(spec.kind):
			"add":
				if has_tag(state, id, str(spec.tag)): out.add += int(spec.value); applied = true
			"mult":
				var ok := false
				if spec.has("tag"): ok = has_tag(state, id, str(spec.tag))
				elif spec.condition == "hot": ok = heat_before >= hot_threshold
				elif spec.condition == "low_hp": ok = int(enemy.get("hp", 0)) * 2 <= int(enemy.get("max_hp", 0))
				elif spec.condition == "controlled": ok = int(enemy.get("slow_left", 0)) > 0 or int(enemy.get("jammed", 0)) > 0
				elif spec.condition == "burning": ok = int(enemy.get("burn", 0)) > 0
				if ok: out.percent = out.percent * int(spec.percent) / 100; applied = true
			"deck":
				if has_tag(state, id, str(spec.tag)) and deck_count(state, str(spec.tag)) >= int(spec.count): out.percent = out.percent * int(spec.percent) / 100; applied = true
			"burn":
				# Burn turns are added in Content.burn_amount; here only the activation is shown.
				applied = has_tag(state, id, str(spec.tag)) and str(Content.AMMO[id].effect) == "burn"
			"variety":
				if magazine_tags(state) >= int(spec.kinds): out.add += int(spec.value); applied = true
			"growth":
				var bonus := mini(int(spec.limit), growth(state, item.id) / int(spec.step))
				if bonus > 0 and has_tag(state, id, str(spec.tag)): out.add += bonus; applied = true
		if applied: out.labels.append({"id": item.via, "source": item.id, "label": label(item.id) + (" (복제)" if item.via != item.id else "")})
	return out

## Tags that equipped tag parts read (copies included).
static func read_tags(state: Dictionary, parts: Array) -> Array:
	var result: Array = []
	if not enabled(state): return result
	for item in effective(state, parts):
		var spec: Dictionary = PARTS[item.id]
		if spec.has("tag") and not result.has(str(spec.tag)): result.append(str(spec.tag))
	return result

## Plain-words explanation for round details (reward, shop, depot, bag, combat).
static func round_summary(state: Dictionary, id: String, parts: Array) -> String:
	var own := tags(state, id)
	if own.is_empty(): return "태그 없음 · 기본탄에는 태그 파츠가 붙지 않습니다."
	var text := "태그 · " + " · ".join(own)
	if not Content.is_attack(id): return text + "\n지원탄 · 태그 파츠 효과는 받지 않고 덱 구성·탄창 태그 수에만 셉니다."
	var now: PackedStringArray = []
	var conditional: PackedStringArray = []
	for item in effective(state, parts):
		var spec: Dictionary = PARTS[item.id]
		var name := str(Content.PARTS[item.via].name) + (" (복제)" if item.via != item.id else "")
		match str(spec.kind):
			"add":
				if has_tag(state, id, str(spec.tag)): now.append("%s +%d" % [name, int(spec.value)])
			"mult":
				if spec.has("tag"):
					if has_tag(state, id, str(spec.tag)): now.append(name + " " + label(item.id))
				else: conditional.append("%s %s(%s)" % [name, label(item.id), {"hot": "고열", "low_hp": "체력 절반 이하", "controlled": "감속·차단된 적", "burning": "화상 중인 적"}[str(spec.condition)]])
			"deck":
				if has_tag(state, id, str(spec.tag)):
					var count := deck_count(state, str(spec.tag))
					if count >= int(spec.count): now.append(name + " " + label(item.id))
					else: conditional.append("%s %s(덱 %s %d/%d장)" % [name, label(item.id), spec.tag, count, int(spec.count)])
			"variety":
				var kinds := magazine_tags(state)
				if kinds >= int(spec.kinds): now.append("%s +%d" % [name, int(spec.value)])
				else: conditional.append("%s +%d(탄창 태그 %d/%d종)" % [name, int(spec.value), kinds, int(spec.kinds)])
			"growth":
				if has_tag(state, id, str(spec.tag)): now.append("%s +%d(처치 %d)" % [name, mini(int(spec.limit), growth(state, item.id) / int(spec.step)), growth(state, item.id)])
			"burn":
				if has_tag(state, id, str(spec.tag)) and str(Content.AMMO[id].effect) == "burn": now.append("%s 화상 +%d턴" % [name, int(spec.value)])
	if not now.is_empty(): text += "\n적용 · " + " / ".join(now)
	if not conditional.is_empty(): text += "\n조건부 · " + " / ".join(conditional)
	if now.is_empty() and conditional.is_empty(): text += "\n이 태그를 읽는 장착 파츠가 없습니다."
	return text

## Hit float label (2026-11-11, user: "태그 식별이 어렵고 효과가 있는지 잘 모르겠어"): the tag
## parts that acted on this shot, by tag, e.g. "화염+2 · 단타×1.5". Copies are summed into their tag.
static func hit_label(effects: Array) -> Dictionary:
	var order: Array = []
	var adds := {}
	var mults := {}
	for effect in effects:
		var part := str(effect.get("source", effect.get("id", "")))
		if not PARTS.has(part): continue
		var spec: Dictionary = PARTS[part]
		var key := str(spec.get("tag", {"hot": "고열", "low_hp": "처형", "controlled": "제어", "burning": "화상"}.get(str(spec.get("condition", "")), "혼합" if str(spec.kind) == "variety" else "")))
		if key.is_empty(): continue
		if not order.has(key): order.append(key)
		match str(spec.kind):
			"add", "variety": adds[key] = int(adds.get(key, 0)) + int(spec.value)
			"mult", "deck": mults[key] = int(mults.get(key, 100)) * int(spec.percent) / 100
			"burn": adds[key + "_burn"] = int(adds.get(key + "_burn", 0)) + int(spec.value)
	var parts: PackedStringArray = []
	for key in order:
		var text := str(key)
		if adds.has(key): text += "+%d" % int(adds[key])
		if mults.has(key): text += "×" + ("%.2f" % (int(mults[key]) / 100.0)).rstrip("0").rstrip(".")
		if adds.has(key + "_burn"): text += " 화상+%d" % int(adds[key + "_burn"])
		if text != str(key): parts.append(text)
	var first := str(order[0]) if not order.is_empty() else ""
	return {"text": " · ".join(parts), "color": COLORS.get(first, Color("f1cf8a"))}

## Card number (2026-11-11): the per-hit damage with the tag parts that need nothing from the
## target (tag +, tag ×, deck, magazine variety, growth). Conditional ones (고열·처형·제어·화상)
## are left to the round details. {add, percent, tag} — tag is the first tag that was boosted.
static func card_bonus(state: Dictionary, id: String, parts: Array) -> Dictionary:
	var out := {"add": 0, "percent": 100, "tag": ""}
	if not enabled(state) or not Content.is_attack(id) or Content.source_id(id) == "basic": return out
	for item in effective(state, parts):
		var spec: Dictionary = PARTS[item.id]
		var hit := ""
		match str(spec.kind):
			"add":
				if has_tag(state, id, str(spec.tag)): out.add += int(spec.value); hit = str(spec.tag)
			"mult":
				if spec.has("tag") and has_tag(state, id, str(spec.tag)): out.percent = out.percent * int(spec.percent) / 100; hit = str(spec.tag)
			"deck":
				if has_tag(state, id, str(spec.tag)) and deck_count(state, str(spec.tag)) >= int(spec.count): out.percent = out.percent * int(spec.percent) / 100; hit = str(spec.tag)
			"variety":
				if magazine_tags(state) >= int(spec.kinds): out.add += int(spec.value); hit = "혼합"
			"growth":
				var bonus := mini(int(spec.limit), growth(state, item.id) / int(spec.step))
				if bonus > 0 and has_tag(state, id, str(spec.tag)): out.add += bonus; hit = str(spec.tag)
		if not hit.is_empty() and str(out.tag).is_empty(): out.tag = hit
	return out

static func label(part: String) -> String:
	var spec: Dictionary = PARTS[part]
	match str(spec.kind):
		"add", "variety": return "+%d" % int(spec.value)
		"mult", "deck": return "×%s" % ("%.2f" % (int(spec.percent) / 100.0)).rstrip("0").rstrip(".")
		"growth": return "기록"
		"burn": return "화상 +%d" % int(spec.value)
	return ""

## Extra burn turns for a burning round of the tag (copies included). Used by Content.burn_amount.
static func burn_bonus(state: Dictionary, parts: Array) -> int:
	if not enabled(state): return 0
	var total := 0
	for item in effective(state, parts):
		if str(PARTS[item.id].kind) == "burn": total += int(PARTS[item.id].value)
	return total

static func record_kill(state: Dictionary, id: String, parts: Array) -> void:
	if not enabled(state): return
	for value in parts:
		var part := str(value)
		if PARTS.has(part) and str(PARTS[part].kind) == "growth" and has_tag(state, id, str(PARTS[part].tag)):
			if not state.has("tag_growth"): state.tag_growth = {}
			state.tag_growth[part] = mini(int(PARTS[part].step) * int(PARTS[part].limit), growth(state, part) + 1)

static func offerable(state: Dictionary, part: String) -> bool:
	if PARTS.has(part): return enabled(state)
	return not (enabled(state) and RETIRED.has(part))

static func valid(state: Dictionary) -> bool:
	var version = state.get("tag_build_version", 0)
	if not (version is int or version is float) or int(version) != version or int(version) < 0 or int(version) > VERSION: return false
	if not state.has("tag_growth"): return true
	if int(version) == 0 or not state.tag_growth is Dictionary: return false
	for key in state.tag_growth:
		if not PARTS.has(str(key)) or str(PARTS[key].kind) != "growth": return false
		var value = state.tag_growth[key]
		if not (value is int or value is float) or int(value) != value or int(value) < 0 or int(value) > 18: return false
	return true
