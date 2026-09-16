# 무기 4종 개편 QA

2026-09-16, Godot 4.7 / Windows / GL Compatibility. 모든 자동 검증은 `qa_runtime` 아래 별도 프로필을 사용한다. 실제 사용자 저장과 기존 제작본 진행을 변경하지 않는다.

## 최종 결과

최종 수치 조정(+1 초과 관통) 이후 검증을 완료했다. 원본 명령과 집계는 [summary.json](weapon_archetypes_2026-09-16_assets/summary.json), [실제 캠페인 명령](weapon_archetypes_2026-09-16_assets/weapon_campaign_report.json)에 보관한다.

| 검증 | 결과 |
|---|---|
| 무기 정산/독립 피해 표/기본탄 주기 | 490검증 / 0실패 |
| 전체 규칙·예측·저장 회귀 | 24,141 / 0 |
| 새 무기 최종 35층 캠페인 | 27,082 / 0 · 10완주 |
| 기존 두 무기 10런 실제 명령 재생 | 28,755 / 0 · 전투 히스토리 동일 |
| 최종 실제 UI 35층 | 3,391 / 0 · 2완주 · 1,110버튼 |
| 네 무기 선택/정보/비교/사격/재개 합성 터치 | 165 / 0 |
| 산개 6칸/압쇄 5칸과 작은 가로 화면 | 364 / 0 |
| 기존 탄환/조합/화상 시각 회귀 | 174 / 0 |
| 기존 제작본 전체 회귀 | 3,730 / 0 · 기존 경보3 |

새 캠페인은 시드731042/17의 두 경로와 난도10 시드90210을 사용한다. 매 사례 35개 방을 방문해 최종 코어에 도달했다.

| 무기 | 시드 | 경로 | 난도 | 턴 | 발사 탄 | 잔여Cr | 최종 칸 |
|---|---:|---|---:|---:|---:|---:|---:|
| 산개 | 731042 | 계단 중심 | 0 | 238 | 206 | 157 | 6 |
| 산개 | 731042 | 혼합 | 0 | 148 | 125 | 243 | 6 |
| 압쇄 | 731042 | 계단 중심 | 0 | 214 | 177 | 157 | 5 |
| 압쇄 | 731042 | 혼합 | 0 | 122 | 102 | 246 | 5 |
| 산개 | 17 | 계단 중심 | 0 | 234 | 202 | 157 | 6 |
| 산개 | 17 | 혼합 | 0 | 173 | 152 | 197 | 6 |
| 압쇄 | 17 | 계단 중심 | 0 | 207 | 180 | 167 | 5 |
| 압쇄 | 17 | 혼합 | 0 | 135 | 117 | 203 | 5 |
| 산개 | 90210 | 혼합 | 10 | 161 | 139 | 201 | 6 |
| 압쇄 | 90210 | 혼합 | 10 | 128 | 108 | 201 | 5 |

계단 중심 경로는25교전, 혼합은16교전이다. 표의 턴/탄 수는 같은 수의 전투를 비교할 때만 의미가 있다. 네 무기의 출발 덱과 버스트 거리 보정이 달라 총 턴만으로 성능 우열을 판정하지 않는다.

## 중요한 검증

무기 규칙 검증은 실제 명령을 호출한다. 같은 명령을 복사 모델로 예측하고 주 피해/보조 피해/HP/화상/거리/최종 단계/무작위 상태 불변을 비교한다. 독립 표로 압쇄의 장갑 0~6 피해와 초과 관통 상한을 검증하고, 실제 한 탄창 사격+재장전 주기로 보행자와 압쇄의 무장갑/장갑 템포를 비교한다.

캠페인 완주는 QA 전용 제한 탐색기로 모델 상태에서 합법적인 장전 순서를 찾고 실제 명령을 실행한다. 탐색 복제에는 이후 패/무작위 상태도 포함되므로, 플레이어에게 보이는 정보만 사용하는 블랙박스 경험 테스트가 아니다. 매 명령마다 원자 저장과 전체 상태 복원을 비교한다. 승리/적 HP를 강제하지 않는다. 기존 제작본 단위 회귀에 사용하는 고정 승리 픽스처는 이 새 완주의 근거에 포함하지 않는다.

전체 UI 완주는 검증된 외부 명령을 실제 화면의 버튼으로 재실행하여 캠페인/전투/프로필 전체 히스토리를 비교한다. 중간 저장 재개와 기록실/재시작/상점 구매 한도도 확인한다. 별도 165검증은 실제 합성 터치로 네 선택/정보/개발자/사격/이어 하기를 확인한다.

최종 용량 레이아웃은 실제 합법 명령으로 첫 관문 성장 +2칸까지 진행한 상태를 렌더링한다. 산개는 6칸, 압쇄는 5칸이다. `city_six_slot_*_heavy.png`는 기존 QA 파일명 관례가 남아 있지만 실제 화면과 검증은 5칸이다. 이 레이아웃 검증은 전체 UI 완주 증거와 별개다.

## 수정된 검증/화면 문제

- WPN-01: 메뉴 HBox의 자동 줄바꿈 제목이 최소 폭을 확보하지 못해 겹치는 문제를 수정하고 화면을 직접 확인했다.
- 기존 공식 테스트가 새 압쇄에도 기존 두 무기 공식을 기대하던 실패는 무기 규칙에 맞춘 독립 기대 식/표로 확장했다.
- 긴 개발자 팝업의 화면 밖 버튼을 터치하던 드라이버 실패는 실제 스크롤 후 터치로 고쳤다.
- 상대 경로 보고서 입력 실패와 이후 실행이 끝나지 않던 QA 도구는 절대 경로 해석/입력 검증/즉시 실패로 고쳤다.

## 재현

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_weapon_checks.ps1 -Mode rules
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_weapon_checks.ps1 -Mode ui
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_city_checks.ps1 -Mode campaign -Weapons scatter,heavy -Seed 731042 -RunName weapons_final
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_city_checks.ps1 -Mode campaign -Weapons scatter,heavy -Seed 17 -Hard -RunName weapons_final_extra
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_city_checks.ps1 -Mode ui -RunName weapons_final -UISource qa_runtime/city/campaign_weapons_final/city_campaign_report.json
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_city_checks.ps1 -Mode ui -RunName weapons_final -LayoutOnly -UISource qa_runtime/city/campaign_weapons_final/city_campaign_report.json
```

## 한계

기능상 완주 경로, 결정론과 정보 전달을 확인한 결과다. 최적 전략/승률이나 사람의 재미를 입증하지 않는다. 최종 네 무기의 균형, 전용 파츠 필요성, 맵/보상 선택 차이, 35층 호흡은 실제 비교 플레이로 조정한다. 현재 탄환 7종과 공통 파츠를 사용하는 첫 4종이며 전용 탄환 풀은 없다. 최종 아트/사운드와 실제 Galaxy 성능은 별도 후속 단계다. APK와 원격 푸시는 수행하지 않았다.
