# 현재 UI 목록

2026-11-07 기준(관문 11-07·탄약고·조우·빌드 작업실·공통 창 11-08 반영), 본편(`PLAY.cmd` → `redesign/main.tscn`)에서 실제로 열리는 화면과 창을 코드 기준으로 정리했다. 진입은 `screen.gd::redraw()`의 `page`(menu / loadout / run)와 `campaign.s.phase`로 나뉘고, 전투 밖 등반 화면은 `campaign_ui.gd::render()`가 고른다. 개편 우선순위와 이유는 [UI 개편 대상](ui-rework-scope.md)을 따른다. 이 문서는 현황 목록이며 새 결정이 아니다.

상태 표기:

- **개편 반영**: 11월 개편이 본편에 연결됨(날짜는 마지막 본편 반영)
- **시안만**: 개편 시안이 있으나 본편은 이전 화면
- **이전 화면**: 개편 전 공통 틀(`_phase_intro`·`_service_place`·`_workspace`) 사용
- **유지**: 개편 대상에서 일부러 뺀 화면

## 1. 등반 흐름의 주 화면

| # | 화면 | 언제 열림 | 본편 구현 | 상태 |
| --- | --- | --- | --- | --- |
| 1 | 타이틀 | 실행 직후 | `title_screen.tscn` | 이어하기 위치 표시, 첫 실행 조작 안내 한 곳, 어두운 철제와 황동 테두리의 주 행동 |
| 2 | 캐릭터·장비 선택(총기·복장·출발 설정) | 새 등반 / 기초 훈련 | `equipment_screen.tscn`, 낮은 화면은 `equipment/screen_short.tscn` | 개편 반영 11-06 |
| 3 | 출발 장면 | 새 등반 첫 진입 | `story_ui.gd::departure` → `story/scene_view.gd` | 개편 반영 11-08([이야기 장면](../qa/reports/story_scenes_2026-11-08/README.md)) |
| 4 | 지도(배관도) | 장소 사이 | `pipe_map/screen.tscn` | 개편 반영 11-06(철제 재질) |
| 5 | 전투 HUD | 전투 장소, 매복 | `campaign_hud/combat.tscn` + 구역별 전장 5종(주거·주조장·정원·귀족·중앙) | 개편 반영 11-06(중립 재질), 연계 표시 11-01 |
| 6 | 전투 보상(코어·탄·파츠·보스 전리품·교체) | 전투 승리 | `rewards/screen.tscn` | 개편 반영 11-05 |
| 7 | 상점(물자 거래 단말) | 상점 | `shop_terminal_live.tscn` 계열 | 개편 반영 11-06(상호작용) |
| 8 | 정비소(공방) | 공방 | `workbench/screen.tscn` | 개편 반영 — 새 기준 화면 |
| 9 | 보급소(탄약고) | 탄약고 | `campaign_ui.gd::modern_depot` → `samples/supply_review/preview.tscn` | 개편 반영 11-08([본편 연결](../qa/reports/supply_live_2026-11-08/README.md)) |
| 10 | 사건·조우 | 조우 장소 | `campaign_ui.gd::modern_event` → `samples/event_review/preview.tscn` | 개편 반영 11-08([본편 연결](../qa/reports/event_live_2026-11-08/README.md)) |
| 11 | 관문(개조·재정비·출발) | 구역 보스 승리 후 | `campaign_ui.gd::modern_gate` → `samples/gate_review/threshold_preview.tscn` | 개편 반영 11-07([본편 연결](../qa/reports/gate_live_2026-11-07/README.md)). 이전 규칙 저장만 `gate_reward_ui.gd` |
| 12 | 공급 복구 | 최종 보스 승리 후 | `story_ui.gd::restoration` → `story/scene_view.gd` | 개편 반영 11-08 |
| 13 | 귀환 | 공급 복구 뒤 | `story_ui.gd::homecoming` → `story/scene_view.gd` | 개편 반영 11-08 |
| 14 | 등반 결과(승리·패배) | 귀환 뒤 / 패배 | `results/screen.tscn` | 개편 반영 11-04 |

## 2. 등반 중 여는 창

| 창 | 여는 곳 | 본편 구현 | 상태 |
| --- | --- | --- | --- |
| 빌드 작업실(파츠 장착·교체·해제, 탄환 덱) | 지도 `빌드`, 장소 `메뉴 → 내 빌드`, 상점·보상 `빌드` | `campaign_ui.gd::deck` → `build/workshop.gd` (+ 상점 `part_mount.tscn`) | 개편 반영 11-08([승인 구성으로 통일](../qa/reports/build_live_2026-11-08/README.md)) |
| 장소 상세(`자세히`) | 지도 | `pipe_map/place.tscn` | 개편 반영 11-06 |
| 기호 설명 | 지도 `기호` | `pipe_map/key.tscn` | 개편 반영 11-06 |
| 전투 메뉴(도움말·재도전·등반 현황·시작 화면·효과음·연출 속도) | 전투 `메뉴` | `samples/hud/combat_menu.tscn` | 개편 반영 |
| 전투 상세(탄 N번 상세·적·증원·압력탄·보유 탄약·총기와 빌드) | 전투 탄/적 터치, `남은 N발`, `빌드` | `samples/hud/combat_detail.tscn` | 개편 반영 |
| 상점 비교·현장 기록 | 상점 | `shop_terminal_live.tscn` 내부 | 개편 반영 |
| 정비 작업 확인(개조·압축·제거·교체·가방) | 정비소 | `workbench/upgrade_dialog*.tscn` | 개편 반영 |
| 보상 상세·교전 기록 | 전투 보상 | `rewards/screen.tscn` 내부 | 개편 반영 |
| 관문 메뉴(내 빌드·기록·설정·타이틀로)·전용 탄 견본/교체 | 관문 | 관문 장면 내부 | 개편 반영 11-07 |
| 결과 상세 | 등반 결과 | `results/screen.tscn` 내부 | 개편 반영 |

## 3. 타이틀에서 여는 창

| 창 | 버튼 | 본편 구현 | 상태 |
| --- | --- | --- | --- |
| 설정 | `설정`(타이틀·지도·장소 메뉴·상점·정비소) | `screen.gd::_settings` → `common/windows.gd` (+ `common/window.tscn`) | 개편 반영 11-08([공통 창](../qa/reports/common_windows_2026-11-08/README.md)) |
| 조작 안내 | `조작 안내`, 첫 실행 `처음이라면 · 조작 안내` | `screen.gd::_guide` → `common/windows.gd` | 개편 반영 11-08 |
| 게임 규칙 | `게임 규칙` | `screen.gd::_rules` → `common/windows.gd` | 개편 반영 11-08 |
| 기록실(도시 기록 20편. 보급 선호 탭은 11-08부터 숨김) | `기록실`, 지도·장소 메뉴 `기록` | `campaign_ui.gd::archive` → `common/archive.gd` | 개편 반영 11-08 |
| 기초 훈련 / 훈련 계속 | `기초 훈련` | 이전 손패·장전 전투 화면(`screen.gd::_combat`) | 이전 화면. 훈련은 탄창 개편 전 규칙을 그대로 쓴다 |
| 개발 실험실 | `개발` | `developer_lab.tscn` | 개발용(플레이어 화면 아님) |

## 4. 본편 밖 검토 화면

`redesign/samples/`의 장면(탄창 여정·비교 전투·시안 전장 등), 관문 시안 3종, HTML 검토판(`docs/qa/reports/ui_prototype_2026-10-31/`)은 본편에서 열리지 않는다. 개편 비교와 검증용이다.

## 요약

- 타이틀은 기존 장면에 저장된 구역·층·장소를 표시한다. 첫 출발과 정상 공급 복구는 해당 장면의 이름을 쓴다. 이어갈 등반이 있으면 ‘등반 계속’, 없으면 ‘새 등반’에 어두운 철제 면과 황동 테두리를 쓴다.
- **공통 창**(설정·조작 안내·게임 규칙·기록실) 개편 반영 11-08. 확인 창(분해 확인 등)과 전투 중 창은 아직 이전 청록 대화창(`console_dialog.tscn`).
- 11-08 이야기 장면(출발·공급 복구·귀환)·파츠 분해 확인·파츠 상세도 개편 반영. 장비 선택의 등반 교체 확인은 승인된 장비 대화창 그대로.
- **남은 이전 화면**: 기초 훈련(유지·재제작·삭제 결정 필요), 탄환 상세·전투 정보 등 기타 대화창.
- **출시 준비(11-12)**: 기초 훈련·개발 메뉴·태그 비교 토글은 출시판 타이틀과 등반 설정에서 숨기고 개발 도구(타이틀 글자 7번 누르기)로 묶었다. 본편 밖에서 여는 메뉴·상세·기록 창은 황동 재질(`common/window.tscn`, `common/workspace_skin.gd`)로 맞췄다. 이전 청록 대화창은 손패 훈련 전투에만 남는다. [출시 준비 점검](launch-readiness.md).
