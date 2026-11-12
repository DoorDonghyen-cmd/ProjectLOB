# 태그 기반 탄환·파츠 비교 시험판 — 검증

2026-11-10. 설계와 결정 상태는 [태그 시험판](../../../direction/tag-build.md)에 있다. 이 문서는 무엇을 어떻게 확인했는지 적는다.

## 기능 확인

| 검사 | 내용 | 결과 |
| --- | --- | --- |
| `tests/tag_build_rules.gd` | 태그 판정, 파츠 15종 계산(실제 `Model._shot`), 복제 순서·건너뛰기, 화염 처치 기록, 제시(태그 등반 42회 제시·바꿔 뺀 파츠 0·일반 등반 누출 0), 아이콘·문구, 저장·복원·잘못된 저장 거부 | 63 통과(화염 파츠 뒤) |
| `tests/tag_build_ui.gd` | 1280×800·844×390. 등반 설정 토글 → 새 등반 플래그, 같은 시드 재시작 유지, 현재 구성으로 되돌림, 상점 태그 파츠 상세(덱의 태그 탄 표시, v2 문구), 전투 HUD 빌드 창 | 38 통과 |
| `tests/growth_v2_climb.gd` `QA_TAGS=0/1` | 3총기 × 두 구성 × 시드 17·23·41, 실제 전투 30회 자동 등반 | 18/18 완주 |
| `tests/tag_fire_bench.gd` | 리액터 실제 4·5구역 보스·정예 4전투에서 파츠 세트 5종 비교(첫 줄이 등반 기록과 일치) | 실패 0 |
| 규칙 회귀 | focus_build 643, build_roles 3048, damage_engines 657, growth_structure 50, build_engine 25 | 통과 |
| `magazine_build_rules` | 64검사 | 기존 실패 1건(후미 점화기)만 남음 |
| 현재 UI 검사 | `tools/run_current_ui_checks.ps1` | 전체 24종 통과(11-10 23:11, 화염 파츠 추가 뒤 23:45 다시 24종 통과) |

자동 등반 비교 표는 [태그 시험판](../../../direction/tag-build.md#자동-등반-비교-11-10)에 있다.

## 화면 확인

| 화면 | 1280×800 | 844×390 |
| --- | --- | --- |
| 등반 설정 · 태그 시험판 선택 | [보기](options_tags_1280x800.png) | [보기](options_tags_844x390.png) |
| 상점 · 다회 가속기 상세 | [보기](shop_tag_part_1280x800.png) | [보기](shop_tag_part_844x390.png) |
| 전투 HUD · 총기와 빌드 | [보기](combat_tag_build_1280x800.png) | [보기](combat_tag_build_844x390.png) |

- 등반 설정: 짧은 화면에서도 두 버튼과 설명이 한 화면에 들어온다. 선택한 쪽이 강조색이다.
- 상점 상세: 덱에서 그 태그를 가진 공격탄을 보여 준다(예: '다회 태그 공격탄 · 연타탄 7'). 태그 파츠 아이콘은 대신하는 파츠의 아이콘을 빌려 쓴다(다회 가속기 = 복열 노리쇠 그림). 전용 아이콘은 후속.
- 전투 빌드 창: '태그 시험판 · 장전된 탄창 태그 N종', 파츠 이름과 효과 문구. 일반 파츠의 빈 값 줄이 없어졌다.

## 사람 확인

아직 없다. 볼 것:
- 탄의 태그를 보고 파츠를 고르는 이유가 바로 보이는가.
- 복제 기판의 '왼쪽에서 가장 가까운 태그 파츠'를 이해하는가.

## 함께 고친 것

- 전투 중 파츠 상세(`screen.gd::_combat_part_details`): 파츠 색 표에 없는 ID에서 멈출 수 있어 등급 색으로 대신한다.
- 전투 HUD 빌드 창(`campaign_hud/combat.gd::show_parts`): 일반 파츠의 빈 '·'·빈 줄 제거, v2에서 '첫 승리 뒤 성장 코어' 안내를 '장착 파츠 없음'으로.
- 파츠 상세(`campaign_ui.gd`): v2 등반에서 '코어는 별도 장착 제한' 문구를 숨긴다. 태그 파츠는 '특정 탄종 없이 적용' 대신 덱의 태그 탄·탄창 태그 수·복제 대상을 보여 준다(`build_guide.gd`).
- `build_roles_rules`: 11-03 제시 비교를 태그 전 파츠 목록으로 한 번 돌려 고정했다(`qa_runtime/build_roles_20261103/offers_before_tags_20261110.json`, `QA_OFFER_BASELINE=write`로 다시 만든다).
- `magazine_build_rules`: v2 이전 규칙으로 고정(새 등반에서 성장 v2 플래그를 지운다).

## 변경

- [changes.patch](changes.patch): `tag_build.gd`·검사 2종(새 파일)과 `build_choices`·`campaign`·`campaign_content`·`content`·`equipment_screen`·`model`·`part_card_view`·`part_icon_art`·`screen`의 태그 작업 전후 차이.
- 그 밖의 작은 수정: `campaign_hud/combat.gd`, `campaign_ui.gd`, `build_guide.gd`, `tests/growth_v2_climb.gd`(`QA_TAGS`), `tests/build_roles_rules.gd`, `tests/magazine_build_rules.gd`, `tools/run_current_ui_checks.ps1`(검사 2종 추가).

## 탄 카드 태그 표시 (11-11)

사용자 플레이 피드백("태그 효과를 잘 모르겠어") 뒤 추가. 설계는 [화면에서 보이는 곳](../../../direction/tag-build.md#화면에서-보이는-곳-11-11).

| 화면 | 1280×800 | 844×390 |
| --- | --- | --- |
| 전투 탄창 카드의 태그 글자 | [보기](combat_tag_cards_1280x800.png) · [확대](combat_tag_cards_zoom.png) | [보기](combat_tag_cards_844x390.png) |
| 탄 상세(1번 소이탄) | [보기](combat_tag_round_1280x800.png) | [보기](combat_tag_round_844x390.png) |

- 기능: `tag_build_rules` 222검사(공격탄마다 3칸 이하·`타격` 없음, 글자·색 표, 탄 상세 문구, 일반 등반에 태그 줄 없음), `tag_build_ui` 64검사(태그 있는 탄마다 카드 안에 글자, 화염 점화기 장착 시 화염 칸만 채움, 기본탄에 글자 없음, 탄 상세 첫 줄).
- 시각: 확대 캡처에서 소이탄 '화'(채움)·'단'(글자만), 차단탄 '제'(글자만)를 확인했다. 처음 그린 테두리 상자는 켜진 칸과 구별되지 않아 고쳤다.
- 사람 확인: 아직. 카드 글자만으로 효과를 읽을 수 있는지, 탄 상세를 열어 보는지 볼 것.
- 현재 UI 검사: 24종 모두 통과(11-11 07:53).
