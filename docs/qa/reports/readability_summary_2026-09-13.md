# 탄환 정보·단계 학습 통합 QA

## 빌드와 범위

Session `codex0913-ammo-readability`. `prototype/core-redesign`의 기준 `06fdd46` 위 변경분, Godot 4.7 stable Windows. [차터](../readability_charter_2026-09-13.md)의 기능 집중·전체 회귀·독립 정적 화면 검토를 수행했다. 최종 제품 파일은 [SHA256 목록](readability_sources_2026-09-13.json)에 기록했다. QA 전용 APPDATA만 사용했으며 APK는 만들거나 갱신하지 않았다.

학습/일반 × 두 총기의 seed731042 및 0~3 실제 캠페인, 학습 보상 유지/제거 정책, 독립 정산 사례, 합성 터치와 UI 버튼 재생을 분리했다. 최종 레이아웃 뒤 추가 수정은 계산 글자색과 개발자 연습 숏컷, 처음 강화 보상의 단계에 맞는 설명이었다. 최종 합성 터치와 내보내기를 재실행했다. 독립 모델 검증 뒤 콘텐츠 수정은 조사 오기 3곳뿐이며 전투 수치/편성은 바뀌지 않았다.

## 결과

| 검사 | 결과 | 근거/경계 |
| --- | --- | --- |
| 독립 전투 | 5,177 통과, 실패 0 | [원문](readability_combat_2026-09-13.md), [JSON](readability_combat_2026-09-13.json). 실제 피해 근거/포맷, 기존 v2 정산17사례, 지급·복원. |
| 독립 캠페인 | 24/24 완주, 23,046 assertions 통과, 2,416 실제명령 거절0 | [원문](readability_campaign_2026-09-13.md), [JSON](readability_campaign_2026-09-13.json). 168 저장왕복, 구 v2 저장10. 일반10경로 이전 결과와 일치. |
| UI 전체 재생 | 4/4 완주, 1,457 통과, 442 버튼 | [UI 원본](readability_ui_2026-09-13.json), [재생 입력](readability_ui_source_2026-09-13.json). 실제 버튼 signal, 저장 재개, 상태/전체이력 대조. 물리 터치 검사와 구별. |
| PC 합성 터치 | 106 통과, 실패0 | [원본](readability_visual_2026-09-13.json). 장전·검사/회수·사격·재개·숏컷, 1280×800/1920×864 버튼 경계. 후반5칸은 명시적 레이아웃 fixture. |
| 기존 전체 회귀 | 3,730 통과, 실패0, 기존 경보3 | `qa_runtime/redesign/regression/{summary.json,stdout.log,stderr.log}`. 기존 `sentry_drone` HP, `nano_stalker` EVA/HP 밴드 경보 유지. |
| 독립 화면 | 24장 사본/해시 보존, 주요 버튼 잘림 미발견 | [원문](readability_experience_2026-09-13.md), [manifest](readability_experience_2026-09-13_assets/manifest.csv). 공개 PNG와 조작설명만 사용. |
| Windows 내보내기 | 완료, exported exe headless 기동 통과 | 아래 파일과 manifest. Godot의 인증서 저장소 접근 경고는 제품 파싱/스크립트 실패와 구별했고 실행은 정상 종료. |

## 수정·재검증

- **READ-01 / Verified:** 학습 최소덱2장인데 실제 제거 조건에 고정6이 남아 덱5장 제거가 거절됐다. 최소덱 조회를 통일했다. 130개 제거 probe와 제거 정책 두 캠페인 통과.
- **READ-02 / Verified:** 5칸 복합 전투의 긴 계산문구가 확정 버튼을 밀어냈다. 탄환 설명과 계산을 공용 영역에 배치한 뒤 두 해상도 경계/터치 및 UI 전체 경로 통과.
- **INFRA:** 처음 저장재개 검사의 raw JSON 문자열 비교는 숫자의 int/float 표현 차이로 실패했다. 양쪽 JSON정규화로 전체 상태를 비교해 통과했으며 필드 제외는 없다. 별도 제품 저장 결함으로 집계하지 않았다.
- 조사 오기 `강화과/강화으로/강화은`을 정정했다. 별도 기능 결함과 혼합하지 않았다.

재현과 수정은 [버그 기록](../../../.agents/skills/05-bug-report/reports/bug_readability_course_remove_and_layout.md)에 남겼다. 기존 이슈의 상태를 이번 화면 검사만으로 일괄 닫지 않았다.

## 판단과 다음 확인

기능 범위는 PASS다. 공개 화면에서 카드 간 수치 비교, 선택 발의 강화/장갑/스침/HP상한 근거, 검사 모드의 밝은 배경과 슬롯 테두리를 확인했다. 최종 화면에서 진행을 막는 잘림을 발견하지 못했다.

정적 관찰에서 남은 가설은 **계산 보기 활성 상태를 보고 회수와 검사 모드의 차이를 사람이 이해하는가**, **후반 여러 카드와 긴 계산근거의 읽기 부담이 어느 정도인가**다. 비활성 카드 대비의 장시간 가독성도 사람 확인 대상이다. 자동 검사의 수와 탐색 완주를 독립 시나리오 수·사람 승률·재미 점수로 해석하지 않는다. 갤럭시 실행/물리 터치/발열/인간 학습성은 이번에 검증하지 않았다.

## Windows 산출물

- 실행: `builds/readability-windows/Play-Readability.cmd`.
- EXE: `LastOnBoard-readability.exe`, **126,686,136 bytes**.
- SHA256: `8AED249396EF192D8D723B77BC8BE3D9738111788F01665CEDEAB422FB8CD478`.
- `build_manifest.json`에는 기준 `06fdd46`, 작업 트리 포함, 내보내기 시각과 기동 결과를 기록했다. 최종 코드 해시 목록을 함께 사용한다.
- 저장은 해당 폴더 `qa-profile`, 이전 Windows 비교판과 APK 보존. 재생성 `tools/export_windows_readability.ps1`.
