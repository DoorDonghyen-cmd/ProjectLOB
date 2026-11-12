extends RefCounted
## Shape and intensity follow the enhancement that reached the target.
enum Tier { STANDARD, TRACER, EMBERS, SHOCKWAVE }
const Ranged = preload("res://redesign/ranged.gd")
const TRAIL_LENGTHS := [0.0, 72.0, 104.0, 132.0]
const SOOT := Color("a67756")
const TRACER_SHARDS := [Vector2(58, -23), Vector2(51, 21), Vector2(-55, 21), Vector2(-48, -16)]
const EMBER_SHARDS := [Vector2(58, -29), Vector2(79, -13), Vector2(76, 12), Vector2(61, 26), Vector2(-76, 17), Vector2(-65, -19), Vector2(44, 37)]
const EMBER_HIGHLIGHTS := [Vector2(93, -28), Vector2(-79, -25)]
const EMBER_COOLING := [Vector2(43, 33), Vector2(-39, 36), Vector2(66, 28)]
const SHOCKWAVE_SHARDS := [Vector2(67, 18), Vector2(-64, 19), Vector2(65, -23), Vector2(-67, -17)]

static func tier(result: Dictionary, style: Dictionary, attack: bool) -> Tier:
	var direct_damage := int(result.get("damage", 0)) - int(result.get("detonation", 0))
	if not attack or direct_damage <= 0 or bool(result.get("intercept", false)) or Ranged.is_projectile(int(result.get("target", -1))):
		return Tier.STANDARD
	if style.operator == "multiply":
		var math: Dictionary = result.get("math", {})
		var weapon_factor := int(result.get("weapon_factor", math.get("weapon_factor", 1)))
		var percent: int = max(
			int(result.get("engine_percent", math.get("engine_percent", 100))),
			int(math.get("tag_percent", 100)),
			int(result.get("gate_percent", math.get("gate_percent", 100))),
			int(result.get("overdrive_percent", math.get("overdrive_percent", 100)))
		)
		return Tier.SHOCKWAVE if int(style.rank) >= 2 or weapon_factor >= 3 or percent >= 300 else Tier.EMBERS
	if style.operator == "repeat":
		if style.sources.has("resonator"): return Tier.EMBERS
		if style.sources.has("duplex") or style.added: return Tier.TRACER
	return Tier.TRACER if style.operator == "add" else Tier.STANDARD

static func trail_limit(option: int) -> float:
	return TRAIL_LENGTHS[option]

static func draw_muzzle(canvas: CanvasItem, progress: float, option: int, ink: Color) -> void:
	if option == Tier.STANDARD or progress >= 0.26: return
	var phase := clampf(progress / 0.26, 0.0, 1.0)
	var opacity := 1.0 - phase
	var reach := 7.0 + phase * (11.0 if option == Tier.SHOCKWAVE else 7.0)
	var hot := Color(ink.lightened(0.35), opacity)
	for side in [-1, 1]:
		_bar(canvas, -3, 4, side * reach - 1, 2, Color(ink, opacity * 0.8))
		_bar(canvas, 5, 11, side * (reach + 3) - 1, 2, hot)
	if option == Tier.SHOCKWAVE:
		_bar(canvas, 12, 15, -reach * 0.55, roundf(reach * 1.1), Color(ink, opacity * 0.7))
		_bar(canvas, -6, 18, -1, 2, hot)

static func _bar(canvas: CanvasItem, left: float, right: float, y: float, height: float, color: Color) -> void:
	if right <= left: return
	canvas.draw_rect(Rect2(roundf(left), roundf(y), maxf(1.0, roundf(right - left)), height), color)

static func draw_trail(canvas: CanvasItem, path: Dictionary, reach: float, option: int, ink: Color, camera: Transform2D) -> void:
	if reach < 3.0: return
	canvas.draw_set_transform_matrix(camera * Transform2D(path.angle, path.rear.round()))
	match option:
		Tier.TRACER:
			_bar(canvas, -reach, 0, 0, 2, Color(ink, 0.45))
			_bar(canvas, -reach * 0.63, 0, -1, 2, Color(ink, 0.9))
			_bar(canvas, -reach * 0.25, 0, -1, 1, ink.lightened(0.44))
		Tier.EMBERS:
			for i in range(5):
				var start := -reach * float(i) / 5.0
				var length := reach * (0.18 - i * 0.022)
				var tone := ink.lerp(SOOT, i * 0.14)
				_bar(canvas, start - length, start, -2 + i % 2, 4 if i == 0 else 2, Color(tone, 1.0 - i * 0.15))
				if i == 1 or i == 3: _bar(canvas, start - length, start - length + 3, 3, 2, Color(ink, 0.7 - i * 0.1))
		Tier.SHOCKWAVE:
			_bar(canvas, -reach, 0, -1, 3, Color(ink.darkened(0.28), 0.72))
			_bar(canvas, -reach * 0.78, 0, -1, 2, ink)
			_bar(canvas, -reach * 0.43, 0, -1, 1, ink.lightened(0.52))
			_bar(canvas, -reach * 0.82, -reach * 0.16, -5, 2, Color(ink, 0.52))
			_bar(canvas, -reach * 0.57, -reach * 0.11, 4, 2, Color(ink, 0.67))
	canvas.draw_set_transform_matrix(camera)

static func _shards(canvas: CanvasItem, offsets: Array, progress: float, ink: Color, kick: float) -> void:
	for i in range(offsets.size()):
		var ray: Vector2 = offsets[i]
		var point := (ray * (0.46 + (1.0 - pow(1.0 - progress, 2.0)) * kick)).round()
		var dimensions := Vector2(9 if i % 3 == 0 else 5, 3 if i % 2 == 0 else 2)
		canvas.draw_rect(Rect2(point, dimensions), Color(ink if i % 3 == 0 else ink.darkened(0.22), 1.0 - progress))

static func draw_contact(canvas: CanvasItem, center: Vector2, pulse: float, option: int, ink: Color, camera: Transform2D, part_powered: bool = false) -> void:
	var duration := 0.48 if option == Tier.TRACER else 0.78
	if option == Tier.STANDARD or pulse >= duration: return
	canvas.draw_set_transform_matrix(camera * Transform2D(0, center.round()))
	var phase := pulse / duration
	var hot := ink.lightened(0.45)
	if part_powered and phase < 0.38:
		var spread := phase / 0.38
		var spark := Color(hot, 1.0 - spread)
		for side: int in [-1, 1]:
			var edge := side * (15.0 + spread * 12.0)
			_bar(canvas, edge - 4, edge + 4, -11.0 - spread * 9.0, 3, spark)
			_bar(canvas, edge - 3, edge + 3, 9.0 + spread * 8.0, 2, spark)
	match option:
		Tier.TRACER:
			if phase < 0.22:
				_bar(canvas, -22, 25, 3, 3, hot)
				_bar(canvas, -4, 5, -9, 25, Color(ink, 0.85))
			_shards(canvas, TRACER_SHARDS, phase, hot, 0.64)
		Tier.EMBERS:
			if phase < 0.32:
				_bar(canvas, -25, 21, 3, 5, Color(ink, 1.0 - phase))
				_bar(canvas, -14, 12, 2, 3, hot)
			_shards(canvas, EMBER_SHARDS, phase, ink, 0.79)
			_shards(canvas, EMBER_HIGHLIGHTS, phase, hot, 0.69)
			if phase > 0.34:
				_shards(canvas, EMBER_COOLING, phase, ink.lerp(SOOT, 0.65), 0.63)
		Tier.SHOCKWAVE:
			# Start beyond the wider damage readout on high-multiplier hits.
			var span := 62.0 + phase * 28.0
			var lift := 15.0 + phase * 19.0
			var ink_fade := Color(ink, (1.0 - phase) * 0.95)
			for side: int in [-1, 1]:
				var x := side * span
				_bar(canvas, x - 2, x + 2, -lift * 0.46, roundf(lift * 0.92), ink_fade)
				for edge: int in [-1, 1]:
					_bar(canvas, x - side * 5 - 4, x - side * 5 + 4, edge * lift * 0.64, 3, ink_fade)
					_bar(canvas, x - side * 13 - 5, x - side * 13 + 5, edge * lift * 0.86, 3, ink_fade)
			if phase < 0.36:
				_bar(canvas, -span - 6, span + 8, -2, 4, Color(ink, 0.9 - phase))
				_bar(canvas, -12, 17, -2, 2, hot)
			_shards(canvas, SHOCKWAVE_SHARDS, phase, hot, 0.79)
	canvas.draw_set_transform_matrix(camera)
