# 🐛 ProjectLoB 버그 트래커

이 문서는 프로젝트 개발 도중 발견되는 결함과 비정상 동작을 추적하는 문서입니다.
모든 버그의 상세 내역은 `reports/` 디렉토리 하위에 개별 버그 리포트 파일로 관리하며, 본 마스터 리스트를 통해 현황을 요약합니다.

## 📌 활성 이슈 (Open / Fixed / Verified)

> 2026-09-12: 텍스트 과밀 피드백은 UX 개선으로 처리. 화면49·연출39·전체UI493 검사와 독립 화면 검토에서 신규 확정 기능 버그 없음. 기존 VIS-01 상태 유지.

| 번호 | 제목 | 중요도 | 상태 | 담당 세션 | 생성일 | 해결일 | 리포트 링크 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| VIS-02 | 가까운 적의 거리 글자가 아래 적 몸체와 중첩 | 보통 | 🔍 Verified | `codex0912-multi-target` | 2026-09-12 | 2026-09-12 | [리포트](bug_multi_target_distance_overlap.md) |
| VIS-01 | 다중 적 정보와 피격 문구의 글자 중첩 | 보통 | 🔍 Verified | `codex0911-visual-combat` | 2026-09-11 | 2026-09-11 | [리포트](bug_visual_combat_label_overlap.md) |
| RD-01 | 큰 시드 저장 재개 후 다음 교전 패 변경 | 보통 | 🔍 Verified | `codex0911-core-redesign` | 2026-09-11 | 2026-09-11 | [리포트](bug_core_seed_precision.md) |
| RD-02 | 비정상 저장이 4칸 총기에 5발 계획을 허용 | 보통 | 🔍 Verified | `codex0911-core-redesign` | 2026-09-11 | 2026-09-11 | [리포트](bug_core_save_capacity.md) |
| RD-03 | 재설계 UI의 행동 노출과 수치 기준 불명확 | 보통 | 🔍 Verified | `codex0911-core-redesign` | 2026-09-11 | 2026-09-11 | [리포트](bug_core_ui_readability.md) |
| RD-04 | 개발자 연습에서 같은 시드 재시도 시 저장 경계 해제 | 보통 | 🔍 Verified | `codex0911-core-redesign` | 2026-09-11 | 2026-09-11 | [리포트](bug_core_practice_retry.md) |
| #025 | 실제 전투의 적 복제가 CSV 기준 스탯을 누락 | 높음 | 🔍 Verified | `codex0911-tactical-workbench` | 2026-09-11 | 2026-09-11 | [리포트](bug_025_enemy_copy_skips_csv.md) |
| #026 | 전투 중 추가 장전 후 일부 닫기 경로에서 적 전진 비용 누락 | 높음 | 🔍 Verified | `codex0911-tactical-workbench` | 2026-09-11 | 2026-09-11 | [리포트](bug_026_drawer_close_bypasses_insertion_tax.md) |
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
| #019 | 4체 편성 몬스터의 시각적 바닥선 불일치 | 보통 | 🔍 Verified | `codex0911-preart` | 2026-08-15 | 2026-09-11 | [리포트](bug_019_enemy_formation_baseline_misalignment.md) |
| #020 | 연발 넉백 증폭·선제 효과의 예산 우회 | 높음 | 🔍 Verified | `codex0911-preart` | 2026-09-11 | 2026-09-11 | [리포트](bug_020_burst_knockback_budget_bypass.md) |
| #021 | 최종 관문 뒤 36층으로 메타 보상 과다 정산 | 높음 | 🔍 Verified | `codex0911-preart` | 2026-09-11 | 2026-09-11 | [리포트](bug_021_summit_floor_overpayment.md) |
| #022 | 암시장 업그레이드 설명과 분해 환급 효과 불일치 | 낮음 | 🔍 Verified | `codex0911-preart` | 2026-09-11 | 2026-09-11 | [리포트](bug_022_meta_refund_label.md) |
| #023 | 첫 장전 화면에서 사용할 수 없는 리로드 안내 | 보통 | 🔍 Verified | `codex0911-preart` | 2026-09-11 | 2026-09-11 | [리포트](bug_023_initial_loading_hint.md) |
| #024 | 경험 QA 행동 결과 누락 및 구매 방문 오분류 | 보통 | 🔍 Verified | `codex0911-preart` | 2026-09-11 | 2026-09-11 | [리포트](bug_024_experience_outcome_missing.md) |

---

## 📋 상태 정의
*   **Open (대기)**: 현상이 제보되었고, 재현이 확인되어 해결 예정인 상태.
*   **Fixed (진행)**: 코드 혹은 설정 수정이 완료되어 컴파일 완료 상태이나 아직 테스트 확인 전.
*   **Verified (검증)**: 수정 후 정상 동작이 직접 검증되었으며 유저 확인을 대기 중인 상태.
*   **Closed (해결)**: 검증 완료 후 정상 동작이 확인되어 완전히 종결된 상태.
