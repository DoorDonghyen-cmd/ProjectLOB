# 처마등 동작 원본

승인 처마등의 겹등판·낮은 몸을 참조한 **4개 키포즈 / 4개 태그** 타임라인이다. `idle` 1프레임, `walk` 2프레임 반복, `hit` 1프레임, `attack` 1프레임이다. 부드러운 다프레임 완성 애니메이션은 아니다. 원래 정지 시안은 기존 경로에 보존된다.

`eavesback.ase`가 편집 원본이며 태그와 프레임 시간은 이 파일에서 읽는다. `animation.json`의 발 좌표·표시 배율·루프 여부는 별도 등록 정보다. `initial_durations_ms`와 from/to는 최초 포장용 값이며 편집 후 내보내기는 실제 ASE의 시간/태그 범위를 읽는다.

```powershell
python tools/pixel_editor.py art_source/monsters/eavesback/eavesback.ase
python tools/export_monster_animation.py
python tools/export_monster_animation.py --check
```

내보내기는 LibreSprite로 임시 PNG/JSON을 출력하고 태그·프레임 시간·셀 크기·발 좌표를 검사한 뒤 Godot PNG/SpriteFrames/좌표 데이터를 갱신한다. `--check`는 게임 파일을 쓰지 않는다. 프레임 추가 시 `anchors`도 추가한다. 4태그 이름과 정방향 재생은 현재 어댑터의 계약이다. 게임 원본 PNG를 별도로 손으로 고치지 않는다. `--initialize`는 원본을 처음 포장할 때만 쓰며 이미 있는 ASE를 덮어쓰지 않는다.

생성 도구가 투명 경계에 흐린 알파를 남겨, 런타임 전용 `monster_alpha_cutout.gdshader`가 0.5 미만의 알파를 버리고 내부를 불투명하게 표시한다. 원본 RGBA는 변경하지 않는다. 처치 시 전체 투명도는 이 처리와 분리했다. 외부 일반 뷰어에서 보는 keyposes PNG와 게임의 외곽은 다르다.

Godot의 `res://redesign/samples/eavesback_animation_preview.tscn`을 열면 native AnimatedSprite2D로 태그와 시간을 확인할 수 있다. 전투에서는 같은 SpriteFrames를 턴 이벤트의 표현 시간에 맞춰 샘플링한다. 발 고정/턴 결과는 Model이 맡고 그림이 결과를 계산하지 않는다.

생성 도구/전체 프롬프트/참조 역할은 [provenance.json](provenance.json)에 있다. [실제 전투와 검증](../../../docs/qa/reports/monster_motion_2026-10-11.md)은 저장소 루트의 docs에서 확인한다.
