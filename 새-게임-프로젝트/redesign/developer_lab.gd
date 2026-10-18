extends PanelContainer
signal close_requested
const Data = preload("res://redesign/content.gd")
const Lab = preload("res://redesign/dev_build_lab.gd")
const PixelSkin = preload("res://redesign/combat_pixel_skin.gd")
const Forecast = preload("res://redesign/forecast.gd")
var lab = Lab.new()
var selected_id := ""
var ids: Array = []
var last_result: Dictionary = {}
var pinned: Dictionary = {}
var pinned_title := ""
var pinned_context: Array = []
var syncing := false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var local_theme := Theme.new()
	local_theme.default_font = PixelSkin.FONT
	local_theme.default_font_size = 20
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var face := PixelSkin.box("button", state)
		face.content_margin_left = 16
		face.content_margin_right = 16
		face.content_margin_top = 10
		face.content_margin_bottom = 10
		local_theme.set_stylebox(state, "Button", face)
	preload("res://redesign/console_widgets.gd").apply_to(local_theme)
	for widget in ["LineEdit", "ItemList", "RichTextLabel", "Label", "Button", "OptionButton", "SpinBox"]:
		local_theme.set_color("font_color", widget, PixelSkin.INK)
		local_theme.set_color("font_selected_color", widget, PixelSkin.SELECT)
		local_theme.set_color("font_placeholder_color", widget, PixelSkin.MUTED)
	for widget in ["LineEdit", "ItemList"]:
		var inset := StyleBoxFlat.new()
		inset.bg_color = Color("17252c")
		inset.border_color = Color("4c6266")
		inset.set_border_width_all(2)
		inset.content_margin_left = 10
		inset.content_margin_right = 10
		inset.content_margin_top = 8
		inset.content_margin_bottom = 8
		local_theme.set_stylebox("normal" if widget == "LineEdit" else "panel", widget, inset)
	var selected := StyleBoxFlat.new()
	selected.bg_color = Color("344c4d")
	local_theme.set_stylebox("selected", "ItemList", selected)
	local_theme.set_stylebox("selected_focus", "ItemList", selected)
	local_theme.set_constant("v_separation", "ItemList", 12)
	theme = local_theme
	%Close.pressed.connect(func(): close_requested.emit())
	%BuildTab.pressed.connect(func(): show_tab(false))
	%UITab.pressed.connect(func(): show_tab(true))
	for id in Data.GUNS: %Gun.add_item(Data.GUNS[id].name)
	for encounter in Data.ENCOUNTERS: %Encounter.add_item(str(encounter.name).split(" / ")[-1])
	%Kind.add_item("탄환"); %Kind.add_item("파츠")
	%Gun.item_selected.connect(func(_i): _configure())
	%Encounter.item_selected.connect(func(_i): _configure())
	%Seed.value_changed.connect(func(_v): _configure())
	%Heat.value_changed.connect(func(_v): _configure())
	%Search.text_changed.connect(func(_v): _catalog())
	%Kind.item_selected.connect(func(_i): _catalog())
	%Catalog.item_selected.connect(func(i): selected_id = str(ids[i]); _detail())
	%Add.pressed.connect(_add)
	%Undo.pressed.connect(func(): lab.loaded.pop_back(); _changed())
	%Clear.pressed.connect(func(): lab.loaded.clear(); lab.parts.clear(); _changed())
	%Trial.pressed.connect(_trial)
	%Pin.pressed.connect(func():
		pinned = last_result.duplicate(true)
		pinned_context = [lab.encounter, lab.run_seed, lab.start_heat]
		pinned_title = _build_name()
		_result_text()
	)
	_gallery()
	_sync_settings()
	_catalog()
	_changed()
	show_tab(false)
	%Close.grab_focus()

func show_tab(gallery: bool) -> void:
	%Build.visible = not gallery
	%Gallery.visible = gallery
	%BuildTab.disabled = not gallery
	%UITab.disabled = gallery

func _sync_settings() -> void:
	syncing = true
	%Gun.select(Data.GUNS.keys().find(lab.gun))
	%Encounter.select(lab.encounter)
	%Seed.value = lab.run_seed
	%Heat.value = lab.start_heat
	syncing = false

func _configure() -> void:
	if syncing: return
	var reason: String = lab.configure(str(Data.GUNS.keys()[%Gun.selected]), %Encounter.selected, int(%Seed.value), int(%Heat.value))
	_sync_settings()
	_changed(reason)

func _catalog() -> void:
	ids = Lab.catalog(%Kind.selected, %Search.text)
	%Catalog.clear()
	for id in ids:
		var spec: Dictionary = Data.AMMO[id] if %Kind.selected == 0 else Data.PARTS[id]
		var grade: String = Data.grade_name(id) if %Kind.selected == 0 else Data.part_grade_name(id)
		%Catalog.add_item(str(spec.name) + " · " + grade)
	%Count.text = "%d종 · 현행 데이터" % ids.size()
	if not ids.has(selected_id): selected_id = str(ids[0]) if not ids.is_empty() else ""
	if not selected_id.is_empty(): %Catalog.select(ids.find(selected_id))
	_detail()

func _detail() -> void:
	for child in %Card.get_children(): child.free()
	%Add.disabled = selected_id.is_empty()
	%Card.text = "검색 결과 없음" if selected_id.is_empty() else ""
	if selected_id.is_empty():
		%Description.text = "다른 이름이나 효과로 검색하세요."
		return
	var m = lab.fixture()
	if %Kind.selected == 0:
		var card = preload("res://redesign/ammo_card_view.gd").new()
		card.combat_skin = true
		%Card.add_child(card)
		card.setup(selected_id, 1, m.s)
		%Description.text = preload("res://redesign/readability.gd").description(selected_id, m.s) + "\n" + Data.grade_detail(selected_id)
		%Add.text = "이 탄환 장전"
	else:
		var card = preload("res://redesign/part_card_view.gd").new()
		%Card.add_child(card)
		card.setup(selected_id, m.s, lab.parts.has(selected_id), true)
		%Description.text = str(Data.PARTS[selected_id].text)
		%Add.text = "이 파츠 해제" if lab.parts.has(selected_id) else "이 파츠 장착"

func _add() -> void:
	var reason: String = lab.add_round(selected_id) if %Kind.selected == 0 else lab.toggle_part(selected_id)
	_changed(reason)

func _changed(reason: String = "") -> void:
	last_result = {}
	%Pin.disabled = true
	%Result.text = "시험 전 · 탄환은 마지막에 넣은 것부터 발사합니다."
	%Notice.text = reason if not reason.is_empty() else "개발용 준비 패 · 실제 계산 사용 · 플레이 저장과 분리"
	%Notice.modulate = PixelSkin.HEAT if not reason.is_empty() else PixelSkin.MUTED
	var m = lab.fixture()
	%Stats.text = "탄창 %d/%d칸 · 열 %d/%d · 재장전 %d턴 / 냉각 %d" % [Data.slots_used(m.s.plan), m.capacity(), lab.start_heat, Data.heat_limit(m.s), m.reload_cost(), Data.reload_cooling(m.s)]
	var names: PackedStringArray = []
	for id in m.s.plan: names.append(Data.AMMO[id].name)
	%Order.text = "발사 순서 →\n" + (" → ".join(names) if not names.is_empty() else "장전한 탄환 없음")
	names.clear()
	for id in lab.parts: names.append(Data.PARTS[id].name)
	%Parts.text = "장착 %d/5 · 코어 최대 1\n%s" % [lab.parts.size(), " · ".join(names) if not names.is_empty() else "파츠 없음"]
	%Trial.disabled = lab.loaded.is_empty()
	%Undo.disabled = lab.loaded.is_empty()
	_detail()

func _build_name() -> String:
	var names: PackedStringArray = []
	for id in lab.loaded: names.append(str(Data.AMMO[id].name))
	var part_names: PackedStringArray = []
	for id in lab.parts: part_names.append(str(Data.PARTS[id].name))
	return "%s · 삽입 %s\n파츠 %s" % [Data.GUNS[lab.gun].name, " / ".join(names), " / ".join(part_names) if not part_names.is_empty() else "없음"]

func _trial() -> void:
	last_result = lab.run_trial()
	%Pin.disabled = last_result.is_empty()
	_result_text()

func _result_text() -> void:
	if last_result.is_empty(): return
	var r := last_result
	var text_value := "예측 · " + Forecast.compact_summary(r.forecast)
	text_value += "\n최고 열 %d~%d · 강제 재장전 %d~%d턴" % [r.forecast.heat.peak_min, r.forecast.heat.peak_max, r.forecast.heat.forced_cost_min, r.forecast.heat.forced_cost_max]
	text_value += "\n\n실제 시험 · 시드 %d\nHP 감소 %d · 처치 %d · 경과 %d턴\n최고 열 %d → 종료 %d · 강제 재장전 %d턴" % [lab.run_seed, r.damage, r.kills, r.turns, r.peak, r.end_heat, r.forced]
	text_value += "\n" + str(r.after.message)
	if not pinned.is_empty():
		text_value += "\n\n비교 기준 · " + pinned_title
		if pinned_context == [lab.encounter, lab.run_seed, lab.start_heat]:
			text_value += "\n변화 · HP 감소 %+d / 처치 %+d / 최고 열 %+d / 턴 %+d" % [r.damage-pinned.damage, r.kills-pinned.kills, r.peak-pinned.peak, r.turns-pinned.turns]
		else: text_value += "\n대열·시드·시작 열이 달라 직접 비교하지 않습니다."
	%Result.text = text_value

func _gallery() -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var b := Button.new()
		b.text = {"normal":"기본", "hover":"가리킴", "pressed":"눌림", "disabled":"비활성", "focus":"포커스"}[state]
		b.custom_minimum_size = Vector2(120,48)
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("normal", PixelSkin.box("button", "normal" if state == "focus" else state))
		if state == "focus": b.add_theme_stylebox_override("normal", PixelSkin.box("button", "focus"))
		%Buttons.add_child(b)
	for i in range(3):
		var b := Button.new()
		b.custom_minimum_size = Vector2(0,176)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = i == 2
		b.toggle_mode = true
		b.button_pressed = i == 1
		var card = preload("res://redesign/ammo_card_view.gd").new()
		card.combat_skin = true
		card.selected_visual = i == 1
		b.add_child(card)
		%Cards.add_child(b)
		card.setup(["basic", "charge", "pierce_c"][i], 1, lab.fixture().s, i == 2, false, ["기본", "현재 선택", "공간 부족"][i])
	for title in ["기본 표시", "긴 문구 · 탄환과 발열 정보를 확인하는 선택 항목", "선택 불가"]: %Options.add_item(title)
	%Options.set_item_disabled(2,true)
	%Interactive.pressed.connect(func(): %InputStatus.text = "실제 버튼 입력 확인")
