# 탄환 데이터 v5 마이그레이션 워크스루

> 완료일: 2026-07-24
> 결과: Phase 12 ③ 완료 — 현대 구경 표기를 유지한 역할 기반 탄환 27종 적용

## 완료 결과

기존 21종 탄환을 27종으로 교체했다. 실제 집합 변화는 단순히 12종을 더한 것이 아니라 **9종 유지 + 12종 교체 + 6종 신규 = 27종**이다. 기존 현대 구경 표기는 세계관 안에서 유산 규격으로 자연스럽게 작동하므로 그대로 두었고, 별도의 “구형 인간 규격” 접두사는 추가하지 않았다.

각 구경에는 기본 운용 외에 셋업과 페이로드 선택지가 생겼다. 시작 덱은 다섯 클래스 모두 `기본탄 + 셋업탄 + 페이로드탄`을 보장한다.

| 클래스 | 기본탄 | 셋업탄 | 페이로드탄 |
|---|---|---|---|
| pistol | `basic_pistol` | `flare_pistol` | `overpressure_pistol` |
| smg | `basic_smg` | `tuner_smg` | `surge_smg` |
| rifle | `basic_rifle` | `shred_rifle` | `heavyslug_rifle` |
| dmr | `basic_dmr` | `marker_dmr` | `burst_dmr` |
| shotgun | `basic_shotgun` | `spread_shotgun` | `dense_shotgun` |

## 함께 개선한 부분

- 탄환 CSV 로더와 검증기를 헤더 기반으로 바꿨다. 중간에 칼럼이 추가돼도 뒤쪽 값을 잘못 읽지 않는다.
- CSV와 27개 `.tres`의 표기명, 설명문, 역할, 모든 전투 수치와 효과 값을 맞췄다.
- 시작 덱 정의를 `RunManager.STARTING_AMMO_IDS`로 모아 클래스별 구성을 한눈에 점검할 수 있게 했다.
- 정비 상점 풀도 `MaintenanceOverlay.SHOP_BULLET_IDS`로 분리해 죽은 ID가 조용히 섞이지 않게 했다.
- 전투 프리로드와 기존 테스트에 남아 있던 구형 ID를 전부 v5 ID로 교체했다.
- 밸런스 가이드의 허용 범위를 v5 페이로드 극단치(DMG 9, ACC 2)까지 반영했다.

## 재발 방지

새 `suite_ammo_integrity`가 다음을 자동 검증한다.

- CSV 27행 ↔ `.tres` 27개 ID 집합 완전 일치
- CSV ↔ 리소스의 표시명·설명·클래스·스탯·효과 완전 일치
- 27종 전부의 CSV 13개 칼럼 ↔ 실제 `DataLoader` 결과 일치
- 폐기 ID 12종의 스크립트·테스트 잔존 여부
- 다섯 클래스 시작 덱의 기본탄·셋업탄·페이로드탄 도달성
- 정비 상점 풀의 CSV 등록 및 리소스 로드 가능 여부

## 검증 결과

- Godot 4.7 리소스 재임포트: 성공
- 전체 자동 검증: **2,324 통과 / 0 실패 / 3 경보**
- 메인 씬 헤드리스 부팅: 성공
- 실제 CSV ↔ 기준 CSV: 동일
- 탄환 CSV 행 수 ↔ `.tres` 수: **27 ↔ 27**

경보 3건은 기존 데이터 밴드 알림(`sentry_drone` HP 4, `nano_stalker` EVA 9, `nano_stalker` HP 4)이며 이번 변경에서 새로 발생한 실패가 아니다.

## 관련 문서

- [마이그레이션 인수인계](file:///D:/ProjectLoB/docs/handoff/ammo_v5_migration.md)
- [탄환 확장 GDD](file:///D:/ProjectLoB/docs/gdd/22_ammo_expansion.md)
- [v5 기준 CSV](file:///D:/ProjectLoB/docs/handoff/reference/ammo_v5.csv)
