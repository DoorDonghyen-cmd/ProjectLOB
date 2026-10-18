extends RefCounted
## Original generated atlas; exact alpha regions, nearest sampling and cached 9-slice resources.
const ATLAS = preload("res://assets/art/fieldkit_ui_20261009/fieldkit_atlas.png")
const REGIONS := {
	"receiver": Rect2i(44,137,962,345),
	"card": Rect2i(1053,85,446,542),
	"canvas": Rect2i(48,628,957,302),
	"trigger": Rect2i(1053,727,446,179),
}
const MARGINS := {
	"receiver": Vector4(38,16,18,15),
	"card": Vector4(12,48,14,12),
	"canvas": Vector4(18,10,17,10),
	"trigger": Vector4(12,8,16,12),
}
static var textures := {}

static func texture(kind: String) -> Texture2D:
	if not textures.has(kind):
		var image := ATLAS.get_image().get_region(REGIONS[kind])
		var ratio := 0.5 if kind == "card" else 0.25
		image.resize(roundi(image.get_width()*ratio), roundi(image.get_height()*ratio), Image.INTERPOLATE_NEAREST)
		textures[kind] = ImageTexture.create_from_image(image)
	return textures[kind]

static func box(kind: String, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var result := StyleBoxTexture.new()
	result.texture = texture(kind)
	result.modulate_color = tint
	var margins: Vector4 = MARGINS[kind]
	for pair in [[SIDE_LEFT,margins.x],[SIDE_TOP,margins.y],[SIDE_RIGHT,margins.z],[SIDE_BOTTOM,margins.w]]:
		result.set_texture_margin(pair[0],pair[1])
		result.set_content_margin(pair[0],0)
	return result
