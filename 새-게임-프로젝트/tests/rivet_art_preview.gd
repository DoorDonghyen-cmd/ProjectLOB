extends SceneTree
const Campaign=preload("res://redesign/campaign.gd")
const Carbine=preload("res://redesign/samples/rivet_carbine_actor.gd")
var checks:=0
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;print("FAIL: "+label)
func settle() -> void:
	for i in range(8):await process_frame
func run() -> void:
	if not ProjectSettings.globalize_path("user://").replace("\\","/").contains("/qa_runtime/rivet_art_20261106/"):quit(2);return
	root.size=Vector2i(1280,800)
	var preview=load("res://redesign/samples/rivet_carbine_preview.tscn").instantiate();root.add_child(preview);await settle()
	for gun in ["single","heavy","amplifier","burst","scatter"]:
		var c=Campaign.new();c.start(gun,17,0,"balanced",4,"work",true);check(c.enter(101),"real new encounter "+gun)
		preview.host.campaign=c;preview.host.model=c.model;preview.host.page="run";preview.host.redraw();await settle()
		for pair in [[KEY_F1,"legacy"],[KEY_F5,"curated"]]:
			var before:=JSON.stringify(c.model.s)
			for pressed in [true,false]:
				var key:=InputEventKey.new();key.keycode=pair[0];key.pressed=pressed;root.push_input(key,true);await process_frame
			await settle()
			var actor=preview.host.campaign_hud.board.weapon_viewport.get_node("Actor")
			check(JSON.stringify(c.model.s)==before,"comparison preserves model "+gun+str(pair[1]))
			check(actor.gun_id==("burst" if gun=="single" and pair[1]=="curated" else gun),"preview cannot disguise other guns "+gun+str(pair[1]))
			if gun=="single" and pair[1]=="curated":check(actor.get_script()==Carbine,"Rivet uses candidate actor")
	check(not preview.host.save_enabled,"preview stays isolated")
	preview.free()
	print("RIVET ART PREVIEW COMPLETE checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
