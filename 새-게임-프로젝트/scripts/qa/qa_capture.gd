class_name QACapture
extends RefCounted


static func capture(viewport: Viewport, directory: String, checkpoint_id: String) -> Dictionary:
	var result := {
		"requested": true,
		"captured": false,
		"classification": "qa_infrastructure",
		"path": "",
		"error": "",
	}
	if viewport == null:
		result.error = "viewport가 없음"
		return result
	if directory.strip_edges().is_empty():
		result.error = "출력 경로가 비어 있음"
		return result
	# headless의 dummy renderer에서 get_image()를 호출하면 빈 이미지뿐 아니라 엔진 오류가
	# 발생한다. 의미 단위 JSON 검증은 계속하고 캡처만 인프라 상태로 명시한다.
	if DisplayServer.get_name() == "headless":
		result.error = "headless display는 PNG 캡처를 지원하지 않음"
		return result

	var global_directory := ProjectSettings.globalize_path(directory)
	var directory_error := DirAccess.make_dir_recursive_absolute(global_directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		result.error = "캡처 폴더 생성 실패: %d" % directory_error
		return result

	var texture := viewport.get_texture()
	if texture == null:
		result.error = "viewport texture를 읽을 수 없음"
		return result
	var image := texture.get_image()
	if image == null or image.is_empty():
		result.error = "렌더 이미지가 비어 있음"
		return result

	var safe_id := _safe_file_name(checkpoint_id)
	var path := "%s/%s.png" % [directory.trim_suffix("/"), safe_id]
	var save_error := image.save_png(ProjectSettings.globalize_path(path))
	if save_error != OK:
		result.error = "PNG 저장 실패: %d" % save_error
		return result

	result.captured = true
	result.classification = "evidence"
	result.path = path
	result["width"] = image.get_width()
	result["height"] = image.get_height()
	return result


static func unavailable(reason: String) -> Dictionary:
	return {
		"requested": false,
		"captured": false,
		"classification": "qa_infrastructure",
		"path": "",
		"error": reason,
	}


static func _safe_file_name(value: String) -> String:
	var safe := ""
	for character in value.to_lower():
		if character in "abcdefghijklmnopqrstuvwxyz0123456789_-":
			safe += character
		else:
			safe += "_"
	return safe if not safe.is_empty() else "checkpoint"
