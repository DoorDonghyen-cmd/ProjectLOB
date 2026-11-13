extends PanelContainer

signal new_run_requested
signal archive_requested
signal details_changed(open: bool)

const Ammo = preload("res://redesign/content.gd")
const Insight = preload("res://redesign/run_insight.gd")
const COMPLETE := Color("f6ddb4")
const FAILED := Color("e5a28d")

func _ready() -> void:
	%DetailsButton.pressed.connect(toggle_details)
	%NewRun.pressed.connect(new_run_requested.emit)
	%Archive.pressed.connect(archive_requested.emit)

func fit_available(extent: Vector2) -> void:
	var compact := extent.y < 700.0
	# 1440p phones are 1040x480 in game units (found 2026-11-12): the 500 floor pushed the
	# 새 도전 row under the screen edge. Short screens get tighter spacing and a smaller title.
	var short := extent.y < 520.0
	custom_minimum_size.y = maxf(454.0, extent.y)
	%Record.custom_minimum_size.x = 512 if compact else 562
	%Caption.offset_left = 28 if compact else 42
	%Caption.offset_top = -110 if compact else -154
	%Caption.offset_bottom = -10 if compact else -37
	%Record.add_theme_constant_override("margin_top", 8 if short else 16 if compact else 55)
	%Record.add_theme_constant_override("margin_bottom", 6 if short else 12 if compact else 27)
	%Record.add_theme_constant_override("margin_left", 30 if compact else 48)
	%Record.add_theme_constant_override("margin_right", 26 if compact else 42)
	%Stack.add_theme_constant_override("separation", 4 if short else 8 if compact else 18)
	%Outcome.add_theme_constant_override("separation", 2 if short else 6 if compact else 15)
	%ResultTitle.add_theme_font_size_override("font_size", 32 if short else 48 if compact else 64)
	%ActionNote.visible = not compact or not %ActionNote.text.is_empty()

func show_note(note: String) -> void:
	%ActionNote.text = note

func present(run, motion: float = 1.0, note: String = "") -> void:
	var won: bool = run.s.phase == "won"
	var state: Dictionary = run.model.s
	var accent := COMPLETE if won else FAILED
	%Stage.present(run, won, motion)
	%SceneLabel.text = "귀환 지점" if won else "마지막 전장"
	%SceneTitle.text = "우리 동네" if won else str(run.region_info().name)
	%SceneSub.text = "주거 구역" if won else "%d층  /  %s" % [int(run.s.floor), str(run.node().get("name", "전투 구역"))]
	%SceneLabel.add_theme_color_override("font_color", accent)
	%ResultTitle.text = "탑 돌파" if won else "돌파 실패"
	%ResultTitle.add_theme_color_override("font_color", accent)
	# Launch pass (2026-11-12): a defeat names its cause and one thing to try next.
	%ResultLine.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	%ResultLine.text = "기상 설비 재가동 · 현장 제어권 복구" if won else loss_line(state) + "\n" + loss_hint(state)
	%Achievement.text = "전투 %d회 통과" % int(run.s.clears)
	%Loadout.text = "%s  /  %s" % [str(Ammo.GUNS[run.s.gun].name), Ammo.outfit_name(state)]
	# Growth structure v2: the gun's built-in drive and what it grew to in this climb. Older
	# saves show the equipped core as before.
	var drive := str(Ammo.innate_engine(state))
	var core := drive
	if core.is_empty():
		for id in run.equipped_parts():
			if Ammo.is_core_part(str(id)):
				core = str(id)
				break
	%CoreIcon.visible = not core.is_empty()
	%CoreIcon.part_id = core
	%CoreIcon.queue_redraw()
	%CoreName.get_parent().get_node("CoreCaption").text = "내장 구동 · 이번 등반의 성장" if not drive.is_empty() else "장착 코어"
	%CoreName.text = "코어 미장착" if core.is_empty() else str(Ammo.part_spec(core, state).name)
	if not drive.is_empty():
		var grown := str(preload("res://redesign/damage_engines.gd").value(state, drive))
		if not grown.is_empty(): %CoreName.text = "%s  ·  %s" % [str(Ammo.part_spec(drive, state).name), grown]
	var peak := recorded_peak(state)
	var round_id := str(peak.get("id", ""))
	%RoundIcon.visible = Ammo.AMMO.has(round_id)
	%RoundIcon.ammo_id = round_id
	%RoundIcon.queue_redraw()
	%RoundName.text = str(Ammo.AMMO[round_id].name) if Ammo.AMMO.has(round_id) else "피해 기록 없음"
	%RoundDamage.text = "피해 %d" % int(peak.damage) if Ammo.AMMO.has(round_id) else ""
	var report := Insight.combat_report(state)
	# One line less than before, so the parts line below fits short phones without scrolling.
	%Travel.text = "방문  %d곳    ·    최고 열  %d    ·    과열  %d회" % [run.s.visited.size(), int(report.heat_peak), int(report.overheats)]
	%Actions.text = "적 행동  %d회    ·    사격  %d발    ·    탄창 교체  %d회" % [int(state.turns), int(state.shots), int(state.reloads)]
	%Heat.hide()
	%Deck.text = "최종 탄약  %d발" % state.deck.size()
	%DeckSummary.text = Insight.deck_summary(state.deck)
	var part_names: PackedStringArray = []
	for id in run.equipped_parts():
		if str(id) != drive: part_names.append(str(Ammo.part_spec(str(id), state).name))
	if not part_names.is_empty(): %DeckSummary.text += "\n파츠  ·  " + " · ".join(part_names)
	show_note(note)

## What ended the run, in one short line.
static func loss_line(state: Dictionary) -> String:
	return str(loss_cause(state)[0])

## One thing to try next, in one short line (each fits the record column on a phone).
static func loss_hint(state: Dictionary) -> String:
	return str(loss_cause(state)[1])

## [what happened, what to try], from how the last fight ended (magazine rules).
static func loss_cause(state: Dictionary) -> Array:
	match str(state.get("loss_reason", "")):
		"ammo": return ["쏠 탄약이 남지 않았습니다.", "빼내거나 교체한 탄은 그 전투에 돌아오지 않습니다."]
		"projectile": return ["적의 발사체가 닿았습니다.", "날아오는 탄은 다음 공격탄이 요격합니다."]
	var history: Array = state.get("history", [])
	for index in range(history.size() - 1, -1, -1):
		var event: Dictionary = history[index]
		var action := str(event.get("action", ""))
		if action == "fire" and not event.get("detail", {}).get("forced_cooling", {}).is_empty():
			return ["과열로 식히는 동안 적이 닿았습니다.", "한계에 닿기 전에 미리 냉각하세요."]
		if action == "reload": return ["탄창을 교체하는 동안 적이 닿았습니다.", "탄창 교체는 적 2행동 이상 걸립니다."]
		if action in ["fire", "cool"]: break
	return ["적이 사격선에 닿았습니다.", "가까운 적부터 쓰러뜨리세요. 충격탄은 밀어냅니다."]

static func recorded_peak(state: Dictionary) -> Dictionary:
	var highest := {"id": "", "damage": 0}
	for entry in state.get("history", []):
		if str(entry.get("action", "")) != "fire":
			continue
		for shot in entry.get("detail", {}).get("results", []):
			var id := str(shot.get("id", ""))
			var damage := int(shot.get("damage", 0))
			if Ammo.AMMO.has(id) and damage > int(highest.damage):
				highest = {"id": id, "damage": damage}
	return highest

func toggle_details() -> void:
	set_details(not details_open())

func details_open() -> bool:
	return %Details.visible

func set_details(open: bool) -> void:
	%Summary.visible = not open
	%Details.visible = open
	%DetailsButton.text = "기록 접기  −" if open else "상세 기록  +"
	details_changed.emit(open)
