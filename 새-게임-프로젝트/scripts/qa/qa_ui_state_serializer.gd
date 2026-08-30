class_name QAUIStateSerializer
extends RefCounted

const PlaytestLoggerScript := preload("res://scripts/core/playtest_logger.gd")


static func screen_id(scene) -> String:
	if scene == null:
		return "unavailable"
	if find_visible_button(scene, "계속 오른다") != null:
		return "section_transition"
	if is_instance_valid(scene._debriefing_overlay) and scene._debriefing_overlay.visible:
		return "debriefing"
	if is_instance_valid(scene._combat_overlay):
		var result_overlay: Control = scene._combat_overlay._result_overlay
		if is_instance_valid(result_overlay) and result_overlay.visible:
			if is_instance_valid(scene._combat_overlay._draft_container) \
					and scene._combat_overlay._draft_container.visible:
				return "reward"
			return "combat_result"
	if is_instance_valid(scene._maintenance_overlay) and scene._maintenance_overlay.visible:
		if int(scene._maintenance_overlay._node_kind) == int(scene._maintenance_overlay.NodeKind.SHOP):
			return "shop"
		return "maintenance"
	if is_instance_valid(scene._combat_margin) and scene._combat_margin.visible \
			and is_instance_valid(scene._combat_overlay) and scene._combat_overlay.visible:
		return "combat"
	if is_instance_valid(scene._map_overlay) and scene._map_overlay.visible:
		return "map"
	if is_instance_valid(scene._loadout_overlay) and scene._loadout_overlay.visible:
		return "loadout"
	if is_instance_valid(scene._section_selector_overlay) and scene._section_selector_overlay.visible:
		return "section_selector"
	if is_instance_valid(scene._title_overlay) and scene._title_overlay.visible:
		return "title"
	return "unknown"


static func find_visible_button(root: Node, text_fragment: String) -> Button:
	if root is Button:
		var button := root as Button
		if button.visible and button.text.contains(text_fragment):
			return button
	for child in root.get_children():
		var found := find_visible_button(child, text_fragment)
		if found != null:
			return found
	return null


static func serialize(scene, checkpoint_id: String, legal_actions: Array[Dictionary] = []) -> Dictionary:
	var current_screen := screen_id(scene)
	var root: Control = _screen_root(scene, current_screen)
	var controls: Array[Dictionary] = []
	if is_instance_valid(root):
		_collect_controls(root, root, current_screen, controls)

	var state := {
		"schema_version": 1,
		"checkpoint_id": checkpoint_id,
		"screen": current_screen,
		"controls": controls,
		"legal_actions": legal_actions.duplicate(true),
	}
	if current_screen == "shop":
		state["shop"] = shop_state(scene._maintenance_overlay)
	elif current_screen == "reward":
		state["reward"] = reward_state(scene._combat_overlay)
	return state


static func shop_state(shop) -> Dictionary:
	var offers: Array[Dictionary] = []
	var rendered_slots: Array[String] = []
	var mismatches: Array[String] = []
	var grid = shop._shop_grid
	if is_instance_valid(grid):
		for child in grid.get_children():
			if not child.is_queued_for_deletion():
				rendered_slots.append(_collect_text(child))

	for i in range(shop._shop_items.size()):
		var entry: Dictionary = shop._shop_items[i]
		var item: Resource = entry.get("item")
		var display_name := str(item.get("display_name")) if item != null else ""
		var description := str(item.get("description")) if item != null else ""
		var offer_reason := str(entry.get("offer_reason", ""))
		var expected_fragments: Array[String] = []
		if not display_name.is_empty():
			expected_fragments.append(display_name.split(" ")[0])
		if not offer_reason.is_empty():
			expected_fragments.append(offer_reason)
		# 탄환 카드는 리소스 원문 대신 DMG/ACC/PEN과 효과 요약을 렌더한다.
		# 파츠·소모품은 description 원문이 실제 카드에 표시되므로 이를 대조한다.
		if not description.is_empty() and not item is BulletData:
			expected_fragments.append(description)

		var rendered_text := rendered_slots[i] if i < rendered_slots.size() else ""
		for fragment in expected_fragments:
			if not rendered_text.contains(fragment):
				mismatches.append("slot_%d missing: %s" % [i, fragment])

		offers.append({
			"slot": i,
			"id": PlaytestLoggerScript.resource_id(item) if item != null else "",
			"display_name": display_name,
			"offer_label": str(entry.get("offer_label", "")),
			"offer_reason": offer_reason,
			"description": description,
			"price": int(entry.get("price", 0)),
			"sold_out": bool(entry.get("sold_out", false)),
			"selected": bool(entry.get("selected", false)),
			"rendered_text": rendered_text,
		})

	if rendered_slots.size() != shop._shop_items.size():
		mismatches.append("rendered slot count %d != offer count %d" % [
			rendered_slots.size(), shop._shop_items.size()])

	return {
		"reroll_count": int(shop._reroll_count),
		"offers": offers,
		"center_slot": offers[1] if offers.size() > 1 else {},
		"render_integrity": {
			"valid": mismatches.is_empty(),
			"mismatches": mismatches,
		},
	}


static func reward_state(combat_overlay) -> Dictionary:
	var draft = combat_overlay._draft_container
	var cards: Array[String] = []
	if is_instance_valid(draft) and is_instance_valid(draft._draft_cards_hbox):
		for card in draft._draft_cards_hbox.get_children():
			if not card.is_queued_for_deletion():
				cards.append(_collect_text(card))
	return {
		"title": str(combat_overlay._result_title.text) if is_instance_valid(combat_overlay._result_title) else "",
		"message": str(combat_overlay._result_message.text) if is_instance_valid(combat_overlay._result_message) else "",
		"card_count": cards.size(),
		"cards": cards,
		"selected_bullet_id": PlaytestLoggerScript.resource_id(draft.get_selected_bullet()) \
			if is_instance_valid(draft) and draft.get_selected_bullet() != null else "",
	}


static func _screen_root(scene, current_screen: String) -> Control:
	match current_screen:
		"title": return scene._title_overlay
		"section_selector": return scene._section_selector_overlay
		"loadout": return scene._loadout_overlay
		"map": return scene._map_overlay
		"combat", "reward", "combat_result": return scene._combat_overlay
		"shop", "maintenance": return scene._maintenance_overlay
		"debriefing": return scene._debriefing_overlay
	return scene as Control


static func _collect_controls(
	node: Node,
	root: Control,
	root_name: String,
	out: Array[Dictionary]
) -> void:
	if node.is_queued_for_deletion():
		return
	if node is Control:
		var control := node as Control
		if not _is_effectively_visible(control, root):
			return
		var rect := control.get_global_rect()
		var record: Dictionary = {
			"path": "%s/%s" % [root_name, str(root.get_path_to(control))],
			"name": str(control.name),
			"type": control.get_class(),
			"visible": true,
			"rect": {
				"x": snappedf(rect.position.x, 0.01),
				"y": snappedf(rect.position.y, 0.01),
				"width": snappedf(rect.size.x, 0.01),
				"height": snappedf(rect.size.y, 0.01),
			},
		}
		var text := _control_text(control)
		if not text.is_empty():
			record["text"] = text
		if control is BaseButton:
			record["disabled"] = (control as BaseButton).disabled
		out.append(record)
	for child in node.get_children():
		_collect_controls(child, root, root_name, out)


static func _is_effectively_visible(control: Control, root: Control) -> bool:
	var current: Node = control
	while current != null:
		if current is CanvasItem and not (current as CanvasItem).visible:
			return false
		if current == root:
			return true
		current = current.get_parent()
	return false


static func _control_text(control: Control) -> String:
	if control is Label:
		return (control as Label).text
	if control is BaseButton:
		return (control as BaseButton).text
	if control is RichTextLabel:
		return (control as RichTextLabel).text
	if control is LineEdit:
		return (control as LineEdit).text
	return ""


static func _collect_text(node: Node) -> String:
	var lines: Array[String] = []
	if node is Control:
		var text := _control_text(node as Control).strip_edges()
		if not text.is_empty():
			lines.append(text)
	for child in node.get_children():
		if not child.is_queued_for_deletion():
			var child_text := _collect_text(child)
			if not child_text.is_empty():
				lines.append(child_text)
	return "\n".join(lines)
