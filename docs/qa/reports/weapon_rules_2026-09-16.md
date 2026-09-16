# 다섯 무기 개편 기능 QA — 2026-09-16

대상: `prototype/core-redesign`의 다섯 무기 구현 변경. 실제 전투 명령·저장·공개 예측과 전체 도시 경로를 검증한다. 사용자의 APPDATA를 사용하지 않고 모두 `qa_runtime` 아래에서 실행했다. 자동 탐색기는 미래 패와 RNG를 읽으므로 사람 관점의 재미 테스트나 실제 승률로 해석하지 않는다.

## 검증 결과

| 묶음 | 결과 | 범위 |
|---|---|---|
| 무기 규칙 | 3,120 / 실패 0 | 실제 주 타격·적별3회 카운터·연쇄/단발·정확한2배·파트·저장v2/v3/v4·손상 파일 거절 |
| 탄환/예측 회귀 | 28,014 / 실패 0 | 80시드×5무기×7교전, 최근접 예측 정확 일치와 산개 HP/거리/종료 확률 범위 |
| 무기 실제 UI | 271 / 실패 0 | 합성 터치, 5종 시작/상세/개발자/발사/재개, 저장 센티넬, PC·가로폰, 산개7칸·이전 모드8칸 |
| 도시 기능 경로 | 22,040 / 실패 0, 10완주 | 5무기×안전/혼합 경로, 35층·맵·상점·이벤트·관문·장비·정산/저장 |
| 도시 실제 UI 완주 | 6,616 / 실패 0, 5완주 | 실제 버튼2,160입력, 무기별 전체 도시 재생, 산개 저장 RNG 결과와 연출 상태 일치 |
| 도시 최종 용량 UI | 760 / 실패 0 | 실제 경로에서 만든5/6/7칸, PC·가로폰, 범위 문구 폭과 발사/재장전 접근 |
| 기존 제작본 회귀 | 3,730 / 실패 0 / 기존 경보 3 | 기존 production 테스트 묶음 |

도시 실제 버튼 재생은 다섯 무기의 안전 경로를35층까지 완주했다. 무기/최대 용량 UI는 이후 표시 수정을 적용해 재실행했다. 전투 모델·경로의 정산은 동일하다.

## 도시 완주 기록

시드731042, 난도0, 모든 런35층 완주. 다음은 실제 모델 명령 수이며 사람의 행동 속도나 승률이 아니다.

| 무기 | 안전 경로 | 혼합 경로 |
|---|---:|---:|
| 보행자 | 417 | 290 |
| 쇄도 | 367 | 266 |
| 산개 | 449 | 307 |
| 압쇄 | 460 | 316 |
| 증강 | 402 | 288 |

명령3,562개, 런10개. 원본 `city_campaign_report.json`에는 경로와 명령, 최종 상태/프로필이 있다. 산개 역시 실제 저장 RNG로 재생한다.

## 산개 분포와 성능

HP8 적 두 마리에 회수탄 두 발은 적A 처치 확률25%, 두 적 전체 처치0%다. 가장 가까운 적이1m에서 시작하면 접촉 위험75%다. HP4 적 두 마리에서는 첫 처치 후 생존 적을 다시 선택해 전체 처치100%다. 거리를 달리한 적 세 마리에240시드로 연발을 쏘았을 때 주 표적 횟수는80 안팎인 `[90,80,70]`이었다. 이것은 난수 분포의 전수 증명이 아니라 고정 예제·재현·범위 검사다.

예측은 표적 RNG가 달라도 동일한 공개 분포이며 원본 상태/RNG를 소비하지 않는다. 각 연발탄은 같은 선택 적에게 최대2타다. 전이·화상은 최종 HP 범위에 포함하며 샷별 범위는 주 피해만 표시한다. 패배·보상·승리 상태에서는 잔탄으로 미래 발사를 예측하지 않는다.

이 PC에서 산개7칸945개 최종 분기를139ms에 계산했고 같은 상태100회 갱신은3ms였다. 이전 전투 모드8칸은280ms였다. 실기 휴대폰 성능으로 일반화하지 않는다.

## 독립 검토와 수정

전투 시뮬레이터는 계획·Content·Model·Forecast를 읽기 전용 대조했으며 실제 실행은 하지 않았다. 적중/배율/RNG 구조에 명세 위반을 찾지 못했다. 고정 증폭 주석 +2와 무기별 교육 수치 불일치를 지적해 실제 +4/화상/밀기/전이 값을 사용하도록 고쳤다. 이전 확장 파츠의8칸, 종료 상태 예측, 손상 구버전 자료형 경계는 실제 테스트로 보강했다.

경험 테스터/CD는 지정6장 PNG와 공개 GDD만 검토했다. 실제 플레이나 조작감·승률을 판정하지 않았다. 전탄 연쇄 대 매 발 적 접근을 선택 카드의 같은 위치에 보강했다. 작은 화면에서 예상 HP19가 HP1처럼 잘리는 관찰은 고정128px 출력 폭으로 재현했고 실제 글자 폭으로 수정했다. 수정 후 화면에서 HP19, 슬롯HP19, 계산29→19가 일치했다. 중앙 버그WPN-02로 기록한다.

증강 이름과 증폭 탄환의 구분, 연발2타/화상 기간은2배가 아니라는 이해, 산개의 같은 적 연속 선택, 쇄도 재장전 후 적중 유지, 압쇄의 이름과 속성 특화의 연결은 사람 플레이 확인 항목이다. 추가 피해나 단발 효율이 최종 균형을 입증했다는 결론은 내리지 않는다.

## 증거와 재실행

[원본 무기 규칙](weapon_rules_2026-09-16_assets/weapon_rules_report.json), [무기 UI](weapon_rules_2026-09-16_assets/weapon_ui_report.json), [도시10런](weapon_rules_2026-09-16_assets/city_campaign_report.json), [최종 용량 UI](weapon_rules_2026-09-16_assets/city_layout_report.json), [기존 회귀](weapon_rules_2026-09-16_assets/legacy_regression_summary.json).
[도시 실제 UI5완주](weapon_rules_2026-09-16_assets/city_ui_report.json), [탄환·예측 회귀](weapon_rules_2026-09-16_assets/readability_rules.json).

[산개 공개 예측](weapon_rules_2026-09-16_assets/weapon_combat_scatter.png), [쇄도 적중](weapon_rules_2026-09-16_assets/weapon_combat_burst.png), [수정 전HP 잘림](weapon_rules_2026-09-16_assets/forecast_hp_before.png), [수정 후HP19](weapon_rules_2026-09-16_assets/weapon_combat_phone_amplifier.png), [산개7칸](weapon_rules_2026-09-16_assets/weapon_scatter_7_slots_phone.png), [이전 모드8칸](weapon_rules_2026-09-16_assets/weapon_scatter_8_slots_phone.png).

워크트리에서 PowerShell 실행 정책을 해당 프로세스만 우회해 실행한다:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_weapon_checks.ps1 -Mode rules
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_weapon_checks.ps1 -Mode ui
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_readability_checks.ps1 -Mode rules
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_city_checks.ps1 -Mode campaign -Seed 731042 -Weapons single,burst,scatter,heavy,amplifier -RunName weapon_v4
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_city_checks.ps1 -Mode ui -RunName weapon_v4 -UISource qa_runtime/city/campaign_weapon_v4/city_campaign_report.json
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_city_checks.ps1 -Mode ui -RunName weapon_v4_final -LayoutOnly -UISource qa_runtime/city/campaign_weapon_v4/city_campaign_report.json
```

Godot4.7의 이 환경에서 root certificate store 오류가 발생하지만 스크립트 오류는 없다. 최초 개발 중 잘못된 tooltip 변수의 컴파일 실패와 잘못된 테스트용 소유 탄환 구성은 수정한 뒤 새 검증을 실행했다. 통과 기록은 수정 후 결과만 사용했다. APK/원격 푸시는 수행하지 않았다.
