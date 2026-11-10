# 플레이 피드백 개편4차 — 획득·교체와 휴대량

사용자의 “다음 스텝 진행해 줘”에 따라 새 등반의 보유 탄 교체, 공방 교체 기회, 복장별 총 휴대량을 적용했다. 세부 수치는 디렉터1차 결정이다. 기존 전투 피해·적 편성·발열은 변경하지 않았다. [비축 정본](../../direction/ammo-reserve.md) · [복장 정본](../../direction/outfit-bag.md).

## 바뀐 플레이

1. **획득 때 보유 탄 한 장 교체.** 기본탄에 한정했던 대상을 특수탄·압축탄·개조탄까지 열었다. 보상·상점·보급·획득 이벤트가 같은 판정을 사용한다. 같은 프로필 여러 장 중 한 장만 내보내며, 동일 프로필·임시 탄·미소유 탄은 거부한다. 교체는 총량을 유지하며 상점 구매 가격도 같다.
2. **공방에서 탄종 교체.** 현재 구역·보유 탄·장착 파츠의 보상 후보2종+다른 계열1종을 제시한다. 새 후보 한 장과 보유 탄 한 장을 교체하며 방문의 무료 작업1회를 쓴다. 압축·개조·정리·가방 확장과 선택을 공유한다. 취소는 무료다.
3. **복장은 총 휴대량도 구분.** 정찰28/작업30/운반32/방열34/인양36/회수38/원정40장. 시작은 모두 기본탄20장이다. 손패4~10장·교환 횟수는 기존대로이며 탄창은 총기·파츠가 정한다. 가방 성장1회는 손패+1·휴대 상한+2(최대40); 자동 탄약 지급은 없다.
4. **고갈 규칙 전달.** 탄약 가방에 총 휴대/상한, 손패 상한, 이번 전투 잔량을 나눠 표시하고 소진 패배·사용함 재사용 없음·남은 화상 진행을 명시한다. 장비 선택에서는 손패·휴대·교환을 함께 보여 준다.

새 캠페인과 전투에 `inventory_version=1`을 저장한다. `reserve_version=1`·`combat_revision=2`는 유지한다. 버전이 없는 저장은 기존32장·기본탄 교체를 유지하며 소유 탄을 삭제하거나 자동 승격하지 않는다. 미래/소수 버전, 캠페인과 전투의 불일치, 새 상한 초과는 원자적으로 거부한다. 훈련 순환도 유지한다.

무한 리필·비상 보급·사용 후 영구 소멸하는 특수탄은 이번에 추가하지 않았다. 파츠는 기존5칸이다. 복장 정식 획득/해금·런 중 교체는 도입하지 않았으며 기존7종 테스트 개방을 유지한다.

## 기능과 화면 검증

Godot4.7, 별도 `qa_runtime`의 APPDATA/LOCALAPPDATA. 사용자 진행 저장을 사용하지 않았다.

| 검사 | 결과 | 확인 범위 |
| --- | ---: | --- |
| 새 휴대·교체 규칙 |771 / 실패0|5무기×7복장, 상한, 사본·압축·개조 교체, 비용/재입력/취소 경계, 공방3시드×3지역, 저장·불법 버전 거부, 실제 이전 엔딩2개 정확 복원|
| 기존 비축 회귀 |683 / 실패0|장전 후 회수 금지, 재장전 배출, 임시 압축, 패 교환, 소진 패배/화상 승리, 패배 저장, 구형 재순환|
| 장갑·발열·강적 회귀 |449 / 실패0|전 단계 실제 피해/예측/강행/적 행동·저장|
| 본편 UI |177 / 실패0|1008×630,1280×576,1280×800의 장비 선택, 꽉 찬 상점 교체4페이지, 취소·가격·자동 저장, 공방 후보→교체→맵, 가방 설명|

실제 터치 입력으로 구매·교체·취소·페이지 이동을 검사했다. 공방 교체 목록은 기존 모달 안에 스크롤을 두고 키보드 포커스가 선택 행을 따라가게 했다. 장비 선택에서 교환 횟수가 숨겨지지 않도록 보이는 복장 행에도 유지했다. 대표 PNG를 직접 열어 글자/카드/선택 버튼의 잘림을 확인했다. 이는 Windows 렌더 확인이며 Galaxy 실기기나 사람의 이해도 검증은 아니다.

- [복장별 손패·휴대·교환](assets/inventory_revision_2026-10-27/equipment_1008x630.png)
- [상점 특수탄 교체 마지막 페이지](assets/inventory_revision_2026-10-27/replacement_last_1280x576.png)
- [공방 새 선택](assets/inventory_revision_2026-10-27/workshop_1280x576.png), [한 장 교체](assets/inventory_revision_2026-10-27/workshop_exchange_1008x630.png)
- [탄약 가방과 소진 안내](assets/inventory_revision_2026-10-27/bag_1008x630.png)

초기 검증에서 공방 후보가 기존 보상 함수의2종만 반환하는 문제가 발견되어 다른 계열1종을 더하도록 수정했다. UI 첫 실행의 타입 추론 오류와, 새 상점의 ‘추가 구매/교체’ 분리를 잘못 누르던 검사 경로도 수정했다. 본편 상점에 남아 있던 기본탄 전용 조회를 모든 보유 탄 조회로 연결했다. 위 표는 수정 후 결과다. Windows 인증서 저장소 경고는 기존 환경 경고이며 최종 검사에는 Script/Parse 오류가 없다.

## 실제 획득으로 이어 간 전체 등반

`central_live_balance_runner.gd`로 새 등반부터 실제 지도·보상·구매·공방·장전/발사 입력을 실행하고 매 단계 저장/복원을 검사한다. 과거 명령 경로는 현재 모델에서 실제로 재생해 승리할 때만 재사용한다. 자동 전투 탐색은 미래 손패/RNG를 볼 수 있는 제한 탐색이므로 사람 승률이나 난이도 확정이 아니다. 모든 전체 등반은 운반용 외투 기준이다.

리액터2시드는8,588검사 실패0, 나머지4무기는14,190검사 실패0. 합계6등반·165전투를 엔딩까지 연결했다. `refit`은 기존 탄종 맞춤/자동 장착을 유지하며 공방에서 낮은 기본탄을 맞는 후보로 교체하는 공개 정보 정책이다. `first`는 앞 단계의 첫 후보 정책을 유지한 회귀다.

| 무기 / 시드 | 정책 | 전투 수 | 전체 턴 | 최종전 턴 | 최종전 잔탄 | 최종전 최소거리 |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 리액터 /731042 |refit|27|228|20|2|14m|
| 리액터 /17 |refit|30|239|18|5|16m|
| 리벳 /731042 |first|27|103|9|17|24m|
| 래칫 /731042 |first|27|230|17|10|17m|
| 스플린터 /731042 |first|27|180|13|9|19m|
| 스파이크 /731042 |first|27|128|12|20|16m|

네 무기의108전투는 앞 단계 결과와 턴·잔탄·최소거리·승리 여부가 모두 같았다. [실제 재생 결과](assets/inventory_revision_2026-10-27/four_weapons.json) · [리액터2시드와 전체 명령](assets/inventory_revision_2026-10-27/reactor_refit.json).

시드731042 리액터는 앞 단계의 ‘탄종 맞춤+자동 장착 유지’ 정책에서 최종전 해법을 찾지 못했지만 이번 공방 교체 정책으로 엔딩까지 통과했다. 장착은 같은 `thermal_drive / chain_sink / compression_sink / radiator / supply`를 유지했다. 초반 기본탄1 세 장을 공방에서 각각 배율탄·전격탄·열방출탄으로 바꿨다. 최종전20턴·잔탄2발·최소거리14m, 전체228턴이다. 4구역 보스는19턴에 탄을 모두 사용해 승리했으므로 자원 여유가 충분하다는 결론은 내리지 않는다. 휴대 상한은 이전과 같은32장이라 이 사례는 상한 확대의 이득이 아니라 획득·교체 경로의 변화다. 이후 후보/손패와 탐색 경로도 달라지므로 특정 탄 한 장만의 인과 효과로 단정하지 않는다.

시드17 리액터도 공방 교체4회로 완주했지만 최종전은 이전 맞춤 정책14턴/잔탄10/18m에서18턴/잔탄5/16m로 여유가 줄었다. 교체가 항상 유리하거나 리액터 고갈이 모든 경로에서 해결됐다고 판단하지 않는다.

## 재현·증거와 남은 판단

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_playtest_revision_checks.ps1 -Mode inventory -Tag final
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_playtest_revision_checks.ps1 -Mode inventory_ui -Tag final
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_reserve_checks.ps1 -Mode rules
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_playtest_revision_checks.ps1 -Mode pressure -Tag inventory_regression
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_central_live_checks.ps1 -Mode balance -Guns heavy -Seeds 731042,17 -Acquisition refit -Tag inventory_refit
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_central_live_checks.ps1 -Mode balance -Guns single,burst,scatter,amplifier -Seeds 731042 -Acquisition first -Tag inventory_four
```

[기능 로그](assets/inventory_revision_2026-10-27/inventory_rules.log), [UI 로그](assets/inventory_revision_2026-10-27/inventory_ui.log), [비축 회귀](assets/inventory_revision_2026-10-27/reserve_rules.log), [전투 회귀](assets/inventory_revision_2026-10-27/pressure_regression.log). 원본 전체 로그·화면은 `qa_runtime/playtest_revision_20261026/{inventory,inventory_ui}` 및 `qa_runtime/central_live/balance/inventory_{refit,four}`에 남긴다.

[적용 소스/검사 도구17개 SHA-256](assets/inventory_revision_2026-10-27/source_hashes.json), [리액터 완료 로그](assets/inventory_revision_2026-10-27/reactor_refit.log), [네 무기 완료 로그](assets/inventory_revision_2026-10-27/four_weapons.log). 이전 단계의 원본 [리액터 맞춤 정책](assets/pressure_revision_2026-10-27/fit_policy.json)과 비교하며 기존 파일은 보존했다.

다음 구현은 거리 기반 적 배치와 위협 안내다. 파츠 슬롯 확대·일회용 특수탄·비상 보급·관문 씬은 별도 후속 판단이다. 다른 복장별 전체 등반 균형, 작은 가방의 자원 부담, 큰 가방의 특수탄 희석, 실제 교체 선택의 이해·재미, Galaxy 성능/터치는 미검증이다. 자동 완주를 이 검증의 대체로 보지 않는다. APK·커밋·푸시·외부 게시를 수행하지 않았다.
