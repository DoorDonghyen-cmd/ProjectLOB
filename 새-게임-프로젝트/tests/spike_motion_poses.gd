extends SceneTree
const Content = preload("res://redesign/content.gd")
const Actor = preload("res://redesign/weapon_actor.gd")
var output: String
func _initialize() -> void: run.call_deferred()
func run() -> void:
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/spike_motion_20261106/"):quit(2);return
	root.size=Vector2i(1600,800);root.content_scale_size=Vector2i.ZERO;root.content_scale_factor=1
	var rows: Array=[]
	var samples := [["idle",0.0],["aim",0.0],["recoil",0.5],["recoil",1.0],["reload_open",0.0],["reload_seat",0.0],["cooling",0.0],["recoil",0.0]]
	for outfit in Content.OUTFITS:
		var board=Control.new();root.add_child(board)
		var bg=ColorRect.new();bg.color=Color("34444b");bg.size=Vector2(1600,800);board.add_child(bg)
		var viewports: Array=[]
		for i in range(samples.size()):
			var viewport=load("res://redesign/weapon_actor.tscn").instantiate();board.add_child(viewport)
			var actor=viewport.get_node("Actor");actor.set_outfit(outfit);actor.configure("amplifier",samples[i][0],samples[i][1])
			viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewports.append(viewport)
			var picture=TextureRect.new();picture.texture=viewport.get_texture();picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
			picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.position=Vector2(i%4*400,i/4*400);picture.size=Vector2(400,267);board.add_child(picture)
			var label=Label.new();label.text="%s / %s / kick %.2f" % [outfit,samples[i][0],samples[i][1]];label.position=picture.position+Vector2(14,285);board.add_child(label)
			rows.append({"outfit":outfit,"pose":samples[i][0],"kick":samples[i][1],"body":actor.body_texture().resource_path,"frame":str(Actor.frame_for(outfit,"amplifier",samples[i][0])),"transform":str(actor.registered_transform())})
		for frame in range(7):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join("poses_"+outfit+".png"))
		for i in range(viewports.size()):viewports[i].get_texture().get_image().save_png(output.path_join("actor_%s_%s_%d.png" % [outfit,samples[i][0],i]))
		board.free();await process_frame
	FileAccess.open(output.path_join("poses.json"),FileAccess.WRITE).store_string(JSON.stringify({"samples":rows},"  "))
	print("SPIKE MOTION POSES COMPLETE samples=",rows.size());quit()
