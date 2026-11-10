extends SceneTree
var view
var output: String
var checks := 0
var failures: Array=[]
func _initialize():run.call_deferred()
func check(ok: bool,label: String):
 checks+=1
 if not ok:failures.append(label);print("FAIL ",label)
func settle():
 for i in range(12):await process_frame
func capture(name: String):
 for node in view.find_children("*","CanvasItem",true,false):node.queue_redraw()
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(name+".png"))
func tap(path: String):
 var b: Button=view.get_node(path)
 var pos: Vector2=b.get_global_rect().get_center()
 for down in [true,false]:
  var e=InputEventScreenTouch.new();e.index=0;e.position=pos;e.pressed=down;root.push_input(e,true);await process_frame
 await settle()
func run():
 output=OS.get_environment("QA_OUTPUT_DIR")
 if not output.replace("\\","/").ends_with("/qa_runtime/workbench_theme_20261104/capture"):quit(2);return
 root.size=Vector2i(1280,800);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_factor=1.0
 view=load("res://redesign/samples/workbench_theme/preview.tscn").instantiate();root.add_child(view)
 await settle()
 await capture("compression")
 for i in range(5):
  await tap("Tabs/Tab%d"%i)
  check(view.mode==i,"tab updates inspected operation")
  check(view.get_node("Inspector/Inset/Content/Title").text==view.MODES[i],"operation heading follows selected tab")
  check(root.get_visible_rect().encloses(view.get_node("Tabs/Tab%d"%i).get_global_rect()),"tab stays in the preview viewport")
  check(root.get_visible_rect().encloses(view.get_node("Inspector").get_global_rect()),"inspector stays in the preview viewport")
  await capture("mode_%d"%i)
 await tap("Tabs/Tab1");await tap("Inventory/Inset/Rows/Slots/Slot1")
 check(view.selected==1,"owned round selection updates inspection")
 check(view.get_node("Inspector/Inset/Content/Name").text==view.Content.AMMO[view.ids[1]].name,"selected item uses game data name")
 await capture("pierce_selected")
 root.size=Vector2i(2340,1080);root.content_scale_factor=2.0;await settle()
 await tap("Tabs/Tab1");await tap("Inventory/Inset/Rows/Slots/Slot0")
 check(root.get_visible_rect().encloses(view.get_node("Inspector").get_global_rect()),"Galaxy aspect inspector fits")
 check(not view.get_node("Inspector").get_global_rect().intersects(view.get_node("Inventory").get_global_rect()),"Galaxy aspect inspector and inventory do not overlap")
 await capture("galaxy_compression")
 check(not FileAccess.file_exists("user://city_campaign_v1.json"),"visual prototype does not create a campaign save")
 FileAccess.open(output.path_join("result.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  "))
 print("WORKBENCH PREVIEW COMPLETE checks=%d failures=%d"%[checks,failures.size()])
 view.free();await settle();quit(0 if failures.is_empty() else 1)
