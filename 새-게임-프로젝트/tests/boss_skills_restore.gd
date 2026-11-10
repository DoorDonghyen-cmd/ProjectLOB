extends SceneTree
const Campaign=preload("res://redesign/campaign.gd")
var checked:=0
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var output: String=OS.get_environment("QA_OUTPUT_DIR")
	if not output.replace("\\","/").contains("/qa_runtime/boss_skills_20261106/"): quit(2); return
	var failures: Array=[]
	for tag in ["single","burst","scatter","heavy_elite","amplifier","heavy_scout"]:
		var directory: String=ProjectSettings.globalize_path("res://../qa_runtime/boss_skills_20261106/"+tag)
		var files: PackedStringArray=DirAccess.get_files_at(directory)
		files.append("Roaming/Godot/app_userdata/Last on Board - Core Redesign/city_probe.json")
		for file in files:
			if not file.begins_with("combat_") and not file.ends_with("city_probe.json"): continue
			checked+=1
			var c=Campaign.new()
			if not c.restore_state(JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(file)))): failures.append(tag+"/"+file)
	FileAccess.open(output.path_join("restore.json"),FileAccess.WRITE).store_string(JSON.stringify({"checks":checked,"failures":failures},"  "))
	print("BOSS SKILLS COMPLETE checks=%d failures=%d" % [checked,failures.size()]); quit(0 if failures.is_empty() else 1)
