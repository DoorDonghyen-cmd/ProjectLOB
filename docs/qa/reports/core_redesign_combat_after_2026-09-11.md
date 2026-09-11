# Core redesign — 수정 후 독립 전투·저장 재검증

## 입력 계약

- QA session: `core-redesign-independent-combat-after-20260911`.
- 대상: `D:/ProjectLoB/worktrees/core-redesign`, branch `prototype/core-redesign`, 기반 HEAD `f5da527` 위 최종 freeze 작업 트리.
- 범위: RD01 큰 시드 저장, RD02 비정상 저장/확정 방어, 기존25개 독립 전투 계약, single의 loader 보상 제외.
- 원본 `core_redesign_combat_2026-09-11.md`, 원래 QA 스크립트와 수정 전 증거는 보존했다.
- 모델 SHA256: `ACFD2C4183E437B5A4C761A6672FF74EC298B906A1262F6C8EFE77F0D5E0C789`.
- 콘텐츠 SHA256: `6B938E2853AD074AF10A520FF9FA131D16901F425DED9BA46F27F8A048DC0BFD`.
- Godot 4.7 stable headless. QA APPDATA/LOCALAPPDATA/GODOT_USER_HOME은 worktree의 `qa_runtime/independent_combat_after` 하위로 격리했다. main·제품 소스·사용자 세이브 미변경.

## 판정

**PASS — 최초 보고의 RD01/RD02 재현 조건이 모두 해결되었고 기존 전투 계약은 유지되었다.** 각 결함 조건은2회 재실행했다. 이번 독립 검증 범위에서 새 회귀를 발견하지 못했다.

| 실행 | 결과 |
|---|---|
| 독립 원래25계약 + 수정 확인12체크 | **37 통과 / 0 실패**, 종료0 |
| freeze의 `redesign_rules_runner.gd` 직접 실행 | **48 통과 / 0 실패**, 종료0 |

두 집합에는 중복 검증이 있어 별도의 독립 사례85개라고 합산하지 않는다.

## RD01: 큰 시드와 다음 교전 패 보존

원래 재현 시드 `9007199254740993`으로 시작·저장·새 Model 복원을2번 실행했다.

| 관찰 | 수정 후 결과(2회 동일) |
|---|---|
| 저장 전 시드 | `9007199254740993` |
| 복원 후 시드 | `9007199254740993` |
| 원본 다음 교전 공개 패 | `precise, charge, mark, pierce, bore` |
| 복원 다음 교전 공개 패 | `precise, charge, mark, pierce, bore` |
| 다음 RNG 상태 | 일치 |

seed가 문자열로 보존되어 원래의 정밀도 손실이 발생하지 않는다. 후속 교전 비교는 최초 보고와 같은 교전 시작 진단 픽스처이며 실제 전투를 강제 승리시켜 검사한 것은 아니다.

레거시 숫자 저장도 별도로 확인했다. 안전한 숫자 `731042`는 복원을 허용하고 내부 문자열 `"731042"`로 정규화한다. 정밀도를 보장할 수 없는 숫자 `9007199254740993`을 포함한 레거시 JSON은 거절한다. 문자열 큰 시드 정상 수용과 불안전 숫자 거절을 혼동하지 않았다.

## RD02: 5발 계획 저장과 확정 거절

원래의 비정상 상태 `burst`, `plan=[basic,basic,basic,basic,basic]`, `supply=9`를 다시 준비했다.

- 직접 `confirm()`은 **false**이며 호출 전 상태를 그대로 유지한다.
- 이 상태가 들어 있는 JSON을 정상 진행 중인 별도 Model에 복원하면 **false**다.
- 복원 실패 뒤 기존 정상 Model의 전체 상태가 보존된다.
- 4칸 총기에5발 탄창이 생성되지 않는다.

위 조건을2회 독립 실행해 확인했다. 문법이 맞는 비정상 저장을 검사하기 위한 QA 픽스처이며 정상 UI에서 과대 계획을 생성했다는 주장은 아니다.

## 기존25계약과 loader 보상

LIFO, 무효 명령의 상태 보존, 예고20회 무변경, 빗나간 준비탄의 버프 발생·소비, 전술탄 순환, 탄창당 밀기2m, 한 번의 둔화, burst4발1턴·리로드3턴, 사망하는 부분 리로드2턴, lost 종료 상태, 정상 저장 및 복원 후3사이클 순환을 모두 다시 통과했다.

단계별 저장 픽스처의 reward/won/lost 상태에는 장전 계획을 남기지 않도록 조정했다. 최초 스크립트는 테스트를 위해 phase만 바꿔 계획이 남아 있었지만, 새 검증은 plan 이외 단계의 잔존 계획을 올바르게 거절한다. 실제 정상 전이에서는 이 계획이 남지 않는다. 합법적인 각 단계의 전체 스냅샷 보존이라는 검증 목적은 유지했다.

loader 변경도 모델 명령으로 확인했다.

- single의 파츠 보상 옵션에서 loader가 없고, `choose_reward("loader")`도 false이며 상태를 바꾸지 않는다. 리로드는 계속1턴이다.
- burst는 loader 옵션과 선택이 유지되고, 장착 후 리로드3→2턴으로 동작한다.

따라서 single에서 효과 없는 보상을 제외하면서 burst의 유효한 선택과 비용 공식을 보존했다. 이번 검증은 옵션·명령 수준이며 화면 배치/버튼 클릭은 별도 UI QA 범위다.

## 산출물과 범위 한계

- 새 스크립트: `qa_runtime/independent_combat_probe_after.gd`.
- 원본 증거: `qa_runtime/independent_combat_after/appdata/Godot/app_userdata/Last on Board/independent_combat_report_after.json`.
- 같은 디렉터리에 큰 시드 저장2개, 과대 계획 저장2개, 안전/불안전 레거시 저장, 단계별 저장을 보존했다.
- 엔진의 루트 인증서 저장소 경고는 기존 환경 경고이며 로컬 검사는 정상 종료했다.

판정은 최초 결함2건과 명시한 회귀 조건에 한정한다. 모든 가능한 손상 파일 형태, signed64 전체 시드 공간, 캠페인 완주, 사람의 재미·피로, 실제 화면 동작을 새로 전수 검증했다는 의미는 아니다.
