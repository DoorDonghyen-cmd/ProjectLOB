# 전체 본편 Android 테스트 전달 · 2026-11-06

사용자 요청으로 현재 작업 트리를 ARM64 APK로 내보내고 기존 Google Drive 모바일 폴더에 전달했다. 실제 Android 기기 실행은 미검증이다.

- 빌드 `LastOnBoard-20261106-140337-v20261106`, 버전 `0.5.20261106.full`, 코드 `20261106`.
- 모드 `campaign`, 시작 씬 `res://redesign/main.tscn`. 5구역 전체 본편이다.
- 패키지 `com.lastonboard.prototype`, 기존 테스트 인증서/서명을 유지한다. Godot 4.7 / ARM64 / GL Compatibility.
- APK 210,579,375바이트. SHA-256 `d2f0a030438af3302d6fa01d93925b55d082a935480ea6c8c866ad3a39a6cf63`.
- ZIP 200,963,782바이트. SHA-256 `9ad255ed1142c7883246c529205e33a1ab897af7e18afaf76c51e15bad57c172`.

## 다운로드

연결 도구가100MiB 초과 업로드를 HTTP413으로 거부했다. PC 브라우저 실행 승인은 시간 초과돼 해당 경로로 업로드하지 않았다. 아트/플레이 자료를 줄이지 않고 ZIP을 두 조각으로 나눴다. 아래 앞의 세 파일을 같은 PC 폴더에 다운로드한 뒤 합치기 파일을 실행하면 해시를 검사하고 APK를 압축 해제한다. 기존의 다른 ZIP/출력 폴더는 덮어쓰지 않는다.

- [첫 조각 .001](https://drive.google.com/file/d/17TgHDGvLCxfoZQwt93j0otv9hPUOwnI1/view?usp=drivesdk),100,663,296바이트.
- [둘째 조각 .002](https://drive.google.com/file/d/1jwhxkbdh7u4sSa7-ybErabN6VVD6Qs5l/view?usp=drivesdk),100,300,486바이트.
- [OPEN_ORVASK_BUILD.cmd](https://drive.google.com/file/d/1vr8Rs68Hm-Smn_MseLRhCFghmCG_oGhy/view?usp=drivesdk).
- [설치 안내](https://drive.google.com/file/d/1wg73d0H_75WTpee-oebS-eNM1n6ca_Rh/view?usp=drivesdk).

[기존 모바일 폴더](https://drive.google.com/drive/folders/1TFdLBn5mCbLWtwg2EP-ZeNW1oCgcWzbO)의 공유 권한은 변경하지 않았다. 네 파일 모두 원격 ID/이름/크기/부모 폴더를 확인했고, 다시 내려받아 SHA-256을 비교했다. 임시 다운로드 주소는 기록하지 않았다.

## 검증

APK 서명·버전·ABI·16KiB 정렬, APK/ZIP CRC, 테스트 소스 제외 검사를 통과했다. 실제 APK의 컴파일 자료2,860개로 본편을 불러오고 현재 정비소의2발→강화1발,5총기의 장전/확정/재장전을 검사했다. `MOBILE_PACKAGE_PROBE_PASS model=15`, 표준 오류는 비어 있다. 기존 패키지 검사가 새 도전에 구형 유료 개조를 요구하던 부분만 현재 규칙에 맞췄고 구형 분기를 유지했다. 게임 코드는 수정하지 않았다.

최신 UI 반응·총기/적중/전이·불씨 효과가 APK에 포함된다. 내보내기 후 원본 프로젝트 설정/사용자 Android preset을 복구했다. 두 조각의 재결합 SHA-256은 원본 ZIP과 일치한다. 합치기 파일은 작은 ZIP으로 동일 조립/해시/압축 해제 경로를 검사했다(폴더 열기만 생략). SDK 접근 제한으로 실패한 첫 내보내기는 실제 SDK에 접근 가능한 실행 환경에서 재실행해 해결했다.

근거: `builds/mobile/releases/LastOnBoard-20261106-140337-v20261106/`의 `build_manifest.json`, `validation.json`, `package_probe/`, `signature.log`, `alignment.log`, `multipart_delivery_request.json`, `drive_metadata.json`, `drive_parts_readback.json`, `drive_helpers_readback.json`, `upload_receipt.json`. `builds/mobile/latest.json`에 `delivery_mode: split-zip`과 네 원격 파일을 기록했다. Galaxy S26의 지속 성능·발열·터치·연출 체감은 미확인이다.

## Godot 기본 내보내기와 차이

로컬 `새-게임-프로젝트/Zip/ORVASK.apk`의 실제 정보는 앱 이름 ORVASK / `com.example.orvask` / 버전 코드1 / ARM64 /247,480,258바이트다. 현재 기본 preset은 전체 리소스 내보내기다. 이 기존 APK에는 이번 UI 반응의 두 스크립트가 없어 최신 변경 이전 결과물이다.

마지막 Drive 전달본(2026-10-31)은 `weapon-magazine` / `res://redesign/samples/combat_weapon_magazine.tscn`의 탄창·빼내기 독립 비교판이었다. 이번은 본편 main 씬이다. 기본 내보내기와 테스트 앱은 식별자가 달라 Android 저장도 별도이며 자동 공유/변환하지 않는다. 이번은 기존 테스트 앱에 업데이트 설치한다.

두 경로 모두 Godot를 사용한다. 차이는 제작 주체보다 실제 프로젝트 버전·시작 씬·포함 리소스·내보내기 설정·앱 식별자/저장에서 확인해야 한다. 새 밸런스/패턴은 ‘새 도전’, 기존 진행은 ‘이어하기’로 구분한다.
