extends RefCounted
## Shared pixel construction for the whole combat console, not an image filter.
const FONT = preload("res://redesign/combat_pixel_font.tres")
const INK := Color("d4ddd5")
const MUTED := Color("8dabae")
const SELECT := Color("b8d4bf")
const HEAT := Color("e39b79")
const COOL := Color("9abdc8")
static var cache := {}

static func box(kind: String = "card", state: String = "normal") -> StyleBoxTexture:
	var key := kind + "_" + state
	if not cache.has(key):
		cache[key] = load("res://assets/ui/console/%s.tres" % key)
	# Callers can retain their existing hit-area/content margins independently.
	return cache[key].duplicate() as StyleBoxTexture

static func glyph(kind: String) -> Texture2D:
	var key := "glyph_" + kind
	if not cache.has(key):
		var rows: Array = []
		match kind:
			"reload": rows = ["00111100","01100010","11000000","11000111","00000111","00000011","01000110","00111100"]
			"fire": rows = ["11000000","11110000","11111100","11111111","11111111","11111100","11110000","11000000"]
			_: rows = ["00000000","00000011","00000110","00001100","11011000","01110000","00100000","00000000"]
		var image := Image.create(16,16,false,Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		for y in range(rows.size()):
			for x in range(8):
				if rows[y][x] == "1": image.fill_rect(Rect2i(x*2,y*2,2,2),Color.WHITE)
		cache[key] = ImageTexture.create_from_image(image)
	return cache[key]
