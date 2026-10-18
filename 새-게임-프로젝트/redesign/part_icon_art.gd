extends RefCounted
## Hand-authored UI pixel art. One logical grid, integer display scales, no filtering.
## Quiet steel masses, local brass/copper, inset seams; functional glyphs stay in UI.
const DARK := Color("293b40")
const SHADE := Color("475650")
const STEEL := Color("718077")
const LIGHT := Color("a7ad96")
const COPPER := Color("927051")
const RUST := Color("615343")
const INSET := Color("35464b")
const SIZE := Vector2(32, 24)
const IDS := ["volley_drive", "thermal_drive", "siege_drive", "ordinary_chain", "compression_sink", "cooling_breech", "chain_sink", "indexer", "radiator", "reclaimer", "ember_core", "lens", "loader", "supply", "coil", "capacitor", "rammer", "sequencer", "duplex", "igniter", "breaker", "executioner", "reserve", "opening", "afterburner", "field_press", "overbore", "inferno", "arc_splitter", "momentum", "triad"]

static func rect(c: CanvasItem, x: float, y: float, w: float, h: float, color: Color) -> void:
	c.draw_rect(Rect2(x, y, w, h), color)

static func metal(c: CanvasItem, x: int, y: int, w: int, h: int, color: Color = STEEL) -> void:
	# Broken top highlight and broad lower/right shade, not a bright full outline.
	rect(c, x + 1, y + 2, w, h - 1, DARK)
	rect(c, x, y + 1, w - 1, h - 1, SHADE)
	rect(c, x, y + 1, w - 3, maxi(2, h - 4), color)
	rect(c, x + 2, y, maxi(2, w - 5), 1, LIGHT)

static func disc(c: CanvasItem, x: int, y: int, radius: int, color: Color) -> void:
	for row in range(-radius, radius + 1):
		var span := floori(sqrt(float(radius * radius - row * row)))
		rect(c, x - span, y + row, span * 2 + 1, 1, color)

static func flange(c: CanvasItem, x: int, y: int, radius: int = 7) -> void:
	disc(c, x + 1, y + 1, radius, DARK)
	disc(c, x, y, radius, SHADE)
	disc(c, x - 1, y - 1, radius - 1, STEEL)
	rect(c, x - 3, y - radius + 1, 5, 1, LIGHT)

static func pipe(c: CanvasItem, x: int, y: int, w: int, h: int) -> void:
	rect(c, x, y, w, h, RUST)
	rect(c, x, y, maxi(1, w - 1), maxi(1, h - 1), COPPER)

static func feet(c: CanvasItem, left: int, right: int, y: int) -> void:
	metal(c, left, y, 5, 3)
	metal(c, right, y, 5, 3)

static func draw(c: CanvasItem, id: String, center: Vector2, accent: Color, factor: float) -> void:
	var unit := 1 if factor < 0.75 else 2
	c.draw_set_transform((center - SIZE * unit * 0.5).floor(), 0, Vector2.ONE * unit)
	var accent_metal := accent.lerp(STEEL, 0.48)
	match id:
		"volley_drive":
			metal(c,3,15,26,6)
			for x in [5,13,21]:
				metal(c,x,3,5,13)
				rect(c,x+1,6,2,6,COPPER)
			pipe(c,7,17,18,2)
		"thermal_drive":
			metal(c,6,3,20,18)
			for x in [3,8,22,27]: metal(c,x,6,3,11)
			disc(c,16,12,6,INSET)
			disc(c,16,12,4,COPPER)
			rect(c,15,8,2,7,accent_metal)
		"siege_drive":
			metal(c,2,8,28,9)
			metal(c,6,4,9,17)
			rect(c,17,10,12,4,INSET)
			pipe(c,14,6,12,3)
			metal(c,25,6,5,13,COPPER)
		"ordinary_chain":
			metal(c, 4, 4, 8, 11)
			metal(c, 20, 4, 8, 11)
			pipe(c, 10, 11, 5, 4)
			pipe(c, 13, 13, 6, 4)
			pipe(c, 17, 10, 5, 4)
			metal(c, 11, 16, 11, 5)
			rect(c, 6, 6, 3, 6, INSET)
			rect(c, 22, 6, 3, 6, INSET)
			rect(c, 14, 17, 4, 2, accent_metal)
		"compression_sink":
			pipe(c, 2, 9, 27, 4)
			metal(c, 7, 4, 19, 15)
			for y in [6, 10, 14]:
				rect(c, 9, y, 13, 2, INSET)
				rect(c, 10, y, 10, 1, accent_metal)
			metal(c, 12, 18, 9, 3)
		"cooling_breech":
			metal(c, 6, 5, 22, 13)
			for x in [5, 9, 13]:
				rect(c, x, 3, 2, 18, SHADE)
				rect(c, x, 3, 1, 15, LIGHT)
			metal(c, 18, 8, 9, 7, accent_metal)
			rect(c, 22, 10, 5, 3, INSET)
		"chain_sink":
			pipe(c, 5, 17, 22, 3)
			for i in range(3):
				var x := 4 + i * 9
				metal(c, x, 5 - i, 6, 13 + i)
				rect(c, x + 1, 7 - i, 2, 7, INSET)
				rect(c, x + 1, 13 - i, 2, 2, accent_metal if i == 2 else RUST)
		"indexer":
			metal(c, 4, 5, 8, 15)
			flange(c, 20, 12, 8)
			disc(c, 20, 12, 5, INSET)
			for y in [7, 12, 17]: rect(c, 18, y, 4, 2, COPPER)
			pipe(c, 10, 11, 7, 3)
			rect(c, 5, 7, 4, 5, accent_metal)
		"radiator":
			metal(c, 4, 4, 25, 16)
			for x in [7, 11, 15, 19, 23]:
				rect(c, x, 4, 2, 14, INSET)
				rect(c, x - 1, 5, 1, 11, LIGHT)
			pipe(c, 3, 18, 26, 2)
		"reclaimer":
			pipe(c, 2, 14, 12, 4)
			pipe(c, 23, 5, 6, 4)
			flange(c, 16, 12, 8)
			disc(c, 16, 12, 5, INSET)
			disc(c, 16, 12, 3, COPPER)
			rect(c, 15, 10, 5, 2, LIGHT)
			feet(c, 8, 22, 20)
		"ember_core":
			metal(c, 7, 4, 19, 16)
			rect(c, 11, 7, 10, 10, INSET)
			rect(c, 13, 9, 6, 7, COPPER)
			rect(c, 14, 10, 3, 4, accent_metal)
			for y in [7, 12, 17]:
				pipe(c, 3, y, 5, 2)
				pipe(c, 25, y, 4, 2)
		"lens":
			metal(c, 3, 9, 26, 7)
			metal(c, 8, 6, 12, 4)
			rect(c, 12, 6, 6, 2, COPPER)
			metal(c, 25, 7, 5, 10)
			rect(c, 27, 10, 2, 4, INSET)
			feet(c, 7, 20, 16)
		"loader":
			metal(c, 6, 12, 19, 8)
			flange(c, 11, 13, 5)
			pipe(c, 12, 9, 6, 4)
			pipe(c, 17, 6, 4, 5)
			pipe(c, 20, 3, 4, 5)
			metal(c, 22, 2, 7, 4)
			rect(c, 15, 16, 6, 1, LIGHT)
		"supply":
			metal(c, 8, 3, 17, 15)
			metal(c, 6, 2, 21, 3)
			metal(c, 10, 16, 13, 5)
			rect(c, 12, 6, 7, 10, INSET)
			for y in [7, 10, 13]: rect(c, 13, y, 5, 1, COPPER)
		"coil":
			metal(c, 3, 8, 27, 8)
			for x in [8, 12, 16, 20]:
				pipe(c, x, 5, 3, 14)
				rect(c, x, 6, 1, 10, LIGHT)
			feet(c, 4, 24, 18)
		"capacitor":
			metal(c, 6, 6, 9, 14)
			metal(c, 18, 3, 9, 17)
			for x in [9, 21]:
				rect(c, x, 10, 3, 6, accent_metal)
				pipe(c, x, 20, 2, 3)
			pipe(c, 13, 17, 7, 2)
		"rammer":
			metal(c, 3, 7, 13, 12)
			pipe(c, 14, 10, 12, 5)
			rect(c, 16, 10, 9, 1, LIGHT)
			metal(c, 25, 4, 5, 17)
			rect(c, 5, 10, 7, 4, INSET)
		"sequencer":
			metal(c, 3, 5, 27, 14)
			for x in [7, 14, 21]:
				rect(c, x, 8, 4, 7, INSET)
				rect(c, x + 1, 9, 2, 3, accent_metal)
				pipe(c, x, 19, 3, 3)
		"duplex":
			metal(c, 5, 5, 22, 6)
			metal(c, 5, 14, 22, 6)
			metal(c, 10, 10, 8, 4, COPPER)
			for y in [6, 15]:
				rect(c, 23, y, 3, 4, INSET)
				rect(c, 7, y, 9, 1, LIGHT)
		"igniter":
			pipe(c, 14, 2, 4, 5)
			metal(c, 11, 6, 11, 8, LIGHT)
			for y in [8, 11]: rect(c, 11, y, 8, 1, SHADE)
			metal(c, 8, 14, 17, 6, COPPER)
			pipe(c, 14, 19, 4, 4)
			rect(c, 16, 2, 1, 3, accent_metal)
		"breaker":
			metal(c, 4, 4, 9, 16)
			metal(c, 20, 4, 9, 16)
			metal(c, 10, 17, 13, 4)
			pipe(c, 11, 8, 4, 7)
			pipe(c, 18, 8, 4, 7)
			rect(c, 13, 9, 2, 3, accent_metal)
			rect(c, 18, 11, 2, 3, accent_metal)
		"executioner":
			metal(c, 3, 10, 11, 7)
			flange(c, 21, 10, 8)
			disc(c, 21, 10, 5, INSET)
			rect(c, 20, 6, 2, 8, accent_metal)
			rect(c, 17, 9, 8, 2, accent_metal)
			feet(c, 7, 19, 19)
		"reserve":
			metal(c, 5, 7, 10, 12)
			metal(c, 17, 3, 10, 16)
			rect(c, 8, 9, 4, 7, INSET)
			rect(c, 20, 6, 4, 10, INSET)
			metal(c, 3, 18, 27, 4, COPPER)
		"opening", "afterburner":
			metal(c, 3, 8, 27, 9)
			var end := 5 if id == "opening" else 23
			metal(c, end, 4, 5, 16, COPPER)
			rect(c, end + 1, 7, 2, 5, accent_metal)
			rect(c, 11, 11, 9, 2, INSET)
			feet(c, 9, 18, 18)
		"field_press":
			metal(c, 4, 3, 25, 5)
			metal(c, 4, 17, 25, 5)
			pipe(c, 5, 8, 3, 9)
			pipe(c, 24, 8, 3, 9)
			metal(c, 12, 7, 10, 4)
			metal(c, 12, 14, 10, 3)
			rect(c, 15, 11, 4, 3, accent_metal)
		"overbore":
			metal(c, 3, 6, 16, 14)
			flange(c, 22, 12, 8)
			disc(c, 22, 12, 6, COPPER)
			disc(c, 22, 12, 4, INSET)
			rect(c, 6, 7, 10, 2, LIGHT)
			rect(c, 6, 12, 4, 5, SHADE)
		"inferno":
			metal(c, 8, 5, 18, 16, COPPER)
			pipe(c, 11, 1, 4, 4)
			pipe(c, 21, 2, 4, 3)
			rect(c, 12, 8, 9, 10, INSET)
			for y in [9, 13, 17]: rect(c, 12, y, 7, 2, accent_metal)
			metal(c, 3, 10, 5, 8)
		"arc_splitter":
			metal(c, 13, 12, 8, 10)
			pipe(c, 8, 8, 7, 5)
			pipe(c, 19, 8, 7, 5)
			metal(c, 3, 2, 8, 8)
			metal(c, 23, 2, 7, 8)
			rect(c, 5, 4, 3, 3, accent_metal)
			rect(c, 25, 4, 3, 3, accent_metal)
		"momentum":
			flange(c, 13, 12, 9)
			disc(c, 13, 12, 5, INSET)
			disc(c, 13, 12, 2, COPPER)
			pipe(c, 14, 11, 12, 4)
			metal(c, 25, 6, 5, 13)
			feet(c, 5, 17, 20)
		"triad":
			metal(c, 3, 16, 27, 6)
			for i in range(3):
				metal(c, 4 + i * 9, 3, 6, 13)
				rect(c, 5 + i * 9, 6, 3, 6, accent_metal if i == 2 else COPPER)
		"none":
			rect(c, 14, 6, 3, 12, SHADE)
			rect(c, 9, 11, 13, 3, SHADE)
	c.draw_set_transform(Vector2.ZERO)
