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
	var ids: Array = []
	var names := {"work":"기본 작업복","carrier":"운반용 외투","scout":"정찰용 작업복","heatworker":"배관공 방열복","hoist":"승강로 인양 장구","recovery":"봉쇄구역 회수 장구","expedition":"밀폐형 원정복"}
	var desc := {"work":"C 원화 기준","carrier":"멜빵을 팔 뒤로 정리","scout":"짧은 재킷 · 가벼운 장구","heatworker":"방열 어깨천 · 배기통","hoist":"인양 하네스 · 케이블 릴","recovery":"보호판 · 회수 장치","expedition":"밀폐 헬멧 · 생존 장치"}
	func column_x(i: int) -> float:
		return 120.0+(i+0.5)*1120.0/ids.size()
	func center_text(x: float, y: float, value: String, size_value: int, tint: Color) -> void:
		var w:=font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value).x
		draw_string(font,Vector2(x-w*0.5,y),value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value,tint)
	func _draw() -> void:
		draw_rect(Rect2(0,0,1280,1050),Color("#17262b"))
		draw_string(font,Vector2(34,44),"복장 통일 시안 · C 기준",HORIZONTAL_ALIGNMENT_LEFT,-1,28,Color("#ded9be"))
		draw_string(font,Vector2(34,76),"복장별 디자인 유지  /  한손 · 양손 대기 자세 비교  /  본편 미적용",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("#95a9a6"))
		for i in range(ids.size()):
			center_text(column_x(i),118,names[ids[i]],22,Color("#ded9be"))
			center_text(column_x(i),145,desc[ids[i]],16,Color("#9bb2ac"))
		draw_string(font,Vector2(32,187),"한손",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("#a3beb2"))
		draw_string(font,Vector2(32,210),"리벳",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#7f9996"))
		draw_string(font,Vector2(32,476),"양손",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("#a3beb2"))
		draw_string(font,Vector2(32,499),"래칫",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#7f9996"))
		for y in [425,715]:
			draw_line(Vector2(120,y),Vector2(1220,y),Color("#34484a"),1)
		draw_string(font,Vector2(34,760),"전투 크기 비교 · 약 94px",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("#ded9be"))
		draw_texture_rect_region(background,Rect2(20,788,1240,180),Rect2(0,510,1672,243))
		for i in range(ids.size()):
			center_text(column_x(i),995,names[ids[i]],18,Color("#ded9be"))
		draw_string(font,Vector2(34,1030),"확대 시안과 배경 위 축소 표시 · 실제 동작 적용 전 정지 시안",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#91a6a1"))

func _initialize() -> void:
	run.call_deferred()

func info(id: String, family: String) -> Dictionary:
	var updated = {
		"carrier": {"file":"carrier_v4.png",
			"pistol":{"bounds":Rect2(346,81,386,745),"grip":Vector2(605,394),"hands":[Rect2(582,374,45,39)]},
			"long":{"bounds":Rect2(162,81,424,745),"grip":Vector2(412,407),"support":Vector2(545,485),"hands":[Rect2(391,386,40,42),Rect2(523,461,43,46)]}},
		"heatworker": {"file":"heatworker_v1.png",
			"pistol":{"bounds":Rect2(299,48,388,789),"grip":Vector2(553,383),"hands":[Rect2(529,360,48,46)]},
			"long":{"bounds":Rect2(205,48,411,789),"grip":Vector2(461,383),"support":Vector2(566,463),"hands":[Rect2(436,360,49,46),Rect2(543,438,45,49)]}},
		"hoist": {"file":"hoist_v1.png",
			"pistol":{"bounds":Rect2(278,47,407,786),"grip":Vector2(557,379),"hands":[Rect2(531,355,52,47)]},
			"long":{"bounds":Rect2(192,47,426,786),"grip":Vector2(460,384),"support":Vector2(566,465),"hands":[Rect2(435,360,50,47),Rect2(543,440,46,50)]}},
		"recovery": {"file":"recovery_v1.png",
			"pistol":{"bounds":Rect2(285,49,400,786),"grip":Vector2(557,377),"hands":[Rect2(531,353,52,47)]},
			"long":{"bounds":Rect2(202,48,418,787),"grip":Vector2(468,381),"support":Vector2(570,465),"hands":[Rect2(445,356,46,49),Rect2(547,439,46,52)]}},
		"expedition": {"file":"expedition_v1.png",
			"pistol":{"bounds":Rect2(290,46,395,790),"grip":Vector2(564,384),"hands":[Rect2(539,361,50,46)]},
			"long":{"bounds":Rect2(207,47,419,789),"grip":Vector2(482,384),"support":Vector2(580,469),"hands":[Rect2(457,361,50,46),Rect2(556,443,47,51)]}}
	}
	if updated.has(id):
		var candidate: Dictionary=updated[id][family].duplicate(true)
		candidate.path=DIR.path_join(updated[id].file)
		candidate.cell=Rect2(0 if family=="pistol" else 887,0,887,887)
		return candidate
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
	for group in [{"ids":["work","carrier","scout"],"file":"basic_updated"},{"ids":["heatworker","hoist","recovery","expedition"],"file":"remaining_four"}]:
		var b:=Board.new();b.size=Vector2(1280,1050);b.ids=group.ids
		b.font=load("res://assets/fonts/NeoDunggeunmoPro-Regular.ttf")
		b.background=load("res://assets/art/tower_sample_20261003/residential_tower.png")
		root.add_child(b)
		for i in range(b.ids.size()):
			var x:=b.column_x(i)
			add_actor(b,b.ids[i],"pistol",x,420,245)
			add_actor(b,b.ids[i],"long",x,710,245)
			add_actor(b,b.ids[i],"pistol",x-42,943,94)
			add_actor(b,b.ids[i],"long",x+43,943,94)
		for n in range(8): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(DIR.path_join(group.file+".png"))
		b.queue_free();await process_frame
	var f:=FileAccess.open(DIR.path_join("all_preview_checks.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"scope":"concept-only seven outfits, production untouched","entries":evidence},"\t"));f.close()
	print("CONCEPT COMPLETE: seven outfits, two idle grips, two sizes; no campaign loaded")
	quit()
