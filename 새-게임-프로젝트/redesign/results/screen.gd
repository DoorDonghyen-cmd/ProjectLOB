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
	custom_minimum_size.y = maxf(500.0, extent.y)
	%Record.custom_minimum_size.x = 512 if compact else 562
	%Caption.offset_left = 28 if compact else 42
	%Caption.offset_top = -110 if compact else -154
	%Caption.offset_bottom = -10 if compact else -37
	%Record.add_theme_constant_override("margin_top", 16 if compact else 55)
	%Record.add_theme_constant_override("margin_bottom", 12 if compact else 27)
	%Record.add_theme_constant_override("margin_left", 30 if compact else 48)
	%Record.add_theme_constant_override("margin_right", 26 if compact else 42)
	%Stack.add_theme_constant_override("separation", 8 if compact else 18)
	%Outcome.add_theme_constant_override("separation", 6 if compact else 15)
	%ResultTitle.add_theme_font_size_override("font_size", 48 if compact else 64)
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
	%ResultLine.text = "기상 설비 재가동 · 현장 제어권 복구" if won else loss_line(state)
	%Achievement.text = "전투 %d회 통과" % int(run.s.clears)
	%Loadout.text = "%s  /  %s" % [str(Ammo.GUNS[run.s.gun].name), Ammo.outfit_name(state)]
	var core := ""
	for id in run.equipped_parts():
		if Ammo.is_core_part(str(id)):
			core = str(id)
			break
	%CoreIcon.visible = not core.is_empty()
	%CoreIcon.part_id = core
	%CoreIcon.queue_redraw()
	%CoreName.text = "코어 미장착" if core.is_empty() else str(Ammo.part_spec(core, state).name)
	var peak := recorded_peak(state)
	var round_id := str(peak.get("id", ""))
	%RoundIcon.visible = Ammo.AMMO.has(round_id)
	%RoundIcon.ammo_id = round_id
	%RoundIcon.queue_redraw()
	%RoundName.text = str(Ammo.AMMO[round_id].name) if Ammo.AMMO.has(round_id) else "피해 기록 없음"
	%RoundDamage.text = "피해 %d" % int(peak.damage) if Ammo.AMMO.has(round_id) else ""
	%Travel.text = "방문  %d곳" % run.s.visited.size()
	%Actions.text = "행동  %d턴    ·    사격  %d발    ·    재장전  %d회" % [int(state.turns), int(state.shots), int(state.reloads)]
	var report := Insight.combat_report(state)
	%Heat.text = "저장된 교전 기록  ·  최고 열 %d  /  과열 %d회" % [int(report.heat_peak), int(report.overheats)]
	%Deck.text = "최종 덱  %d발" % state.deck.size()
	%DeckSummary.text = Insight.deck_summary(state.deck)
	show_note(note)

static func loss_line(state: Dictionary) -> String:
	match str(state.get("loss_reason", "")):
		"ammo": return "사용할 탄약이 모두 소진됐습니다."
		"projectile": return "적의 발사체가 사격선에 닿았습니다."
		_: return "적이 사격선에 도달했습니다."

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
