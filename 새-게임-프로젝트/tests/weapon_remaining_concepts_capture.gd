extends SceneTree
## Art-only contact sheet: source images remain untouched; no campaign saves.

const FONT = preload("res://redesign/combat_pixel_font.tres")
const ART := "res://assets/art/weapon_redesign_20261024/"
const OUTPUT := "res://../docs/qa/reports/assets/weapon_remaining_concepts_2026-10-24"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1440, 600)
	root.content_scale_size = Vector2i(1440, 600)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var background := ColorRect.new()
	background.color = Color("142126")
	background.size = Vector2(1440, 600)
	root.add_child(background)
	_label("ORVASK  /  무기 컨셉 3종", Vector2(36, 20), 28)
	_label("정지 시안 · 본편 파지/애니메이션 적용 전", Vector2(36, 62), 18)
	var info := [
		["스플린터 / SPLINTER", "양손 · 분산 사격", "scatter_splinter_v1.png", Rect2(115,115,1943,537)],
		["리액터 / REACTOR", "양손 · 과부하 연사", "heavy_reactor_v1.png", Rect2(35,98,2092,571)],
		["스파이크 / SPIKE", "한손 · 강한 단발", "amplifier_spike_v1.png", Rect2(88,113,1943,553)]
	]
	var splinter_v2 := OS.get_cmdline_user_args().has("--splinter-v2")
	if splinter_v2:
		info[0][2] = "scatter_splinter_v2.png"
		info[0][3] = Rect2(114,98,1996,558)
	var splinter_v3 := OS.get_cmdline_user_args().has("--splinter-v3")
	if splinter_v3:
		info[0][2] = "scatter_splinter_v3.png"
		info[0][3] = Rect2(113,109,1928,547)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){vec4 c=texture(TEXTURE,UV); if(c.a<0.5){discard;} COLOR=vec4(c.rgb,1.0); }"
	for i in range(info.size()):
		var x := float(i * 480)
		_label(info[i][0], Vector2(x+32,125), 25)
		_label(info[i][1], Vector2(x+32,163), 18)
		var source := Image.load_from_file(ART+str(info[i][2]))
		assert(source != null)
		var texture := ImageTexture.create_from_image(source)
		var region: Rect2 = info[i][3]
		for display in [[400.0,235.0],[110.0,460.0]]:
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = region
			var image := TextureRect.new()
			image.texture = atlas
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			image.size = region.size * (float(display[0]) / region.size.x)
			image.position = Vector2(x+(480.0-image.size.x)*0.5,display[1])
			var material := ShaderMaterial.new()
			material.shader = shader
			image.material = material
			root.add_child(image)
		_label("축소 판독 비교 · 폭110px", Vector2(x+32,402), 18)
	_label("생성 원본 보존 · nearest + 알파 컷아웃 표시 · 실제 장착 크기는 후속 조정", Vector2(36,551), 18)
	for frame in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	var output := ProjectSettings.globalize_path(OUTPUT)
	if splinter_v3:
		output += "_splinter_v3"
	elif splinter_v2:
		output += "_splinter_v2"
	DirAccess.make_dir_recursive_absolute(output)
	var result := root.get_texture().get_image().save_png(output.path_join("remaining_concepts_1440.png"))
	print("REMAINING WEAPON CONCEPTS: source + 110px comparison; save result=", result)
	quit(0 if result == OK else 1)

func _label(text: String, at: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.modulate = Color("d3c8ab") if font_size > 20 else Color("91a5a3")
	root.add_child(label)
