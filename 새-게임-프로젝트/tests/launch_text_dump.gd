extends SceneTree
## Launch text audit (2026-11-12): every player-facing sentence of a new run in one file, so
## wording can be read in one pass. QA_OUTPUT_DIR/text_dump.txt. Not a pass/fail check.
const Campaign = preload("res://redesign/campaign.gd")
const Content = preload("res://redesign/content.gd")
const CampaignContent = preload("res://redesign/campaign_content.gd")
const Readability = preload("res://redesign/readability.gd")
const PartChoice = preload("res://redesign/part_choice.gd")
const PartSlots = preload("res://redesign/part_slots.gd")
const PartTuning = preload("res://redesign/part_tuning.gd")
const TagBuild = preload("res://redesign/tag_build.gd")
const Discovery = preload("res://redesign/ammo_discovery.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/"): quit(2); return
	var lines: PackedStringArray = []
	var c = Campaign.new()
	c.start("single", 17, 0, "balanced", CampaignContent.RouteMap.VERSION, "carrier", true)
	var state: Dictionary = c.model.s
	lines.append("== 탄환 (새 등반, 리벳) ==")
	var seen: Array = []
	for id in Content.AMMO:
		var spec: Dictionary = Content.AMMO[id]
		if spec.get("temporary", false): continue
		var key := str(spec.name) + "|" + Readability._description(str(id), state)
		if seen.has(key): continue
		seen.append(key)
		var stat: Dictionary = Content.primary_stat(str(id), state)
		lines.append("[%s] %s · %s %s · 열 %s" % [id, spec.name, stat.label, stat.value, Content.heat_label(str(id), state)])
		lines.append("    " + Readability.description(str(id), state).replace("\n", "\n    "))
	lines.append("")
	lines.append("== 파츠 (새 등반 제시 대상) ==")
	# The same filters as campaign_content.gd::offers, per gun.
	var offered: Dictionary = {}
	for gun in Content.GUNS:
		var run = Campaign.new()
		run.start(str(gun), 17, 0, "balanced", CampaignContent.RouteMap.VERSION, "carrier", true)
		var gun_state: Dictionary = run.model.s
		var parts: Array = CampaignContent.eligible_parts(str(gun), int(run.s.get("discovery_version", 0)), int(run.s.get("focus_build_version", 0)))
		if not preload("res://redesign/build_engine.gd").enabled(gun_state): parts = parts.filter(func(id): return not preload("res://redesign/build_engine.gd").NEW_PARTS.has(id))
		parts = parts.filter(func(id): return TagBuild.offerable(gun_state, id) and PartTuning.offerable(gun_state, id))
		parts.erase(Content.innate_engine(gun_state))
		for id in parts:
			if not offered.has(id): offered[id] = []
			offered[id].append(str(Content.GUNS[gun].name))
	for id in Content.PARTS:
		if not offered.has(id): continue
		var spec: Dictionary = Content.part_spec(str(id), state)
		lines.append("[%s] %s · %s · %s  (%s)" % [id, spec.name, PartSlots.name_of(str(id)), str(spec.get("value", "")), "전 총기" if offered[id].size() == Content.GUNS.size() else "/".join(offered[id])])
		lines.append("    이점: %s" % str(spec.get("upside", "")))
		if not str(spec.get("downside", "")).is_empty(): lines.append("    대가: %s" % str(spec.downside))
		lines.append("    설명: %s" % str(spec.get("text", "")))
		lines.append("    보상 카드: %s" % PartChoice.effect(str(id), state))
	lines.append("")
	lines.append("== 총기 ==")
	for id in Content.GUNS:
		var gun: Dictionary = Content.GUNS[id]
		lines.append("[%s] %s · %s · %s" % [id, gun.name, gun.role, gun.identity])
	lines.append("")
	lines.append("== 복장 ==")
	for id in Content.OUTFITS:
		var outfit: Dictionary = Content.OUTFITS[id]
		lines.append("[%s] %s · %s · %s" % [id, outfit.name, str(outfit.get("role", "")), str(outfit.get("text", ""))])
	var output := OS.get_environment("QA_OUTPUT_DIR")
	FileAccess.open(output.path_join("text_dump.txt"), FileAccess.WRITE).store_string("\n".join(lines))
	print("TEXT DUMP lines=%d" % lines.size())
	quit(0)
