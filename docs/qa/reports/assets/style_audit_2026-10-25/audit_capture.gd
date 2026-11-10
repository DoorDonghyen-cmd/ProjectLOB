extends SceneTree

var screen: Control
var output := ""
var evidence: Array = []
var portraits: Dictionary = {}
var actors: Dictionary = {}
const FONT = preload("res://redesign/combat_pixel_font.tres")

func _initialize() -> void:
	run.call_deferred()

func settle() -> void:
	for n in range(8): await process_frame
	await RenderingServer.frame_post_draw

func capture(name: String) -> void:
	await settle()
	root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func label_at(parent: Node, value: String, at: Vector2, font_size := 22) -> void:
	var item := Label.new()
	item.text = value; item.position = at
	item.add_theme_font_override("font", FONT)
	item.add_theme_font_size_override("font_size", font_size)
	parent.add_child(item)

func image_at(parent: Node, texture: Texture2D, at: Vector2, extent: Vector2, mat: Material = null) -> void:
	var item := TextureRect.new()
	item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item.texture = texture; item.position = at; item.size = extent
	item.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	item.material = mat; parent.add_child(item)

func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\", "/").contains("/qa_runtime/style_audit_20261025/"):
		quit(1); return
	output = OS.get_environment("QA_OUTPUT_DIR")
	root.size = Vector2i(1280,900)
	screen = load("res://redesign/main.tscn").instantiate()
	screen.save_enabled = false; root.add_child(screen)
	await settle()
	for outfit in ["work", "carrier", "recovery", "expedition"]:
		screen._open_preparation(false); await settle()
		var equipment = screen.find_child("EquipmentScreen", true, false)
		equipment._select_outfit(outfit); equipment._select_weapon("single")
		await capture("equipment_" + outfit)
		var portrait = equipment.get_node("%OutfitPortrait")
		portraits[outfit] = {"texture":portrait.texture,"material":portrait.material.duplicate()}
		evidence.append({"screen":"equipment","outfit":outfit,"rect":str(portrait.get_global_rect()),"texture":portrait.texture.atlas.resource_path,"region":str(portrait.texture.region),"shadow_lift":portrait.material.get_shader_parameter("shadow_lift")})
		screen._debug_challenge("elite"); await settle()
		screen.model.s.outfit = outfit; screen.model.s.gun = "single"
		screen.redraw(); await settle()
		var view = screen.battle_view
		view.reduced_feedback = true
		await capture("battle_" + outfit)
		var actor = view.weapon_viewport.get_node("Actor")
		var actor_image = view.weapon_viewport.get_texture().get_image()
		var atlas := AtlasTexture.new()
		atlas.atlas = ImageTexture.create_from_image(actor_image)
		atlas.region = actor_image.get_used_rect()
		actors[outfit] = atlas
		evidence.append({"screen":"battle","outfit":outfit,"body":actor.body_texture().resource_path,"region":str(atlas.region),"screen_body_factor":view.character_scale()*actor.BODY_SCALE,"shadow_lift":actor.material.get_shader_parameter("shadow_lift")})
	for region in [3,4]:
		for stage in range(3):
			if region == 3: screen._debug_noble_background(stage)
			else: screen._debug_central_background(stage)
			await capture("region%d_stage%d" % [region+1,stage])
			var view = screen.battle_view
			evidence.append({"screen":"background","region":region+1,"stage":stage,"path":view.tower_texture.resource_path,"source_rect":str(view.background_source_rect()),"target_size":str(view.size),"filter":view.texture_filter,"source_size":str(view.tower_texture.get_size())})
	screen.queue_free(); await process_frame
	root.content_scale_size = Vector2i(1280,900)
	var board := Control.new(); root.add_child(board)
	var bg := ColorRect.new(); bg.size = Vector2(1280,900); bg.color = Color("17262b"); board.add_child(bg)
	label_at(board,"같은 높이 비교 · 왼쪽 선택 원화 / 오른쪽 전투 원화",Vector2(30,16),26)
	var i := 0
	for outfit in portraits:
		var origin := Vector2((i % 2)*640+20,(i/2)*405+60)
		label_at(board,str(preload("res://redesign/content.gd").OUTFITS[outfit].name),origin,22)
		image_at(board,portraits[outfit].texture,origin+Vector2(8,38),Vector2(280,335),portraits[outfit].material)
		image_at(board,actors[outfit],origin+Vector2(308,38),Vector2(280,335))
		i += 1
	await capture("character_comparison")
	var file := FileAccess.open(output.path_join("evidence.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"\t")); file.close()
	print("STYLE AUDIT CAPTURE COMPLETE captures=15; no game mutations")
	quit(0)
