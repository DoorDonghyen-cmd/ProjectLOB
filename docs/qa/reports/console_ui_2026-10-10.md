# 참조 기반 공통 도트 UI 적용

## 범위와 판단

사용자는 CraftPix, Pinterest, 상점 카드 이미지를 참고한 개편을 승인했다. 카드 섹션·카드·행동 버튼을 함께 다듬는 방향을 구현했다. 새 외형의 미감은 사용자 확인 전이다. 전투의 배치·규칙·탄환 그림·배우·배경·저장 데이터는 유지한다. 상점의 선택→비교→구매와 파츠 교체 흐름도 유지한다.

전투: 낮은 채도의 밝은 데이터 면, 어두운 이름 띠와 효과 띠, 탄환 그림의 홈으로 카드의 반복 비교 위치를 구분한다. 탄창 빈 홈과 장전된 판은 서로 다른 자원이며 발열은 읽는 면과 눈금 채널을 한 계기로 묶는다. 발사/재장전은 두께가 있는 키와 의미별 색을 갖는다. 보조 버튼도 같은 단면을 사용하되 더 어둡다. focus는 투명 모서리만 덧그려 pressed 깊이를 가리지 않는다.

다른 화면: 탄환 가방과 상점 탄환에도 같은 카드가 적용된다. 파츠는 어두운 장치 판, 빈 칸은 홈으로 구별한다. 장착된 파츠 전체에 선택 모서리를 사용하지 않으며 현재 비교 대상을 별도 표시한다. 파츠의 등급/코어/패널티는 유지한다. 메인·무기 선택·맵은 공통 버튼과 일부 공통 패널을 교체했으며 화면 고유 그림/배치를 새로 제작한 것은 아니다. 작은 화면의 파츠 `규칙` 버튼 폭을 보완했다.

## 제작과 씬

- 원본 참조: [상점 카드](../../art/style-reference/shop-card-ui-study.md), [CraftPix](../../art/style-reference/craftpix-ui-study.md), [Pinterest](../../art/style-reference/pinterest-ui-study.md). 원본 이미지의 픽셀·폰트·아이콘은 게임 자산에 복제하지 않았다.
- `tools/build_console_ui.py`: 직접 구성한 사각 픽셀 도형을 SVG/StyleBoxTexture로 저장한다. 32×32 원본, 보호 여백10px, 9종×6상태. 상태별 파일은 `assets/ui/console/`에 있으며 `provenance.json`에 제작 경로를 남겼다. 생성형 이미지나 외부 유료 자산은 사용하지 않았다.
- `combat_pixel_skin.gd`는 공용 리소스를 불러온다. `combat_workbench.tscn`에 공용 표면과 대표 카드 스타일을 직렬화했다. [실행 전 구성](console_ui_2026-10-10_assets/scene_before_ready.png)은 스타일과 배치 확인용이며 전장/탄환 그림 및 동적 발열의 완전한 편집기 재현은 아니다.
- `combat_surface.gd`, `ammo_card_view.gd`, `magazine_view.gd`, `heat_gauge.gd`, `ammo_bag_view.gd`, `part_card_view.gd`, `campaign_ui.gd`, `screen.gd`에서 역할별로 연결했다. 기존 절차적 화면 전체를 씬으로 다시 이전하는 작업은 이번 범위에 포함하지 않았다.
- Godot MCP `get_project_info` 정상, Godot4.7 확인. 파일 편집과 기존 로컬 Godot 렌더 검증 경로를 사용했다.

## 화면

[전투 이전](combat_visual_polish_2026-10-10_assets/insertion_1280.png) · [전투 적용](console_ui_2026-10-10_assets/insertion_1280.png) · [과열 계획](console_ui_2026-10-10_assets/planned_1008.png) · [냉각](console_ui_2026-10-10_assets/cooling_1008.png)

[상점](console_ui_2026-10-10_assets/shop_1008.png) · [구매 후](console_ui_2026-10-10_assets/shop_bought_1008.png) · [파츠](console_ui_2026-10-10_assets/parts_1008.png) · [탄환 가방](console_ui_2026-10-10_assets/bag_1008.png)

[메인](console_ui_2026-10-10_assets/title_1008.png) · [무기 선택](console_ui_2026-10-10_assets/weapons_1008.png) · [맵](console_ui_2026-10-10_assets/map_1008.png)

## 검증 상태

- 전투 기존 검사 `run_combat_affordance_checks.ps1`: **340검사/0실패**, 장전/확정/발사/냉각 및 상태 전환의 고정 배치, 1008×630·1280×900·1440×630. [로그](console_ui_2026-10-10_assets/combat.log).
- 가방 기존 검사 `run_ammo_bag_checks.ps1`: **618검사/0실패**, 같은 세 비율에서 구역 수량·탭·상세·닫기·포커스 복귀·모델 불변. [로그](console_ui_2026-10-10_assets/bag.log).
- 메인/무기 기존 검사 `run_director_ui_checks.ps1 -Mode frontend`: **33검사/0실패**. [로그](console_ui_2026-10-10_assets/frontend.log).
- 공통 UI 적용에 대한 `run_console_visual_checks.ps1`: **51검사/0실패**, 실제 상점 구매 금액과 중복 구매 거절, 파츠 교체, 메인/무기/맵/상점/파츠 캡처, 1008×630·1280×800. [로그](console_ui_2026-10-10_assets/console.log).
- 기존 `interaction_flow_runner`는 이전에 삭제한 `undo`를 요구해 실패했다. 수정 UI의 회귀 증거로 사용할 수 없어 중단했으며 통과로 집계하지 않는다. 현재 구매/교체 경로는 위 전용 검사로 확인했다.
- 초기 파츠 스크립트의 `Skin` 상수명이 Godot 기본 클래스와 충돌해 `PixelSkin`으로 수정했다. 후속 import/런타임의 스크립트 오류는 없음. import 시 로컬 Android build-tools 경고가 있으나 APK 작업은 하지 않았다.
- 직접 연 화면: 전투1280/과열1008, 상점1008, 파츠1008, 가방1008, 무기1008, 맵1008, 메인1280, 실행 전 구성. 디렉터 시각 확인과 자동 기능 검사는 별개다. 실제 Galaxy 판독성과 사용자의 미감은 후속 확인이며 출시 비주얼 완료로 선언하지 않는다.

테스트는 모두 격리 저장을 사용했다. APK·커밋·푸시는 수행하지 않았다.
