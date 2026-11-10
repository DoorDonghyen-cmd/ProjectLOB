extends SceneTree
var host
var output:String
var checks:=0
var failures:Array=[]
var rows:Array=[]
func _initialize():run.call_deferred()
func settle():
	for frame in range(10):await process_frame
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);print("FAIL ",label)
func geometry(view:Control) -> Dictionary:
	var result:Dictionary={}
	for node in view.find_children("*","Control",true,false):
		if node is Button or str(node.name) in ["OutfitPortrait","WeaponArt","Stage","OutfitScroll","SelectedWeaponPanel"]:
			result[str(view.get_path_to(node))]=[node.get_global_rect(),node.get_combined_minimum_size()]
	return result
func run():
	output=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/equipment_visual_20261106/"):quit(2);return
	host=load("res://redesign/main.tscn").instantiate();host.save_enabled=false;root.add_child(host);await settle()
	for extent in [Vector2i(1280,800),Vector2i(1170,540)]:
		root.size=extent;root.content_scale_size=extent;await settle()
		host._open_preparation(false);await settle()
		var view:Control=host.find_child("EquipmentScreen",true,false)
		var styling=load(output.path_join("material.gd")).new();root.add_child(styling)
		var before:Dictionary=geometry(view)
		styling.bind(view,host);await settle()
		check(geometry(view)==before,"material keeps every button, preview and scroll geometry "+str(extent))
		if extent.x==1280:
			for gun in host.Content.GUNS:
				for outfit in host.Content.OUTFITS:
					view.find_child("weapon_select_"+gun,true,false).pressed.emit()
					view.find_child("outfit_select_"+outfit,true,false).pressed.emit()
					await settle()
					var live=view.find_child("OutfitPortrait",true,false).actor
					check(live.gun_id==gun and live.outfit_id==outfit,"preview binding retains "+gun+"/"+outfit)
		for pair in [["single","carrier"],["heavy","expedition"]]:
			var actor=view.find_child("OutfitPortrait",true,false)
			view.find_child("weapon_select_"+pair[0],true,false).pressed.emit()
			view.find_child("outfit_select_"+pair[1],true,false).pressed.emit()
			await settle();host.main_scroll.scroll_vertical=0;await settle()
			check(actor.actor.gun_id==pair[0] and actor.actor.outfit_id==pair[1],"live actor retains selected weapon and outfit")
			await RenderingServer.frame_post_draw
			var image:String="%dx%d_%s_%s.png"%[extent.x,extent.y,pair[0],pair[1]]
			root.get_texture().get_image().save_png(output.path_join(image))
			rows.append({"image":image,"size":str(extent),"weapon":pair[0],"outfit":pair[1]})
		styling.free()
	host.free();await settle()
	FileAccess.open(output.path_join("review.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"frames":rows,"scope":"Review-only runtime styling of the authored equipment screen; not production integration or Android testing."},"  "))
	print("EQUIPMENT STYLE REVIEW COMPLETE checks=%d failures=%d"%[checks,failures.size()]);quit(0 if failures.is_empty() else 1)
