extends SceneTree
# Concept-only renderer. Loads external PNGs; does not instantiate campaign or save.
const Art = preload("res://redesign/weapon_art.gd")
const DIR = "D:/ProjectLoB/worktrees/core-redesign/docs/art/concepts/2026-10-25-outfit-unification"
var evidence: Array = []

class Actor extends Node2D:
	var body: Texture2D
	var cell := Rect2()
	var grip := Vector2()
	var support := Vector2()
	var hands: Array[Rect2] = []
	var gun: Dictionary
	var occupied_height := 447.0
	var long_hold := false
	func _draw() -> void:
		draw_texture_rect_region(body, Rect2(Vector2.ZERO, cell.size), cell)
		var f: float = occupied_height / 447.0 * 0.10
		var a := deg_to_rad(20.0)
		if long_hold:
			var delta: Vector2 = support - grip
			var source_delta: Vector2 = gun.support - gun.grip
			f = delta.length() / source_delta.length()
			a = delta.angle() - source_delta.angle()
		var t := Transform2D(a, Vector2.ONE*f, 0.0, grip)
		t.origin -= t.basis_xform(gun.grip)
		draw_set_transform_matrix(t)
		draw_texture(gun.image, Vector2.ZERO)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		for hand in hands:
			draw_texture_rect_region(body, hand, Rect2(cell.position+hand.position,hand.size))

class Board extends Control:
	var background: Texture2D
	var font: Font
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,1050),Color("#17262b"))
		draw_string(font,Vector2(34,44),"복장 통일 시안 · C 기준",HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color("#ded9be"))
		draw_string(font,Vector2(34,76),"기존 파지 유지  /  본편 적용 전 비교",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("#95a9a6"))
		var names = ["기본 작업복","운반용 외투","정찰용 작업복"]
		var desc = ["기준 C의 청회색 외투","긴 외투 · 적재 가방 · 큰 주머니","짧은 재킷 · 소형 가방 · 가벼운 장구"]
		for i in range(3):
			var x: float = 205+i*380
			draw_string(font,Vector2(x-80,118),names[i],HORIZONTAL_ALIGNMENT_LEFT,-1,24,Color("#ded9be"))
			draw_string(font,Vector2(x-115,145),desc[i],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#9bb2ac"))
		draw_string(font,Vector2(32,187),"한손",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("#a3beb2"))
		draw_string(font,Vector2(32,210),"리벳",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#7f9996"))
		draw_string(font,Vector2(32,476),"양손",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("#a3beb2"))
		draw_string(font,Vector2(32,499),"래칫",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#7f9996"))
		for y in [425,715]:
			draw_line(Vector2(120,y),Vector2(1220,y),Color("#34484a"),1)
		draw_string(font,Vector2(34,760),"전투 크기 비교 · 약 94px",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("#ded9be"))
		draw_texture_rect_region(background,Rect2(20,788,1240,180),Rect2(0,510,1672,243))
		for i in range(3):
			draw_string(font,Vector2(225+i*380,995),names[i],HORIZONTAL_ALIGNMENT_LEFT,-1,19,Color("#ded9be"))
		draw_string(font,Vector2(34,1030),"확대 시안과 실제 배경 위 축소 표시 · 정지 자세 비교이며 애니메이션 적용본은 아닙니다",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#91a6a1"))

func _initialize() -> void:
	run.call_deferred()

func info(id: String, family: String) -> Dictionary:
	if id=="work" and family=="pistol":
		return {"path":"res://assets/art/hero_contours_20261025/work_pistol.png","cell":Rect2(0,0,512,512),"bounds":Rect2(195,39,225,447),"grip":Vector2(344,226),"hands":[Rect2(330,212,32,28)]}
	var data = {
		"work": {
			"pistol":{"bounds":Rect2(290,48,395,787),"grip":Vector2(558,378),"hands":[Rect2(531,356,49,43)]},
			"long":{"bounds":Rect2(204,48,410,788),"grip":Vector2(459,384),"support":Vector2(564,464),"hands":[Rect2(435,361,49,43),Rect2(542,440,44,47)]}},
		"carrier": {
			"pistol":{"bounds":Rect2(351,87,378,738),"grip":Vector2(605,394),"hands":[Rect2(582,374,45,39)]},
			"long":{"bounds":Rect2(166,87,417,738),"grip":Vector2(411,408),"support":Vector2(544,484),"hands":[Rect2(390,386,40,42),Rect2(522,461,43,46)]}},
		"scout": {
			"pistol":{"bounds":Rect2(322,66,374,737),"grip":Vector2(589,377),"hands":[Rect2(565,356,47,43)]},
			"long":{"bounds":Rect2(244,66,392,737),"grip":Vector2(490,398),"support":Vector2(593,463),"hands":[Rect2(471,376,37,42),Rect2(572,442,42,41)]}}
	}
	var d: Dictionary = data[id][family].duplicate(true)
	d.path=DIR.path_join(id+"_v2.png")
	d.cell=Rect2(0 if family=="pistol" else 887,0,887,887)
	return d

func add_actor(board: Node, id: String, family: String, x: float, floor_y: float, h: float, gun_id: String="") -> void:
	var d:=info(id,family)
	var image:=Image.load_from_file(ProjectSettings.globalize_path(d.path))
	assert(not image.is_empty())
	var a:=Actor.new()
	a.body=ImageTexture.create_from_image(image)
	a.cell=d.cell;a.grip=d.grip
	a.support=d.get("support",Vector2.ZERO)
	for v in d.hands: a.hands.append(v)
	a.long_hold=family=="long"
	if gun_id.is_empty(): gun_id="burst" if a.long_hold else "single"
	a.gun=Art.PROFILES[gun_id]
	var bounds: Rect2=d.bounds
	a.occupied_height=bounds.size.y
	var factor: float=h/bounds.size.y
	a.scale=Vector2.ONE*factor
	a.position=Vector2(x-bounds.get_center().x*factor,floor_y-bounds.end.y*factor).round()
	a.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	var material:=ShaderMaterial.new()
	material.shader=load("res://redesign/monster_alpha_cutout.gdshader")
	material.set_shader_parameter("shadow_lift",0.65)
	a.material=material
	board.add_child(a)
	evidence.append({"outfit":id,"family":family,"gun":gun_id,"height":h,"source":d.path,"grip":[a.grip.x,a.grip.y],"support":[a.support.x,a.support.y]})

func run() -> void:
	if not OS.get_environment("APPDATA").replace("\\","/").contains("/qa_runtime/outfit_unification_20261025/"):
		printerr("Isolation required");quit(1);return
	root.size=Vector2i(1280,1050);root.content_scale_size=root.size
	var b:=Board.new();b.size=Vector2(1280,1050)
	b.font=load("res://assets/fonts/NeoDunggeunmoPro-Regular.ttf")
	b.background=load("res://assets/art/tower_sample_20261003/residential_tower.png")
	root.add_child(b)
	var ids=["work","carrier","scout"]
	for i in range(3):
		add_actor(b,ids[i],"pistol",260+i*380,420,245)
		add_actor(b,ids[i],"long",260+i*380,710,245)
		add_actor(b,ids[i],"pistol",225+i*380,943,94)
		add_actor(b,ids[i],"long",310+i*380,943,94)
	for n in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIR.path_join("comparison.png"))
	var f:=FileAccess.open(DIR.path_join("preview_checks.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"scope":"concept-only static renderer; production untouched","renderer":"Godot 4.7","entries":evidence},"\t"));f.close()
	print("CONCEPT COMPLETE: six grip/outfit combinations at two sizes; no campaign loaded")
	b.queue_free();await process_frame;quit()

