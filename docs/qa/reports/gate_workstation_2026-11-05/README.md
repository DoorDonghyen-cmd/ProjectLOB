# 정비소 구도를 적용한 관문 시안

정비소처럼 차단문, 캐릭터, 조작대를 같은 가로 장면에 놓았다. 상단은 구역과 진행 단계, 하단은 작업 후보, 오른쪽은 선택한 작업의 전후 수치와 실행 버튼을 맡는다. 정비소의 Godot Theme와 기존 픽셀 아이콘을 사용했다.

`OPEN_GATE_REVIEW.cmd -Workstation`을 실행하면 이 시안이 열린다. F1은 개조, F2는 재정비에서 시작한다. 기본 실행은 [문 옆 출발을 적용한 시안](../gate_threshold_2026-11-05/README.md)이다. 첫 분할 화면은 `OPEN_GATE_REVIEW.cmd -Classic`으로 열 수 있다. 각 시안은 동일한 관문 규칙을 사용한다.

| 비교 화면 | 1280×800 |
| --- | --- |
| 정비소 기준 | [탄환 압축](../workbench_remove_display_2026-11-04/compression.png) |
| 처음 만든 관문 | [개조](../gate_review_2026-11-05/upgrade_1280x800.png) |
| 정비소 구도의 관문 | [개조](upgrade_1280x800.png) · [재정비](service_1280x800.png) · [개방](depart_1280x800.png) |

[작은 가로 창](service_1008x454.png) · [S26 가로 크기](upgrade_2340x1080.png) · [전용 탄약 생산](production_1280x800.png).

## 검증 범위

격리 세션에서 실제 Campaign의 개조, 탄약 생산, 유료 정비, 다음 구역 이동을 실행했다. PC에서 1280×800, 1008×454, 2340×1080으로 실행했고 `-Capture -Workstation` 검사 112개와 `-Capture -Classic` 검사 102개를 통과했다. 본편 연결과 Galaxy S26 실기 확인은 이후 범위다.

## 배경 제작 기록

내장 ImageGen으로 만든 [가로 관문 장면](../../../../새-게임-프로젝트/assets/art/gate_review_20261105/workstation.png). 기존 관문과 정비소의 배경을 화풍과 구조의 참고로 사용했다. 관문 문짝의 이동, 운반 복장 캐릭터, 정보와 조작은 Godot에서 합성했다.

> Landscape 16:10, polished original low-resolution chunky pixel-art interior for ORVASK. The first supplied image is the existing gate design, match its doorway architecture and amber lighting; the second is the project's workshop visual reference, match its quiet detailed foreground, muted charcoal-brown ochre and dark edges. Compose a new wide scene, no UI. The existing massive rectangular OPEN sliding door is centered at x 36% of the landscape, with a clean rectangular aperture from x about 21% to 48%, y about 24% to 76%, visible in front elevation. Through it the same orange-lit vertical factory catwalk and distant tower, with clean straight rectangular front aperture. To the right around x 64%-94%, extend the room as a practical narrow maintenance station set against the SAME industrial wall: a sturdy dark steel bracket-mounted gate control cabinet with a few square mechanical indicator bulbs, a cable drum and a small waist-high service bench. No monitor text, no bright neon, no overt controls UI. Keep this upper right third subdued and dark enough for an in-engine panel. One continuous dark metal floor with a little warm reflected light, visually grounded. Dark top 12% and floor at bottom 16% to allow later UI. Avoid symmetrical framing, bloom or fog, extra doors, fantasy architecture, cinematic photorealism, people, text, lettering, logos or any UI. Flat stepped pixel clusters and strong dark negative space.
