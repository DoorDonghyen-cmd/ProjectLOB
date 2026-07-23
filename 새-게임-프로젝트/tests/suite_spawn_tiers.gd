extends RefCounted
## 스폰 구간 도달성 — 각 계층에서 선언된 3구간이 모두 실제로 등장하는가.
##
## 배경(2026-07-24 발견): 스폰 분기가 `floor_num <= 8` 같은 구 층수(10~15층) 기준
##   절대 임계값을 쓰고 있었다. 층수 압축(6/7/7/7/8) 이후 마지막 구간이 전 계층에서
##   도달 불가가 되어, 설계상 그 계층의 정체성이던 적들이 일반전에 한 번도 나오지 않았다.
##     · 공역  — 술사(Caster)
##     · 정비 계층 — 스펀지(Absorber)  ← 주석에는 "스펀지 유입"이라 적혀 있었다
##     · 관리/정점 — 신경술사(NeuroCaster)
##   전투가 정상 동작했기 때문에 기존 스위트는 전부 통과했다.
##
## "선언됐는데 도달할 수 없는 콘텐츠"는 조용히 죽는다. 구간 계산을 직접 검증한다.


static func run(t) -> void:
	t.section("SpawnTiers")

	for sec in RunManager.SECTION_ORDER:
		var sec_key: String = str(sec)
		var info: Dictionary = MapGenerator.section_info(sec_key)
		var floors: int = int(info.floors)

		# ── 3구간이 모두 등장하는가 ──
		var seen := {}
		var track: Array[String] = []
		for f in range(1, floors + 1):
			var tier: int = MapGenerator.floor_tier(sec_key, f)
			seen[tier] = true
			track.append("%d" % tier)

		t.check(seen.size() == 3,
			"%s(%d층): 3구간 전부 도달 가능 — 층별 구간 %s" % [str(info.name), floors, "".join(track)])

		# ── 구간은 0/1/2 범위를 벗어나지 않는다 ──
		for f in range(1, floors + 1):
			var tier2: int = MapGenerator.floor_tier(sec_key, f)
			t.check(tier2 >= 0 and tier2 <= 2, "%s %d층 구간 범위(%d)" % [sec_key, f, tier2])

		# ── 구간은 층이 오를수록 뒤로만 간다(되돌아가지 않는다) ──
		var prev := -1
		var monotonic := true
		for f in range(1, floors + 1):
			var tier3: int = MapGenerator.floor_tier(sec_key, f)
			if tier3 < prev:
				monotonic = false
			prev = tier3
		t.check(monotonic, "%s: 구간이 층 진행에 따라 단조 증가" % str(info.name))

		# ── 첫 층은 초반, 마지막 층(보스층)은 종반이어야 한다 ──
		t.eq(MapGenerator.floor_tier(sec_key, 1), 0, "%s 1층 = 초반 구간" % str(info.name))
		t.eq(MapGenerator.floor_tier(sec_key, floors), 2, "%s 최종층 = 종반 구간" % str(info.name))
