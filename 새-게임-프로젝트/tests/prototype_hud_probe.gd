extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/"):quit(2);return
 root.size=Vector2i(844,390)
 var p=load("res://redesign/samples/hud/combat_journey_hud.tscn").instantiate()
 p.resume_saved=false
 root.add_child(p)
 for i in range(18):await process_frame
 print("root=",root.get_visible_rect()," ui=",p.get_global_rect()," scale=",root.content_scale_mode," ",root.content_scale_size)
 for id in ["Safe","Screen","Header","Battle","Console","MagazineHeader","MagazineHousing","RoundRow","Actions","Fire","FireArt","CoolArt","ReloadArt"]:
  print(id," ",p.node(id).get_global_rect()," min=",p.node(id).get_combined_minimum_size())
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join("native_probe.png"))
 root.size=Vector2i(2016,908)
 for i in range(18):await process_frame
 assert(root.content_scale_factor==2.0,"Dense landscape uses an integer UI scale")
 assert(p.size==Vector2(1008,454),"Dense display retains readable logical units")
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OS.get_environment("QA_OUTPUT_DIR").path_join("dense_probe.png"))
 p.queue_free()
 await process_frame
 print("PROTOTYPE HUD PROBE COMPLETE")
 quit()
