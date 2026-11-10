# UI 정합성 독립 증거 B — 2026-11-06

검토 대상은 최신 지도와 장비 선택, 정비소·상점·보상·결과, 보충 요청한 현행 전투 HUD다. A의 출력은 읽지 않았다. 탐지 결과는 A 완료 통보 전까지 공유하지 않았다. 게임·스킬·설정·제작 원본은 수정하지 않았으며 이 폴더에 증거만 저장했다. 미감·품질을 숫자 점수로 환산하지 않았다.

## 기준과 검사 한계

- 활성 위치: `D:/ProjectLoB/worktrees/core-redesign`. HEAD는 `197c6941fb8134349083de1e187bbe82571c5413`이며 기존 변경이 있는 작업 트리다. 따라서 HEAD만으로 빌드를 식별하지 않고 `evidence.json`에 실제 읽은 소스 35개의 SHA256을 남겼다.
- `AGENTS.md`, `docs/direction/current.md`, `art-and-ux.md`, `route-map.md`, `equipment-ui.md`, `ui-standards.md`, `combat-hud.md`의 최신 결정이 기준이다. 과거 청록 팔레트를 최신 지도·장비의 먹색/철제·아이보리·황동보다 우선하지 않았다. 다른 화면 전체에 같은 배색을 강제하지 말라는 현행 방향도 유지했다.
- Impeccable의 context를 실제 지도 씬에 실행하고 audit/audit.native의 증거·오탐 구분 절차를 읽었다. Godot 네이티브 소스·캡처로 검사했으며 브라우저·DOM이나 별도 PRODUCT/DESIGN 문서를 만들지 않았다. native 안내 자체가 `impeccable detect`가 적용되지 않는다고 명시한다. 이번 탐지 실행은 요청된 도구의 실제 지원 범위를 확인하는 증거다.
- 이번 검토는 기존 캡처의 시각 확인과 정적 소스/해시 대조다. 새 게임 실행·입력 테스트·Android 실기기·사람의 이해도 시험은 수행하지 않았다. 기존 기능 검사 개수는 미감 점수나 이번 재실행 통과로 취급하지 않았다.

## 실제 탐지기 실행

`.agents/skills/impeccable/scripts/impeccable.cmd detect --json`에 다음 7개 파일을 명시해 한 번 실행했다.

1. `새-게임-프로젝트/redesign/pipe_map/screen.tscn`
2. `새-게임-프로젝트/redesign/pipe_map/theme.tres`
3. `새-게임-프로젝트/redesign/equipment/theme.tres`
4. `새-게임-프로젝트/redesign/workbench/theme.tres`
5. `새-게임-프로젝트/redesign/samples/shop_terminal_review/theme.tres`
6. `새-게임-프로젝트/redesign/rewards/screen.tscn`
7. `새-게임-프로젝트/redesign/results/theme.tres`

종료 코드는 0, stdout은 `[]`, stderr는 비어 있다. 원본은 `detector_output.json`, 실행 시각/인수는 `detector_invocation.json`이다. 보상은 별도 theme.tres가 없고 screen.tscn 안의 Theme/StyleBoxFlat을 검사 대상으로 지정했다. 본편 상점은 `shop_terminal_live.tscn → samples/shop_terminal_review/console_preview.tscn → preview.tscn`의 테마를 사용하므로 샘플이라는 폴더명만으로 제외하지 않았다.

**`[]`는 Godot 결함이 없다는 결과가 아니다.** 배포된 `reference/hooks.md`의 내장 지원 목록은 `.tsx/.jsx/.html/.vue/.svelte/.astro/.css/.scss/.sass/.less/.ts/.js`이며 `.tscn/.tres`는 빠져 있다. 출력에는 검사한 파일 수가 없어 실제 스캔 개수를 확인할 수 없다. 이 실행에서 네이티브 규칙 분석이 수행됐다는 근거는 없으며, 지원 파일 0개로 생긴 빈 결과일 수 있다. 확장자/설정을 추가하거나 웹 파일로 변환해 결과를 꾸미지 않았다.

## 네이티브 토큰 대조

| 화면 | 글꼴·크기 | 바탕/글자·주 행동 | 모서리·선·버튼 | 실제 표현 |
| --- | --- | --- | --- | --- |
| 지도 | 공통 `combat_pixel_font.tres`, 기본16, 제목/잔액32 | `INK=e1dccc`, `BRASS=bea36b`, 바탕 `0e130e` | StyleBoxFlat, AA off, radius4/corner_detail1, 보통1/1/1/2px, 주 행동1/2/1/2px, 내용12/8 | 조용한 평면 배관판 + PNG 도트 기호. 기호는 exact2x 원본을 사용한다. |
| 장비 | 같은 공통 글꼴·기본16 | `INK=e1dccc`, `BRASS=bea36b`가 지도와 정확히 동일 | StyleBoxFlat, AA off, radius4/detail1. 보통1/1/1/2px, 주 행동1/2/1/2px. 선택 왼쪽3px. 그 위에 edge.gd의2px 빛/그림자 | 평면 철제 선택틀 + 배경/배우·무기 PNG. 지도와 가장 직접적으로 연결되지만 가장자리 마감은 더 두텁다. |
| 정비소 | 같은 글꼴·기본16, SectionTitle32 | 아이보리 `(0.88,.84,.74)`, 황동 주 행동 `(.64,.54,.36)` | StyleBoxFlat, AA off, 각진 면, 일반 아래1px/선택 아래2px, 내용12/8 | 따뜻한 작업장 원화 + 반투명 정보면/하단 탭. 각진 아래 선은 장소별 차이다. |
| 상점 | 같은 글꼴·기본16, 대표 금액/제목32 | 회녹색 철제, 아이보리 `(.87,.85,.74)`, 구매 `(.70,.61,.40)` | StyleBoxFlat. 일반 아래1px, 주 행동 아래3px, 물리 구매키 좌/상/우2·아래6px | CRT/카세트 외함은 `console_chassis.gd`의 직사각형/깎인 다각형 그리기다. 원화 틀이라고 오인하지 않았다. 주사선은 사용자 지시의 장소 재질이다. |
| 보상 | 같은 공통 글꼴·기본16 | 차가운 먹색, 아이보리 `(.918,.886,.816)`, 수령 `(.81,.645,.419)` | 씬 내부 StyleBoxFlat, AA off, 일반 아래2px/수령 아래3px, 각진 면 | 전장 PNG 위 평면 보상 트레이. 황동 선택/수령이 지도·장비와 같은 행동 계열이다. |
| 결과 | 같은 공통 글꼴·기본16, 대표32/제목64·짧은 창48 | 자주 먹색, 아이보리 `(.93,.88,.84)`, 주 행동 `(.79,.61,.53)` | StyleBoxFlat, AA off, 각진 면/아래2px, 내용 좌우12 | 귀환/빈 전장 + 결과 패널. 장미빛/구리색은 결과 맥락의 기존 변주이며 팔레트가 다르다는 이유만으로 결함 판정하지 않았다. |

지도와 장비는 팔레트 이름만 비슷한 상태가 아니라 INK/BRASS와 깎인 모서리·기본 StyleBox 선 두께가 일치한다. **최종 가장자리 마감까지 같지는 않다.** 장비 `equipment/edge.gd:26–27`은 위쪽 y=2와 아래쪽 y=height−3에 두께2px 빛/그림자 선을 더한다. 일반 빛 `606557`·그림자 `0c110d`, 주 행동 빛 `dfc996`·그림자 `72613f`와 선택 끝 표시가 따로 있다. 정식 equipment_screen.tscn의 버튼들에 이 장식이 연결되어 있다. 지도는 기본 StyleBox의1px 위/옆·2px 아래 경계로 끝나 같은 황동 버튼도 상대적으로 얇고 평평하다. 따라서 '테마 색이 같으니 재질도 완전히 동일하다'는 결론은 피한다. 두 화면의 보조 버튼·주 행동 가장자리 마감을 맞출지는 실제 크기에서 비교할 수 있는 구체적인 보완 항목이다.

정비소/상점/보상/결과도 동일한 픽셀 글꼴과 절제된 평면 조작부가 공통 기반이다. 서로 다른 장소의 원화나 상점 외함까지 같은 형태로 만들 필요는 없다. 현재 지도에서 '철제'는 강한 광택/고해상도 프레임보다 색·절제된 모서리/선으로 표현된다.

현재 지도 캡처에서는 현재 위치의 굵은 황동 테두리, 지나온 길의 낮은 황동, 선택한 길의 밝은 황동, 이동 가능 모서리가 함께 존재한다. 이는 색 하나만 달리한 상태가 아니며 현행 방향의 상태 역할과 일치한다. 740×360에서도 이동 패널과 주 행동은 보인다. 다만 이것은 사람이 상태를 즉시 이해했다는 증거가 아니다.

## 보충: 전투 HUD의 기능색과 중립 재질

`presentation_integration_2026-11-06/after.png`를 실제로 열었다. 파일 해시는 그 보고서의 `artifact_sha256`과 일치하고, `combat_hud_presenter.gd`의 최신 해시도 `source_after`와 일치한다.

- **유지할 기능색:** `combat_hud_presenter.gd`는 WARNING=`ff6f61`, GOLD=`f3cf73`, 사격의 어두운 글자 `1c0903`, 냉각의 `bff3f1`, 위험 비용/열 경고와 실제 사격/장전 준비를 따로 처리한다. `combat_pixel_skin.gd`는 HEAT=`e39b79`, COOL=`9abdc8`, SELECT=`5cdddc`를 구분한다. 다음 발사 탄의 청록·상승·순서 번호, 열·과열·위험·사격 강조는 의미 있는 상태다. 이 색들을 모두 황동으로 바꾸는 것은 이번 정합성 근거에서 도출되지 않는다.
- **실제 남은 재질 차이:** 전투의 공통 기본 버튼/메뉴·프레임과 카드 받침은 청록 성향의 선과 반복 디더가 강하다. `combat_pixel_skin.gd`는 `StyleBoxTexture`를 반환하며 `console_button_normal.tres → px_slate.png`, `active.tres → px_active.png`의 9분할 원본을 사용한다. 최신 지도·장비의 조용한 StyleBoxFlat 틀과 제작 방식이 다르고, 캡처에서도 이 차이가 보인다. 전투의 청록 전체를 중립 색으로 세지 않고, 다음 발사 선택 등 의미가 있는 청록은 분리했다.
- **정합성 보완 후보:** 전체 색을 통일하기보다, 같은 보조 행동인 메뉴·빌드·일반 버튼과 비활성/빈 받침의 프레임·디더 강도를 먼저 나란히 비교할 수 있다. 다음 발사/열·위험·사격 신호는 보존해야 한다. 이는 현행 UI를 바꾼 결과나 사람 검증이 아니라 이번 소스/이미지 대조의 시각 판단이다.

## 캡처 최신성

전체 해시 대조는 `freshness_evidence.json`과 `freshness_additional.json`, 실제 열어 본 13장 및 현재 소스35개 해시/수정 시각은 `evidence.json`에 있다.

| 대상 | 실제 사용한 캡처와 출처 | 현재 소스와의 관계·한계 |
| --- | --- | --- |
| 지도 | `map_material_2026-11-06/current/region_1_1280x800.png`, `region_1_740x360.png` | validation의 source_sha256 **32/32 일치**. before/after·legacy를 최신 화면으로 사용하지 않았다. |
| 장비 | `equipment_navigation_2026-11-06/1280x800.png`, `1170x540.png` | 이 최신 manifest의 정식 씬/스크립트 **2/2 일치**. 공통 테마도 live manifest와 일치한다. `equipment_live` manifest는 이전 씬/스크립트2개가 현재와 달라 단독으로 최신 근거가 될 수 없음을 확인하고 navigation 캡처로 교체했다. |
| 상점·정비소 | `presentation_integration_2026-11-06/shop.png`, `workshop.png` | 최신 실제 본편 캡처로 채택. validation의 source_after **10/10**, artifact_sha256 **15/15 일치**. 다만 source_after는 전체 UI 의존성 manifest가 아니어서 모든 테마/씬을 이 해시만으로 보증할 수 없다. |
| 처리 후 상태 | `interaction_fx_2026-11-06/purchase_full.png`, `installed.png`, `upgrade.png` | 실제 구매/장착/강화 표시를 보충. source_audit **10/12 일치**이며 이후 바뀐 공통 screen.gd와 pipe_map/screen.gd2개가 다르다. 상점/정비 전용 스크립트는 일치한다. 따라서 이 폴더의 과거 지도를 현행 지도처럼 사용하지 않았다. |
| 보상 | `qa_runtime/presentation_integration_20261106/flow-final/flow_reward.png` | 보고서 flow_integration.json의 capture 목록과 실제 파일을 확인한 최신11월6일 화면. 보상 전용 소스 수정 시각은11월5일로 더 이르다. 전체 보상 씬/자산의 캡처 당시 해시 manifest는 없으므로 완전한 버전 일치는 미증명이다. |
| 결과 | `results_live_2026-11-04/lost_1280x800.png` | 최신 전용 결과 본편 캡처. 현재 결과 씬/스크립트/테마 수정 시각은 이 캡처보다 이르며 원본을 직접 대조했다. 캡처 당시 전용 source hash manifest가 없어 현재 전체 버전의 완전 일치는 미증명이다. |
| 전투 | `presentation_integration_2026-11-06/after.png` | 산출물 해시와 최신 presenter 해시 일치. 이 정지 장면은 입력 잠금 상태이며, 활성 사격 버튼의 모든 상태를 시각 확인했다고 확장하지 않았다. 기능색은 소스로 보충 확인했다. |

추가로 연 `flow-final/flow_won.png`는 정상 복구 직전 화면이다. 결과창이 아니므로 최신 결과 근거에서 제외했다. `workbench_live_2026-11-04`의 오래된 source_hashes는12/20만 일치해 단독 최신 근거로 쓰지 않았다. `shop_actions_2026-11-05`는7/8 일치하며 달라진 상점 스크립트는11월6일 interaction manifest의 현재 해시와 일치한다.

## 이 증거로 말할 수 있는 범위

최신 지도는 장비 선택과 정확히 같은 핵심 색·모서리 언어로 연결되어 있고, 정비소·상점·보상의 아이보리/황동 계열과 공통 글꼴도 이어진다. 남은 차이는 **지도1/2px 경계와 장비의 추가2px 가장자리 빛/그림자**, 그리고 **전투의 중립 조작부 재질과 디더 강도**로 구체화할 수 있다. 결과의 맥락색·상점 CRT·전투 기능색까지 동일화할 근거는 없다. 탐지기의 빈 배열이나 기존 기능 통과 수로 시각 완성·사용자 이해·실기기 품질을 판정할 수 없다.
