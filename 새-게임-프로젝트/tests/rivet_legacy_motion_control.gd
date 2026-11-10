extends "res://tests/actor_motion_ui_runner.gd"
const Legacy=preload("res://art_source/rivet_twohand_20261106/legacy_weapon_actor.gd")
const ArtPreview=preload("res://redesign/samples/rivet_carbine_preview.gd")
func _initialize() -> void:
	process_frame.connect(keep_legacy_art)
	super._initialize()
func keep_legacy_art() -> void:
	if not is_instance_valid(screen) or not is_instance_valid(screen.battle_view):return
	var actor=screen.battle_view.weapon_viewport.get_node("Actor")
	if actor.get_script()!=Legacy:ArtPreview.apply_style(screen.battle_view,"legacy")
