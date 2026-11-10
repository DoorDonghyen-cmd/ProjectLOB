extends RefCounted
## Contents of the common windows (2026-11-08): 설정, 조작 안내, 게임 규칙.
## screen.gd::_settings/_guide/_rules call these. The text is the same as before the
## rework; only the layout changed (choice buttons instead of drop-downs, step cards,
## headed rule rows) to match the workshop/gate/depot theme.
const Shell = preload("res://redesign/common/window.tscn")
const GOLD := Color("e9c27f")
const IVORY := Color("ebe2d1")
const MUTED := Color("a59c8b")

static func open(host: Control, title: String, subtitle: String, preferred: Vector2) -> VBoxContainer:
	var window = Shell.instantiate()
	window.set_meta("preferred_size", preferred)
	host.add_child(window)
	var column: VBoxContainer = window.setup(host, title, false)
	window.subtitle(subtitle)
	window.fit_content()
	return column

static func text(parent: Control, value: String, variation: StringName = &"", color: Variant = null) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if variation != &"": label.theme_type_variation = variation
	if color != null: label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

static func rule(parent: Control) -> void:
	var line := ColorRect.new()
	line.custom_minimum_size.y = 1
	line.color = Color(0.24, 0.21, 0.17, 1)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)

static func wide(host: Control) -> bool:
	return host.ReadableUI.available(host).size.x >= 1000

# ---------------------------------------------------------------- 확인 창

## Yes/no confirmation (2026-11-08) in the common window: message, cancel, confirm.
static func confirm(host: Control, title: String, message: String, key: String, accept_text: String, cancel_text: String, callback: Callable) -> Control:
	var column := open(host, title, "", Vector2(640, 330))
	var dialog: Control = column.get_meta("dialog")
	dialog.name = key
	text(column, message, &"", IVORY)
	dialog.ask(accept_text, cancel_text, callback)
	return dialog

# ---------------------------------------------------------------- 설정

static func settings(host: Control) -> VBoxContainer:
	var column := open(host, "설정", "연출 · 소리 · 도움말", Vector2(820, 560))
	column.name = "SettingsDialog"
	var label_width := 210.0 if wide(host) else 150.0
	choice(column, "MotionSetting", "전투 연출", "사격·적 행동 속도", label_width, [["기본", "normal"], ["빠르게", "fast"], ["즉시", "instant"]])
	choice(column, "EffectsVolumeSetting", "효과음", "버튼·사격 소리", label_width, [["끄기", 0.0], ["25%", 0.25], ["50%", 0.5], ["75%", 0.75], ["100%", 1.0]])
	choice(column, "ContextHintsSetting", "상황 도움말", "장면별 짧은 안내", label_width, [["켜기", true], ["끄기", false]])
	text(column, "탄환 수치, 예상 결과, 비용과 위험 표시는 도움말을 꺼도 유지됩니다.", &"Caption")
	var reset := Button.new()
	reset.name = "settings_reset"
	reset.text = "기본 설정으로 복원"
	reset.custom_minimum_size = Vector2(0, 44)
	reset.size_flags_horizontal = Control.SIZE_SHRINK_END
	reset.pressed.connect(reset_settings.bind(host, column))
	column.add_child(reset)
	return column

## One setting: name and caption on the left, every option visible as a button.
static func choice(column: VBoxContainer, id: String, title: String, caption: String, label_width: float, options: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = id + "Row"
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	var names := VBoxContainer.new()
	names.custom_minimum_size.x = label_width
	names.add_theme_constant_override("separation", 0)
	row.add_child(names)
	text(names, title, &"", IVORY)
	text(names, caption, &"Caption")
	var buttons := HBoxContainer.new()
	buttons.name = id
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_theme_constant_override("separation", 4)
	row.add_child(buttons)
	var group := ButtonGroup.new()
	for i in range(options.size()):
		var button := Button.new()
		button.name = "%s_%d" % [id, i]
		button.text = str(options[i][0])
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(0, 44)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.clip_text = true
		var host: Control = column.get_meta("dialog").host
		button.set_pressed_no_signal(is_current(host, id, options[i][1]))
		button.pressed.connect(apply_setting.bind(host, id, options[i][1]))
		buttons.add_child(button)
	rule(column)
	return row

static func is_current(host: Control, id: String, value: Variant) -> bool:
	var data: Dictionary = host.preferences.data
	match id:
		"TextScaleSetting": return is_equal_approx(float(value), float(data.text_scale))
		"MotionSetting": return str(value) == str(data.motion)
		"EffectsVolumeSetting": return roundi(float(data.effects_volume) * 4) == roundi(float(value) * 4)
		"ContextHintsSetting": return bool(value) == bool(data.hints)
	return false

static func apply_setting(host: Control, id: String, value: Variant) -> void:
	var prefs = host.preferences
	host.feedback.play("click")
	match id:
		"TextScaleSetting":
			prefs.set_value("text_scale", float(value))
			host._apply_preferences()
		"MotionSetting":
			prefs.set_value("motion", str(value))
			host._apply_preferences()
		"EffectsVolumeSetting":
			prefs.set_value("effects_volume", float(value))
			host.feedback.configure(prefs.data)
			host.feedback.play("load")
		"ContextHintsSetting":
			prefs.set_value("hints", bool(value))
			host._apply_preferences()

static func reset_settings(host: Control, column: VBoxContainer) -> void:
	host.feedback.play("click")
	host.preferences.reset()
	column.get_meta("dialog").close()
	host._apply_preferences()
	host._settings.call_deferred()

# ---------------------------------------------------------------- 조작 안내

static func guide(host: Control, magazine: bool) -> VBoxContainer:
	var column := open(host, "조작 안내", "처음 등반 · 세 번의 판단", Vector2(1080, 620))
	column.name = "FirstGuide"
	var steps := [
		["1", "탄환을 고른다", "아이콘의 큰 수치는 피해, 방패 수치는 관통입니다. 같은 탄환 두 장은 빛나는 결합 표시가 있을 때 서로 끌어 압축할 수 있습니다."],
		["2", "순서를 읽는다", "마지막에 넣은 탄이 맨 앞에서 발사됩니다. 증폭은 다음 공격탄, 화상은 전진 직전, 전이는 다른 생존 적에게 적용됩니다."],
		["3", "열과 시간을 확인한다", "열 한계에 닿으면 사격이 끊기고 강제 재장전합니다. 냉각탄은 그 전에 놓으세요. 예상 처치와 총 경과 턴을 확인한 뒤 확정하고 쏩니다."],
	]
	if magazine:
		steps = [
			["1", "이번 탄창을 읽는다", "보유 덱을 섞어 탄창을 채웁니다. 밝은 테두리와 순서 번호가 이번에 쏠 탄입니다. 탄환 수치는 기본 성능이며 적의 HP 게이지에서 사격 예측을 확인할 수 있습니다."],
			["2", "쏘거나 탄을 빼낸다", "그대로 사격하거나 탄을 먼저 고른 뒤 빼내기를 누르세요. 탄창당 두 발까지 뺄 수 있습니다. 빼낸 탄은 이번 전투에서 소모되며 뒤 탄이 앞으로 당겨집니다."],
			["3", "열과 접근을 판단한다", "사격 뒤 적이 한 번 행동합니다. 냉각은 잔탄을 보존하고, 탄창 교체는 미사용 탄을 예비 뒤로 보냅니다. 과열 냉각은 추가 시간이 들며 적이 도달하면 패배합니다."],
		]
	var grid := GridContainer.new()
	grid.name = "GuideSteps"
	grid.columns = 3 if wide(host) else 1
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	column.add_child(grid)
	for entry in steps:
		var card := PanelContainer.new()
		card.name = "GuideStep" + str(entry[0])
		card.theme_type_variation = &"Inspector"
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		var body := VBoxContainer.new()
		body.add_theme_constant_override("separation", 4)
		card.add_child(body)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		body.add_child(head)
		var number := Label.new()
		number.text = str(entry[0])
		number.theme_type_variation = &"SectionTitle"
		number.add_theme_color_override("font_color", GOLD)
		head.add_child(number)
		var name_label := text(head, str(entry[1]), &"", IVORY)
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		text(body, str(entry[2]), &"", MUTED)
	var flow := PanelContainer.new()
	flow.name = "GuideFlow"
	flow.theme_type_variation = &"Inspector"
	column.add_child(flow)
	var flow_body := VBoxContainer.new()
	flow.add_child(flow_body)
	text(flow_body, "등반 흐름", &"", GOLD)
	var chain := HFlowContainer.new()
	chain.add_theme_constant_override("h_separation", 8)
	chain.add_theme_constant_override("v_separation", 6)
	flow_body.add_child(chain)
	var stops := ["지도에서 다음 장소 선택", "전투 · 탄약고 · 조우 · 정비소 · 상점", "구역 관문", "다음 구역 · 다섯째 구역 최종 관문"]
	for i in range(stops.size()):
		var stop := Label.new()
		stop.text = stops[i]
		stop.add_theme_color_override("font_color", IVORY)
		chain.add_child(stop)
		if i < stops.size() - 1:
			var arrow := Label.new()
			arrow.text = "→"
			arrow.add_theme_color_override("font_color", GOLD)
			chain.add_child(arrow)
	text(flow_body, "기초 훈련은 개별 장전으로 탄환 효과를 익히는 별도 모드입니다.", &"Caption")
	return column

# ---------------------------------------------------------------- 게임 규칙

static func rules(host: Control, magazine: bool, pressure: bool) -> VBoxContainer:
	if magazine:
		var column := open(host, "게임 규칙", "탄창과 등반 · 덱을 섞어 탄창을 채웁니다", Vector2(1040, 660))
		column.name = "RulesDialog"
		var heading_width := 180.0 if wide(host) else 120.0
		for entry in [
			["사격", "사격은 총기마다 2~3발씩 진행하며 남은 탄은 탄창에 보존됩니다. 스파이크는 한 발을 쏘고 처치하면 이어 쏩니다. 사격 뒤 적이 1행동합니다."],
			["빼내기", "탄을 먼저 선택한 뒤 빼내기를 누르면 해당 탄이 빠집니다. 탄창당 최대 2발이며 적 행동이나 발열은 늘지 않습니다. 빈칸을 새 탄으로 채우지는 않습니다."],
			["냉각과 교체", "냉각은 잔탄을 보존하고 적이 1행동합니다. 탄창 교체는 미사용 탄을 예비 뒤로 보내고 새로운 탄창을 채웁니다. 과열 시 강제 냉각 중 적이 추가로 접근합니다."],
			["소모와 복구", "사용하거나 빼낸 탄은 이번 전투에서 돌아오지 않습니다. 공격탄을 소진하면 비상 보급을 선택할 수 있지만 추가 시간이 듭니다. 다음 전투에는 보유 탄이 복구됩니다."],
			["등반과 저장", "전투 보상과 상점에서 덱·파츠를 만들고 관문에서 개조·재정비합니다. 공방에서 같은 일반탄 두 발을 영구 압축할 수 있습니다. 전투·선택마다 자동 저장됩니다."],
		]:
			rule_row(column, str(entry[0]), str(entry[1]), heading_width)
		return column
	var legacy := open(host, "게임 규칙", "순서를 설계하는 법 · 마지막 장전부터 발사", Vector2(1040, 660))
	legacy.name = "RulesDialog"
	var width := 72.0
	rule_row(legacy, "1", "피해는 타격당 기본 화력, 관통은 무시하는 장갑입니다. 마지막에 넣은 탄부터 발사합니다. 레일은 실제 발사 순서이며 확정 전에는 위치 제약 안에서 순서를 바꿀 수 있습니다.", width)
	if pressure: rule_row(legacy, "", "장갑 · 관통을 뺀 장갑 1마다 직접 피해가 10% 줄어듭니다(최대 80%, 버림, 최소 1). 파쇄는 후속 공격의 장갑을 낮추며 화상·전이는 장갑을 무시합니다.", width)
	rule_row(legacy, "2", "리벳·래칫·스플린터·리액터는 한 탄창을 1턴에 연쇄 발사합니다. 스파이크는 1발을 쏘고, 주 표적을 처치하면 다음 탄도 이어 쏩니다. 한 번의 발사가 끝나면 1턴이 지나고 살아남은 적이 전진합니다.", width)
	rule_row(legacy, "", "리액터는 과열 후 다음 탄 1장까지 강행합니다. 강행 후에도 과열이면 추가 냉각이 총 2턴이며, 한계 아래로 내리면 잔탄을 보존합니다.", width)
	if pressure: rule_row(legacy, "", "강행 공격은 장갑 적용 전 직접 피해 ×2를 얻습니다. 열 한계에 닿은 공격에는 아직 적용되지 않습니다.", width)
	rule_row(legacy, "발열", "한계에 닿은 탄까지 효과를 처리한 뒤 사격을 중단합니다. 적이 남으면 기본 재장전 + 냉각 1턴이 자동 진행됩니다. 냉각탄은 과열 전에 놓으세요. 일반 재장전은 무기별 일정량만 냉각하고 남은 열은 다음 탄창에 이어집니다. 강제 재장전은 열을 0으로 낮춥니다.", width, GOLD)
	for entry in [
		["3", "리벳는 공격탄 피해 +1, 기본탄 피해 +1. 증폭·파쇄·냉각은 공격탄 보너스에서 제외합니다. 래칫는 같은 적의 주 타격 3회마다 추가 피해 4. 연타탄의 두 타격은 각각 세며 화상/전이는 세지 않습니다."],
		["4", "스플린터는 탄환마다 살아 있는 적 중 무작위 표적을 선택합니다. 확률과 HP 범위가 예상이며 확정 결과가 아닙니다. 나머지는 가장 가까운 적부터 조준합니다."],
		["5", "리액터는 과열 후 남은 탄 1발을 더 쏘고 멈춥니다. 여전히 과열이면 강제 재장전에 1턴이 추가됩니다. 추가탄으로 냉각해 한계 아래로 내려오면 강제 재장전은 없습니다. 이전 등반의 리액터는 저장된 속성 특화 규칙을 유지합니다. 스파이크는 탄환 기본 피해/관통과 증폭/넉백/화상 피해/전이 강도 2배입니다. 기본 연타탄은 2타, 증폭은 다음 공격탄에 적용하며, 화상 기간은 유지합니다."],
		["6", "일반 증폭은 다음 공격 1발 +3, 고급 증폭은 공격 2발, 배율탄은 다음 공격 ×2입니다. 지원탄은 강화 효과를 소비하지 않습니다. 일반·잔열 증폭은 서로 교체하고 배율도 중첩하지 않습니다. 덧셈과 배율은 함께 쓸 수 있습니다. 배율 공격은 추가 열 +3, 잔열 증폭은 공격 직전 고열이 필요합니다. 스파이크의 배율탄은 ×3입니다. 화상은 전진 직전에 진행합니다. 실제 총기 수치와 효과는 탄환 카드에서 확인하세요."],
		["7", "새 등반은 총기에 따라 기본탄 14장 또는 20장으로 출발하고, 첫 승리 뒤 주력 탄 2장과 지원탄 1장으로 기본탄을 교체합니다. 복장별 덱 최소/휴대 최대는 장비 화면에서 확인하며 정비로 휴대 상한을 2발씩 최대 3회 늘립니다. 탄창 크기는 총기/파츠, 한 번에 선택할 발수는 총기/관문 개조로 결정합니다. 드래그는 앞 탄부터 연속 선택하며 탄환을 누른 뒤 빼내기로 순서를 당길 수도 있습니다. 과열·처치 조건으로 일찍 멈춘 탄은 남습니다. 탄창 교체는 적 2행동 이상이며 잔탄은 예비 뒤로 돌아가고 열은 유지됩니다. 냉각은 적 1행동으로 열과 연속 사격 누적을 초기화합니다. 사용·빼낸 탄은 이번 전투에서 돌아오지 않으며 다음 전투에서 복구됩니다. 공격탄이 소진되면 비용이 점차 늘어나는 비상 보급을 선택할 수 있습니다. 기존 저장과 훈련은 원래 규칙을 유지합니다."],
		["8", "회색 한 줄은 일반, 파란 두 줄은 고급입니다. 같은 일반탄 2장을 고급 1장으로 압축합니다. 상점·공방에서 표시된 비용과 횟수로 가공하며 덱은 최소 8장, 고급 재압축은 아직 지원하지 않습니다. 새 등반의 관문은 보스 전리품 뒤 전용 개조를 선택합니다."],
		["9", "전투 압축은 코어 1개를 쓰는 임시 고급탄입니다. 작은 금색 점이 임시 상태입니다. 새 등반에서는 압축 취소나 개별 회수가 불가능합니다. 재장전으로 배출하면 원본 두 발은 사용함으로 이동하고 코어를 반환하지 않습니다. 원본 탄은 다음 전투에 복구되고 영구 등급은 바뀌지 않습니다. 코어는 상점에서 최대 2개까지 충전합니다. 이전 순환 저장은 확정 전 압축 취소 시 두 발과 코어를 돌려받습니다."],
		["10", "상층 부유체는 3턴마다 다른 적을 2m 당기고, 흡수 구체는 직접 타격으로 배리어를 먼저 소모하며, 태세 드론은 전진 뒤 장갑 4와 0을 교대합니다."],
		["11", "탑의 여러 구역을 지나 정상으로 향합니다. 매 등반의 경로와 시설이 달라집니다. 파츠는 최대 5개를 함께 장착하고 금색 코어는 하나만 사용합니다. 청록 ▲는 이점, 적색 ▼는 패널티입니다."],
	]:
		rule_row(legacy, str(entry[0]), str(entry[1]), width)
	return legacy

static func rule_row(column: VBoxContainer, heading: String, body: String, heading_width: float, body_color: Color = IVORY) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	var head := Label.new()
	head.text = heading
	head.custom_minimum_size.x = heading_width
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_theme_color_override("font_color", GOLD)
	head.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(head)
	text(row, body, &"", body_color)
	rule(column)
	return row
