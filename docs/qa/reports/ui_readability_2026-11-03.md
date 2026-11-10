# 공통 UI 글꼴·배율 수정 — PC와 Galaxy S26 기준

2026-11-03. 사용자 실행 승인 및 사용 기기 Galaxy S26 반영. **본편 적용·PC 렌더/입력 검사 완료. Galaxy S26 실기기 검증은 미실행.**

## 변경 결과

- 상점의 1600×900 Canvas 전체 축소를 제거했다. 비전투 화면에 native 픽셀과 정수 확대를 적용해, 작은 창에서 글자까지 함께 줄어들던 문제를 고쳤다. 지도·사건·공방·보급소·빌드 작업실·덱·설정·시작/장비 선택·보상·관문이 같은 기준을 쓴다.
- NeoDunggeunmoPro의 16단위 글자 원형에 맞춰 비전투 본문·버튼은 최소16, 큰 제목/수치는32단계로 정리했다. 창이 좁으면 배치/줄바꿈/세로 스크롤로 수용한다. 카드 직접 그리기는16보다 작게 줄이지 않고 필요한 경우 말줄임하고 상세에서 전체 내용을 제공한다. 라이브 전투 HUD의 기존 크기/배치는 유지했다.
- 기본 글꼴에 없는 화살표·마이너스·이전/다음 기호·장소 기호를 프로젝트 자체16격자 보조 글꼴로 동봉했다. 한글 폰트 원본은 변경하지 않았다. 공통 FontVariation의 명시적 fallback을 사용한다([Godot Font 문서](https://docs.godotengine.org/en/stable/classes/class_font.html)).
- 상점 선택 정보는 좁은 창에서 상품 아래로 이동한다. 상세/가방 창은 화면에 고정하고 내용만 스크롤하며, **돌아가기·다음 목록 버튼은 항상 보인다.** 장비 선택의 가로 넘침도 수정했다.
- Android에서 얻은 안전 영역을 비전투 페이지·작업실·상세 창의 여백에 반영한다. 실제 카메라 홀/내비게이션 영역 값은 아직 기기에서 측정하지 않았다.
- 게임 규칙·가격·보상·전투 계산·저장 형식은 변경하지 않았다. 시작 전 스냅샷과 model/campaign/content/campaign_content/route_map 파일이 동일하다. 이번 기존 제품 수정11파일의 [차이](ui_readability_2026-11-03/presentation_changes.patch)와 [해시](ui_readability_2026-11-03/sources.json)를 보존했다.

## Galaxy S26 기준

사용자가 말한 기기를 일반 S26으로 해석했다. 공식 사양은2340×1080이다([Samsung 공식 사양](https://www.samsung.com/sec/smartphones/galaxy-s26/specs/)). 본편을 PC에서 해당 가로 해상도로 렌더했고 비전투 UI는2배, 논리1170×540으로 표시된다. 2160×1032도 가용 영역이 줄어든 보조 크기로 검사했으며 **실제 S26 안전 영역 측정값은 아니다.**

화면 검사와 별도로 안전 영역 좌표 변환을 입력2340×1080, 안전Rect(96,0,2160,1032), 배율2 → 논리Rect(48,0,1080,516)으로 검증했다. 이는 계산 확인이며 Android 통합 통과를 의미하지 않는다.

| 화면/창 | 수정 전 최소 보조 글자 | 수정 후 최소 보조 글자 |
| --- | ---: | ---: |
| 상점1008×630 | 약10.08px | 16px |
| 지도1008×630 | 약9.45px | 16px |
| 상점·공방2340×1080 | 이번 수정 전 미측정 | 32물리px(논리16×2) |

실측은 화면의 Label/Button/RichTextLabel 변환 기준이다. 카드 직접 그리기는 별도 시각 확인했다. [전체105화면 측정값](ui_readability_2026-11-03/metrics.json).

## 실제 화면

| 구간 | PC/작은 창 | S26 해상도 PC 렌더 |
| --- | --- | --- |
| 상점 | [1280×800](ui_readability_2026-11-03/shop_1280x800.png), [1008×630](ui_readability_2026-11-03/shop_1008x630.png) | [2340×1080](ui_readability_2026-11-03/shop_2340x1080.png) |
| 상세·가방 | [844×390 상세](ui_readability_2026-11-03/shop_detail_844x390.png) | [상세](ui_readability_2026-11-03/shop_detail_2340x1080.png), [가방](ui_readability_2026-11-03/shop_bag_2340x1080.png) |
| 지도 | [1008×630](ui_readability_2026-11-03/map_1008x630.png) | [2340×1080](ui_readability_2026-11-03/map_2340x1080.png) |
| 공방·보급 | [공방844×390](ui_readability_2026-11-03/workshop_844x390.png), [보급1008×630](ui_readability_2026-11-03/supply_1008x630.png) | [공방](ui_readability_2026-11-03/workshop_2340x1080.png) |
| 빌드·장비 | [빌드844×390](ui_readability_2026-11-03/parts_844x390.png), [덱1008×630](ui_readability_2026-11-03/ammo_1008x630.png) | [장비 선택](ui_readability_2026-11-03/preparation_2340x1080.png) |
| 기타 | [설정](ui_readability_2026-11-03/settings_844x390.png), [사건](ui_readability_2026-11-03/event_844x390.png), [관문 정비](ui_readability_2026-11-03/gate_service_1008x630.png) | [탄환 보상](ui_readability_2026-11-03/reward_ammo_2340x1080.png), [기존 전투](ui_readability_2026-11-03/combat_2340x1080.png) |

캡처는 실제 입력 뒤의 스크롤 위치를 그대로 담는다. 화면 상단/하단 일부가 보이지 않는 이미지는 세로 스크롤 중인 상태다. 상점·상세/가방·지도·작업실·장비·설정·보상·공방·관문 대표 캡처를 직접 확인했다. 모든105장과 모든 후반 문구의 미감 확인을 주장하지 않는다. 수정 전 증거는 [이전 보고서](place_font_audit_2026-11-03.md)에 보존했다.

## 검사 결과

Windows/Godot4.7 GL Compatibility에서 격리 APPDATA/LOCALAPPDATA로 실행했다. 사용자 저장에는 접근하지 않았다.

| 검사 | 결과 | 확인 범위 |
| --- | ---: | --- |
| run_ui_readability.ps1 -Label final3 | 9,734 / 실패0 | 21화면×5크기, 글꼴/기호/가로 넘침, 상세 닫기, 구매·자동 저장, 실제 리사이즈, 지도→전투→메뉴→이어하기 |
| run_line_world_checks.ps1 -Mode shop | 2,264 / 실패0 | 구매·교체·품절·잔액·자동 저장·모든 파츠 상세·5구역·복장·큰 글씨 설정,1008/S26 크기 터치 드래그 |
| run_line_world_checks.ps1 -Mode map | 654 / 실패0 | 기존 지도/장소 조작 회귀 |
| run_focus_build.ps1 -Mode ui -Label readability | 74 / 실패0 | 공개 보상 선택·효과/화면 전환·저장 회귀 |
| run_prototype_hud.ps1 -Mode ui -Fast | 11,536 / 실패0 | 기존 전투 HUD 조작 회귀 |

[공통 UI 로그](ui_readability_2026-11-03/stdout.log) · [상점](ui_readability_2026-11-03/shop_stdout.log) · [지도](ui_readability_2026-11-03/map_stdout.log) · [보상](ui_readability_2026-11-03/reward_stdout.log) · [HUD](ui_readability_2026-11-03/hud_stdout.log).

상점/전투/관문은 앞선 실제 획득 등반 저장을 복원했다. 사건·장소는 현재 합법 경로를 따르는 표시용 fixture, 보상은 적 종료 상태를 설정한 fixture다. 후자는 사람의 전투 승리 증거가 아니다. 모든 캡처 원본과 초기 실패는 `qa_runtime/ui_readability_20261103/`에 보존한다.

진행 중 장비 선택에 가로 넘침2건을 발견해 최소 폭을 수정했다. 새 전환 검사의 초기5건은 fixture가 구형 전투 모드로 시작한 오류를 수정했다. 이전 상점 검사의2건은 글자가 줄바꿈 없이 들어가 더 이상 이야기 영역이 넘치지 않는 상태를 실패로 간주한 검사였다. 이야기 전체가 보이면 그 조건을 확인하고 실제 넘치는 상점 페이지를 손가락 드래그로 검사하도록 바꿨다. 최종 동작·상태 불변 검사는 통과했다. Windows PowerShell의 UTF-8 한글 경로 해석 오류는 런너에서 project.godot 탐색으로 수정했다.

## 남은 확인

- 실제 Galaxy S26의 Android 화면 배율/글꼴 설정, 카메라 홀·제스처 내비게이션·앱 복귀, 손가락 편의와 장시간 발열/프레임은 미검증이다.
- Windows 디스플레이 DPI 조합, 엔딩/모든 이전 저장 창·긴 문자열 조합은 이번 대표 검수 범위 밖이다.
- 큰 글씨 설정은 도트16단계로 반올림되므로110%에서 모든16px 본문이 커지는 것은 아니다. 연속 배율 확대와 도트 획 균일함을 함께 보장하는 접근성 옵션은 별도 설계가 필요하다.
- APK·커밋·푸시·외부 업로드는 수행하지 않았다. 본편은 기존 `PLAY.cmd`로 실행한다.
