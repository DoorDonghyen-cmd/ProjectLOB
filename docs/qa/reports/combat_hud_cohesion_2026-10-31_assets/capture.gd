extends "res://tests/combat_hud_ui.gd"
func run()->void:
 out=OS.get_environment("QA_OUTPUT_DIR")
 root.content_scale_size=Vector2i(1280,800)
 preview=Scene.instantiate();preview.resume_saved=false;root.add_child(preview);await settle()
 for size in [Vector2i(1280,800),Vector2i(1008,630),Vector2i(1280,576)]:
  root.size=size;await settle()
  for gun in [0,3]:
   preview.gun_index=gun;preview.case_index=1;preview.mount(false);await settle()
   await capture("ready_%s_%dx%d"%[preview.model.s.gun,size.x,size.y])
   if gun==0 and size==Vector2i(1280,800):
    await tap("EjectToggle");await tap("Select1");await capture("selected");await key(KEY_ESCAPE)
    await tap("Menu");await capture("menu");await key(KEY_ESCAPE)
    await tap("Inspect1");await capture("detail");await key(KEY_ESCAPE)
 print("COHESION CAPTURE COMPLETE failures=%d"%failures.size());quit(0 if failures.is_empty() else 1)
