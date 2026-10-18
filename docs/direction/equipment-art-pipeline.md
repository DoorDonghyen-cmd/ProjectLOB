# 복장·무기 제작 파이프라인

유지 기준: 2026-10-13. 다음 “복장 추가해 줘”, “무기 추가해 줘” 요청에서 사용하는 제작 진입점이다. 실행 위치는 활성 저장소 루트이며 아래 `res://`는 `새-게임-프로젝트/`를 뜻한다. 현재 구현을 재사용하기 위한 안내로, 도구·해상도·복장 디자인을 영구 고정하지 않는다.

## 바로 시작하는 순서

1. [현재 결정](current.md)과 최신 사용자 요청에서 **시안 / 아트 미리보기 / 본편 적용** 범위를 확인한다. 이미 채택한 디자인은 다시 승인받지 않고 이어서 제작한다. 획득·능력치가 미정이어도 독립적인 아트 제작은 진행한다.
2. [도트 제작 기준](pixel-production.md), 아래 해당 계열의 실제 PNG와 최근 게임 캡처를 연다. 실제 참조 이미지를 생성 도구에 전달한다. 경로를 프롬프트에 쓰는 것으로 대체하지 않는다.
3. 승인 디자인 → 몸체 또는 총기 레이어 제작 → 좌표 등록 → 기존 미리보기/게임 합성 → 해당 QA → 실제 크기 시각 검토 순으로 진행한다.
4. 첫 전달 전에 손·총구·발·가구 접점과 작은 화면의 실루엣을 고친다. 생성 성공이나 테스트 통과만으로 아트 완료라고 하지 않는다.
5. 원본, 전체 프롬프트, 참조 역할, 등록 좌표, 캡처, 남은 범위를 기록한다. 최신 기준이 바뀌면 이 문서의 연결도 갱신한다.

**현행 범위:** 신규 7~10칸 4종은 본편 선택·전투·실내까지 연결됐다. 신규 4종의 테스트용 전체 개방은 2026-10-14 사용자 확정이다. 신규 교환0회는 임시 수치이며 정식 획득은 후속이다. 새 등반 메뉴 기본은4칸이다. [적용 보고서](../qa/reports/outfits_live_2026-10-13.md), [복장 규칙](outfit-bag.md)을 먼저 확인한다.

## 참조와 재사용 원본

| 용도 | 먼저 여는 자료 | 적용 범위 |
|---|---|---|
| 공통 도트풍 | [주인공 색면 v2](../../새-게임-프로젝트/assets/art/actor_cohesion_20261005/reclaimer_grouped_v2.png), [전투 배경](../../새-게임-프로젝트/assets/art/tower_sample_20261003/residential_tower.png), [게임 내 승인 크기](../qa/reports/hero_mass_v2_2026-10-05_assets/after_rest_1280.png) | 큰 색면·묶인 그림자·배경과 비슷한 묘사 밀도. 옛 HUD와 의상 자체를 새 디자인의 고정 조건으로 쓰지 않는다. |
| 신규 복장 디자인 | [콘셉트 폴더](../art/concepts/2026-10-11-outfits/), 특히 [채택 원정복 v3](../art/concepts/2026-10-11-outfits/10_expedition_v3.png) | 밀폐 헬멧·호흡관·올리브 작업복·황토 소매·통합 생존 장치. 앞/뒤 시안과 사용자 참조는 같은 폴더에서 찾는다. |
| 몸체 동작 기준 | [권총 몸체 v2](../../새-게임-프로젝트/assets/art/weapon_motion_20261011/pistol_body_v2.png), [장총 몸체 v2](../../새-게임-프로젝트/assets/art/weapon_motion_20261011/long_body_v2.png) | 손 위치·팔 방향·발 기준점·6키포즈. 교정 전 v1로 돌아가지 않는다. |
| 새 복장 구현 예제 | [원정복 미리보기 자산](../../새-게임-프로젝트/assets/art/outfit_preview_20261011/), [제작 provenance](../../새-게임-프로젝트/assets/art/outfit_preview_20261011/provenance.json) | 권총/장총 몸체 2장, 장소 3장, 원본·참조·전체 프롬프트·등록값. 아직 최종 장갑과 확대 묘사 정리가 남아 있다. |
| 장비 선택용 무기 | [weapons_20261011](../../새-게임-프로젝트/assets/art/weapons_20261011/) | 무기별 형태와 큰 장비 화면의 표현. |
| 전투용 무기 | [weapons_mass_20261013](../../새-게임-프로젝트/assets/art/weapons_mass_20261013/), 쇄도 `burst_v4.png` / 나머지4종 `*_v3.png` | 쇄도는 v4와4단위 무기 레이어를 사용한다. 2026-10-14 사용자가 현재 총기 표현에서 멈추기로 채택했으며 다른 총기에 일괄 확장하지 않는다. v2·기존 쇄도v3·10월11일 원본은 비교 이력이다. |
| 실내 배경·인물 | [service_layers_20261011](../../새-게임-프로젝트/assets/art/service_layers_20261011/), [분리 검증](../qa/reports/service_layers_2026-10-11.md) | 상점·보급·작업대 공통 실내. 외부 탑 풍경 없이 다른 구역에서도 재사용한다. |

실제 도구 가용성과 로컬 명령은 [art_tooling.lock.json](../../tools/art_tooling.lock.json)을 확인한다. 위 폴더의 `provenance*.json`은 성공한 작업의 전체 프롬프트와 입력 역할을 보존한다. 필요한 계열만 읽고 새 디자인에 맞춰 수정한다. 이전 실패 시안을 승인본으로 섞지 않는다.

## 복장 추가

### 1. 디자인과 산출물

- 명칭/ID, 사용자 채택 상태, 앞·뒤 실루엣, 대표 색면, 가방/장치 배치, 적용 범위를 먼저 적는다. 가방 용량은 [복장 규칙](outfit-bag.md)을 따르며 탄창이나 덱 전체 수량과 혼동하지 않는다.
- 현재 방식의 전체 아트 묶음은 **앞·뒤 시안 + 권총형 6키포즈 + 장총형 6키포즈 + 실내 3자세**다. 요청이 시안뿐이면 나머지를 완료로 표시하지 않는다.
- 기계적 개성은 장치의 큰 실루엣으로 표현한다. 모든 표면에 호스·리벳·금속선을 추가해 도트 밀도를 높이지 않는다. 새 복장에 기존 모자를 무조건 복제하지 않는다.

### 2. 전투 몸체 제작과 합성

현재 아틀라스는 1536×1024 RGBA, 512셀의 3열×2행이며 순서는 `idle / aim / recoil / reload_open / reload_seat / cooling`이다. 기존 파일을 편집 참조로 사용해 셀·발·손 위치를 유지한다. 다른 규격이 더 적합하면 등록 코드와 검증을 함께 바꾼다.

- 새 복장을 입힌 **몸체만** 생성한다. 총을 몸체에 구워 넣으면 모든 무기 조합을 다시 그려야 한다.
- 기존 도트 기준과 새 복장 시안은 외형 참조, 기존 몸체 아틀라스는 포즈·좌표 참조로 역할을 분명히 지정한다. 투명 배경을 요청하고 실제 알파를 확인한다.
- [weapon_actor.gd](../../새-게임-프로젝트/redesign/weapon_actor.gd)의 합성 순서는 몸체 → 무기 → 필요한 앞쪽 손가락이다. `body_texture()`, `registered_hands()`, `registered_transform()` 조회 지점을 재사용한다.
- 쇄도는 `weapon_pixel_layer.gd`의 낮은 해상도 무기 레이어를 통해 그린다. 몸체와 앞손은 기존 경로, 무기 회전·부품·열기 색은 같은 격자를 따른다. [4단위/6단위 비교 결과](../qa/reports/weapon_density_2026-10-14.md)를 참조하며 아직 모든 총기의 영구 기준으로 삼지 않는다. `coarse_burst=false`는 기존 경로 비교용이다.
- 미리보기 전용 사례는 [outfit_preview_actor.gd](../../새-게임-프로젝트/redesign/outfit_preview_actor.gd)다. 현재 원정복의 보정은 공용 `weapon_actor.gd`로 옮겼다. 권총 조준의 +28 소스 픽셀 보정은 그 이미지에만 맞는 값이다. 다른 복장에 그대로 복사하지 말고 손을 측정한다.
- 실제 불투명 영역과 손/발 접점을 보고 등록한다. 생성 지시를 따랐을 것이라는 가정으로 좌표를 정하지 않는다. 좌우 팔과 총의 앞뒤 가림을 5무기·6자세에서 비교한다.
- 현재 6키포즈와 절차적 총기 움직임은 연속 프레임 애니메이션 완성본과 구별한다.

### 3. 실내 3자세

상점은 카운터 안쪽 상대와 대화, 보급은 보관함 이용, 압축 작업대는 등을 보이고 작업하는 구도다. 배경과 인물을 분리하여 복장마다 배경을 다시 생성하지 않는다.

- `service_layers_20261011/*_background.png`를 공통 배경으로 유지한다.
- 새 인물 PNG의 불투명 영역을 측정하여 [ServiceActorProfile](../../새-게임-프로젝트/redesign/service_actor_profile.gd)의 `texture / source_rect / foot_in_source`에 등록한다. 샘플은 `outfit_preview_shop.tres`, `outfit_preview_supply.tres`, `outfit_preview_workshop.tres`다.
- [service_actor_layer.gd](../../새-게임-프로젝트/redesign/service_actor_layer.gd)가 배경의 실제 표시 영역에 맞춰 발 위치와 인물 높이를 계산한다. 원본 캔버스 여백 때문에 발이 뜨지 않는지 확인한다.
- 손과 작업대, 발과 바닥, 몸과 카운터가 맞닿는지 작은 화면에서 확인한다. 가구 뒤로 들어가야 하는 새 포즈는 필요할 때 가구 전경 마스크를 따로 만든다.
- 현재 본편 [service_actor_catalog.gd](../../새-게임-프로젝트/redesign/service_actor_catalog.gd)는 `work`와 신규4종의 3자세를 갖는다. `scout/carrier` 등 미등록 복장은 기존 작업복으로 대체한다. 이 대체 표시를 새 복장 제작 완료로 보고하지 않는다.

### 4. 미리보기와 본편 통합 구분

- [OUTFIT_PREVIEW.cmd](../../OUTFIT_PREVIEW.cmd) 또는 메인 메뉴 → 개발자 테스트 → 복장 작업실에서 검토한다.
- 새 시안/탭은 [outfit_preview.gd](../../새-게임-프로젝트/redesign/outfit_preview.gd)와 [outfit_preview.tscn](../../새-게임-프로젝트/redesign/outfit_preview.tscn)에 연결한다. 신규4종은 모두 동작 탭을 열 수 있다. 새 ID의 시안 목록·탭·테스트도 함께 확장한다. 이름만 추가하면 자동 등록되는 구조는 아니다.
- 전투 합성·확대는 [outfit_preview_stage.gd](../../새-게임-프로젝트/redesign/outfit_preview_stage.gd), 의상 몸체는 본편과 같은 `outfit_art.gd` 카탈로그 및 `weapon_actor.gd.set_outfit()`으로 선택하고 실내는 공용 카탈로그의 프로필을 사용한다.
- 본편 적용까지 요청받은 경우에만 `content.gd`의 OUTFITS, 장비 선택, 캠페인/모델의 복장 보존, 전투 몸체 선택, 실내 카탈로그를 연결하고 저장 호환을 확인한다. 미정 획득 방식을 임의로 완성하지 않는다.
- 본편은 `battle_view.gd.sync()`의 `display_state.outfit` → `tower_battle_view.gd` → `weapon_actor.gd.set_outfit()`으로 연결한다. 신규 복장에 맞는 손 보정은 `registered_hands/registered_transform`에 두고 `registered_muzzle`도 같은 변환을 사용한다. `tools/run_outfits_live_checks.ps1`로 저장/용량/본편 렌더/실내/목록 터치 스크롤을 검증한다.

## 무기 추가 또는 외형 교체

### 1. 형태와 모션 계열

현재 계열은 `single` 보행자·`amplifier` 증강이 권총형, `burst` 쇄도·`scatter` 산개·`heavy` 압쇄가 장총형이다. 새 무기가 기존 계열과 접점이 맞으면 몸체 동작을 재사용한다. 새 포즈가 필요한 이유가 있을 때만 몸체를 추가한다.

- 장비 선택용 그림과 전투용 그림을 별도 산출물로 둔다. 전투 그림은 얼굴·몸통을 가리지 않는 크기와 읽히는 총구 실루엣을 우선한다.
- 외곽선을 약하게 하는 것과 도트 밀도를 맞추는 것은 다르다. 사용자 최신 지적은 총기의 가는 검은선이다. 바깥 윤곽은 캐릭터와 비슷한 굵기, 내부는 적은 묘사로 비교한다. [쇄도v4 비교](../qa/reports/burst_contour_2026-10-14.md)는 구현 사례이며 아직 전체 총기 스타일로 확정하지 않았다.
- 현재 생성본은 1536×1024 RGBA이며 총만 오른쪽으로 향한다. 손·팔·탄도·글자·UI가 포함되지 않도록 하고 투명 배경을 사용한다. 새 시점을 쓸 경우 합성 계열도 검토한다.
- 같은 색면·총열·탄창/약실 형태를 유지하되 전투 축소본에서는 불필요한 손잡이·레일·잔선을 정리한다. 장비 그림을 그대로 작게 줄이는 것만으로 검수를 끝내지 않는다.
- 몸체와 합성한 상태에서 총의 내부 경계·밝은 테두리가 유독 촘촘하지 않은지 비교한다. 큰 원화의 단순함만으로 판단하지 않는다. [10월13일 두 차례 편집·전후 검수](../qa/reports/weapon_mass_2026-10-13.md)의 최종 v3를 후속 표현 참조로 사용하되 사용자 체감 미확인 상태를 구분한다.

### 2. 등록 위치

| 연결 | 파일과 확인 항목 |
|---|---|
| 장비 선택 그림 | [equipment_weapon.gd](../../새-게임-프로젝트/redesign/equipment_weapon.gd), [equipment_weapon.tscn](../../새-게임-프로젝트/redesign/equipment_weapon.tscn): 원본, 표시 영역, 축소 품질 |
| 실제 총 합성 | `weapon_actor.gd`: `WEAPONS`의 family/image/grip/muzzle/scale 또는 support/part/release; `KICK_ANGLE`, `HEAT_REGIONS` |
| 전장 발·총구 | [tower_battle_view.gd](../../새-게임-프로젝트/redesign/samples/tower_battle_view.gd): 몸체와 총구가 같은 변환을 따르는지 |
| 열기·타격 표현 | [risk_battle_view.gd](../../새-게임-프로젝트/redesign/samples/risk_battle_view.gd): 실제 총 표면과 연출 상태, 독립된 돌출 도형 유무 |
| 실제 새 무기 규칙 | [content.gd](../../새-게임-프로젝트/redesign/content.gd)의 GUNS 및 모델, [equipment_screen.gd](../../새-게임-프로젝트/redesign/equipment_screen.gd)와 해당 장면의 선택 목록, 무기 ID를 고정 열거한 미리보기·테스트 |

손잡이, 보조 손, 총구, 움직일 부품 영역을 **새 이미지에서** 측정한다. 장총의 기준 크기는 조준 자세의 두 손 간격으로 맞추고 자세마다 크기가 출렁이지 않게 한다. 재장전 부품 분리와 증강의 꺾이는 총열은 현 구현을 참고하되 새 무기의 구조에 맞춰 선택한다.

### 3. 오늘 수정한 문제를 반복하지 않는 검수

- 팔이 과도하게 뻗거나 좌우가 뒤집히지 않는지 몸체만 먼저 본다. 장총이 얼굴과 몸을 가리면 무기 크기·각도·손 접점을 함께 확인한다.
- 일반탄의 `shot_power=0`에서도 기본 반동이 있어야 한다. 상태값이 바뀌는 것뿐 아니라 실제 렌더 차이를 확인한다.
- 재장전은 열기/부품 추출 → 유지 → 삽입/복귀가 보이는지, 뷰포트 갱신 조건에 진행률이 포함되는지 검사한다.
- 앞손 전체를 총 위에 그리면 총열이 끊어진다. 필요한 손가락 부분만 전경으로 합성한다.
- 총과 같이 움직이는 작은 도형이 나타나면 원화를 재생성하기 전에 몸체/총/손/효과 레이어를 분리하고 발열 0과 1을 비교한다. 오늘의 돌출 막대는 원화가 아니라 별도 잔열 사각형이었다. [정정된 원인과 회귀 검증](../qa/reports/weapon_heat_artifact_2026-10-11.md)을 우선한다.
- 총열 열기는 불투명한 실제 금속 영역에 제한하고 총 회전·재장전 변환을 따른다. 냉각 후 원래 픽셀이 복구되는지 확인한다.

## 검증 실행

아래는 활성 저장소 루트에서 실행한다. 런처의 격리 APPDATA/LOCALAPPDATA와 QA 경로를 유지하고 일반 플레이 저장을 검사에 사용하지 않는다. 엔진 위치는 각 런처와 도구 잠금 파일을 확인한다.

| 변경 | 명령 | 확인 대상 |
|---|---|---|
| 복장 미리보기 | `powershell -NoProfile -File tools/run_outfit_preview_checks.ps1` | 시안/탭/5총기·6자세/발사·장전/실내 접지/닫기/본편 상태 불변 |
| 장비 선택용 무기 | `powershell -NoProfile -File tools/run_equipment_checks.ps1` | 선택·그림·모바일 배치 |
| 몸체·무기 합성/모션 | `powershell -NoProfile -File tools/run_actor_motion_checks.ps1` | 실제 반동·재장전·냉각·건너뛰기 |
| 총 표면 열기/합성 공유 변경 | `powershell -NoProfile -File tools/run_weapon_heat_checks.ps1` | 투명도 유지·금속 색 변화·냉각 복구·돌출 회귀 |
| 본편 실내 복장 연결 | `powershell -NoProfile -File tools/run_service_location_checks.ps1` | 배경/배우 분리·접지·요청 복장/대체 구분 |
| 전투 연출 연결 변경 | `powershell -NoProfile -File tools/run_combat_feedback_checks.ps1` | 실제 사건과 화면 반응의 정합성 |
| 새 무기 규칙 연결 | `powershell -NoProfile -File tools/run_weapon_checks.ps1 -Mode rules` 및 `-Mode ui` | 규칙·UI 회귀. 아트 교체만이면 규칙을 임의 변경하지 않는다. |

현재 검수 화면 크기는 1280×900, 1008×630, 1440×630이다. 실제 표시 크기로 전장·장비 화면·실내를 보고, 확대 그림은 접점 확인에만 보조적으로 쓴다. 새 ID 추가 시 검사에 그 ID가 실제 포함되는지도 확인한다. 고정된 검사 수를 성공 조건으로 복사하지 않는다.

레이어 진단 도구는 [weapon_layer_inspector.gd](../../새-게임-프로젝트/tests/weapon_layer_inspector.gd), 포즈 비교는 [weapon_pose_preview.gd](../../새-게임-프로젝트/tests/weapon_pose_preview.gd)다. 실행 전 각각의 QA 출력 경로/환경 요구를 읽는다. 기능 통과, 제작자의 시각 확인, 사용자의 체감 승인, Galaxy 실기기는 별도 결과로 남긴다.

## 제작 기록과 완료 조건

새 폴더/버전을 사용하여 승인 원본을 보존한다. 각 자산 폴더의 `provenance.json`에는 아래를 남긴다. 과거 생성 도구가 현재도 연결돼 있다고 가정하지 않는다.

- 자산 ID·버전·용도·채택 상태·본편/미리보기 적용 상태.
- 도구, 전체 프롬프트, 입력 참조별 경로/역할/SHA256, 생성 원본 위치.
- 프로젝트 파일 경로/SHA256/실제 크기/알파, 아틀라스 셀 순서와 등록 영역/손·총구·발 좌표.
- 연결된 장면/코드, 실행한 검증과 캡처, 사용자 확인 여부, 알려진 한계.

제작 결과는 [자산 목록](art-assets.md)에, 현재 결정은 해당 방향 문서에, 작업·실패 원인·검증 증거는 `docs/history/`와 `docs/qa/reports/`에 둔다. 역할 스킬에는 이 절차의 연결만 유지한다.

**완료 보고:** 무엇을 새로 만들었는지, 어디서 볼 수 있는지, 실제 착용까지 되는지, 어떤 검증을 했는지, 무엇이 아직 미완성인지를 구분한다. APK·커밋·푸시·외부 게시를 이 제작 절차만으로 자동 실행하지 않는다.

### 기준 사례

- [무기 디자인](../qa/reports/weapon_art_2026-10-11.md) → [팔·총기 크기·모션 교정](../qa/reports/weapon_motion_2026-10-11.md) → [총구 가독성](../qa/reports/weapon_readability_2026-10-11.md) → [돌출 효과 원인 정정](../qa/reports/weapon_heat_artifact_2026-10-11.md).
- [실내 레이어 분리](../qa/reports/service_layers_2026-10-11.md) → [원정복 아트·미리보기](../qa/reports/outfit_preview_2026-10-11.md).
- 과거 보고서는 근거다. 충돌 시 최신 사용자 결정과 원인 정정, 실제 코드 순으로 상태를 확인하며 오래된 “완료/후속” 문장을 그대로 재사용하지 않는다.

신규 방열복·인양·회수 전체 프롬프트와 실제 원본은 [본편 복장 provenance](../../새-게임-프로젝트/assets/art/outfits_live_20261013/provenance.json)에 있다. 인양 대기 자세의 잘못된 팔을 교정한 v2가 최종이다.
