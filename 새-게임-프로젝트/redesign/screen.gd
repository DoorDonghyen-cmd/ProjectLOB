extends Control
const Model = preload("res://redesign/model.gd")
const Content = preload("res://redesign/content.gd")
const BattleView = preload("res://redesign/battle_view.gd")
const MagazineView = preload("res://redesign/magazine_view.gd")
const AmmoVisual = preload("res://redesign/ammo_visual.gd")
const AmmoCardView = preload("res://redesign/ammo_card_view.gd")
const Forecast = preload("res://redesign/forecast.gd")
const Readability = preload("res://redesign/readability.gd")
const SAVE := "user://chain_run_v2.json"
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
var course_toggle: CheckButton
var calculation_label: Label
var selected_slot := 0
var inspect_slots := false
var previous_forecast: Dictionary = {}
var save_error := ""
var busy := false
var presentation_speed := 1.0
var battle_view: Control
var magazine_view: Control
var preview_label: Label
var last_presentation: Dictionary = {}
var ammo_inspector: Label
var inspected_ammo := "basic"
var combat_forecast: Dictionary = {}

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
	button.custom_minimum_size.y = 52
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
	for item in [["정보", "details", _details], ["규칙", "rules", _rules], ["메뉴", "menu", _to_menu]]:
		var button := _button(top, item[0], item[1], item[2])
		button.size_flags_horizontal = Control.SIZE_SHRINK_END
		button.custom_minimum_size.x = 84
	var skip := _button(top, "연출 생략", "skip_animation", _skip_animation, true)
	skip.custom_minimum_size.x = 135
	skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	skip.visible = busy
	var equipment := str(Content.GUNS[model.s.gun].name)
	if model.s.part != "none": equipment += " · " + str(Content.PARTS[model.s.part].name)
	if model.s.buff.has("dmg"): equipment += " · 증폭 %d발" % model.s.buff.dmg_left
	_label(body, "%s   ·   %d턴" % [equipment, model.s.turns], 18, MUTED)
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
	_label(body, "3속성 개편판 · 피해와 관통 · 물리·화염·전기", 20, MUTED)
	course_toggle = CheckButton.new()
	course_toggle.name = "CourseToggle"
	course_toggle.text = "차근차근 배우기 · 끄면 일반 런"
	course_toggle.button_pressed = not FileAccess.file_exists("user://course_completed.flag")
	course_toggle.custom_minimum_size.y = 52
	body.add_child(course_toggle)
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
	var course: bool = model.s.get("course", false) if same_seed else course_toggle.button_pressed
	model.start(id, run_seed, course)
	selected_slot = 0
	inspect_slots = false
	previous_forecast = {}
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
	var previous := combat_forecast
	combat_forecast = Forecast.analyze(model.s)
	battle_view = BattleView.new()
	battle_view.name = "BattleView"
	battle_view.inspection_enabled = not busy
	body.add_child(battle_view)
	battle_view.sync(model.s)
	if model.s.get("course", false): battle_view.caption = Content.LESSONS[int(model.s.floor)]
	if not combat_forecast.shots.is_empty(): battle_view.first_shot = combat_forecast.shots[0]
	battle_view.shot_started.connect(_visual_shot)
	battle_view.enemy_inspected.connect(_enemy_details)
	var workbench := _row(body)
	var candidates := _panel(workbench)
	candidates.get_parent().size_flags_stretch_ratio = 1.45
	var hand_header := _row(candidates)
	_label(hand_header, "보유 탄환", 22, ACCENT)
	if not model.s.get("course", false) or int(model.s.floor) >= 2:
		_button(hand_header, "패 교환 · %d회" % model.s.exchange_left, "exchange", _exchange_dialog, model.s.phase != "plan" or model.s.exchange_left <= 0 or (model.s.draw.is_empty() and model.s.discard.is_empty()))
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
		var disabled: bool = model.s.phase != "plan" or count <= 0 or model.s.plan.size() >= model.capacity()
		var button := _button(grid, "", "load_" + id, _load.bind(id), disabled)
		button.tooltip_text = _ammo_stats(id) + "\n" + Readability.description(id, model.s)
		button.custom_minimum_size.y = 104
		button.mouse_entered.connect(_inspect_ammo.bind(id))
		button.focus_entered.connect(_inspect_ammo.bind(id))
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
			style.content_margin_left = 6
			style.content_margin_right = 6
			button.add_theme_stylebox_override(state, style)
		var card_view := AmmoCardView.new()
		card_view.name = "CardInfo"
		card_view.setup(id, count, model.s, disabled)
		button.add_child(card_view)
	ammo_inspector = _label(candidates, "", 17, INK)
	ammo_inspector.name = "AmmoInspector"
	ammo_inspector.custom_minimum_size.y = 48
	calculation_label = ammo_inspector
	_inspect_ammo(inspected_ammo if ids.has(inspected_ammo) else "basic")
	_label(candidates, "다음  ·  %s" % [_ammo_names(model.s.draw.slice(0, 2)) if not model.s.draw.is_empty() else "사용탄 셔플"], 16, MUTED)
	var queue := _panel(workbench)
	var multi: bool = model.s.enemies.size() > 1
	_label(queue, "발사 순서 → · %d칸" % model.capacity(), 22, ACCENT)
	var stack: Array = model.s.plan if model.s.phase == "plan" else model.s.magazine
	magazine_view = MagazineView.new()
	magazine_view.name = "MagazineView"
	magazine_view.stack = stack.duplicate()
	magazine_view.capacity = model.capacity()
	magazine_view.interactive = not busy
	magazine_view.selected_index = selected_slot
	magazine_view.slot_hovered.connect(_inspect_slot)
	for i in range(combat_forecast.shots.size()):
		if i >= previous.get("shots", []).size() or combat_forecast.shots[i].damage != previous.shots[i].damage or combat_forecast.shots[i].target != previous.shots[i].target:
			magazine_view.changed_slots.append(i)
	magazine_view.slot_pressed.connect(_slot_action)
	magazine_view.confirmed = model.s.phase == "ready"
	if not stack.is_empty(): magazine_view.forecast = combat_forecast
	queue.add_child(magazine_view)
	if model.s.phase == "plan":
		var edits := _row(queue)
		var inspect := _button(edits, "계산 보기", "inspect_slots", func():
			inspect_slots = not inspect_slots
			redraw()
		)
		inspect.toggle_mode = true
		inspect.button_pressed = inspect_slots
		inspect.tooltip_text = "켜면 칸 터치로 계산을 확인하고, 끄면 칸 터치로 회수합니다."
		_button(edits, "끝 탄 회수", "undo", _undo, stack.is_empty()).tooltip_text = "마지막 칸을 돌려받습니다. 시간 소모 없음."
	var preview: Dictionary = model.preview()
	preview_label = _label(queue, _preview_text(preview), 18, ACCENT if int(preview.get("damage", 0)) > 0 else MUTED)
	preview_label.tooltip_text = str(preview.get("text", "누른 순서대로 발사합니다. 피해·거리·속성 효과를 함께 설계하세요."))
	if not stack.is_empty():
		preview_label.text = "" + ("전탄 후 적 접근" if model.s.gun == "burst" else "매 발 후 적 접근")
		if combat_forecast.phase == "lost": preview_label.text = "연속 사격: %d발 뒤 접촉 위험" % combat_forecast.shots.size()
		preview_label.tooltip_text = "현재 탄창을 중간 재장전 없이 계속 발사할 때의 예상입니다. 보존은 전투 종료로 미발사, 중단은 접촉 패배로 미발사입니다.\n같은 거리는 A → B → C 순서로 조준합니다."
	if not stack.is_empty(): _inspect_slot(clampi(selected_slot, 0, stack.size() - 1))
	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	queue.add_child(actions)
	if model.s.phase == "plan":
		_button(actions, "장전 확정", "confirm", _confirm, stack.is_empty()).tooltip_text = "시간 소모 없음. 확정 후 순서를 바꾸려면 재장전해야 합니다."
	else:
		_button(actions, "%s · 1턴" % ("전탄 발사" if model.s.gun == "burst" else "발사"), "fire", _fire, stack.is_empty())
		var projected: Array = model.movement_preview(model.reload_cost())
		var lethal := false
		for i in range(projected.size()):
			if model.s.enemies[i].hp > 0 and projected[i] <= 0:
				lethal = true
		_button(actions, "재장전 · %d턴%s" % [model.reload_cost(), " · 접촉 위험" if lethal else ""], "reload", _reload)

func _ammo_stats(id: String) -> String:
	return Content.AMMO[id].name + "   " + Readability.stats(id, model.s, true)

func _inspect_ammo(id: String) -> void:
	inspected_ammo = id
	if is_instance_valid(ammo_inspector):
		var axes := Content.axes(model.s)
		var legend := "피해 → HP"
		if axes.armor: legend += "   관통 → 장갑"
		ammo_inspector.text = legend + "\n" + Readability.description(id, model.s)
		ammo_inspector.add_theme_color_override("font_color", AmmoVisual.COLORS[id])

func _preview_text(preview: Dictionary) -> String:
	if preview.is_empty():
		return "탄환을 눌러 장전하세요" if model.s.phase == "plan" else "탄창이 비었습니다"
	var result := "빗나감" if not preview.hit else ("도탄" if int(preview.damage) == 0 else "피해 %d" % preview.damage)
	if int(preview.hp) <= 0: result += " · 처치"
	var spec: Dictionary = Content.AMMO[preview.id]
	if str(spec.effect) in ["boost", "burn", "arc"]:
		result += "\n" + str(AmmoVisual.HINT[preview.id])
	return "첫 발  ·  " + result

func _reward() -> void:
	_label(body, "통과했습니다. 무엇을 가져갈까요?", 34, ACCENT)
	var next: Dictionary = Content.ENCOUNTERS[int(model.s.floor) + 1]
	var peek := _panel(body)
	_label(peek, "다음 교전  /  " + str(next.name), 24)
	for e in Content.enemies_for(int(model.s.floor) + 1, int(model.s.seed), model.s.get("course", false), str(model.s.gun)):
		_label(peek, "%s · HP %d · %s · 거리 %dm" % [e.name, e.hp, Readability.enemy_stats(e, {"course": model.s.get("course", false), "floor": int(model.s.floor) + 1}), e.distance], 18, MUTED)
	if model.s.get("course", false):
		var grants: Array = Content.COURSE_GRANTS[int(model.s.floor) + 1]
		if not grants.is_empty(): _label(peek, "다음 교전 보급: " + _ammo_names(grants), 18, ACCENT)
	_label(body, "덱 %d장 · %s" % [model.s.deck.size(), Content.PARTS[model.s.part].name], 18, MUTED)
	var row := _row(body)
	for id in model.reward_options():
		var is_ammo: bool = Content.AMMO.has(id)
		var spec: Dictionary = Content.AMMO[id] if is_ammo else Content.PARTS[id]
		var card := _panel(row)
		if is_ammo:
			var card_view := AmmoCardView.new()
			card_view.name = "RewardCardInfo"
			card_view.custom_minimum_size = Vector2(280, 104)
			card_view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			card_view.setup(id, 1, model.s)
			card.add_child(card_view)
		else:
			_label(card, spec.name, 25, ACCENT)
		_label(card, Readability.description(id, model.s) if is_ammo else str(spec.text), 19)
		_button(card, "덱에 1장 추가" if is_ammo else "파츠 장착 · 기존 파츠 교체", "reward_" + id, _choose.bind(id, ""), is_ammo and model.s.deck.size() >= model.deck_limit())
	var refine := _panel(body)
	_label(refine, "덱을 늘리지 않는 선택", 23)
	_button(refine, "지금 구성을 유지하고 계속", "reward_skip", _choose.bind("skip", ""))
	var remove_row := GridContainer.new()
	remove_row.columns = 5
	refine.add_child(remove_row)
	var ids: Array = []
	for id in model.s.deck:
		if ids.has(id):
			continue
		ids.append(id)
		_button(remove_row, "%s\n1장 제거" % Content.AMMO[id].name, "remove_" + id, _choose.bind("remove", id), model.s.deck.size() <= model.minimum_deck()).add_theme_font_size_override("font_size", 16)
	_label(refine, "정제는 보상 하나를 대신 사용합니다. 최소 %d장을 유지합니다." % model.minimum_deck(), 17, MUTED)

func _ending() -> void:
	var won: bool = model.s.phase == "won"
	if won and model.s.get("course", false) and save_enabled and not debug_session:
		var flag := FileAccess.open("user://course_completed.flag", FileAccess.WRITE)
		if flag: flag.store_string("completed")
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
		inspected_ammo = id
		selected_slot = model.s.plan.size() - 1
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
		var detail: Dictionary = model.s.history.back().detail
		await _present(before, detail.results, detail.get("advance_events", []), false)

func _reload() -> void:
	if busy: return
	var before: Dictionary = model.s.duplicate(true)
	if model.reload_magazine():
		await _present(before, [], model.s.history.back().detail.get("advance_events", []), true)

func _choose(id: String, remove_id: String) -> void:
	if busy: return
	if model.choose_reward(id, remove_id): _changed()

func _present(before: Dictionary, results: Array, advance_events: Array, reloading: bool) -> void:
	busy = true
	_persist()
	find_child("skip_animation", true, false).show()
	magazine_view.forecast = {}
	magazine_view.queue_redraw()
	for button in find_children("*", "Button", true, false):
		button.disabled = button.name != "skip_animation"
	battle_view.speed_scale = presentation_speed
	await battle_view.play_action(before, model.s, results, advance_events, reloading)
	last_presentation = {"before": before, "after": model.s.duplicate(true), "shown_enemies": battle_view.enemies.duplicate(true), "events": battle_view.visual_events.duplicate(true)}
	busy = false
	redraw()

func _visual_shot(result: Dictionary) -> void:
	magazine_view.consume()
	preview_label.text = ""
	preview_label.tooltip_text = str(result.text)

func _skip_animation() -> void:
	if busy and is_instance_valid(battle_view): battle_view.fast_forward = true

func _dialog(title: String, compact: bool = false) -> VBoxContainer:
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.min_size = Vector2i(520, 240) if compact else Vector2i(720, 480)
	dialog.dialog_hide_on_ok = true
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(530, 190) if compact else Vector2(780, 500)
	dialog.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	column.set_meta("dialog", dialog)
	scroll.add_child(column)
	dialog.popup_centered.call_deferred(Vector2i(580, 330) if compact else Vector2i(820, 640))
	return column

func _rules() -> void:
	if busy: return
	var column := _dialog("순서를 설계하는 법")
	_label(column, "누른 순서대로 · 피해와 관통", 30, ACCENT)
	_label(column, "1. 피해는 타격당 HP 감소, 관통은 무시하는 장갑 수치입니다. 가까운 적을 자동 조준하며 같은 거리는 A → B → C 순서입니다. 확률 판정은 없습니다.")
	_label(column, "2. 확정 전에는 탄창의 칸을 눌러 자유롭게 회수할 수 있습니다. 계산 보기를 켜면 칸을 눌러 해당 탄의 피해 근거를 봅니다. 확정 이후 바꾸려면 재장전 시간이 듭니다. 빈 칸을 모두 채울 필요는 없습니다.")
	_label(column, "3. 물리는 즉시 피해와 장갑·거리 대응, 화염은 전진 직전 화상 피해, 전기는 가장 가까운 다른 적에게 고정 피해 전이를 담당합니다. 속성 저항과 약점은 없습니다.")
	_label(column, "4. 증폭탄은 다음 2발의 타격당 피해 +2, 연발탄은 같은 적을 2회 타격합니다. 증폭 뒤 연발탄을 두면 증폭 피해도 두 번 적용됩니다.")
	_label(column, "5. 타격 피해 = 피해 + 총기 보정 + 증폭 − 남은 장갑 (최소 1). 남은 장갑 = 장갑 − 관통입니다. 전이와 화상은 별도 고정 피해입니다.")
	_label(column, "6. 화상은 적의 전진 직전에 1피해를 주고 1 감소합니다. 화상으로 죽은 적은 전진하지 않습니다. 충격탄은 탄창당 총 2m까지 밀어 거리를 확보합니다.")
	_label(column, "7. 재장전마다 회수탄 4발(확장 탄창 5발), 전술 패 5장, 패 교환 1회. 미사용 패 유지, 사용탄은 다시 섞습니다. 교환은 탄창에 넣지 않은 전술탄 1장을 다음 탄으로 바꿉니다.")
	_label(column, "8. 매 시드 적 편성·거리·보상 후보가 달라집니다. 보상 화면에서 다음 적을 먼저 확인하세요. 파츠는 하나만 장착합니다.")

func _inspect_slot(index: int) -> void:
	if busy or not is_instance_valid(calculation_label): return
	selected_slot = index
	magazine_view.selected_index = index
	magazine_view.queue_redraw()
	if combat_forecast.shots.is_empty():
		calculation_label.text = Readability.explain({}) if model.s.phase == "plan" else "다음 탄창을 장전하세요."
	elif index >= combat_forecast.shots.size():
		calculation_label.text = "%d번 · 전투가 먼저 끝나 이 탄은 발사되지 않습니다." % (index + 1)
	else:
		var shot: Dictionary = combat_forecast.shots[index]
		calculation_label.add_theme_color_override("font_color", INK)
		calculation_label.text = "%d번 %s → " % [index + 1, Content.AMMO[shot.id].name] + Readability.explain(shot)

func _slot_action(index: int) -> void:
	if busy: return
	if inspect_slots or model.s.phase != "plan": _inspect_slot(index)
	else: _remove_slot(index)

func _remove_slot(index: int) -> void:
	if not busy and model.remove_planned(index): _changed()

func _exchange_dialog() -> void:
	if busy or model.s.phase != "plan" or model.s.exchange_left <= 0: return
	var column := _dialog("전술탄 1장 교환", true)
	column.name = "ExchangeDialog"
	_label(column, "다음 탄: " + _ammo_names(model.s.draw.slice(0, 1)), 20, ACCENT)
	var ids: Array = []
	for id in model.s.hand:
		if ids.has(id): continue
		ids.append(id)
		_button(column, Content.AMMO[id].name + " 교환", "exchange_" + id, func():
			if not busy and model.exchange(id):
				column.get_meta("dialog").queue_free()
				_changed()
		, model.available(id) <= 0)

func _details() -> void:
	if busy: return
	var column := _dialog("전투 정보")
	column.name = "CombatDetails"
	var encounter: Dictionary = Content.ENCOUNTERS[int(model.s.floor)]
	_label(column, encounter.name, 26, ACCENT)
	_label(column, encounter.text, 18, MUTED)
	_label(column, "시드 %s · %s\n%s · %s" % [str(model.s.seed), Content.GUNS[model.s.gun].text, Content.PARTS[model.s.part].name, Content.PARTS[model.s.part].text], 18)
	_label(column, "적 정보", 22, ACCENT)
	for e in model.s.enemies:
		_label(column, "%s · HP %d/%d · 장갑 %d · 화상 %d\n거리 %dm · 접근 %dm" % [e.name, e.hp, e.max_hp, e.def, e.burn, e.distance, e.speed], 18)
	_label(column, "탄환 · 현재 총기/파츠 반영", 22, ACCENT)
	var ids: Array = ["basic"]
	for id in model.s.deck:
		if not ids.has(id): ids.append(id)
	for id in ids:
		_label(column, _ammo_stats(id), 19, AmmoVisual.COLORS[id])
		_label(column, "재장전 시 %d발 공급" % model.supply_capacity() if id == "basic" else str(Content.AMMO[id].text), 17, MUTED)
	_label(column, "덱 %d장 · 남은 덱 %d · 사용탄 %d\n%s" % [model.s.deck.size(), model.s.draw.size(), model.s.discard.size(), _ammo_names(model.s.deck)], 18)
	_label(column, "최근 결과\n" + str(model.s.message), 18, MUTED)

func _enemy_details(index: int) -> void:
	if busy or index < 0 or index >= model.s.enemies.size(): return
	var e: Dictionary = model.s.enemies[index]
	var column := _dialog("적 정보 · 자동 조준 유지", true)
	column.name = "EnemyDetails"
	column.set_meta("enemy_index", index)
	_label(column, "%s · %s" % [Forecast.tag(index), e.name], 26, ACCENT)
	_label(column, "HP %d/%d   장갑 %d   화상 %d" % [e.hp, e.max_hp, e.def, e.burn], 21)
	_label(column, "거리 %dm · 다음 접근 %dm" % [e.distance, e.speed], 19, MUTED)
	var hits: PackedStringArray = []
	for i in range(combat_forecast.get("shots", []).size()):
		var shot: Dictionary = combat_forecast.shots[i]
		if shot.target == index: hits.append("%d발 %s" % [i + 1, Forecast.outcome(shot)])
	_label(column, "연속 사격 예상: " + (" · ".join(hits) if not hits.is_empty() else "피격 없음"), 18, ACCENT)

func _developer() -> void:
	var column := _dialog("개발자 테스트 · 기존 저장 보존")
	_label(column, "화면과 규칙을 즉시 확인하는 연습", 26)
	_button(column, "3속성 탄환 전체", "debug_icon_cards", func():
		model.start("single", 731042)
		model.s.floor = 6
		model.begin_encounter()
		model.s.deck = ["bore", "pierce", "precise", "charge", "push", "arc"]
		model.s.hand = model.s.deck.duplicate()
		model.s.draw = []
		model.s.discard = []
		debug_session = true
		selected_slot = 0
		inspect_slots = false
		page = "run"
		column.get_meta("dialog").queue_free()
		redraw()
	)
	var lessons := _row(column)
	for entry in [["피해·증폭 연습", 0], ["장갑·관통 연습", 1], ["화상 연습", 2]]:
		_button(lessons, entry[0], "debug_lesson_" + str(entry[1]), func():
			model.start("single", 731042, true)
			for floor_index in range(1, int(entry[1]) + 1):
				model.s.deck.append_array(Content.COURSE_GRANTS[floor_index])
			model.s.floor = entry[1]
			model.begin_encounter()
			debug_session = true
			selected_slot = 0
			inspect_slots = false
			page = "run"
			column.get_meta("dialog").queue_free()
			redraw()
		)
	_button(column, "화상 전진 정산", "debug_burn_tick", func():
		model.start("single", 731042)
		model.s.floor = 2
		model.begin_encounter()
		model.s.enemies = [{"kind": "wall", "name": Content.ENEMY_NAMES.wall, "hp": 8, "max_hp": 8, "def": 1, "speed": 2, "distance": 6, "burn": 0}]
		model.s.deck = ["bore", "charge", "precise", "pierce", "push", "arc"]
		model.s.hand = model.s.deck.slice(0, 5)
		model.s.draw = ["arc"]
		model.s.discard = []
		model.load_round("bore")
		model.confirm()
		debug_session = true
		page = "run"
		column.get_meta("dialog").queue_free()
		redraw()
	)
	_button(column, "다수전 표적 전환 연습", "debug_multi_target", func():
		model.start("burst", 731042)
		model.s.floor = 3
		model.begin_encounter()
		model.s.enemies[0].distance = 16
		model.s.enemies[0].hp = 20
		model.s.enemies[0].max_hp = 20
		model.s.enemies[1].distance = 17
		model.s.enemies[1].hp = 4
		model.s.enemies[1].max_hp = 4
		model.s.enemies[1].def = 0
		model.s.hand = ["push", "charge", "precise", "bore", "arc"]
		for id in ["bore", "push", "precise", "charge"]: model.load_round(id)
		debug_session = true
		page = "run"
		column.get_meta("dialog").queue_free()
		redraw()
	)
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
