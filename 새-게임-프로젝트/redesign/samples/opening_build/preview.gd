extends Control

const Campaign = preload("res://redesign/campaign.gd")
const PartsCampaign = preload("res://redesign/samples/opening_build/parts_campaign.gd")
const Game = preload("res://redesign/main.tscn")
const FONT = preload("res://redesign/combat_pixel_font.tres")
const SEED := 731042
const OPTIONS := [
	["CoreStart", "A  기존 성장 코어"],
	["PartsStart", "B  첫 파츠 보상"],
	["SupportStart", "C  첫 파츠 + 지원탄 장전"],
	["FollowUpStart", "D  지원탄 장전 + 두 번째 파츠 후보"],
]

var chooser: Control
var game

func _ready() -> void:
	var background := ColorRect.new()
	background.color = Color("141610")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	chooser = center
	var stack := VBoxContainer.new()
	stack.custom_minimum_size.x = 380
	stack.add_theme_constant_override("separation", 12)
	center.add_child(stack)
	var ui_theme := Theme.new()
	ui_theme.default_font = FONT
	ui_theme.default_font_size = 18
	stack.theme = ui_theme
	var heading := Label.new()
	heading.text = "첫 보상 비교"
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color("dfca9a"))
	stack.add_child(heading)
	var context := Label.new()
	context.text = "리벳 · 운반복 · 시드 %d" % SEED
	stack.add_child(context)
	for option in range(OPTIONS.size()):
		var button := Button.new()
		button.name = OPTIONS[option][0]
		button.text = OPTIONS[option][1]
		button.custom_minimum_size.y = 48
		button.pressed.connect(start.bind(option))
		stack.add_child(button)
	var hint := Label.new()
	hint.text = "F8 · 비교 선택으로 돌아가기"
	stack.add_child(hint)
	stack.get_node("CoreStart").grab_focus()

func start(option: int) -> void:
	if is_instance_valid(game): return
	var run: Campaign = Campaign.new() if option == 0 else PartsCampaign.new()
	if run is PartsCampaign: run.mode = option - 1
	run.start("single", SEED, 0, "balanced", 4, "carrier", true)
	run.advance_departure(true)
	game = Game.instantiate()
	game.save_enabled = false
	game.debug_session = true
	game.campaign = run
	game.model = run.model
	game.page = "run"
	chooser.hide()
	add_child(game)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8 and is_instance_valid(game) and not game.busy:
		get_viewport().set_input_as_handled()
		show_comparison.call_deferred()

func show_comparison() -> void:
	if not is_instance_valid(game): return
	remove_child(game)
	game.queue_free()
	game = null
	chooser.show()
	chooser.find_child("CoreStart", true, false).grab_focus()
