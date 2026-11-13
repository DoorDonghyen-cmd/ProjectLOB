extends RefCounted
## Player-facing UI preferences. Kept separate from campaign saves so a new run
## never resets accessibility choices.

const SAVE := "user://redesign_preferences_v1.json"
const DEFAULTS := {
	"version": 1,
	"text_scale": 1.0,
	"motion": "normal",
	"hints": true,
	"guide_seen": false,
	"effects_volume": 0.5,
	# Launch build (2026-11-12): developer tools, the legacy training mode and the tag
	# comparison toggle are hidden unless this is on (seven taps on the title wordmark).
	"dev_tools": false,
	# First-fight coach line (campaign_hud/combat.gd): shown while 상황 도움말 is on, until the
	# player has won three fights. Kept across 기본 설정으로 복원 like the guide flag.
	"coached": false,
}

var data: Dictionary = DEFAULTS.duplicate(true)

func load_preferences(path: String = SAVE) -> bool:
	data = DEFAULTS.duplicate(true)
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return false
	var source: Dictionary = parsed
	# 글자 크기(2026-11-08 디렉터 결정): 픽셀 글꼴은 16 단위, 화면은 정수 배율로 커져 90/110%가
	# 실제로 바뀌지 않거나 흐려진다. 설정에서 빼고 저장값도 100%로 읽는다.
	var scale := 1.0
	var motion := str(source.get("motion", "normal"))
	if motion not in ["normal", "fast", "instant"]:
		motion = "normal"
	data.text_scale = scale
	data.motion = motion
	data.hints = bool(source.get("hints", true))
	data.guide_seen = bool(source.get("guide_seen", false))
	data.dev_tools = bool(source.get("dev_tools", false))
	data.coached = bool(source.get("coached", false))
	var audio_value: Variant = source.get("effects_volume", 0.5)
	if (audio_value is float or audio_value is int) and is_finite(float(audio_value)):
		data.effects_volume = clampf(float(audio_value), 0.0, 1.0)
	return true

func save_preferences(path: String = SAVE) -> Error:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if FileAccess.file_exists(path):
		var remove_error := DirAccess.remove_absolute(path)
		if remove_error != OK:
			return remove_error
	return DirAccess.rename_absolute(path + ".tmp", path)

func set_value(key: String, value: Variant, path: String = SAVE) -> Error:
	if not DEFAULTS.has(key):
		return ERR_INVALID_PARAMETER
	if key == "effects_volume":
		if not (value is float or value is int) or not is_finite(float(value)):
			return ERR_INVALID_PARAMETER
		value = clampf(float(value), 0.0, 1.0)
	data[key] = value
	return save_preferences(path)

func reset(path: String = SAVE) -> Error:
	# Not a player setting: restoring the defaults keeps the developer switch.
	var dev := bool(data.get("dev_tools", false))
	var coached := bool(data.get("coached", false))
	data = DEFAULTS.duplicate(true)
	data.dev_tools = dev
	data.coached = coached
	return save_preferences(path)

func dev_tools() -> bool:
	return bool(data.get("dev_tools", false))

func motion_scale() -> float:
	return {"normal": 1.0, "fast": 0.55, "instant": 0.05}.get(str(data.motion), 1.0)
