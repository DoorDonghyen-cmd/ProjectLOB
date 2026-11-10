# 전투 사이 UI — 보상 비교·무료 정비·경로 확인

2026-11-01. 사용자의 ‘다음 스텝’ 요청으로 전투 HUD 다음의 비전투 흐름을 개편했다. 기존 첫 관문 여정의 실제 보상/정비/진행 명령과 저장을 사용한다.

## 적용 내용

- 보상/정비를 왼쪽 후보 목록과 오른쪽 선택 상세로 나눴다. 세 카드 안에서 긴 설명을 각각 넘기는 구성을 대체한다.
- 코어 선택에는 실제 장착 뒤의 탄창·발열 상한과 코어 값을 표시한다. 예: 돌파 구동핵 선택 시 탄창7칸에서6칸.
- 탄 보상에는 추가할 탄과 보유 탄 수를, 무료 정비에는 빠질 기본탄의 이름·기본 피해·발열과 들어올 특수탄을 표시한다. 한 발 교체 후 보유 총수도 확인한다.
- 미리보기는 격리된 Journey/Campaign 복사본에 실제 `choose` 명령을 실행한다. 화면에서 선택만 바꿔도 현재 덱·성장·난수·보상 기록·저장은 변하지 않는다. 확정 명령은 기존 경로를 사용한다.
- 메뉴의 ‘여정’과 전투 사이 이동 화면에7개 구간(5전투/무료 정비2곳)을 표시한다. 현재·다음·지나옴·예정을 구분하고, 다른 구간을 살펴봐도 실제 이동은 기존 고정 경로를 따른다. 자동 통과하는302조우는 새 선택으로 만들지 않았다.
- 다음 목적지가 목록 안에서 보이도록 스크롤하며, 보유 탄·총기·코어와 다음 전투의 탄 복구를 함께 안내한다.
- 확정/건너뛰기 직후0.3초 동안 후속 실행을 막아 빠른 두 번 누르기가 다음 보상/다음 전투 진입으로 이어지지 않게 했다. 메뉴·경로·후보·실행 버튼의 키보드 초점도 해당 창 안에서 순환한다.

## 기준과 구현 경계

[사용자 HTML](ui_prototype_2026-10-31/index.html)의 후보 목록/상세와 경로/장소 정보 구분, 앞 단계의 강철 프레임·글꼴을 재사용했다. 실제 여정은 고정 경로이므로 HTML의 분기 지도와 상점 경제를 복제하지 않았다. 지도 아이콘이나 배경을 새로 생성하지 않았다.

주요 파일:

- `redesign/samples/hud/journey_flow.tscn`: 후보 목록/상세와 기존 흐름 창.
- `redesign/samples/hud/journey_route.tscn`: 독립적으로 열 수 있는 경로/장소/현재 준비 구성.
- `journey_flow_presenter.gd`: 공개 경로와 실제 선택 결과의 표시. 런타임에서 주 배치를 생성하지 않는다.
- `combat_journey_hud.gd`, `combat_hud_presenter.gd`: 기존 명령 연결, 빠른 재입력 차단, 창 내 초점.
- `tests/journey_flow_ui.gd`, `tests/combat_hud_flow.gd`, `tests/pixel_hud_visual.gd`: 실제 획득 경로와 UI·글리프 검사.

Godot MCP 프로젝트 조회 성공. 로컬 씬 편집과 Godot4.7 Compatibility 실행으로 검증했다. QA 저장은 `qa_runtime/combat_hud_20261031/journey_flow_20261101/`의 별도 APPDATA/LOCALAPPDATA다. 사용자 실행 저장과 앞 단계 증거는 보존했다.

## 확인 결과

| 검사 | 확인한 내용 |
| --- | --- |
| 선택·정비 집중 검사 | 412검사 실패0. 740×360,844×390,1280×800에서 실제 첫3전투/보상으로 정비 도달. 모든 후보 미리보기의 무변경, 확정 결과 일치, 실제1발 교체, 미확정 선택 재개, 확정 재개 |
| 빠른 반복 입력 | 코어·탄 보상 확정을 연속 호출해 후속 보상 획득/이동이 발생하지 않음 |
| 경로 확인 | 전투 중 관문 열람은 전투/난수/저장 불변, 실제 다음 목적지와 열람 구분, 저장 복원 뒤 지나온 위치, 다음 목적지 스크롤, Escape 복귀와 초점 순환 |
| 전체 흐름 | 3크기의5전투·보상·정비·관문·완료/재도전/새 출발·저장 재개4,274검사 실패0. 테스트 전용 연출 배속 사용 |
| 독립 씬/글리프 | 컨트롤러 없는 구성과 실제 HUD의 글리프·부분 탄창·위험1,999검사 실패0. 네이티브 글꼴에 없는 화살표 대신 지원되는 삼각표시를 사용 |
| 임포트 | 에디터 임포트 종료0, 스크립트/리소스 오류0. 기존 Android build-tools 경로 경고는 별도이며 APK 내보내기는 수행하지 않음 |

검사 수는 반복되는 배치/상태 확인을 포함한다. 새 게임 밸런스·사람의 선택 이유·모바일 실기기 성능을 입증하는 수가 아니다. 최종 집중 검사 수와 소스/증거 해시는 [검증 묶음](../../../qa_runtime/combat_hud_20261031/journey_flow_20261101/validation.json)에 둔다.

실행 명령:

```powershell
./tools/run_prototype_hud.ps1 -Mode journey -Fast -Suite journey_flow_20261101
./tools/run_prototype_hud.ps1 -Mode flow -Fast -Suite journey_flow_20261101
./tools/run_prototype_hud.ps1 -Mode visual -Fast -Suite journey_flow_20261101
./tools/run_prototype_hud.ps1 -Mode import -Suite journey_flow_20261101
```

## 실제 화면

- [이전 보상 화면](../../../qa_runtime/combat_hud_20261031/prototype_20261101/flow/core_selected_844x390.png)
- [코어 선택과 실제 변화](../../../qa_runtime/combat_hud_20261031/journey_flow_20261101/journey/core_preview_844x390.png)
- [특수탄 추가](../../../qa_runtime/combat_hud_20261031/journey_flow_20261101/journey/ammo_preview_844x390.png)
- [무료 정비 교체 미리보기](../../../qa_runtime/combat_hud_20261031/journey_flow_20261101/journey/workshop_preview_740x360.png)
- [다음 정비와 현재 준비](../../../qa_runtime/combat_hud_20261031/journey_flow_20261101/journey/next_workshop_844x390.png)
- [전투 중 이후 구간 확인](../../../qa_runtime/combat_hud_20261031/journey_flow_20261101/journey/route_inspection_844x390.png)
- [독립 경로 씬 구성](../../../qa_runtime/combat_hud_20261031/journey_flow_20261101/journey/authored_route.png)

작은 가로 화면의 텍스트·실행 버튼·두 열 배치를 직접 이미지로 검토했다. 긴 상세와 경로 목록은 스크롤하고 확정/건너뛰기 버튼은 바깥 아래에 유지한다. 에디터 구성 증거는 컨트롤러 없이 씬을 연 캡처이며, 실제 에디터 창을 촬영한 것은 아니다.

## 판단과 다음 단계

보상의 효과와 포기하는 탄을 확인하고 다음 전투를 준비할 수 있게 하는 것이 이번 UI 변경의 목적이다. 선택 전후 수치가 실제 실행과 일치하는 기능 근거는 확보했다. 사람이 보상을 비교하고 선택 이유를 설명하기 쉬워졌는지는 다음 연속 플레이 후기에서 확인한다.

같은 `OPEN_COMBAT_UI_STUDY.cmd` 실행본에 적용했다. 본편 기본 진입·전투 규칙·저장 형식·획득 후보/가격은 바꾸지 않았다. 상점·전체 분기 지도·새 전투/경제를 이 여정에 추가하지 않았고 APK·커밋·게시도 수행하지 않았다. 실기기 스와이프/안전 영역·지속 FPS/발열, 사람 미감은 미검증이다.
