extends Control
## Shared, editor-visible modal shell. Content is supplied by the current screen.
signal confirmed
signal canceled
var compact := false
var confirmation := false
var return_focus: WeakRef
var host: Control

func _ready() -> void:
	set_meta("lob_modal", true)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_clear_preview()
	%DialogClose.pressed.connect(func(): canceled.emit())
	%DialogCancel.pressed.connect(func(): canceled.emit())
	%DialogConfirm.pressed.connect(func(): confirmed.emit())
	confirmed.connect(close)
	canceled.connect(close)
	resized.connect(_fit)
	get_viewport().gui_focus_changed.connect(_guard_focus)
	%DialogActions.hide()
	_focus.call_deferred()

func _clear_preview() -> void:
	for child in %DialogContent.get_children(): child.queue_free()

func setup(owner_screen: Control, title: String, small: bool) -> VBoxContainer:
	host = owner_screen
	compact = small
	var previous := get_viewport().gui_get_focus_owner()
	if previous != null: return_focus = weakref(previous)
	%Title.text = title
	%Title.add_theme_font_size_override("font_size", host._scaled(26))
	var skin = preload("res://redesign/combat_pixel_skin.gd")
	for button in [%DialogClose, %DialogCancel, %DialogConfirm]:
		for state in ["normal", "hover", "pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(state, skin.box("primary" if button == %DialogConfirm else "button", state))
		button.add_theme_font_override("font", skin.FONT)
		button.add_theme_font_size_override("font_size", host._scaled(20))
		button.pressed.connect(func(): host.feedback.play("click"))
	%DialogContent.set_meta("dialog", self)
	_fit()
	return %DialogContent

func ask(accept_text: String, cancel_text: String, callback: Callable) -> void:
	confirmation = true
	%DialogActions.show()
	%DialogConfirm.text = accept_text
	%DialogCancel.text = cancel_text
	confirmed.connect(callback)
	_fit()

func _fit() -> void:
	if not is_node_ready(): return
	var desired: Vector2 = get_meta("preferred_size", Vector2(660, 480) if compact else Vector2(960, 660))
	if confirmation: desired.y = 330
	var extent := desired.min((size - Vector2(32, 32)).max(Vector2(1, 1)))
	%Frame.offset_left = -floorf(extent.x / 2)
	%Frame.offset_right = ceilf(extent.x / 2)
	%Frame.offset_top = -floorf(extent.y / 2)
	%Frame.offset_bottom = ceilf(extent.y / 2)

func _topmost() -> bool:
	if not is_visible_in_tree() or is_queued_for_deletion(): return false
	for child in get_parent().get_children():
		if child != self and child.has_meta("lob_modal") and child.visible and child.get_index() > get_index() and not child.is_queued_for_deletion(): return false
	return true

func _focus() -> void:
	if _topmost(): (%DialogCancel if confirmation else %DialogClose).grab_focus()

func _guard_focus(control: Control) -> void:
	if _topmost() and control != null and not is_ancestor_of(control): _focus.call_deferred()

func _input(event: InputEvent) -> void:
	if not _topmost(): return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		canceled.emit()
	elif event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_focus_prev"):
		var controls: Array[Control] = []
		for item in find_children("*", "Control", true, false):
			if item.is_visible_in_tree() and item.focus_mode == Control.FOCUS_ALL and not (item is BaseButton and item.disabled): controls.append(item)
		if controls.is_empty(): return
		var current := controls.find(get_viewport().gui_get_focus_owner())
		var step := -1 if event.is_action_pressed("ui_focus_prev") else 1
		controls[posmod(current + step, controls.size())].grab_focus()
		get_viewport().set_input_as_handled()

func close() -> void:
	hide()
	queue_free()

func get_ok_button() -> Button:
	return %DialogConfirm if confirmation else %DialogClose

func get_cancel_button() -> Button:
	return %DialogCancel if confirmation else %DialogClose

func _exit_tree() -> void:
	if return_focus != null:
		var control = return_focus.get_ref()
		if is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree() and is_instance_valid(host): host._focus_control.call_deferred(control)
