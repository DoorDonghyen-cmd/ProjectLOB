extends RefCounted
## Magazine LIFO 스택 검증 — 마지막 장전탄이 먼저 발사, 용량/약실/언로드 규칙.
## 정본: scripts/core/magazine.gd


static func _gun(cap: int, chamber: bool) -> GunData:
	var g := GunData.new()
	g.magazine_capacity = cap
	g.has_chamber = chamber
	return g


static func _bullet(name: String) -> BulletData:
	var b := BulletData.new()
	b.display_name = name
	return b


static func run(t) -> void:
	t.section("Magazine(LIFO)")

	var a := _bullet("A")
	var b := _bullet("B")
	var c := _bullet("C")

	# ── LIFO: 마지막 장전탄(C)이 먼저 발사 ──
	var mag := Magazine.new(_gun(5, false))
	var arr: Array[BulletData] = [a, b, c]
	mag.load_bullets(arr)
	t.eq(mag.get_remaining(), 3, "장전 3발")
	t.eq(mag.fire(), c, "첫 발사 = C(마지막 장전)")
	t.eq(mag.fire(), b, "둘째 발사 = B")
	t.eq(mag.fire(), a, "셋째 발사 = A(첫 장전)")
	t.eq(mag.fire(), null, "빈 탄창 발사 = null")

	# ── 용량 초과분 절삭 ──
	var mag2 := Magazine.new(_gun(2, false))
	var arr2: Array[BulletData] = [a, b, c]
	mag2.load_bullets(arr2)
	t.eq(mag2.get_remaining(), 2, "용량 2 → 초과분 절삭")

	# ── 약실(+1) 지원 ──
	var mag3 := Magazine.new(_gun(2, true))
	var arr3: Array[BulletData] = [a, b, c]
	mag3.load_bullets(arr3)
	t.eq(mag3.get_remaining(), 3, "약실 포함 최대 3발")

	# ── unload = 스택 맨 위 제거 ──
	var mag4 := Magazine.new(_gun(5, false))
	var arr4: Array[BulletData] = [a, b, c]
	mag4.load_bullets(arr4)
	t.eq(mag4.unload(), c, "unload → 맨 위 C 제거")
	t.eq(mag4.peek(), b, "peek → 다음 발사탄 B")
	t.eq(mag4.get_remaining(), 2, "unload 후 잔탄 2")

	# ── insert = 전투 중 탑 장전 ──
	var mag5 := Magazine.new(_gun(3, false))
	var arr5: Array[BulletData] = [a]
	mag5.load_bullets(arr5)
	mag5.insert_bullet(b)
	t.eq(mag5.peek(), b, "insert 후 다음 발사탄 = 새로 얹은 B")
