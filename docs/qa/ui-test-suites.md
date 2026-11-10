# UI 검사 목록 — 현재 검사와 은퇴한 검사

2026-11-08 정리. 11월 UI 개편(상점 단말 11-04, 정비소 11-04, 장비 11-06, 관문 11-07, 탄약고·조우·빌드 작업실·공통 창·이야기 장면 11-08) 뒤에 **현재 화면을 검사하는 것**과 **없어진 화면을 누르던 것**을 나눴다. 이 문서는 검사 운영 기록이며 게임 결정은 `docs/direction/`을 따른다.

## 한 번에 돌리기

```powershell
tools\run_current_ui_checks.ps1                 # 전체(4개씩 병렬, 약 15분)
tools\run_current_ui_checks.ps1 -Only gate_live_ui,build_live_ui
```

- 검사마다 `qa_runtime\current_ui_checks\<시각>\<검사>\qa_runtime\<격리 폴더>`에 따로 저장한다. 플레이어 저장은 건드리지 않는다.
- 스크립트 오류 뒤 20초 동안 출력이 없으면 멈춘 것으로 보고 그 검사 프로세스만 끈다(오래된 검사는 오류 뒤 종료하지 않고 멈춘다).
- 하나라도 실패·스크립트 오류가 있으면 실패로 끝난다.
- 실제 등반 상태가 필요하다: `qa_runtime\ammo_upgrade_single_20261106\balance_final`(11-06 자동 등반, `tests/ammo_upgrade_live.gd`가 만든다). 관문·입구·전투·상점·승리 상태를 쓴다.

## 현재 검사 (2026-11-08 모두 통과)

| 검사 | 대상 | 검사 수 |
| --- | --- | --- |
| `gate_live_ui` | 관문 | 123 |
| `supply_live_ui` | 탄약고 | 85 |
| `event_live_ui` | 조우 | 72 |
| `build_live_ui` | 빌드 작업실 | 105 |
| `common_windows_ui` | 설정·조작 안내·게임 규칙·기록실, 타이틀 낮은 화면 | 119 |
| `story_scenes_ui` | 출발·공급 복구·귀환, 파츠 분해 확인, 파츠 상세 | 90 |
| `equipment_live_ui` | 장비 선택(총기·복장) | 6142 |
| `equipment_dialog_ui` | 장비 화면 대화창 | 72 |
| `title_ui_runner` | 타이틀·저장 안전 | 190 |
| `preart_ux_runner` | 첫 안내·설정 저장·뒤로 가기 | 34 |
| `console_visual_runner` | 타이틀·설정 화면 모양 | 35 |
| `modal_touch_runner` | 대화창 터치·스크롤·포커스 | 66 |
| `line_world_ui` | 지도 경로·장소 출입 | 653 |
| `shop_terminal_live_runner` | 상점 단말 | 318 |
| `reward_live_runner` | 전투 보상 | 104 |
| `results_live_runner` | 등반 결과 | 1211 |
| `workshop_standard_ui` | 정비소 | 1881 |
| `weapon_live_ui` | 탄창 전투 | 151 |
| `build_engine_rules` | 빌드 엔진 시험(공명기·기록기·계산 줄·제시·저장) | 25 |
| `build_engine_ui` | 전투 계산 줄 표시, 새 파츠 아이콘·기록 | 13 |

2026-11-08에 고친 검사: `title_ui_runner`(엔딩 고정 상태를 실제 승리 상태로), `preart_ux_runner`·`console_visual_runner`·`modal_touch_runner`·`equipment_dialog_ui`·`line_world_ui`(설정 선택 버튼, 출발 장면, 탄약고 장면, 공통 창). 바뀐 줄에는 날짜와 이유를 주석으로 남겼다.

## 은퇴한 검사 (실행 대상에서 제외)

파일은 지우지 않았다. 각 파일 맨 위에 `RETIRED 2026-11-08` 주석으로 사유와 대체 검사를 적었다. 다른 검사가 상속하는 파일은 '기반 클래스이므로 지우지 말 것'도 적었다.

| 검사 | 왜 | 대체 |
| --- | --- | --- |
| `city_ui_runner` | 이전 장소·상점·관문·빌드 버튼으로 등반 전체를 재현 | 위 현재 검사 전체 |
| `gate_ui_runner`, `late_growth_ui_runner`, `economy_roles_ui`, `playtest_rework_ui` | 이전 관문 격자(`city_gate_*`) | `gate_live_ui` |
| `bag_growth_ui_runner`, `place_clarity_ui_runner`, `place_layout_ui_runner`, `place_revision_ui_runner`, `service_location_ui_runner`, `earned_ammo_ui_runner` | 이전 장소 틀·정비소·탄약 교체 창 | `supply_live_ui`, `event_live_ui`, `workshop_standard_ui`, `shop_terminal_live_runner` |
| `production_experience_runner`, `shop_parts_ui_runner` | 이전 상점 비교 버튼 | `shop_terminal_live_runner` |
| `core_choice_ui`, `part_grade_ui_runner`, `parts_revision_ui_runner`, `navigation_ui_runner` | 이전 빌드 작업실·준비 화면 | `build_live_ui`, `equipment_live_ui` |
| `build_synergy_ui_runner`, `heat_builds_ui_runner`, `heat_polish_ui_runner`, `interaction_flow_runner`, `progression_ui_runner` | 이전 손패 장전 전투 | `weapon_live_ui`, `reward_live_runner` |
| `ui_readability_ui` | 11-03 장소·전투 배치 범위 | 개편 화면별 검사 |
| `story_flow_runner` | 이전 이야기·기록실 배치 | `story_scenes_ui`, `common_windows_ui` |
| `presentation_feedback_runner` | 이전 손패 전투·상점·보상 버튼으로 효과음 신호 확인(설정 부분은 고침) | **없음** — 탄창 전투의 효과음 신호 검사는 새로 필요 |
| `outfits_live_runner` | 이전 손패 전투(지도 1판)의 복장별 시작 손패 | `equipment_live_ui` |
| `line_theme_capture` | `LOB_UI_DATA`가 필요한 캡처 도구 | `line_world_ui` |

기준 실행(11-08)에서 은퇴 검사는 대부분 수십~수백 개 실패하거나 스크립트 오류로 멈췄다(예: `story_flow_runner` 1101 중 787, `navigation_ui_runner` 116, `parts_revision_ui_runner` 95). 실패 대부분은 11-08 이전부터 있었다.

## 확인하지 못한 것

- `presentation_feedback_runner`가 보던 효과음 신호(사격·명중·과열·재장전)는 탄창 전투에서 다시 검사해야 한다.
- 기초 훈련(이전 손패 전투)의 끌어서 압축·탭 장전 검사는 `modal_touch_runner`에서 `QA_LEGACY_HAND=1`일 때만 돈다. 기준 실행에서 실패했다. 기초 훈련을 유지할지 정해질 때까지 훈련 화면이 실제로 고장인지 확인하지 않았다.
- `outfits_live_runner`에서 이전 규칙 저장(지도 1판)의 열 작업복 시작 손패가 비었다. 이전 저장에만 해당하는지 확인하지 않았다.
