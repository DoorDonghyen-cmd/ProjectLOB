extends RefCounted
## Shared, integer-scaled pixel assets. World positions are anchored at the feet.
const ROOT := "res://assets/art/pixel_20261003/"
const INK := Color("101820")
const STEEL := Color("425c67")
const LIGHT := Color("b4c7c5")
static var cache: Dictionary = {}
static var anchors: Dictionary = {}

static func texture(id: String) -> Texture2D:
	if not cache.has(id):
		var path := ROOT + id + ".png"
		cache[id] = load(path) if ResourceLoader.exists(path) else null
	return cache[id] as Texture2D

static func sprite(canvas: CanvasItem, id: String, foot: Vector2, scale_value: int = 2, tint: Color = Color.WHITE) -> void:
	var art := texture(id)
	if art == null: return
	if anchors.is_empty():
		anchors = (load(ROOT + "sprite_anchors.tres") as Resource).get_meta("anchors", {})
	var extent := art.get_size() * scale_value
	var anchor: Vector2 = anchors.get(id, Vector2(art.get_width() * 0.5, art.get_height()))
	canvas.draw_texture_rect(art, Rect2((foot - anchor * scale_value).round(), extent), false, tint)

static func shadow(canvas: CanvasItem, foot: Vector2, width: float) -> void:
	var p := foot.round()
	canvas.draw_rect(Rect2(p + Vector2(-width * 0.5 + 6, -2), Vector2(width - 12, 8)), Color("0a1219"))
	canvas.draw_rect(Rect2(p + Vector2(-width * 0.5, 0), Vector2(width, 4)), Color("0a1219"))

static func backdrop(canvas: CanvasItem, bounds: Rect2, ground: float) -> void:
	canvas.draw_rect(bounds, INK)
	var art := texture("foundry")
	if art != null:
		# Fixed two-pixel texels; horizontal repeats only on unusually wide windows.
		var extent := art.get_size() * 2.0
		var x := 0.0
		while x < bounds.size.x:
			var w := minf(extent.x, bounds.size.x - x)
			canvas.draw_texture_rect_region(art, Rect2(x, 0, w, ground), Rect2(0, 0, w / 2.0, ground / 2.0))
			x += extent.x
	canvas.draw_rect(Rect2(0, 0, bounds.size.x, ground), Color(0.04, 0.07, 0.10, 0.48))
	# The foreground owns the ground plane. It is independent of backdrop cropping.
	canvas.draw_rect(Rect2(0, ground, bounds.size.x, bounds.size.y - ground), Color("233640"))
	canvas.draw_rect(Rect2(0, ground, bounds.size.x, 4), Color("698086"))
	canvas.draw_rect(Rect2(0, ground + 4, bounds.size.x, 4), Color("121e28"))
	for x in range(0, int(bounds.size.x), 80):
		canvas.draw_rect(Rect2(x, ground + 10, 2, bounds.size.y - ground - 28), Color("16262f"))
		canvas.draw_rect(Rect2(x + 8, ground + 12, 4, 2), Color("59717a"))
		canvas.draw_rect(Rect2(x + 8, bounds.size.y - 24, 4, 2), Color("59717a"))
	canvas.draw_rect(Rect2(0, bounds.size.y - 14, bounds.size.x, 14), Color("0c151e"))
	canvas.draw_rect(Rect2(0, bounds.size.y - 16, bounds.size.x, 2), Color("52646a"))

static func round_icon(canvas: CanvasItem, center: Vector2, kind: String, color: Color, scale_value: float, compressed: bool, temporary: bool) -> void:
	var pixel := maxi(1, roundi(scale_value * 2.0))
	canvas.draw_set_transform(center.round(), 0, Vector2.ONE * pixel)
	if compressed:
		canvas.draw_rect(Rect2(-10, -18, 20, 35), Color("0c171f"))
		canvas.draw_rect(Rect2(-10, -18, 20, 2), color)
		canvas.draw_rect(Rect2(-10, 15, 20, 2), color)
	# Each family has a different silhouette, even with all colors removed.
	var width := 7 if kind == "push" else 5
	canvas.draw_rect(Rect2(-width - 1, -7, width * 2 + 2, 21), INK)
	canvas.draw_rect(Rect2(-width, -6, width * 2, 18), Color("65767b"))
	canvas.draw_rect(Rect2(-width, -6, 2, 18), LIGHT)
	canvas.draw_rect(Rect2(width - 2, -6, 2, 18), Color("374952"))
	canvas.draw_rect(Rect2(-width - 1, 12, width * 2 + 2, 3), color)
	match kind:
		"pierce":
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(-5, -7), Vector2(-2, -14), Vector2(-1, -18), Vector2(1, -18), Vector2(2, -14), Vector2(5, -7)]), LIGHT)
			canvas.draw_rect(Rect2(-3, -8, 2, 19), Color("e6d8b4"))
		"precise":
			for x in [-5, 1]:
				canvas.draw_rect(Rect2(x, -13, 4, 9), color)
				canvas.draw_rect(Rect2(x + 1, -15, 2, 2), LIGHT)
			canvas.draw_rect(Rect2(-5, 1, 10, 2), INK)
			canvas.draw_rect(Rect2(-5, 5, 10, 2), INK)
		"push":
			canvas.draw_rect(Rect2(-8, -12, 16, 7), color)
			canvas.draw_rect(Rect2(-6, -14, 12, 2), LIGHT)
			for y in [-2, 3, 8]: canvas.draw_rect(Rect2(-7, y, 14, 2), INK)
		"bore":
			canvas.draw_rect(Rect2(-4, -11, 8, 8), color)
			canvas.draw_rect(Rect2(-2, -15, 4, 4), Color("f4d99d"))
			canvas.draw_rect(Rect2(-3, -1, 6, 9), Color("753b32"))
			canvas.draw_rect(Rect2(-1, 0, 2, 6), Color("f8c179"))
		"arc":
			for x in [-5, 3]: canvas.draw_rect(Rect2(x, -16, 2, 10), LIGHT)
			canvas.draw_rect(Rect2(-3, -10, 6, 18), Color("163640"))
			for y in [-8, -3, 2, 7]: canvas.draw_rect(Rect2(-6, y, 12, 2), color)
		"charge":
			canvas.draw_rect(Rect2(-4, -13, 8, 8), Color("edc47a"))
			canvas.draw_rect(Rect2(-2, -16, 4, 3), LIGHT)
			canvas.draw_rect(Rect2(-3, -1, 6, 9), INK)
			canvas.draw_rect(Rect2(-1, 0, 2, 7), Color("edc47a"))
			canvas.draw_rect(Rect2(-3, 2, 6, 2), Color("edc47a"))
		_:
			canvas.draw_rect(Rect2(-4, -11, 8, 5), color)
			canvas.draw_rect(Rect2(-2, -14, 4, 3), LIGHT)
			canvas.draw_rect(Rect2(-4, 0, 8, 3), INK)
	if temporary:
		canvas.draw_rect(Rect2(-10, -15, 2, 8), Color("78c9ed"))
		canvas.draw_rect(Rect2(8, 5, 2, 8), Color("78c9ed"))
	canvas.draw_set_transform(Vector2.ZERO)
