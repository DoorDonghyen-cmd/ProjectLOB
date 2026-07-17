extends RefCounted
## 미니 테스트 하니스 — 외부 애드온 없이 assert / 집계 / 요약을 제공한다.
## 각 스위트는 이 인스턴스(t)를 받아 t.check / t.eq / t.warn 을 호출한다.
##   - check/eq 실패 → FAIL(종료 코드 1)
##   - warn 실패    → WARN(경보만, 종료 코드 영향 없음)

var passed: int = 0
var failed: int = 0
var warned: int = 0
var failures: Array[String] = []
var _section: String = "-"


func section(name: String) -> void:
	_section = name
	print("\n── [%s] ──" % name)


func check(cond: bool, msg: String) -> void:
	if cond:
		passed += 1
		print("  ✓ %s" % msg)
	else:
		failed += 1
		failures.append("[%s] %s" % [_section, msg])
		printerr("  ✗ FAIL [%s] %s" % [_section, msg])


func eq(actual: Variant, expected: Variant, msg: String) -> void:
	check(actual == expected, "%s (기대=%s, 실제=%s)" % [msg, str(expected), str(actual)])


## 실패해도 종료 코드에 영향을 주지 않는 경보(밸런스 밴드 이탈 등).
func warn(ok: bool, msg: String) -> void:
	if ok:
		passed += 1
	else:
		warned += 1
		print("  ⚠ WARN [%s] %s" % [_section, msg])


## 요약 출력 후 종료 코드(0=성공, 1=실패)를 반환한다.
func summary() -> int:
	print("\n════════ 테스트 요약 ════════")
	print("통과: %d | 실패: %d | 경보: %d" % [passed, failed, warned])
	if failed > 0:
		print("실패 목록:")
		for f in failures:
			print("  - " + f)
	print("결과: %s" % ("✅ PASS" if failed == 0 else "❌ FAIL"))
	return 0 if failed == 0 else 1
