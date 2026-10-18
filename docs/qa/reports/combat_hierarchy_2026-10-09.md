# 전투 정보 위계와 발열·냉각

2026-10-09 · 사용자 요청: 불필요한 상시 정보를 줄이고 발열·재장전 냉각을 핵심 판단으로 드러낸다.

## 적용

빈 상태에는 전장·탄환·발열·재장전이 중심이다. 장전 시 순서 편집/예상 결과를 드러내고 확정하면 발사 행동에 집중한다. 전장 상시 설명·반복 조합 안내·빈 결과 상자·별도 하단 예비탄 행을 제거했다. 무기 이름은 상세 버튼, 턴/적/재화는 빌드 상세, 기존 공개 다음2장은 탄환 가방의 뽑을 탄 탭으로 이동했다.

큰 열 게이지에 현재/한계 및 사격 중 최고 열을 표시한다. 재장전 버튼은 냉각량·현재→이후 열·적 경과 턴을 보여 준다. 과열 경고는 확정/발사 옆에 두고 사격 중단·강제 재장전 비용을 알린다. 무작위 과열은 확률, 교전 종료는 재장전 없음으로 구분한다. 전투 규칙·수치·저장 형식은 변경하지 않았다.

## 검증

격리 저장과 save_enabled=false로 실제 Godot 입력·모델 결과를 확인했다. 1008×630 / 1280×900 / 1440×630.

- `tools/run_combat_hierarchy_checks.ps1`: 473검사/0실패. 빈 탄창/장전/확정/사격, 실제 냉각·적 경과 턴, 과열 사격 중단과 강제3턴, 산개50% 위험, 마지막 적 처치, 현재 재장전 접촉 위험, 증강 이번/전체 예측, 화면 경계 및 가방으로 이동한 다음2장 확인.
- `tools/run_ammo_cycle_checks.ps1 -Mode ui`: 341검사/0실패. 기존 개별 카드·장전/회수·LIFO·교환·재장전·10장 페이지 유지.
- `tools/run_ammo_bag_checks.ps1`: 618검사/0실패. 카드 집계·임시 압축·전체 분류·무소모 열람·닫기·스크롤 유지.

초기 검사에서 작은 화면의 과열 경고가 카드 하단을 밀어내는 문제와 같은 다음 탄2장의 UI 이름 중복을 발견했다. 가변 전장 높이와 고유 UI 이름으로 수정했다. 최종 캡처에서 작은 화면의 현재 열/예측 최고 열/냉각 및 과열·확률·접촉 위험의 시각 배치를 확인했다.

[장전 전](combat_hierarchy_2026-10-09_assets/empty_1008.png) · [과열 장전](combat_hierarchy_2026-10-09_assets/overheat_plan_1008.png) · [발사 직전](combat_hierarchy_2026-10-09_assets/overheat_ready_1008.png) · [확률 위험](combat_hierarchy_2026-10-09_assets/random_1008.png) · [재장전 위험](combat_hierarchy_2026-10-09_assets/reload_risk_1008.png) · [증강 전체 예측](combat_hierarchy_2026-10-09_assets/amplifier_full_1008.png)

[UI 로그](combat_hierarchy_2026-10-09_assets/stdout.log) · [전투 회귀](combat_hierarchy_2026-10-09_assets/cycle_regression.log) · [가방 회귀](combat_hierarchy_2026-10-09_assets/bag_regression.log)

사람이 빠르게 이해하는지는 사용자 플레이 확인이 필요하다. Galaxy 실기기·새 APK 검증은 수행하지 않았다. APK/커밋/푸시/외부 게시 없음.


## 후속 수정 — 장전 시 화면 높이 변화

사용자가 장전하면 화면이 세로로 늘어난다고 보고했다. 기존 검증은 화면 안 배치만 확인했으며 상태 사이의 위치/높이 변화는 확인하지 않았다. 재현 검사에서 첫 장전 시 편집행25→40px, 결과행 추가로 손패가14~45px 이동하고 전장 높이가31px 줄어드는 경우를 확인했다.

편집 헤더40px·예측행40px와 손패 헤더44px를 유지하고, 과열 경고에는 현재 글꼴 기준 두 줄 공간을 확보했다. 정보만 조건부로 드러내며 빈 결과 박스/안내는 되살리지 않는다. 전장·발사 순서·발열·손패의 영역 크기가 장전/회수/확정/과열 경고/예측 범위 전환에 따라 달라지지 않게 했다. 창 크기 변경에 대한 반응형 조절은 유지한다.

`tools/run_combat_hierarchy_checks.ps1`: **662검사/0실패**. 기존3해상도에서 첫 장전·마지막 회수·과열 장전·확정·강제 재장전·증강 예측 전환의6개 영역 위치/높이를 비교했다(허용1논리px). 스크롤/잘림 및 실제 냉각·사격 기능도 통과. 최종 장전 전/후 캡처를 직접 비교했다. 사람 체감/Galaxy는 후속이다.

[장전 전](combat_hierarchy_2026-10-09_assets/stable_empty_1008.png) · [첫 장전 후](combat_hierarchy_2026-10-09_assets/stable_first_load_1008.png) · [과열 경고](combat_hierarchy_2026-10-09_assets/stable_overheat_plan_1008.png) · [검증 로그](combat_hierarchy_2026-10-09_assets/stability.log) · [수정 전 재현](combat_hierarchy_2026-10-09_assets/stability_before.log)

추가 전투 UI 회귀 `tools/run_ammo_cycle_checks.ps1 -Mode ui`: **341검사/0실패**. 기존 사격·LIFO·교환·일반 재장전·10장 페이지 확인. [로그](combat_hierarchy_2026-10-09_assets/stability_cycle.log).
