class_name QARunJournal
extends RefCounted

const RandomStreamsScript := preload("res://scripts/core/random_streams.gd")

var output_directory: String = ""
var manifest: Dictionary = {}
var step: int = 0


func configure(session_manifest: Dictionary, directory: String) -> Error:
	if directory.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if error != OK and error != ERR_ALREADY_EXISTS:
		return error
	output_directory = directory.trim_suffix("/")
	manifest = session_manifest.duplicate(true)
	step = 0
	return _flush({"action": "configured"}, {})


func record(action: Dictionary, progress: Dictionary) -> Error:
	step += 1
	return _flush(action, progress)


func latest() -> Dictionary:
	if output_directory.is_empty():
		return {}
	var path := "%s/progress.json" % output_directory
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _flush(action: Dictionary, progress: Dictionary) -> Error:
	var value := {
		"schema_version": 1,
		"manifest": manifest.duplicate(true),
		"step": step,
		"last_action": action.duplicate(true),
		"progress": progress.duplicate(true),
		"rng": RandomStreamsScript.snapshot(),
		"updated_at": Time.get_datetime_string_from_system(false, true),
	}
	var file := FileAccess.open("%s/progress.json" % output_directory, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value, "\t") + "\n")
	return OK
