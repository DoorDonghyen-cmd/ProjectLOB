extends RefCounted
const Scene = preload("res://redesign/story_scene.gd")
const Story = preload("res://redesign/city_story.gd")

static func heading(ui, title: String) -> HBoxContainer:
	var top: HBoxContainer = ui._row(ui.body)
	ui._label(top, title, 23, ui.MUTED)
	var menu: Button = ui._button(top, "메뉴", "menu", ui._to_menu)
	menu.size_flags_horizontal = Control.SIZE_SHRINK_END
	menu.custom_minimum_size.x = 80
	menu.add_theme_font_size_override("font_size", ui._scaled(17))
	return top

static func scene(ui, supplied: bool, released: bool) -> void:
	var view := Scene.new()
	view.name = "SupplyScene"
	view.supplied = supplied
	view.released = released
	view.custom_minimum_size.y = 210 if ui.size.y < 700 else 280
	view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ui.body.add_child(view)
	var labels: HBoxContainer = ui._row(ui.body)
	ui._label(labels, "정상 · 중앙 제어", 17, ui.MUTED)
	var valve: Label = ui._label(labels, "현장 제어 가능" if released else "수동 밸브", 17, ui.ACCENT if released else ui.MUTED)
	valve.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var home: Label = ui._label(labels, "우리 동네 · 공급 중" if supplied else "우리 동네 · 공급 중단", 17, ui.ACCENT if supplied else ui.DANGER)
	home.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

static func departure(ui) -> void:
	var step := int(ui.campaign.s.get("departure_step", 0))
	var top := heading(ui, "출발 전 · 우리 동네 정비소")
	var skip: Button = ui._button(top, "도입 건너뛰기", "story_skip", ui._campaign_action.bind("departure_skip"))
	skip.size_flags_horizontal = Control.SIZE_SHRINK_END
	skip.custom_minimum_size.x = 185
	skip.add_theme_font_size_override("font_size", ui._scaled(17))
	scene(ui, step == 1, false)
	var beat: Dictionary = Story.DEPARTURE[step]
	ui._label(ui.body, beat.title, 34)
	ui._label(ui.body, beat.text, 20, ui.MUTED)
	var next: Button = ui._primary_button(ui._button(ui.body, beat.action, "story_next", ui._campaign_action.bind("departure_next")))
	ui._focus_control.call_deferred(next)

static func restoration(ui) -> void:
	heading(ui, "정상 · 수동제어실")
	scene(ui, false, false)
	ui._label(ui.body, "아직, 저 아래에 사람들이 산다.", 34)
	ui._label(ui.body, "기상 설비는 다시 돌릴 수 있다. 하지만 예전 공급 목록을 그대로 복원하면 같은 집들이 또 꺼진다.\n차단 명령을 지우고, 각 구역에서도 밸브를 제어할 수 있게 하자.", 20, ui.MUTED)
	var next: Button = ui._primary_button(ui._button(ui.body, "공급 복구 · 현장 제어권 열기", "story_restore", ui._campaign_action.bind("restore_supply")))
	ui._focus_control.call_deferred(next)

static func shop_inline(ui, place: Control, region: int) -> void:
	var shop: Dictionary = Story.SHOPS[region]
	var copy: VBoxContainer = place.get_node("Copy")
	var prose: Label = ui._label(copy, str(shop.story), 18)
	prose.name = "ShopStoryText"
	prose.add_theme_color_override("font_color", Color("c4c9be"))
	# This is part of entering the room, with no modal or extra reading action.
	place.get_node("%PlaceActions").hide()

static func shop_story(ui, region: int) -> void:
	var shop: Dictionary = Story.SHOPS[region]
	var panel: VBoxContainer = ui._workspace(shop.person, str(ui.campaign.node().name) if ui.campaign != null and ui.campaign.modern_places() else shop.place)
	ui._label(panel, shop.greeting, 27, ui.ACCENT)
	ui._label(panel, shop.story, 22)
	ui._primary_button(ui._button(panel, "거래로 돌아가기", "story_shop_close", ui._close_workspace))

static func homecoming(ui, show_results: Callable) -> void:
	heading(ui, "귀환 · 우리 동네 정비소")
	scene(ui, true, true)
	ui._label(ui.body, "돌아갈 곳에 불이 켜졌다.", 34)
	ui._label(ui.body, "기상 설비가 다시 돌고, 각 구역의 밸브가 사람들의 손으로 돌아왔다.\n정비소 동료가 그릇을 하나 더 놓는다. “왔네. 손부터 녹여.”", 20, ui.MUTED)
	var next: Button = ui._primary_button(ui._button(ui.body, "등반 결과 보기", "story_results", show_results))
	ui._focus_control.call_deferred(next)
