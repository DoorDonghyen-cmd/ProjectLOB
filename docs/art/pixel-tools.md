# PixelOE · pixelfx 로컬 제작 도구

사용자 요청으로 2026-11-05 추가했다. 두 원본은 `D:/ProjectLoB/.tools/`에 설치하며 Godot 프로젝트 밖에서 실행한다. 버전·커밋·라이선스 해시·명령은 [도구 잠금 파일](../../tools/art_tooling.lock.json)이 관리한다. 사용 여부는 각 자산의 목적과 [현행 아트 기준](../direction/art-and-ux.md)에 따라 결정한다.

| 도구 | 용도 | 설치 버전·원본 | 확인한 경로 |
|---|---|---|---|
| [PixelOE](https://github.com/KohakuBlueleaf/PixelOE) | 원화의 명암·윤곽을 고려한 픽셀 변환 후보 제작 | 1.0.1 / `7ce444b36d3876a151d845d4493240e904454d89` | CPU CLI 이미지 변환 |
| [pixelfx](https://github.com/patch-gg/pixelfx) | 효과 검색·미리보기·팔레트 조정·투명 시트 출력 | 0.3.0 / `a84159688af3ca37a4be05a0d422b94451b2e24e` | 244개 효과 등록, 탄착·불꽃 시트 출력 및 자체 검사 |

## 바로 실행

활성 저장소 `D:/ProjectLoB/worktrees/core-redesign`에서 실행한다. 파일 이름은 영문·한글 모두 인용부호로 감쌀 수 있다.

**pixelfx 갤러리** — `OPEN_PIXELFX.cmd`를 더블클릭한다. 브라우저에서 `http://127.0.0.1:8766/gallery/`가 열린다. 서버는 이 PC에서만 접속할 수 있다. 기존 UI 목업의 8765 포트와 별개다. 다른 포트를 쓰려면 `OPEN_PIXELFX.cmd -Port 8767`로 실행한다.

```powershell
.\PIXELFX.cmd list bullet
.\PIXELFX.cmd render impacts/bullet-impact --sheet
.\PIXELFX.cmd check impacts/bullet-impact
```

기본 출력은 `qa_runtime/pixelfx_exports/<분류>/<이름>/`이다. `contact.png`와 투명 PNG 시트·JSON을 만든다. `--out`으로 출력 폴더를 바꿀 수 있으며 `--opts` 등 원본 렌더 옵션을 그대로 전달한다. 실제 Godot 적용에는 프레임·재생 속도·원점 정보를 연결하고 현재 전장의 도트 크기와 팔레트로 검수한다. 시트를 내보낸 상태만으로 본편 통합을 완료했다고 보지 않는다.

**PixelOE** — 도움말과 변환 명령은 다음과 같다. `-S`는 변환 후 가로·세로, `-P`는 내부 처리 배율이며 `--no_upscale`로 최종 확대를 생략한다.

```powershell
.\PIXELOE.cmd --help
.\PIXELOE.cmd "원화.png" -O "변환.png" -S 320 200 -P 4 --colors 32 --no_upscale
```

프로젝트 실행기는 원본의 `pixeloe.pixelize` CPU CLI를 호출한다. GPU가 없어도 동작하며, 전용 Python 환경으로 다른 프로젝트 패키지와 분리했다. 이 CLI는 원본에서 legacy로 분류한다. 투명 알파를 보존하는 변환 경로가 아니므로 불투명 원화에 사용한다. 투명 캐릭터·UI 자산의 알파 유지나 프레임 간 일관성은 별도 검증이 필요하다. `--colors` 이후 색상 매칭이 수행되므로 최종 색 수가 지정 값으로 엄격히 제한된다고 가정하지 않는다.

현 설치의 Torch는 CPU 빌드다. Torch·torchvision·kornia·slangpy 가져오기를 확인했으며, Slang은 Python 실행 파일(C:)과 SDK(D:)의 드라이브 차이로 D3D12 Agility 경고를 표시한다. GPU 변환·컴파일 경로는 검증하지 않았다. 확인된 CPU CLI에는 이 경로가 필요 없다.

## 설치 복구와 검사

Python 3.13 x64, Node.js 18 이상, Git이 필요하다. 현재 검증 환경은 Python 3.13.15 / Node.js 24.14.1 / Windows다. 인터넷 연결이 가능한 환경에서 다음을 실행한다.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/install_pixel_tools.ps1
python tools/check_pixel_tools.py
```

설치기는 잠금 파일의 커밋을 사용하고 PixelOE 의존성 버전도 고정한다. 이미 다른 버전이나 수정된 원본이 있으면 덮어쓰지 않고 중단한다. pixelfx의 갤러리와 PNG 시트 출력에는 npm 패키지 설치가 필요 없다. 새 효과 제작 안내는 원본 `skills/pixelfx/SKILL.md`에 보존하며 LoB의 전역 작업 지침으로 자동 등록하지 않았다.

검사는 `qa_runtime/pixel_tools_20261105/report.json`에 기록한다. 소스 커밋·라이선스 사본, 패키지 정합성, 실제 RGB 이미지 변환과 입력 보존, 효과 시트의 알파·프레임 좌표·재생 시간, 원본 효과 검사를 확인한다. 게임 저장이나 본편 에셋을 수정하지 않는다.

갤러리 종료는 `qa_runtime/pixelfx_gallery/server.pid`의 프로세스 번호를 확인한 뒤 작업 관리자에서 해당 Node 프로세스를 종료하면 된다. PC 재시작 후에는 실행기를 다시 연다.

## 라이선스

- PixelOE는 Apache-2.0이다. [원문 사본](../../tools/notices/pixeloe/LICENSE)을 보존했다.
- pixelfx 효과 코드는 MIT다. [LICENSE](../../tools/notices/pixelfx/LICENSE)와 [NOTICE](../../tools/notices/pixelfx/NOTICE.md)의 파생 코드 출처를 함께 보존했다.
- 갤러리의 Patch Pixel 글꼴은 MIT 대상에서 제외된다. [별도 고지](../../tools/notices/pixelfx/gallery/fonts/NOTICE.md)를 보존했으며 게임 글꼴로 가져오지 않았다.

현재 추가 범위는 로컬 제작 도구다. 효과나 변환 이미지를 실제로 채택할 때 해당 자산의 출처·변환 설정·검수 결과와 필요한 고지를 연결한다.
