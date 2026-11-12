extends Control

const Trial = preload("res://redesign/samples/opening_build/early_parts_campaign.gd")
const Game = preload("res://redesign/main.tscn")
const PIXEL_FONT = preload("res://redesign/combat_pixel_font.tres")
const ActionTheme = preload("res://redesign/ui/dark_primary.tres")
const Data = preload("res://redesign/content.gd")
const INVESTMENT_ROUTE := "res://redesign/samples/opening_build/striker_shop_route.json"

var chooser: Control
var hint: Label
var game: Control
var shop_menu: Control
var shop_run: Trial
var shop_plan: Dictionary

func _ready() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("151613")
	backdrop.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(backdrop)
	var column := _menu_column()
	chooser = column.get_parent()
	var title := Label.new()
	title.text = "1구역 · 첫 파츠 보상 비교"
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color("dfca9a"))
	column.add_child(title)
	var context := Label.new()
	context.text = "두 번째 승리 보상에서 시작 · 다음 목적지 사수 매복"
	column.add_child(context)
	for gun: String in Trial.FIRST_PARTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		column.add_child(row)
		var label := Label.new()
		label.text = str(Data.GUNS[gun].name)
		label.custom_minimum_size.x = 90
		row.add_child(label)
		_add_choice(row, gun, false, "현재 보상", 122)
		_add_choice(row, gun, true, str(Data.PARTS[Trial.FIRST_PARTS[gun]].name) + " 추가", 202)
	_button(column, "Investment", "2구역 · 제3 격발기 투자 비교", _open_investment)
	hint = Label.new()
	hint.text = "F8 · 비교 선택으로 돌아가기"
	column.add_child(hint)
	chooser.find_child("single_trial", true, false).grab_focus()

func _menu_column() -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	column.theme = ActionTheme.duplicate()
	column.theme.default_font = PIXEL_FONT
	column.theme.default_font_size = 18
	center.add_child(column)
	return column

func _button(parent: Container, id: String, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = id
	button.text = text
	button.custom_minimum_size.y = 48
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _add_choice(row: HBoxContainer, gun: String, trial: bool, title: String, width: int) -> void:
	var button := _button(row, gun + ("_trial" if trial else "_current"), title, _start.bind(gun, trial))
	button.custom_minimum_size.x = width

func _start(gun: String, trial: bool) -> void:
	if is_instance_valid(game): return
	var run := Trial.new()
	run.offer_enabled = trial
	if not run.prepare_checkpoint(gun):
		hint.text = "현재 전투 규칙에서 시작 지점을 불러오지 못했습니다."
		return
	_mount(run)
	if trial: _show_first_part(run)

func _mount(run: Trial) -> void:
	game = Game.instantiate()
	game.save_enabled = false
	game.debug_session = true
	game.campaign = run
	game.model = run.model
	game.page = "run"
	chooser.hide()
	add_child(game)

func _open_investment() -> void:
	var plan: Variant = JSON.parse_string(FileAccess.get_file_as_string(INVESTMENT_ROUTE))
	shop_run = Trial.new()
	if not plan is Dictionary or not shop_run.prepare_investment(plan):
		hint.text = "상점까지의 비교 경로를 재생하지 못했습니다."
		shop_run = null
		return
	shop_plan = plan
	var index := _shop_offer()
	if index < 0:
		hint.text = "비교할 파츠가 상점에 없습니다."
		shop_run = null
		return
	var column := _menu_column()
	shop_menu = column.get_parent()
	chooser.hide()
	var title := Label.new()
	title.text = "2구역 · 제3 격발기 투자 비교"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color("dfca9a"))
	column.add_child(title)
	var balance := Label.new()
	balance.text = "%s · %d Cr" % [shop_run.node().name, int(shop_run.s.credits)]
	column.add_child(balance)
	var offer: Dictionary = shop_run.s.offers[index]
	_button(column, "Keep", "제3 격발기 유지 · ×3", _take_investment.bind("keep"))
	_button(column, "Upgrade", "제3 격발기 ★2 · ×3 → ×3.5 · %d Cr" % Trial.StrikerUpgrade.PRICE, _take_investment.bind("upgrade")).disabled = not shop_run.can_upgrade_striker()
	_button(column, "Buy", "%s 구매 · %d Cr" % [Data.PARTS[offer.id].name, int(offer.price)], _take_investment.bind("buy")).disabled = int(shop_run.s.credits) < int(offer.price)
	_button(column, "Back", "돌아가기", _close_investment).grab_focus()

func _shop_offer() -> int:
	return shop_run.s.offers.find_custom(func(offer): return offer.type == "part" and offer.id == shop_plan.purchase and not offer.sold)

func _take_investment(choice: String) -> void:
	if choice == "upgrade" and not shop_run.upgrade_striker(): return
	if choice == "buy" and not shop_run.buy(_shop_offer()): return
	var run := shop_run
	if not run.leave() or not run.enter(int(shop_plan.next_node)):
		_close_investment()
		hint.text = "상점 다음 전투에 진입하지 못했습니다."
		return
	_close_investment()
	_mount(run)

func _close_investment() -> void:
	shop_menu.hide()
	shop_menu.queue_free()
	shop_menu = null
	shop_run = null
	chooser.show()
	chooser.find_child("Investment", true, false).grab_focus()

func _show_first_part(run: Trial) -> void:
	var id: String = Trial.FIRST_PARTS[run.s.gun]
	var card_name := "city_reward_" + id
	var card := game.find_child(card_name, true, false) as Button
	if card == null: return
	# The trial offer needs to be visible before the horizontal reward row scrolls.
	var offers := card.get_parent()
	offers.move_child(card, 0)
	offers.child_entered_tree.connect(func(child: Node):
		if child.name == card_name: offers.move_child.call_deferred(child, 0))

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8 and is_instance_valid(game) and not game.busy:
		get_viewport().set_input_as_handled()
		_show_comparison.call_deferred()

func _show_comparison() -> void:
	if not is_instance_valid(game): return
	remove_child(game)
	game.queue_free()
	game = null
	chooser.show()
	chooser.find_child("single_trial", true, false).grab_focus()
