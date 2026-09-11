# Core Redesign — 실제 전체 UI 캠페인 독립 QA

최종 판정: **PASS — 493 checks, 실패 0, 214개 UI 버튼 입력, 2개 전체 캠페인 완료.**

## 입력 계약과 독립성

- QA 모드: 기능 집중. `15-gameplay-qa-lead`의 기능/인프라/경험 판정 경계를 적용했다.
- 대상: `D:/ProjectLoB/worktrees/core-redesign`, `prototype/core-redesign`, HEAD `f5da527d76becdc54834b92dc45a99a317a7c70a`의 dirty 개발 트리.
- 최종 실행: 2026-09-11 16:48 KST, Godot 4.7 stable / OpenGL compatibility / 1280×800 / NVIDIA RTX 4060 Ti.
- 세션: `core-redesign-campaign-ui-final-retry`.
- 신규 격리 프로필: `qa_runtime/redesign/campaign_ui/final_retry/{Roaming,Local}`. 제품의 `save_enabled=true`로 이 프로필의 자동 저장만 사용했다. 원본 게임/사용자 진행에는 접근하지 않았다.
- 프로필: 단발 `single`, 일제 `burst`, 각 seed `731042`. 탐색기가 남긴 실제 합법 행동 경로를 그대로 재생하는 기능 테스트다.
- 입력 원본: `qa_runtime/redesign/campaign/Roaming/Godot/app_userdata/Last on Board - Core Redesign/redesign_campaign_report.json`의 `paths` 및 보상 선택 `history`. 다른 QA의 통과 판정을 테스트의 근거로 사용하지 않았다.
- 허용된 기존 기능 결함: 없음. 최초 실행의 비교 오류는 아래에 INFRA로 분리했다.
- QA가 변경한 파일은 `tests/redesign_ui_campaign_runner.gd`와 이 보고서뿐이다. 제품 소스/적/전투 상태/보상 수치는 수정하지 않았다.

첫 직접 GUI 도구 호출은 승인 대기 중 중단되어 실행되지 않았다. 이후 부모 에이전트가 승인된 `tools/run_redesign_checks.ps1 -Mode ui_campaign` 경로로 이 독립 하네스를 실행했다. 원본 JSON·stderr·실제 스크린샷 검토와 판정은 이 QA가 수행했다.

## 실행 결과

| 총기 | 완료 교전 | 턴 | 발사 탄환 | 재장전 | UI 버튼 입력 | 실제 history 항목 |
|---|---:|---:|---:|---:|---:|---:|
| single | 7 / 7 | 42 | 36 | 6 | 110 | 68 |
| burst | 7 / 7 | 39 | 51 | 8 | 104 | 51 |

검증한 실제 경로:

1. 메뉴 시드 입력 → 해당 총기 시작 버튼.
2. 매 프레임 갱신되는 실제 `Button`에서 `load_ID` → `confirm` → `fire` 및 `reload` 실행.
3. 각 교전 후 실제 `reward_ID` 선택, 총 7교전 진행.
4. 두 총기 모두 4번째 교전의 장전 확정 상태에서 자동 저장 → 메뉴 → 화면과 모델 인스턴스 폐기 → 새 화면의 **이어 하기** 버튼 실행. 저장 전후 전체 상태를 JSON 숫자형 정규화 후 대조해 일치 확인.
5. 최종 적 전원의 HP 0, 실제 `won` 상태 확인. 턴·발사수와 전체 행동 history가 입력 원본에 일치.
6. **같은 시드로 다시 설계** 버튼 → 같은 총기·시드, 첫 교전·0턴·계획 상태 확인 → 메뉴 버튼 복귀.

모든 버튼에서 존재·활성·트리 가시성을 확인했고, 각 버튼 이후 자동 저장 오류가 없는지 검사했다. 493 checks는 이 assertion과 캡처 검사의 합계이며 493개의 독립 시나리오를 의미하지 않는다. 최종 `stderr.log`는 비어 있다.

**강제 승리, 적 스탯 변경, 개발자 순간 이동, 전투 상태 주입을 사용하지 않았다.** 기존 경로를 알고 재생하는 자동 기능 QA이므로 사람의 승률·발견 난이도·반복 플레이 재미를 입증하지는 않는다. 포인터 좌표 클릭 대신 실제 UI `Button.pressed` 신호로 연결된 제품 콜백을 실행했다.

## 원본 증거와 실제 캡처

최종 artifact 공통 경로:

`qa_runtime/redesign/campaign_ui/final_retry/Roaming/Godot/app_userdata/Last on Board - Core Redesign/`

- `redesign_ui_campaign_report.json`: 전체 체크, 각 버튼 전후 상태, 두 최종 history, 스크린샷 목록.
- `single_04_ready_actual.{png,json}`: 단발 4번째 교전 실제 장전 완료 상태.
- `burst_04_ready_actual.{png,json}`: 일제 4번째 교전 실제 장전 완료 상태.
- `single_07_won_actual.{png,json}`: 단발 실제 최종 승리 42턴/36발/재장전 6회.
- `burst_07_won_actual.{png,json}`: 일제 실제 최종 승리 39턴/51발/재장전 8회.

4개의 PNG를 직접 열어 검토했다. 모두 수평 잘림 없이 표시됐고, 중반 두 화면에서 적 수치·발사 순서·첫 발 예측·발사와 재장전 버튼을 확인했다. 일제 중반은 설명이 길어 하단 피드백이 세로 스크롤 아래로 내려가지만 발사·재장전 버튼은 화면에 보인다. 두 최종 승리 화면은 실제 기록과 7/7 표기가 일치하며 재시도 버튼이 표시된다. 이번 범위에서 진행을 막는 시각 결함은 발견하지 못했다.

## 최초 실행의 인프라 오류

`campaign_ui/final` 원본은 73 checks / 1 failure / 29개 UI 버튼에서 중단됐다. 실패는 `disk resume restores complete mid-run state`였다.

원본 버튼 전후 상태에서 4번째 교전·ready·7턴·7발·탄창 순서가 같았으나, 저장 전 Godot 정수와 JSON 복원 후 실수 타입을 Dictionary 전체 `==`로 비교한 것이 원인이었다. QA 하네스의 전체 상태와 history 양측에 `JSON.parse_string(JSON.stringify(value))` 정규화만 추가했다. 필드 생략이나 seed 문자열 변환은 하지 않았다. 제품은 수정하지 않았고, 새 `final_retry` 프로필의 전체 경로에서 상태 보존과 history 일치가 통과했다. 최초 INFRA 원본은 별도 경로에 유지했다.

## 최종 소스 식별

최종 실행 후 freeze 상태의 SHA256을 `qa_runtime/redesign/campaign_ui/final_retry/source_hashes.json`에 기록했다.

| 파일 | SHA256 |
|---|---|
| `redesign/model.gd` | `ACFD2C4183E437B5A4C761A6672FF74EC298B906A1262F6C8EFE77F0D5E0C789` |
| `redesign/screen.gd` | `8CBAE04A96CF5652075119B1549D76266CF3E6894FEF327CC571A562EED926A3` |
| `redesign/content.gd` | `6B938E2853AD074AF10A520FF9FA131D16901F425DED9BA46F27F8A048DC0BFD` |
| `tests/redesign_ui_campaign_runner.gd` | `8A7EDEF5BA4ED40D37ACFFB1EDD5F59D1D81862DA2FD136CB225E9A91EA61B67` |

전체 레거시 회귀, 다른 시드, 저장 손상 입력, 개발자 연습 저장 분리, 작은 창과 규칙 팝업의 상세 검증은 이 보고서의 독립 판정 범위에 포함하지 않는다.
