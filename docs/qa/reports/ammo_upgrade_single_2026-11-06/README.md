# 단일 탄환 강화 — 본편 연결

2026-11-06 · [현재 규칙과 사용자 결정](../../../direction/ammo-upgrade.md). 승인한2발→1발을 본편 정비소와 자동 저장에 연결했다. 강화 수치/기존 압축 효과는 이번에 변경하지 않았다.

## 현재 화면과 조작

- 정비소4탭: 탄종 교체 / **탄환 강화** / 덱 정리 / 가방 확장. 독립된 화력/방열 개조 선택은 없다.
- 강화할 탄 선택 → 강화 상세 → 같은 성능의 원본2발/결과1발 비교 → 강화 확정. 선택/닫기/취소에는 정비 비용이 없고 확정만 무료 정비1회를 소비한다.
- 피해는 원본 두 발 합계와 결과 한 발의 기본 직접 피해를 비교한다. 화상·증폭 등은 중첩 가능성을 임의 합산하지 않고 발당 효과/설명을 비교한다. 발열·점유·보유 탄 수와 순서 제약도 표시한다.
- 원본/강화 특수 효과를 나란히 표시하고, 과거 위력/화력/방열 프로필은 이름표로 구별한다. 서로 다른 프로필은 섞을 수 없다.
- [기본탄 PC](upgrade_1280x800.png) · [소이탄 실제 획득 PC](earned_fire_1280x800.png) · [소이탄 S26비율](earned_fire_2340x1080.png) · [844×390](upgrade_844x390.png) · [열린 상태 크기 변경](resized_844x390.png).

작업대 장면/인물·기존 하단 항목은 유지한다. 기본 비교 창920×440, 짧은 창은 별도 상속 씬으로 여백 안에 맞추며 행동 버튼 최소44·16/32폰트·정수 배율을 유지한다. 효과 설명은 내부 스크롤, 취소/확정은 고정이다. 등급 프레임은 일반/고급을 사용하고 레어·에픽은 기존F2연구판에만 남긴다.

## 구현과 저장 경계

- 본편 `redesign/workbench/screen.tscn/gd`가 `upgrade_dialog.tscn/gd`와 작은 창 변형을 사용한다. 기본 구도와 카드/버튼은 실행 전 씬에 직렬화되어 있다.
- `redesign/ammo_upgrade.gd`는 Campaign/Model을 깊게 복제해 **실제** `resolve("compress", exact_id)` 결과로 제안한다. 본편 확정은 기존 `screen.gd::_campaign_action()`을 통해 저장/다시 그리기까지 실행한다. 캐시한 유효성을 믿지 않고 확정 시 다시 소유·최소 보유량·정비 상태를 확인한다.
- 현대 장소의 `Campaign.tune()`은 거절한다. 과거 저장의 모든 개조 ID/성능, 구형 유료 상점 명령과 임시 전투 압축 규칙은 유지한다. 저장 형식/게임 수치를 변경하지 않았다.
- 열려 있는 비교 창과 대상은 창 크기 변경 후 복원된다. Tab/Shift-Tab 포커스는 창 안에 머물고 ESC/취소 후 기존 버튼으로 돌아온다. 완료 저장을 재개하면 정비를 재사용할 수 없다.

## 기능 검증

| 검사 | 결과 |
|---|---|
| 새 본편 UI/입력/원본2발 합계/부족/최소 보유/오래된 제안/화력·방열 보유 탄/취소·확정/저장·재개/크기 변경/포커스/실제 소이 획득 상태 | **2,015검사 실패0** |
| 기존 정비소의 교체·강화·덱 정리·가방·메뉴/기록/설정·이탈 | **1,881검사 실패0** |
| 기존 `run_prototype_hud.ps1 -Mode ui -Fast` | **11,558검사 실패0** |
| 스파이크 후반 실제 유지 분기·종료 저장/재개 | **163검사 실패0** |

PC1280×800,1008×630,844×390,S26비율2340×1080,감소 영역2160×1032에서 실제 Godot 렌더/합성 터치·키보드를 확인했다. `metrics.json`은 글리프·실제 글자 크기/배율을 기록한다. Android 실기기/안전 영역·발열·장시간 성능 통과를 의미하지 않는다.

Godot MCP 프로젝트 정보 조회 성공(4.7.stable), 기존 로컬 Godot 실행 경로로 실제 입력과 캡처를 수행했다. `PLAY.cmd`의 엔진/프로젝트/메인 씬 점검과 독립 강화 시안의 headless 시작도 통과했다. 최종 로그에 새 파싱/실행 오류 없음. 모든 QA는 격리 APPDATA/LOCALAPPDATA를 사용했다.

## 밸런스 비교 — 승패와 기능 실패를 구분

자연 획득6경로에서 실제 정비 진입11상태를 확보했다. 리벳/래칫/리액터의 시드17·운반복 기준 경로, 스플린터/스파이크의 같은 시드·강화 우선 경로, 리액터 시드731042·정찰복의 강화 우선 경로다. 그중5경로는 끝까지 통과했고, 항상 강화한 스파이크는 마지막 조우에서 탐색이 멈췄다.

각 정비 상태를 원본 유지 / 강화 / 가방 확장(다른 정비)으로 복제하고 다음 최대2전투를 비교했다. 행동 정책은 전탄 반복, 보이는 열/탄창으로 냉각·1발을 고르는 단순 운용, 미래 드로/난수를 아는 탐색을 분리했다. **138개 국소 전투 기록**이며 사람의 승률이 아니다. 뒤 전투는 앞 전투를 이긴 분기에서만 진행되므로 전체 평균을 동등한 표본처럼 비교하지 않는다. 획득 여정의178조우 기록에는 탐색 미해결1건이 포함된다.

[요약/원본 연결](summary.json)의 같은 첫 조우11개 비교:

| 정책 | 유지 | 강화 | 다른 정비 |
|---|---|---|---|
| 전탄 반복 | 6통과/5패배 | 7통과/4패배 | 6통과/5패배 |
| 공개 열 기준 냉각/1발 | 4통과/7패배 | 5통과/6패배 | 4통과/7패배 |
| 미래 정보를 아는 탐색 | 11경로 확인 | 10확인/1미해결 | 11경로 확인 |

강화가 통과를 만든 사례와 반대로 같은 운용이 실패하게 된 사례가 모두 있다. 강화로 덱 수가 바뀌면 장전/난수 소비와 발사 위치도 달라지므로 피해 수치만의 인과효과로 해석하지 않는다. 이번 다른 정비는 가방 확장이며 뒤의 보상은 고정 정책이므로, 가까운 전투의 동일 결과만으로 가방 확장이나 모든 정비의 가치를 결론내리지 않는다. 쓴 탄은 다음 전투에 복구되며 관측하는 감소는 영구 보유량2→1과 각 전투의 잔탄이다.

### 스파이크의 미해결을 유지 선택으로 확인

시드17·5구역 마지막 정비40901에서 증폭탄2발을 강화한 분기는 보스41002의 통과 경로를 정해진 탐색 범위 안에서 찾지 못했다. 패배나 이론적 불가능을 입증한 결과가 아니다. 동일한 실제 획득 상태에서 **강화를 보류**한 분기는 보스24행동/잔탄9발로 통과하고 종료 저장·재개도 통과했다. [진입 상태](states/spike_final_workshop.json) · [재현 결과](runs/recovery_final/result.json).

초기 실험은 ‘항상 강화하는 모든 경로가 완주해야 한다’는 잘못된 검증 가정으로 이 상황을2개 assert 실패로 기록했다. [그 로그/결과](diagnostics/always_upgrade_initial_result.json)를 보존했다. 이후 불법 명령·저장 오류는 실패로 유지하고, 이 운용의 탐색 미완료는 **관측값2건**으로 분리했다. 게임 수치를 바꿔 자동 운용을 통과시키지 않았다. [새 관측 기록](runs/amplifier_observed/result.json).

첫 수집에서 발사 이벤트 키를 잘못 읽은 지표는 폐기하고 실제 `detail.results`/`part_effects`로 다시 수집했다. 최종 원본은 발사 탄 수와 표시된 파츠 발동 이벤트를 포함한다. 이전 통과 경로를 사용할 때도 현재 모델에 먼저 합법 재생해 확인하며, 빌드나 승리를 주입하지 않는다.

## 재현과 남은 범위

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_ammo_upgrade.ps1 -Mode ui -Label ui_final
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_ammo_upgrade.ps1 -Mode balance -Label balance_final -Guns single,burst,heavy -Seeds 17
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_ammo_upgrade.ps1 -Mode balance -Label scatter_final -Guns scatter -Seeds 17 -UpgradeRoute
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_ammo_upgrade.ps1 -Mode balance -Label amplifier_observed -Guns amplifier -Seeds 17 -UpgradeRoute
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_ammo_upgrade.ps1 -Mode balance -Label scout_final -Guns heavy -Seeds 731042 -Outfit scout -UpgradeRoute
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_ammo_upgrade.ps1 -Mode recovery -Label recovery_final
```

[코드 해시](source_manifest.json),[기능 결과](result.json),[UI 로그](stdout.log),[오류 로그](stderr.log),[가독성 기록](metrics.json). 초기 UI 검사의 저장 전후 비교는 기존 `normalize_for_save()`에 의한 더미 정리를 반영하도록 수정했고, 실제 자동 저장 확인을 위해 확정 직전에 미완료 저장을 따로 기록해 기대값 저장으로 검사를 대신하지 않게 했다.

단일 강화의 기능/본편 연결은 완료했다. 수치의 최종 적절성·사람의 강화/유지 판단·레어/에픽과 상위 강화는 미확정이다. 다음은 원본을 남기는 이유와 강화의 체감, 특히 스파이크 증폭탄의 다음 탄창 강화/마지막 발 제약을 사람 플레이에서 확인하는 것이다. 정예/보스·전장 기믹·탄약고와 승인 관문 본편 통합은 후속으로 유지한다. APK·커밋·푸시·외부 게시는 하지 않았다.
