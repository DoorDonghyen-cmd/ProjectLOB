---
name: 04-daily-logs
description: ProjectLoB 일일 작업 내역 요약 및 히스토리 트래킹용 스킬. 대화 및 작업 종료 시 오늘 진행한 작업, 작성한 코드, 해결한 이슈, 다음 할 일 등을 일자별로 정리하여 기록합니다.
---

## 2026-07-18 (Sat) #4 - 연결 끊김 버그 4건 추가 수정 · 파츠 콘텐츠 완성 · 세계관 전면 개정

### 🎯 목표
- 플레이 체감 확인 후, 실제 플레이에 영향을 주는 결함을 계속 색출·수정한다.
- 게임의 세계관 및 컨셉이 메카닉과 정합한지 재검토하고 재정립한다.

### 🛠️ 개발 내역
**1. 연결 끊김 계열 버그 4건 추가 수정 (전날 파츠 버그와 동일 유형)**
- **최종 보스 2페이즈 미작동**: `check_phase_transition()`이 어디서도 호출되지 않아 배리어 소진 시 즉사, 기획된 2페이즈 결전이 도달 불가였음. `_apply_damage_to_enemy` 배리어 차감 직후 연동(모든 대미지 경로가 이 헬퍼를 거쳐 단일 지점 수정으로 전 경로 커버).
- **총기 시그니처 2종 미발동**: 시그니처를 `display_name` 문자열("저격"/"돌격")로 판정했으나 실제 표시명이 "정밀 지정사수소총"·"브리칭 샷건"이라 매칭 실패 → DMR·샷건 고유 능력이 전혀 발동하지 않았음. `_gun_is(리소스 ID)` 판정으로 교체(표시명은 문구 변경·현지화에 취약).
- **콤보탄 판정 오류**: `last_shot_hit`를 현재 격발 결과로 덮어쓴 뒤 콤보 조건에서 읽어 "직전 명중" 조건이 항상 참 → 첫 발부터 보너스. `prev_shot_hit` 보존으로 수정.
- **무기 해금 미저장**: 디브리핑이 `end_run()`(내부 save) → `check_weapon_unlocks()` 순서라 해금이 저장 이후에 일어나 재시작 시 유실. `check_weapon_unlocks`가 자체 저장하도록 변경.
- **샷건 자기모순 해소**: 초근접 DMG+4를 받는데 자체 패시브 넉백이 적을 구간 밖으로 밀어내던 문제 → 거리 ≤2에서 패시브 넉백 제외(13 → 21 대미지).
- **nano_stalker EVA9 이슈 해소**: 원인이 수치가 아니라 DMR 저격 시그니처가 죽어 카운터가 없던 것. 시그니처 복구로 명중·처치 확인, EVA 9는 설계대로 유지.

**2. 파츠 콘텐츠 완성**
- 전투 로직만 있고 리소스가 없어 획득 불가였던 **파츠 13종 제작**(8종 → 21종). 무기고 상점 풀 등록 + 밀수 상점은 디렉터리 스캔으로 자동 편입.
- 설명문을 실제 전투 효과(가산량·발동 조건)에 맞춰 작성하고, **6종의 효과를 with/without 대조로 실증 검증**.

**3. 세계관 전면 개정 (핵심 작업)**
- 진단: 메카닉↔픽션 접합은 좋으나 표면이 관습적이고, **인간형 일색이라 실루엣으로 자물쇠 판독이 불가한 가독성 결함** 발견. "전술 호러" 지향이 결정론과 정면 충돌한다는 점도 확인.
- 아이데이션 후 확정: **기계화(사이보그화)=계급인 거대 수직 도시. 개조받지 못한 최하층민이 생존을 위해 오른다.**
  - 지배가 아니라 **경제적 계층화** — 위층은 미워하지 않고 무관심하다
  - **LIFO 정당화**: 인간용 구형 화기의 경직된 실행 큐 (기존 최대 약점 해소)
  - **결정론 정당화**: 계산하는 건 총이다. 인간이라 스스로 못 하기 때문 — 강해서가 아니라 **약해서** 도구에 의존
  - **결말**: 정점에서 개조 거부. 물리적 탈출은 그리지 않음
  - **무드**: 비장한 절차 + 고독 (호러 폐기)
- **서사 3층 통제**: 전제(필수)/시각 암시(필수)/로어 파편(선택). 컷씬 없는 게임의 실제 대역폭에 맞춤
- **실루엣 규칙 신설**: 기계화율에 따라 인간 실루엣이 붕괴하며 아키타입별 방향이 다름 → 자물쇠를 형태만으로 판독
- **계층 5개 + 노드 테마 설계** 후 **전 구역 노드명 교체**, **절대 고도 표기(LV) 도입**(도시 3000층 규모 전달)

**4. 회귀 안전망 확대**
- 638 → **917 체크**. 전 5구역 맵 생성 강제 구동(명칭 테이블 키 누락 검출), 파츠 적용, 총기 시그니처, 탄환 특수효과, 무기 해금 영속화 검증 추가.

### 📁 수정된 주요 파일
- [combat_manager.gd](file:///d:/ProjectLoB/%EC%83%88-%EA%B2%8C%EC%9E%84-%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8/scripts/core/combat_manager.gd) · [run_manager.gd](file:///d:/ProjectLoB/%EC%83%88-%EA%B2%8C%EC%9E%84-%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8/scripts/core/run_manager.gd) · [map_generator.gd](file:///d:/ProjectLoB/%EC%83%88-%EA%B2%8C%EC%9E%84-%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8/scripts/core/map_generator.gd)
- resources/parts/ (13종 신규) · tests/ (스위트 4종 신규)
- docs/gdd/ 01·04·08·12 (세계관·실루엣·노드 테마·계층 팔레트)

### 💡 다음 예정 작업
- **Phase 9 세계관 적용**: 적 스프라이트 실루엣 재작업(주 제작비) · 계층별 배경 아트 · 몬스터 계층 배치 · 로어 파편 20개 · 제목 재명명
- 정비소 노드 3종(M3), STANCE 파츠 2종 로직 구현

---

## 2026-07-18 (Sat) #3 - 리팩토링(죽은 코드 제거·맵 생성 분리) 및 파츠 미적용 버그 수정

### 🎯 목표
- 본격 제작 전환 판단의 일환으로 리팩토링 필요성을 진단하고, 저위험·고효용 항목만 정리한다.
- 파츠 시스템이 실제로 무기에 적용되는지 점검하고 결함을 수정한다.

### 🛠️ 개발 내역
**1. 리팩토링 진단 및 실행 (저위험 2건)**
- 규모 진단: combat_overlay.gd(2167줄)가 `is_v2_ui` 상시 true로 **도달 불가한 죽은 코드**임을 확인.
- v1 죽은 오버레이 제거: combat_overlay.gd/tscn(v1) + dump_ui.gd/dump_tool.tscn(v1 전용 덤프툴) 6파일 삭제(~3080줄 순감).
- 맵 생성 분리: `generate_run_map` 본문 + `_finalize_route_graph`를 `map_generator.gd`(MapGenerator)로 추출, RunManager는 위임 래퍼로 축소(927→659줄). SRP 개선.
- 리팩토링 중 유입된 타입 코어싱 버그(connected_routes)를 테스트 안전망(suite_full_run)이 즉시 포착 → 명시적 Array[String] 할당으로 수정.
- (섹션별 층수 확인: section_a=10 / b·c=12 / 그 외=15층. "15층" 문서 표기의 실체.)

**2. 파츠 미적용 버그 수정 (🔴 실게임 영향)**
- 원인: combat_overlay_v2가 `start_encounter`에 4번째 인자 `parts`를 누락 → `equipped_parts`가 항상 [] → 장착 파츠(~21종 효과)·총기 고유 내장 파츠가 실게임에서 전혀 발동하지 않음.
- 수정: `run_manager.equipped_parts`를 전달하도록 1곳 수정.
- suite_parts 회귀 테스트 추가: HIGH_PRECISION(ACC+2) 장착 시 ACC6<EVA7 빗나감이 명중으로 뒤집혀 HP 20→5 발생함을 검증.

### 📁 수정된 주요 파일
- [map_generator.gd](file:///d:/ProjectLoB/%EC%83%88-%EA%B2%8C%EC%9E%84-%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8/scripts/core/map_generator.gd) (신설), [run_manager.gd](file:///d:/ProjectLoB/%EC%83%88-%EA%B2%8C%EC%9E%84-%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8/scripts/core/run_manager.gd), [combat_scene.gd](file:///d:/ProjectLoB/%EC%83%88-%EA%B2%8C%EC%9E%84-%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8/scripts/ui/combat_scene.gd)
- [combat_overlay_v2.gd](file:///d:/ProjectLoB/%EC%83%88-%EA%B2%8C%EC%9E%84-%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8/scripts/ui/overlays/combat_overlay_v2.gd) (파츠 전달 수정)
- tests/ (suite_parts 추가, 총 642 체크)
- 삭제: combat_overlay.gd/tscn, dump_ui.gd, dump_tool.tscn

### 💡 다음 예정 작업
- 풀 런 플레이테스트(재미 관문) — 파츠 체감 포함.
- 미해결: 최종보스 페이즈2, 맵 10 vs 15 확정, nano_stalker EVA9, 파츠 ~13종 .tres 미생성(획득 불가).

---

## 2026-07-18 (Sat) #2 - 스킬 지침 정합 · 자동 검증/CI 구축 · 메타 세이브로드 · 프리프로덕션 하드닝

### 🎯 목표
- 프로젝트 스킬 지침의 모순을 정본에 정합시키고, 완료 기능/테스트를 자동 검증하는 파이프라인을 구축한다.
- 메타 진행 영속성(세이브/로드) 공백을 메우고, 프로토타입→프로덕션 전환 판단을 위한 하드닝을 수행한다.

### 🛠️ 개발 내역
**1. 스킬 지침 모순 4건 정합**
- balance-designer·combat-simulator: 대미지 공식을 이진 관통 게이트로, 명중을 `ACC≥EVA` 정수 임계값으로 통일(확률 % 제거), 수치를 실제 CSV 밴드로 교체. damage_calculator.gd 스테일 주석 정정.
- art-resource-manager: 화풍을 미니멀 16-bit 플랫으로 단일화(§1↔§2 모순 해소), 몬스터를 "감염된 보안/연구 인력"으로 명기, 탄환 아이콘 아웃라인 예외 명문화.
- work.md·AGENTS.md: 세션 종료 절차를 Phase 4로 통합(문서→커밋→푸시 승인 게이트).
- work.md·07-notion-sync: 스킬 07~14 워크플로우 연결, 노션 도구명 현행화(post-page→notion-create-pages).

**2. 헤드리스 자동 검증 스타터 + CI 구축**
- `tests/` 신설: 전투 수식(이진 관통 게이트·ACC≥EVA)·탄창 LIFO·적 태세/거리·CSV 정합·결정론 전투 시뮬 스위트 + 미니 assert 하니스 + 로컬 러너(run.ps1).
- `.github/workflows/tests.yml`: push/PR 시 Godot 4.7 헤드리스로 자동 실행(초록 확인).

**3. 플레이 흐름 통합 + 메타 세이브/로드**
- suite_run_flow: 무기→맵→노드→실제 CombatManager 전투→클리어→정산 완주 검증.
- RunManager.save_meta/load_meta(user://meta_save.cfg, ConfigFile) 신설. 저장: end_run·upgrade_meta_*, 로드: combat_scene._ready. save_path_override로 테스트 격리. suite_save_load 추가.

**4. 프리프로덕션 하드닝 (풀 런 스캔 + 보스 기믹 커버리지 + 적 데이터 일원화)**
- suite_full_run: 맵 BFS 도달성(랜덤 5회, 데드엔드 0) + 전투 크래시 스캔(일반6+보스4, 크래시/행 0).
- suite_boss_gimmicks: 앱소버 배리어·캐스터 차징·삼단 태세·최종보스 페이즈 전환(함수 단위) 검증.
- sentry_drone·nano_stalker·neuro_caster 3종을 enemy_stats.csv로 편입(동작 무변화).
- **자동 발견 이슈**: ① 최종보스 페이즈2 미작동(check_phase_transition 미호출) ② 맵 실측 10층 vs 문서 15층 드리프트 ③ nano_stalker EVA9 > ACC상한8 명중 불가. → task_tracker 등록.
- 최종 검증: 638개 체크 그린(경보 3), 로컬·CI exit 0.

### 📁 수정된 주요 파일
- [.agents/skills/ (10·12·08·07·00·work.md·AGENTS.md)](file:///d:/ProjectLoB/.agents/) — 스킬 지침 정합
- [새-게임-프로젝트/tests/](file:///d:/ProjectLoB/%EC%83%88-%EA%B2%8C%EC%9E%84-%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8/tests/) — 자동 검증 스위트 8종 + 러너
- [.github/workflows/tests.yml](file:///d:/ProjectLoB/.github/workflows/tests.yml) — CI
- [run_manager.gd](file:///d:/ProjectLoB/%EC%83%88-%EA%B2%8C%EC%9E%84-%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8/scripts/core/run_manager.gd) — 세이브/로드 API + 훅
- [combat_scene.gd](file:///d:/ProjectLoB/%EC%83%88-%EA%B2%8C%EC%9E%84-%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8/scripts/ui/combat_scene.gd) — 부팅 시 load_meta
- [enemy_stats.csv](file:///d:/ProjectLoB/%EC%83%88-%EA%B2%8C%EC%9E%84-%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8/data/enemy_stats.csv) — 적 3종 편입

### 💡 다음 예정 작업
- **풀 런 플레이테스트**로 "재미 관문" 확인(프로덕션 전환 판단).
- 등록된 이슈 정리: 🔴 최종보스 페이즈2, 🟡 맵 10 vs 15층 확정, 🟡 nano_stalker EVA9 밸런스.

---

## 2026-07-18 (Sat) - 통로 분기 목적지 가격 구조 구현

### 🎯 목표
- 통로를 별도 선택지가 아닌 목적지의 가격으로 재정의하고 비상계단·환기구 2종만 유지합니다.
- 환기구의 다음 전투 시작 거리 `-2m` 비용, 무기고 통로 가변 배치, 한 번의 목적지 선택을 런타임과 UI에 연동합니다.

### 🛠️ 개발 내역
**1. 런 그래프와 환기 압박 상태**
- `RunManager`에 현재 노드와 미소비 거리 보정 상태를 추가하고 실제 연결 노드 판정을 구현했습니다.
- 환기구 비용을 비전투 노드에서도 유지하고 다음 전투 시작 시 한 번 소비하도록 했으며, 연속 이용 시 중첩하지 않게 했습니다.
- 런 시작 시 무기고별 통로를 가변 배치하고 계단/환기구 최소 1개씩을 보장했습니다.

**2. 목적지 1회 선택 UI**
- 맵의 별도 통로 선택 팝업을 제거하고 노드 클릭 한 번으로 목적지와 연결 통로가 함께 확정되도록 변경했습니다.
- 현재 노드에서 실제로 연결된 목적지만 활성화하고 노드 카드·연결선에 통로 비용을 사전 공개했습니다.
- 구형/V2 전투 오버레이 모두 환기 압박을 적 시작 거리에 반영합니다.

**3. 기획 및 목업 동기화**
- GDD v0.18과 통로 의도 보충 문서를 추가하고 로드맵, 메타 진행, 침투 맵 UI 문서를 갱신했습니다.
- 층 스킵·확률 패널티 통로를 제거하고, TDC를 보스·히든·우회·보급 목적지 클리어 보상으로 이전했습니다.
- Creative Director와 Balance Designer 지침에 목적지 가격 및 `-2m` 검증 원칙을 반영했습니다.

### ✅ 검증
- 런타임 경로 값이 `stairs`, `air_duct` 두 종류뿐임을 확인했습니다.
- 구형 통로 선택 UI와 제거 대상 통로 문자열이 현행 런타임·GDD·목업에 남지 않았습니다.
- 침투 맵 HTML 목업 JavaScript 구문 검사를 통과했습니다.
- Godot 실행 파일 부재로 엔진 헤드리스 파싱 및 실제 씬 실행은 미수행입니다.

### 📁 주요 산출물
- [implementation_plan](file:///D:/ProjectLoB/docs/implementation_plan_route_branching_2026-07-18.md)
- [walkthrough](file:///D:/ProjectLoB/docs/walkthrough_route_branching_2026-07-18.md)
- [통로 분기 의도 보충](file:///D:/ProjectLoB/docs/gdd/19_route_branching_intention.md)

### 💡 다음 예정 작업
- Godot 편집기에서 환기구 → 무기고 → 전투 이월, 비중첩, 무기고 통로 최소 배치 규칙을 수동 스모크 테스트합니다.

---

## 2026-07-17 (Fri) - 렐릭 시스템 전면 제거

### 🎯 목표
- 문자열 ID와 UI 상태로 분산돼 있던 렐릭 시스템을 런타임, 맵, 정산, 현행 기획 문서에서 제거합니다.
- 총기 고유 파츠와 기존 맵 연결은 보존하여 제거로 인한 회귀를 최소화합니다.

### 🛠️ 개발 내역
**1. 런타임 상태 및 전투 효과 제거**
- `run_manager.gd`와 `combat_manager.gd`의 `active_relics` 상태 및 렐릭 인자를 삭제했습니다.
- 전술 장갑 재장전 감소, 가스 밸브 넉백 증가, 렐릭 개수 기반 크레딧 정산을 제거했습니다.
- 구형/V2 전투 오버레이의 `start_encounter()` 호출 계약을 함께 갱신했습니다.

**2. 로드아웃·맵·정산 UI 정리**
- `loadout_overlay.gd`의 전술 렐릭 카드, 토글 상태, 탄창/예고창 보정 미리보기를 제거했습니다.
- 가스 밸브 전용 숨김 노드 3곳을 일반 공개 우회로로 전환하여 맵 연결 구조를 유지했습니다.
- 디브리핑의 렐릭 보너스 항목과 구형 전투 UI의 장비 의존 스탯 은폐를 제거했습니다.

**3. 현행 문서 및 프로젝트 지침 동기화**
- GDD, 프로젝트 로드맵, 전술 로드아웃/침투 맵 목업에서 렐릭 설계와 확장 계획을 제거했습니다.
- Creative Director, Balance Designer, Combat Simulator 스킬을 탄환·파츠 중심 지침으로 갱신했습니다.
- 포인트블랭크는 실제 `PartData` 리소스이므로 유지하고 잘못된 렐릭 명칭만 수정했습니다.

### ✅ 검증
- 런타임 및 현행 문서에서 렐릭 키워드와 관련 문자열 ID 잔존 없음.
- `start_encounter()` 선언/호출 인자 정합 확인.
- 전술 로드아웃 HTML JavaScript 구문 검사 통과.
- 작업 대상 파일 `git diff --check` 통과.
- Godot 실행 파일 부재로 엔진 헤드리스 파싱 및 실제 씬 실행은 미수행.

### 📁 주요 산출물
- [implementation_plan](file:///D:/ProjectLoB/docs/implementation_plan_relic_system_removal_2026-07-17.md)
- [walkthrough](file:///D:/ProjectLoB/docs/walkthrough_relic_system_removal_2026-07-17.md)

### 💡 다음 예정 작업
- Godot 편집기에서 로드아웃 진입, 맵 경로 표시, 전투 시작, 디브리핑 정산을 1회 수동 스모크 테스트합니다.

---

## 2026-07-12 (Sun) - 맵 · 레벨 구조 및 경제 개정 기획 인게임 연동 구현

### 🎯 목표
- "10노드가 짧다"는 플레이 성장 피드백을 기반으로 런의 길이와 전투 밀도, 비전투 배치 및 성장 곡선을 재설계합니다.
- GDD `08_meta_progression.md`에 개정 반영된 15층 맵 구조, 보상 드래프트 (Add/Swap/Skip), 스타팅 보증금/금고 크레딧 이월 기능, 그리고 히든 노드 안전 완충망을 실제 인게임 코드와 연동하는 작업을 완성합니다.

### 🛠️ 개발 내역
**1. 15노드 및 3구역(Act) 구조 반영**
- `run_manager.gd`의 `generate_run_map()` 함수를 개편하여 총 15개 층의 가로 분기 구조를 구축했습니다 (Act 1~3 매핑).
- `map_overlay.gd`의 최대 층수 한계를 `15`로 확장하고, 보스 표시 조건을 `15F`로 갱신했습니다.
- `combat_scene.gd`와 `debriefing_overlay.gd`에서 런 완료/종료 한계를 `15F`로 통일했습니다.
**2. 드래프트 보상 (방안 B) 및 덱 교체 (Swap) UI 구현**
- `reward_draft_panel.gd`에서 드래프트 구성을 2개의 무작위 탄환 카드와 1개의 보너스 기업 크레딧 카드로 변경했습니다 (방안 B 복합 매핑 적용).
- 크레딧 카드 획득 시 런 보유 크레딧이 정상 가산되며, 이때는 `[교체]` 버튼이 비활성화되도록 방어했습니다.
- 드래프트가 끝나는 공통 마감 시점(`_finish_draft_flow()`)에 전투 클리어 효율 등급에 따른 **기본 전투 보상 크레딧**이 플레이어의 보유금에 누적 가산되도록 수정했습니다.
- `[교체]` 버튼 조작 시 덱 리스트를 스크롤 뷰로 노출하는 `DeckSwapModal` 플로팅 팝업을 화면 중앙에 정렬되도록 구현했습니다.
**3. 스타팅 보증 및 전술 금고 이월 기능**
- `run_manager.gd`에 `meta_vault_lvl`, `saved_vault_credits`, `starting_bonus_available` 변수를 선언하고 `end_run()`과 `start_new_run()` 시 정산을 처리했습니다.
- `loadout_overlay.gd`에 `StartingBonusPopup`을 추가하여 런 시작 시 보증금이 유효하면 "+50 Cr" 또는 "무작위 1티어 파츠 1개" 선택지를 제공하고 연동을 마쳤습니다.
- `title_overlay.gd`에 영구 업그레이드 상점 항목으로 "전술 금고" 업그레이드 버튼을 추가했습니다.
**4. 히든 노드 위험 완충 안전망**
- `combat_scene.gd`의 `handle_route_selected()`에서 미지 노드가 전투일 때 30% 확률로 **안전 가옥** 또는 **암시장 상인**을 조우하도록 구현했습니다.
- 안전 가옥에서는 HP 버퍼를 회복하고 잃어버린 탄을 복구하며, 암시장에서는 크레딧을 소비해 파츠나 탄환을 밀수할 수 있습니다.

### 📁 수정된 주요 파일
- [run_manager.gd](file:///d:/ProjectLoB/%EC%83%88-%EA%B2%8C%EC%9E%84-%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8/scripts/core/run_manager.gd)
- [map_overlay.gd](file:///d:/ProjectLoB/%EC%83%88-%EA%B2%8C%EC%9E%84-%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8/scripts/ui/overlays/map_overlay.gd)
- [combat_scene.gd](file:///d:/ProjectLoB/%EC%83%88-%EA%B2%8C%EC%9E%84-%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8/scripts/ui/combat_scene.gd)
- [debriefing_overlay.gd](file:///d:/ProjectLoB/%EC%83%88-%EA%B2%8C%EC%9E%84-%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8/scripts/ui/overlays/debriefing_overlay.gd)
- [reward_draft_panel.gd](file:///d:/ProjectLoB/%EC%83%88-%EA%B2%8C%EC%9E%84-%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8/scripts/ui/components/reward_draft_panel.gd)
- [combat_overlay_v2.gd](file:///d:/ProjectLoB/%EC%83%88-%EA%B2%8C%EC%9E%84-%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8/scripts/ui/overlays/combat_overlay_v2.gd)
- [loadout_overlay.gd](file:///d:/ProjectLoB/%EC%83%88-%EA%B2%8C%EC%9E%84-%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8/scripts/ui/overlays/loadout_overlay.gd)
- [title_overlay.gd](file:///d:/ProjectLoB/%EC%83%88-%EA%B2%8C%EC%9E%84-%ED%94%84%EB%A1%9C%EC%A0%9D%ED%8A%B8/scripts/ui/overlays/title_overlay.gd)

### 💡 다음 예정 작업
- 메타 진행 데이터 저장/로드 및 영구 데이터 직렬화 로직 보완.

## 2026-07-11 (Sat) - 기업 크레딧 경제 시스템 및 무기고 보급단말기 상점 연동 구현 완결

### 🎯 목표
- 전투 종료 시 탄 소모율 기반 효율 평가 등급과 연동되는 기업 크레딧 획득 시스템을 구축합니다.
- 무기고 보급단말기 상점을 통해 탄환 및 소모품 구매, 리롤 기믹을 구현하여 '탄환 vs 크레딧'의 경제 선택을 완성합니다.

### 🛠️ 개발 내역
**1. 경제 기획서 및 UI 요청서 수립**
- `docs/gdd/16_economy_and_armory.md` 및 `docs/gdd/17_ui_request_economy_shop.md` 작성 및 HTML 인터랙티브 목업 추가.
**2. 소모품 데이터 구조 신설**
- 소모품 데이터 클래스(`consumable_item.gd`)를 추가하여 의료 킷 등의 인게임 정비 아이템 관리 기틀 마련.
**3. 핵심 비즈니스 로직 및 UI 연동**
- `run_manager.gd`, `combat_manager.gd`, `combat_scene.gd`, `reward_draft_panel.gd` 등에 크레딧 정산, 등급 계산, 무기고 상점 내 구매 및 리롤 동작 구현 완결.

### 📁 수정된 주요 파일
- [16_economy_and_armory.md](file:///d:/ProjectLoB/docs/gdd/16_economy_and_armory.md)
- [17_ui_request_economy_shop.md](file:///d:/ProjectLoB/docs/gdd/17_ui_request_economy_shop.md)
- [reward_draft_panel.gd](file:///d:/ProjectLoB/새-게임-프로젝트/scripts/ui/components/reward_draft_panel.gd)
- [run_manager.gd](file:///d:/ProjectLoB/새-게임-프로젝트/scripts/managers/run_manager.gd)
- [combat_manager.gd](file:///d:/ProjectLoB/새-게임-프로젝트/scripts/managers/combat_manager.gd)


## 2026-07-05 (Sun) - 거리 표시, 분석 패널 워터마크, 상황 라벨 이동 및 장전 탄환 순서/은폐/아이콘 개선

### 🎯 목표
- 전투 오버레이(v2)에서 거리 표시 UI(`_distance_label`)가 전투 영역(수평 트랙)의 정확한 상단 중앙에 고정되도록 구조와 속성을 개선합니다.
- 최상단 좌측(`TopBar`)에 존재하던 상황 로그/경고 라벨(`_top_log_toast`)을 전투 영역(`_track_control`) 내부의 **우측 상단**으로 독립하여 이동시킵니다.
- 좌상단 플로팅 패널인 격발 분석(`_hit_info_panel`)의 가로 너비를 줄여 전투 영역의 공간 가독성을 개선하고, 배경 및 테두리 투명도를 조율하고 마우스 클릭 관통 설정을 적용하여 은은한 **워터마크 스타일**로 재디자인합니다.
- 공중에 떠 있는 느낌이 들던 플레이어 캐릭터, 몬스터 스프라이트 및 트랙 중심선의 세로축 앵커를 추가 하향 배치(`0.75` 지점)하여 레이아웃 안정감을 유도합니다.
- **장전된 탄환 목록을 개별 카드 형태로 세로 나열**하되, LIFO(스택) 원리에 따라 가장 마지막에 장전된(가장 먼저 격발될) 탄환이 최상단에 배치되도록 역순 정렬하고 **상위 2개 탄환을 제외한 나머지 깊이의 탄환은 정보를 은폐(???)** 처리하며, **동적 카드 내부에 고유 총알 이미지(아이콘)를 표시**하여 시인성을 높입니다.

### 🛠️ 개발 내역
**1. 상황 로그 라벨(TopLogToast) 우상단 배치 및 VBox 제거**
- `_top_log_toast`를 세로정렬 컨테이너에서 제거하고 최상위 전투 영역 컨트롤러(`_track_control`)의 직접 자식으로 탑재했습니다.
- 프리셋을 `PRESET_TOP_RIGHT`로 설정하고 마진(`offset_right = -12`, `offset_top = 12`) 및 가로 우측 정렬(`HORIZONTAL_ALIGNMENT_RIGHT`)을 주어 우상단에 정확히 오버레이 고정되도록 개선했습니다.
- 세로정렬용 `DistanceVBox`를 제거하고, `_distance_container` (CenterContainer) 하위에 `_distance_label`이 직접 자식으로 탑재되어 거리 정렬의 균형을 극대화했습니다.

**2. 장전 탄환 카드 내 총알 이미지(아이콘) 렌더링**
- `_create_dynamic_bullet_card` 함수에서 카드가 은폐 상태가 아닐 때(`is_hidden = false`)에 한하여 `_get_bullet_icon(bullet)` 함수로 텍스트 아이콘을 로드했습니다.
- 로드된 텍스트 아이콘을 카드 크기에 맞는 `18x18px` 규격의 `TextureRect`로 변환해 HBox 안의 인덱스 라벨과 탄환 이름 라벨 사이에 정렬 삽입했습니다.

**3. 격발 분석 패널(HitAnalysis) 워터마크화**
- `_hit_info_panel` 스타일박스의 `bg_color` 알파값을 `0.8 ➡️ 0.25`로 변경해 뒷배경이 비치게 했고, 테두리 색상(`border_color`)은 아웃라인 강조를 대폭 죽인 `Color(parent_scene.C_ACCENT, 0.2)`로 약화시켰습니다.
- `mouse_filter = Control.MOUSE_FILTER_IGNORE` 설정을 부여하여 뒤에 가려진 공간 마우스 클릭을 통과시키는 완벽한 워터마크 연출을 구현했습니다.

**4. 장전 탄환 목록 LIFO 역순 동적 정렬 및 3순위 은폐 적용**
- `combat_overlay_v2.gd` 내부의 `_build_ui()` 에서 기존 3개 정적 카드 배치 코드를 제거하고, 다량의 카드 나열에 대응할 수 있도록 `ScrollContainer`로 감싼 동적 `Lookahead` VBox 영역을 마련했습니다.
- `_update_cylinder_visuals()` 함수에서 자식 카드를 모두 클리어한 후, 장전된 모든 탄환에 대해 뒤에서부터 역순으로 루프(`for i in range(bullets.size() - 1, -1, -1)`)를 돌며 개별 `PanelContainer` 카드를 동적으로 렌더링하도록 변경했습니다.
- 이를 통해 가장 최근에 장전한(가장 먼저 격발될) 탄환이 리스트의 맨 위(1순위)에 오고 깊이 묻힌 탄환들이 하단에 정렬되는 스택 시각화 정합성을 맞추었습니다.
- 노출 순서 카운터 `display_count >= 2`인 경우(3번째 격발 예정 탄환부터) 은폐 플래그 `is_hidden = true`를 전달하여 탄환 명칭을 `"???"`로, 성능 수치를 `"D? P?"`로 은폐하도록 구현했습니다.

**5. 격발 분석 패널 가로 너비 축소**
- `_hit_info_panel` 의 `custom_minimum_size`를 가로 `210`에서 `180`으로 축소하여 콤팩트한 레이아웃을 구현했습니다.

**6. 트랙 라인 및 캐릭터/적 하향 배치 고도화**
- `combat_overlay_v2.gd` 에서 트랙 가로 중심선(`_track_line`), 플레이어 캐릭터(`_agent_sprite`), 몬스터 스프라이트(`es`)의 세로축 앵커(`anchor_top`, `anchor_bottom`)를 기존 `0.5 ➡️ 0.65 ➡️ 0.75`로 최종 하향 조정했습니다.
- 이를 통해 전투 트랙 영역 하단(세로 75% 지점)에 모든 주요 오브젝트가 정렬되어 배치되도록 디자인 구조를 고도화했습니다.마크 연출을 구현했습니다.

**3. 장전 탄환 목록 LIFO 역순 동적 정렬 및 3순위 은폐 적용**
- `combat_overlay_v2.gd` 내부의 `_build_ui()` 에서 기존 3개 정적 카드 배치 코드를 제거하고, 다량의 카드 나열에 대응할 수 있도록 `ScrollContainer`로 감싼 동적 `Lookahead` VBox 영역을 마련했습니다.
- `_update_cylinder_visuals()` 함수에서 자식 카드를 모두 클리어한 후, 장전된 모든 탄환에 대해 뒤에서부터 역순으로 루프(`for i in range(bullets.size() - 1, -1, -1)`)를 돌며 개별 `PanelContainer` 카드를 동적으로 렌더링하도록 변경했습니다.
- 이를 통해 가장 최근에 장전한(가장 먼저 격발될) 탄환이 리스트의 맨 위(1순위)에 오고 깊이 묻힌 탄환들이 하단에 정렬되는 스택 시각화 정합성을 맞추었습니다.
- 노출 순서 카운터 `display_count >= 2`인 경우(3번째 격발 예정 탄환부터) 은폐 플래그 `is_hidden = true`를 전달하여 탄환 명칭을 `"???"`로, 성능 수치를 `"D? P?"`로 은폐하도록 구현했습니다.

**4. _distance_label 및 상황 로그 라벨 통합 배치**
- `combat_overlay_v2.gd` 에서 `_top_log_toast` 가 `TopBar` 의 자식으로 들어가는 구조를 변경했습니다.
- `_distance_container` (CenterContainer) 하위에 세로 정렬용 `distance_vbox` (VBoxContainer)를 신설하고, `_distance_label`과 `_top_log_toast`를 순서대로 추가했습니다.
- 두 라벨 모두 `horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER`를 적용하고 아웃라인 설정을 보강하여, 거리 표시 바로 아래에서 깔끔하게 가로 중앙 정렬을 유지하도록 개선했습니다.
- `TopBar` 에는 `_top_log_toast` 가 빠지고 빈 스페이스가 배치되어 우측 페이즈 라벨만 남도록 정리했습니다.

**5. 격발 분석 패널 가로 너비 축소**
- `_hit_info_panel` 의 `custom_minimum_size`를 가로 `210`에서 `180`으로 축소하여 콤팩트한 레이아웃을 구현했습니다.

**6. 트랙 라인 및 캐릭터/적 하향 배치 고도화**
- `combat_overlay_v2.gd` 에서 트랙 가로 중심선(`_track_line`), 플레이어 캐릭터(`_agent_sprite`), 몬스터 스프라이트(`es`)의 세로축 앵커(`anchor_top`, `anchor_bottom`)를 기존 `0.5 ➡️ 0.65 ➡️ 0.75`로 최종 하향 조정했습니다.
- 이를 통해 전투 트랙 영역 하단(세로 75% 지점)에 모든 주요 오브젝트가 정렬되어 배치되도록 디자인 구조를 고도화했습니다.

### 📁 수정된 주요 파일
- [MODIFY] [combat_overlay_v2.gd](file:///c:/Users/도얼동현/.gemini/antigravity-ide/scratch/ProjectLOB/새-게임-프로젝트/scripts/ui/overlays/combat_overlay_v2.gd)
- [MODIFY] [.agents/skills/06-history-archive/implementation_plan_master.md](file:///c:/Users/도얼동현/.gemini/antigravity-ide/scratch/ProjectLOB/.agents/skills/06-history-archive/implementation_plan_master.md)
- [MODIFY] [.agents/skills/06-history-archive/walkthrough_master.md](file:///c:/Users/도얼동현/.gemini/antigravity-ide/scratch/ProjectLOB/.agents/skills/06-history-archive/walkthrough_master.md)

### 💡 다음 예정 작업
- UI 가시성 및 기획 밸런스에 기반한 전투 메커니즘 확장 구현.

---

## 2026-06-28 (Sun) - combat_scene.gd 거대 UI 리팩토링 및 AD 픽셀 아트 가이드 개정

### 🎯 목표
- 1,420라인 규모의 거대 UI 결합 소스 파일인 `combat_scene.gd`를 씬 라우터 및 5대 독립 오버레이 컴포넌트로 분할 리팩토링.
- 리소스 제작 및 관리 매니저 스킬을 도트풍(픽셀 아트) AD 가이드로 갱신하고, 게임에 필요한 모든 리소스 마스터 목록 정리.

### 🛠️ 개발 내역
**1. combat_scene.gd 거대 UI 소스 코드 리팩토링 및 5대 오버레이 분리**
- `title_overlay.gd` (타이틀 & 메타 상점), `map_overlay.gd` (단면도 맵), `maintenance_overlay.gd` (정비 노드 액션), `combat_overlay.gd` (전투 루프 & LIFO 장탄), `debriefing_overlay.gd` (런 정산 디브리핑)의 5대 독립 서브 스크립트 추출 및 UI 이식 완료.
- `combat_scene.gd`를 서브 오버레이들을 인스턴스화하고 상태에 따라 토글/데이터 주입을 조율하는 슬림한 씬 라우터로 전면 리팩토링 완료 (1,420라인 ➡️ 296라인).
- 전투 진입 시 통로 선택 로그가 덮어씌워져 유실되던 잠재적 버그를 해결하기 위해 `clear_combat_log` / `add_combat_log` 헬퍼 메서드 추가 및 라우터-오버레이 간 호출 설계 보완.

**2. AD 리소스 스킬 도트풍(픽셀 아트) 개정 및 필요 리소스 마스터 리스트 신설**
- `08-art-resource-manager/SKILL.md`를 32비트 스케일 도트 엣지 렌더링, 서브 픽셀 네온 발광, AI 생성용 픽셀 전용 프롬프트 공식, Godot Nearest 필터링 및 Mipmaps 억제 강제화 지침을 담은 AD 가이드라인으로 개정.
- `required_assets_list.md` 아티팩트를 신설하여 총기, 탄환 15종, 적 5종, 렐릭, UI 맵 데칼 및 오버레이 배경의 규격(해상도) 및 상세 AD 도트 묘사를 테이블화하여 정리 완료.

### 📁 수정된 주요 파일
- [NEW] [title_overlay.gd](file:///d:/ProjectLoB/새-게임-프로젝트/scripts/ui/overlays/title_overlay.gd)
- [NEW] [map_overlay.gd](file:///d:/ProjectLoB/새-게임-프로젝트/scripts/ui/overlays/map_overlay.gd)
- [NEW] [maintenance_overlay.gd](file:///d:/ProjectLoB/새-게임-프로젝트/scripts/ui/overlays/maintenance_overlay.gd)
- [NEW] [combat_overlay.gd](file:///d:/ProjectLoB/새-게임-프로젝트/scripts/ui/overlays/combat_overlay.gd)
- [NEW] [debriefing_overlay.gd](file:///d:/ProjectLoB/새-게임-프로젝트/scripts/ui/overlays/debriefing_overlay.gd)
- [MODIFY] [combat_scene.gd](file:///d:/ProjectLoB/새-게임-프로젝트/scripts/ui/combat_scene.gd)
- [MODIFY] [08-art-resource-manager/SKILL.md](file:///d:/ProjectLoB/.agents/skills/08-art-resource-manager/SKILL.md)
- [NEW] [required_assets_list.md](file:///C:/Users/mdyt7/.gemini/antigravity-ide/brain/bbacb3ae-bec7-4690-b500-e3c4ec102daf/required_assets_list.md)

### 💡 다음 예정 작업
- 특수 전술 탄환 10종 중 5종 신규 특수 효과 구현 (`Opening Shot`, `Last Shot` 등) 및 전투 대미지 계산기(`damage_calculator.gd`) 반영.

---

## 2026-06-27 (Sat) - 에이전트 매니지먼트 환경 구축

### 🎯 목표
- D:\ProjectLoB 프로젝트용 에이전트 매니지먼트 지침 및 템플릿 패키지 이식.

### 🛠️ 개발 내역
**1. 에이전트 매니지먼트 환경 구축**
- 작업 표준 워크플로우(`workflows/work.md`) 생성.
- `00-project-manager`, `04-daily-logs`, `05-bug-report`, `06-history-archive`, `07-notion-sync` 등 매니지먼트 핵심 스킬 이식 및 템플릿화 완료.

### 📁 수정된 주요 파일
- [NEW] `.agents/workflows/work.md`
- [NEW] `.agents/skills/00-project-manager/SKILL.md`
- [NEW] `.agents/skills/00-project-manager/task_tracker.md`
- [NEW] `.agents/skills/04-daily-logs/SKILL.md`
- [NEW] `.agents/skills/05-bug-report/...`
- [NEW] `.agents/skills/06-history-archive/...`
- [NEW] `.agents/skills/07-notion-sync/...`

### 💡 다음 예정 작업
- 프로젝트 초기 개발 태스크 목록 작성 및 첫 기능 개발 시작.

---

## 2026-06-27 (Sat) #2 - 현대 전술 CQB 테마 및 빌딩 단면도 맵 기획 반영 (GDD v0.4)

### 🎯 목표
- 게임의 세계관 및 현대 전술 CQB 테마 구체화 사항을 GDD에 추가.
- "Last on Board" 게임의 로그라이크 런 구조(빌딩 단면도 맵) 기획을 수립하여 GDD에 반영.

### 🛠️ 개발 내역
**1. 현대 전술 CQB 테마 구체화**
- 세계관 배경 및 주인공, 제목 "Last on Board"의 다각적 재해석 내용 추가.
- 거리 트랙의 전술적 의미("복도와 코너 대치", 거리 0 = 즉사/제압)와 넉백/둔화의 CQB 테마 치환 내용 정립.
- 총알 장전 행위를 "전술 사격 계획(CQB Loadout)"으로 직관적 재정의.
- 탄환(카드) 종류(JHP, FMJ, 슬러그/고무탄, EMP 탄)의 특징 매핑 및 기존 샘플 데이터의 한글 묘사 갱신.
- 재장전의 긴박함(엄폐물 없는 Tactical Reload) 정의 보완.

**2. 로그라이크 런 구조 추가**
- 슬더스식 지도 대신 "봉쇄된 빌딩의 층별 단면도"를 맵으로 사용하는 기획 수립.
- 맵 노드 유형(사무실/서버실, 무기 캐비닛, 치료 키트/엄폐 구역, 보안 통제실, 옥상)의 전술적 보상과 기능 정의.

### 📁 수정된 주요 파일
- [MODIFY] [game_design_document.md](file:///d:/ProjectLoB/docs/game_design_document.md)
- [MODIFY] [task_tracker.md](file:///d:/ProjectLoB/.agents/skills/00-project-manager/task_tracker.md)

### 💡 다음 예정 작업
- GDD 확장: UI/UX 설계 (장전 UI 및 거리 트랙 시각화 구상)

---

## 2026-06-27 (Sat) #3 - GDD 기획 문서 분할 및 토큰 최적화

### 🎯 목표
- 방대해진 GDD 문서를 주제별 세부 문서로 분할하여 가독성과 토큰 효율성을 확보.
- 기존 문서를 마스터 인덱스 문서로 재구성.

### 🛠️ 개발 내역
**1. GDD 기획서 주제별 분할**
- `01_game_overview.md`, `02_core_mechanics.md`, `03_combat_system.md`, `04_enemy_design.md`, `05_design_tensions.md`, `06_open_decisions.md`, `07_technical_architecture.md`, `08_meta_progression.md`로 총 8개의 개별 기획 파일 생성 및 본문 이식 완료.
- 각 파일별로 상위 마스터 문서 및 상대 경로 링크 구성.

**2. 마스터 인덱스 구축**
- 기존 `game_design_document.md`를 세부 문서 바로가기 링크 및 핵심 요약 위주의 마스터 인덱스로 개편.

### 📁 수정된 주요 파일
- [MODIFY] [game_design_document.md](file:///d:/ProjectLoB/docs/game_design_document.md)
- [NEW] [01_game_overview.md](file:///d:/ProjectLoB/docs/gdd/01_game_overview.md)
- [NEW] [02_core_mechanics.md](file:///d:/ProjectLoB/docs/gdd/02_core_mechanics.md)
- [NEW] [03_combat_system.md](file:///d:/ProjectLoB/docs/gdd/03_combat_system.md)
- [NEW] [04_enemy_design.md](file:///d:/ProjectLoB/docs/gdd/04_enemy_design.md)
- [NEW] [05_design_tensions.md](file:///d:/ProjectLoB/docs/gdd/05_design_tensions.md)
- [NEW] [06_open_decisions.md](file:///d:/ProjectLoB/docs/gdd/06_open_decisions.md)
- [NEW] [07_technical_architecture.md](file:///d:/ProjectLoB/docs/gdd/07_technical_architecture.md)
- [NEW] [08_meta_progression.md](file:///d:/ProjectLoB/docs/gdd/08_meta_progression.md)

### 💡 다음 예정 작업
- GDD 확장: UI/UX 설계 (장전 UI 및 거리 트랙 시각화 구상)

---

## 2026-06-27 (Sat) #4 - GDD UI/UX 설계 추가

### 🎯 목표
- 전술 사격 계획(장전 UI), 1차원 전술 복도 트랙(거리 트랙 UI), 격발 및 연출 연쇄(전투 FX), 실시간 정보 전투 HUD 가시성 기획안 수립 및 GDD 반영.

### 🛠️ 개발 내역
**1. 전술 장전 화면 (CQB Loadout UI) 설계**
- FIFO(큐) 방식과 LIFO(스택) 방식 총기 구조에 따른 장전 UI 차이 및 카드 드래그 앤 드롭을 통한 장전 상호작용 설계.

**2. 전술 복도 트랙 UI (Corridor Track UI) 설계**
- 0~10 격자 트랙, 요원과 적의 마커 배치, 적의 SPD 이동 예정 표시, 거리 0(즉사) 임박 시 위기 연출 및 스탯 오버레이 묘사.

**3. 전투 연출 및 격발 템포 (Combat FX & Tempo UX) 설계**
- 활성화 -> 총구 반동 -> 궤적 투사 -> 명중(피격)/빗나감 -> 거리 변동(넉백/둔화) -> 적 전진으로 이어지는 격발 연출 연쇄(6단계) 정립.
- 모바일을 위한 자동 사격 토글 및 배속(1x, 2x, 4x) 제어 설계.

**4. 전투 정보 가시성 (Combat HUD) 설계**
- 상단 체력(HP), 하단 실시간 탄창 잔탄 상태(`[NEXT]`), 상세 적 정보 패널 정보 가독성 보완.

### 📁 수정된 주요 파일
- [MODIFY] [game_design_document.md](file:///d:/ProjectLoB/docs/game_design_document.md)
- [NEW] [09_ui_ux_design.md](file:///d:/ProjectLoB/docs/gdd/09_ui_ux_design.md)
- [MODIFY] [task_tracker.md](file:///d:/ProjectLoB/.agents/skills/00-project-manager/task_tracker.md)

### 💡 다음 예정 작업
- 프로토타입 핵심 로직 및 Godot 4.x 소스 코드 구현 개시 (DamageCalculator, Magazine 등 GDScript 제작)

---

## 2026-06-27 (Sat) #5 - LIFO 단일화 및 Unload 결합 비용 기획 반영 (GDD v0.6)

### 🎯 목표
- 완전 예측 가능한 결정론적 사격 계산 하에서 발생할 수 있는 "방정식 풀이기(Solver)" 꼼수 문제를 타파하기 위해, LIFO(스택) 구조로 탄창을 단일화하고 빼내기(Unload) 조작에 기회비용(소실 + 적 전진)을 부과하여 GDD 전반에 반영.

### 🛠️ 개발 내역
**1. LIFO 스택 구조 단일화**
- `02_core_mechanics.md` 및 `07_technical_architecture.md` 등에서 FIFO 관련 분기 코드를 모두 삭제하고, 스택 구조 단일화로 역순 장전 시퀀스 조립을 퍼즐 코어 메커니즘으로 확정.

**2. 빼내기(Unload)의 결합 비용(A+B) 적용**
- **비용 A**: 빼낸 탄환 카드가 이번 전투 내 임시 버린 탄고(Discard Pile)로 이동하여 유실됨.
- **비용 B**: 격발 루프 도중 탄을 빼내는 순간 적이 요원의 틈을 타 1칸(Distance) 즉시 전진함.
- 두 징벌적 비용의 상호 결합을 통해 무한한 카드 재배치 꼼수를 막고 묵직한 마찰력을 생성.

**3. 전투 중 적 상태 변환 규칙 수립**
- 전투 도중 적이 일정 격발/시간 주기마다 태세(예: 물리 장갑 태세 ↔ 회피 돌격 태세)를 교대하도록 기획.
- 이에 맞춰 플레이어가 강제적으로 이미 로드된 스택 탄환을 재정정(Unload)하게 만드는 실시간 변동 리액션 생성.

### 📁 수정된 주요 파일
- [MODIFY] [game_design_document.md](file:///d:/ProjectLoB/docs/game_design_document.md)
- [MODIFY] [02_core_mechanics.md](file:///d:/ProjectLoB/docs/gdd/02_core_mechanics.md)
- [MODIFY] [03_combat_system.md](file:///d:/ProjectLoB/docs/gdd/03_combat_system.md)
- [MODIFY] [04_enemy_design.md](file:///d:/ProjectLoB/docs/gdd/04_enemy_design.md)
- [MODIFY] [06_open_decisions.md](file:///d:/ProjectLoB/docs/gdd/06_open_decisions.md)
- [MODIFY] [07_technical_architecture.md](file:///d:/ProjectLoB/docs/gdd/07_technical_architecture.md)
- [MODIFY] [task_tracker.md](file:///d:/ProjectLoB/.agents/skills/00-project-manager/task_tracker.md)

### 💡 다음 예정 작업
- 프로토타입 핵심 로직 및 Godot 4.x 소스 코드 구현 개시 (DamageCalculator, Magazine 등 GDScript 제작)

---

## 2026-06-27 (Sat) #6 - GDD 전체 플레이 루프 설계 추가

### 🎯 목표
- 메인 메뉴부터 침투, 정비, 브리칭, 복도 교전, 그리고 보상 및 메타 성장에 이르는 "Last on Board"의 전체적인 게임 흐름과 Core Loop를 확립하고 GDD에 이식.

### 🛠️ 개발 내역
**1. 3단계 게임 루프 (3-Tier Core Loops) 정의**
- **메타 루프**: 작전 침투 및 전사/성공 정산 ➡️ 메타 업그레이드 순환.
- **런 루프**: 빌딩 내부 단면도 노드 전진 ➡️ 정비 및 브리칭 ➡️ 전투 노드 순환.
- **전투 루프**: 브리칭 장전 ➡️ 사격/Unload ➡️ 승리 보상 카드 드래프트 순환.

**2. 상세 페이즈 흐름 (7 Phase Flow) 구체화**
- 메인 화면 요원 관리, 빌딩 침투 개시(단면도 경로 선택), 전술 정비(안전 구역 및 무기 캐비닛), 도어 브리칭(스택 장전), 복도 교전(Unload 비용 공방), 노드 소탕 및 드래프트, 작전 디브리핑(헬기 탑승/사망에 따른 데이터 칩 회수)의 UX 단계와 디제틱 전술 의미 정의.

### 📁 수정된 주요 파일
- [MODIFY] [game_design_document.md](file:///d:/ProjectLoB/docs/game_design_document.md)
- [MODIFY] [01_game_overview.md](file:///d:/ProjectLoB/docs/gdd/01_game_overview.md)
- [MODIFY] [task_tracker.md](file:///d:/ProjectLoB/.agents/skills/00-project-manager/task_tracker.md)

### 💡 다음 예정 작업
- 프로토타입 플레이테스트 검증 및 디버깅

---

## 2026-06-27 (Sat) #7 - 최소 프로토타입 핵심 로직 GDScript 구현 및 UI 연동

### 🎯 목표
- LIFO 단일화, Unload 결합 비용 적용, 적 실시간 태세 전환 기획 메카닉을 Godot 4.x 소스 코드에 이식하고 프로토타입 UI에 직접 연동 및 검증.

### 🛠️ 개발 내역
**1. LIFO 스택 및 Unload 조작 구현**
- `enums.gd`에서 `MagazineStructure` 제거 및 `EnemyStance` 추가.
- `gun_data.gd`에서 `magazine_structure` 제거 및 `has_chamber` 필드 추가.
- `magazine.gd`를 LIFO 단일 구조(`pop_back` / `back`)로 리팩토링하고, 탄창 맨 위 1발을 제거하는 `unload() -> BulletData` 메서드 구현.
- `combat_manager.gd`에 `request_unload()` 함수를 설계하여 탄 유실 연동 및 Unload 징벌 패널티(적이 둔화 상태에 무관하게 즉시 1칸 강제 전진) 구현.

**2. 적 실시간 태세 전환 구현**
- `enemy_instance.gd`에 `current_stance` 및 `shot_counter` 변수 추가.
- 피격/빗나감에 상관없이 3회 격발 누적 시 태세를 교대하고 가변 스탯(DEF, PRES, EVA, SPD)을 재조정하는 `apply_shot_and_check_shift()` 및 `_shift_stance()` 함수 연동.
- `combat_manager.gd` 격발 루프(`fire()`) 끝부분에 격발 정산 직후 태세 전환을 판단하도록 훅 연동 및 `enemy_stance_changed` 시그널 방출 구현.

**3. 프로토타입 UI 연동**
- `combat_scene.gd`에 `_unload_btn`을 동적으로 추가하여 가로 횡형 3버튼(발사, 빼내기, 리로드) 구조로 재설계.
- UI 레벨에서 빼내기 클릭 시 `request_unload()` 호출 및 시그널 바인딩.
- 적 태세 전환 시그널 발생 시 HUD에 `[철갑 방패]` 또는 `[회피 기동]` 등의 상태 정보 텍스트를 실시간으로 출력 및 스탯 오버레이 갱신 구현.

### 📁 수정된 주요 파일
- [MODIFY] [enums.gd](file:///d:/ProjectLoB/새-게임-프로젝트/scripts/data/enums.gd)
- [MODIFY] [gun_data.gd](file:///d:/ProjectLoB/새-게임-프로젝트/scripts/data/gun_data.gd)
- [MODIFY] [magazine.gd](file:///d:/ProjectLoB/새-게임-프로젝트/scripts/core/magazine.gd)
- [MODIFY] [enemy_instance.gd](file:///d:/ProjectLoB/새-게임-프로젝트/scripts/core/enemy_instance.gd)
- [MODIFY] [combat_manager.gd](file:///d:/ProjectLoB/새-게임-프로젝트/scripts/core/combat_manager.gd)
- [MODIFY] [combat_scene.gd](file:///d:/ProjectLoB/새-게임-프로젝트/scripts/ui/combat_scene.gd)
- [MODIFY] [task_tracker.md](file:///d:/ProjectLoB/.agents/skills/00-project-manager/task_tracker.md)

### 💡 다음 예정 작업
- 프로토타입 밸런싱 수정 및 콘텐츠 스코프 가이드 작성

---

## 2026-06-27 (Sat) #8 - 수동 플레이테스트 시나리오 가이드 제공 및 walkthrough.md 양식 신설

### 🎯 목표
- 신규 구현된 LIFO, Unload, 적 태세 전환 규칙을 사용자가 직접 엔진에서 테스트해볼 수 있도록 검증 시나리오 가이드를 제공하고, 피드백을 기록할 수 있는 워크스루 양식을 배포.

### 🛠️ 개발 내역
**1. 수동 검증 시나리오 가이드 수립**
- LIFO 역순 장탄 퍼즐(장전 시퀀스 검증), Unload 패널티(1칸 강제 전진 및 사망 판정), 적 실시간 태세 전환(3발 격발 후 Iron Shield ↔ Active Dodger 교대 및 스탯 재설정)의 상세 테스트 절차 안내.

**2. Walkthrough 양식 신설**
- `walkthrough.md` 파일을 생성하여, 사용자가 직접 플레이하고 검증 결과를 정상/오류 여부로 아카이빙할 수 있는 리포트 템플릿 신설.

### 📁 수정된 주요 파일
- [NEW] [walkthrough.md](file:///C:/Users/mdyt7/AppData/Local/Temp/walkthrough.md) (artifacts 디렉토리 하위 생성)
- [MODIFY] [task_tracker.md](file:///d:/ProjectLoB/.agents/skills/00-project-manager/task_tracker.md)

### 💡 다음 예정 작업
- 프로토타입 콘텐츠 스코프 가이드라인 수립

---

## 2026-06-27 (Sat) #9 - 플레이테스트 피드백에 따른 프로토타입 리소스 밸런싱 보정

### 🎯 목표
- 사용자의 수동 플레이테스트 결과, "진압 방패병" 처치가 불가능했던 수식적 불균형을 개선하기 위해 전술 탄환 및 적 스탯 수치를 보정하여 밸런스 정상화.

### 🛠️ 개발 내역
**1. 카운터 전술 탄환 명중 상향**
- JHP 할로우포인트(`basic_bullet.tres`)의 `accuracy`를 `5 ➡️ 7`로 조정하여, 적이 `Active Dodger` 태세(EVA 7)로 변환했을 때도 정상 명중 및 카운터 공격(DEF 0 대상 고대미지)이 가능하도록 보정.

**2. FMJ 철갑탄 관통 및 적 HP 조율**
- FMJ 철갑탄(`armor_piercing.tres`)의 `penetration`을 `3 ➡️ 4`로 올려 첫 사격 시 대미지가 정상적으로 꽂히도록 상향.
- 진압 방패병(`tank.tres`)의 `max_hp`를 `15 ➡️ 12`로 하향 조정하여, 6발 탄창 한도 내에서 설계된 순서대로 대응 시 격파할 수 있도록 체력 밸런싱.

### 📁 수정된 주요 파일
- [MODIFY] [basic_bullet.tres](file:///d:/ProjectLoB/새-게임-프로젝트/resources/bullets/basic_bullet.tres)
- [MODIFY] [armor_piercing.tres](file:///d:/ProjectLoB/새-게임-프로젝트/resources/bullets/armor_piercing.tres)
- [MODIFY] [tank.tres](file:///d:/ProjectLoB/새-게임-프로젝트/resources/enemies/tank.tres)
- [MODIFY] [task_tracker.md](file:///d:/ProjectLoB/.agents/skills/00-project-manager/task_tracker.md)

### 💡 다음 예정 작업
- 프로토타입 메타 진행 및 로그라이크 노드 선택 룰 고도화

---

## 2026-06-27 (Sat) #10 - GDD 콘텐츠 스코프 가이드라인 수립 (GDD v0.8)

### 🎯 목표
- 1인/소규모 1인 개발 환경에 적합하도록 총기, 탄환, 적, 렐릭의 볼륨을 조절하는 양적 상한선(Scope Ceiling)과 한 손 플레이 암산을 위한 스탯 밴드(Stat Bands), 그리고 신규 콘텐츠 검증 워크플로우를 정의하여 GDD에 통합.

### 🛠️ 개발 내역
**1. 콘텐츠 규모 상한선 (Scope Ceiling) 설계**
- **총기 4종**: 표준 리볼버, 더블배럴 산탄총(넉백+1), 전술 SMG(10발 + 약실 1발), DMR(4발 + 약실 1발, 명중 +1) 아키타입 정의.
- **탄환 15종**: 스탯 특화 기본 탄환 5종(JHP, FMJ, 스턴탄, EMP, 매치그레이드) 및 효과 중심 전술 탄환 10종(Opening Shot, Last Shot, Combo Shot, Breaker Slug 등) 구성.
- **적 5종**: 기본 3대 아키타입 + 저격 드론(넉백 감산) + 보스 '센트리'(실드 전개) 규정.
- **렐릭 20종**: 장전/Unload 메카닉과 호환되는 렐릭 설계(예: Unload 패널티 면제 장갑, 스마트 고글 등).

**2. 인지적 스탯 밴드 (Cognitive Stat Bands) 수립**
- 대미지/체력(1~20), 명중/회피(0~8), 관통/저항(0~5), 속도/거리(0~12)로 수치 확장을 차단하여 한 손 암산 계산 투명성을 유지.

**3. 신규 콘텐츠 추가 검증 워크플로우 설계**
- 스탯 밴드 ➡️ 설계 5대 필라 대조 ➡️ 기존 카운터 정합성 검증으로 이어지는 3단계 체크리스트 검증 모델 도입.

### 📁 수정된 주요 파일
- [MODIFY] [game_design_document.md](file:///d:/ProjectLoB/docs/game_design_document.md)
- [NEW] [10_content_scope_guide.md](file:///d:/ProjectLoB/docs/gdd/10_content_scope_guide.md)
- [MODIFY] [task_tracker.md](file:///d:/ProjectLoB/.agents/skills/00-project-manager/task_tracker.md)

### 💡 다음 예정 작업
- 상용 비즈니스 모델(BM) 및 수익 구조 초안 기획 수립

---

## 2026-06-27 (Sat) #11 - GDD 로그라이크 런 및 메타 진행 규칙 고도화 (GDD v0.9)

### 🎯 목표
- 층별 단면도 맵 진행에 필요한 침투 경로별 리스크와 기회비용, 정비 구역(무기 캐비닛)의 세부 상호작용 액션, 그리고 런 종료 후 데이터 칩 정산을 활용한 영구 메타 성장 트랙을 구체적으로 기획하고 GDD에 이식.

### 🛠️ 개발 내역
**1. 3대 침투 경로 기회비용 정의**
- **비상계단**: 기본 상승, 안전 지향, 평균적 전투 및 보상.
- **환기구**: 전투 빈도 낮음, 렐릭/보상 파밍 확률 증가, 단 전투 조우 시 **시작 거리 강제 -2칸 단축** 패널티 적용.
- **엘리베이터 샤프트**: 2~3개 층 스킵 돌파 가능하나, 와이어 끊어짐 등으로 **HP 버퍼 1 소실** 리스크가 있거나 **시작 거리가 4칸인 초근접 강습 전투** 리스크 부여.

**2. 5대 노드 세부 상호작용 설계**
- **무기 캐비닛**: 장약 보강(탄환 영구 DMG +1 또는 넉백 +1), 약실 소탕(리로드 턴 1회 면제 버프), 탄환 폐기(덱 압축 용융)의 3택 전술 기능 신설.
- **대피소/휴게실**: HP 버퍼 1 보급 및 Unload(빼내기) 조작으로 소실된 전술 탄환을 덱으로 수거 복귀시키는 자원 복구 메커니즘 구체화.
- **보안 통제실**: 센서 고글 렐릭(가시성) 획득 ↔ 다음 층 SPD 증가 등 리스크 기반 렐릭 파밍 이벤트 정의.

**3. 작전 디브리핑 및 영구 메타 성장 트랙 설계**
- **정산 공식**: `Credit = (도달 층수 * 10) + (처치한 적 수 * 5) + (획득한 렐릭 수 * 15)`
- **영구 업그레이드 트랙 (4종)**: 시작 덱 용량 확장, 최대 HP 버퍼 확장(기본 1 ➡️ 최대 3), 캐비닛 폐기 수수료 할인, 특수 전술 탄환 드래프트 풀 잠금 해제 체계 정립.

### 📁 수정된 주요 파일
- [MODIFY] [game_design_document.md](file:///d:/ProjectLoB/docs/game_design_document.md)
- [MODIFY] [08_meta_progression.md](file:///d:/ProjectLoB/docs/gdd/08_meta_progression.md)
- [MODIFY] [task_tracker.md](file:///d:/ProjectLoB/.agents/skills/00-project-manager/task_tracker.md)

### 💡 다음 예정 작업
- GDD 확장: 상용 비즈니스 모델(BM) 및 수익 구조 초안 기획 수립

---

## 2026-06-27 (Sat) #12 - 프로토타입 메카닉 고도화 구현 (약실, 넉백 저항, 렐릭 연동)

### 🎯 목표
- GDD v0.9의 전술 메카닉(약실 용량 확장, 공중 드론 넉백 감쇄, 3대 시너지 렐릭)을 실제 Godot 프로젝트의 GDScript 로직 및 UI에 이식.

### 🛠️ 개발 내역
**1. 약실 (Chamber) 시스템 구현**
- `gun_data.gd`에 `passive_acc_bonus` 명중 패시브 추가 및 패시브 보너스 가산 수치 범위 음수 허용 리팩토링.
- `magazine.gd`에서 총의 `has_chamber` 필드를 판별하여 최대 장입량을 `Capacity + 1`발로 동적 확장 및 약실 장탄 구현.
- `damage_calculator.gd`에서 명중률 계산 시 총의 명중 패시브 보정을 가산하도록 갱신.

**2. 넉백 저항 (Knockback Resistance) 메커니즘 적용**
- `enemy_data.gd` 및 `enemy_instance.gd`에 `knockback_resistance` 스탯 추가.
- 드론과 같이 호버링 면역이 있는 적 대상 넉백 연동 시 `apply_knockback` 함수에서 저항값 감산 처리 구현.

**3. 3대 전술 렐릭 테스트 시스템 및 UI 신설**
- `combat_manager.gd`에 활성화된 렐릭 목록 변수 및 전투당 1회 Unload 면제 플래그 탑재.
- `combat_scene.gd` 화면 상단에 렐릭 3종(`CheckButton`) UI 추가 및 `start_encounter` 시 목록 전달 연동.
- **전술 가죽 장갑 (`tactical_gloves`)**: 전투 중 1회 Unload 시 적 전진 패널티 면제 적용.
- **가스압 증폭 밸브 (`gas_valve`)**: 모든 사격의 넉백 수치를 +1칸 가산 적용.
- **스마트 센서 고글 (`smart_sensor_goggles`)**: 해제 시 적 HUD 스탯을 `DEF ? | EVA ?` 등으로 숨기고, 장착 시에만 완전 정보 노출 처리.

**4. 신규 리소스 에셋 보충**
- `smg.tres` (10발, 약실 지원, DMG -1 패시브), `dmr.tres` (4발, 약실 지원, ACC +1 패시브), `sentry_drone.tres` (HP 4, EVA 5, SPD 2, 넉백 저항 1) 생성 및 UI 선택지에 바인딩.

### 📁 수정된 주요 파일
- [MODIFY] [gun_data.gd](file:///d:/ProjectLoB/새-게임-프로젝트/scripts/data/gun_data.gd)
- [MODIFY] [enemy_data.gd](file:///d:/ProjectLoB/새-게임-프로젝트/scripts/data/enemy_data.gd)
- [MODIFY] [enemy_instance.gd](file:///d:/ProjectLoB/새-게임-프로젝트/scripts/core/enemy_instance.gd)
- [MODIFY] [magazine.gd](file:///d:/ProjectLoB/새-게임-프로젝트/scripts/core/magazine.gd)
- [MODIFY] [damage_calculator.gd](file:///d:/ProjectLoB/새-게임-프로젝트/scripts/core/damage_calculator.gd)
- [MODIFY] [combat_manager.gd](file:///d:/ProjectLoB/새-게임-프로젝트/scripts/core/combat_manager.gd)
- [MODIFY] [combat_scene.gd](file:///d:/ProjectLoB/새-게임-프로젝트/scripts/ui/combat_scene.gd)
- [NEW] [smg.tres](file:///d:/ProjectLoB/새-게임-프로젝트/resources/guns/smg.tres)
- [NEW] [dmr.tres](file:///d:/ProjectLoB/새-게임-프로젝트/resources/guns/dmr.tres)
- [NEW] [sentry_drone.tres](file:///d:/ProjectLoB/새-게임-프로젝트/resources/enemies/sentry_drone.tres)
- [MODIFY] [task_tracker.md](file:///d:/ProjectLoB/.agents/skills/00-project-manager/task_tracker.md)

### 💡 다음 예정 작업
- 콘텐츠 에셋 볼륨 추가 확장 (렐릭 및 전술 탄환 추가 구현)

---

## 2026-06-27 (Sat) #13 - 프로토타입 로그라이크 런 및 메타 진행 연동

### 🎯 목표
- 빌딩 층별 진행, 기회비용 통로(비상계단/환기구/샤프트) 선택, 비전투 정비실 조작, 그리고 런 정산 및 영구 메타 상점을 완벽히 연동한 런(Run) 플레이 루프 구현.

### 🛠️ 개발 내역
**1. RunManager 클래스 신설 및 데이터 모델링**
- `run_manager.gd`를 생성하여 런의 라이프사이클 및 가변 상태(HP 버퍼, 크레딧, 현재 층, 덱 카드, 렐릭, 소실 탄고) 제어.
- 1층~5층(옥상 보스)의 결정론적 노드 지도 생성 규칙 구현.
- 통로별 특수 디버프(환기구: 거리-2, 샤프트: 30% 확률 버퍼 소실 혹은 시작 거리 4 고정) 산출 로직 구현.
- 영구 메타 업그레이드 트랙(덱 용량 Lv.3, HP 아머 Lv.2, 폐기 무료화)을 클래스 정적 변수로 유지.

**2. 단일 UI 씬 루프 개편 및 다중 오버레이 탑재**
- `combat_scene.gd`에 메타 상점, 층별 맵, 비전투 정비실, 디브리핑용 전용 오버레이 컨테이너 생성 및 이식.
- **메타 상점**: 보유 Cr 노출 및 3종 영구 업그레이드 해금 클릭 시 정적 변수 차감/레벨업 반영.
- **빌딩 단면도 맵**: 층 상승에 맞춰 분기 방 버튼 생성 및 통로 선택 팝업 연동.
- **정비실 (무기 캐비닛/대피소/보안실)**: 노드에 맞춤화된 조작 버튼(탄환 강화, 약실 소탕 버프 적용, 덱 압축 폐기, HP 아머 회복, 소실 탄환 복구, 터미널 해킹 스마트 고글 강제 장착) 및 동적 덱 리스트 선택 스크립트 작성.
- **디브리핑**: 런 클리어/실패 정산 수식 및 획득 Cr 환전 결과 출력.

**3. HP 버퍼 및 소실 탄고 수집 시스템 연동**
- `combat_manager.gd`에 `bullet_unloaded` 시그널 신설하여 전투 중 Unload 처리 시 즉시 `RunManager`의 소실 풀로 빼내 덱에서 임시 배제.
- `combat_scene.gd`에서 요원 사망 시 `hp_buffer > 0` 이면 버퍼 1칸을 차감하고 맵으로 안전 철수(탈출)시키고, 버퍼가 0일 때 비로소 완전 사망하여 런이 종료되도록 라이프/완충재 물리 구현.

### 📁 수정된 주요 파일
- [NEW] [run_manager.gd](file:///d:/ProjectLoB/새-게임-프로젝트/scripts/core/run_manager.gd)
- [MODIFY] [combat_manager.gd](file:///d:/ProjectLoB/새-게임-프로젝트/scripts/core/combat_manager.gd)
- [MODIFY] [combat_scene.gd](file:///d:/ProjectLoB/새-게임-프로젝트/scripts/ui/combat_scene.gd)
- [MODIFY] [task_tracker.md](file:///d:/ProjectLoB/.agents/skills/00-project-manager/task_tracker.md)

### 💡 다음 예정 작업
- 콘텐츠 에셋 볼륨 추가 확장 (렐릭 및 전술 탄환 추가 구현)
