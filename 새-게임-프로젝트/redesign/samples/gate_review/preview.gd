extends Control

const Campaign = preload("res://redesign/campaign.gd")
const Gates = preload("res://redesign/gate_upgrades.gd")
const Ammo = preload("res://redesign/content.gd")
const Readability = preload("res://redesign/ui_readability.gd")
const GateUI = preload("res://redesign/gate_reward_ui.gd")
const Actors = preload("res://redesign/service_actor_catalog.gd")
const Actor = preload("res://redesign/weapon_actor.gd")
const ACTIVE := Color("e9c27f")
const MUTED := Color("9b9586")

enum Mode { MODS, DEFER, SPECIMENS, SOURCES, SERVICE, COPIES, DEPARTED }

var run: Campaign
var mode := Mode.MODS
var selected := ""
var deferred_choice := ""
var specimen := ""
var sources: Array = []
var buttons: Dictionary = {}
var template: Button
var traveling := false
var travel_time := 0.72
var checks := 0
var failures := 0
## Main-game link (2026-11-07). configure() hands over the live campaign; every
## gate command then goes through screen.gd::_campaign_action (autosave, sound).
## Without it the scene stays the standalone review fixture (load_gate, F1/F2).
var live_host = null
var live_presenter = null
@onready var shelf_layout := %Options is HBoxContainer

## Short screens (below 440 px, e.g. 844x390): lift the inspector beside the stage
## tabs so its action button clears the bottom shelf. Taller screens keep the
## reviewed layout (offset 124).
const COMPACT_HEIGHT := 440.0
func fit_stage() -> void:
	var compact := size.y > 0.0 and size.y < COMPACT_HEIGHT
	$Inspector.offset_top = 60.0 if compact else 124.0
	$Stages.offset_right = $Inspector.offset_left - 12.0 if compact else -24.0

func configure(screen, presenter) -> void:
	live_host = screen
	live_presenter = presenter
	run = screen.campaign

func _ready() -> void:
	template = %Options.get_child(0).duplicate()
	template.button_pressed = false
	%Apply.pressed.connect(apply)
	%Back.pressed.connect(back)
	%Secondary.pressed.connect(secondary)
	if shelf_layout:
		departure_control().pressed.connect(secondary)
		resized.connect(fit_stage)
		fit_stage.call_deferred()
	if live_host != null:
		enter_live()
		return
	get_window().size_changed.connect(fit_window)
	fit_window()
	Input.emulate_mouse_from_touch = true
	load_gate()
	var output := OS.get_environment("LOB_GATE_CAPTURE")
	if not output.is_empty():
		capture_review.call_deferred(output)

func _exit_tree() -> void:
	if is_instance_valid(template):
		template.free()

func fit_window() -> void:
	var window := get_window()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	window.content_scale_factor = Readability.scale_for(window.size)

## The live gate: real region names, the player's own outfit at the console, and the
## workbench's utility menu (build, archive, settings, title).
func enter_live() -> void:
	var outfit := str(run.model.s.get("outfit", "work"))
	%Gate.work_profile = Actors.resolve(outfit, "workshop").profile
	%Gate.operator_texture = Actor.portrait(outfit)
	%Region.text = run.region_info().name
	%Destination.text = run.region_info(int(run.s.region) + 1).name
	%Gate.travel = 0.0
	add_live_menu()
	show_mode(Mode.SERVICE if run.gate_ready() else Mode.MODS)

func add_live_menu() -> void:
	var menu := Button.new()
	menu.name = "Menu"
	menu.text = "메뉴"
	menu.custom_minimum_size = Vector2(72, 44)
	$Header.add_child(menu)
	var panel := PanelContainer.new()
	panel.name = "UtilityMenu"
	panel.visible = false
	panel.theme_type_variation = &"Inspector"
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -240.0
	panel.offset_top = 64.0
	panel.offset_right = -24.0
	add_child(panel)
	var actions := VBoxContainer.new()
	actions.name = "Actions"
	panel.add_child(actions)
	for entry in [["Build", "내 빌드", live_presenter.deck], ["Archive", "기록", live_presenter.archive], ["Settings", "설정", live_host._settings], ["ReturnTitle", "타이틀로", live_host._to_menu], ["CloseMenu", "닫기", Callable()]]:
		var button := Button.new()
		button.name = entry[0]
		button.text = entry[1]
		button.custom_minimum_size = Vector2(0, 44)
		actions.add_child(button)
		button.pressed.connect(use_utility.bind(panel, entry[2]))
	menu.pressed.connect(func(): panel.visible = not panel.visible)

func use_utility(panel: Control, target: Callable) -> void:
	panel.hide()
	if target.is_valid():
		target.call()

## Review fixture calls the rules directly; the live gate uses the main handler
## without a redraw, so this scene stays (departure redraws instead; see depart()).
func command(name: String, value: Variant = "", extra: String = "") -> bool:
	if live_host != null:
		return live_host._campaign_action(name, value, extra, "", false)
	match name:
		"gate": return run.gate(str(value), extra)
		"gate_production": return run.gate("production", extra, value)
		"gate_bag": return run.buy_gate_bag()
		"gate_copy": return run.buy_gate_copy(str(value))
		"gate_depart": return run.depart_gate()
	return false

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.pressed or event.echo or traveling:
		return
	if live_host != null:
		if event.keycode == KEY_ESCAPE: back()
		return
	match event.keycode:
		KEY_F1: load_gate()
		KEY_F2: load_gate(); run.gate("cadence"); show_mode(Mode.SERVICE)
		KEY_ESCAPE: back()

func load_gate() -> void:
	run = Campaign.new()
	run.start("burst", 251025, 0, "balanced", Campaign.Content.RouteMap.VERSION, "carrier", true)
	run.s.region = 1
	run.s.departure_step = 3
	run.s.clears = 2
	run.s.opening_reward_step = 2
	run.s.credits = 43
	run.s.parts = ["volley_drive"]
	run.s.equipped_parts = ["volley_drive"]
	run.model.s.deck = run.Model.FocusBuild.replace_opening(run.model.s.deck, "precise")
	var nodes := run.current_nodes()
	var boss: Dictionary = nodes.filter(func(node): return node.kind == "boss")[0]
	var prior: Dictionary = nodes.filter(func(node): return node.next.has(boss.id))[0]
	run.s.node = prior.id
	run.s.floor = prior.floor
	if not run.enter(int(boss.id)):
		push_error("Cannot stage the gate's boss encounter.")
		return
	# Only the review session stages victory; gate and service transactions are live rules.
	run.model.s.phase = "won"
	run.sync_combat()
	if not run.reward("skip"):
		push_error("Cannot advance from loot to the gate fixture.")
		return
	%Region.text = run.region_info().name
	%Destination.text = run.region_info(int(run.s.region) + 1).name
	%Gate.travel = 0.0
	specimen = ""
	sources.clear()
	show_mode(Mode.MODS)

func show_mode(next: Mode) -> void:
	mode = next
	var labels: Dictionary = {}
	match mode:
		Mode.MODS:
			for id in run.gate_options():
				labels[id] = Gates.NAMES[id]
		Mode.SPECIMENS:
			for id in Gates.specimens(run.model.s.deck):
				labels[id] = ammo_label(id)
		Mode.SOURCES:
			for id in Gates.basics(run.model.s.deck):
				labels[id] = ammo_label(id)
		Mode.SERVICE:
			if paid_service():
				labels = {"bag": "수납 확장  ·  %d Cr" % run.Economy.BAG_PRICE, "copy": "보유 탄 1장 복제"}
		Mode.COPIES:
			for id in run.gate_copy_options():
				labels[id] = "%s · %d Cr" % [ammo_label(id), run.gate_copy_price(id)]
	if not labels.has(selected):
		selected = str(labels.keys()[0]) if not labels.is_empty() else ""
	if mode == Mode.SOURCES:
		selected = ""
	rebuild_options(labels)
	refresh()

func rebuild_options(labels: Dictionary) -> void:
	for child in %Options.get_children():
		%Options.remove_child(child)
		child.queue_free()
	buttons.clear()
	for id in labels:
		var button := template.duplicate() as Button
		button.name = "Option_" + str(id)
		set_option_label(button, str(labels[id]))
		button.tooltip_text = Gates.description(id) if mode == Mode.MODS else str(labels[id])
		if shelf_layout:
			var icon = button.get_node("Icon")
			icon.item_id = id
			icon.ammo = mode in [Mode.SPECIMENS, Mode.SOURCES, Mode.COPIES]
		button.pressed.connect(pick.bind(str(id)))
		%Options.add_child(button)
		buttons[id] = button
	%OptionsScroll.scroll_vertical = 0
	%OptionsScroll.scroll_horizontal = 0
	if not shelf_layout:
		var rows := ceili(float(labels.size()) / 2.0)
		%OptionsScroll.custom_minimum_size.y = clampi(rows * 51 - 7, 44, 146)

func set_option_label(button: Button, label: String) -> void:
	if shelf_layout:
		button.get_node("Caption").text = label
	else:
		button.text = label

func pick(id: String) -> void:
	selected = id
	if mode == Mode.SOURCES and sources.size() < 3 and sources.count(id) < run.model.s.deck.count(id):
		sources.append(id)
	refresh()

func ammo_label(id: String) -> String:
	var state: Dictionary = run.model.s
	var stat := Ammo.primary_stat(id, state)
	return "%s · %s %s" % [Ammo.AMMO[id].name, stat.label, stat.value]

func service_used() -> bool:
	return bool(run.s.get("gate_bag_used", false)) or bool(run.s.get("gate_ammo_used", false))

## Runs started before the run economy (older map saves) have no paid gate service.
func paid_service() -> bool:
	return run.Economy.enabled(run.s)

func can_copy() -> bool:
	return run.gate_copy_options().any(func(id): return run.can_buy_gate_copy(id))

func refresh() -> void:
	var ready := run.gate_ready()
	%ModifyStep.modulate = MUTED if ready or traveling or mode == Mode.DEPARTED else ACTIVE
	%ServiceStep.modulate = ACTIVE if ready and not traveling else MUTED
	%DepartStep.modulate = ACTIVE if traveling or mode == Mode.DEPARTED else MUTED
	%Gate.release_ready = ready or traveling
	%Gate.queue_redraw()
	%GateState.text = "차단문 개방 중" if traveling else "통과 완료" if mode == Mode.DEPARTED else "다음 구역 · 출발 대기" if ready else "다음 구역 · 차단문 잠김"
	if shelf_layout:
		%GateState.text = %GateState.text.get_slice(" · ", 1) if %GateState.text.contains(" · ") else %GateState.text
		%SelectionTitle.text = inspector_title()
		%ModifyStep.get_node("Line").visible = not ready and not traveling and mode != Mode.DEPARTED
		%ServiceStep.get_node("Line").visible = ready and not traveling
		%DepartStep.get_node("Line").visible = traveling or mode == Mode.DEPARTED
		%Departure.visible = mode == Mode.SERVICE
		%Departure.disabled = traveling
		%Shelf.visible = mode != Mode.DEPARTED
	%OptionsScroll.visible = not buttons.is_empty()
	%Back.visible = mode != Mode.SERVICE and mode != Mode.DEPARTED
	%Secondary.visible = (mode == Mode.SERVICE and not shelf_layout) or (mode == Mode.SOURCES and not sources.is_empty())
	%Secondary.disabled = traveling
	var primary := &"PrimaryButton" if shelf_layout else &"Primary"
	%Secondary.theme_type_variation = primary if mode == Mode.SERVICE else &""
	%Apply.theme_type_variation = &"" if mode == Mode.SERVICE else primary
	%Apply.disabled = false
	%Receipt.visible = mode == Mode.SERVICE or mode == Mode.COPIES
	%Receipt.text = upgrade_receipt() if %Receipt.visible else ""
	for id in buttons:
		var button: Button = buttons[id]
		button.set_pressed_no_signal(sources.has(id) if mode == Mode.SOURCES else id == selected)
		button.disabled = traveling
		if mode == Mode.SOURCES:
			var owned: int = run.model.s.deck.count(id)
			set_option_label(button, "%s (%d/%d)" % [ammo_label(id), sources.count(id), owned])
			button.disabled = sources.size() >= 3 or sources.count(id) >= owned
	%BeforeLabel.text = "현재"
	%AfterLabel.text = "적용 후"
	var deck: Array = run.model.s.deck
	var credits: int = run.s.credits
	match mode:
		Mode.MODS:
			%Condition.text = "무료 개조 1회"
			%Back.text = "개조 보류"
			%Apply.text = "견본 고르기" if selected == "production" else "개조 적용"
			%Apply.disabled = selected.is_empty()
			if selected == "production":
				show_values("기본탄 3장", "견본 탄환 3장", "가방 수량 유지 · 보유 특수탄을 견본으로 사용")
			elif selected.is_empty():
				show_values("개조 한도 도달", "변경 없음", "개조를 보류하고 재정비로 이동할 수 있습니다.")
			else:
				var state: Dictionary = run.model.s
				var detail := GateUI.growth_projection(state) if selected == "growth" else Gates.caution(selected)
				if selected == "efficiency":
					detail = "기본 발열 최저 1 · 연속 사격 추가 열 유지"
				show_values(Gates.summary(selected, state), Gates.summary(selected, state, true), detail)
		Mode.DEFER:
			%Condition.text = "무료 개조 보류"
			%Back.text = "돌아가기"
			%Apply.text = "보류하고 계속"
			show_values("무료 개조 가능", "재정비로 이동", "이 관문의 무료 개조는 사용하지 않습니다.")
		Mode.SPECIMENS:
			%Condition.text = "복제할 견본을 고르세요"
			%Back.text = "개조로"
			%Apply.text = "기본탄 고르기"
			%Apply.disabled = selected.is_empty()
			show_values("기본탄 3장", "견본 탄환 3장" if selected.is_empty() else "%s 3장" % Ammo.AMMO[selected].name, "견본은 가방에 남습니다.")
		Mode.SOURCES:
			%Condition.text = "교체할 기본탄  %d / 3" % sources.size()
			%Back.text = "견본으로"
			%Secondary.text = "한 장 취소"
			%Apply.text = "3장 교체"
			%Apply.disabled = not Gates.can_produce(run.model.s, specimen, sources)
			show_values("기본탄 %d장 선택" % sources.size(), "%s 3장" % Ammo.AMMO[specimen].name, "전체 탄약 %d장 유지" % deck.size())
		Mode.SERVICE:
			if not paid_service():
				%Condition.text = "보유 %d Cr" % credits
				%Secondary.text = "출발"
				%Apply.text = "정비 없음"
				%Apply.disabled = true
				show_values(%Region.text, %Destination.text, "이 등반에는 관문 유료 정비가 없습니다. 표찰에서 출발하세요.")
				return
			%Condition.text = "유료 정비 %s   ·   보유 %d Cr" % ["완료" if service_used() else "1회", credits]
			%Secondary.text = "출발"
			var bag := selected == "bag"
			%Apply.text = "수납 확장" if bag else "복제할 탄 고르기"
			%Apply.disabled = traveling or (not run.can_buy_gate_bag() if bag else not can_copy())
			var capacity: int = run.model.deck_limit()
			if service_used():
				%BeforeLabel.text = "보유 탄약"
				%AfterLabel.text = "잔액"
				show_values("가방 %d / %d발" % [deck.size(), capacity], "%d Cr" % credits, str(run.s.message))
			elif bag:
				var cost := run.Economy.BAG_PRICE
				var detail := "%d Cr · 탄약 지급 없음" % cost
				if not run.can_grow_bag():
					detail = "이 구역의 수납 확장 한도에 도달했습니다."
				elif credits < cost:
					detail = "%d Cr 부족" % (cost - credits)
				show_values("휴대 상한 %d발" % capacity, "휴대 상한 %d발" % mini(40, capacity + 2), detail)
			else:
				show_values("보유 탄약 %d발" % deck.size(), "보유 탄약 %d발" % (deck.size() + 1), "일반 12 Cr · 고급 24 Cr" if can_copy() else "가방 여유와 보유 크레딧을 확인하세요.")
		Mode.COPIES:
			%Condition.text = "복제할 보유 탄  ·  %d Cr" % credits
			%Back.text = "재정비로"
			%Apply.text = "1장 복제"
			%Apply.disabled = selected.is_empty() or not run.can_buy_gate_copy(selected)
			if not selected.is_empty():
				var count: int = deck.count(selected)
				var price := run.gate_copy_price(selected)
				show_values("%s %d장" % [Ammo.AMMO[selected].name, count], "%s %d장" % [Ammo.AMMO[selected].name, count + 1], "%d Cr 사용  ·  잔액 %d Cr" % [price, credits - price] if not %Apply.disabled else "가방 여유와 보유 크레딧을 확인하세요.")
		Mode.DEPARTED:
			%Condition.text = str(run.region_info().name)
			%Apply.text = "관문 다시 보기"
			%BeforeLabel.text = "출발"
			%AfterLabel.text = "도착"
			show_values(%Region.text, %Destination.text, "다음 구역 지도에 도착했습니다.")

func show_values(before: String, after: String, explanation: String) -> void:
	%BeforeValue.text = before
	%AfterValue.text = after
	%Explanation.text = explanation

func inspector_title() -> String:
	match mode:
		Mode.MODS: return str(Gates.NAMES.get(selected, "무료 개조"))
		Mode.DEFER: return "개조 보류"
		Mode.SPECIMENS, Mode.SOURCES: return "전용 탄약 생산"
		Mode.SERVICE:
			if not paid_service():
				return "출발 준비"
			if service_used():
				return "재정비 완료"
			return "수납 확장" if selected == "bag" else "탄환 복제"
		Mode.COPIES: return "탄환 복제" if selected.is_empty() else str(Ammo.AMMO[selected].name)
	return "통과 완료"

func upgrade_receipt() -> String:
	for event in range(run.s.log.size() - 1, -1, -1):
		var entry: Dictionary = run.s.log[event]
		if entry.action != "gate_upgrade":
			continue
		var id := str(entry.detail.choice)
		if id == "skip":
			return "무료 개조 보류"
		if id == "production":
			return "%s 3장 교체 완료" % Ammo.AMMO[entry.detail.ammo].name
		return "%s · %s" % [Gates.NAMES[id], Gates.summary(id, run.model.s)]
	return ""

func apply() -> void:
	if %Apply.disabled or traveling:
		return
	match mode:
		Mode.MODS:
			if selected == "production":
				show_mode(Mode.SPECIMENS)
			elif command("gate", selected):
				show_mode(Mode.SERVICE)
		Mode.DEFER:
			if command("gate", "skip"):
				show_mode(Mode.SERVICE)
		Mode.SPECIMENS:
			specimen = selected
			sources.clear()
			show_mode(Mode.SOURCES)
		Mode.SOURCES:
			if command("gate_production", sources.duplicate(), specimen):
				show_mode(Mode.SERVICE)
		Mode.SERVICE:
			if selected == "copy":
				show_mode(Mode.COPIES)
			elif command("gate_bag"):
				refresh()
		Mode.COPIES:
			if command("gate_copy", selected):
				show_mode(Mode.SERVICE)
		Mode.DEPARTED:
			load_gate()

func back() -> void:
	if traveling:
		return
	match mode:
		Mode.MODS:
			deferred_choice = selected
			show_mode(Mode.DEFER)
		Mode.DEFER:
			selected = deferred_choice
			show_mode(Mode.MODS)
		Mode.SPECIMENS:
			selected = "production"
			show_mode(Mode.MODS)
		Mode.SOURCES:
			selected = specimen
			show_mode(Mode.SPECIMENS)
		Mode.COPIES:
			selected = "copy"
			show_mode(Mode.SERVICE)

func secondary() -> void:
	if mode == Mode.SOURCES and not sources.is_empty():
		sources.pop_back()
		refresh()
	elif mode == Mode.SERVICE and not traveling and run.gate_ready():
		depart()

func departure_control() -> Button:
	return %Departure if shelf_layout else %Secondary

func depart() -> void:
	traveling = true
	refresh()
	await animate_departure()
	if live_host != null:
		# Fully black now: the main handler enters the next region and redraws the map.
		traveling = false
		if not live_host._campaign_action("gate_depart"):
			%Gate.travel = 0.0
			refresh()
		return
	traveling = false
	if command("gate_depart"):
		show_mode(Mode.DEPARTED)
	else:
		%Gate.travel = 0.0
		refresh()

func animate_departure() -> void:
	var motion := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	motion.tween_property(%Gate, "travel", 1.0, travel_time)
	await motion.finished

func departure_visual_complete() -> bool:
	return %Gate.travel == 1.0

func verify(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", label)

func settle() -> void:
	for step in range(6):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

func touch(button: Button) -> void:
	verify(button.is_visible_in_tree() and not button.disabled, "available " + str(button.name))
	button.grab_focus()
	await settle()
	var point := button.get_global_transform_with_canvas() * (button.size * 0.5)
	for pressed in [true, false]:
		var event := InputEventScreenTouch.new()
		event.index = 0
		event.position = point
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame
	await settle()

func capture(output: String, name: String, extent: Vector2i) -> void:
	await settle()
	var frame := get_viewport().get_texture().get_image()
	verify(frame.get_size() == extent and frame.save_png(output.path_join(name + ".png")) == OK, "capture " + name)
	for node in [%Apply, %Effect, %OptionsScroll, %Destination]:
		if node.is_visible_in_tree():
			verify(get_viewport_rect().grow(1).encloses(node.get_global_rect()), "visible " + str(node.name))
	if shelf_layout and %OptionsScroll.visible:
		verify(not %OptionsScroll.get_global_rect().intersects(%Apply.get_global_rect()), "shelf clears the inspector action")
		var exit := departure_control()
		if exit.visible:
			verify(not %OptionsScroll.get_global_rect().intersects(exit.get_global_rect()), "shelf clears departure action")

func capture_review(output: String) -> void:
	for extent in [Vector2i(1280, 800), Vector2i(1008, 454), Vector2i(2340, 1080)]:
		get_window().size = extent
		var suffix := "%dx%d" % [extent.x, extent.y]
		load_gate()
		verify(run.s.phase == "gate" and not run.gate_ready(), "actual boss loot leads to gate")
		await capture(output, "upgrade_" + suffix, extent)
		var before: Dictionary = run.model.s.gate_mods.duplicate()
		await touch(buttons["efficiency"])
		verify(run.model.s.gate_mods == before, "highlight does not apply an upgrade")
		await touch(%Apply)
		verify(run.gate_ready() and Gates.level(run.model.s, "efficiency") == 1, "real upgrade applied once")
		await capture(output, "service_" + suffix, extent)
		var money: int = run.s.credits
		var limit: int = run.model.deck_limit()
		await touch(%Apply)
		verify(run.model.deck_limit() == limit + 2 and run.s.credits == money - run.Economy.BAG_PRICE, "storage service uses actual rules")
		verify(%Apply.disabled and not can_copy(), "paid service shares its one-use lock")
		await touch(departure_control())
		while traveling:
			await get_tree().process_frame
		verify(mode == Mode.DEPARTED and run.s.phase == "map" and run.s.region == 2 and departure_visual_complete(), "departure cue ends and actual next map is entered")
		await capture(output, "depart_" + suffix, extent)
	get_window().size = Vector2i(1280, 800)
	load_gate()
	await settle()
	await touch(buttons["production"])
	await touch(%Apply)
	await touch(%Apply)
	verify(mode == Mode.SOURCES and %Apply.disabled, "production requires three source rounds")
	var deck_before: Array = run.model.s.deck.duplicate()
	var source_id := str(buttons.keys()[0])
	await touch(buttons[source_id])
	await touch(%Secondary)
	verify(sources.is_empty() and run.model.s.deck == deck_before, "undo changes only the selection")
	for index in range(3):
		await touch(buttons[source_id])
	await capture(output, "production_1280x800", Vector2i(1280, 800))
	await touch(%Apply)
	verify(run.model.s.deck.size() == deck_before.size() and run.model.s.deck.count(specimen) == deck_before.count(specimen) + 3, "production swaps exactly three rounds")
	await touch(buttons["copy"])
	await touch(%Apply)
	var copy := selected
	var cost := run.gate_copy_price(copy)
	var before_count: int = run.model.s.deck.count(copy)
	var balance: int = run.s.credits
	await touch(%Apply)
	verify(run.model.s.deck.count(copy) == before_count + 1 and run.s.credits == balance - cost and not run.can_buy_gate_bag(), "copy uses real cost and consumes the shared visit service")
	load_gate()
	await settle()
	await touch(buttons["efficiency"])
	await touch(%Back)
	verify(mode == Mode.DEFER and not run.gate_ready(), "defer requires confirmation")
	await touch(%Back)
	verify(mode == Mode.MODS and not run.gate_ready() and selected == "efficiency", "canceling defer preserves the selected modification")
	await touch(%Back)
	await touch(%Apply)
	verify(run.gate_ready() and run.model.s.gate_mods.is_empty(), "confirmed defer opens service without upgrading")
	run.s.credits = 5
	refresh()
	var departure := departure_control()
	verify(%Apply.disabled and not departure.disabled and %Explanation.text.contains("13 Cr 부족"), "low credits block paid service while leaving departure available")
	print("GATE REVIEW COMPLETE checks=%d failures=%d" % [checks, failures])
	get_tree().quit(1 if failures else 0)
