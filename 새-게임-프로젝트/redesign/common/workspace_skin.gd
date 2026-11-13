extends RefCounted
## Warm skin for the full-screen workspace overlay outside combat (launch pass 2026-11-12).
## The overlay (screen.gd::_workspace) was built for the teal combat console; the menus and
## detail pages opened from rewards, the shop, the workshop and the gate now use the same
## dark brass material as those places (workbench/theme.tres). Layout and names are unchanged.
const THEME = preload("res://redesign/workbench/theme.tres")
const BACKGROUND := Color(0.072, 0.063, 0.052, 1)
const HEADER := Color(0.11, 0.098, 0.08, 1)
const RULE := Color(0.36, 0.31, 0.23, 1)
const GOLD := Color("e9c27f")
const IVORY := Color("ebe2d1")
const MUTED := Color("a59c8b")
## Console colours used by screen.gd labels (ACCENT, MUTED, INK) and their warm counterparts.
const REMAP := {"5cdddc": GOLD, "8fb0b0": MUTED, "e4f2ee": IVORY}

static func apply(overlay: Control) -> void:
	if not is_instance_valid(overlay) or overlay.is_queued_for_deletion(): return
	overlay.theme = THEME
	var controls: Array = [overlay]
	controls.append_array(overlay.find_children("*", "Control", true, false))
	for item in controls:
		if item == overlay or str(item.name) == "WorkspaceHeader":
			var surface := StyleBoxFlat.new()
			surface.bg_color = BACKGROUND if item == overlay else HEADER
			surface.anti_aliasing = false
			if item != overlay:
				surface.border_color = RULE
				surface.border_width_bottom = 1
				surface.set_content_margin_all(12)
			item.add_theme_stylebox_override("panel", surface)
	recolor(overlay)
	if overlay.get_meta("card", false): card(overlay)

## Card layout for short menus and notes (screen.gd::_workspace_card): the place stays visible,
## dimmed, and the overlay's frame becomes a centred panel sized to its content.
static func card(overlay: Control) -> void:
	var margin := overlay.get_child(0) as MarginContainer
	var header := overlay.find_child("WorkspaceHeader", true, false) as Control
	var scroll := overlay.find_child("WorkspaceScroll", true, false) as ScrollContainer
	if margin == null or header == null or scroll == null or scroll.get_child_count() == 0: return
	var column := scroll.get_child(0) as Control
	var shade := StyleBoxFlat.new()
	shade.bg_color = Color(0.02, 0.016, 0.012, 0.84)
	overlay.add_theme_stylebox_override("panel", shade)
	var plate := Panel.new()
	plate.name = "WorkspaceCard"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var surface := StyleBoxFlat.new()
	surface.bg_color = Color(BACKGROUND.r, BACKGROUND.g, BACKGROUND.b, 0.98)
	surface.border_color = RULE
	surface.set_border_width_all(1)
	surface.border_width_top = 2
	surface.set_expand_margin_all(16)
	surface.anti_aliasing = false
	plate.add_theme_stylebox_override("panel", surface)
	margin.add_child(plate)
	margin.move_child(plate, 0)
	var clear := StyleBoxFlat.new()
	clear.bg_color = Color(0, 0, 0, 0)
	clear.border_color = RULE
	clear.border_width_bottom = 1
	clear.content_margin_bottom = 10
	header.add_theme_stylebox_override("panel", clear)
	var width := minf(720.0, overlay.size.x - 96.0)
	var side := maxf(48.0, (overlay.size.x - width) * 0.5)
	margin.add_theme_constant_override("margin_left", ceili(side))
	margin.add_theme_constant_override("margin_right", ceili(side))
	margin.modulate.a = 0.0
	# Wrapped labels need the card width before their height is known.
	await overlay.get_tree().process_frame
	await overlay.get_tree().process_frame
	if not is_instance_valid(overlay) or overlay.is_queued_for_deletion(): return
	var needed := header.get_combined_minimum_size().y + 12.0 + column.get_combined_minimum_size().y + 6.0
	var height := minf(needed, overlay.size.y - 72.0)
	var edge := maxf(36.0, (overlay.size.y - height) * 0.5)
	margin.add_theme_constant_override("margin_top", floori(edge))
	margin.add_theme_constant_override("margin_bottom", floori(edge))
	margin.modulate.a = 1.0

## Console label colours and the console's orange primary key become their warm counterparts.
## Also used by the common window for content built with screen.gd::_label/_primary_button.
static func recolor(root: Control) -> void:
	if not is_instance_valid(root): return
	for item in root.find_children("*", "Control", true, false):
		if item is Label and item.has_theme_color_override("font_color"):
			var current: Color = item.get_theme_color("font_color")
			for key in REMAP:
				if current.is_equal_approx(Color(key)): item.add_theme_color_override("font_color", REMAP[key])
		elif item is Button and item.has_theme_stylebox_override("normal") and item.has_theme_color_override("font_color"):
			if item.get_theme_color("font_color").is_equal_approx(Color("1c0903")):
				for state in ["normal", "hover", "pressed", "focus"]: item.remove_theme_stylebox_override(state)
				for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]: item.remove_theme_color_override(state)
				item.theme_type_variation = &"PrimaryButton"
		elif item is PanelContainer and item.has_theme_stylebox_override("panel") and str(item.name) != "WorkspaceHeader":
			# screen.gd::_panel cards: teal console surface to the warm card surface.
			var box: StyleBox = item.get_theme_stylebox("panel")
			if box is StyleBoxFlat and box.bg_color.b > box.bg_color.r + 0.02:
				var warm: StyleBoxFlat = box.duplicate()
				warm.bg_color = Color(HEADER.r, HEADER.g, HEADER.b, box.bg_color.a)
				warm.border_color = RULE
				item.add_theme_stylebox_override("panel", warm)
