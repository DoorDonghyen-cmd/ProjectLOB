# 🔧 인수인계 — Phase 12 ③ 탄환 데이터 v5 교체 & 마이그레이션

> **대상**: 이 작업을 이어받는 개발자 / AI 에이전트
> **설계 정본**: [22_ammo_expansion.md](file:///d:/ProjectLoB/docs/gdd/22_ammo_expansion.md) — **먼저 읽을 것**
> **참조 데이터**: `docs/handoff/reference/ammo_v5.csv`, `conversion_kits.csv`
> **선행 완료**: ① 시뮬 하니스 버프 지원(`a869426`) · ② `BUFF_ACC`/`BUFF_PEN` 구현(`fc5ce64`)

---

## 0. 이 작업이 위험한 이유

탄환 21종 → 27종 교체인데, **삭제되는 12종 중 9종을 코드가 하드코딩 참조**한다.
그리고 **드래프트·도감이 디렉터리를 스캔**하므로 CSV만 고치면 유령 탄이 계속 등장한다.

> ⚠️ **자동 검증이 이걸 실패로 잡아주지 않는다.** `validate_data`의 CSV↔`.tres` 대조는
> `t.warn`(경보)이라 종료 코드에 영향이 없다. **테스트가 초록불이어도 깨져 있을 수 있다.**
> 아래 §5의 수동 확인을 반드시 수행할 것.

---

## 1. 작업 환경

```bash
# 프로젝트 경로 (폴더명이 한글이라 bash cd가 실패할 수 있음 → 절대 경로 사용)
d:\ProjectLoB\새-게임-프로젝트

# 전체 검증 (현재 기준선: 1256 통과 / 0 실패 / 경보 3)
<Godot> --headless --path "d:\ProjectLoB\새-게임-프로젝트" --script res://tests/run_all.gd

# 부팅 확인 (UI 변경 시 필수 — 테스트만으로는 부족)
<Godot> --headless --path "d:\ProjectLoB\새-게임-프로젝트" --quit-after 150

# 새 리소스 추가 후에는 임포트 먼저
<Godot> --headless --path "d:\ProjectLoB\새-게임-프로젝트" --import
```

Godot 실행파일: `C:\Users\mdyt7\OneDrive\Desktop\Godot_v4.7-stable_win64_console.exe`
(`_console` 변형이라야 stdout이 보인다)

---

## 2. 삭제 12종 → 참조 위치 (정확한 좌표)

| 삭제되는 탄 | 참조 위치 | 성격 |
|---|---|---|
| `combo_smg` | `run_manager.gd:168` | SMG 시작 덱 특수A |
| `rhythm_smg` | `run_manager.gd:169` | SMG 시작 덱 특수B |
| `knockback_pistol` | `run_manager.gd:161`<br>`combat_scene.gd:20`<br>`combat_overlay_v2.gd:15`<br>`maintenance_overlay.gd:1343` | 권총 시작 덱 · **전역 프리로드** · 상점 풀 |
| `opening_pistol` | `run_manager.gd:162` | 권총 시작 덱 특수B |
| `heavy_dmr` | `run_manager.gd:182`<br>`combat_scene.gd:36`<br>`combat_overlay_v2.gd:16`<br>`maintenance_overlay.gd:1341` | DMR 시작 덱 · **전역 프리로드** · 상점 풀 |
| `last_rifle` | `run_manager.gd:176` | 소총 시작 덱 특수B |
| `shred_shotgun` | `run_manager.gd:189` | 샷건 시작 덱 특수A |
| `heavy_shotgun` | `run_manager.gd:190` | 샷건 시작 덱 특수B |
| `last_smg` · `shred_ap_rifle` · `critical_dmr` · `universal_caliber` | 코드 참조 없음 | `.tres`만 삭제/개명 |

> `universal_caliber` → `crosscal_universal` **개명**이다(삭제 아님).

### 디렉터리를 통째로 스캔하는 곳 (개별 참조 없음, 그래서 더 위험)

| 파일 | 용도 |
|---|---|
| `reward_draft_panel.gd:115` | **드래프트 보상 풀** — 여기 남은 유령 탄이 플레이어에게 그대로 노출된다 |
| `bullet_gallery_overlay.gd` | 탄환 도감 |

---

## 3. 새 시작 덱 구성 (설계 §22.8 확정)

`run_manager.gd`의 `start_new_run()` 안 `match cls:` 블록을 아래로 교체한다.
**새 코어 루프(셋업→페이로드)를 첫 턴부터 가르치는 것**이 목적이다.

| 클래스 | `basic_path` | `specA_path` (셋업) | `specB_path` (페이로드) |
|---|---|---|---|
| PISTOL | `basic_pistol` | `flare_pistol` | `overpressure_pistol` |
| SMG | `basic_smg` | `tuner_smg` | `surge_smg` |
| RIFLE | `basic_rifle` | `shred_rifle` | `heavyslug_rifle` |
| DMR | `basic_dmr` | `marker_dmr` | `burst_dmr` |
| SHOTGUN | `basic_shotgun` | `spread_shotgun` | `dense_shotgun` |

수량(`basic_cnt` / `specA_cnt` / `specB_cnt`)은 **현행 유지**. 승천 `deck_delta`가 여기에 걸려 있으니 건드리지 말 것.

### 전역 프리로드 대체

`combat_scene.gd` · `combat_overlay_v2.gd`의 두 변수는 데모·폴백용이다.

```gdscript
var _bullets_kb    → impact_pistol.tres      # knockback_pistol의 v5 대응물
var _bullets_heavy → burst_dmr.tres          # heavy_dmr 자리
```

### 상점 풀 (`maintenance_overlay.gd:1339~1344`)

4종 중 2종이 삭제된다. 셋업/페이로드가 상점에 뜨도록 재구성할 것:

```gdscript
"res://resources/bullets/shred_rifle.tres",      # 유지 (셋업)
"res://resources/bullets/slow_pistol.tres",      # 유지 (유틸)
"res://resources/bullets/marker_dmr.tres",       # 신규 (셋업)
"res://resources/bullets/burst_dmr.tres"         # 신규 (페이로드)
```

---

## 4. ⚠️ 밸런스 밴드를 넓혀야 한다

v5 **페이로드는 의도적으로 극단 스탯**이다. 현행 검증 밴드를 그대로 두면 경보가 쏟아진다.

| 탄 | DMG | ACC | 현행 밴드 위반 |
|---|---|---|---|
| `overpressure_pistol` | 6 | 2 | DMG(1~5) 초과 · ACC(4~8) 미달 |
| `surge_smg` | 6 | 3 | 〃 |
| `burst_dmr` | **9** | 3 | 〃 |
| `heavyslug_rifle` | 7 | 5 | DMG 초과 |
| `dense_shotgun` | 7 | 4 | DMG 초과 |

**고칠 곳 2군데:**

1. `tests/validate_data.gd:99~101` — DMG 밴드 `1~5` → **`1~9`**, ACC 밴드 `4~8` → **`2~8`**
2. `.agents/skills/10-balance-designer/SKILL.md` §2-② — 같은 밴드 표기 갱신

> ⚠️ **밴드를 넓히는 것이 아니라 없애면 안 된다.** 밴드는 "인지 부담 상한"이라
> 아무 숫자나 허용하면 존재 이유가 사라진다. 페이로드가 들어올 만큼만 넓히고,
> **왜 넓혔는지 주석으로 남길 것**(극단 스탯이 설계 의도라는 사실).

---

## 5. 작업 순서

```
1. resources/bullets/ 에 신규 .tres 12종 생성
   → 기존 .tres를 템플릿으로 (예: shred_rifle.tres 열어 구조 확인)
   → weapon_class / effect_type / effect_value 정확히
   → BUFF_ACC = 7, BUFF_PEN = 8 (Enums.BulletEffect)

2. universal_caliber.tres → crosscal_universal.tres 개명
   (파일명이 곧 id다. DataLoader가 basename으로 CSV와 매칭한다)

3. 삭제 대상 11종 .tres 제거

4. data/bullet_stats.csv를 ammo_v5.csv 내용으로 교체
   ⚠️ v5는 role / is_basic 칼럼이 추가돼 있다.
      DataLoader는 **헤더 이름 기반 파싱**이라 칼럼 삽입은 안전하지만,
      새 칼럼을 실제로 쓰려면 _load_bullet_stats에 추가해야 한다.
      (role은 지금 당장 로직에 안 쓰이면 CSV에만 두고 로드 생략 가능 —
       쓰지 않을 값을 미리 로드하지 말 것)

5. §2 표의 코드 참조 9곳 수정

6. §4 밸런스 밴드 확장

7. --import → 전체 테스트 → 부팅 확인
```

---

## 6. 검증 — 자동 테스트만 믿지 말 것

### 자동으로 잡히는 것
```bash
<Godot> --headless --path "..." --script res://tests/run_all.gd
```
- `suite_script_parse` — 스크립트 컴파일 실패 (경로 오타 등)
- `suite_ui_smoke` — 씬 인스턴스화 + 오버레이 런타임 오류
- `suite_bullet_effects` — 버프 체인 동작 (이미 작성돼 있음)

### ⚠️ 자동으로 안 잡히는 것 — 반드시 수동 확인

| 확인 | 방법 | 왜 필요한가 |
|---|---|---|
| **유령 탄** | `ls resources/bullets/` 와 `awk -F, 'NR>1{print $1}' data/bullet_stats.csv` 비교 | 드래프트는 디렉터리를 스캔한다. CSV에 없는 `.tres`가 남으면 **CSV 동기화 안 된 탄이 보상으로 등장** |
| **시작 덱** | 개발자 테스트 → 요원 준비실 → 각 클래스 선택 후 전투 진입 | 경로 오타는 파싱 오류가 아니라 **`load()` null**이라 조용히 덱이 비어 버린다 |
| **드래프트 풀** | 전투 승리 후 드래프트 화면 | 삭제된 탄이 뜨는지 |
| **상점** | 지도에서 상점 노드 진입 | 하드코딩 4종 |

### 회귀 테스트 추가 권장

이번 작업의 실패 모드(유령 탄)를 **테스트로 고정**해두면 이후 재발이 막힌다:

```gdscript
# tests/suite_ammo_integrity.gd (신규)
# - resources/bullets/*.tres 집합 == bullet_stats.csv id 집합  (t.check, warn 아님)
# - start_new_run이 참조하는 모든 경로가 실제로 load 가능한가
# - 각 클래스 시작 덱에 setter와 payload가 최소 1종씩 들어 있는가
```

> 이 프로젝트는 **"구현했는데 연결이 빠진"** 결함이 반복해서 나왔다
> (파츠 미전달 · 보스 페이즈 미호출 · 시그니처 문자열 불일치 · 스폰 구간 도달 불가).
> 그래서 **"만들었다"가 아니라 "실제로 도달하는가"를 검증하는 습관**이 이 코드베이스의 규칙이다.

---

## 7. 이 코드베이스에서 지켜야 할 규칙

작업 전에 알아두면 함정을 피할 수 있다.

| 규칙 | 이유 |
|---|---|
| **CSV는 헤더 이름으로 읽는다** | 인덱스 파싱은 칼럼 삽입 시 뒤가 밀리는데, 실패하지 않고 **엉뚱한 값을 조용히 읽는다**. `DataLoader._s/_i/_b` 헬퍼 사용 |
| **총기 판정은 리소스 ID로** (`gun_is`) | 표시명 문자열 매칭은 이름이 바뀌면 조용히 어긋난다. 실제로 시그니처가 죽은 적 있다 |
| **UI에 데이터를 복사하지 않는다** | `suite_ui_data_drift`가 하드코딩을 잡는다. 정본에서 읽을 것 |
| **`t.check(true, ...)` 금지** | GDScript 오류는 실행을 멈추지 않으므로 "안 죽었다"만 확인하는 단언은 무조건 통과한다. **실제 값을 검사할 것** |
| **결정론 유지** | 확률 판정을 도입하지 말 것. 전투는 `ACC ≥ EVA` / `PEN ≥ DEF` 정수 임계값이다 |
| **적 DEF/EVA를 난이도 손잡이로 쓰지 않는다** | 이진 게이트라 절벽이 된다(특정 빌드만 죽음) |
| **커밋 메시지에 "왜"를 쓴다** | 무엇을 바꿨는지는 diff가 말한다. 왜 그렇게 했는지, 어떤 대안을 왜 버렸는지를 남길 것 |

---

## 8. 완료 조건

- [ ] `.tres` 27종 == `bullet_stats.csv` 27행 (집합 일치)
- [ ] 5개 클래스 시작 덱이 셋업+페이로드 포함해 정상 생성
- [ ] 코드 참조 9곳 전부 갱신 (§2)
- [ ] 밸런스 밴드 확장 + 근거 주석 (§4)
- [ ] 전체 테스트 통과 (기준선 1256 이상, 실패 0)
- [ ] 부팅 정상 (종료 코드 0)
- [ ] 드래프트·상점에 유령 탄 없음 (수동 확인)
- [ ] `docs/gdd/22_ammo_expansion.md` §22.10 구현 순서에 ③ 완료 표기
- [ ] `.agents/skills/00-project-manager/task_tracker.md` Phase 12 항목 갱신

---

## 9. 다음 단계 (이 작업 이후)

| 단계 | 내용 | 주의 |
|---|---|---|
| ④ | 기관단총 연발 전환 | 리로드 2→3 **필수**(안 하면 턴당 4.00으로 밴드 초과) · 예고창 2→6 · 더블탭 제거. **도박형은 단발 유지** |
| ⑤ | 컨버전 킷 | 소멸 면제 확장 · 드래프트 가중 · `conversion_cost` 칼럼. 승천 8등급과 상호작용 있음 |
| ⑥ | 매트릭스 수치 조정 | 하니스에 버프 지원이 이미 들어가 있다(`sim_harness.simulate`의 `total_damage`/`buffed_shots`) |
