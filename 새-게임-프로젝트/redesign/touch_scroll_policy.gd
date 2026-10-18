extends Node
## Allow native ScrollContainer touch gestures through decorative/card containers.
## Native scroll notifications cancel a button press once the finger starts moving.
const HandButton = preload("res://redesign/ammo_hand_button.gd")
const Magazine = preload("res://redesign/magazine_view.gd")

func _ready() -> void:
	get_tree().node_added.connect(_added)
	for control in get_parent().find_children("*", "Control", true, false): _configure(control)

func _added(node: Node) -> void:
	if node is Control and get_parent().is_ancestor_of(node): _configure.call_deferred(node)

func _configure(control: Variant) -> void:
	if not is_instance_valid(control) or not control.is_inside_tree(): return
	if control is ScrollContainer:
		control.scroll_deadzone = 12
		return
	# These controls own a drag/edit gesture; do not hand it to the page scroll.
	if control is HandButton or control is Magazine or control is Range or control is LineEdit or control is TextEdit or control is OptionButton: return
	var parent: Node = control.get_parent()
	while parent != null and parent != get_parent():
		if parent is ScrollContainer:
			if control.mouse_filter == Control.MOUSE_FILTER_STOP:
				control.mouse_filter = Control.MOUSE_FILTER_PASS
			return
		parent = parent.get_parent()
