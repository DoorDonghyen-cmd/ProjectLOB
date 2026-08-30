class_name RandomStreams
extends RefCounted

## 런 결과에 영향을 주는 난수와 화면 연출 난수를 분리한다.
## 게임플레이는 이름별 스트림을 사용해 한 시스템의 추첨 횟수가 다른 시스템을 흔들지 않는다.

const GAMEPLAY_STREAMS := ["map", "encounter", "reward", "shop", "event", "combat"]

static var _gameplay_seed: int = 0
static var _fx_seed: int = 0
static var _streams: Dictionary = {}
static var _draw_counts: Dictionary = {}
static var _fx_rng := RandomNumberGenerator.new()
static var _fx_draw_count: int = 0
static var _configured: bool = false


static func begin_run(gameplay_seed: int = 0, fx_seed: int = 0) -> int:
	_gameplay_seed = gameplay_seed if gameplay_seed != 0 else _runtime_seed()
	_fx_seed = fx_seed if fx_seed != 0 else _runtime_seed()
	_streams.clear()
	_draw_counts.clear()
	for stream_name in GAMEPLAY_STREAMS:
		_create_stream(stream_name)
	_fx_rng.seed = _fx_seed
	_fx_draw_count = 0
	_configured = true
	return _gameplay_seed


static func gameplay_seed() -> int:
	_ensure_configured()
	return _gameplay_seed


static func fx_seed() -> int:
	_ensure_configured()
	return _fx_seed


static func gameplay_float(stream_name: String) -> float:
	var rng := _stream(stream_name)
	_count_draw(stream_name)
	return rng.randf()


static func gameplay_int(minimum: int, maximum: int, stream_name: String) -> int:
	var rng := _stream(stream_name)
	_count_draw(stream_name)
	return rng.randi_range(minimum, maximum)


static func gameplay_pick(values: Array, stream_name: String) -> Variant:
	if values.is_empty():
		return null
	return values[gameplay_int(0, values.size() - 1, stream_name)]


static func gameplay_shuffle(values: Array, stream_name: String) -> void:
	for i in range(values.size() - 1, 0, -1):
		var swap_index := gameplay_int(0, i, stream_name)
		var value = values[i]
		values[i] = values[swap_index]
		values[swap_index] = value


static func fx_float() -> float:
	_ensure_configured()
	_fx_draw_count += 1
	return _fx_rng.randf()


static func fx_float_range(minimum: float, maximum: float) -> float:
	_ensure_configured()
	_fx_draw_count += 1
	return _fx_rng.randf_range(minimum, maximum)


static func snapshot() -> Dictionary:
	_ensure_configured()
	var stream_states: Dictionary = {}
	for stream_name in _streams.keys():
		var rng: RandomNumberGenerator = _streams[stream_name]
		stream_states[stream_name] = {
			"state": rng.state,
			"draws": int(_draw_counts.get(stream_name, 0)),
		}
	return {
		"gameplay_seed": _gameplay_seed,
		"fx_seed": _fx_seed,
		"streams": stream_states,
		"fx_state": _fx_rng.state,
		"fx_draws": _fx_draw_count,
	}


static func restore(state: Dictionary) -> Error:
	var gameplay_seed := int(state.get("gameplay_seed", 0))
	if gameplay_seed == 0:
		return ERR_INVALID_DATA
	begin_run(gameplay_seed, int(state.get("fx_seed", 0)))
	var stream_states: Dictionary = state.get("streams", {})
	for stream_name in stream_states.keys():
		var rng := _stream(str(stream_name))
		var stream_state: Dictionary = stream_states[stream_name]
		rng.state = int(stream_state.get("state", rng.state))
		_draw_counts[str(stream_name)] = int(stream_state.get("draws", 0))
	_fx_rng.state = int(state.get("fx_state", _fx_rng.state))
	_fx_draw_count = int(state.get("fx_draws", 0))
	return OK


static func _stream(stream_name: String) -> RandomNumberGenerator:
	_ensure_configured()
	if not _streams.has(stream_name):
		_create_stream(stream_name)
	return _streams[stream_name]


static func _create_stream(stream_name: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _derive_seed(_gameplay_seed, stream_name)
	_streams[stream_name] = rng
	_draw_counts[stream_name] = 0


static func _count_draw(stream_name: String) -> void:
	_draw_counts[stream_name] = int(_draw_counts.get(stream_name, 0)) + 1


static func _ensure_configured() -> void:
	if not _configured:
		begin_run()


static func _derive_seed(root_seed: int, stream_name: String) -> int:
	var derived := root_seed & 0x7fffffffffffffff
	for byte in stream_name.to_utf8_buffer():
		derived = int((derived * 1103515245 + int(byte) + 12345) & 0x7fffffffffffffff)
	return derived if derived != 0 else 1


static func _runtime_seed() -> int:
	var seed_value := int(Time.get_unix_time_from_system() * 1000000.0) ^ Time.get_ticks_usec()
	seed_value &= 0x7fffffffffffffff
	return seed_value if seed_value != 0 else 1
