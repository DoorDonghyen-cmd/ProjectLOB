# 관문 재정비·출발 검증 — 2026-10-28

사용자의 순차 개편 지시에 따라 통합 우선순위2번을 구현했다. 현대 관문은 **보스 전리품 → 개조 확정/포기 → 재정비 → 직접 출발**로 진행한다. 소유 파츠 관리, 탄약·휴대량 확인과 다음 구역 안내를 연결했다. 수치·탄약 획득 정책은 [관문 정본](../../direction/gate-rewards.md)을 유지한다.

## 변경과 호환

- `phase=gate`의 `resolved`로 개조 선택 중/재정비 중을 구분한다. 적용과 출발을 분리했고 출발 전 중복 개조, 재정비 중 보스 보상 재수령, 출발 재실행을 거부한다.
- 개조 확정, 파츠 장착·해제·교체, 출발마다 기존 자동 저장을 실행한다. 재개 후에도 확정한 개조·보유물·장착 구성이 남고 재정비에서 계속한다.
- 파츠5슬롯/코어1개, 무료 보유 파츠 교체를 유지한다. 탄약은 열람하며 생산권 외에 무상 탄약/공방 서비스/분해를 추가하지 않았다. 창을 닫으면 관문으로 돌아온다.
- 현대 관문 기존 저장은 계속 사용할 수 있다. `gate_version`이 없는 옛 저장의 보상과 즉시 이동, 마지막 보스의 전리품→엔딩 흐름은 유지한다.
- 작은 화면의 보스 전리품 포기 버튼을 상단 수령 내역 옆에 배치했다. 빌드 작업실의 무료 교체 안내는 파츠에 해당함을 명시했다.

## 환경과 기능 검사

활성 작업 폴더 `D:/ProjectLoB/worktrees/core-redesign`, Godot4.7 stable `5b4e0cb0f`, Windows/RTX4060Ti OpenGL 호환 렌더링. APPDATA/LOCALAPPDATA는 `qa_runtime/gate/` 및 `qa_runtime/central_live/balance/gate_rest_20261028/`로 격리했다. 원래 작업 트리의 변경을 보존했으며 APK·커밋·푸시·외부 게시는 수행하지 않았다.

| 검사 | 결과 | 범위 |
|---|---|---|
| 관문 규칙·저장 | 835검사, 실패0 | 5무기·3개조/포기, 선택/재정비/출발 저장, 파츠 해제·재장착·코어 교체, 소유물 보존, 중복 방지, 기존 저장, 마지막 보스 |
| 실제 화면·터치 | 151검사, 실패0 | 1008×630/1280×800/1440×630, 큰 글씨1.2, 적용·생산·포기·파츠 관리·탄약·닫기·출발, 실제 자동 저장 재개 |
| 전체 등반 회귀 | 4,293검사, 실패0 | 연사·시드731042·refit 획득 정책, 실제27전투와4관문 출발 후 최종 보스/엔딩. 전 단계 저장·복구 확인 |
| 새 등반 관문 경로 | 4,561검사 중2실패 | 세 무기 모두 첫 관문을 자연 진행으로 통과. 연사/증폭은 두 번째 관문도 통과. 리액터 주조장 보스 탐색 실패와 이에 따른 두 번째 관문 미도달 |
| 즉시 이동 비교 대조군 | 1,711검사 중 동일2실패 | 리액터 동일 시드/획득/입력으로7개 전투 시작 상태·결과 행이 모두 일치. 재정비로 인한 전투 상태 차이는 없음 |

명령은 PowerShell 프로세스 범위 `-ExecutionPolicy Bypass`로 실행했다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_gate_checks.ps1 -Mode rules
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_gate_checks.ps1 -Mode ui
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_gate_checks.ps1 -Mode campaign
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_gate_checks.ps1 -Mode campaign -ImmediateBaseline
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_central_live_checks.ps1 -Mode balance -Guns burst -Seeds 731042 -Tag gate_rest_20261028 -Acquisition refit
```

기능 근거: [규칙](assets/gate_reorganization_2026-10-28/rules.json) · [UI](assets/gate_reorganization_2026-10-28/ui.json) · [전체 등반](assets/gate_reorganization_2026-10-28/full_run.json) · [세 무기 관문 경로](assets/gate_reorganization_2026-10-28/campaign.json) · [즉시 이동 비교](assets/gate_reorganization_2026-10-28/immediate_baseline.json) · [상태 일치](assets/gate_reorganization_2026-10-28/comparison.json) · [검증 소스 SHA256](assets/gate_reorganization_2026-10-28/source_hashes.json). 다섯 무기 모두 재정비/저장/재개 후 다음 교전 상태와 프로필이 즉시 이동 방식과 일치했다. 자동 경로는 미래 난수를 보는 탐색/기존 입력 재검증을 사용하므로 사람의 승률이나 재미로 해석하지 않는다.

## 화면 확인

실제 Godot 캡처를 직접 확인했다. 재정비의 주요3버튼은 세 화면 및 큰 글씨에서 화면 안에 들어온다. 작은 화면과 큰 글씨에서는 하단 파츠·탄약 목록을 스크롤한다. 재정비 캡처는 과거 획득 덱의 관문 위치를 구성한 UI fixture이며 자연 등반 증거는 별도 실행 결과다.

- [재정비1280](assets/gate_reorganization_2026-10-28/gate_rest_1280.png), [작은 화면1008](assets/gate_reorganization_2026-10-28/gate_rest_1008.png), [긴 화면1440](assets/gate_reorganization_2026-10-28/gate_rest_1440.png), [큰 글씨](assets/gate_reorganization_2026-10-28/gate_rest_large_text.png)
- [보유 파츠 관리](assets/gate_reorganization_2026-10-28/gate_parts_1008.png), [탄약 구성](assets/gate_reorganization_2026-10-28/gate_ammo_1008.png), [보스 전리품](assets/gate_reorganization_2026-10-28/boss_loot_1008.png), [생산권 교체 선택](assets/gate_reorganization_2026-10-28/production_sources.png)

## 발견·수정·남은 한계

- 네이티브630높이 검사에서 보스 전리품 포기 버튼이 화면 아래에 놓이는 결함을 발견해 상단으로 옮겼다. 빠른 다시 그리기 때 이미 제거된 출발 버튼이 포커스를 얻으려던 오류는 트리 내 존재 확인으로 막았다. 최종 UI 실행에서 두 오류는 재발하지 않았다.
- 상태 비교 검사의 프로필 숫자형 차이(int/JSON float)는 양쪽을 같은 JSON 표현으로 정규화했다. 실제 저장 내용 차이는 없었다.
- 리액터 시드731042 주조장 보스 `10902`는 제한된 탐색에서 해결하지 못했다. 즉시 이동 대조군도 같은 상태와 동일 실패라 이번 관문 흐름의 회귀로 분류하지 않는다. 승리 불가능 판정이나 밸런스 해결을 뜻하지 않으며 성장/강적·전체 탄약 경제 단계의 후속이다. 옛 등반 보고서의 `remaining=-2`는 비상 임시탄까지 사용탄에서 빼는 기존 집계식 때문에 생긴 값이므로 영구 탄약 부족량으로 해석하지 않는다.
- 루트 인증서 저장소를 읽지 못하는 실행 환경 경고가 있었다. 정확히 해당 경고만 제외하고 다른 Godot 오류는 실패 처리하도록 검사 도구를 보강했다.
- Android 실기기·모바일 지속 성능/온도와 사람의 재정비 이해도·재미는 확인하지 않았다. 관문 연출, 등반 중 무기/복장 변경은 이 단계에 포함하지 않았다. 다음 구현은 성장·파츠 발동 체감과 강적 대응이다.
