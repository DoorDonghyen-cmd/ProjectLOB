extends "res://redesign/console_dialog.gd"
## Common window (2026-11-08): 설정·조작 안내·게임 규칙 in the workshop/gate/depot theme.
## Keeps the console dialog's behaviour (Esc and back close it, focus stays inside,
## the frame fits the safe area, focus returns to the opener) and drops its teal skin.

## Builders rename the content column (SettingsDialog, FirstGuide...), so keep a reference.
var content: VBoxContainer

func setup(owner_screen: Control, title: String, small: bool) -> VBoxContainer:
	host = owner_screen
	compact = small
	var previous := get_viewport().gui_get_focus_owner()
	if previous != null: return_focus = weakref(previous)
	%Title.text = title
	for button in [%DialogClose, %DialogCancel, %DialogConfirm]:
		button.pressed.connect(func(): host.feedback.play("click"))
	content = %DialogContent
	content.set_meta("dialog", self)
	_fit()
	return content

func subtitle(text: String) -> void:
	%Subtitle.text = text
	%Subtitle.visible = not text.is_empty()

## Same as the console dialog's fit, without its fixed 330 height for confirmations:
## fit_content() sizes every common window to its content.
func _fit() -> void:
	if not is_node_ready(): return
	var desired: Vector2 = get_meta("preferred_size", Vector2(660, 480) if compact else Vector2(960, 660))
	var safe := preload("res://redesign/ui_readability.gd").available(self)
	var extent := desired.min((safe.size - Vector2(32, 32)).max(Vector2(1, 1)))
	var shift := safe.get_center() - size * 0.5
	%Frame.offset_left = shift.x - floorf(extent.x / 2)
	%Frame.offset_right = shift.x + ceilf(extent.x / 2)
	%Frame.offset_top = shift.y - floorf(extent.y / 2)
	%Frame.offset_bottom = shift.y + ceilf(extent.y / 2)

## Shrinks the frame to its content once wrapped text has its height (the preferred size
## stays the upper bound, so long text still scrolls).
func fit_content() -> void:
	%Frame.modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree(): return
	# Content built with screen.gd helpers carries the teal console colours.
	preload("res://redesign/common/workspace_skin.gd").recolor(content)
	var preferred: Vector2 = get_meta("preferred_size", Vector2(960, 660))
	var needed: float = %Frame.get_combined_minimum_size().y + content.get_combined_minimum_size().y + 2.0
	set_meta("preferred_size", Vector2(preferred.x, minf(preferred.y, needed)))
	_fit()
	%Frame.modulate.a = 1.0
