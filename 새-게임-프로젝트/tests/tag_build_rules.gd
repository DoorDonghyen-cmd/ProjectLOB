extends SceneTree
## Tag-based rounds and parts prototype rules (2026-11-10). Shots run on the real Model
## against an earned region-3 combat (QA_BUILD_DIR) with dummy enemies.
const Campaign = preload("res://redesign/campaign.gd")
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const Data = preload("res://redesign/campaign_content.gd")
const Tags = preload("res://redesign/tag_build.gd")
var checks := 0
var failures: Array = []
var base_state: Dictionary

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures.append(label); print("FAIL: " + label)
	return ok

func dummy(parts: Array, tags := true) -> Model:
	var m := Model.new()
	m.s = Model.simulation_state(base_state)
	if tags: m.s.tag_build_version = Tags.VERSION
	else: m.s.erase("tag_build_version")
	m.s.equipped_parts = parts.duplicate()
	m.s.heat = 0; m.s.buff = {}
	m.s.erase("tag_growth")
	for e in m.s.enemies:
		e.hp = 999; e.max_hp = 999; e.def = 0; e.barrier = 0; e.slow_left = 0; e.jammed = 0; e.burn = 0
	return m

func hit(parts: Array, id: String, tags := true, setup: Callable = Callable()) -> int:
	var m := dummy(parts, tags)
	if setup.is_valid(): setup.call(m)
	return int(m._shot(id, 0, {}).damage)

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	var c = Campaign.new()
	check(c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("QA_BUILD_DIR").path_join("combat_heavy_17_r3_n20101.json")))), "earned combat restores")
	base_state = c.model.s
	# Tags.
	var s := base_state
	check(Tags.tags(s, "bore").has("화염") and Tags.tags(s, "bore").has("단타"), "소이: 화염·단타")
	check(Tags.tags(s, "precise").has("다회") and Tags.tags(s, "arc").has("전기") and Tags.tags(s, "chase").has("마무리"), "연타 다회, 전격 전기, 추격 마무리")
	check(Tags.tags(s, "charge").has("준비") and not Tags.tags(s, "charge").has("단타"), "지원탄은 형태 태그 없음")
	check(Tags.tags(s, "basic_p2").is_empty(), "기본탄은 태그 없음")
	# Card chips and round details (2026-11-11).
	var shown: Array = []
	for id in Content.AMMO:
		if Content.source_id(id) == "basic": continue
		var own := Tags.tags(s, id)
		check(own.size() <= 3 and not own.has("타격"), "at most 3 chips, no 타격: " + id)
		for tag in own:
			if not shown.has(tag): shown.append(tag)
	for tag in shown: check(Tags.SHORT.has(tag) and Tags.COLORS.has(tag), "chip syllable and colour for " + tag)
	var fire_state: Dictionary = dummy(["tag_fire_add", "tag_copy", "tag_low_mult"]).s
	var summary := Tags.round_summary(fire_state, "bore", fire_state.equipped_parts)
	check(summary.contains("태그 · 화염 · 단타") and summary.contains("화염 점화기 +2") and summary.contains("(복제)") and summary.contains("조건부 · 처형 회로 ×2(체력 절반 이하)"), "round details: tags, applied parts, copy and conditions")
	check(Tags.round_summary(fire_state, "pierce", fire_state.equipped_parts).contains("적용") == false, "철갑 details: 화염 parts not applied")
	check(Tags.round_summary(fire_state, "basic_p2", fire_state.equipped_parts).begins_with("태그 없음"), "기본탄 details say no tags")
	check(Tags.read_tags(fire_state, fire_state.equipped_parts) == ["화염"], "chips light 화염 for 화염 점화기")
	check(preload("res://redesign/readability.gd").description("bore", fire_state).begins_with("태그 · 화염"), "shared round text starts with the tags in tag runs")
	check(not preload("res://redesign/readability.gd").description("bore", dummy([], false).s).contains("태그 ·"), "normal runs show no tags")
	# Additive and multiplier parts act only on matching tags, only in tag runs.
	var bore := hit([], "bore")
	check(hit(["tag_fire_add"], "bore") == bore + 2, "화염 점화기: 화염 +2")
	check(hit(["tag_fire_add"], "pierce") == hit([], "pierce"), "화염 점화기는 철갑에 무효")
	check(hit(["tag_fire_add"], "bore", false) == hit([], "bore", false), "태그 시험판이 아니면 무효")
	var pierce := hit([], "pierce")
	check(hit(["tag_single_mult"], "pierce") == pierce * 3 / 2, "단타 배율기 ×1.5: %d → %d" % [pierce, hit(["tag_single_mult"], "pierce")])
	check(hit(["tag_low_mult"], "pierce", true, func(m): m.s.enemies[0].hp = 400) == pierce * 2, "처형 회로: 절반 이하 ×2")
	check(hit(["tag_low_mult"], "pierce") == pierce, "처형 회로: 체력이 많으면 무효")
	check(hit(["tag_control_mult"], "pierce", true, func(m): m.s.enemies[0].slow_left = 2) == pierce * 2, "경직 추격기: 감속된 적 ×2")
	# Deck composition and magazine variety.
	check(hit(["tag_fire_deck"], "bore", true, func(m): m.s.deck = ["bore", "bore", "bore", "bore", "bore", "bore"]) == bore * 3 / 2, "화염 탄약고: 화염 6장이면 ×1.5")
	check(hit(["tag_fire_deck"], "bore", true, func(m): m.s.deck = ["bore", "bore"]) == bore, "화염 탄약고: 부족하면 무효")
	check(hit(["tag_variety"], "pierce", true, func(m): m.s.magazine_loaded = ["bore", "precise", "arc", "chase"]) == pierce + 3, "혼합 탄띠: 태그 4종 이상 +3")
	# Copy: repeats the tag part on its left; order matters.
	check(hit(["tag_fire_add", "tag_copy"], "bore") == bore + 4, "복제 기판: 왼쪽 화염 점화기를 한 번 더")
	check(hit(["tag_copy", "tag_fire_add"], "bore") == bore + 2, "복제 기판이 왼쪽에 아무것도 없으면 무효")
	check(hit(["tag_fire_add", "supply", "tag_copy"], "bore") == hit(["supply"], "bore") + 4, "복제 기판은 사이의 일반 파츠를 건너뜀")
	check(hit(["tag_fire_add", "tag_single_add", "tag_copy"], "bore") == bore + 6, "복제 기판은 가장 가까운 태그 파츠(단타 조준경)를 복제")
	check(hit(["tag_single_mult", "tag_copy"], "pierce") == pierce * 9 / 4, "복제 기판: 배율도 한 번 더(×1.5×1.5)")
	# Readouts (11-11): the hit float names the tags; the drive multiplier stays the drive's.
	var Readout = preload("res://redesign/damage_readout.gd")
	var shot_fire: Dictionary = dummy(["tag_fire_add", "tag_copy"])._shot("bore", 0, {})
	var float_fire: Dictionary = Readout.entry(shot_fire)
	check(str(float_fire.label).begins_with("화염+4"), "hit float starts with 화염+4 (점화기 + 복제): " + str(float_fire.label))
	var shot_single: Dictionary = dummy(["tag_single_add", "tag_single_mult"])._shot("pierce", 0, {})
	var float_single: Dictionary = Readout.entry(shot_single)
	check(str(float_single.label).begins_with("단타+2×1.5") and not str(float_single.label).contains("화력"), "단타+2×1.5, no 화력 label from a tag multiplier: " + str(float_single.label))
	check(int(shot_single.math.tag_percent) == 150 and int(shot_single.engine_percent) == int(dummy([])._shot("pierce", 0, {}).engine_percent), "tag × recorded apart from the drive")
	check(str(float_single.ledger).contains("×1.5"), "calculation line shows the tag ×1.5: " + str(float_single.ledger))
	var plain_float: Dictionary = Readout.entry(dummy([])._shot("pierce", 0, {}))
	check(not str(plain_float.label).contains("단타+"), "no tag label without tag parts")
	# Card number: unconditional tag parts only.
	var card_state: Dictionary = dummy(["tag_single_add", "tag_single_mult", "tag_low_mult"]).s
	var card := Tags.card_bonus(card_state, "pierce", card_state.equipped_parts)
	check(int(card.add) == 2 and int(card.percent) == 150 and str(card.tag) == "단타", "card bonus: +2 ×1.5 from 단타, 처형 left out")
	check(int(Tags.card_bonus(card_state, "basic_p2", card_state.equipped_parts).add) == 0, "basic card unchanged")
	# Fire status parts (11-10): burn turns and burning targets.
	var burn_of := func(parts: Array) -> int:
		var m := dummy(parts)
		m._shot("bore", 0, {})
		return int(m.s.enemies[0].burn)
	var burn_plain: int = burn_of.call([])
	check(burn_of.call(["tag_fire_burn"]) == burn_plain + 1, "화염 연소기: 화상 +1턴 (%d)" % burn_plain)
	check(burn_of.call(["tag_fire_burn", "tag_copy"]) == mini(6, burn_plain + 2), "복제 기판: 화상도 한 번 더")
	var plain_burn := dummy(["tag_fire_burn"], false)
	plain_burn._shot("bore", 0, {})
	check(int(plain_burn.s.enemies[0].burn) == burn_plain, "화염 연소기는 태그 시험판에서만")
	check(Content.burn_amount("bore", dummy(["tag_fire_burn", "tag_copy", "tag_fire_burn"]).s) <= 6, "화상 최대 6턴")
	var burn_labels: Array = dummy(["tag_fire_burn"])._shot("bore", 0, {}).get("part_effects", []).map(func(effect): return str(effect.id))
	check(burn_labels.has("tag_fire_burn"), "화염 연소기 발동 표시")
	check(hit(["tag_burning_mult"], "pierce", true, func(m): m.s.enemies[0].burn = 2) == pierce * 2, "잔불 추격기: 화상 중인 적 ×2")
	check(hit(["tag_burning_mult"], "pierce") == pierce, "잔불 추격기: 화상 없으면 무효")
	# Growth: 화염 kills while equipped.
	var g := dummy(["tag_fire_growth"])
	for i in range(3):
		g.s.enemies[0].hp = 1
		g._shot("bore", 0, {})
	check(Tags.growth(g.s, "tag_fire_growth") == 3, "화염 기록기: 화염 처치 기록")
	g.s.enemies[0].hp = 999
	check(int(g._shot("bore", 0, {}).damage) == bore + 1, "3처치 → 화염 탄 +1")
	# Offers.
	var tag_state: Dictionary = Model.simulation_state(base_state)
	tag_state.tag_build_version = Tags.VERSION
	var plain_state: Dictionary = Model.simulation_state(base_state)
	plain_state.erase("tag_build_version")
	var tag_seen := 0
	var retired_seen := 0
	var leaked := 0
	for region in range(1, 5):
		for k in range(12):
			var node := {"id": region * 10000 + 400 + k, "region": region, "floor": 4, "elite": k % 3 == 0, "kind": "shop"}
			for offer in Data.offers(node, 731042 + k, 0, "heavy", [], [], [], [], 4, 1, tag_state):
				if offer.type != "part": continue
				if Tags.PARTS.has(offer.id): tag_seen += 1
				if Tags.RETIRED.has(offer.id): retired_seen += 1
			for offer in Data.offers(node, 731042 + k, 0, "heavy", [], [], [], [], 4, 1, plain_state):
				if offer.type == "part" and Tags.PARTS.has(offer.id): leaked += 1
	print("OFFERS tag parts %d, retired parts %d, tag parts in normal runs %d" % [tag_seen, retired_seen, leaked])
	check(tag_seen > 0 and retired_seen == 0 and leaked == 0, "tag runs offer tag parts and not the retired ones; normal runs never see tag parts")
	# Icons and text.
	for id in Tags.PARTS:
		check(Content.PARTS.has(id) and not str(Content.PARTS[id].text).is_empty(), "part entry " + id)
		check(preload("res://redesign/part_icon_art.gd").ALIASES.has(id), "icon for " + id)
	# Saves.
	var saved := Model.new(); saved.s = Model.simulation_state(base_state)
	saved.s.tag_build_version = Tags.VERSION; saved.s.tag_growth = {"tag_fire_growth": 4}
	var back := Model.new()
	check(back.restore_state(JSON.parse_string(saved.serialized_state())) and Tags.growth(back.s, "tag_fire_growth") == 4, "tag growth survives save and load")
	var broken: Dictionary = JSON.parse_string(saved.serialized_state())
	broken.tag_growth = {"tag_fire_add": 1}
	check(not Model.new().restore_state(broken), "growth only for growth parts")
	broken.tag_growth = {"tag_fire_growth": 2}; broken.tag_build_version = 0
	check(not Model.new().restore_state(broken), "tag growth needs the tag flag")
	print("TAG BUILD RULES checks=%d failures=%d" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
