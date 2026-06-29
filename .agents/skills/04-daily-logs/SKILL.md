---
name: 04-daily-logs
description: ProjectLoB 일일 작업 내역 요약 및 히스토리 트래킹용 스킬. 대화 및 작업 종료 시 오늘 진행한 작업, 작성한 코드, 해결한 이슈, 다음 할 일 등을 일자별로 정리하여 기록합니다. 트리거: 작업 요약 요청, 오늘 뭐했지?, 데일리 로그 작성, 작업 내역 기록 등.
---

# 📅 ProjectLoB Daily Logs

이 문서는 프로젝트의 일일 개발 진행 상황, 수정된 주요 파일, 해결된 버그, 그리고 다음 목표를 추적 관리하기 위한 로그입니다.

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
