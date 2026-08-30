extends SceneTree
## 고정 전투 QA 브리지 실행기.
##
## 실행 예:
##   Godot --headless --path <project> --script res://tests/qa_session_runner.gd
##
## 선택 환경 변수:
##   QA_OUTPUT_DIR=user://qa_runtime/fixed_ammo
##   QA_SESSION_ID=qa-manual-session
##   QA_COMMIT=<git commit>
##
## 실행기는 state_0000.json을 만든 뒤 command_0000.json을 기다린다.
## command 파일은 QABridge action 계약과 동일한 JSON이며 step을 포함해야 한다.

const ManifestScript := preload("res://scripts/qa/qa_session_manifest.gd")
const BridgeScript := preload("res://scripts/qa/qa_bridge.gd")
const PlaytestLoggerScript := preload("res://scripts/core/playtest_logger.gd")

const DEFAULT_OUTPUT := "user://qa_runtime/fixed_ammo"

var bridge
var output_directory: String


func _initialize() -> void:
	RunManager.infiltration_risk_level = 1
	RunManager.meta_ascension_level = 0
	PlaytestLoggerScript.enabled = false

	output_directory = OS.get_environment("QA_OUTPUT_DIR")
	if output_directory.is_empty():
		output_directory = DEFAULT_OUTPUT
	var session_id := OS.get_environment("QA_SESSION_ID")
	if session_id.is_empty():
		session_id = "qa-fixed-%d" % Time.get_ticks_msec()
	var commit_hash := OS.get_environment("QA_COMMIT")
	if commit_hash.is_empty():
		commit_hash = "working-tree"

	var manifest := ManifestScript.create(
		session_id,
		commit_hash,
		"quick_smoke",
		"fixed_ammo_specialty",
		commit_hash == "working-tree"
	)
	bridge = BridgeScript.new()
	var error: Error = bridge.configure(manifest, output_directory)
	if error != OK:
		printerr("QA runner configure 실패: %d" % error)
		quit(1)
		return

	var gun: GunData = load("res://resources/guns/revolver.tres")
	var enemies: Array[EnemyData] = [load("res://resources/enemies/rusher.tres")]
	var deck: Array[BulletData] = [
		load("res://resources/bullets/cal_9mm.tres"),
		load("res://resources/bullets/chain.tres"),
		load("res://resources/bullets/marker.tres"),
		load("res://resources/bullets/borer.tres"),
		load("res://resources/bullets/finale.tres"),
	]
	var parts: Array[PartData] = []
	error = bridge.start_fixed_combat(gun, enemies, deck, parts)
	if error != OK:
		printerr("QA runner 전투 시작 실패: %d" % error)
		quit(1)
		return

	print("QA bridge ready: %s" % ProjectSettings.globalize_path(output_directory))
	print("Waiting for command_%04d.json" % bridge.step)


func _process(_delta: float) -> bool:
	if bridge == null or not bridge.active:
		return false
	var command_path := "%s/command_%04d.json" % [output_directory, bridge.step]
	if not FileAccess.file_exists(command_path):
		return false

	var file := FileAccess.open(command_path, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(command_path))
	if not parsed is Dictionary:
		printerr("QA command JSON 파싱 실패: %s" % command_path)
		return false

	var result: Dictionary = bridge.submit_action(parsed)
	print(JSON.stringify(result))
	if not bool(result.get("accepted", false)):
		print("Command rejected. Waiting for command_%04d.json" % bridge.step)
		return false

	var state: Dictionary = bridge.state_bundle()
	var combat_state := str(state.player_view.combat_state)
	if combat_state == "won" or combat_state == "lost":
		print("QA fixed combat finished: %s" % combat_state)
		bridge.close()
		quit(0)
		return true
	print("Waiting for command_%04d.json" % bridge.step)
	return false
