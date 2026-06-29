extends Node

func _ready():
	print("Starting UI generation dump...")
	var combat_scene = load("res://scripts/ui/combat_scene.gd").new()
	var rm = load("res://scripts/core/run_manager.gd").new()
	var combat_overlay = load("res://scripts/ui/overlays/combat_overlay.gd").new()
	
	print("Initializing overlay...")
	combat_overlay.initialize(combat_scene, rm)
	
	print("Setting owner recursively...")
	_set_owner_recursive(combat_overlay, combat_overlay)
	
	print("Packing scene...")
	var packed = PackedScene.new()
	var result = packed.pack(combat_overlay)
	if result != OK:
		print("Failed to pack scene:", result)
		get_tree().quit()
		return
		
	var dir = DirAccess.open("res://scenes/ui/overlays")
	if not dir:
		DirAccess.make_dir_absolute("res://scenes/ui/overlays")
		
	result = ResourceSaver.save(packed, "res://scenes/ui/overlays/combat_overlay.tscn")
	if result == OK:
		print("Dumped combat_overlay.tscn successfully!")
	else:
		print("Failed to save scene:", result)

	get_tree().quit()

func _set_owner_recursive(node, root):
	if node != root:
		node.owner = root
	for child in node.get_children():
		_set_owner_recursive(child, root)
