# 🧪 tests — 헤드리스 자동 검증

Godot 4.7 프로젝트의 결정론적 로직을 **씬 없이 헤드리스로** 자동 검증한다.
수동 `walkthrough.md` 플레이테스트를 코드 회귀 테스트로 대체/보완한다.

## 실행

```powershell
# Windows
.\tests\run.ps1
# 또는 Godot 경로 직접 지정
.\tests\run.ps1 -Godot "C:\Program Files\Godot\Godot_v4.7-stable_win64.exe"
```

```bash
# Linux / macOS / CI
GODOT=/path/to/godot ./tests/run.sh
```

수동 실행:

```
<Godot실행파일> --headless --path <새-게임-프로젝트경로> --script res://tests/run_all.gd
```

종료 코드 **0 = 전체 통과**, **1 = 실패** (CI에서 레드/그린 판정 가능).

## 구성

| 파일 | 역할 |
|------|------|
| `run_all.gd` | 오케스트레이터(SceneTree). 모든 검증을 순차 실행하고 종료 코드 반환 |
| `lob_test.gd` | 미니 assert/집계 하니스 (`check`/`eq`/`warn`/`summary`) |
| `suite_damage.gd` | 전투 수식 — 이진 관통 게이트, 명중 `ACC≥EVA` 임계값 |
| `suite_magazine.gd` | 탄창 LIFO — 발사 순서, 용량/약실, unload/insert |
| `suite_enemy.gd` | 적 태세 전환(N발 주기), 전진/둔화/넉백 거리 계산 |
| `validate_data.gd` | CSV 정합성 — id 유니크·컬럼·정수·밴드(ERROR/WARN), `.tres` 매칭 |
| `sim_harness.gd` | 결정론 전투 시뮬레이터 — 승패·마진·넉백락 산출(밸런스 회귀+튜닝) |

- **ERROR**(FAIL, 종료 1): 구조적 오류(관통 게이트 위반, 중복 id, 컬럼 부족 등).
- **WARN**(경보만): 밸런스 밴드 이탈, `.tres` 파일명 불일치 등. 종료 코드에 영향 없음.

## 새 테스트 추가

1. `suite_*.gd`에 `static func run(t) -> void:` 작성, `t.eq(...)` / `t.check(...)` 사용.
2. `run_all.gd`에 `preload` + `Suite.run(t)` 한 줄 추가.

## 참고

- 시각/UX 검증(레이아웃·연출)은 자동화 대상이 아니다 → 인게임 `🛠️ 개발자 테스트` 메뉴 활용.
- 순수 static 클래스(`DamageCalculator`/`DataLoader`)와 `RefCounted` 로직(`Magazine`/`EnemyInstance`)만 대상. UI/씬 의존 코드는 제외.
- 밸런스 밴드 정본은 `.agents/skills/10-balance-designer/SKILL.md`, 전투 공식 정본은 `docs/gdd/03_combat_system.md §3.2`.
