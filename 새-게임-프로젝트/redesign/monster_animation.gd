extends RefCounted
## Presentation sampling reads exported SpriteFrames timing, never combat state.
const FRAMES = preload("res://assets/art/monster_motion_20261011/eavesback_frames.tres")
const Data = preload("res://redesign/eavesback_animation_data.gd")

static func frame(tag: String, seconds: float) -> AtlasTexture:
	var duration := 0.0
	for i in range(FRAMES.get_frame_count(tag)):
		duration += FRAMES.get_frame_duration(tag,i) / FRAMES.get_animation_speed(tag)
	var time := fmod(maxf(0.0,seconds),duration) if FRAMES.get_animation_loop(tag) else minf(maxf(0.0,seconds),duration-0.00001)
	for i in range(FRAMES.get_frame_count(tag)):
		time -= FRAMES.get_frame_duration(tag,i) / FRAMES.get_animation_speed(tag)
		if time < 0.0: return FRAMES.get_frame_texture(tag,i) as AtlasTexture
	return FRAMES.get_frame_texture(tag,0) as AtlasTexture

static func index_of(texture: AtlasTexture) -> int:
	return int(texture.region.position.x / Data.CELL.x)

static func position(texture: AtlasTexture, foot: Vector2) -> Vector2:
	var result: Vector2 = foot - Data.ANCHORS[index_of(texture)] * Data.SCALE
	result.x = roundf(result.x)
	return result

static func visible_rect(texture: AtlasTexture, foot: Vector2) -> Rect2:
	var bounds: Rect2 = Data.BOUNDS[index_of(texture)]
	return Rect2(position(texture,foot) + bounds.position * Data.SCALE, bounds.size * Data.SCALE)
