extends RefCounted

const RandomStreamsScript := preload("res://scripts/core/random_streams.gd")
const ManifestScript := preload("res://scripts/qa/qa_session_manifest.gd")
const JournalScript := preload("res://scripts/qa/qa_run_journal.gd")

const JOURNAL_OUTPUT := "user://__qa_rng_journal"


static func run(t) -> void:
	t.section("QA RNG replay")
	var seed := 424242
	var first := _gameplay_signature(seed, 0)
	var second := _gameplay_signature(seed, 50)
	t.eq(first, second, "동일 seed의 게임플레이 결과는 FX 난수 50회와 무관")
	var different := _gameplay_signature(seed + 1, 0)
	t.check(first != different, "다른 gameplay seed는 핵심 결과를 변경")

	RandomStreamsScript.begin_run(seed, 11)
	var reward_before := RandomStreamsScript.gameplay_int(1, 100000, "reward")
	RandomStreamsScript.begin_run(seed, 12)
	for i in range(100):
		RandomStreamsScript.gameplay_float("map")
	var reward_after_map_noise := RandomStreamsScript.gameplay_int(1, 100000, "reward")
	t.eq(reward_before, reward_after_map_noise, "map 추첨 횟수가 reward 스트림을 오염시키지 않음")

	RandomStreamsScript.begin_run(seed, 13)
	RandomStreamsScript.gameplay_int(1, 999, "shop")
	var saved_rng := RandomStreamsScript.snapshot()
	var expected_next := RandomStreamsScript.gameplay_int(1, 999, "shop")
	t.eq(RandomStreamsScript.restore(saved_rng), OK, "RNG 상태 복원")
	t.eq(RandomStreamsScript.gameplay_int(1, 999, "shop"), expected_next,
		"복원 후 다음 상점 추첨이 동일")

	var manifest := ManifestScript.create(
		"qa-rng-session", "qa-commit", "focused", "campaign_two_sections", true, seed)
	t.check(ManifestScript.is_valid(manifest), "schema v2 manifest의 gameplay seed 계약")
	t.eq(int(manifest.gameplay_seed), seed, "manifest에 gameplay seed 기록")

	_cleanup_journal()
	RandomStreamsScript.begin_run(seed, 14)
	var journal = JournalScript.new()
	t.eq(journal.configure(manifest, JOURNAL_OUTPUT), OK, "강제 종료 복구용 진행 저널 구성")
	t.eq(journal.record({"action": "choose_route", "node_id": 101}, {
		"section": "section_a", "floor": 1, "node_id": 101}), OK,
		"행동 직후 진행 저널 원자 기록")
	var restored: Dictionary = journal.latest()
	t.eq(int(restored.step), 1, "마지막 완료 행동 단계 보존")
	t.eq(int(restored.progress.node_id), 101, "마지막 완료 노드 보존")
	t.eq(int(restored.rng.gameplay_seed), seed, "복구 저널에 RNG 상태 보존")
	_cleanup_journal()


static func _gameplay_signature(seed: int, fx_draws: int) -> Array:
	RandomStreamsScript.begin_run(seed, seed + 9000)
	for i in range(fx_draws):
		RandomStreamsScript.fx_float()
	var result: Array = []
	var map_data: Dictionary = MapGenerator.generate("section_a")
	for node_id in [202, 401]:
		var node: RunManager.RunNode = map_data.map_nodes[node_id]
		result.append([node_id, node.hidden_type, node.connected_routes])
	for tier in range(3):
		result.append(EnemyRoster.regular_encounter_ids("section_a", tier))
	for i in range(4):
		result.append(RandomStreamsScript.gameplay_int(1, 1000000, "reward"))
	for i in range(4):
		result.append(RandomStreamsScript.gameplay_int(1, 1000000, "shop"))
	return result


static func _cleanup_journal() -> void:
	var file_path := ProjectSettings.globalize_path("%s/progress.json" % JOURNAL_OUTPUT)
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
	var directory := ProjectSettings.globalize_path(JOURNAL_OUTPUT)
	if DirAccess.dir_exists_absolute(directory):
		DirAccess.remove_absolute(directory)
