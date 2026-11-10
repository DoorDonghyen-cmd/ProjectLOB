extends Node
## Native UI pixels, integer enlargement and shared typography for noncombat screens.
const FONT = preload("res://redesign/combat_pixel_font.tres")
var host: Control
var queued := false

static func scale_for(extent: Vector2i) -> float:
	return maxf(1.0, floorf(minf(extent.x / 1008.0, extent.y / 454.0)))

static func font_size(requested: int) -> int:
	return maxi(16, int(floorf((requested + 4.0) / 16.0)) * 16)

static func safe_rect(extent: Vector2i, device_safe: Rect2i, factor: float) -> Rect2:
	var full := Rect2i(Vector2i.ZERO, extent)
	var safe := full.intersection(device_safe) if device_safe.has_area() else full
	return Rect2(Vector2(safe.position) / factor, Vector2(safe.size) / factor)

static func available(control: Control) -> Rect2:
	var window := control.get_window()
	var safe := DisplayServer.get_display_safe_area() if OS.has_feature("android") else Rect2i(Vector2i.ZERO,window.size)
	return safe_rect(window.size, safe, window.content_scale_factor)

func _ready() -> void:
	host = get_parent()
	get_tree().node_added.connect(_added)
	request()

func _added(node: Node) -> void:
	if node is Control and host.is_ancestor_of(node): request()

func request() -> void:
	if queued: return
	queued = true
	apply.call_deferred()

func apply() -> void:
	queued = false
	if not is_instance_valid(host) or not host.is_inside_tree(): return
	for item in host.find_children("*", "Control", true, false):
		# Combat owns its existing native HUD typography and scaling.
		if is_instance_valid(host.campaign_hud) and host.campaign_hud.is_ancestor_of(item): continue
		if item is Label or item is Button or item is LineEdit:
			item.add_theme_font_override("font", FONT)
			item.add_theme_font_size_override("font_size", font_size(item.get_theme_font_size("font_size")))
		elif item is RichTextLabel:
			for key in ["normal", "bold", "italics", "bold_italics", "mono"]:
				item.add_theme_font_override(key + "_font", FONT)
				item.add_theme_font_size_override(key + "_font_size", font_size(item.get_theme_font_size(key + "_font_size")))
