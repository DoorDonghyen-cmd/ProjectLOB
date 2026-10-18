# APK 요청 → ZIP → Google Drive 전달

사용자가 APK를 요청하면 아래 전체 흐름을 실행한다. 별도 업로드 요청을 반복해서 받지 않는다. 요청 없이 APK를 만들거나 배포하는 예약 작업은 아니다.

빌드는 로컬 스크립트, 업로드와 읽기 검증은 연결된 Google Drive 앱을 사용하는 에이전트가 담당한다. `BUILD_MOBILE.cmd` 단독 실행은 검증된 ZIP 생성까지 수행한다. OAuth 키·토큰을 저장소나 스크립트에 넣지 않는다.

## 실행

1. 활성 작업 트리와 현재 플레이 변경 사항을 확인하고 짧은 변경 내역을 준비한다. 기존 사용자 변경과 실제 저장을 유지한다.
2. `tools/mobile_delivery.json`의 Drive 폴더를 `google_drive_get_file_metadata`로 확인한다. 연결 계정에서 접근되는 실제 폴더인지 확인하며 기존 공유 권한을 바꾸지 않는다. 폴더가 사라졌으면 검색으로 확인한 뒤 새 전용 폴더를 만들고 설정을 갱신한다.
3. 아래 명령으로 빌드한다. `NotesFile`에는 해당 버전의 플레이 변경 사항을 넣는다.

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File tools/build_mobile_release.ps1 -NotesFile docs/releases/2026-10-04-mobile.md
   ```

   이후 빌드는 날짜에 맞는 노트를 사용하거나 옵션을 생략한다. `BUILD_MOBILE.cmd`도 같은 진입점이다. 64비트 Galaxy용으로 용량을 줄일 때는 `-Architecture arm64`를 지정한다. 기본 `universal`은 ARM64와 ARMv7을 모두 포함한다. SDK 자동 경로가 격리 환경으로 바뀌면 `-AndroidSdk <실제 SDK 경로>`를 지정할 수 있다.
4. `builds/mobile/latest.json`의 `zip_path`, `file_name`, `parent_folder_id`로 `google_drive_upload_file`을 호출한다. MIME은 `application/zip`, `file_uri`는 런타임 도구 스키마에 따라 로컬 ZIP 절대 경로를 사용한다. 공개 공유를 켜지 않는다.
5. 응답 ID로 `google_drive_get_file_metadata`를 다시 호출한다. 파일명·크기·MIME·부모 폴더·URL·체크섬을 요청한다. 메타데이터를 해당 release 폴더의 `drive_metadata.json`에 보존한다.
6. 연결 도구가 체크섬을 생략하면 `google_drive_fetch(download_raw_file=true, include_base64=false)`로 해당 파일을 내려받아 SHA-256을 비교한다. 메타데이터를 읽기 전에 원본 파일 다운로드를 시작하지 않는다.
   `file_uri.download_url`이 반환되면 해당 임시 HTTPS URL의 파일을 release 폴더의 `drive_readback.zip`으로 내려받는다. 이 런타임에서는 일반 HTTP `User-Agent: Mozilla/5.0` 헤더가 필요했으며 Python 기본 헤더는 HTTP 403이었다. 만료된 URL은 fetch로 갱신한다. 서명된 임시 URL을 저장소·영구 기록에 남기지 않는다.
7. 다음으로 검증 완료 영수증을 기록한다. 원격 체크섬이 있는 경우 `--downloaded`를 생략할 수 있다.

   ```powershell
   python tools/mobile_release.py record-upload --release <release-folder> --metadata <drive_metadata.json> --downloaded <downloaded-zip>
   ```

8. `upload_receipt.json`과 `latest.json`의 `uploaded`를 확인한 뒤 실제 도구에서 받은 Drive URL을 사용자에게 전달한다. 설치는 ZIP 압축 해제 후 APK 업데이트이며 기존 앱 삭제를 요구하지 않는다. 실제 기기에서 검증하지 않았다면 기기 테스트 완료로 표현하지 않는다.

## 빌드와 실패 처리

- Godot 4.7·Android 템플릿·SDK·JDK와 기존 서명을 검사한다. 동일 패키지 ID와 인증서를 유지하고 버전 코드는 이전 로컬 빌드보다 올린다.
- export preset은 임시 추가 후 원본 바이트로 복구한다. 프로세스 강제 종료 시에는 preset을 확인하고 임시 항목만 복구한다. 동시 빌드는 잠금으로 막는다.
- APK 서명·정렬·패키지·ABI, 전체 ZIP CRC와 필수 리소스를 검사한다. APK에 든 컴파일 리소스로 실제 메인 씬과 전투 기본 규칙을 격리 저장에서 실행한다. 이는 Android 기기 실행 검사와 구별한다.
- 배포 ZIP에는 APK·설치 안내·변경 내역·빌드/검증 manifest·SHA-256 목록만 들어간다. 소스, 저장 데이터, QA 프로필, 에디터 설정, 서명 키는 넣지 않는다.
- 빌드별 고유 폴더와 ZIP을 유지한다. 업로드 실패 시 같은 `delivery_request.json`과 ZIP으로 재시도하고 APK를 다시 만들지 않는다.
- 연결 도구의 파일당 업로드 상한은 100MiB(`104857600`바이트)이며 포장 단계에서 검사한다. 사용되지 않는 리소스만 배포에서 제외하며 기존 아트 원본은 보존한다. 제외 목록은 `tools/mobile_export_exclusions.json`의 명시적 경로로 관리한다. 목록을 바꾸면 코드·씬·리소스 참조와 동적 로드 경로를 확인한다. 현행 아트 및 동적으로 사용하는 `production_20261002`, `pixel_20261003`는 유지한다. ARM64 전용 빌드는 32비트 Android에서 실행되지 않으므로 전달 시 명시한다. 서명과 패키지 ID는 동일하게 유지한다.
- 업로드 응답을 받지 못했다면 같은 부모 폴더에서 정확한 파일명으로 먼저 검색한다. 일치 파일의 크기/체크섬을 검증해 재사용한다. 없다는 것이 확인된 뒤에만 재업로드한다. 업로드 응답 ID가 있으면 그 ID부터 읽는다.
- 연결 인증 실패는 로컬 파일 생성 실패가 아니다. ZIP 경로와 재시도 상태를 보존하고 계정 재연결이 필요한 사실을 알린다. 확인되지 않은 URL이나 업로드 성공을 만들지 않는다.

## 로컬 경로

- `builds/mobile/releases/<build-id>/`: APK·ZIP·로그·검증·업로드 영수증
- `builds/mobile/latest.json`: 최신 패키지 경로와 전달 상태
- `tools/mobile_delivery.json`: 고정 폴더 ID와 서명 지문. 인증정보는 없음.
- `python -m unittest discover -s tools -p test_mobile_release.py`: ZIP 허용 목록과 잘못된 업로드/체크섬 거부 검사
