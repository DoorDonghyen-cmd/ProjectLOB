extends SceneTree
var screen: Control
var output := ""
var evidence: Array = []
func _initialize() -> void: run.call_deferred()
func settle() -> void:
	for n in range(8): await process_frame
	await RenderingServer.frame_post_draw
func capture(name: String) -> void:
	await settle()
	root.get_texture().get_image().save_png(output.path_join(name+".png"))
func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/outline_preview_20261025/"):
		quit(1);return
	output=OS.get_environment("QA_OUTPUT_DIR")
	root.size=Vector2i(1280,900);root.content_scale_size=root.size
	screen=load("res://redesign/main.tscn").instantiate();screen.save_enabled=false;root.add_child(screen)
	await settle()
	for pair in [["work","single"],["work","burst"],["recovery","amplifier"],["expedition","heavy"]]:
		var outfit: String=pair[0]
		var gun: String=pair[1]
		screen._open_preparation(false);await settle()
		var equipment=screen.find_child("EquipmentScreen",true,false)
		equipment._select_outfit(outfit);equipment._select_weapon(gun)
		await capture("equipment_"+outfit+"_"+gun)
		var preview=equipment.get_node("%OutfitPortrait")
		var selection_image: Image=preview.actor_viewport.get_texture().get_image()
		var selection_hash:=hash(selection_image.get_data())
		var selection_body: String=preview.actor.body_texture().resource_path
		screen._debug_challenge("elite");await settle()
		screen.model.s.outfit=outfit;screen.model.s.gun=gun;screen.redraw();await settle()
		var view=screen.battle_view
		view.reduced_feedback=true
		await capture("battle_"+outfit+"_"+gun)
		var actual= view.weapon_viewport.get_node("Actor")
		var battle_hash:=hash(view.weapon_viewport.get_texture().get_image().get_data())
		assert(selection_body==actual.body_texture().resource_path)
		assert(selection_hash==battle_hash,"Selection and battle composite must be pixel-identical before screen scaling")
		evidence.append({"outfit":outfit,"gun":gun,"body":selection_body,"selection_hash":selection_hash,"battle_hash":battle_hash,"identical_composite":true})
	var file:=FileAccess.open(output.path_join("shared_actor_evidence.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"\t"));file.close()
	print("SHARED ACTOR COMPLETE checks=8 failures=0; exact composite equality in four pairs")
	screen.queue_free();await process_frame;quit(0)
