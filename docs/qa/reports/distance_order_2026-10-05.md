# 전투 거리와 화면 배치 역전 수정 — 2026-10-05

상태: 재현 → 수정 → 기능·실제 화면 검증 완료. 수정본의 사용자 플레이 확인은 후속.

사용자 제보는 13m 적이 9m 적보다 플레이어에 가깝게 보이는 현상이다. 실제 표적 계산은 9m 적을 선택했지만, 화면은 적의 고정 lane에 따라 가로 좌표를 96픽셀씩 더해 거리 순서를 뒤집었다. 압력탄에도 발사한 적의 lane 보정과 별도 거리 곡선이 적용되어 같은 오해가 생길 수 있었다.

## 재현

- 브랜치: `prototype/core-redesign` 작업 트리, Godot 4.7 Compatibility. 기존 미커밋 변경 보존.
- 본편 `redesign/main.tscn`, 무기 `single`, 시드 731042, 진입 노드101. 회귀 검사에 재현 편성 A13/B24/C28/D9m을 주입했다.
- 1280×900, 전장 내부 너비1260: 수정 전 A13m의 x472, D9m의 x672. 13m 적이 200픽셀 앞에 보였지만 실제 표적은 D였다.
- 수정 후 같은 편성: D9m의 x466, A13m의 x632. 명찰과 실제 표적도 같은 순서다.
- [수정 전](distance_order_2026-10-05_assets/before_13m_9m.png), [수정 후 같은 해상도](distance_order_2026-10-05_assets/after_13m_9m_1280.png), [작은 화면](distance_order_2026-10-05_assets/after_13m_9m_1008.png).

## 변경

`battle_view.gd`에서 실제 거리 순으로 적·압력탄을 배치한다. 겹치는 몸체는 순서를 유지한 채 간격을 확보하고, 먼 쪽 화면 경계를 넘으면 같은 순서로 안쪽에 배치한다. 동일 거리에서는 실제 표적 선정과 같이 압력탄을 우선하고 적은 고유 배열 순서를 따른다. 명찰도 그 배치를 따라간다. `ranged_battle_view.gd`의 별도 좌표식을 제거해 같은 축을 사용한다.

지면 높이와 적의 식별자는 유지한다. 쓰러진 적의 마지막 좌표는 타격 표시가 끝날 때까지 보존한다. 화면 간격은 겹침 방지를 위해 보정되므로 픽셀 간격이 미터에 항상 정비례하지는 않으며, 서로 다른 거리의 앞뒤 관계는 보존한다. 전투 계산·난수·저장 구조·밸런스 수치는 변경하지 않았다.

## 검증

- `powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_distance_order_checks.ps1`: **1,492검사 / 0실패**. 1280×900, 1008×630, 1440×630.
- 9/13m 역전 편성, 뒤섞인 lane, 동일1m/32m, 표시 범위보다 먼33~45m, 압력탄6/9/11/13/25/32m, 동거리 요격 우선순위, 명찰 비중첩·순서, 적 중심 선택, 화면 경계를 검증했다.
- 공개 장전/확정/발사 입력으로 밀치기에 따른 순위 변경, 서로 다른 접근 속도로 추월, 처치 후 실제 증원을 확인했다. 진행 중 **123프레임의 거리 역전 0건**. 최종 표시 적 상태와 모델 일치.
- 기존 `run_actor_cohesion_checks.ps1`: **350검사 / 0실패**. 적7종, 3해상도, 개구리 준비·발사·요격·차단, 몸체·명찰·선택 영역 유지.
- 실제 캡처를 열어 [동거리4마리](distance_order_2026-10-05_assets/after_equal_distance_1008.png), [전방 압력탄](distance_order_2026-10-05_assets/after_projectile_front_1008.png), [증원 후 배치](distance_order_2026-10-05_assets/after_deployment.png)를 확인했다.
- 격리 `qa_runtime/distance_order/` 및 `qa_runtime/actor_cohesion/` 저장, `save_enabled=false`. 사용자 저장에 접근하지 않았다.
- [거리 검사 로그](distance_order_2026-10-05_assets/after_stdout.log), [기존 회귀 로그](distance_order_2026-10-05_assets/actor_regression_stdout.log). 스크립트 오류 없음. 기존 Windows 루트 인증서 읽기 경고만 존재한다. `git diff --check` 통과.

이는 자동 기능 검사와 화면 검수이며 Galaxy 실기기·장시간 플레이 검증은 아니다. APK 생성·커밋·푸시는 수행하지 않았다. 실행 경로는 기존 `PLAY.cmd`다.
