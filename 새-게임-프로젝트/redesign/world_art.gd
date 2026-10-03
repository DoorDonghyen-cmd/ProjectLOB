extends RefCounted
## Asset lookup and framing shared by every gameplay screen.
const ROOT := "res://assets/art/production_20261002/"
const DEFAULT := "res://assets/art/director_20261002/transit_platform.png"
const REGIONS := ["", "foundry", "maintenance", "administration", "summit"]
static var cache: Dictionary = {}

static func texture(id: String) -> Texture2D:
	var path := DEFAULT if id.is_empty() else ROOT + id + ".png"
	if not cache.has(path):
		cache[path] = load(path) if ResourceLoader.exists(path) else load(DEFAULT)
	return cache[path] as Texture2D

static func region_texture(region: int) -> Texture2D:
	return texture(REGIONS[clampi(region, 0, 4)])

static func cover(canvas: CanvasItem, art: Texture2D, bounds: Rect2, tint: Color = Color.WHITE) -> void:
	var source := art.get_size()
	var scale_factor := maxf(bounds.size.x / source.x, bounds.size.y / source.y)
	var region_size := bounds.size / scale_factor
	canvas.draw_texture_rect_region(art, bounds, Rect2((source - region_size) * 0.5, region_size), tint)

static func contain(canvas: CanvasItem, art: Texture2D, bounds: Rect2, tint: Color = Color.WHITE) -> void:
	var dimensions := art.get_size()
	var scale_factor := minf(bounds.size.x / dimensions.x, bounds.size.y / dimensions.y)
	var fitted := dimensions * scale_factor
	canvas.draw_texture_rect(art, Rect2(bounds.position + (bounds.size - fitted) * 0.5, fitted), false, tint)
