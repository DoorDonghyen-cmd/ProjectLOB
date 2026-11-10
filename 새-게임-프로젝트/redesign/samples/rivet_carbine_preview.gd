extends Control
const Campaign=preload("res://redesign/campaign.gd")
const Content=preload("res://redesign/content.gd")
const Carbine=preload("res://redesign/samples/rivet_carbine_actor.gd")
const Legacy=preload("res://art_source/rivet_twohand_20261106/legacy_weapon_actor.gd")
var host
var style_mode:="curated"
var outfit_index:=0
var installed_board: Node
var installed_style:=""

func _ready() -> void:
	# Dedicated developer preview always uses isolated data, even when launched
	# accidentally from an editor whose ordinary save path is not isolated.
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/rivet_art_20261106/"):
		get_tree().quit(2);return
	host=load("res://redesign/main.tscn").instantiate()
	host.save_enabled=false;add_child(host)
	start_outfit.call_deferred()

func start_outfit() -> void:
	var c=Campaign.new();c.start("single",17,0,"balanced",4,Content.OUTFITS.keys()[outfit_index],true)
	c.enter(101)
	host.campaign=c;host.model=c.model;host.page="run";host.redraw()
	installed_board=null;installed_style=""
	update_title()

func update_title() -> void:
	DisplayServer.window_set_title("리벳 아트 비교 — F1 기존 / F2 새 원화 / F3 약한 처리 / F4 강한 처리 / F5 총만 처리 / F6 복장 | "+style_mode)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var modes:={KEY_F1:"legacy",KEY_F2:"raw",KEY_F3:"quiet",KEY_F4:"coarse",KEY_F5:"curated"}
	if modes.has(event.keycode): style_mode=modes[event.keycode];update_title();get_viewport().set_input_as_handled()
	if event.keycode==KEY_F6:
		outfit_index=(outfit_index+1)%Content.OUTFITS.size();start_outfit();get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not is_instance_valid(host) or not is_instance_valid(host.campaign_hud): return
	var board=host.campaign_hud.board
	var render_mode:=style_mode if str(host.model.s.gun)=="single" else "production"
	if board==installed_board and render_mode==installed_style:return
	apply_style(board,render_mode)
	installed_board=board;installed_style=render_mode

static func apply_style(board: Control, mode: String) -> void:
	if not board.has_meta("rivet_original_background"):board.set_meta("rivet_original_background",board.tower_texture)
	var viewport=load("res://redesign/weapon_actor.tscn").instantiate()
	if mode!="production":
		var old_actor=viewport.get_node("Actor")
		var actor=Legacy.new() if mode=="legacy" else Carbine.new();actor.name="Actor";actor.material=old_actor.material;actor.texture_filter=old_actor.texture_filter
		viewport.remove_child(old_actor);old_actor.free();viewport.add_child(actor)
		if mode!="legacy":actor.set_style(mode)
	var old_viewport=board.weapon_viewport
	board.weapon_viewport=viewport;board.add_child(viewport)
	board.remove_child(old_viewport);old_viewport.free()
	board.tower_texture=Carbine.texture(Carbine.PILOT+"background_"+mode+".png") if mode in ["quiet","coarse"] else board.get_meta("rivet_original_background")
	board._update_weapon_actor();board.queue_redraw()
