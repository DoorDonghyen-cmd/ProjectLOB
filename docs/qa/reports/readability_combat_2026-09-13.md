# 탄환 가독성·학습 런 독립 기능 QA

## 입력 계약

- QA session: `readability-combat-independent-20260913`.
- 대상: `D:/ProjectLoB/worktrees/core-redesign`, `prototype/core-redesign`, HEAD `06fdd46e5e114921e67e9dc511ad2fa44494702a` 위 미커밋 학습 런·math trace 변경.
- 범위: `model.gd`, `content.gd`, `forecast.gd`를 통한 실제 정산·예고, 후속 제공된 `readability.gd`의 stats/explain/enemy_stats. 화면·APK 제외.
- 모드: 기능 집중. 인간 재미·체감·전체 캠페인 승률 판정 아님.
- 지침: `15-gameplay-qa-lead`, `12-combat-simulator`. 승인된 현행 v2 FIFO·감산 규칙을 사용했다.
- 사용자 데이터: `qa_runtime/readability_combat_20260913/{appdata,localappdata,godot_home}`으로 격리. main·사용자 저장·제품 파일 미변경.
- 실행: Godot `4.7.stable.official.5b4e0cb0f`, Windows headless, 종료 코드0.
- 고정 입력: 합성 정산17사례, 실제 학습 첫2전투의 시드1/2×단발/일제, 단계 전환의 시드1/2/3/42/731042/9007199254740993×양 총기×보상 skip/take.
- 독립 원본: 본 스크립트·보고서·JSON. 다른 에이전트의 캠페인/화면 결과는 읽거나 인용하지 않았다.

## 판정

**기능 PASS — 5,177개 체크 통과 / 0개 실패. 최종 대상에서 재현된 기능 결함 없음.** 별도로 낮은 중요도의 설명 문자열 조사 오기3곳을 정적 확인했다.

체크 수는 독립 캠페인 수가 아니다. 실제 초반2전투 검증4경로, 전투를 생략한 단계 전환24경로×7단계, 이전 독립 v2의17개 정산 기준, 복원170지점, 설명·상한·타입 검사를 포함한다.

## 일반 런 유지 및 피해 근거

본 감사자가 앞서 작성한 `chain_combat_2026-09-13.json`의17개 초기 상태를 새 모델로 재생했다. 새 math 필드·course 기본값·명칭 변경에 따른 text/combo/message만 비교에서 제외했고, 그 외 기존 예고의 주/보조 피해·타격 수·균열·효과·표적·잔탄·종료 상태·이동·비용은 모두 일치했다. 이전 수치 결과를 다시 정의하지 않았으므로 정상 일반 런 변경 여부의 고정 기준으로 사용했다.

별도 복제 Model에서 실제 confirm/fire를 실행해 math를 포함한 Forecast 전체와 대조했다. 모든 샷에서 다음을 검사했다.

- `raw = base + boost + special`이며 base는 탄종 위력+총기 보너스다.
- `armor = max(0, armor_before - crack_before - penetration)`, `evasion = max(0, evasion_before - accuracy)`다.
- `per_hit = max(1, raw - armor - evasion)`이고 math.hits와 결과 hits가 같다.
- 실제 피해는 `min(hp_before, per_hit * hits)`이고 최종 HP는 hp_before에서 실제 피해만큼 감소한다.
- 예고 두 번 호출 전후 원본 상태·RNG가 같으며, 실제 샷과 첫발 preview의 math도 같다.

대표 사례는 강화→연속→회수의 1/8/6 피해, 강화+조준의 독립 유지, 균열 cap3 뒤 파쇄11, 두 타격의 장갑 적용, 균열 도약 고정3 및 무균열 도약 고정1, 보조 적 처치, HP1 적에게 연속탄의 초과 피해 제한, 5칸 탄창, 접촉 중단을 포함한다. math는 **주 피해의 근거**이며 도약은 별도 secondary 목록의 실제 보조 피해다. 두 값을 합쳐 한 타격의 per_hit로 취급하지 않았다.

## 설명 formatter

- explain 첫 줄의 표적·실제 피해·이전/이후 HP가 샷과 일치했다. 이어지는 식은 타격당 위력/강화/특수/감소량/per_hit를 사용한다.
- 최소1, 2회 타격, 남은 HP까지만 피해, 파쇄/마무리 보너스, 도약 대상별 고정 피해 이유가 해당 결과에서 표시됐다.
- 빈 샷은 안내문을 반환한다. math가 없는 기존 샷은 기존 text로 돌아가 예전 v2 이력 표시를 수용한다.
- 연속탄 stats는 일제 `위력 2×2`, 단발 `위력 3×2`다. 렌즈 장착 시 `명중 11`을 확인했다. 기본 stats는 영구 총기·파츠 수치이고 현재 강화 효과는 실제 explain에서 설명한다.
- enemy_stats는 균열을 반영한 남은 장갑과 둔화를 반영한 다음 접근량을0 이상으로 표시한다.
- 학습0단계는 관통·명중 축을 숨기고,1단계부터 관통,3단계부터 명중을 표시한다. full=true 상세는 모든 축을 표시한다.
- 후속 helper의 `description`은 학습0단계 회수탄·강화탄을 짧게 설명하는 별도 경로로 정적 확인했다. 해당 텍스트의 실제 화면 배치는 검사하지 않았다.

## 학습 런 실제 초반과 제거 경로

시드1/2×양 총기,4경로에서 적·덱·phase를 변조하지 않고 다음 실제 명령으로 첫2전투를 이겼다.

| 총기 | 첫 전투 장전 순서 | 두 번째 전투 장전 순서 |
|---|---|---|
| 단발 | 강화, 회수, 회수 | 균열, 강화, 회수, 파쇄 |
| 일제 | 강화, 회수, 회수, 회수 | 균열, 강화, 회수, 파쇄 |

첫 승리 시 덱2장에서 제거는 거절되고 전체 상태가 유지됐다. skip 보상 뒤 덱은 정확히 `[charge, charge, bore, pierce]`였다. 두 번째 실제 승리에서 charge 한 장 제거는 성공하며 다음 단계 precise 한 장 지급까지 합쳐 덱4장으로 진입했다. 일반 최소6과 학습 최소2의 구분을 확인했다.

최초 소스 읽기에는 remove 경로의 고정6이 남아 있었다. 첫 실행 전에 부모가 이를 `minimum_deck()`로 바꾸었다고 통지했고, 위 실측은 **수정 후 소스**다. 이전 상태의 런타임 실패를 재현했다고 주장하지 않으며 최종 기능 결함으로 집계하지 않는다.

## 단계 지급·보상·상한·교환

24개 유한 단계 전환 경로에서 전투 자체는 생략하고 reward phase 및 reward_taken=false를 명시해 보상 전환만 격리 검사했다. 따라서 이 구간을7전투 완주로 취급하지 않는다.

- 시작은 charge2장이다. skip 경로의 단계별 덱 크기는 **2,4,5,6,8,10,10**이며 지급 내역과 정확히 일치한다.
- 각 단계의 COURSE_GRANTS에 등장하는 새 탄종은 첫 패에 있었다. 첫 패 보정 전후 소유 탄환은 증감하지 않았다.
- 다음 단계 전환 뒤 같은 보상을 다시 호출해도 거절되고 지급 중복이 없었다. begin_encounter 재호출도 덱을 추가하지 않으며 같은 시드에서 같은 첫 패/뽑기 더미/RNG를 만들었다.
- 학습 초반 숨긴 축은 단지 UI에서 감춘 값이 아니다.0단계 장갑은 실제0,0~2단계 회피는 실제0이었다.
- 파츠 보상 단계4를 제외한 후보는 해당 단계까지 소개된 course_pool에만 속했다. 미래 탄종이 보상으로 먼저 나타나지 않았다.
- deck_limit는 남은 자동 지급 공간을 예약한다. 각 보상 단계에서 현재 한도까지 채운 명시적 덱으로 선택 보상 탄 추가를 거절하고, skip 후 필수 지급은 최종14장 범위에 들어가는지 확인했다.
- 매 단계의 손패/뽑기 더미/사용탄/탄창 전술탄 다중집합은 덱과 같고 손패5 이하·덱14 이하를 지켰다.
- 원본과 복원본에서 같은 전술탄을 교환하여 성공 여부, 변경된 패·더미, RNG와 전체 상태가 같음을 비교했다. 초반처럼 교환 재료가 없는 상황은 교환 불가로 원본 상태를 보존했다.

## 저장·호환성

170개 정상 상태를 JSON 파일에 기록한 뒤 별도 Model로 복원해 전체 상태를 비교했다. 학습 단계별 신규 탄 보정·보상 후 상태와 큰 문자열 시드를 포함한다. 복원 후 예고 및 실제 교환까지 일치했다.

- course가 없는 기존 정상 v2 저장은 course=false를 채워 일반 런으로 복원한다.
- course의 문자열/숫자/null/배열/객체 값은 모두 거절하며 기존 정상 Model을 변경하지 않는다.
- 학습 덱2장 저장은 정상 수용하고, 같은 상태를 일반 런으로 바꾼 덱2장 저장은 거절한다.
- default start는 일반 덱10장, 최소6, 상한14다. 일반 편성·보상 함수의 새 인자 생략과 명시적인 course=false 결과도 일치했다.

## 낮은 중요도 문자열 오기

최종 content 해시에서 아래 세 문자열을 정적 확인했다. 전투 계산·진행에는 영향이 없으며, 실제 화면 전사 여부는 별도 UI QA 범위다.

| 위치 | 현재 문자열 | 수정 제안 |
|---|---|---|
| AMMO.mark.text | `강화과 함께 유지되며` | `강화와 함께 유지되며` |
| ENCOUNTERS[0].text | `강화으로 다음 두 발을` | `강화로 다음 두 발을` |
| ENCOUNTERS[4].text | `강화은 연속탄을` | `강화는 연속탄을` |

## 한계와 QA 자체 수정

- 실제 전체 캠페인, 화면 정렬·클릭·글자 폭·모바일 입력·APK는 검사하지 않았다. 기능 PASS는 인간 학습 효과나 재미를 뜻하지 않는다.
- 첫 단계 전환 하네스는 전투를 생략하면서 이전 보상의 reward_taken=true를 false로 바꾸지 않아 후속 보상이 정상 거절됐고 연쇄480개 QA 실패가 발생했다. 보상 상태 픽스처를 올바르게 구성하도록 **테스트만 수정**했다. 실제 첫2전투 경로는 해당 문제 없이 통과했고, 최종 전체는5,177/0이다.
- 디스크 실패·프로세스 강제 종료·모든 손상 파일을 전수 검사하지 않았다.
- 정상 회귀의 설명 이름 변화는 의도된 변경이므로 이전 문자열과 동일해야 한다고 검사하지 않았다. 새 표시 명칭과 산식 의미는 별도로 검사했다.
- Windows 인증서 저장소 경고는 출력됐으나 오프라인 검사에 스크립트 오류가 없었고 종료 코드0이었다.

## 최종 실행 해시 및 원본

| 파일 | SHA256 |
|---|---|
| model.gd | `4436EF9FCB3622A7C4014B82266E417E78EA6B4F78DC2A87A21232A08B853EAE` |
| content.gd | `637DCBDEB9E8F7554FD6F01CD2A34A8F2AB1DCAD884BB0CC5B9F3D0E82E26968` |
| forecast.gd | `4C9348739300E14C70CFB74D52EACABED25C2BD14A341F32BA32C5F63711C5CD` |
| readability.gd | `DFB76FCB8950BDA9D7D3102187B3065814F0E7C58957947AB74FF4D3749EA30F` |
| tests/readability_rules_runner.gd | `5756CC1054CF34B3CB75A033DE26EE10A7E76BE982556548A09448039F4E842C` |

- 스크립트: `새-게임-프로젝트/tests/readability_rules_runner.gd`.
- 전체 체크·17개 trace·4개 실제 제거 경로 원본: `docs/qa/reports/readability_combat_2026-09-13.json`.
- 런타임 원본: `qa_runtime/readability_combat_20260913/appdata/Godot/app_userdata/Last on Board - Core Redesign/readability_combat_independent.json`.

```powershell
$env:APPDATA = 'D:\ProjectLoB\worktrees\core-redesign\qa_runtime\readability_combat_20260913\appdata'
$env:LOCALAPPDATA = 'D:\ProjectLoB\worktrees\core-redesign\qa_runtime\readability_combat_20260913\localappdata'
$env:GODOT_USER_HOME = 'D:\ProjectLoB\worktrees\core-redesign\qa_runtime\readability_combat_20260913\godot_home'
& 'C:\Users\mdyt7\OneDrive\Desktop\Godot_v4.7-stable_win64_console.exe' --headless --path 'D:\ProjectLoB\worktrees\core-redesign\새-게임-프로젝트' --script res://tests/readability_rules_runner.gd
```
