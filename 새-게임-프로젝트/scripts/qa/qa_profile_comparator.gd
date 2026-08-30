class_name QAProfileComparator
extends RefCounted

const ReportScript := preload("res://scripts/qa/qa_experience_report.gd")
const MetricsScript := preload("res://scripts/qa/qa_experience_metrics.gd")


static func compare(reports: Array) -> Dictionary:
	var errors: Array[String] = []
	if reports.size() != ReportScript.PROFILES.size():
		errors.append("비교에는 네 플레이 프로필이 모두 필요함")
	var by_profile: Dictionary = {}
	for i in range(reports.size()):
		var report = reports[i]
		if not report is Dictionary:
			errors.append("reports[%d]가 객체가 아님" % i)
			continue
		for error in ReportScript.validation_errors(report):
			errors.append("%s: %s" % [str(report.get("profile", i)), error])
		var profile := str(report.get("profile", ""))
		if by_profile.has(profile):
			errors.append("중복 플레이 프로필: %s" % profile)
		by_profile[profile] = report
	for profile in ReportScript.PROFILES:
		if not by_profile.has(profile):
			errors.append("누락 플레이 프로필: %s" % profile)

	if errors.is_empty():
		_validate_same_start(by_profile, errors)

	var metrics_by_profile: Dictionary = {}
	var signatures: Dictionary = {}
	if errors.is_empty():
		for profile in ReportScript.PROFILES:
			var report: Dictionary = by_profile[profile]
			metrics_by_profile[profile] = MetricsScript.aggregate(report)
			var signature_key := JSON.stringify(ReportScript.action_signature(report))
			if not signatures.has(signature_key):
				signatures[signature_key] = []
			signatures[signature_key].append(profile)
		if signatures.size() == 1:
			errors.append("프로필 이름만 다른 동일 행동열은 비교 성공으로 인정할 수 없음")

	var result := {
		"schema_version": 1,
		"comparable": errors.is_empty(),
		"errors": errors,
		"metrics_by_profile": metrics_by_profile,
		"duplicate_action_series": _duplicate_series(signatures),
		"selection_comparison": {},
		"dominant_choices": [],
		"conclusions": [],
		"pairwise_choice_overlap": [],
	}
	if not errors.is_empty():
		return result

	var selection_comparison := _selection_comparison(metrics_by_profile)
	result.selection_comparison = selection_comparison
	result.dominant_choices = _dominant_choices(selection_comparison)
	result.conclusions = _conclusions(by_profile, metrics_by_profile)
	result.pairwise_choice_overlap = _pairwise_overlap(metrics_by_profile)
	return result


static func save(comparison: Dictionary, path: String) -> Error:
	var directory := path.get_base_dir()
	var error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if error != OK and error != ERR_ALREADY_EXISTS:
		return error
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(comparison, "\t") + "\n")
	return OK


static func _validate_same_start(by_profile: Dictionary, errors: Array[String]) -> void:
	var baseline: Dictionary = by_profile[ReportScript.PROFILES[0]]
	var baseline_start := JSON.stringify(baseline.start_condition)
	for profile in ReportScript.PROFILES.slice(1):
		var report: Dictionary = by_profile[profile]
		for field in ["commit", "scenario_id", "gameplay_seed"]:
			if report.get(field) != baseline.get(field):
				errors.append("시작 조건 %s 불일치: %s" % [field, profile])
		if JSON.stringify(report.start_condition) != baseline_start:
			errors.append("시작 로드아웃·세이브 조건 불일치: %s" % profile)


static func _duplicate_series(signatures: Dictionary) -> Array[Dictionary]:
	var duplicates: Array[Dictionary] = []
	for signature in signatures:
		var profiles: Array = signatures[signature]
		if profiles.size() > 1:
			duplicates.append({"profiles": profiles.duplicate(), "action_count": JSON.parse_string(signature).size()})
	return duplicates


static func _selection_comparison(metrics_by_profile: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for profile in metrics_by_profile:
		var by_category: Dictionary = metrics_by_profile[profile].selection.by_category
		for category in by_category:
			if not result.has(category):
				result[category] = {"total": 0, "choices": {}, "profiles": {}}
			result[category].profiles[profile] = by_category[category].duplicate(true)
			for choice_id in by_category[category]:
				var count := int(by_category[category][choice_id])
				result[category].total = int(result[category].total) + count
				result[category].choices[choice_id] = \
					int(result[category].choices.get(choice_id, 0)) + count
	return result


static func _dominant_choices(selection_comparison: Dictionary) -> Array[Dictionary]:
	var dominant: Array[Dictionary] = []
	for category in selection_comparison:
		# 기본탄은 매 장전 슬롯마다 반복되므로 선택지 지배율로 해석하지 않는다.
		# 탄환의 전략적 가치는 core fun 순서 대조와 전술탄 사용 맥락에서 별도 판정한다.
		if str(category) == "ammo":
			continue
		var entry: Dictionary = selection_comparison[category]
		if entry.choices.size() < 2 or int(entry.total) < 4:
			continue
		var ordered: Array = entry.choices.keys()
		ordered.sort_custom(func(a, b): return int(entry.choices[a]) > int(entry.choices[b]))
		var top_id := str(ordered[0])
		var top_count := int(entry.choices[top_id])
		var share := float(top_count) / float(entry.total)
		if share < 0.6:
			continue
		var alternatives: Array[Dictionary] = []
		for alternative_id in ordered.slice(1):
			alternatives.append({
				"choice_id": str(alternative_id),
				"selected": int(entry.choices[alternative_id]),
				"lead": top_count - int(entry.choices[alternative_id]),
			})
		dominant.append({
			"category": category,
			"choice_id": top_id,
			"selected": top_count,
			"decisions": int(entry.total),
			"share": share,
			"alternatives": alternatives,
			"classification": "strong_signal" if _profile_support(entry.profiles, top_id) >= 3 else "hypothesis",
		})
	return dominant


static func _conclusions(by_profile: Dictionary, metrics_by_profile: Dictionary) -> Array[Dictionary]:
	var grouped: Dictionary = {}
	for profile in ReportScript.PROFILES:
		for judgment in metrics_by_profile[profile].judgments:
			_add_signal(grouped, str(judgment.signal_key), str(judgment.axis), profile,
				judgment.evidence, "observation")
		for observation in by_profile[profile].observations:
			_add_signal(grouped, str(observation.signal_key), str(observation.axis), profile,
				{"steps": observation.evidence_steps, "observation": observation.observation},
				str(observation.confidence))

	var conclusions: Array[Dictionary] = []
	for signal_key in grouped:
		var entry: Dictionary = grouped[signal_key]
		var classification := "hypothesis"
		if bool(entry.human_confirmation):
			classification = "human_confirmation"
		elif entry.profiles.size() >= 3:
			classification = "strong_signal"
		conclusions.append({
			"signal_key": signal_key,
			"axis": entry.axis,
			"classification": classification,
			"profiles": entry.profiles.keys(),
			"evidence": entry.evidence,
		})
	return conclusions


static func _add_signal(
	grouped: Dictionary,
	signal_key: String,
	axis: String,
	profile: String,
	evidence: Dictionary,
	confidence: String
) -> void:
	if not grouped.has(signal_key):
		grouped[signal_key] = {
			"axis": axis,
			"profiles": {},
			"evidence": [],
			"human_confirmation": false,
		}
	grouped[signal_key].profiles[profile] = true
	grouped[signal_key].evidence.append({"profile": profile, "details": evidence.duplicate(true)})
	if confidence == "human_confirmation":
		grouped[signal_key].human_confirmation = true


static func _pairwise_overlap(metrics_by_profile: Dictionary) -> Array[Dictionary]:
	var pairs: Array[Dictionary] = []
	for i in range(ReportScript.PROFILES.size()):
		for j in range(i + 1, ReportScript.PROFILES.size()):
			var first: String = ReportScript.PROFILES[i]
			var second: String = ReportScript.PROFILES[j]
			var first_set: Dictionary = metrics_by_profile[first].selection.counts
			var second_set: Dictionary = metrics_by_profile[second].selection.counts
			var union: Dictionary = first_set.duplicate()
			for choice_id in second_set:
				union[choice_id] = true
			var intersection := 0
			for choice_id in first_set:
				if second_set.has(choice_id):
					intersection += 1
			pairs.append({
				"profiles": [first, second],
				"shared_choices": intersection,
				"combined_unique_choices": union.size(),
				"overlap": float(intersection) / float(union.size()) if not union.is_empty() else 0.0,
			})
	return pairs


static func _profile_support(profile_counts: Dictionary, choice_id: String) -> int:
	var support := 0
	for profile in profile_counts:
		if int(profile_counts[profile].get(choice_id, 0)) > 0:
			support += 1
	return support
