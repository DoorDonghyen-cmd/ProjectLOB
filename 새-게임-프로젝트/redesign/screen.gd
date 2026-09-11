extends Control
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const BattleView = preload("res://redesign/battle_view.gd")
const MagazineView = preload("res://redesign/magazine_view.gd")
const AmmoVisual = preload("res://redesign/ammo_visual.gd")
const SAVE := "user://core_redesign_run.json"
const BG := Color("101920")
const PANEL := Color("1b2a34")
const INK := Color("e7e4d9")
const MUTED := Color("a4b4ba")
const ACCENT := Color("a9dfbf")
const DANGER := Color("f2a38d")
var model = Model.new()
var page := "menu"
var save_enabled := true
var debug_session := false
var body: VBoxContainer
var seed_input: LineEdit
var save_error := ""
var busy := false
var presentation_speed := 1.0
var battle_view: Control
var magazine_view: Control
var preview_label: Label
var last_presentation: Dictionary = {}

func _ready() -> void:
	RenderingServer.set_default_clear_color(BG)
	var ui_theme := Theme.new()
	ui_theme.default_font = preload("res://assets/fonts/NeoDunggeunmoPro-Regular.ttf")
	ui_theme.default_font_size = 20
	ui_theme.set_color("font_color", "Label", INK)
	ui_theme.set_color("font_color", "Button", INK)
	ui_theme.set_color("font_disabled_color", "Button", Color("a0b1ba"))
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := _style(PANEL if state == "normal" else Color("28404b"))
		box.border_color = ACCENT if state in ["hover", "focus"] else Color("38515d")
		box.set_border_width_all(1)
		ui_theme.set_stylebox(state, "Button", box)
	theme = ui_theme
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	scroll.add_child(margin)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	margin.add_child(body)
	redraw()

func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(5)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

func _label(parent: Node, value: String, font_size: int = 20, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _row(parent: Node) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	return row

func _panel(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(PANEL))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	return column

func _button(parent: Node, title: String, key: String, callback: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.name = key
	button.text = title
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size.y = 46
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = disabled or busy
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func redraw() -> void:
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	if page == "menu":
		_menu()
		return
	var top := _row(body)
	_label(top, "LAST ON BOARD   /   %02d · 07" % (int(model.s.floor) + 1), 26, ACCENT)
	for item in [["규칙", "rules", _rules], ["메뉴", "menu", _to_menu]]:
		var button := _button(top, item[0], item[1], item[2])
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		button.custom_minimum_size.x = 84
	var skip := _button(top, "연출 생략", "skip_animation", _skip_animation, true)
	skip.custom_minimum_size.x = 135
	skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	_label(body, "%s   |   시드 %s   |   %s   |   %d턴" % [Content.GUNS[model.s.gun].name, str(model.s.seed), Content.PARTS[model.s.part].name, model.s.turns], 18, MUTED)
	if debug_session:
		_label(body, "개발자 연습 · 진행 저장 안 함", 18, DANGER)
	if not save_error.is_empty():
		_label(body, save_error, 18, DANGER)
	match model.s.phase:
		"plan", "ready": _combat()
		"reward": _reward()
		"won", "lost": _ending()

func _menu() -> void:
	_label(body, "LAST\nON BOARD", 76, ACCENT)
	_label(body, "인간에게 남은 것은, 빌린 총의 순서를 정하는 일뿐이다.", 24)
	_label(body, "7개 교전 · 공개 정보 전투 · 마지막에 넣은 탄이 먼저 발사됩니다.", 20, MUTED)
	var intro := _panel(body)
	_label(intro, "순서를 설계하고, 그 결과를 감당한다.", 26)
	_label(intro, "적의 거리·장갑·회피를 보고 탄환을 고르세요. 장전 계획은 무료로 취소할 수 있습니다. 확정한 뒤에는 발사하거나 시간을 써서 다시 장전합니다.")
	var row := _row(body)
	for id in ["single", "burst"]:
		var column := _panel(row)
		_label(column, Content.GUNS[id].name, 28)
		_label(column, Content.GUNS[id].text, 20, MUTED)
		_button(column, "이 총으로 시작", "start_" + id, _start.bind(id, false))
	var controls := _row(body)
	var seed_label := _label(controls, "시드", 20, MUTED)
	seed_label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	seed_label.custom_minimum_size.x = 48
	seed_input = LineEdit.new()
	seed_input.name = "Seed"
	seed_input.text = str(int(Time.get_unix_time_from_system()) % 1000000)
	seed_input.custom_minimum_size = Vector2(180, 46)
	controls.add_child(seed_input)
	var probe = Model.new()
	var can_resume: bool = probe.restore_run(SAVE)
	if FileAccess.file_exists(SAVE) and not can_resume:
		_label(body, "자동 저장을 읽을 수 없습니다. 기존 파일은 보존되며, 새 런을 시작하면 교체됩니다.", 17, DANGER)
	_button(controls, "이어 하기", "resume", _resume, not can_resume)
	_button(controls, "규칙 읽기", "rules", _rules)
	_button(controls, "개발자 테스트", "dev", _developer)
	_label(body, "새 런을 시작하면 이 실험 버전의 자동 저장이 교체됩니다. 기존 게임의 진행도는 별도로 보관됩니다.", 17, MUTED)

func _start(id: String, same_seed: bool) -> void:
	if busy: return
	var run_seed: int = int(model.s.seed) if same_seed else int(seed_input.text)
	debug_session = debug_session and same_seed
	model.start(id, run_seed)
	page = "run"
	_changed()

func _resume() -> void:
	if busy: return
	if model.restore_run(SAVE):
		debug_session = false
		page = "run"
		redraw()

func _to_menu() -> void:
	if busy: return
	page = "menu"
	redraw()

func _combat() -> void:
	var encounter: Dictionary = Content.ENCOUNTERS[int(model.s.floor)]
	_label(body, str(encounter.name) + "   ·   " + str(encounter.text), 19, MUTED)
	battle_view = BattleView.new()
	battle_view.name = "BattleView"
	body.add_child(battle_view)
	battle_view.sync(model.s)
	battle_view.shot_started.connect(_visual_shot)
	var workbench := _row(body)
	var candidates := _panel(workbench)
	candidates.get_parent().size_flags_stretch_ratio = 1.45
	_label(candidates, "탄환을 눌러 장전", 22, ACCENT)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	candidates.add_child(grid)
	var ids: Array = ["basic"]
	for id in model.s.hand:
		if not ids.has(id):
			ids.append(id)
	for id in ids:
		var spec: Dictionary = Content.AMMO[id]
		var count: int = model.available(id)
		var hint: String = AmmoVisual.HINT[id] if id != "basic" else "재장전 시 %d발" % model.supply_capacity()
		var text := "%s ×%d\n피해%d 관통%d 명중%d\n%s" % [spec.name, count, int(spec.dmg) + int(Content.GUNS[model.s.gun].bonus), spec.pen, int(spec.acc) + (2 if model.s.part == "lens" else 0), hint]
		var button := _button(grid, text, "load_" + id, _load.bind(id), model.s.phase != "plan" or count <= 0 or model.s.plan.size() >= model.capacity())
		button.add_theme_font_size_override("font_size", 16)
		button.tooltip_text = str(spec.text) if id != "basic" else hint
		button.custom_minimum_size.y = 100
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
			style.content_margin_left = 36
			style.content_margin_right = 6
			button.add_theme_stylebox_override(state, style)
		var icon := AmmoVisual.new()
		icon.ammo_id = id
		icon.position = Vector2(2, 18)
		icon.size = Vector2(32, 50)
		button.add_child(icon)
	_label(candidates, "다음 보충: %s\n남은 덱 %d · 사용탄 %d · 전체 %d장" % [_ammo_names(model.s.draw.slice(0, 2)) if not model.s.draw.is_empty() else "사용탄 셔플", model.s.draw.size(), model.s.discard.size(), model.s.deck.size()], 16, MUTED)
	var queue := _panel(workbench)
	_label(queue, "← 먼저 발사   /   탄창 4칸", 22, ACCENT)
	var stack: Array = model.s.plan if model.s.phase == "plan" else model.s.magazine
	magazine_view = MagazineView.new()
	magazine_view.name = "MagazineView"
	magazine_view.stack = stack.duplicate()
	magazine_view.confirmed = model.s.phase == "ready"
	queue.add_child(magazine_view)
	if model.s.phase == "plan":
		_button(queue, "최근 장전 취소 · 무료", "undo", _undo, stack.is_empty())
	var preview: Dictionary = model.preview()
	preview_label = _label(queue, str(preview.get("text", "마지막에 넣은 탄이 1번으로 들어옵니다.\n준비탄 → 다음 탄으로 효과가 이어집니다.")), 17, ACCENT if int(preview.get("damage", 0)) > 0 else MUTED)
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	queue.add_child(actions)
	if model.s.phase == "plan":
		_button(actions, "장전 확정 · 시간 0", "confirm", _confirm, stack.is_empty())
	else:
		_button(actions, "발사 · %s · 1턴" % ("전탄" if model.s.gun == "burst" else "한 발"), "fire", _fire, stack.is_empty())
		var projected: Array = model.movement_preview(model.reload_cost())
		var lethal := false
		for i in range(projected.size()):
			if model.s.enemies[i].hp > 0 and projected[i] <= 0:
				lethal = true
		_button(actions, "다시 장전 · %d턴%s" % [model.reload_cost(), " · 0m 도달 위험" if lethal else ""], "reload", _reload)
	# The battlefield carries immediate feedback; the full result remains accessible.
	var feedback := _label(body, str(model.s.message), 16, MUTED)
	feedback.max_lines_visible = 1
	feedback.tooltip_text = str(model.s.message)

func _reward() -> void:
	_label(body, "통과했습니다. 무엇을 가져갈까요?", 34, ACCENT)
	_label(body, str(model.s.message), 18, MUTED)
	var next: Dictionary = Content.ENCOUNTERS[int(model.s.floor) + 1]
	var peek := _panel(body)
	_label(peek, "다음 교전  /  " + str(next.name), 24)
	for e in Content.enemies_for(int(model.s.floor) + 1):
		_label(peek, "%s · HP %d / 장갑 %d / 회피 %d / 속도 %d / 거리 %dm" % [e.name, e.hp, e.def, e.eva, e.speed, e.distance], 18, MUTED)
	_label(body, "현재 덱: " + _ammo_names(model.s.deck), 19)
	_label(body, "현재 파츠: %s · %s" % [Content.PARTS[model.s.part].name, Content.PARTS[model.s.part].text], 18, MUTED)
	var row := _row(body)
	for id in model.reward_options():
		var is_ammo: bool = Content.AMMO.has(id)
		var spec: Dictionary = Content.AMMO[id] if is_ammo else Content.PARTS[id]
		var card := _panel(row)
		_label(card, spec.name, 25, ACCENT)
		_label(card, spec.text, 19)
		if is_ammo:
			_label(card, "기본 피해 %d / 관통 %d / 명중 %d" % [spec.dmg, spec.pen, spec.acc], 18, MUTED)
			_label(card, "현재 총기: 피해 %d / 관통 %d / 명중 %d" % [int(spec.dmg) + int(Content.GUNS[model.s.gun].bonus), spec.pen, int(spec.acc) + (2 if model.s.part == "lens" else 0)], 18, ACCENT)
		_button(card, "덱에 1장 추가" if is_ammo else "파츠 장착 · 기존 파츠 교체", "reward_" + id, _choose.bind(id, ""), is_ammo and model.s.deck.size() >= 10)
	var refine := _panel(body)
	_label(refine, "덱을 늘리지 않는 선택", 23)
	_button(refine, "지금 구성을 유지하고 계속", "reward_skip", _choose.bind("skip", ""))
	var remove_row := _row(refine)
	var ids: Array = []
	for id in model.s.deck:
		if ids.has(id):
			continue
		ids.append(id)
		_button(remove_row, "%s\n1장 제거" % Content.AMMO[id].name, "remove_" + id, _choose.bind("remove", id), model.s.deck.size() <= 4).add_theme_font_size_override("font_size", 16)
	_label(refine, "정제는 보상 하나를 대신 사용합니다. 최소 4장을 유지하며, 다음 교전부터 반영됩니다.", 17, MUTED)

func _ending() -> void:
	var won: bool = model.s.phase == "won"
	_label(body, "당신은 아직 인간이다." if won else "계산은 여기서 멈췄다.", 46, ACCENT if won else DANGER)
	_label(body, "정점은 개조를 권한다. 당신은 거부하고, 그 자리에 선다." if won else str(model.s.message), 24)
	_label(body, "%d / 7 교전 통과 · %d턴 · %d발 · 재장전 %d회" % [7 if won else int(model.s.floor), model.s.turns, model.s.shots, model.s.reloads], 22, MUTED)
	_label(body, "최종 덱: " + _ammo_names(model.s.deck), 20)
	var row := _row(body)
	_button(row, "같은 시드로 다시 설계", "retry", _start.bind(str(model.s.gun), true))
	_button(row, "총기 / 새 시드 선택", "new_run", _to_menu)

func _ammo_names(ids: Array) -> String:
	var names: PackedStringArray = []
	for id in ids:
		names.append(Content.AMMO[id].name)
	return " · ".join(names) if not names.is_empty() else "없음"

func _persist() -> void:
	if save_enabled and not debug_session:
		var error: Error = model.save_run(SAVE)
		save_error = "자동 저장 실패 (%d) · 게임을 종료하지 말아 주세요." % error if error != OK else ""

func _changed() -> void:
	_persist()
	redraw.call_deferred()

func _load(id: String) -> void:
	if busy: return
	var source := find_child("load_" + id, true, false) as Button
	var from: Vector2 = source.get_global_rect().get_center() if source else Vector2(300, 500)
	if model.load_round(id):
		busy = true
		_persist()
		redraw()
		await get_tree().process_frame
		await magazine_view.arrive(id, from, 0.23 * presentation_speed)
		busy = false
		redraw()

func _undo() -> void:
	if busy: return
	if model.undo(): _changed()

func _confirm() -> void:
	if busy: return
	if model.confirm(): _changed()

func _fire() -> void:
	if busy: return
	var before: Dictionary = model.s.duplicate(true)
	if model.fire():
		await _present(before, model.s.history.back().detail.results, false)

func _reload() -> void:
	if busy: return
	var before: Dictionary = model.s.duplicate(true)
	if model.reload_magazine():
		await _present(before, [], true)

func _choose(id: String, remove_id: String) -> void:
	if busy: return
	if model.choose_reward(id, remove_id): _changed()

func _present(before: Dictionary, results: Array, reloading: bool) -> void:
	busy = true
	_persist()
	for button in find_children("*", "Button", true, false):
		button.disabled = button.name != "skip_animation"
	battle_view.speed_scale = presentation_speed
	await battle_view.play_action(before, model.s, results, reloading)
	last_presentation = {"before": before, "after": model.s.duplicate(true), "shown_enemies": battle_view.enemies.duplicate(true), "events": battle_view.visual_events.duplicate(true)}
	busy = false
	redraw()

func _visual_shot(result: Dictionary) -> void:
	magazine_view.consume()
	preview_label.text = str(result.text)

func _skip_animation() -> void:
	if busy and is_instance_valid(battle_view): battle_view.fast_forward = true

func _dialog(title: String) -> VBoxContainer:
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.min_size = Vector2i(720, 480)
	dialog.dialog_hide_on_ok = true
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(780, 500)
	dialog.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	column.set_meta("dialog", dialog)
	scroll.add_child(column)
	dialog.popup_centered.call_deferred(Vector2i(820, 640))
	return column

func _rules() -> void:
	if busy: return
	var column := _dialog("구형 화기 사용법")
	_label(column, "마지막 장전 → 첫 발사", 30, ACCENT)
	_label(column, "1. 가까운 적을 자동 조준합니다. 동률이면 왼쪽 적이 먼저입니다. 명중 ≥ 회피, 관통 ≥ 장갑이어야 표시된 피해가 전부 들어갑니다. 확률 판정은 없습니다.")
	_label(column, "2. 계획 중에는 무료로 취소합니다. 확정 이후 순서를 바꾸려면 유료 재장전이 필요합니다. 탄환을 다 넣을 필요는 없습니다.")
	_label(column, "3. 준비탄은 발사하면 다음 한 발을 강화합니다. 빗나가도 준비 효과는 생기며, 다음 탄이 빗나가도 소모됩니다. 재장전하면 준비 효과가 사라집니다.")
	_label(column, "4. 적은 행동 비용만큼 전진합니다. 0m면 즉시 패배합니다. 충격탄은 명중하면 장갑에 막혀도 밀며, 탄창당 총 2m가 한계입니다. 점착은 다음 전진 한 번만 늦춥니다.")
	_label(column, "5. 재장전 시 남은 탄창은 사용탄 더미로, 남은 패는 유지됩니다. 기본탄 3발이 복구되고 전술 패를 5장까지 채웁니다. 뽑을 탄이 없으면 사용탄을 섞습니다.")
	_label(column, "6. 단발은 피해 +1 / 사격 1턴 / 재장전 1턴. 일제는 전탄 사격 1턴 / 재장전 3턴. 각 교전은 전체 덱과 기본 공급으로 새로 시작합니다.")

func _developer() -> void:
	var column := _dialog("개발자 테스트 · 기존 저장 보존")
	_label(column, "화면과 규칙을 즉시 확인하는 연습", 26)
	for entry in [["통합 장전 화면", 0, "plan"], ["보상 선택 화면", 0, "reward"], ["최종 복합 교전", 6, "plan"]]:
		_button(column, entry[0], "debug_" + str(entry[1]) + entry[2], func():
			model.start("single", 731042)
			model.s.floor = entry[1]
			model.begin_encounter()
			model.s.phase = entry[2]
			debug_session = true
			page = "run"
			column.get_meta("dialog").queue_free()
			redraw()
		)
