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
	var scale := float(source.get("text_scale", 1.0))
	if scale not in [0.9, 1.0, 1.1]:
		scale = 1.0
	var motion := str(source.get("motion", "normal"))
	if motion not in ["normal", "fast", "instant"]:
		motion = "normal"
	data.text_scale = scale
	data.motion = motion
	data.hints = bool(source.get("hints", true))
	data.guide_seen = bool(source.get("guide_seen", false))
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
	data[key] = value
	return save_preferences(path)

func reset(path: String = SAVE) -> Error:
	data = DEFAULTS.duplicate(true)
	return save_preferences(path)

func motion_scale() -> float:
	return {"normal": 1.0, "fast": 0.55, "instant": 0.05}.get(str(data.motion), 1.0)
