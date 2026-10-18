# Actor cohesion — current v2

사용자가 표현 기준으로 확정한 현재 주인공은 `reclaimer_grouped_v2.png`다. 배경 정도로 더 뭉개진 표현을 요청받아 색면을 크게 묶고 외곽선/잔묘사를 더 줄였다. 적7종도 `*_grouped_v2.png` 및 `pressure_toad_atlas_v2.png`로 교체했다. `actors.tres`와 원거리 렌더가 현재 자산을 선택한다. 전체 프롬프트는 각 적의 `*-v2-prompt.txt`이며 [실제 통합/검증](../../../../docs/qa/reports/enemy_mass_v2_2026-10-05.md)에 전후 화면을 남겼다. `hero-v2-prompt.txt`와 `provenance.json`에 내장 image_gen의 입력·프롬프트·출처를 남겼다. [v2 실제 비교/검증](../../../../docs/qa/reports/hero_mass_v2_2026-10-05.md).

2026-10-05. 내장 `image_gen.imagegen`으로 제작하고 생성 원본을 바이트 그대로 복사했다. 선택된 캐릭터 디자인을 유지하며 큰 색면과 절제된 내부 명암으로 전투 배우들의 표현을 맞췄다.

아래 v1 파일은 이전 표현의 원본 보존 목록이다.

- `reclaimer_grouped_v1.png`: 이전 주인공. 1254×1254, 기존 캔버스/앵커/0.65 배율 유지.
- `pressure_toad_atlas_v1.png`: 압력두꺼비 2상태. 1774×887, 각 셀 887×887, 왼쪽 수축/오른쪽 팽창. 실제 준비 카운트가 선택한다.
- `runner`, `wall`, `evader`, `caster`, `absorber`, `stance`의 `*_grouped_v1.png`: 기존 적의 개별 수정안. 각 1254×1254. 역할과 실루엣을 유지한다.
- `actors.tres`: 원본을 자르거나 덮어쓰지 않고 Godot 아틀라스 영역과 작은 화면 크기를 지정한다. 비행 적의 기존 부유 오프셋은 전투 렌더가 유지한다.
- `hero-prompt.txt`, `toad-prompt.txt`, 각 적의 `*-prompt.txt`: 도구에 전달한 전체 프롬프트.
- `provenance.json`: 입력 설명, 생성 원본 경로, SHA-256, 크기·알파 분석. 캡처 입력 중간 상태는 이후 QA로 갱신된 경로이므로 최종 캡처와 동일하다고 간주하지 않는다.

PNG의 Python 편집은 하지 않았다. 생성된 제한 팔레트/도트 격자의 엄밀한 준수를 주장하지 않으며, 최종 결과는 실제 전투 크기에서 비교한다. 기존 자산 폴더를 보존한다. [실제 화면·검증](../../../../docs/qa/reports/actor_cohesion_2026-10-05.md).
