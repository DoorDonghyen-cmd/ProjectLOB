extends "res://tests/ammo_risk_ui_runner.gd"
## Exports real game data and an enemy-free battlefield render for the HTML
## UI prototype. Isolated save only; never issues commands after setup.

const Content = preload("res://redesign/content.gd")
const HandFace = preload("res://redesign/ammo_hand_face.gd")
const MapData = preload("res://redesign/campaign_content.gd")
var out := ""


func _run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/ui_prototype/"):
		quit(1)
		return
	out = OS.get_environment("QA_OUTPUT_DIR")
	root.size = Vector2i(1280, 800)
	var data := {}
	# --- combat: 1st-region elite with the real starting hand -------------
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	screen.presentation_speed = 0.04
	root.add_child(screen)
	await settle()
	screen._debug_challenge("elite")
	await settle()
	screen.model.s.gun = "single"
	screen.model.s.weapon_version = 1
	screen.redraw()
	await settle()
	var state: Dictionary = screen.model.s
	var view: Control = screen.battle_view
	view.reduced_feedback = true
	var holder := Control.new()
	holder.position = Vector2.ZERO
	holder.size = Vector2(1280, 520)
	root.add_child(holder)
	view.get_parent().remove_child(view)
	holder.add_child(view)
	view.position = Vector2.ZERO
	view.size = Vector2(1280, 520)
	view.custom_minimum_size = Vector2.ZERO
	screen.visible = false
	await settle()
	var enemies: Array = []
	for i in range(view.enemies.size()):
		var e: Dictionary = view.enemies[i].duplicate(true)
		var rect: Rect2 = view.concept_rect(i) if view.has_method("concept_rect") else Rect2()
		e["_feet"] = [view.enemy_feet(i).x, view.enemy_feet(i).y]
		e["_head"] = view.enemy_head_y(i)
		e["_rect"] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
		e["_threat"] = view.threat_readouts.get(i, {})
		var cells: Array = []
		for cell in view.enemy_status_layout(i).cells: cells.append({"icon": str(cell.entry.icon), "value": str(cell.entry.value)})
		e["_status"] = cells
		e["_intent"] = view.challenge_intent(i) if view.has_method("challenge_intent") and str(e.get("rank", "")) in ["elite", "boss"] else ""
		enemies.append(e)
	data["combat"] = {
		"size": [view.size.x, view.size.y],
		"player_feet": [view.player_feet().x, view.player_feet().y],
		"muzzle": [view.player_muzzle().x, view.player_muzzle().y],
		"ground": view.ground_y(),
		"enemies": enemies,
		"reinforcements": view.reinforcements,
		"hand": state.hand, "draw": state.draw, "deck": state.deck,
		"heat": state.get("heat", 0), "heat_limit": Content.heat_limit(state),
		"weapon": Content.weapon_spec(state),
		"capacity": int(Content.weapon_spec(state).capacity) + int(state.get("capacity_bonus", 0)),
	}
	# --- ammo table for every id the prototype can show --------------------
	var ids: Array = []
	for id in state.deck + ["basic", "pierce", "charge", "cool", "arc", "precise", "detonate", "shatter", "chase", "bypass", "push", "bore", "spread", "vent", "double"]:
		if Content.AMMO.has(id) and not ids.has(id): ids.append(id)
	var ammo := {}
	for id in ids:
		var spec: Dictionary = Content.AMMO[id]
		var stat: Dictionary = Content.primary_stat(id, state)
		ammo[id] = {
			"name": spec.name, "source": Content.source_id(id), "effect": str(spec.get("effect", "")),
			"dmg": Content.damage(id, state), "pen": Content.penetration(id, state),
			"hits": int(spec.get("hits", 1)), "value": Content.effect_value(id, state),
			"heat": Content.heat_delta(id, state), "heat_label": Content.heat_label(id, state),
			"stat_label": str(stat.label), "stat_value": str(stat.value),
			"secondary": HandFace.secondary(id, state), "text": str(spec.get("text", "")),
			"role": Content.ammo_role(id),
		}
	data["ammo"] = ammo
	# --- parts --------------------------------------------------------------
	var parts := {}
	for id in Content.PARTS.keys():
		var spec: Dictionary = Content.part_spec(id, state)
		parts[id] = {"name": spec.name, "kind": str(spec.get("kind", "")), "value": str(spec.get("value", "")), "upside": str(spec.get("upside", "")), "downside": str(spec.get("downside", "")), "grade": Content.part_grade_name(id)}
	data["parts"] = parts
	# --- enemy-free battlefield (hero + weapon stay) ------------------------
	view.enemies = []
	view.reinforcements = []
	view.projectiles = []
	view.threat_readouts = {}
	view.show_caption = false
	view.readout_layer.visible = false
	for item in view.info_buttons + view.reserve_buttons: item.visible = false
	for child in view.get_children():
		if child is CanvasItem and child != view.readout_layer and not child is Button:
			# Actor sprites of removed enemies.
			if child.name.begins_with("Enemy") or child.name.begins_with("Actor"): child.visible = false
	view.queue_redraw()
	await settle()
	var image := root.get_texture().get_image()
	check(image.get_region(Rect2i(0, 0, 1280, 520)).save_png(out.path_join("combat_bg.png")) == OK, "export combat background")
	# --- map ------------------------------------------------------------------
	holder.queue_free()
	screen.queue_free()
	await process_frame
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false
	root.add_child(screen)
	await settle()
	screen._debug_city("map")
	await settle()
	var run = screen.campaign
	var nodes: Array = []
	for node in run.current_nodes():
		var kind := MapData.room_kind(node)
		nodes.append({"id": int(node.id), "floor": int(node.floor), "lane": int(node.lane), "next": node.next, "kind": kind, "kind_name": MapData.kind_name(kind), "name": str(node.get("name", "")), "hint": MapData.hint(node), "route": str(node.get("route", ""))})
	data["map"] = {"nodes": nodes, "floors": int(run.region_info().floors), "region": str(run.region_info().get("name", "")), "available": run.choices().map(func(n): return int(n.id)), "current": int(run.s.node)}
	# --- part icons: hand-authored pixel drawing, keyed out of magenta -------
	screen.visible = false
	var part_ids: Array = Content.PARTS.keys().filter(func(id): return id != "none")
	var sheet := Control.new()
	sheet.position = Vector2.ZERO
	sheet.size = Vector2(1280, 800)
	sheet.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var centers := {}
	for i in range(part_ids.size()):
		centers[part_ids[i]] = Vector2(48 + (i % 12) * 100, 48 + floori(i / 12.0) * 90)
	sheet.draw.connect(func():
		sheet.draw_rect(Rect2(Vector2.ZERO, sheet.size), Color(1, 0, 1))
		for id in part_ids: preload("res://redesign/part_icon_art.gd").draw(sheet, id, centers[id], Color("b5b9a3"), 2.0)
	)
	root.add_child(sheet)
	await settle()
	check(root.get_texture().get_image().get_region(Rect2i(0, 0, 1280, 800)).save_png(out.path_join("part_sheet.png")) == OK, "export part icon sheet")
	var centers_json := {}
	for id in centers: centers_json[id] = [centers[id].x, centers[id].y]
	data["part_icons"] = centers_json
	var file := FileAccess.open(out.path_join("game_data.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	print("UI PROTOTYPE EXPORT COMPLETE checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
