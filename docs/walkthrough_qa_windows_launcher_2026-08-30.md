# QA 대시보드 Windows 실행 파일 런처 완료 워크스루

## 결과

프로젝트 루트에 `ProjectLoB-QA.exe`를 생성했다. 파일을 더블클릭하면 기존 QA PowerShell
컨트롤러를 시작하고 `http://127.0.0.1:8765/`가 준비된 뒤 기본 브라우저를 자동으로 연다.
함께 열린 콘솔 창을 닫거나 `Ctrl+C`를 누르면 컨트롤러를 종료할 수 있다.

런처는 자신이 놓인 위치부터 상위 폴더를 탐색하므로 현재 작업 폴더에 의존하지 않는다.
필수 컨트롤러·실행기·대시보드 파일이 누락됐거나 명시한 Godot 경로가 잘못되면 QA를
시작하지 않고 오류로 종료한다.

## 제공 파일

- `ProjectLoB-QA.exe`: 더블클릭 실행 파일, 11,776 bytes, 버전 1.0.0.0
- `tools/qa_launcher/Program.cs`: 런처 정본 소스
- `tools/build_qa_launcher.ps1`: Windows 기본 C# 컴파일러 기반 재빌드 스크립트
- `docs/qa/dashboard/README.md`: 실행 파일과 명령줄 옵션 안내

## 옵션

```powershell
.\ProjectLoB-QA.exe --check
.\ProjectLoB-QA.exe --probe
.\ProjectLoB-QA.exe --port 8877
.\ProjectLoB-QA.exe --godot "C:\path\to\Godot_v4.x-stable_win64_console.exe"
```

## 검증

- 빌드 직후 `--check`: 필수 파일 및 저장소 경로 확인 성공
- `C:\tmp`에서 EXE 자체 점검: `D:\ProjectLoB` 저장소 탐색 성공
- `--probe --port 8879`: Godot 4.7 console 자동 탐지, localhost 응답 성공
- probe 종료 후 포트 8879 닫힘 확인
- 제품 메타데이터: `ProjectLoB QA`, 파일 버전 `1.0.0.0`

이 파일은 서명되지 않은 내부 개발 도구이므로 다른 PC로 복사할 경우 Windows SmartScreen
경고가 표시될 수 있다. 또한 저장소와 Godot가 필요하므로 단독 배포본으로 사용할 수 없다.
