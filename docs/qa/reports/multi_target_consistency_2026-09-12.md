# 다수 적 연속 사격 예고 독립 정합 감사

## 입력 계약과 판정

- 세션: `multi-target-consistency-independent-20260912`.
- 대상: `D:/ProjectLoB/worktrees/core-redesign`, branch `prototype/core-redesign`, HEAD `34c47614f3a05fcbc6c368940a6d885bfa5a9023` 위 미커밋 다수 적 예고 변경.
- 명세: `docs/implementation_plan_multi_target_2026-09-12.md`.
- 독립 작성: `qa_runtime/multi_target_independent.gd` 및 본 보고서. 제품 코드/데이터/main/사용자 저장은 수정하지 않았다. 다른 QA 결과를 판정 근거로 사용하지 않았다.
- 적용 지침: `15-gameplay-qa-lead`, `12-combat-simulator`. 기존 게임의 전투 규칙을 새 실험 모델에 강제하지 않았다.
- 실행: Windows Godot `4.7.stable.official.5b4e0cb0f`, headless, 실제 Model 및 Screen 씬. 최종 종료 코드 0.

**PASS: 2,627개 체크 통과 / 0개 실패. 재현된 제품 기능 결함 없음.**

18개 명명 사례와 256개 유한 조합, 총 274개 전투 상태를 검사했다. 체크 수에는 픽스처 합법 장전, 실제 사격 호출, 상태 비교, UI 검증 등이 포함된다. 2,627개의 독립 캠페인이나 승률 표본을 의미하지 않는다.

## 독립 검사 방식

모든 전투 픽스처는 명시적 적 HP·거리·속도·장갑·회피와 탄환 목록을 사용했다. 단발/일제의 공급 3발, 용량 4발을 유지하며 실제 `load_round`와 `confirm`으로 장전했다. 전술 덱은 최소 4장이 되도록 미사용 표식탄으로 채웠고, 덱과 소유 탄환을 보존했다. 시드는 문자열로 유지되는 `9223372036854000000`을 사용했다.

1. Forecast에 원본 상태를 넘겨 계산한 뒤 깊은 원본 전체가 같음을 비교했다. 계획, 탄창, 적, 효과, 재고, 이력, 시드, RNG 상태를 모두 포함한다.
2. 같은 원본에서 예고를 다시 계산해 동일 결과를 확인했다.
3. 별도 Model 복제본에서 계획을 확정하고, `ready`이면서 탄창이 남아 있는 동안 실제 `fire()`를 실행했다. 무한 반복을 막기 위한 독립 상한은 8회이며 정상 용량은 4발이다.
4. 샷 전체 필드와 행동 묶음, 최종 적 상태, 종료 phase, 잔탄 배열, 실제 턴 비용을 예고와 비교했다. 계획 중 예고와 확정 후 예고도 동일했다.
5. 반환 예고의 적 HP·샷 피해·잔탄 배열을 고의로 변경해도 원본이나 다음 예고가 바뀌지 않는지 확인했다.

예고와 실제가 같은 모델을 사용한다는 사실만으로 규칙이 옳다고 단정하지 않도록, 아래 대표 사례에는 수동 계산한 표적 순서·피해·거리·비용을 추가 비교했다.

## 대표 전투 근거

표의 탄종은 **발사 순서**이며 장전 순서는 역순이다. 별도 표기가 없으면 장갑 0, 회피 1, 속도 1이다. A/B/C는 원본 적 배열의 인덱스 0/1/2다.

| 조건 | 발사·예고 결과 | 확인한 계약 |
|---|---|---|
| 일제, A HP5/거리10/속도2, B HP6/거리11; push → charge → basic → basic | A → B → B → A, 4발·1턴, reward | 밀기 직후 재표적, B 처치 후 A 복귀 |
| 단발, A HP40/거리10/속도1, B HP40/거리11/속도3; precise → basic → basic | A → B → B, 3턴, 최종 거리 A7/B2 | 매 발 뒤 접근에 따른 표적 전환 |
| 위와 같은 적/탄창, 일제 | A → A → A, 1턴, 최종 거리 A9/B8 | 일제 도중 접근 없음, 전탄 후 1회 접근 |
| 일제, A/B/C HP3/거리20; basic 3발 | A → B → C, reward | 동률 인덱스 순서, 사망 적 제외 |
| 단발, A HP40/거리1, B HP40/거리4; precise → basic → basic | precise 1발 뒤 lost, basic 2발 잔존 | 접촉 뒤 사격 중단, 중단 슬롯 근거 |
| 일제, A HP1/거리20, B HP0/거리20; charge → basic 3발 | charge 1발 뒤 reward, basic 3발 잔존 | 전투 종료 뒤 미발사 보존 |
| 마지막 교전, 단발, A HP1/거리20; charge | won | 최종 승리 phase |
| 일제, A HP1/거리10, B HP10/거리11; charge → basic | A 처치 후 B에 피해7 | 준비탄으로 표적을 죽여도 다음 표적에 효과 전달 |
| 일제, HP50/거리20/회피9; charge → mark → basic | charge 빗나감, mark 피해5, basic 피해3 | 빗나가도 준비 효과 생성, 다음 탄에 소모·대체 |
| 일제, HP50/거리20/장갑4; bore → basic | 피해1 → 피해3 | 후속 관통 효과 |
| 일제, HP50/거리20/장갑4; basic → push → push | 기본탄 도탄, 밀기2 → 밀기0, 최종 거리21 | 장갑에 막힌 명중도 밀기 적용, 탄창 공유 상한2m |
| 단발, A HP50/거리10/속도2, B HP50/거리11/속도3; slow → basic | A → B, 최종 거리 A8/B5 | 둔화는 다음 접근 1회만 적용 |
| 이미 charge를 발사한 단발 ready 상태, basic 잔탄 | 피해8 | 저장된 준비 효과와 단발 피해 +1 반영 |

빈 계획, 빈 ready 탄창, reward/lost/won phase는 모두 사격 0발·추가 비용 0으로 안전하게 반환했다. 마지막 처치/빗나감/도탄 문자열과 A/C 레이블도 별도로 검사했다.

유한 조합은 **총기 2종 × 첫 탄종 8종 × 둘째 탄종 8종 × 적/파츠 조건 2종 = 256개**다. 모든 두 발 조합을 기본 조건과 높은 장갑·회피 및 lens 파츠 조건에서 실행했다. 적은 A HP7/거리5/속도2, B HP10/거리6/속도3을 공통으로 사용했다. 모든 조합에서 원본 불변·재현·계획/확정 동등성·실제 결과·최종 거리/잔탄/비용이 일치했다.

## Screen 통합과 코드 감사

실제 `main.tscn`을 headless SceneTree에 올리고, `presentation_speed=0.1`로 실제 프레임/await/연출을 실행했다.

- 다수 적 계획 화면의 Magazine 예고와 Battlefield 첫 발 예고가 독립 계산과 일치했다. `연속 사격` 조건 및 동률 규칙 안내가 존재했다.
- 적 정보 버튼 0/1의 실제 `pressed` 시그널을 각각 발생시켰다. 해당 인덱스 상세 창이 생성되고, 원본 모델 전체와 자동 조준 표적은 변하지 않았다. 콜백 인덱스가 잘못 묶이는 문제는 없었다.
- 되돌리기 → 다시 장전 → 확정 각각 뒤에 예고가 현재 모델로 갱신됐다.
- 사격 시작 즉시 Magazine 예고와 Battlefield 첫 발 예고가 비워졌고, inspection이 잠겼다. busy 중 상세 열기도 거부했다.
- 연출이 끝나기 전에 저장 파일을 별도 Model로 복원해 이미 정산된 실제 상태와 일치함을 확인했다.
- 일제의 실제 시각 샷 순서 A → B → B → A 및 최종 적 상태가 사전 예고와 일치했다.
- 생존하는 단발 사격 후에는 접근 완료 거리와 두 발 잔탄으로 예고가 다시 계산됐다.

정적 검토에서도 `Forecast.analyze`는 전체 상태를 깊게 복제한 새 Model에만 `confirm/fire`를 호출한다. 원본 모델 명령, 파일 저장, RNG 변경 경로는 호출하지 않는다. Magazine 슬롯은 LIFO 순서와 예고 샷 순서를 같은 인덱스로 대응하며 미발사 슬롯을 lost이면 `중단`, 그 외에는 `보존`으로 표기한다. 연출 중에는 예고를 지우고 실제 결과 목록만 표시한다. 적 클릭과 정보 버튼은 상세 시그널을 내보내며 조준 명령을 갖지 않는다.

현재 Forecast의 `range(4)`는 두 총기의 최대 용량 4와 일치한다. **향후 용량을 늘리면 함께 변경해야 하는 의존성**이지만 현재 정상 데이터의 누락 결함은 아니다.

## 미검증·범위 제한 및 QA 자체 오류

- 전투 규칙 및 예고 정합 감사다. 실제 캠페인 승률, 전략적 무해법, 인간 체감, 화면 글자 겹침·픽셀 가독성·마우스 좌표 명중 영역은 검증하지 않았다. 정보 버튼은 시그널 경로를 검증했으며 실제 마우스 이동/클릭은 수행하지 않았다.
- 정상 Model 상태가 입력 계약이다. 손으로 손상시킨 Dictionary를 직접 Forecast에 넣는 악성 입력/스키마 검사는 범위 밖이다. 정상 저장의 복원 검증과 구별한다.
- 쓰기 실패나 프로세스 강제 종료를 주입하지 않았다. 정상 격리 파일 시스템에서 연출 중 즉시 복원해 저장 선행을 확인했다.
- 첫 실행 2,626/1의 1개 실패는 독립 QA 픽스처가 전술 덱 2장을 사용해 기존 저장 복원의 최소 4장 계약을 위반한 것이었다. QA 픽스처에 미사용 전술탄을 채워 소유 재고를 맞춘 뒤 최종 **2,627/0**을 확인했다. 제품 코드는 고치지 않았고 제품 결함으로 집계하지 않았다.
- Godot 실행 중 `Failed to read the root certificate store`가 출력됐다. 네트워크를 사용하지 않는 본 검사에서 스크립트 오류 없이 완료했고 종료 코드는 0이었다.
- 감사 중 부모가 Battlefield 거리 라벨 위치만 변경한다고 통지했다. 본 보고의 최종 통과 실행은 변경 후 해시를 사용했다. 예고/모델/조준 로직은 감사 중 변경되지 않았다.

## 최종 실행 식별과 증거

| 파일 | SHA256 |
|---|---|
| forecast.gd | `B4F389C0B222E67B4842284618CFFA98C13F3BAE8B4CD0FE33F6391255140EFD` |
| model.gd | `ACFD2C4183E437B5A4C761A6672FF74EC298B906A1262F6C8EFE77F0D5E0C789` |
| screen.gd | `39C4D78E25DDF9FB16DF4067AF4F95220CA97291E818C6F18A89C21CF7FB797F` |
| battle_view.gd | `D780D0411EB830788237A67CBDFCAC92191D793630F43604244D29817E020529` |
| magazine_view.gd | `7147ABA7A11497707F73EA357E8EEF3482F6B7026A43FF67E17A669D12E509C7` |
| qa_runtime/multi_target_independent.gd | `78D3F0CD1FBBE73D1D050913971298BFA3D4011952EFF164E641A5A5FE814036` |

원본 JSON은 `qa_runtime/multi_target_independent/appdata/Godot/app_userdata/Last on Board - Core Redesign/multi_target_independent.json`이다. 전체 체크 목록과 명명 18사례의 초기 전체 상태·예고·실제 종료 상태를 포함한다. 256개 조합은 하네스의 유한 루프로 재생 가능하며 해당 검사 결과는 JSON 체크 목록에 남는다.

```powershell
$env:APPDATA = 'D:\ProjectLoB\worktrees\core-redesign\qa_runtime\multi_target_independent\appdata'
$env:LOCALAPPDATA = 'D:\ProjectLoB\worktrees\core-redesign\qa_runtime\multi_target_independent\localappdata'
$env:GODOT_USER_HOME = 'D:\ProjectLoB\worktrees\core-redesign\qa_runtime\multi_target_independent\godot_home'
& 'C:\Users\mdyt7\OneDrive\Desktop\Godot_v4.7-stable_win64_console.exe' --headless --path 'D:\ProjectLoB\worktrees\core-redesign\새-게임-프로젝트' --script 'D:\ProjectLoB\worktrees\core-redesign\qa_runtime\multi_target_independent.gd'
```

## 원본 완료 후 처치 표기 변경 재검증

원본 보고 완료 후 부모가 `Forecast.outcome`의 처치 표시 `×`를 ` 처치`로 변경하고 Screen 툴팁 설명을 갱신했다. QA 하네스의 문자열 기대값만 `−7 처치`로 맞춰 같은 전체 유한 검사를 재실행했다. **2,627 통과 / 0 실패, 종료 코드 0**이다. 전투 계산·원본 상태 불변·UI 동기화 판정은 유지된다.

표기 변경 전 원본 결과는 `qa_runtime/multi_target_independent/before_wording.json`에 보존했다. 위 user 경로의 JSON은 표기 변경 후 최종 실행 결과다. 모델, Battlefield, Magazine 해시는 위와 같다. 갱신된 해시는 다음과 같다.

| 파일 | 표기 변경 후 SHA256 |
|---|---|
| forecast.gd | `918BB68C8F12B43FB4C6C415A6D2715F25B1867B0C178509615EFD0269E19FEC` |
| screen.gd | `895A7D8D6AEE13AE4BA6F910D20A8E975CB90F250A215D8BE9EFB8E4381D66AD` |
| qa_runtime/multi_target_independent.gd | `3B05021A7D0DD62158AA9BFECB7CECF34FAFA917BA2BB548CEA0A990F8402BE3` |
