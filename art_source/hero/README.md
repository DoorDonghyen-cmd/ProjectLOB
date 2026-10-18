# 주인공 자세 원본과 게임 반영

현재 승인된 `reclaimer_actions_v1.png`의 네 자세를 **픽셀 변경 없이** `reclaimer_actions.ase`로 보존했다. 네 자세가 2×2로 놓인 한 장의 편집 원본이다. 타임라인 프레임이나 중간 동작을 새로 생성한 것은 아니다. 실제 재생 시점은 기존 Godot 동작 흐름을 사용한다.

저장소 루트에서:

```powershell
python tools/pixel_editor.py art_source/hero/reclaimer_actions.ase
python tools/export_hero_animation.py
python tools/export_hero_animation.py --check
```

1. LibreSprite에서 해당 원본을 편집한다. 원본은 게임 내보내기에 포함되지 않는 저장소 `art_source/`에 있다.
2. 발 위치·총구 위치를 바꾸면 `poses.json`에서 해당 자세의 `anchor`·`muzzle`을 함께 수정한다. 값은 627×627 각 셀 내부 좌표다.
3. 내보내기는 임시 영역에서 PNG와 메타데이터를 먼저 검증한 뒤, 실제 게임의 PNG와 `redesign/hero_pose_data.gd`를 갱신한다. 후자는 자동 생성물이므로 직접 고치지 않는다.
4. `--check`는 원본 재출력과 게임 그림의 RGBA 일치 및 자세 데이터 최신 여부를 검사한다. 게임 파일은 수정하지 않는다.
5. `powershell -ExecutionPolicy Bypass -File tools/run_actor_motion_checks.ps1`로 실제 조준·반동·재장전·강제 냉각·건너뛰기와 발/총구 정렬을 확인한다. 산출물은 `qa_runtime/actor_motion/`에 있다.

현재 출력 규격은 1254×1254/2×2다. 이 원본의 등록 좌표를 보존하기 위한 규격이며 모든 향후 아트의 영구 해상도 기준이 아니다. 중간 동작을 추가할 때는 별도 타임라인 원본과 재생 규칙을 먼저 설계한다. Importality와 Pixelorama는 설치하지 않았다. 기존 LibreSprite만으로 이 경로를 검증했다.
