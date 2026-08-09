# 🐛 ProjectLoB 버그 트래커

이 문서는 프로젝트 개발 도중 발견되는 결함과 비정상 동작을 추적하는 문서입니다.
모든 버그의 상세 내역은 `reports/` 디렉토리 하위에 개별 버그 리포트 파일로 관리하며, 본 마스터 리스트를 통해 현황을 요약합니다.

## 📌 활성 이슈 (Open / Fixed / Verified)

| 번호 | 제목 | 중요도 | 상태 | 담당 세션 | 생성일 | 해결일 | 리포트 링크 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| #001 | 에이전트 초기 이식 및 정적 링크 검증 | 낮음 | ✅ Closed | - | 2026-06-27 | 2026-06-27 | [링크](#) |
| #002 | Tempo 조율탄 피해 0으로 셋업 효과 미발동 | 보통 | ✅ Closed | `codex0724-smg-role` | 2026-07-24 | 2026-07-24 | [리포트](bug_002_tempo_tuner_zero_damage.md) |
| #003 | 리듬 챔버 6발 연발 보너스 +20 폭증 | 보통 | ✅ Closed | `codex0724-smg-role` | 2026-07-24 | 2026-07-24 | [리포트](bug_003_rhythm_chamber_full_auto_scaling.md) |
| #004 | 보스 차징 카운터가 실전 전투에서 진행되지 않음 | 높음 | ✅ Closed | `codex0726-boss-qa` | 2026-07-26 | 2026-07-26 | [리포트](bug_004_boss_charger_not_advancing.md) |
| #005 | 생존 몬스터의 HP 바가 피격 후 빈 상태로 표시됨 | 보통 | ✅ Closed | `codex0726-enemy-hp-bar` | 2026-07-26 | 2026-07-26 | [리포트](bug_005_enemy_hp_bar_empty_while_alive.md) |
| #006 | 연발 오버킬 이월 피해와 순차 피격 연출의 시점 불일치 | 보통 | ✅ Closed | `codex0726-full-auto-carryover-fx` | 2026-07-26 | 2026-07-26 | [리포트](bug_006_full_auto_carryover_fx_desync.md) |
| #007 | 마지막 적 사망 연출 전에 결과·드래프트 창 표시 | 보통 | ✅ Closed | `codex0726-last-kill-draft-delay` | 2026-07-26 | 2026-07-26 | [리포트](bug_007_last_enemy_death_before_draft.md) |
| #008 | Tempo 6발 설계가 약실 중복으로 실제 7발 적재됨 | 높음 | ✅ Closed | `codex0727-ammo-v6-preflight` | 2026-07-27 | 2026-07-27 | [리포트](bug_008_tempo_effective_capacity_seven.md) |
| #009 | 흡수체 배리어가 관통 실패 명중에도 감소함 | 높음 | ✅ Closed | `codex0727-ammo-v6-runtime` | 2026-07-27 | 2026-07-27 | [리포트](bug_009_absorber_barrier_counts_blocked_hits.md) |
| #010 | 태세 사냥꾼 파훼가 2발 주기 오메가에 발동하지 않음 | 높음 | ✅ Closed | `codex0727-ammo-v6-runtime` | 2026-07-27 | 2026-07-27 | [리포트](bug_010_stance_hunter_misses_omega_interval.md) |
| #011 | 첫 구역 보스 클리어 후 다음 구역 대신 메인 화면으로 복귀 | 높음 | ✅ Closed | `codex0728-continuous-ascent` | 2026-07-28 | 2026-07-28 | [리포트](bug_011_first_section_returns_to_title.md) |
| #012 | 상점 주파수 재요청 후 가운데 파츠의 이전 설명 잔존 | 보통 | 🔍 Verified | `codex0805-shop-reroll-ui` | 2026-08-05 | 2026-08-05 | [리포트](bug_012_shop_reroll_stale_part_description.md) |
| #013 | 기본탄만 사용하면 탄약 효율이 무조건 S등급으로 정산됨 | 높음 | 🔍 Verified | `codex0806-function-accuracy` | 2026-08-05 | 2026-08-06 | [리포트](bug_013_basic_ammo_always_s_grade.md) |
| #014 | 파츠 1개 구매 제한이 리롤 후 초기화됨 | 높음 | 🔍 Verified | `codex0806-function-accuracy` | 2026-08-05 | 2026-08-06 | [리포트](bug_014_part_purchase_limit_resets_on_reroll.md) |
| #015 | 캠페인 보스 노드에 실제 보스가 등장하지 않음 | 높음 | 🔍 Verified | `codex0805-campaign-integrity` | 2026-08-05 | 2026-08-05 | [리포트](bug_015_campaign_boss_nodes_omit_boss.md) |
| #016 | 무작위 보상 풀이 보류·고유 항목을 우회하고 암시장 결제가 소실될 수 있음 | 높음 | 🔍 Verified | `codex0805-campaign-integrity` | 2026-08-05 | 2026-08-05 | [리포트](bug_016_random_reward_pool_bypasses_rules.md) |
| #017 | 제압형 해금 정산에서 무기명이 알 수 없음으로 표시됨 | 낮음 | 🔍 Verified | `codex0809-scan-ammo-guidance` | 2026-08-05 | 2026-08-09 | [리포트](bug_017_suppressor_unlock_unknown_name.md) |
| #018 | 모바일에서 미지 노드 스캔 힌트를 확인할 수 없음 | 높음 | 🔍 Verified | `codex0809-scan-ammo-guidance` | 2026-08-05 | 2026-08-09 | [리포트](bug_018_mobile_scan_hint_hover_only.md) |

---

## 📋 상태 정의
*   **Open (대기)**: 현상이 제보되었고, 재현이 확인되어 해결 예정인 상태.
*   **Fixed (진행)**: 코드 혹은 설정 수정이 완료되어 컴파일 완료 상태이나 아직 테스트 확인 전.
*   **Verified (검증)**: 수정 후 정상 동작이 직접 검증되었으며 유저 확인을 대기 중인 상태.
*   **Closed (해결)**: 검증 완료 후 정상 동작이 확인되어 완전히 종결된 상태.
