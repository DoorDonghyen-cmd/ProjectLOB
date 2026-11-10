extends "res://redesign/workbench/screen.gd"
## Standalone review fixture: actual Campaign commands, no load/save operations.
var workbench_memory: Dictionary = {}
var busy := false
var save_error := ""

func _ready() -> void:
	get_window().size_changed.connect(_viewport)
	_viewport()
	$ReviewLayer/GradeStudy/Center/Panel/Content/Header/Close.pressed.connect(_close_grades)
	reset_preview()

func _viewport() -> void:
	var window := get_window()
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_size = Vector2i.ZERO
	window.content_scale_factor = preload("res://redesign/ui_readability.gd").scale_for(window.size)

func reset_preview() -> void:
	# Recreate the scene to disconnect the previous bindings. F1 is a review control.
	if campaign != null:
		get_tree().reload_current_scene()
		return
	var owner = Campaign.new()
	owner.start("burst", 17, 0, "balanced", Campaign.Content.RouteMap.VERSION, "carrier", true)
	var rooms: Array = owner.current_nodes().filter(func(room): return Campaign.Content.room_kind(room) == "workshop")
	owner.s.node = rooms[0].id
	owner.s.phase = "supply"
	owner.s.resolved = false
	owner.s.credits = 70
	owner.model.s.deck = ["basic_p3", "basic_p3", "basic_p3", "basic_p3", "basic_p2", "basic_p2", "basic_p2", "basic_p2", "pierce_p3", "pierce_p3", "pierce_p3", "pierce_p3", "precise_p2", "precise_p2", "bore", "bore", "disrupt", "disrupt", "charge", "charge"]
	campaign = owner
	selected = "basic_p3"
	configure(self, self)

func _refresh() -> void:
	super._refresh()
	$Header/Budget.text = ("정비 완료" if campaign.s.resolved else "무료 정비 1회") + " · 시안 F1 초기화 / F2 등급 비교"
	$Header/Exit.text = "시안 닫기"

func _campaign_action(command: String, value = "", extra := "", replacement := "") -> bool:
	var accepted := false
	match command:
		"resolve": accepted = campaign.resolve(str(value), extra, replacement)
		"tune": accepted = campaign.tune(int(value), extra)
	_refresh()
	return accepted

func _leave() -> void: get_tree().quit()
func deck() -> void: pass
func archive() -> void: pass
func _settings() -> void: pass
func _to_menu() -> void: get_tree().quit()

func _close_grades() -> void:
	$ReviewLayer/GradeStudy.hide()
	$Inspector/Inset/Actions/Apply.grab_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1: reset_preview()
		elif event.keycode == KEY_F2:
			if $ReviewLayer/GradeStudy.visible: _close_grades()
			else:
				upgrade_dialog().dismiss()
				$ReviewLayer/GradeStudy.show()
				$ReviewLayer/GradeStudy/Center/Panel/Content/Header/Close.grab_focus()
		elif event.keycode == KEY_ESCAPE and $ReviewLayer/GradeStudy.visible:
			_close_grades()
			get_viewport().set_input_as_handled()
	else: super._input(event)
